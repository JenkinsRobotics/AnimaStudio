"""Studio ↔ AnimaCore bridge: the stdio helper that makes AnimaCore the
single canonical engine and the Swift app a front end.

Newline-delimited JSON over the helper's stdio (``python -m
animacore.bridge``). The app spawns the helper once and keeps it alive
for the session; every rig/pose/frame *meaning* is answered here, never
reimplemented in Swift. Protocol: ``dev/docs/roadmap/Studio_Bridge.md``.

The protocol logic is a pure ``handle_request(session, request) ->
response`` over parsed dicts, so it is unit-testable without real stdio;
``main`` is the thin newline-JSON loop around it. A protocol or format
error is reported as an ``{ok: false, error: {...}}`` envelope — the
loop never crashes on bad input; only a truly unexpected error
propagates.
"""

from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass, field
from typing import IO

import yaml

from animacore import __version__ as ENGINE_VERSION
from animacore.kinematics import resolve_pose, transform_to_json
from animacore.loader import CharacterFormatError, parse_character
from animacore.mates import (
    DofKind,
    JointType,
    MateConnector,
    MateControls,
    MateOffset,
    RotationAxis,
    RotationDof,
    TangentSpec,
    TranslationDof,
    all_mate_type_schemas,
    describe_mate,
)
from animacore.rig import (
    Identity,
    Joint,
    LimitViolationError,
    OutputMapping,
    Parameter,
    Part,
    Relation,
    RelationKind,
    Rig,
    RigClip,
    all_relation_type_schemas,
    describe_relation,
    evaluate_pose,
    project_channels,
)
from animacore.scene import SceneFormatError, parse_scene
from animacore.serialize import rig_to_yaml, scene_to_yaml
from animacore.tracks import Clip, Interpolation, Keyframe, Track

PROTOCOL_VERSION = 1
ENGINE_NAME = "animacore"

# The BR1 vertical-slice verbs — also the ``hello`` capabilities list.
CAPABILITIES = [
    "hello",
    "load_character",
    "validate_character",
    "evaluate",
    "resolve_pose",
    "mate_types",
    "relation_types",
    "serialize_character",
    "serialize_scene",
    "release",
    "shutdown",
]


@dataclass
class Session:
    """Long-lived helper state: rigs loaded by deterministic handle.

    Handles are ``"rig1"``, ``"rig2"``, … from a monotonic counter — no
    randomness/uuid, so a client transcript is reproducible. ``exit`` is
    set by ``shutdown`` and read by the stdio loop.
    """

    _rigs: dict[str, Rig] = field(default_factory=dict)
    _counter: int = 0
    exit: bool = False

    def add(self, rig: Rig) -> str:
        self._counter += 1
        handle = f"rig{self._counter}"
        self._rigs[handle] = rig
        return handle

    def get(self, handle: str) -> Rig | None:
        return self._rigs.get(handle)

    def drop(self, handle: str) -> bool:
        return self._rigs.pop(handle, None) is not None


# Envelope helpers ------------------------------------------------------------


def _ok(request_id: object, result: dict) -> dict:
    return {"id": request_id, "ok": True, "result": result}


def _error(
    request_id: object, code: str, message: str, path: str | None = None
) -> dict:
    return {
        "id": request_id,
        "ok": False,
        "error": {"code": code, "message": message, "path": path},
    }


class _BadRequest(Exception):
    """A malformed/mistyped request field; becomes a ``bad_request``."""


def _require_str(params: dict, key: str) -> str:
    value = params.get(key)
    if not isinstance(value, str):
        raise _BadRequest(f"{key!r} must be a string")
    return value


# Rig → summary DTOs (what Swift mirrors, never redefines) --------------------


