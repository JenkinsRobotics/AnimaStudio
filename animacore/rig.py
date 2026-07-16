"""Mechanism rig runtime model: parts, typed joints, DOF, projection.

The Python mirror of the `.character.anima` structure semantics for
headless playback. A rig is a mechanism: rigid ``Part``s connected by
typed ``Joint``s (mates, in the Onshape sense), where the joint type
alone defines the set of ``DegreeOfFreedom`` being controlled. Clips
target DOF by path (``"<joint_name>.<dof_name>"``) and generic 0..1
``Parameter``s by name; every unanimated target falls back to its
neutral — empty or missing tracks are legal at rig level. Per-track
hold/linear interpolation is reused from ``animacore.tracks``;
``project_channels`` is the B04 seam mapping evaluated DOF/parameter
values to the normalized 0..1 channels ``wire.encode_frm`` takes. Rigs
come from ``.character.anima`` files via ``animacore.loader``.

Kinematics (per ``dev/docs/roadmap/Kinematics.md``): per-DOF limits are
optional — an unlimited DOF (a wheel) is legal and never clamped, but
it cannot be mapped to a bounded output channel. ``Relation`` couples
exactly two DOF linearly (gear / rack_pinion / screw / linear);
``evaluate_pose`` resolves drivers from the clip, applies relations in
dependency order, and reports (never clamps) driven values outside
their limits as ``Pose.limit_violations``; ``project_channels`` raises
``LimitViolationError`` for a mapped violated DOF so hardware refuses
to arm.

Design rule: this module is mechanism-generic. Domain vocabulary —
character, face, vehicle, or any other application naming — lives only
in author data such as the files under ``examples/``.
"""

from __future__ import annotations

import math
from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import StrEnum

from animacore.mates import (
    JOINT_TYPE_DOF_TEMPLATES,
    DegreeOfFreedom,
    DofKind,
    JointType,
    MateConnector,
    MateControls,
    MateOffset,
    RotationAxis,
    RotationDof,
    SecondaryAxisRotation,
    TranslationDof,
    all_mate_type_schemas,
    describe_mate,
    mate_type_schema,
)
from animacore.tracks import Clip, evaluate_clip

# The mate-authoring vocabulary lives in ``animacore.mates``; rig.py
# re-exports it so ``from animacore.rig import JointType`` (and the
# other typed-mate names) keeps working.
__all__ = [
    "JOINT_TYPE_DOF_TEMPLATES",
    "DegreeOfFreedom",
    "DofKind",
    "JointType",
    "MateConnector",
    "MateControls",
    "MateOffset",
    "RotationAxis",
    "RotationDof",
    "SecondaryAxisRotation",
    "TranslationDof",
    "all_mate_type_schemas",
    "describe_mate",
    "mate_type_schema",
    "Part",
    "Joint",
    "Parameter",
    "OutputMapping",
    "RelationKind",
    "RELATION_KIND_DOF_KINDS",
    "RELATION_DISPLAY_KEYS",
    "Relation",
    "relations_in_dependency_order",
    "RigClip",
    "Identity",
    "Rig",
    "LimitViolation",
    "LimitViolationError",
    "Pose",
    "evaluate_pose",
    "project_channels",
]


@dataclass(frozen=True)
class Part:
    """A rigid body in the mechanism.

    ``model_node`` optionally references a node path inside an imported
    model; it is opaque data the runtime stores but never interprets.
    ``parent`` is optional assembly-tree metadata; kinematic
    connectivity is carried by ``Joint``, not here.
    """

    name: str
    parent: str | None = None
    model_node: str | None = None
    description: str = ""

    def __post_init__(self) -> None:
        if not self.name:
            raise ValueError("part name must not be empty")
        if self.parent == self.name:
            raise ValueError(f"part {self.name!r} cannot be its own parent")


