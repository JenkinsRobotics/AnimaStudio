"""``.scene.anima`` execution: show model, loader, deterministic runner.

A scene is a self-contained show: it names the ``.character.anima`` it
drives (resolved relative to the scene file), declares scalar
``variables``, and lists a ``sequence`` of actions. This module ships
the executable subset of ``dev/docs/roadmap/Scene_Format.md`` —
execution v1 (``clip``, ``pose``, ``wait``, ``wait_for``, ``set``,
``if``, ``loop``, ``parallel``, ``event``) plus the v2
scripting-engine constructs (FANUC Teach Pendant-inspired): structured
condition trees (leaf compare + ``all``/``any``/``xor``/``not``,
node-mappable data — never string expressions), ``select`` multi-way
branches, ``call`` + top-level ``subroutines:``, externally driven
read-only ``inputs:``, level-triggered ``wait_until`` gates, and
background ``monitors:`` (BG Logic: interlock rules scanned every tick
before the main sequence, edge-triggered, restricted to ``set`` /
``event`` / ``end_scene``). It rejects, with a ``SceneFormatError``
naming the offending path, every spec'd action the runtime cannot
execute yet (``speak``, ``expression``, ``blend_shapes``, ``lights``,
``ai_response``, ``goto``/``label``) rather than playing a show back
incompletely. Parsing follows ``animacore.loader`` discipline:
closed schema, typed pathed errors, explicit units (``_s``/``_ms``).

The executor, ``SceneRunner``, has no wall clock — the caller drives
scene-local time with ``advance(now_s)`` ticks and delivers logic-gate
events with ``post_event(name)`` and input changes with
``set_input(name, value)`` between ticks, mirroring ``sim.py``. Input
changes take effect at the next tick boundary for determinism. Each
tick first applies pending inputs, then scans every monitor in
declaration order (a monitor firing ``end_scene`` e-stops the adapter
and finishes the run with the monitor's result string), then resolves
due actions in global timestamp order (ties broken by track creation
order — that is the deterministic ``parallel`` interleaving),
evaluates the character pose, projects it through
``rig.project_channels``, and streams one frame to an
``outputs.OutputAdapter``. Opening/closing the adapter (channel
configs are hardware detail, not scene detail) stays the caller's job.

Motion model: the runner holds every animatable target's last settled
value (initially neutral). ``clip`` and ``pose`` actions register
motion sources; active sources override held values in start order, so
a later-started source wins a contested target while both are active.
A finished source settles its final values into the held state.
Relation-driven DOF are recomputed from the merged driver values every
frame; a driven value outside its limits surfaces exactly per the
K-packet rules — reported on the pose, and ``project_channels`` raises
``LimitViolationError`` for a mapped violated DOF (never clamps).
The scene finishes when the root sequence AND every background
(``wait: false``) source have run to completion.

# ponytail: deliberate ceilings — `set` values and condition-leaf
# `value:` are literals or other variable names only (no
# arithmetic/expressions); `wait_for`/`wait_until` outcomes cannot
# branch (on_timeout is skip|end, no timeout-set-var); a finished
# short source's value holds only until an earlier still-active
# source reasserts the target (no per-target ownership); wait_until
# and monitors sample conditions at tick granularity (a mid-tick
# variable write is observed at the tick that contains it, not at its
# own timestamp).
"""

from __future__ import annotations

import math
from collections.abc import Callable, Iterator, Mapping
from dataclasses import dataclass, field
from enum import StrEnum
from pathlib import Path

import yaml

from animacore.loader import CharacterFormatError, load_character_file
from animacore.outputs import OutputAdapter
from animacore.rig import (
    DofKind,
    Identity,
    LimitViolation,
    Pose,
    Rig,
    RigClip,
    project_channels,
    relations_in_dependency_order,
)
from animacore.tracks import evaluate_clip

SUPPORTED_ANIMA_VERSION = "2.0"
SUPPORTED_TYPE = "scene"

DEFAULT_FRAME_INTERVAL_MS = 33

# Spec'd action types deferred past v1. Kept explicit so a scene using
# them fails loudly instead of playing back incompletely.
_DEFERRED_ACTIONS = (
    "speak",
    "expression",
    "blend_shapes",
    "lights",
    "ai_response",
    "goto",
    "label",
)

_ACTION_KEYS = (
    "clip",
    "pose",
    "wait",
    "wait_for",
    "wait_until",
    "set",
    "if",
    "select",
    "loop",
    "parallel",
    "call",
    "event",
)

# The only actions legal inside a monitor body (BG Logic is a PLC, not
# a second choreography track): instantaneous interlock effects.
_MONITOR_ACTION_KEYS = ("set", "event", "end_scene")

VariableValue = bool | int | float | str


class SceneFormatError(ValueError):
    """A scene file that cannot be loaded; ``path`` names the field."""

    def __init__(self, path: str, message: str):
        super().__init__(f"{path}: {message}")
        self.path = path
        self.message = message


class SceneRuntimeError(RuntimeError):
    """A scene that cannot continue executing (bad clock, dead loop)."""


class TimeoutPolicy(StrEnum):
    """What a timed-out ``wait_for``/``wait_until`` gate does."""

    SKIP = "skip"
    END = "end"


class CompareOp(StrEnum):
    """Comparison operator of a condition leaf."""

    EQ = "eq"
    NE = "ne"
    LT = "lt"
    LE = "le"
    GT = "gt"
    GE = "ge"


class SceneResult(StrEnum):
    """How a scene run ended."""

    FINISHED = "finished"
    ENDED_BY_GATE_TIMEOUT = "ended_by_gate_timeout"
    STOPPED = "stopped"


@dataclass(frozen=True)
class EmittedEvent:
    """One outbound ``event`` emission, at scene-local time."""

    name: str
    time_s: float


# Conditions ---------------------------------------------------------------------
#
# Structured condition trees, used by `if: {when}`, `wait_until`, and
# `monitors`. Deliberately data, never string expressions: every node
# maps 1:1 onto a canvas node (dev/docs/roadmap/Node_Graph.md) and no
# expression parser exists. Nesting is unlimited.


@dataclass(frozen=True)
class CompareCondition:
    """One leaf comparison against a variable or an input.

    Exactly one of ``var``/``input`` names the left operand (the two
    namespaces stay explicit — inputs are the DI/RI analog, externally
    driven and read-only to the scene). ``value`` follows ``set:``
    discipline: a string naming a declared variable copies that
    variable at evaluation time; anything else is the literal itself.
    ``eq``/``ne`` compare same-kind values only (numbers compare
    numerically; ``true != 1`` per the v1 discipline; mismatched kinds
    are simply unequal). The ordering operators (``lt``/``le``/``gt``/
    ``ge``) require numbers on both sides — anything else is a typed
    runtime error naming this leaf.
    """

    path: str
    op: CompareOp
    value: VariableValue
    var: str | None = None
    input: str | None = None


@dataclass(frozen=True)
class AllCondition:
    """True when every operand is true (AND)."""

    path: str
    operands: tuple[Condition, ...]


@dataclass(frozen=True)
class AnyCondition:
    """True when at least one operand is true (OR)."""

    path: str
    operands: tuple[Condition, ...]


@dataclass(frozen=True)
class XorCondition:
    """True when exactly one operand is true — always exactly two
    operands, matching the FANUC binary XOR."""

    path: str
    operands: tuple[Condition, Condition]


@dataclass(frozen=True)
class NotCondition:
    """Inverts its operand."""

    path: str
    operand: Condition


Condition = (
    CompareCondition
    | AllCondition
    | AnyCondition
    | XorCondition
    | NotCondition
)


# Actions ----------------------------------------------------------------------
#
# Every action carries the file path that declared it
# (``sequence[2].if.then[0]``, ...) so rig-dependent validation and
# runtime errors can name their source line.


@dataclass(frozen=True)
class ClipAction:
    """Play a named character clip.

    ``speed`` is a playback-rate ratio (2.0 = twice as fast);
    ``duration_s`` bounds wall playback and is REQUIRED for a looping
    clip (a loop has no natural end); ``wait: false`` continues the
    sequence immediately while the clip keeps playing in the
    background.
    """

    path: str
    name: str
    speed: float = 1.0
    wait: bool = True
    duration_s: float | None = None


@dataclass(frozen=True)
class PoseAction:
    """Move to a target pose over ``duration_s`` (0 = jump).

    ``targets`` maps DOF paths / parameter names to values in file
    units (degrees for rotation DOF, meters for translation, 0..1 for
    parameters). Interpolation starts from each target's current value
    captured when the action starts.
    """

    path: str
    targets: Mapping[str, float]
    duration_s: float