def _rig_summary(rig: Rig) -> dict:
    """The ``load_character`` result's ``rig`` block (spec shapes).

    Each joint entry is ``describe_mate(joint)`` — the consistent
    per-mate hook carrying the stable id, the full universal controls,
    and the DOF paths + limits (``min``/``max`` null for an unlimited
    DOF). Each relation entry is ``describe_relation(relation)`` — the
    per-instance relation hook (signed ratio, reverse flag, kind-specific
    ratio field value); empty for a rig without relations.

    **Full-fidelity enrichment (additive).** So ``serialize_character``
    can reconstruct the rig losslessly from exactly this DTO, the summary
    carries a few fields beyond the spec shapes — all *added*, none
    renamed/removed, so existing consumers are unaffected:
    ``describe_mate`` gains a joint ``description`` and, per DOF, its
    ``name``, per-DOF ``axis_vector`` (the file's ``axis:`` list, null
    when absent — distinct from the template ``axis`` string) and
    ``description``; each clip gains ``keyframes`` (the per-time keyframe
    entries in native units); each output gains ``value_at_zero`` /
    ``value_at_one`` (the mapping range in native units).
    """
    identity = rig.identity
    joints = [_joint_summary(joint) for joint in rig.joints.values()]
    return {
        "identity": {
            "name": identity.name,
            "display_name": identity.display_name,
            "description": identity.description,
            "version": identity.version,
            "author": identity.author,
        },
        "parts": [
            {
                "name": part.name,
                "parent": part.parent,
                "model_node": part.model_node,
                "description": part.description,
                "model": part.model,
                "suppressed": part.suppressed,
                "grounded": part.grounded,
            }
            for part in rig.parts.values()
        ],
        "joints": joints,
        "parameters": [
            {
                "name": parameter.name,
                "neutral": parameter.neutral_value,
                "description": parameter.description,
            }
            for parameter in rig.parameters.values()
        ],
        "clips": [
            {
                "name": rig_clip.clip.name,
                "duration_s": rig_clip.clip.duration_seconds,
                "loop": rig_clip.loop,
                "keyframes": _clip_keyframes(rig_clip.clip),
            }
            for rig_clip in rig.clips.values()
        ],
        "outputs": [
            {
                "dof_path": mapping.target,
                "channel": mapping.channel,
                "value_at_zero": mapping.value_at_zero,
                "value_at_one": mapping.value_at_one,
            }
            for mapping in rig.outputs
        ],
        "relations": [
            describe_relation(relation) for relation in rig.relations
        ],
    }


def _joint_summary(joint: Joint) -> dict:
    """``describe_mate`` plus the additive full-fidelity fields that make
    the summary a lossless serialize input (see ``_rig_summary``)."""
    described = describe_mate(joint)
    described["description"] = joint.description
    dof_by_path = {
        f"{joint.name}.{dof.name}": dof for dof in joint.dofs
    }
    for dof_entry in described.get("dofs", []):
        dof = dof_by_path[dof_entry["path"]]
        dof_entry["name"] = dof.name
        dof_entry["axis_vector"] = (
            None if dof.axis is None else list(dof.axis)
        )
        dof_entry["description"] = dof.description
    return described


def _clip_keyframes(clip: Clip) -> list:
    """One clip's tracks inverted into per-time keyframe entries in native
    units (radians/metres/0..1) — the lossless serialize input.

    All targets keyed at one time share that entry's interpolation, which
    is how the file/loader builds them, so grouping by time is lossless.
    """
    grouped: dict[float, dict] = {}
    for target, track in clip.tracks.items():
        for keyframe in track.keyframes:
            bucket = grouped.setdefault(
                keyframe.time_seconds,
                {
                    "interpolation": keyframe.interpolation.value,
                    "values": {},
                },
            )
            bucket["values"][str(target)] = keyframe.value
    return [
        {
            "time_s": time_seconds,
            "interpolation": grouped[time_seconds]["interpolation"],
            "values": grouped[time_seconds]["values"],
        }
        for time_seconds in sorted(grouped)
    ]


def _projectable_channels(rig: Rig, pose) -> dict[int, float]:
    """``project_channels`` but never fails on a limit violation.

    On the common path this is exactly ``project_channels`` (a faithful
    passthrough of the canonical projection). When a mapped DOF is in
    ``pose.limit_violations`` the canonical call raises; per the spec
    ``evaluate`` reports the violation rather than failing, so the
    violated channel is omitted and the rest still project.
    """
    try:
        return project_channels(rig, pose)
    except LimitViolationError:
        violated = {v.dof_path for v in pose.limit_violations}
        channels: dict[int, float] = {}
        for mapping in rig.outputs:
            if mapping.target in violated:
                continue
            if "." in mapping.target:
                value = pose.dof_values[mapping.target]
            else:
                value = pose.parameter_values[mapping.target]
            channels[mapping.channel] = mapping.channel_value(value)
        return channels