@dataclass(frozen=True)
class Joint:
    """A typed mate connecting a child part to a parent part.

    The joint type defines the DOF set (count, kinds, order — see
    ``JOINT_TYPE_DOF_TEMPLATES``); ``dofs`` supplies the named
    instances. A DOF list whose kinds do not match the type is
    rejected. Each DOF is addressable as ``"<joint_name>.<dof_name>"``.

    ``id`` is a stable tracking identity (e.g. ``"Fastened 33"``),
    distinct from the editable ``name`` and preserved verbatim — empty
    is allowed (the app assigns it). ``controls`` carries the universal
    connector/offset/flip/orient controls (``MateControls``); the
    as-mated offset lives at ``controls.offset``. The headless runtime
    round-trips connectors and offsets without spatial math.
    """

    name: str
    joint_type: JointType
    parent_part: str
    child_part: str
    dofs: tuple[DegreeOfFreedom, ...] = ()
    description: str = ""
    id: str = ""
    controls: MateControls | None = None

    def __post_init__(self) -> None:
        object.__setattr__(self, "dofs", tuple(self.dofs))
        if not self.name:
            raise ValueError("joint name must not be empty")
        if "." in self.name:
            raise ValueError(f"joint name must not contain '.': {self.name!r}")
        if self.parent_part == self.child_part:
            raise ValueError(
                f"joint {self.name!r} connects part "
                f"{self.parent_part!r} to itself"
            )
        template_kinds = tuple(
            kind for _, kind, _ in JOINT_TYPE_DOF_TEMPLATES[self.joint_type]
        )
        dof_kinds = tuple(dof.kind for dof in self.dofs)
        if dof_kinds != template_kinds:
            raise ValueError(
                f"joint {self.name!r} of type {self.joint_type.value!r} "
                f"must have dof kinds "
                f"({', '.join(template_kinds) or 'none'}), got "
                f"({', '.join(dof_kinds) or 'none'})"
            )
        names = [dof.name for dof in self.dofs]
        if len(names) != len(set(names)):
            raise ValueError(f"joint {self.name!r} has duplicate dof names")

    def dof_paths(self) -> dict[str, DegreeOfFreedom]:
        """This joint's DOF keyed by ``"<joint_name>.<dof_name>"`` path."""
        return {f"{self.name}.{dof.name}": dof for dof in self.dofs}


@dataclass(frozen=True)
class Parameter:
    """A named generic scalar channel, always normalized 0.0..1.0.

    The rig model gives parameters no further meaning; what one drives
    (a display weight, a lamp intensity, ...) is the author's business.
    """

    name: str
    neutral_value: float = 0.0
    description: str = ""

    def __post_init__(self) -> None:
        if not self.name:
            raise ValueError("parameter name must not be empty")
        if "." in self.name:
            raise ValueError(
                f"parameter name must not contain '.': {self.name!r}"
            )
        if not 0.0 <= self.neutral_value <= 1.0:
            raise ValueError(
                f"parameter {self.name!r} neutral outside 0..1: "
                f"{self.neutral_value}"
            )


@dataclass(frozen=True)
class OutputMapping:
    """Evaluated target value → normalized wire channel value (B04 seam).

    ``target`` is a DOF path (``"<joint_name>.<dof_name>"``) or a
    parameter name. ``value_at_zero`` / ``value_at_one`` are the target
    values — in the target's native units: radians for a rotation DOF,
    meters for a translation DOF, unitless 0..1 for a parameter — that
    map to channel values 0.0 and 1.0; a descending pair inverts the
    channel. Values outside the pair clamp to 0..1. Pulse widths, pins,
    and other hardware detail stay in the wire ``CFG`` layer, never
    here.
    """

    target: str
    channel: int
    value_at_zero: float
    value_at_one: float

    def __post_init__(self) -> None:
        if self.channel < 0:
            raise ValueError(f"channel must be >= 0: {self.channel}")
        if self.value_at_zero == self.value_at_one:
            raise ValueError(
                f"mapping for target {self.target!r} has zero span: "
                f"both ends are {self.value_at_zero}"
            )

    def channel_value(self, value: float) -> float:
        """Project a target value to the normalized 0..1 channel value."""
        span = self.value_at_one - self.value_at_zero
        normalized = (value - self.value_at_zero) / span
        return min(max(normalized, 0.0), 1.0)


class RelationKind(StrEnum):
    """The four linear DOF couplings (Kinematics.md §5)."""

    GEAR = "gear"
    RACK_PINION = "rack_pinion"
    SCREW = "screw"
    LINEAR = "linear"


# Each relation kind DEFINES its (driver kind, driven kind) pairing.
RELATION_KIND_DOF_KINDS: dict[RelationKind, tuple[DofKind, DofKind]] = {
    RelationKind.GEAR: (DofKind.ROTATION, DofKind.ROTATION),
    RelationKind.RACK_PINION: (DofKind.ROTATION, DofKind.TRANSLATION),
    RelationKind.SCREW: (DofKind.ROTATION, DofKind.TRANSLATION),
    RelationKind.LINEAR: (DofKind.TRANSLATION, DofKind.TRANSLATION),
}