@dataclass(frozen=True)
class WaitAction:
    """Hold the current pose for ``seconds``."""

    path: str
    seconds: float


@dataclass(frozen=True)
class WaitForAction:
    """Suspend until ``post_event(event)`` fires or ``timeout_s`` passes.

    Without ``timeout_s`` the gate waits indefinitely. ``on_timeout``
    (legal only with a timeout) is ``skip`` (continue past the gate,
    the default) or ``end`` (end the whole scene as
    ``ended_by_gate_timeout``).
    """

    path: str
    event: str
    timeout_s: float | None = None
    on_timeout: TimeoutPolicy = TimeoutPolicy.SKIP


@dataclass(frozen=True)
class SetAction:
    """Set a declared scene variable to a literal or another variable.

    A string value naming a declared variable copies that variable;
    any other value is the literal itself.
    """

    path: str
    var: str
    value: VariableValue


@dataclass(frozen=True)
class IfAction:
    """Run ``then`` when the guard holds, else ``orelse``.

    The guard is exactly one of: the v1 literal-equality form
    (``var`` + ``equals``, kept verbatim) or a v2 condition tree
    (``when``).
    """

    path: str
    then: tuple[Action, ...]
    var: str | None = None
    equals: VariableValue | None = None
    when: Condition | None = None
    orelse: tuple[Action, ...] = ()


@dataclass(frozen=True)
class SelectCase:
    """One ``select`` case: a literal and the actions it runs."""

    path: str
    equals: VariableValue
    then: tuple[Action, ...]


@dataclass(frozen=True)
class SelectAction:
    """FANUC SELECT: multi-way branch on a variable.

    The first case whose literal equals the variable (document order,
    same equality discipline as ``if``) runs — no fallthrough. With no
    match, ``default`` runs (empty when omitted). Duplicate case
    literals are rejected at parse.
    """

    path: str
    var: str
    cases: tuple[SelectCase, ...]
    default: tuple[Action, ...] = ()


@dataclass(frozen=True)
class CallAction:
    """FANUC CALL: run the named subroutine, then resume here.

    Subroutines share the scene's variable scope (registers are global
    on a Teach Pendant too). Recursion — direct or indirect — is
    rejected at parse with the cycle named.
    """

    path: str
    name: str


@dataclass(frozen=True)
class WaitUntilAction:
    """FANUC WAIT: suspend until the condition holds (level-triggered).

    The condition is sampled the moment the action starts and then at
    every tick boundary; the gate passes at the first sample where it
    holds (unlike ``wait_for``'s edge-triggered events, a condition
    that is already true never waits). ``timeout_s``/``on_timeout``
    mirror ``wait_for``; a timeout that fires before the condition is
    observed true wins.
    """

    path: str
    when: Condition
    timeout_s: float | None = None
    on_timeout: TimeoutPolicy = TimeoutPolicy.SKIP


@dataclass(frozen=True)
class EndSceneAction:
    """Stop all motion (adapter e-stop) and finish the run with the
    given result string (e.g. ``"estop"``). Legal only inside a
    monitor body."""

    path: str
    result: str


@dataclass(frozen=True)
class LoopAction:
    """Repeat ``body``: exactly ``count`` times, or while a bool
    variable is true (checked before every iteration)."""

    path: str
    body: tuple[Action, ...]
    count: int | None = None
    while_var: str | None = None


@dataclass(frozen=True)
class ParallelAction:
    """Run every track concurrently; completes when all tracks finish.

    Interleaving is deterministic: due steps execute in timestamp
    order, ties broken by track declaration order.
    """

    path: str
    tracks: tuple[tuple[Action, ...], ...]


@dataclass(frozen=True)
class EmitAction:
    """Emit an outbound named event (recorded, and sent to the
    runner's ``on_event`` callback)."""

    path: str
    name: str


Action = (
    ClipAction
    | PoseAction
    | WaitAction
    | WaitForAction
    | WaitUntilAction
    | SetAction
    | IfAction
    | SelectAction
    | LoopAction
    | ParallelAction
    | CallAction
    | EmitAction
)

# What a monitor body may contain. EndSceneAction is deliberately NOT
# part of the Action union: it can never appear in a sequence.
MonitorAction = SetAction | EmitAction | EndSceneAction


@dataclass(frozen=True)
class Monitor:
    """One background interlock rule (FANUC BG Logic).

    Scanned every tick, in declaration order, before the main
    sequence. Edge-triggered: fires when the condition transitions
    false -> true (a condition already true at the first tick fires,
    the prior state starts false) and re-arms after it goes false.
    """

    path: str
    name: str
    when: Condition
    do: tuple[MonitorAction, ...]


@dataclass(frozen=True)
class Scene:
    """One parsed ``.scene.anima`` document (rig-independent AST)."""

    identity: Identity
    character: str
    variables: Mapping[str, VariableValue]
    sequence: tuple[Action, ...]
    # v2 scripting surface (all optional in the file).
    # Inputs are the DI/RI analog: externally driven initial scalars,
    # read-only to the scene, a namespace distinct from variables.
    inputs: Mapping[str, VariableValue] = field(default_factory=dict)
    subroutines: Mapping[str, tuple[Action, ...]] = field(
        default_factory=dict
    )
    monitors: tuple[Monitor, ...] = ()
    # Opaque editor metadata (node-canvas layout etc. — see
    # dev/docs/roadmap/Node_Graph.md). Preserved for round-trip,
    # NEVER interpreted by the runtime.
    editor: Mapping[str, object] | None = None


# Loading ----------------------------------------------------------------------


def load_scene_file(file_path: str | Path) -> tuple[Scene, Rig]:
    """Read one ``.scene.anima`` file and the character rig it drives.

    The ``character:`` path resolves relative to the scene file's
    directory. The returned scene is fully validated against the rig.
    """
    path = Path(file_path)
    scene = parse_scene(path.read_text(encoding="utf-8"))
    character_path = path.parent / scene.character
    if not character_path.is_file():
        raise SceneFormatError(
            "character", f"character file not found: {character_path}"
        )
    try:
        rig = load_character_file(character_path)
    except CharacterFormatError as error:
        raise SceneFormatError(
            "character", f"failed to load {character_path}: {error}"
        ) from error
    validate_scene(scene, rig)
    return scene, rig


def parse_scene(text: str) -> Scene:
    """Parse ``.scene.anima`` YAML text into a structural ``Scene``.

    Rig-dependent rules (clip names, pose targets/limits, variable
    references) are checked by ``validate_scene``.
    """
    try:
        document = yaml.safe_load(text)
    except yaml.YAMLError as error:
        raise SceneFormatError(
            "<document>", f"not valid YAML: {error}"
        ) from error
    document = _mapping(document, "<document>")

    _check_header(document)
    _check_top_level_fields(document)

    identity = _parse_identity(_mapping(document["identity"], "identity"))
    character = _string(document["character"], "character")
    if not character:
        raise SceneFormatError("character", "must not be empty")
    variables = _parse_variables(document.get("variables"))
    inputs = _parse_inputs(document.get("inputs"))
    sequence = _parse_actions(document["sequence"], "sequence")
    subroutines = _parse_subroutines(document.get("subroutines"))
    monitors = _parse_monitors(document.get("monitors"))
    _check_call_graph(sequence, subroutines)
    editor = document.get("editor")
    if editor is not None and not isinstance(editor, dict):
        raise SceneFormatError("editor", "must be a mapping when present")
    return Scene(
        identity=identity,
        character=character,
        variables=variables,
        sequence=sequence,
        inputs=inputs,
        subroutines=subroutines,
        monitors=monitors,
        editor=editor,
    )


def _check_header(document: dict) -> None:
    version = document.get("anima_version")
    if version is None:
        raise SceneFormatError("anima_version", "missing required field")
    if version != SUPPORTED_ANIMA_VERSION:
        raise SceneFormatError(
            "anima_version",
            f"unsupported version {version!r} "
            f"(expected {SUPPORTED_ANIMA_VERSION!r})",
        )
    file_type = document.get("type")
    if file_type is None:
        raise SceneFormatError("type", "missing required field")
    if file_type != SUPPORTED_TYPE:
        raise SceneFormatError(
            "type", f"expected {SUPPORTED_TYPE!r}, got {file_type!r}"
        )
    for section in ("identity", "character", "sequence"):
        if section not in document:
            raise SceneFormatError(section, "missing required section")


def _check_top_level_fields(document: dict) -> None:
    supported = {
        "anima_version",
        "type",
        "identity",
        "character",
        "variables",
        "inputs",
        "sequence",
        "subroutines",
        "monitors",
        "editor",
    }
    for key in document:
        if key == "meta":
            raise SceneFormatError(
                "meta",
                "draft-spec section superseded in v1 "
                "(scene identity lives in identity:)",
            )
        if key not in supported:
            raise SceneFormatError(str(key), "unknown field")