# Rig DTO → Rig (the serialize_character input adapter) ----------------------
#
# The inverse of ``_rig_summary``: rebuild a ``Rig`` from the exact,
# enriched DTO ``load_character`` returns. The DTO is already in native
# units (radians/metres/0..1), like the model, so reconstruction is a
# direct structural mapping with no unit conversion — that keeps the
# bridge round-trip exact. ``serialize_character`` then hands the rebuilt
# rig to ``rig_to_yaml``. A malformed DTO raises (KeyError/ValueError/
# TypeError), which the verb reports as a ``format_error``.


def rig_from_dict(dto: dict) -> Rig:
    """Reconstruct a validated ``Rig`` from a ``load_character`` rig DTO."""
    identity = _identity_from_dto(dto["identity"])
    parts = {
        entry["name"]: Part(
            name=entry["name"],
            parent=entry.get("parent"),
            model_node=entry.get("model_node"),
            description=entry.get("description", ""),
            model=entry.get("model", ""),
            suppressed=entry.get("suppressed", False),
            grounded=entry.get("grounded", False),
        )
        for entry in dto.get("parts", [])
    }
    joints = {
        entry["name"]: _joint_from_dto(entry) for entry in dto.get("joints", [])
    }
    parameters = {
        entry["name"]: Parameter(
            name=entry["name"],
            neutral_value=entry.get("neutral", 0.0),
            description=entry.get("description", ""),
        )
        for entry in dto.get("parameters", [])
    }
    dof_paths: dict[str, object] = {}
    for joint in joints.values():
        dof_paths.update(joint.dof_paths())
    clips = {
        entry["name"]: _clip_from_dto(entry, dof_paths, parameters)
        for entry in dto.get("clips", [])
    }
    outputs = tuple(
        OutputMapping(
            target=entry["dof_path"],
            channel=entry["channel"],
            value_at_zero=entry["value_at_zero"],
            value_at_one=entry["value_at_one"],
        )
        for entry in dto.get("outputs", [])
    )
    relations = tuple(
        Relation(
            kind=RelationKind(entry["kind"]),
            driver=entry["driver"],
            driven=entry["driven"],
            ratio=entry["ratio"],
            offset=entry.get("offset", 0.0),
            display=dict(entry.get("display", {})),
            suppressed=entry.get("suppressed", False),
        )
        for entry in dto.get("relations", [])
    )
    return Rig(
        identity=identity,
        parts=parts,
        joints=joints,
        parameters=parameters,
        clips=clips,
        outputs=outputs,
        relations=relations,
    )


def _identity_from_dto(dto: dict) -> Identity:
    return Identity(
        name=dto["name"],
        display_name=dto.get("display_name", ""),
        description=dto.get("description", ""),
        version=dto.get("version", ""),
        author=dto.get("author", ""),
    )


def _joint_from_dto(dto: dict) -> Joint:
    joint_type = JointType(dto["type"])
    if joint_type is JointType.TANGENT:
        tangent_dto = dto["tangent"]
        return Joint(
            name=dto["name"],
            joint_type=joint_type,
            parent_part=dto["parent_part"],
            child_part=dto["child_part"],
            id=dto.get("id", ""),
            description=dto.get("description", ""),
            tangent=TangentSpec(
                selection_a=tangent_dto["selection_a"],
                selection_b=tangent_dto["selection_b"],
                propagation=tangent_dto.get("propagation", True),
            ),
            suppressed=dto.get("suppressed", False),
        )
    dofs = tuple(_dof_from_dto(entry) for entry in dto.get("dofs", []))
    return Joint(
        name=dto["name"],
        joint_type=joint_type,
        parent_part=dto["parent_part"],
        child_part=dto["child_part"],
        dofs=dofs,
        id=dto.get("id", ""),
        description=dto.get("description", ""),
        controls=_controls_from_dto(dto.get("controls")),
        suppressed=dto.get("suppressed", False),
    )