# Non-semantic display fields a relation may carry per kind (teeth,
# lead, ...). They round-trip for UI display; ``ratio`` stays the one
# semantic value and no consistency between the two is enforced.
RELATION_DISPLAY_KEYS: dict[RelationKind, frozenset[str]] = {
    RelationKind.GEAR: frozenset({"driver_teeth", "driven_teeth"}),
    RelationKind.RACK_PINION: frozenset({"pinion_diameter_mm"}),
    RelationKind.SCREW: frozenset({"lead_mm_per_rev"}),
    RelationKind.LINEAR: frozenset(),
}


@dataclass(frozen=True)
class Relation:
    """A linear coupling between exactly two DOF (Kinematics.md §5).

    ``driven_value = ratio * driver_value + offset``, all in model
    units: ``ratio`` is driven model units per driver model unit
    (unitless for gear/linear, meters per radian for rack_pinion and
    screw) and ``offset`` is in the driven DOF's model units (radians
    or meters). ``driver`` and ``driven`` are DOF paths
    (``"<joint_name>.<dof_name>"``). The relation always computes —
    no collision detection, no clamping; limit handling for the driven
    DOF is violation reporting in ``evaluate_pose``.
    """

    kind: RelationKind
    driver: str
    driven: str
    ratio: float
    offset: float = 0.0
    display: Mapping[str, float] = field(default_factory=dict)

    def __post_init__(self) -> None:
        for role, path in (("driver", self.driver), ("driven", self.driven)):
            if "." not in path:
                raise ValueError(
                    f"relation {role} {path!r} must be a dof path "
                    f"(\"<joint_name>.<dof_name>\")"
                )
        if self.driver == self.driven:
            raise ValueError(
                f"relation cannot couple dof {self.driver!r} to itself"
            )
        if not math.isfinite(self.ratio) or self.ratio == 0.0:
            raise ValueError(
                f"relation {self.describe()} ratio must be a nonzero "
                f"finite number, got {self.ratio!r}"
            )
        if not math.isfinite(self.offset):
            raise ValueError(
                f"relation {self.describe()} offset must be finite, "
                f"got {self.offset!r}"
            )
        allowed = RELATION_DISPLAY_KEYS[self.kind]
        for key, value in self.display.items():
            if key not in allowed:
                valid = ", ".join(sorted(allowed)) or "none"
                raise ValueError(
                    f"relation {self.describe()} has unknown display "
                    f"field {key!r} for kind {self.kind.value!r} "
                    f"(expected: {valid})"
                )
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                raise ValueError(
                    f"relation {self.describe()} display field {key!r} "
                    f"must be a number, got {value!r}"
                )
            if value <= 0:
                raise ValueError(
                    f"relation {self.describe()} display field {key!r} "
                    f"must be > 0, got {value!r}"
                )

    def describe(self) -> str:
        """Stable human identity used in validation errors."""
        return f"{self.kind.value} {self.driver} -> {self.driven}"


def relations_in_dependency_order(
    relations: tuple[Relation, ...],
) -> tuple[Relation, ...]:
    """Order relations so every driver is resolved before its driven.

    Raises ``ValueError`` on a cycle. Deterministic: ready relations
    keep their declaration order (assumes at most one relation per
    driven DOF, which ``Rig`` validates).
    """
    pending = list(relations)
    pending_driven = {relation.driven for relation in pending}
    order: list[Relation] = []
    while pending:
        ready = [
            relation
            for relation in pending
            if relation.driver not in pending_driven
        ]
        if not ready:
            unresolved = ", ".join(
                relation.describe() for relation in pending
            )
            raise ValueError(
                f"relation graph has a cycle (unresolvable: {unresolved})"
            )
        for relation in ready:
            order.append(relation)
            pending.remove(relation)
            pending_driven.discard(relation.driven)
    return tuple(order)


@dataclass(frozen=True)
class RigClip:
    """A named clip plus its rig-level playback flags."""

    clip: Clip
    loop: bool = False


@dataclass(frozen=True)
class Identity:
    """Character identity metadata from the ``identity:`` section."""

    name: str
    display_name: str = ""
    description: str = ""
    version: str = ""
    author: str = ""