def _parse_identity(raw: dict) -> Identity:
    _reject_unknown_fields(
        raw,
        "identity",
        {"name", "display_name", "description", "version", "author"},
    )
    if "name" not in raw:
        raise SceneFormatError("identity.name", "missing required field")
    name = _string(raw["name"], "identity.name")
    if not name:
        raise SceneFormatError("identity.name", "must not be empty")
    return Identity(
        name=name,
        display_name=_string(
            raw.get("display_name", ""), "identity.display_name"
        ),
        description=_string(
            raw.get("description", ""), "identity.description"
        ),
        version=_string(raw.get("version", ""), "identity.version"),
        author=_string(raw.get("author", ""), "identity.author"),
    )


def _parse_variables(raw: object) -> dict[str, VariableValue]:
    if raw is None:
        return {}
    variables: dict[str, VariableValue] = {}
    for name, value in _mapping(raw, "variables").items():
        path = f"variables.{name}"
        if not isinstance(name, str) or not name:
            raise SceneFormatError(
                path, f"variable name must be a non-empty string: {name!r}"
            )
        variables[name] = _variable_value(value, path)
    return variables


def _parse_inputs(raw: object) -> dict[str, VariableValue]:
    if raw is None:
        return {}
    inputs: dict[str, VariableValue] = {}
    for name, value in _mapping(raw, "inputs").items():
        path = f"inputs.{name}"
        if not isinstance(name, str) or not name:
            raise SceneFormatError(
                path, f"input name must be a non-empty string: {name!r}"
            )
        inputs[name] = _variable_value(value, path)
    return inputs


def _parse_subroutines(raw: object) -> dict[str, tuple[Action, ...]]:
    if raw is None:
        return {}
    subroutines: dict[str, tuple[Action, ...]] = {}
    for name, body in _mapping(raw, "subroutines").items():
        path = f"subroutines.{name}"
        if not isinstance(name, str) or not name:
            raise SceneFormatError(
                path,
                f"subroutine name must be a non-empty string: {name!r}",
            )
        subroutines[name] = _parse_actions(body, path)
    return subroutines