def _dof_from_dto(dto: dict):
    axis = dto.get("axis_vector")
    axis = None if axis is None else tuple(axis)
    description = dto.get("description", "")
    if DofKind(dto["kind"]) is DofKind.ROTATION:
        return RotationDof(
            name=dto["name"],
            min_radians=dto.get("min"),
            max_radians=dto.get("max"),
            neutral_radians=dto.get("neutral", 0.0),
            axis=axis,
            description=description,
        )
    return TranslationDof(
        name=dto["name"],
        min_meters=dto.get("min"),
        max_meters=dto.get("max"),
        neutral_meters=dto.get("neutral", 0.0),
        axis=axis,
        description=description,
    )


def _controls_from_dto(dto: dict | None) -> MateControls | None:
    if dto is None:
        return None
    connectors = dto.get("connectors", {})
    offset = dto.get("offset", {})
    return MateControls(
        connector_a=_connector_from_dto(connectors.get("a")),
        connector_b=_connector_from_dto(connectors.get("b")),
        offset=MateOffset(
            enabled=offset.get("enabled", False),
            translation_m=tuple(offset.get("translation_m", (0.0, 0.0, 0.0))),
            rotation_axis=RotationAxis(offset.get("rotation_axis", "z")),
            rotation_radians=offset.get("rotation_radians", 0.0),
        ),
        flip_primary_axis=dto.get("flip_primary_axis", False),
        secondary_axis_rotation_deg=dto.get("secondary_axis_rotation_deg", 0),
        simulation_connection=dto.get("simulation_connection", True),
    )


def _connector_from_dto(dto: dict | None) -> MateConnector | None:
    if dto is None:
        return None
    return MateConnector(
        part=dto["part"],
        origin_m=tuple(dto.get("origin_m", (0.0, 0.0, 0.0))),
        primary_axis=tuple(dto.get("primary_axis", (0.0, 0.0, 1.0))),
        secondary_axis=tuple(dto.get("secondary_axis", (1.0, 0.0, 0.0))),
        flipped=dto.get("flipped", False),
        feature=dto.get("feature", ""),
    )


def _clip_from_dto(
    dto: dict, dof_paths: dict, parameters: dict
) -> RigClip:
    per_target: dict[str, list[Keyframe]] = {}
    for entry in dto.get("keyframes", []):
        interpolation = Interpolation(entry.get("interpolation", "linear"))
        for target, value in entry["values"].items():
            per_target.setdefault(target, []).append(
                Keyframe(
                    time_seconds=entry["time_s"],
                    value=value,
                    interpolation=interpolation,
                )
            )
    tracks: dict[int | str, Track] = {}
    for target, keyframes in per_target.items():
        minimum, maximum = _dto_target_bounds(target, dof_paths, parameters)
        tracks[target] = Track(
            keyframes=tuple(keyframes),
            minimum_value=minimum,
            maximum_value=maximum,
        )
    return RigClip(
        clip=Clip(
            name=dto["name"],
            duration_seconds=dto["duration_s"],
            tracks=tracks,
        ),
        loop=dto.get("loop", False),
    )


def _dto_target_bounds(
    target: str, dof_paths: dict, parameters: dict
) -> tuple[float, float]:
    dof = dof_paths.get(target)
    if dof is not None:
        if not dof.has_limits:
            return -math.inf, math.inf
        return dof.minimum, dof.maximum
    return 0.0, 1.0


# Verbs -----------------------------------------------------------------------


def _hello(session: Session, params: dict, request_id: object) -> dict:
    client_version = params.get("protocol_version")
    if not isinstance(client_version, int) or isinstance(client_version, bool):
        raise _BadRequest("'protocol_version' must be an integer")
    if client_version != PROTOCOL_VERSION:
        return _error(
            request_id,
            "protocol_mismatch",
            f"client speaks protocol {client_version}, engine speaks "
            f"{PROTOCOL_VERSION}",
        )
    return _ok(
        request_id,
        {
            "engine": ENGINE_NAME,
            "engine_version": ENGINE_VERSION,
            "protocol_version": PROTOCOL_VERSION,
            "capabilities": list(CAPABILITIES),
        },
    )