@dataclass(frozen=True)
class Rig:
    """A mechanism's movable structure: what a clip is evaluated against.

    Clip track keys are DOF paths (``"<joint_name>.<dof_name>"``) or
    parameter names, and every key must resolve to a declared DOF or
    parameter. Parameter names never contain ``.`` and DOF paths always
    do, so the two namespaces cannot collide.

    Relation rules (validated here): the graph is acyclic, at most one
    relation drives any DOF, a driven DOF carries no animation tracks
    (one source of truth), and each kind's (driver, driven) DOF-kind
    pairing must match ``RELATION_KIND_DOF_KINDS``. An output mapping
    may not target a DOF without limits — a bounded actuator channel
    needs a range to project to 0..1.
    """

    identity: Identity
    parts: Mapping[str, Part] = field(default_factory=dict)
    joints: Mapping[str, Joint] = field(default_factory=dict)
    parameters: Mapping[str, Parameter] = field(default_factory=dict)
    clips: Mapping[str, RigClip] = field(default_factory=dict)
    outputs: tuple[OutputMapping, ...] = ()
    relations: tuple[Relation, ...] = ()

    def __post_init__(self) -> None:
        object.__setattr__(self, "outputs", tuple(self.outputs))
        object.__setattr__(self, "relations", tuple(self.relations))
        for kind, items in (
            ("part", self.parts),
            ("joint", self.joints),
            ("parameter", self.parameters),
        ):
            for key, item in items.items():
                if key != item.name:
                    raise ValueError(
                        f"{kind} key {key!r} != name {item.name!r}"
                    )
        for part in self.parts.values():
            if part.parent is not None and part.parent not in self.parts:
                raise ValueError(
                    f"part {part.name!r} parent references undeclared part "
                    f"{part.parent!r}"
                )
        for joint in self.joints.values():
            for part_name in (joint.parent_part, joint.child_part):
                if part_name not in self.parts:
                    raise ValueError(
                        f"joint {joint.name!r} references undeclared part "
                        f"{part_name!r}"
                    )
        paths = self.dof_paths()
        driven_by: dict[str, Relation] = {}
        for relation in self.relations:
            expected = RELATION_KIND_DOF_KINDS[relation.kind]
            for role, path, expected_kind in (
                ("driver", relation.driver, expected[0]),
                ("driven", relation.driven, expected[1]),
            ):
                dof = paths.get(path)
                if dof is None:
                    raise ValueError(
                        f"relation {relation.describe()} {role} references "
                        f"undeclared dof {path!r}"
                    )
                if dof.kind is not expected_kind:
                    raise ValueError(
                        f"relation {relation.describe()} {role} must be a "
                        f"{expected_kind.value} dof, got {dof.kind.value} "
                        f"({path!r})"
                    )
            if relation.driven in driven_by:
                raise ValueError(
                    f"dof {relation.driven!r} is driven by two relations: "
                    f"{driven_by[relation.driven].describe()} and "
                    f"{relation.describe()} (at most one driver per dof)"
                )
            driven_by[relation.driven] = relation
        relations_in_dependency_order(self.relations)  # rejects cycles
        for clip_name, rig_clip in self.clips.items():
            for key in rig_clip.clip.tracks:
                if key not in paths and key not in self.parameters:
                    raise ValueError(
                        f"clip {clip_name!r} animates unknown target {key!r}"
                    )
                if key in driven_by:
                    raise ValueError(
                        f"clip {clip_name!r} animates {key!r}, which is "
                        f"driven by relation {driven_by[key].describe()}; "
                        f"a driven dof has one source of truth — remove "
                        f"the track or the relation"
                    )
        seen_channels: set[int] = set()
        for mapping in self.outputs:
            dof = paths.get(mapping.target)
            if dof is None and mapping.target not in self.parameters:
                raise ValueError(
                    f"output mapping references unknown target "
                    f"{mapping.target!r}"
                )
            if dof is not None and not dof.has_limits:
                raise ValueError(
                    f"output mapping on channel {mapping.channel} targets "
                    f"unlimited dof {mapping.target!r}: a bounded actuator "
                    f"channel needs a dof range to project to 0..1 — add "
                    f"limits to the dof or remove the mapping"
                )
            if mapping.channel in seen_channels:
                raise ValueError(f"duplicate output channel: {mapping.channel}")
            seen_channels.add(mapping.channel)

    def dof_paths(self) -> dict[str, DegreeOfFreedom]:
        """Every addressable DOF, keyed by ``"<joint_name>.<dof_name>"``."""
        paths: dict[str, DegreeOfFreedom] = {}
        for joint in self.joints.values():
            paths.update(joint.dof_paths())
        return paths