def _parse_monitors(raw: object) -> tuple[Monitor, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        raise SceneFormatError(
            "monitors",
            f"expected a list of monitors, got {type(raw).__name__}",
        )
    monitors: list[Monitor] = []
    seen: set[str] = set()
    for index, entry_raw in enumerate(raw):
        path = f"monitors[{index}]"
        entry = _mapping(entry_raw, path)
        _reject_unknown_fields(entry, path, {"name", "when", "do"})
        for required in ("name", "when", "do"):
            if required not in entry:
                raise SceneFormatError(
                    f"{path}.{required}", "missing required field"
                )
        name = _string(entry["name"], f"{path}.name")
        if not name:
            raise SceneFormatError(f"{path}.name", "must not be empty")
        if name in seen:
            raise SceneFormatError(
                f"{path}.name", f"duplicate monitor name {name!r}"
            )
        seen.add(name)
        monitors.append(
            Monitor(
                path=path,
                name=name,
                when=_parse_condition(entry["when"], f"{path}.when"),
                do=_parse_monitor_actions(entry["do"], f"{path}.do"),
            )
        )
    return tuple(monitors)


def _parse_monitor_actions(
    raw: object, path: str
) -> tuple[MonitorAction, ...]:
    if not isinstance(raw, list) or not raw:
        raise SceneFormatError(
            path, f"expected a non-empty list of actions, got {raw!r}"
        )
    return tuple(
        _parse_monitor_action(entry, f"{path}[{index}]")
        for index, entry in enumerate(raw)
    )


def _parse_monitor_action(raw: object, path: str) -> MonitorAction:
    entry = _mapping(raw, path)
    present = [key for key in _MONITOR_ACTION_KEYS if key in entry]
    if len(present) > 1:
        raise SceneFormatError(
            path,
            f"entry declares more than one action: {', '.join(present)}",
        )
    if not present:
        offending = next(
            (
                key
                for key in (*_ACTION_KEYS, *_DEFERRED_ACTIONS)
                if key in entry
            ),
            None,
        )
        if offending is not None:
            raise SceneFormatError(
                f"{path}.{offending}",
                f"{offending!r} is not allowed in a monitor body — "
                f"background monitors are interlock logic scanned every "
                f"tick (a PLC, not a second choreography track); only "
                f"set, event, and end_scene are legal here",
            )
        first = next(iter(entry), "<empty>")
        raise SceneFormatError(
            f"{path}.{first}",
            "unknown action (monitor bodies allow: set, event, end_scene)",
        )
    action_key = present[0]
    if action_key == "set":
        return _parse_set(entry, path)
    if action_key == "event":
        return _parse_event(entry, path)
    return _parse_end_scene(entry, path)


def _iter_actions(actions: tuple[Action, ...]) -> Iterator[Action]:
    """Every action in the tree, depth-first, containers included."""
    for action in actions:
        yield action
        if isinstance(action, IfAction):
            yield from _iter_actions(action.then)
            yield from _iter_actions(action.orelse)
        elif isinstance(action, SelectAction):
            for case in action.cases:
                yield from _iter_actions(case.then)
            yield from _iter_actions(action.default)
        elif isinstance(action, LoopAction):
            yield from _iter_actions(action.body)
        elif isinstance(action, ParallelAction):
            for track in action.tracks:
                yield from _iter_actions(track)


def _check_call_graph(
    sequence: tuple[Action, ...],
    subroutines: Mapping[str, tuple[Action, ...]],
) -> None:
    """Every call target must exist; the subroutine call graph must be
    acyclic — recursion (direct or indirect) is rejected with the
    cycle path named."""
    for action in _iter_actions(sequence):
        if isinstance(action, CallAction) and action.name not in subroutines:
            _unknown_subroutine(action, subroutines)
    calls: dict[str, list[CallAction]] = {}
    for name, body in subroutines.items():
        calls[name] = []
        for action in _iter_actions(body):
            if isinstance(action, CallAction):
                if action.name not in subroutines:
                    _unknown_subroutine(action, subroutines)
                calls[name].append(action)

    state: dict[str, int] = {}  # 1 = on the DFS stack, 2 = finished

    def visit(name: str, stack: tuple[str, ...]) -> None:
        state[name] = 1
        for call in calls[name]:
            if state.get(call.name) == 1:
                cycle = stack[stack.index(call.name) :] + (call.name,)
                raise SceneFormatError(
                    f"{call.path}.call",
                    f"recursive subroutine call: {' -> '.join(cycle)}",
                )
            if state.get(call.name) is None:
                visit(call.name, stack + (call.name,))
        state[name] = 2

    for name in subroutines:
        if state.get(name) is None:
            visit(name, (name,))


def _unknown_subroutine(
    action: CallAction, subroutines: Mapping[str, tuple[Action, ...]]
) -> None:
    known = ", ".join(sorted(subroutines)) or "none"
    raise SceneFormatError(
        f"{action.path}.call",
        f"unknown subroutine {action.name!r} (subroutines: {known})",
    )


def _parse_actions(raw: object, path: str) -> tuple[Action, ...]:
    if not isinstance(raw, list):
        raise SceneFormatError(
            path, f"expected a list of actions, got {type(raw).__name__}"
        )
    return tuple(
        _parse_action(entry, f"{path}[{index}]")
        for index, entry in enumerate(raw)
    )


def _parse_action(raw: object, path: str) -> Action:
    entry = _mapping(raw, path)
    for deferred in _DEFERRED_ACTIONS:
        if deferred in entry:
            raise SceneFormatError(
                f"{path}.{deferred}",
                "spec'd action deferred past scene execution v1 "
                "(see Scene_Format.md); the runtime cannot execute it yet",
            )
    if "end_scene" in entry:
        raise SceneFormatError(
            f"{path}.end_scene",
            "end_scene is legal only inside a monitors: do: block",
        )
    present = [key for key in _ACTION_KEYS if key in entry]
    if "clip" in present and "wait" in present:
        # Inside a clip entry, `wait:` is the completion flag
        # (`wait: false` = keep playing in the background), not a
        # wait action.
        present.remove("wait")
    if not present:
        first = next(iter(entry), "<empty>")
        valid = ", ".join(_ACTION_KEYS)
        raise SceneFormatError(
            f"{path}.{first}", f"unknown action (expected one of: {valid})"
        )
    if len(present) > 1:
        raise SceneFormatError(
            path,
            f"entry declares more than one action: {', '.join(present)}",
        )
    action_key = present[0]
    parser = _ACTION_PARSERS[action_key]
    return parser(entry, path)


_CONDITION_COMBINATORS = ("all", "any", "xor", "not")


def _parse_condition(raw: object, path: str) -> Condition:
    entry = _mapping(raw, path)
    present = [key for key in _CONDITION_COMBINATORS if key in entry]
    if len(present) > 1:
        raise SceneFormatError(
            path,
            f"condition declares more than one combinator: "
            f"{', '.join(present)}",
        )
    if present:
        combinator = present[0]
        _reject_unknown_fields(entry, path, {combinator})
        if combinator == "not":
            return NotCondition(
                path=path,
                operand=_parse_condition(entry["not"], f"{path}.not"),
            )
        operands_raw = entry[combinator]
        if not isinstance(operands_raw, list):
            raise SceneFormatError(
                f"{path}.{combinator}",
                f"expected a list of conditions, "
                f"got {type(operands_raw).__name__}",
            )
        if combinator == "xor" and len(operands_raw) != 2:
            raise SceneFormatError(
                f"{path}.xor",
                f"xor takes exactly two operands (the FANUC binary XOR), "
                f"got {len(operands_raw)}",
            )
        if not operands_raw:
            raise SceneFormatError(
                f"{path}.{combinator}", "requires at least one condition"
            )
        operands = tuple(
            _parse_condition(operand, f"{path}.{combinator}[{index}]")
            for index, operand in enumerate(operands_raw)
        )
        if combinator == "all":
            return AllCondition(path=path, operands=operands)
        if combinator == "any":
            return AnyCondition(path=path, operands=operands)
        return XorCondition(path=path, operands=operands)
    # Leaf comparison.
    _reject_unknown_fields(entry, path, {"var", "input", "op", "value"})
    if ("var" in entry) == ("input" in entry):
        raise SceneFormatError(
            path,
            "a condition leaf names exactly one of var (a scene "
            "variable) or input (an externally driven input)",
        )
    for required in ("op", "value"):
        if required not in entry:
            raise SceneFormatError(
                f"{path}.{required}", "missing required field"
            )
    try:
        op = CompareOp(entry["op"])
    except ValueError:
        valid = ", ".join(member.value for member in CompareOp)
        raise SceneFormatError(
            f"{path}.op",
            f"expected one of {valid}, got {entry['op']!r}",
        ) from None
    value = _variable_value(entry["value"], f"{path}.value")
    if "var" in entry:
        var = _string(entry["var"], f"{path}.var")
        if not var:
            raise SceneFormatError(f"{path}.var", "must not be empty")
        return CompareCondition(path=path, op=op, value=value, var=var)
    input_name = _string(entry["input"], f"{path}.input")
    if not input_name:
        raise SceneFormatError(f"{path}.input", "must not be empty")
    return CompareCondition(path=path, op=op, value=value, input=input_name)


def _parse_clip(entry: dict, path: str) -> ClipAction:
    _reject_unknown_fields(
        entry, path, {"clip", "speed", "wait", "duration_s"}
    )
    name = _string(entry["clip"], f"{path}.clip")
    if not name:
        raise SceneFormatError(f"{path}.clip", "must not be empty")
    speed = _number(entry.get("speed", 1.0), f"{path}.speed")
    if speed <= 0:
        raise SceneFormatError(f"{path}.speed", f"must be > 0: {speed}")
    wait = _bool(entry.get("wait", True), f"{path}.wait")
    duration_s: float | None = None
    if "duration_s" in entry:
        duration_s = _number(entry["duration_s"], f"{path}.duration_s")
        if duration_s <= 0:
            raise SceneFormatError(
                f"{path}.duration_s", f"must be > 0: {duration_s}"
            )
    return ClipAction(
        path=path, name=name, speed=speed, wait=wait, duration_s=duration_s
    )


def _parse_pose(entry: dict, path: str) -> PoseAction:
    _reject_unknown_fields(entry, path, {"pose", "duration_s"})
    targets_raw = _mapping(entry["pose"], f"{path}.pose")
    if not targets_raw:
        raise SceneFormatError(f"{path}.pose", "requires at least one target")
    if "duration_s" in targets_raw:
        raise SceneFormatError(
            f"{path}.pose.duration_s",
            "duration_s belongs beside pose:, not inside the target mapping",
        )
    targets = {
        str(target): _number(value, f"{path}.pose.{target}")
        for target, value in targets_raw.items()
    }
    if "duration_s" not in entry:
        raise SceneFormatError(
            f"{path}.duration_s", "missing required field"
        )
    duration_s = _number(entry["duration_s"], f"{path}.duration_s")
    if duration_s < 0:
        raise SceneFormatError(
            f"{path}.duration_s", f"must be >= 0: {duration_s}"
        )
    return PoseAction(path=path, targets=targets, duration_s=duration_s)


def _parse_wait(entry: dict, path: str) -> WaitAction:
    _reject_unknown_fields(entry, path, {"wait"})
    block = _mapping(entry["wait"], f"{path}.wait")
    _reject_unknown_fields(block, f"{path}.wait", {"seconds"})
    if "seconds" not in block:
        raise SceneFormatError(
            f"{path}.wait.seconds", "missing required field"
        )
    seconds = _number(block["seconds"], f"{path}.wait.seconds")
    if seconds < 0:
        raise SceneFormatError(
            f"{path}.wait.seconds", f"must be >= 0: {seconds}"
        )
    return WaitAction(path=path, seconds=seconds)


def _parse_wait_for(entry: dict, path: str) -> WaitForAction:
    _reject_unknown_fields(entry, path, {"wait_for"})
    block = _mapping(entry["wait_for"], f"{path}.wait_for")
    _reject_unknown_fields(
        block, f"{path}.wait_for", {"event", "timeout_s", "on_timeout"}
    )
    if "event" not in block:
        raise SceneFormatError(
            f"{path}.wait_for.event", "missing required field"
        )
    event = _string(block["event"], f"{path}.wait_for.event")
    if not event:
        raise SceneFormatError(f"{path}.wait_for.event", "must not be empty")
    timeout_s: float | None = None
    if "timeout_s" in block:
        timeout_s = _number(block["timeout_s"], f"{path}.wait_for.timeout_s")
        if timeout_s <= 0:
            raise SceneFormatError(
                f"{path}.wait_for.timeout_s", f"must be > 0: {timeout_s}"
            )
    on_timeout = TimeoutPolicy.SKIP
    if "on_timeout" in block:
        if timeout_s is None:
            raise SceneFormatError(
                f"{path}.wait_for.on_timeout",
                "meaningless without timeout_s",
            )
        try:
            on_timeout = TimeoutPolicy(block["on_timeout"])
        except ValueError:
            raise SceneFormatError(
                f"{path}.wait_for.on_timeout",
                f"expected 'skip' or 'end', got {block['on_timeout']!r}",
            ) from None
    return WaitForAction(
        path=path, event=event, timeout_s=timeout_s, on_timeout=on_timeout
    )


def _parse_set(entry: dict, path: str) -> SetAction:
    _reject_unknown_fields(entry, path, {"set"})
    block = _mapping(entry["set"], f"{path}.set")
    _reject_unknown_fields(block, f"{path}.set", {"var", "value"})
    for required in ("var", "value"):
        if required not in block:
            raise SceneFormatError(
                f"{path}.set.{required}", "missing required field"
            )
    var = _string(block["var"], f"{path}.set.var")
    if not var:
        raise SceneFormatError(f"{path}.set.var", "must not be empty")
    value = _variable_value(block["value"], f"{path}.set.value")
    return SetAction(path=path, var=var, value=value)


def _parse_if(entry: dict, path: str) -> IfAction:
    _reject_unknown_fields(entry, path, {"if"})
    block = _mapping(entry["if"], f"{path}.if")
    _reject_unknown_fields(
        block, f"{path}.if", {"var", "equals", "when", "then", "else"}
    )
    if "then" not in block:
        raise SceneFormatError(f"{path}.if.then", "missing required field")
    has_when = "when" in block
    has_equality = "var" in block or "equals" in block
    if has_when == has_equality:
        raise SceneFormatError(
            f"{path}.if",
            "give exactly one guard: var+equals (literal equality) or "
            "when: (a condition tree)",
        )
    then = _parse_actions(block["then"], f"{path}.if.then")
    orelse = _parse_actions(block.get("else", []), f"{path}.if.else")
    if has_when:
        when = _parse_condition(block["when"], f"{path}.if.when")
        return IfAction(path=path, then=then, when=when, orelse=orelse)
    for required in ("var", "equals"):
        if required not in block:
            raise SceneFormatError(
                f"{path}.if.{required}", "missing required field"
            )
    var = _string(block["var"], f"{path}.if.var")
    if not var:
        raise SceneFormatError(f"{path}.if.var", "must not be empty")
    equals = _variable_value(block["equals"], f"{path}.if.equals")
    return IfAction(
        path=path, var=var, equals=equals, then=then, orelse=orelse
    )


def _parse_select(entry: dict, path: str) -> SelectAction:
    _reject_unknown_fields(entry, path, {"select"})
    block = _mapping(entry["select"], f"{path}.select")
    _reject_unknown_fields(
        block, f"{path}.select", {"var", "cases", "default"}
    )
    for required in ("var", "cases"):
        if required not in block:
            raise SceneFormatError(
                f"{path}.select.{required}", "missing required field"
            )
    var = _string(block["var"], f"{path}.select.var")
    if not var:
        raise SceneFormatError(f"{path}.select.var", "must not be empty")
    cases_raw = block["cases"]
    if not isinstance(cases_raw, list) or not cases_raw:
        raise SceneFormatError(
            f"{path}.select.cases",
            f"expected a non-empty list of cases, got {cases_raw!r}",
        )
    cases: list[SelectCase] = []
    for index, case_raw in enumerate(cases_raw):
        case_path = f"{path}.select.cases[{index}]"
        case = _mapping(case_raw, case_path)
        _reject_unknown_fields(case, case_path, {"equals", "then"})
        for required in ("equals", "then"):
            if required not in case:
                raise SceneFormatError(
                    f"{case_path}.{required}", "missing required field"
                )
        equals = _variable_value(case["equals"], f"{case_path}.equals")
        if any(
            _scalar_equals(equals, previous.equals) for previous in cases
        ):
            raise SceneFormatError(
                f"{case_path}.equals",
                f"duplicate case literal {equals!r} (the first matching "
                f"case wins in document order; a duplicate can never run)",
            )
        cases.append(
            SelectCase(
                path=case_path,
                equals=equals,
                then=_parse_actions(case["then"], f"{case_path}.then"),
            )
        )
    default = _parse_actions(
        block.get("default", []), f"{path}.select.default"
    )
    return SelectAction(
        path=path, var=var, cases=tuple(cases), default=default
    )


def _parse_call(entry: dict, path: str) -> CallAction:
    _reject_unknown_fields(entry, path, {"call"})
    name = _string(entry["call"], f"{path}.call")
    if not name:
        raise SceneFormatError(f"{path}.call", "must not be empty")
    return CallAction(path=path, name=name)


def _parse_wait_until(entry: dict, path: str) -> WaitUntilAction:
    _reject_unknown_fields(entry, path, {"wait_until"})
    block = _mapping(entry["wait_until"], f"{path}.wait_until")
    _reject_unknown_fields(
        block, f"{path}.wait_until", {"when", "timeout_s", "on_timeout"}
    )
    if "when" not in block:
        raise SceneFormatError(
            f"{path}.wait_until.when", "missing required field"
        )
    when = _parse_condition(block["when"], f"{path}.wait_until.when")
    timeout_s: float | None = None
    if "timeout_s" in block:
        timeout_s = _number(
            block["timeout_s"], f"{path}.wait_until.timeout_s"
        )
        if timeout_s <= 0:
            raise SceneFormatError(
                f"{path}.wait_until.timeout_s", f"must be > 0: {timeout_s}"
            )
    on_timeout = TimeoutPolicy.SKIP
    if "on_timeout" in block:
        if timeout_s is None:
            raise SceneFormatError(
                f"{path}.wait_until.on_timeout",
                "meaningless without timeout_s",
            )
        try:
            on_timeout = TimeoutPolicy(block["on_timeout"])
        except ValueError:
            raise SceneFormatError(
                f"{path}.wait_until.on_timeout",
                f"expected 'skip' or 'end', got {block['on_timeout']!r}",
            ) from None
    return WaitUntilAction(
        path=path, when=when, timeout_s=timeout_s, on_timeout=on_timeout
    )


def _parse_end_scene(entry: dict, path: str) -> EndSceneAction:
    _reject_unknown_fields(entry, path, {"end_scene"})
    block = _mapping(entry["end_scene"], f"{path}.end_scene")
    _reject_unknown_fields(block, f"{path}.end_scene", {"result"})
    if "result" not in block:
        raise SceneFormatError(
            f"{path}.end_scene.result", "missing required field"
        )
    result = _string(block["result"], f"{path}.end_scene.result")
    if not result:
        raise SceneFormatError(
            f"{path}.end_scene.result", "must not be empty"
        )
    return EndSceneAction(path=path, result=result)


def _parse_loop(entry: dict, path: str) -> LoopAction:
    _reject_unknown_fields(entry, path, {"loop"})
    block = _mapping(entry["loop"], f"{path}.loop")
    _reject_unknown_fields(
        block, f"{path}.loop", {"count", "while_var", "body"}
    )
    if ("count" in block) == ("while_var" in block):
        raise SceneFormatError(
            f"{path}.loop", "give exactly one of count or while_var"
        )
    if "body" not in block:
        raise SceneFormatError(f"{path}.loop.body", "missing required field")
    body = _parse_actions(block["body"], f"{path}.loop.body")
    if not body:
        raise SceneFormatError(
            f"{path}.loop.body", "requires at least one action"
        )
    count: int | None = None
    while_var: str | None = None
    if "count" in block:
        count = _int(block["count"], f"{path}.loop.count")
        if count < 0:
            raise SceneFormatError(
                f"{path}.loop.count", f"must be >= 0: {count}"
            )
    else:
        while_var = _string(block["while_var"], f"{path}.loop.while_var")
        if not while_var:
            raise SceneFormatError(
                f"{path}.loop.while_var", "must not be empty"
            )
    return LoopAction(path=path, body=body, count=count, while_var=while_var)


def _parse_parallel(entry: dict, path: str) -> ParallelAction:
    _reject_unknown_fields(entry, path, {"parallel"})
    block = _mapping(entry["parallel"], f"{path}.parallel")
    _reject_unknown_fields(block, f"{path}.parallel", {"tracks"})
    if "tracks" not in block:
        raise SceneFormatError(
            f"{path}.parallel.tracks", "missing required field"
        )
    tracks_raw = block["tracks"]
    if not isinstance(tracks_raw, list) or not tracks_raw:
        raise SceneFormatError(
            f"{path}.parallel.tracks",
            f"expected a non-empty list of action lists, got {tracks_raw!r}",
        )
    tracks = tuple(
        _parse_actions(track, f"{path}.parallel.tracks[{index}]")
        for index, track in enumerate(tracks_raw)
    )
    return ParallelAction(path=path, tracks=tracks)


def _parse_event(entry: dict, path: str) -> EmitAction:
    _reject_unknown_fields(entry, path, {"event"})
    block = _mapping(entry["event"], f"{path}.event")
    _reject_unknown_fields(block, f"{path}.event", {"emit"})
    if "emit" not in block:
        raise SceneFormatError(
            f"{path}.event.emit", "missing required field"
        )
    name = _string(block["emit"], f"{path}.event.emit")
    if not name:
        raise SceneFormatError(f"{path}.event.emit", "must not be empty")
    return EmitAction(path=path, name=name)


_ACTION_PARSERS: dict[str, Callable[[dict, str], Action]] = {
    "clip": _parse_clip,
    "pose": _parse_pose,
    "wait": _parse_wait,
    "wait_for": _parse_wait_for,
    "wait_until": _parse_wait_until,
    "set": _parse_set,
    "if": _parse_if,
    "select": _parse_select,
    "loop": _parse_loop,
    "parallel": _parse_parallel,
    "call": _parse_call,
    "event": _parse_event,
}


# Rig-dependent validation -----------------------------------------------------


def validate_scene(scene: Scene, rig: Rig) -> None:
    """Check every rig-dependent rule; raises ``SceneFormatError``.

    Clip names must exist (a looping clip needs an explicit
    ``duration_s``); pose targets must be declared, not
    relation-driven, and within their limits; variable references must
    be declared under ``variables:`` and input references under
    ``inputs:``; ``set`` must never target an input. Subroutine bodies
    and monitor rules are validated exactly like the main sequence.
    """
    driven = {relation.driven for relation in rig.relations}
    _validate_actions(scene.sequence, scene, rig, driven)
    for body in scene.subroutines.values():
        _validate_actions(body, scene, rig, driven)
    for monitor in scene.monitors:
        _validate_condition(monitor.when, scene)
        _validate_actions(monitor.do, scene, rig, driven)


def _validate_actions(
    actions: tuple[Action | MonitorAction, ...],
    scene: Scene,
    rig: Rig,
    driven: set[str],
) -> None:
    for action in actions:
        if isinstance(action, ClipAction):
            rig_clip = rig.clips.get(action.name)
            if rig_clip is None:
                known = ", ".join(sorted(rig.clips)) or "none"
                raise SceneFormatError(
                    f"{action.path}.clip",
                    f"character has no clip {action.name!r} "
                    f"(clips: {known})",
                )
            if rig_clip.loop and action.duration_s is None:
                raise SceneFormatError(
                    f"{action.path}.duration_s",
                    f"clip {action.name!r} loops; a looping clip needs an "
                    f"explicit duration_s to bound playback",
                )
        elif isinstance(action, PoseAction):
            _pose_model_values(action, rig, driven)
        elif isinstance(action, SetAction):
            _require_settable_variable(
                scene, action.var, f"{action.path}.set.var"
            )
        elif isinstance(action, IfAction):
            if action.when is not None:
                _validate_condition(action.when, scene)
            else:
                _require_variable(
                    scene, action.var, f"{action.path}.if.var"
                )
            _validate_actions(action.then, scene, rig, driven)
            _validate_actions(action.orelse, scene, rig, driven)
        elif isinstance(action, SelectAction):
            _require_variable(
                scene, action.var, f"{action.path}.select.var"
            )
            for case in action.cases:
                _validate_actions(case.then, scene, rig, driven)
            _validate_actions(action.default, scene, rig, driven)
        elif isinstance(action, WaitUntilAction):
            _validate_condition(action.when, scene)
        elif isinstance(action, LoopAction):
            if action.while_var is not None:
                _require_variable(
                    scene,
                    action.while_var,
                    f"{action.path}.loop.while_var",
                )
            _validate_actions(action.body, scene, rig, driven)
        elif isinstance(action, ParallelAction):
            for track in action.tracks:
                _validate_actions(track, scene, rig, driven)


def _require_variable(scene: Scene, name: str, path: str) -> None:
    if name not in scene.variables:
        raise SceneFormatError(
            path,
            f"references undeclared variable {name!r} "
            f"(declare it under variables:)",
        )


def _require_settable_variable(scene: Scene, name: str, path: str) -> None:
    if name in scene.variables:
        return
    if name in scene.inputs:
        raise SceneFormatError(
            path,
            f"targets input {name!r} — inputs are externally driven and "
            f"read-only to the scene (drive them with "
            f"runner.set_input instead)",
        )
    _require_variable(scene, name, path)


def _validate_condition(condition: Condition, scene: Scene) -> None:
    if isinstance(condition, CompareCondition):
        if condition.var is not None:
            _require_variable(scene, condition.var, f"{condition.path}.var")
        elif condition.input not in scene.inputs:
            raise SceneFormatError(
                f"{condition.path}.input",
                f"references undeclared input {condition.input!r} "
                f"(declare it under inputs:)",
            )
        return
    if isinstance(condition, NotCondition):
        _validate_condition(condition.operand, scene)
        return
    for operand in condition.operands:
        _validate_condition(operand, scene)


def _pose_model_values(
    action: PoseAction, rig: Rig, driven: set[str]
) -> dict[str, float]:
    """A pose action's targets in model units (radians/meters/0..1),
    validated against the rig exactly like clip track values."""
    paths = rig.dof_paths()
    values: dict[str, float] = {}
    for target, raw_value in action.targets.items():
        value_path = f"{action.path}.pose.{target}"
        dof = paths.get(target)
        if dof is None and target not in rig.parameters:
            raise SceneFormatError(
                value_path,
                "references an undeclared DOF path or parameter",
            )
        if target in driven:
            raise SceneFormatError(
                value_path,
                "dof is driven by a relation; pose its driver instead",
            )
        value = raw_value
        if dof is not None:
            if dof.kind is DofKind.ROTATION:
                value = math.radians(raw_value)
            if dof.has_limits and not dof.minimum <= value <= dof.maximum:
                raise SceneFormatError(
                    value_path, f"{raw_value} outside the target's range"
                )
        elif not 0.0 <= value <= 1.0:
            raise SceneFormatError(
                value_path, f"{raw_value} outside the target's range"
            )
        values[target] = value
    return values


# Motion sources ----------------------------------------------------------------


class _ClipSource:
    """One playing clip: start time, speed ratio, bounded end."""

    def __init__(
        self,
        rig_clip: RigClip,
        start_s: float,
        speed: float,
        duration_s: float | None,
    ):
        self.clip = rig_clip.clip
        self.loop = rig_clip.loop
        self.start_s = start_s
        self.speed = speed
        if duration_s is not None:
            self.end_s = start_s + duration_s
        else:
            self.end_s = start_s + self.clip.duration_seconds / speed

    def values_at(self, time_s: float) -> dict[str, float]:
        local_s = (min(time_s, self.end_s) - self.start_s) * self.speed
        if self.loop and self.clip.duration_seconds > 0:
            local_s %= self.clip.duration_seconds
        return {
            str(target): value
            for target, value in evaluate_clip(self.clip, local_s).items()
        }


class _PoseSource:
    """One move-to-pose interpolation from captured start values."""

    def __init__(
        self,
        start_values: dict[str, float],
        end_values: dict[str, float],
        start_s: float,
        duration_s: float,
    ):
        self.start_values = start_values
        self.end_values = end_values
        self.start_s = start_s
        self.duration_s = duration_s
        self.end_s = start_s + duration_s

    def values_at(self, time_s: float) -> dict[str, float]:
        if self.duration_s <= 0 or time_s >= self.end_s:
            return dict(self.end_values)
        progress = max(0.0, time_s - self.start_s) / self.duration_s
        return {
            target: start + (self.end_values[target] - start) * progress
            for target, start in self.start_values.items()
        }


_MotionSource = _ClipSource | _PoseSource


# Executor ----------------------------------------------------------------------


class _EndSceneByTimeout(Exception):
    """Raised inside a track when a gate times out with policy END."""


class _Track:
    """One executing action sequence (the root, or a parallel track)."""

    def __init__(
        self, generator: Iterator, order: int, start_s: float
    ):
        self.generator = generator
        self.order = order
        self.start_s = start_s
        self.started = False
        self.done = False
        self.end_s = start_s
        # The last yielded request: ("sleep", until_s) |
        # ("gate", WaitForAction, started_s) | ("join", children).
        self.request: tuple = ()
        self.gate_fired_s: float | None = None


class SceneRunner:
    """Deterministic ``.scene.anima`` executor over an output adapter.

    No wall clock: the caller drives scene-local time with monotonic
    ``advance(now_s)`` ticks (typically at the frame interval) and
    delivers gate events with ``post_event(name)`` and input changes
    with ``set_input(name, value)`` between ticks (inputs apply at the
    next tick boundary for determinism). Each ``advance`` applies
    pending inputs, scans the background monitors (declaration order,
    edge-triggered), executes every action step due by ``now_s`` at
    its exact timestamp, then streams one evaluated frame through
    ``adapter.send_frame(targets, frame_interval_ms)``. The caller
    owns the adapter lifecycle (``open``/``close``); ``stop()``
    forwards an e-stop and marks the run ``stopped``. ``result`` stays
    ``None`` while the scene is running; a monitor ``end_scene`` sets
    it to the monitor's result string (e.g. ``"estop"``) after
    e-stopping the adapter.
    """

    def __init__(
        self,
        scene: Scene,
        rig: Rig,
        adapter: OutputAdapter,
        frame_interval_ms: int = DEFAULT_FRAME_INTERVAL_MS,
        on_event: Callable[[str, float], None] | None = None,
    ):
        validate_scene(scene, rig)
        if frame_interval_ms <= 0:
            raise ValueError(
                f"frame interval must be > 0 ms: {frame_interval_ms}"
            )
        self._scene = scene
        self._rig = rig
        self._adapter = adapter
        self._frame_interval_ms = frame_interval_ms
        self._on_event = on_event
        self._variables: dict[str, VariableValue] = dict(scene.variables)
        self._driven = {relation.driven for relation in rig.relations}
        self._relations_ordered = relations_in_dependency_order(
            rig.relations
        )
        self._held: dict[str, float] = {
            path: dof.neutral
            for path, dof in rig.dof_paths().items()
            if path not in self._driven
        }
        self._held.update(
            (name, parameter.neutral_value)
            for name, parameter in rig.parameters.items()
        )
        self._sources: list[_MotionSource] = []
        self._tracks: list[_Track] = []
        self._emitted: list[EmittedEvent] = []
        self._now_s = 0.0
        self._inputs: dict[str, VariableValue] = dict(scene.inputs)
        self._pending_inputs: dict[str, VariableValue] = {}
        # Per-monitor previous condition value (edge detection). Starts
        # false: a condition already true at the first tick fires.
        self._monitor_was_true = [False] * len(scene.monitors)
        self.result: SceneResult | str | None = None
        self._spawn_track(scene.sequence, 0.0)

    # Observability -----------------------------------------------------------

    @property
    def now_s(self) -> float:
        """Scene-local time of the last ``advance``."""
        return self._now_s

    @property
    def variables(self) -> dict[str, VariableValue]:
        """A snapshot of the scene variables."""
        return dict(self._variables)

    @property
    def inputs(self) -> dict[str, VariableValue]:
        """A snapshot of the effective input values (pending
        ``set_input`` changes are excluded until their tick)."""
        return dict(self._inputs)

    @property
    def emitted_events(self) -> tuple[EmittedEvent, ...]:
        """Every outbound event emitted so far, in emission order."""
        return tuple(self._emitted)

    # Driving -------------------------------------------------------------------

    def advance(self, now_s: float) -> SceneResult | str | None:
        """Advance scene-local time and stream one frame.

        Returns the run result, or ``None`` while the scene is still
        running. After the scene ends, ``advance`` is a no-op (no
        further frames are sent; the caller decides whether to hold,
        loop, or stop the hardware).
        """
        if now_s < self._now_s:
            raise SceneRuntimeError(
                f"time went backwards: {now_s} < {self._now_s}"
            )
        self._now_s = now_s
        if self.result is not None:
            return self.result
        self._inputs.update(self._pending_inputs)
        self._pending_inputs.clear()
        self._scan_monitors(now_s)
        if self.result is not None:  # a monitor ended the scene
            return self.result
        self._run_until(now_s)
        if self.result is not None:  # a gate timeout ended the scene
            return self.result
        pose = self._pose_at(now_s)
        self._adapter.send_frame(
            project_channels(self._rig, pose), self._frame_interval_ms
        )
        if all(track.done for track in self._tracks) and not self._sources:
            self.result = SceneResult.FINISHED
        return self.result

    def post_event(self, name: str) -> None:
        """Deliver an inbound event to every gate waiting on it now.

        The event fires at the current scene-local time (the last
        ``advance``). Gates that are not yet waiting — or scenes that
        already ended — never see it (edge-triggered, no queue).
        """
        if self.result is not None:
            return
        for track in self._tracks:
            if track.done or not track.started or not track.request:
                continue
            if (
                track.request[0] == "gate"
                and track.request[1].event == name
                and track.gate_fired_s is None
            ):
                track.gate_fired_s = self._now_s

    def set_input(self, name: str, value: VariableValue) -> None:
        """Drive a declared input from outside the scene.

        Takes effect at the next tick boundary (the start of the next
        ``advance``) so mid-tick logic never observes an input change
        — the determinism twin of ``post_event``. Repeated calls for
        the same input before the tick keep the last value. Unknown
        input names and non-scalar values are typed runtime errors.
        """
        if name not in self._inputs:
            known = ", ".join(sorted(self._inputs)) or "none"
            raise SceneRuntimeError(
                f"unknown input {name!r} (inputs: {known})"
            )
        if not isinstance(value, (bool, int, float, str)):
            raise SceneRuntimeError(
                f"input {name!r} must be a boolean, number, or string, "
                f"got {value!r}"
            )
        self._pending_inputs[name] = value

    def stop(self) -> None:
        """E-stop the adapter and mark the run stopped. Idempotent."""
        self._adapter.stop()
        if self.result is None:
            self.result = SceneResult.STOPPED

    # Background monitors ---------------------------------------------------------

    def _scan_monitors(self, now_s: float) -> None:
        """FANUC BG Logic: every monitor, every tick, declaration
        order, before any main-sequence step of the tick.

        Edge-triggered: a monitor fires when its condition transitions
        false -> true and re-arms once the condition goes false again.
        ``end_scene`` e-stops the adapter and finishes the run with
        the monitor's result string; later monitors do not run.
        """
        for index, monitor in enumerate(self._scene.monitors):
            was_true = self._monitor_was_true[index]
            is_true = self._condition_holds(monitor.when)
            self._monitor_was_true[index] = is_true
            if not is_true or was_true:
                continue
            for action in monitor.do:
                if isinstance(action, SetAction):
                    self._apply_set(action)
                elif isinstance(action, EmitAction):
                    self._emit(action, now_s)
                else:  # EndSceneAction: stop all motion, end the run
                    self._adapter.stop()
                    self.result = action.result
                    return

    # Condition evaluation --------------------------------------------------------

    def _condition_holds(self, condition: Condition) -> bool:
        if isinstance(condition, CompareCondition):
            return self._compare(condition)
        if isinstance(condition, NotCondition):
            return not self._condition_holds(condition.operand)
        # Every operand is evaluated (no short-circuit) so a typing
        # error surfaces regardless of its siblings' values.
        results = [
            self._condition_holds(operand)
            for operand in condition.operands
        ]
        if isinstance(condition, AllCondition):
            return all(results)
        if isinstance(condition, AnyCondition):
            return any(results)
        return results[0] != results[1]  # xor: exactly one of two

    def _compare(self, leaf: CompareCondition) -> bool:
        if leaf.var is not None:
            left = self._variables[leaf.var]
        else:
            left = self._inputs[leaf.input]
        right = self._resolve_value(leaf.value)
        if leaf.op is CompareOp.EQ:
            return _scalar_equals(left, right)
        if leaf.op is CompareOp.NE:
            return not _scalar_equals(left, right)
        for side, operand in (("left", left), ("right", right)):
            if isinstance(operand, bool) or not isinstance(
                operand, (int, float)
            ):
                raise SceneRuntimeError(
                    f"{leaf.path}: ordering comparison "
                    f"{leaf.op.value!r} requires numbers on both sides; "
                    f"the {side} operand is {operand!r}"
                )
        if leaf.op is CompareOp.LT:
            return left < right
        if leaf.op is CompareOp.LE:
            return left <= right
        if leaf.op is CompareOp.GT:
            return left > right
        return left >= right

    # Scheduler -------------------------------------------------------------------

    def _spawn_track(
        self, actions: tuple[Action, ...], start_s: float
    ) -> _Track:
        track = _Track(
            self._run_sequence(actions, start_s),
            order=len(self._tracks),
            start_s=start_s,
        )
        self._tracks.append(track)
        return track

    def _run_until(self, now_s: float) -> None:
        """Execute every due step in (timestamp, track order) order."""
        while self.result is None:
            best_track: _Track | None = None
            best_key: tuple[float, int] | None = None
            for track in self._tracks:
                if track.done:
                    continue
                ready_s = self._ready_time(track)
                if ready_s is None or ready_s > now_s:
                    continue
                key = (ready_s, track.order)
                if best_key is None or key < best_key:
                    best_key, best_track = key, track
            if best_track is None or best_key is None:
                return
            self._step(best_track, best_key[0])

    def _ready_time(self, track: _Track) -> float | None:
        """When the track can next run, or None if it cannot yet."""
        if not track.started:
            return track.start_s
        kind = track.request[0]
        if kind == "sleep":
            return track.request[1]
        if kind == "gate":
            if track.gate_fired_s is not None:
                return track.gate_fired_s
            action: WaitForAction = track.request[1]
            if action.timeout_s is None:
                return None
            return track.request[2] + action.timeout_s
        if kind == "until":
            # Level-triggered: the condition is sampled at tick
            # granularity, so a satisfied gate resumes at the current
            # tick time — unless its deadline already passed at an
            # earlier moment, in which case the timeout wins.
            until: WaitUntilAction = track.request[1]
            deadline = (
                None
                if until.timeout_s is None
                else track.request[2] + until.timeout_s
            )
            if self._condition_holds(until.when):
                if deadline is not None and deadline < self._now_s:
                    return deadline
                return self._now_s
            return deadline
        # join: ready when every child track has finished.
        children: tuple[_Track, ...] = track.request[1]
        if all(child.done for child in children):
            return max(child.end_s for child in children)
        return None

    def _step(self, track: _Track, wake_s: float) -> None:
        if track.started:
            send_value = self._resume_value(track, wake_s)
        else:
            track.started = True
            send_value = None
        try:
            request = track.generator.send(send_value)
        except StopIteration as stop:
            track.done = True
            track.end_s = wake_s if stop.value is None else stop.value
            return
        except _EndSceneByTimeout:
            self.result = SceneResult.ENDED_BY_GATE_TIMEOUT
            return
        track.request = request
        track.gate_fired_s = None

    def _resume_value(self, track: _Track, wake_s: float) -> object:
        kind = track.request[0]
        if kind == "gate":
            return (wake_s, track.gate_fired_s is None)
        if kind == "until":
            # Mirrors _ready_time exactly (no step runs in between, so
            # both evaluations see identical state): satisfied at this
            # tick and not already past the deadline = passed.
            until: WaitUntilAction = track.request[1]
            deadline = (
                None
                if until.timeout_s is None
                else track.request[2] + until.timeout_s
            )
            timed_out = not self._condition_holds(until.when) or (
                deadline is not None and deadline < self._now_s
            )
            return (wake_s, timed_out)
        return wake_s

    # Action semantics -----------------------------------------------------------

    def _run_sequence(self, actions: tuple[Action, ...], start_s: float):
        now_s = start_s
        for action in actions:
            now_s = yield from self._run_action(action, now_s)
        return now_s

    def _run_action(self, action: Action, now_s: float):
        if isinstance(action, ClipAction):
            source = _ClipSource(
                self._rig.clips[action.name],
                now_s,
                action.speed,
                action.duration_s,
            )
            self._sources.append(source)
            if action.wait:
                now_s = yield ("sleep", source.end_s)
            return now_s
        if isinstance(action, PoseAction):
            end_values = _pose_model_values(action, self._rig, self._driven)
            start_values = {
                target: self._value_of(target, now_s)
                for target in end_values
            }
            source = _PoseSource(
                start_values, end_values, now_s, action.duration_s
            )
            self._sources.append(source)
            return (yield ("sleep", source.end_s))
        if isinstance(action, WaitAction):
            return (yield ("sleep", now_s + action.seconds))
        if isinstance(action, WaitForAction):
            fired_s, timed_out = yield ("gate", action, now_s)
            if timed_out and action.on_timeout is TimeoutPolicy.END:
                raise _EndSceneByTimeout(action.path)
            return fired_s
        if isinstance(action, WaitUntilAction):
            if self._condition_holds(action.when):
                return now_s  # already true the moment the action starts
            passed_s, timed_out = yield ("until", action, now_s)
            if timed_out and action.on_timeout is TimeoutPolicy.END:
                raise _EndSceneByTimeout(action.path)
            return passed_s
        if isinstance(action, SetAction):
            self._apply_set(action)
            return now_s
        if isinstance(action, IfAction):
            if action.when is not None:
                taken = self._condition_holds(action.when)
            else:
                taken = self._variable_equals(action.var, action.equals)
            branch = action.then if taken else action.orelse
            return (yield from self._run_sequence(branch, now_s))
        if isinstance(action, SelectAction):
            value = self._variables[action.var]
            for case in action.cases:
                if _scalar_equals(value, case.equals):
                    return (yield from self._run_sequence(case.then, now_s))
            return (yield from self._run_sequence(action.default, now_s))
        if isinstance(action, CallAction):
            return (
                yield from self._run_sequence(
                    self._scene.subroutines[action.name], now_s
                )
            )
        if isinstance(action, LoopAction):
            if action.count is not None:
                for _ in range(action.count):
                    now_s = yield from self._run_sequence(action.body, now_s)
                return now_s
            while self._while_true(action):
                iteration_start_s = now_s
                now_s = yield from self._run_sequence(action.body, now_s)
                if now_s == iteration_start_s and self._while_true(action):
                    raise SceneRuntimeError(
                        f"{action.path}: while_var loop iteration consumed "
                        f"no time and {action.while_var!r} is still true — "
                        f"this loop can never finish"
                    )
            return now_s
        if isinstance(action, ParallelAction):
            children = tuple(
                self._spawn_track(track_actions, now_s)
                for track_actions in action.tracks
            )
            return (yield ("join", children))
        if isinstance(action, EmitAction):
            self._emit(action, now_s)
            return now_s
        raise AssertionError(f"unhandled action type: {action!r}")

    def _apply_set(self, action: SetAction) -> None:
        self._variables[action.var] = self._resolve_value(action.value)

    def _emit(self, action: EmitAction, now_s: float) -> None:
        self._emitted.append(EmittedEvent(name=action.name, time_s=now_s))
        if self._on_event is not None:
            self._on_event(action.name, now_s)

    def _resolve_value(self, value: VariableValue) -> VariableValue:
        # A string naming a declared variable is a reference; anything
        # else is the literal itself (expression arithmetic is a
        # documented ceiling — see the module docstring).
        if isinstance(value, str) and value in self._variables:
            return self._variables[value]
        return value

    def _variable_equals(self, name: str, literal: VariableValue) -> bool:
        return _scalar_equals(self._variables[name], literal)

    def _while_true(self, action: LoopAction) -> bool:
        value = self._variables[action.while_var]
        if not isinstance(value, bool):
            raise SceneRuntimeError(
                f"{action.path}: while_var {action.while_var!r} must hold "
                f"a boolean, got {value!r}"
            )
        return value

    # Pose evaluation -------------------------------------------------------------

    def _settle(self, time_s: float) -> None:
        """Fold every source finished by ``time_s`` into the held state.

        Finished sources apply in (end time, start order) order so the
        most recent motion wins a contested target.
        """
        finished: list[tuple[float, int, _MotionSource]] = []
        remaining: list[_MotionSource] = []
        for index, source in enumerate(self._sources):
            if source.end_s <= time_s:
                finished.append((source.end_s, index, source))
            else:
                remaining.append(source)
        if not finished:
            return
        for _, _, source in sorted(finished, key=lambda item: item[:2]):
            self._held.update(source.values_at(source.end_s))
        self._sources = remaining

    def _value_of(self, target: str, time_s: float) -> float:
        """A target's current value: held state overridden by active
        sources in start order."""
        self._settle(time_s)
        value = self._held[target]
        for source in self._sources:
            source_values = source.values_at(time_s)
            if target in source_values:
                value = source_values[target]
        return value

    def _pose_at(self, time_s: float) -> Pose:
        self._settle(time_s)
        values = dict(self._held)
        for source in self._sources:
            values.update(source.values_at(time_s))
        paths = self._rig.dof_paths()
        dof_values = {
            path: values.get(path, dof.neutral)
            for path, dof in paths.items()
        }
        # Mirrors the relation stage of rig.evaluate_pose, which is
        # bound to a single named clip; a scene composes several motion
        # sources, so the merged values re-enter the same relation math
        # (report violations, never clamp) here.
        violations: list[LimitViolation] = []
        for relation in self._relations_ordered:
            driven_value = (
                relation.ratio * dof_values[relation.driver] + relation.offset
            )
            dof_values[relation.driven] = driven_value
            dof = paths[relation.driven]
            if dof.has_limits and not (
                dof.minimum <= driven_value <= dof.maximum
            ):
                violations.append(
                    LimitViolation(
                        dof_path=relation.driven,
                        value=driven_value,
                        min_value=dof.minimum,
                        max_value=dof.maximum,
                    )
                )
        return Pose(
            dof_values=dof_values,
            parameter_values={
                name: values[name] for name in self._rig.parameters
            },
            limit_violations=tuple(violations),
        )


# Primitive validators ----------------------------------------------------------


def _scalar_equals(left: VariableValue, right: VariableValue) -> bool:
    """The scene equality discipline: same-kind values only.

    Booleans are their own kind (``true != 1``); numbers compare
    numerically across int/float; mismatched kinds are simply unequal.
    """
    if isinstance(left, bool) != isinstance(right, bool):
        return False
    return left == right


def _mapping(value: object, path: str) -> dict:
    if not isinstance(value, dict):
        raise SceneFormatError(
            path, f"expected a mapping, got {type(value).__name__}"
        )
    return value


def _string(value: object, path: str) -> str:
    if not isinstance(value, str):
        raise SceneFormatError(path, f"expected a string, got {value!r}")
    return value


def _number(value: object, path: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise SceneFormatError(path, f"expected a number, got {value!r}")
    return float(value)


def _int(value: object, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise SceneFormatError(path, f"expected an integer, got {value!r}")
    return value


def _bool(value: object, path: str) -> bool:
    if not isinstance(value, bool):
        raise SceneFormatError(path, f"expected true/false, got {value!r}")
    return value


def _variable_value(value: object, path: str) -> VariableValue:
    if isinstance(value, (bool, int, float, str)):
        return value
    raise SceneFormatError(
        path, f"expected a boolean, number, or string, got {value!r}"
    )


def _reject_unknown_fields(raw: dict, path: str, allowed: set[str]) -> None:
    for key in raw:
        if key not in allowed:
            raise SceneFormatError(f"{path}.{key}", "unknown field")