def _load_character(session: Session, params: dict, request_id: object) -> dict:
    text = _require_str(params, "text")
    try:
        rig = parse_character(text)
    except CharacterFormatError as error:
        return _error(request_id, "format_error", error.message, error.path)
    handle = session.add(rig)
    return _ok(request_id, {"handle": handle, "rig": _rig_summary(rig)})


def _validate_character(
    session: Session, params: dict, request_id: object
) -> dict:
    text = _require_str(params, "text")
    try:
        parse_character(text)
    except CharacterFormatError as error:
        return _ok(
            request_id,
            {
                "diagnostics": [
                    {
                        "code": "format_error",
                        "message": error.message,
                        "path": error.path,
                    }
                ]
            },
        )
    return _ok(request_id, {"diagnostics": []})


def _evaluate(session: Session, params: dict, request_id: object) -> dict:
    handle = _require_str(params, "handle")
    rig = session.get(handle)
    if rig is None:
        return _error(
            request_id, "unknown_handle", f"no rig loaded as {handle!r}"
        )
    clip = params.get("clip")
    if clip is not None and not isinstance(clip, str):
        raise _BadRequest("'clip' must be a string or null")
    time_s = params.get("time_s", 0.0)
    if isinstance(time_s, bool) or not isinstance(time_s, (int, float)):
        raise _BadRequest("'time_s' must be a number")
    try:
        pose = evaluate_pose(rig, clip, float(time_s))
    except KeyError:
        raise _BadRequest(f"rig {handle!r} has no clip named {clip!r}")
    channels = _projectable_channels(rig, pose)
    return _ok(
        request_id,
        {
            "dof_values": dict(pose.dof_values),
            "parameters": dict(pose.parameter_values),
            # JSON object keys are strings; the channel index is an int.
            "channels": {str(ch): value for ch, value in channels.items()},
            "limit_violations": [
                {
                    "dof_path": v.dof_path,
                    "value": v.value,
                    "min": v.min_value,
                    "max": v.max_value,
                }
                for v in pose.limit_violations
            ],
        },
    )


def _resolve_pose(session: Session, params: dict, request_id: object) -> dict:
    # The RealityKit render hook: evaluate one frame, run forward
    # kinematics over the joint graph (per-mate motion about/along the
    # connector as the relative origin), and return every part's world
    # transform. Supersedes the Swift RigPoseResolver / MateConnectorMath.
    handle = _require_str(params, "handle")
    rig = session.get(handle)
    if rig is None:
        return _error(
            request_id, "unknown_handle", f"no rig loaded as {handle!r}"
        )
    clip = params.get("clip")
    if clip is not None and not isinstance(clip, str):
        raise _BadRequest("'clip' must be a string or null")
    time_s = params.get("time_s", 0.0)
    if isinstance(time_s, bool) or not isinstance(time_s, (int, float)):
        raise _BadRequest("'time_s' must be a number")
    try:
        pose = evaluate_pose(rig, clip, float(time_s))
    except KeyError:
        raise _BadRequest(f"rig {handle!r} has no clip named {clip!r}")
    transforms = resolve_pose(rig, pose)
    return _ok(
        request_id,
        {
            "parts": {
                part_name: transform_to_json(transform)
                for part_name, transform in transforms.items()
            }
        },
    )


def _mate_types(session: Session, params: dict, request_id: object) -> dict:
    # The palette/panel-builder hook: the static per-kind schema for all
    # ten mate kinds — the eight kinematic mates plus the two
    # geometry-constraint mates (width, tangent), each with its
    # category, drivable flag, DOF slots, and control ids. No rig handle
    # needed — it is the type catalog.
    return _ok(request_id, {"mate_types": all_mate_type_schemas()})


def _relation_types(session: Session, params: dict, request_id: object) -> dict:
    # The relations palette/panel hook: the static per-kind schema for
    # all four relation kinds (Gear, Rack and pinion, Screw, Linear) —
    # each with its driver/driven DOF kinds, operator label, editable
    # ratio field, and reverse-supported flag. No rig handle needed — it
    # is the type catalog (the relation twin of ``mate_types``).
    return _ok(request_id, {"relation_types": all_relation_type_schemas()})