@dataclass(frozen=True)
class LimitViolation:
    """A relation-driven DOF evaluated outside its enabled limits.

    Values are in the DOF's native units (radians / meters). Per
    Kinematics.md §5 the relation always computes and nothing clamps —
    the violation is reported here, and ``project_channels`` refuses
    to project the violated DOF.
    """

    dof_path: str
    value: float
    min_value: float
    max_value: float


class LimitViolationError(ValueError):
    """Channel projection refused: a mapped DOF is outside its limits."""


@dataclass(frozen=True)
class Pose:
    """One evaluated rig state.

    ``dof_values`` is keyed by DOF path in each DOF's native units
    (radians for rotation, meters for translation); ``parameter_values``
    is keyed by parameter name, 0..1. ``limit_violations`` lists every
    relation-driven DOF whose computed value exited its enabled limits
    (in relation dependency order); it is empty for a rig without
    relations, because clip values are load-validated against limits
    and neutrals must lie within them.
    """

    dof_values: Mapping[str, float]
    parameter_values: Mapping[str, float]
    limit_violations: tuple[LimitViolation, ...] = ()


def evaluate_pose(
    rig: Rig, clip_name: str | None = None, time_seconds: float = 0.0
) -> Pose:
    """Evaluate the rig at ``time_seconds``, deterministically.

    ``clip_name`` selects one of ``rig.clips``; ``None`` gives the
    neutral pose. Every DOF or parameter the clip does not animate
    falls back to its neutral. Looping clips wrap time modulo the
    duration; non-looping clips clamp.

    Order per Kinematics.md §5: driver DOF resolve from the clip (or
    neutral), relations apply in dependency order, then limits — a
    driven value outside its enabled limits is reported in
    ``Pose.limit_violations``, never clamped.
    """
    animated: Mapping[int | str, float] = {}
    if clip_name is not None:
        rig_clip = rig.clips.get(clip_name)
        if rig_clip is None:
            raise KeyError(f"rig has no clip named {clip_name!r}")
        duration_seconds = rig_clip.clip.duration_seconds
        if rig_clip.loop and duration_seconds > 0:
            time_seconds = time_seconds % duration_seconds
        animated = evaluate_clip(rig_clip.clip, time_seconds)

    paths = rig.dof_paths()
    dof_values = {
        path: animated.get(path, dof.neutral) for path, dof in paths.items()
    }
    violations: list[LimitViolation] = []
    for relation in relations_in_dependency_order(rig.relations):
        driven_value = (
            relation.ratio * dof_values[relation.driver] + relation.offset
        )
        dof_values[relation.driven] = driven_value
        dof = paths[relation.driven]
        if dof.has_limits and not dof.minimum <= driven_value <= dof.maximum:
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
            name: animated.get(name, parameter.neutral_value)
            for name, parameter in rig.parameters.items()
        },
        limit_violations=tuple(violations),
    )


def project_channels(rig: Rig, pose: Pose) -> dict[int, float]:
    """Project a pose's mapped targets to normalized 0..1 channel values.

    The result is exactly what ``wire.encode_frm`` takes. Unmapped DOF
    and parameters are omitted. A mapping whose target is in
    ``pose.limit_violations`` raises ``LimitViolationError`` — hardware
    must refuse to arm on a violated pose, never clamp it.
    """
    violated = {
        violation.dof_path: violation
        for violation in pose.limit_violations
    }
    channels: dict[int, float] = {}
    for mapping in rig.outputs:
        violation = violated.get(mapping.target)
        if violation is not None:
            raise LimitViolationError(
                f"channel {mapping.channel} target {mapping.target!r} is "
                f"outside its limits ({violation.value} not in "
                f"[{violation.min_value}, {violation.max_value}]); "
                f"refusing to project a violated dof to hardware"
            )
        if "." in mapping.target:
            value = pose.dof_values[mapping.target]
        else:
            value = pose.parameter_values[mapping.target]
        channels[mapping.channel] = mapping.channel_value(value)
    return channels