def _serialize_character(
    session: Session, params: dict, request_id: object
) -> dict:
    # The write side of Save: rebuild a Rig from the full rig DTO (the
    # exact shape load_character returns) and emit canonical
    # .character.anima text. Serialization validates — an un-serializable
    # or invalid rig is a format_error, so the app can never write a
    # broken file.
    rig_dto = params.get("rig")
    if not isinstance(rig_dto, dict):
        raise _BadRequest("'rig' must be an object")
    try:
        rig = rig_from_dict(rig_dto)
        text = rig_to_yaml(rig)
    except CharacterFormatError as error:
        return _error(request_id, "format_error", error.message, error.path)
    except (ValueError, KeyError, TypeError) as error:
        return _error(request_id, "format_error", str(error), None)
    return _ok(request_id, {"text": text})


def _serialize_scene(
    session: Session, params: dict, request_id: object
) -> dict:
    # The scene write side: the ``scene`` DTO is the .scene.anima document
    # structure (the scene AST is rig-independent and stores pose targets
    # already in file units, so there is no unit conversion). Validate by
    # parsing it back through the canonical scene loader, then emit
    # canonical text — one parser, one validator, no second surface.
    scene_dto = params.get("scene")
    if not isinstance(scene_dto, dict):
        raise _BadRequest("'scene' must be an object")
    try:
        scene = parse_scene(yaml.safe_dump(scene_dto))
        text = scene_to_yaml(scene)
    except SceneFormatError as error:
        return _error(request_id, "format_error", error.message, error.path)
    except (yaml.YAMLError, ValueError, KeyError, TypeError) as error:
        return _error(request_id, "format_error", str(error), None)
    return _ok(request_id, {"text": text})


def _release(session: Session, params: dict, request_id: object) -> dict:
    # Idempotent: dropping an unknown handle is not an error, so a client
    # can release freely without tracking exactly what the engine holds.
    session.drop(_require_str(params, "handle"))
    return _ok(request_id, {})


def _shutdown(session: Session, params: dict, request_id: object) -> dict:
    session.exit = True
    return _ok(request_id, {})


_VERBS = {
    "hello": _hello,
    "load_character": _load_character,
    "validate_character": _validate_character,
    "evaluate": _evaluate,
    "resolve_pose": _resolve_pose,
    "mate_types": _mate_types,
    "relation_types": _relation_types,
    "serialize_character": _serialize_character,
    "serialize_scene": _serialize_scene,
    "release": _release,
    "shutdown": _shutdown,
}


def handle_request(session: Session, request: dict) -> dict:
    """Dispatch one parsed request to a response envelope.

    Never raises for a protocol/format/shape error — those become an
    ``{ok: false, error: {...}}`` envelope. Only a truly unexpected
    engine bug propagates. ``request['id']`` is echoed verbatim.
    """
    request_id = request.get("id")
    method = request.get("method")
    if not isinstance(method, str):
        return _error(request_id, "bad_request", "missing/invalid 'method'")
    params = request.get("params", {})
    if params is None:
        params = {}
    if not isinstance(params, dict):
        return _error(request_id, "bad_request", "'params' must be an object")
    verb = _VERBS.get(method)
    if verb is None:
        return _error(request_id, "bad_request", f"unknown method {method!r}")
    try:
        return verb(session, params, request_id)
    except _BadRequest as error:
        return _error(request_id, "bad_request", str(error))


# stdio loop ------------------------------------------------------------------


def main(stdin: IO[str] | None = None, stdout: IO[str] | None = None) -> None:
    """Run the newline-JSON stdio loop until ``shutdown`` or EOF."""
    stdin = stdin if stdin is not None else sys.stdin
    stdout = stdout if stdout is not None else sys.stdout
    session = Session()
    for line in stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError as error:
            response = _error(None, "bad_request", f"invalid JSON: {error}")
        else:
            if isinstance(request, dict):
                response = handle_request(session, request)
            else:
                response = _error(
                    None, "bad_request", "request must be a JSON object"
                )
        stdout.write(json.dumps(response) + "\n")
        stdout.flush()
        if session.exit:
            break


if __name__ == "__main__":  # pragma: no cover - exercised via subprocess
    main()
