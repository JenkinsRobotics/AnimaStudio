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
from dataclasses import dataclass, field, replace
from typing import IO, Callable

import yaml

from animacore import __version__ as ENGINE_VERSION
from animacore.canvas2d import Canvas2D, SourceKind, evaluate_surfaces
from animacore.canvas2d_io import (
    canvas2d_from_mapping,
    canvas2d_to_mapping,
    canvas2d_to_yaml,
    parse_canvas2d,
)
from animacore.dh import DHError, forward_kinematics, solve_ik
from animacore.kinematics import Transform, resolve_pose, transform_to_json
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
    ChainJoint,
    Identity,
    Joint,
    JointKind,
    KinematicChain,
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
    "forward_kinematics",
    "solve_ik",
    "mate_types",
    "relation_types",
    "preview_mate",
    "add_mate",
    "update_mate",
    "remove_mate",
    "add_part",
    "update_part",
    "remove_part",
    "add_relation",
    "update_relation",
    "remove_relation",
    "serialize_character",
    "serialize_scene",
    "canvas2d.describe",
    "canvas2d.new",
    "canvas2d.load",
    "canvas2d.save",
    "canvas2d.get",
    "canvas2d.add_surface",
    "canvas2d.update_surface",
    "canvas2d.remove_surface",
    "canvas2d.add_source",
    "canvas2d.remove_source",
    "canvas2d.evaluate",
    "canvas2d.render_frame",
    "canvas2d.matrix_preview",
    "canvas2d.release",
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
    _canvases: dict[str, Canvas2D] = field(default_factory=dict)
    _canvas_counter: int = 0
    exit: bool = False

    def add(self, rig: Rig) -> str:
        self._counter += 1
        handle = f"rig{self._counter}"
        self._rigs[handle] = rig
        return handle

    def get(self, handle: str) -> Rig | None:
        return self._rigs.get(handle)

    def set(self, handle: str, rig: Rig) -> None:
        """Replace the rig behind an existing handle (in-place authoring)."""
        self._rigs[handle] = rig

    def drop(self, handle: str) -> bool:
        return self._rigs.pop(handle, None) is not None

    # 2D characters — a parallel handle space ("canvas1", "canvas2", …).
    def add_canvas(self, canvas: Canvas2D) -> str:
        self._canvas_counter += 1
        handle = f"canvas{self._canvas_counter}"
        self._canvases[handle] = canvas
        return handle

    def get_canvas(self, handle: str) -> Canvas2D | None:
        return self._canvases.get(handle)

    def set_canvas(self, handle: str, canvas: Canvas2D) -> None:
        self._canvases[handle] = canvas

    def drop_canvas(self, handle: str) -> bool:
        return self._canvases.pop(handle, None) is not None


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
                # Rest transform (part-in-character), native radians for
                # the orientation like other DOF descriptors — the app
                # converts to degrees for display.
                "position_m": list(part.position_m),
                "rotation_euler_rad": list(part.rotation_euler_rad),
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
        # The articulated-arm rig type: null for a general assembly rig,
        # the DH chain (base/tool parts, ordered joints in native units)
        # when present, so the app knows it is an arm and can show/drive
        # the joints. ``rig_from_dict`` reconstructs the rig from exactly
        # this shape.
        "kinematic_chain": _chain_summary(rig.kinematic_chain),
    }


def _chain_summary(chain: KinematicChain | None) -> dict | None:
    """The ``kinematic_chain`` block of the rig DTO (native units).

    ``a_m`` / ``d_m`` metres, ``alpha_rad`` / ``theta_rad`` radians, and
    each joint's variable ``min`` / ``max`` / ``neutral`` in native units
    (radians for a revolute joint, metres for a prismatic one — ``min`` /
    ``max`` null when unbounded). ``dof_path`` is the addressable
    ``"<chain>.<joint>"`` clip target. ``None`` for a non-chain rig.
    """
    if chain is None:
        return None
    return {
        "name": chain.name,
        "base_part": chain.base_part,
        "tool_part": chain.tool_part,
        "tool_position_m": list(chain.tool_position_m),
        "tool_rotation_euler_rad": list(chain.tool_rotation_euler_rad),
        "joints": [
            {
                "name": joint.name,
                "dof_path": f"{chain.name}.{joint.name}",
                "joint_type": joint.joint_type.value,
                "a_m": joint.a_m,
                "alpha_rad": joint.alpha_rad,
                "d_m": joint.d_m,
                "theta_rad": joint.theta_rad,
                "min": joint.min,
                "max": joint.max,
                "neutral": joint.neutral,
                "part": joint.part,
            }
            for joint in chain.joints
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


def _part_from_dto(entry: dict) -> Part:
    return Part(
        name=entry["name"],
        parent=entry.get("parent"),
        model_node=entry.get("model_node"),
        description=entry.get("description", ""),
        model=entry.get("model", ""),
        suppressed=entry.get("suppressed", False),
        grounded=entry.get("grounded", False),
        position_m=tuple(entry.get("position_m", (0.0, 0.0, 0.0))),
        rotation_euler_rad=tuple(
            entry.get("rotation_euler_rad", (0.0, 0.0, 0.0))
        ),
    )


def rig_from_dict(dto: dict) -> Rig:
    """Reconstruct a validated ``Rig`` from a ``load_character`` rig DTO."""
    identity = _identity_from_dto(dto["identity"])
    parts = {
        entry["name"]: _part_from_dto(entry) for entry in dto.get("parts", [])
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
    kinematic_chain = _chain_from_dto(dto.get("kinematic_chain"))
    dof_paths: dict[str, object] = {}
    for joint in joints.values():
        dof_paths.update(joint.dof_paths())
    if kinematic_chain is not None:
        dof_paths.update(kinematic_chain.dof_paths())
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
        kinematic_chain=kinematic_chain,
    )


def _chain_from_dto(dto: dict | None) -> KinematicChain | None:
    """Reconstruct a ``KinematicChain`` from the rig DTO (native units)."""
    if dto is None:
        return None
    return KinematicChain(
        name=dto["name"],
        joints=tuple(
            ChainJoint(
                name=joint["name"],
                a_m=joint.get("a_m", 0.0),
                alpha_rad=joint.get("alpha_rad", 0.0),
                d_m=joint.get("d_m", 0.0),
                theta_rad=joint.get("theta_rad", 0.0),
                joint_type=JointKind(joint.get("joint_type", "revolute")),
                min=joint.get("min"),
                max=joint.get("max"),
                neutral=joint.get("neutral", 0.0),
                part=joint.get("part"),
            )
            for joint in dto.get("joints", [])
        ),
        base_part=dto.get("base_part"),
        tool_part=dto.get("tool_part"),
        tool_position_m=tuple(dto.get("tool_position_m", (0.0, 0.0, 0.0))),
        tool_rotation_euler_rad=tuple(
            dto.get("tool_rotation_euler_rad", (0.0, 0.0, 0.0))
        ),
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


def _dof_overrides(params: dict) -> dict[str, float] | None:
    """Optional ``dof_values`` object: live posing overrides by DOF path."""
    raw = params.get("dof_values")
    if raw is None:
        return None
    if not isinstance(raw, dict):
        raise _BadRequest("'dof_values' must be an object")
    overrides: dict[str, float] = {}
    for path, value in raw.items():
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise _BadRequest(f"dof_values[{path!r}] must be a number")
        overrides[path] = float(value)
    return overrides


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
        pose = evaluate_pose(
            rig, clip, float(time_s), dof_overrides=_dof_overrides(params)
        )
    except KeyError as error:
        raise _BadRequest(str(error.args[0] if error.args else error))
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
        pose = evaluate_pose(
            rig, clip, float(time_s), dof_overrides=_dof_overrides(params)
        )
    except KeyError as error:
        raise _BadRequest(str(error.args[0] if error.args else error))
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


def _chain_or_error(
    session: Session, params: dict, request_id: object
) -> tuple[Rig, KinematicChain] | dict:
    """The loaded rig + its chain, or an error envelope to return."""
    handle = _require_str(params, "handle")
    rig = session.get(handle)
    if rig is None:
        return _error(
            request_id, "unknown_handle", f"no rig loaded as {handle!r}"
        )
    if rig.kinematic_chain is None:
        return _error(
            request_id,
            "no_kinematic_chain",
            f"rig {handle!r} is not an articulated-arm type "
            f"(no kinematic_chain); forward_kinematics/solve_ik require one",
        )
    return rig, rig.kinematic_chain


def _joint_values_in_order(
    chain: KinematicChain, values: dict, path: str
) -> list[float]:
    """Chain joint values in link order, missing ones falling to neutral."""
    ordered: list[float] = []
    for joint in chain.joints:
        value = values.get(joint.name, joint.neutral)
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise _BadRequest(f"{path}[{joint.name!r}] must be a number")
        ordered.append(float(value))
    return ordered


def _forward_kinematics(
    session: Session, params: dict, request_id: object
) -> dict:
    # Articulated-arm FK: place the chain's link frames and tool pose for a
    # set of joint values (missing joints fall back to their neutral). All
    # frames are character-space (the chain base is base_part's rest
    # transform), matching resolve_pose.
    resolved = _chain_or_error(session, params, request_id)
    if isinstance(resolved, dict):
        return resolved
    rig, chain = resolved
    joint_values = params.get("joint_values", {})
    if not isinstance(joint_values, dict):
        raise _BadRequest("'joint_values' must be an object")
    values = _joint_values_in_order(chain, joint_values, "joint_values")
    try:
        forward = forward_kinematics(rig.dh_chain(), values)
    except DHError as error:
        return _error(request_id, "kinematics_error", str(error))
    return _ok(
        request_id,
        {
            "link_frames": [
                transform_to_json(frame) for frame in forward.link_frames
            ],
            "tool_pose": transform_to_json(forward.tool_pose),
        },
    )


def _solve_ik(session: Session, params: dict, request_id: object) -> dict:
    # Articulated-arm IK: joint values putting the tool at a target pose
    # (damped least-squares; reports non-convergence honestly, never
    # raises for an unreachable target). The optional seed and returned
    # joint values are keyed by joint name; residuals are in metres /
    # radians.
    resolved = _chain_or_error(session, params, request_id)
    if isinstance(resolved, dict):
        return resolved
    rig, chain = resolved
    target = params.get("target_pose")
    if not isinstance(target, dict):
        raise _BadRequest("'target_pose' must be an object")
    position = target.get("position")
    orientation = target.get("orientation")
    if not _is_number_seq(position, 3):
        raise _BadRequest("'target_pose.position' must be 3 numbers")
    if not _is_number_seq(orientation, 4):
        raise _BadRequest(
            "'target_pose.orientation' must be 4 numbers (x, y, z, w)"
        )
    target_pose = Transform(
        rotation=tuple(float(c) for c in orientation),
        translation=tuple(float(c) for c in position),
    )
    seed_param = params.get("seed")
    seed: list[float] | None = None
    if seed_param is not None:
        if not isinstance(seed_param, dict):
            raise _BadRequest("'seed' must be an object or null")
        seed = _joint_values_in_order(chain, seed_param, "seed")
    try:
        result = solve_ik(rig.dh_chain(), target_pose, seed=seed)
    except DHError as error:
        return _error(request_id, "kinematics_error", str(error))
    return _ok(
        request_id,
        {
            "joint_values": {
                joint.name: value
                for joint, value in zip(chain.joints, result.joint_values)
            },
            "reached": result.reached,
            "position_error_m": result.position_error_m,
            "orientation_error_rad": result.orientation_error_rad,
            "iterations": result.iterations,
        },
    )


def _is_number_seq(value: object, length: int) -> bool:
    return (
        isinstance(value, (list, tuple))
        and len(value) == length
        and all(
            not isinstance(c, bool) and isinstance(c, (int, float))
            for c in value
        )
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


# Rig authoring — mates + relations mutate the canonical rig (Studio_Bridge).
# The engine owns mate/relation *meaning*: Studio sends the same joint/relation
# DTO shapes it already parses in ``load_character``, the engine rebuilds and
# re-validates the whole ``Rig`` (frozen dataclass ``__post_init__``), and
# returns the updated summary. Studio never mutates rig semantics itself.


def _rig_or_error(
    session: Session, params: dict, request_id: object
) -> tuple[Rig | None, str, dict | None]:
    handle = _require_str(params, "handle")
    rig = session.get(handle)
    if rig is None:
        return None, handle, _error(
            request_id, "unknown_handle", f"no rig loaded as {handle!r}"
        )
    return rig, handle, None


def _commit_rig(
    session: Session,
    handle: str,
    build: "Callable[[], Rig]",
    request_id: object,
) -> dict:
    """Build + re-validate a mutated rig, store it, return the summary.

    ``Rig.__post_init__`` raises ``ValueError`` for a dangling part
    reference, a self/duplicate-driven relation, etc.; that surfaces as a
    ``format_error`` rather than crashing the loop.
    """
    try:
        rig = build()
    except (KeyError, ValueError, TypeError) as error:
        return _error(request_id, "format_error", str(error), None)
    session.set(handle, rig)
    return _ok(request_id, {"handle": handle, "rig": _rig_summary(rig)})


def _relation_from_dto(dto: dict) -> Relation:
    return Relation(
        kind=RelationKind(dto["kind"]),
        driver=dto["driver"],
        driven=dto["driven"],
        ratio=dto["ratio"],
        offset=dto.get("offset", 0.0),
        display=dict(dto.get("display", {})),
        suppressed=dto.get("suppressed", False),
    )


def _validate_mate_graph(joints: dict[str, Joint]) -> None:
    """Reject a parent→child cycle before it can enter an authoring handle.

    The kinematic resolver is a forward walk, so a newly-authored mate must
    keep the Part graph acyclic. Loaded legacy characters remain compatible;
    every bridge-authored add/update and every non-destructive preview uses
    this validation.
    """
    children_by_parent: dict[str, list[str]] = {}
    for joint in joints.values():
        children_by_parent.setdefault(joint.parent_part, []).append(
            joint.child_part
        )

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(part: str, path: list[str]) -> None:
        if part in visiting:
            cycle_start = path.index(part)
            cycle = path[cycle_start:] + [part]
            raise ValueError(
                f"mate graph has a cycle ({' -> '.join(cycle)})"
            )
        if part in visited:
            return
        visiting.add(part)
        for child in children_by_parent.get(part, []):
            visit(child, path + [part])
        visiting.remove(part)
        visited.add(part)

    for part in children_by_parent:
        visit(part, [])


def _rig_adding_mate(rig: Rig, joint_dto: dict) -> Rig:
    joint = _joint_from_dto(joint_dto)
    joints = {**rig.joints, joint.name: joint}
    _validate_mate_graph(joints)
    return replace(rig, joints=joints)


def _preview_mate(session: Session, params: dict, request_id: object) -> dict:
    """Resolve a candidate mate without mutating the rig behind ``handle``."""
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    joint_dto = params.get("joint")
    if not isinstance(joint_dto, dict):
        raise _BadRequest("'joint' must be an object")
    name = joint_dto.get("name")
    if name in rig.joints:
        return _error(request_id, "bad_request", f"mate {name!r} already exists")
    clip = params.get("clip")
    if clip is not None and not isinstance(clip, str):
        raise _BadRequest("'clip' must be a string or null")
    time_s = params.get("time_s", 0.0)
    if isinstance(time_s, bool) or not isinstance(time_s, (int, float)):
        raise _BadRequest("'time_s' must be a number")
    try:
        preview_rig = _rig_adding_mate(rig, joint_dto)
    except (KeyError, ValueError, TypeError) as error:
        return _error(request_id, "format_error", str(error), None)
    try:
        pose = evaluate_pose(preview_rig, clip, float(time_s))
        transforms = resolve_pose(preview_rig, pose)
    except KeyError:
        raise _BadRequest(f"rig {handle!r} has no clip named {clip!r}")
    except (ValueError, TypeError) as error:
        return _error(request_id, "format_error", str(error), None)
    return _ok(
        request_id,
        {
            "parts": {
                part_name: transform_to_json(transform)
                for part_name, transform in transforms.items()
            }
        },
    )


def _add_mate(session: Session, params: dict, request_id: object) -> dict:
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    joint_dto = params.get("joint")
    if not isinstance(joint_dto, dict):
        raise _BadRequest("'joint' must be an object")
    name = joint_dto.get("name")
    if name in rig.joints:
        return _error(request_id, "bad_request", f"mate {name!r} already exists")
    return _commit_rig(
        session,
        handle,
        lambda: _rig_adding_mate(rig, joint_dto),
        request_id,
    )


def _update_mate(session: Session, params: dict, request_id: object) -> dict:
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    joint_dto = params.get("joint")
    if not isinstance(joint_dto, dict):
        raise _BadRequest("'joint' must be an object")
    name = joint_dto.get("name")
    if name not in rig.joints:
        return _error(request_id, "bad_request", f"no mate named {name!r}")
    return _commit_rig(
        session,
        handle,
        lambda: _rig_adding_mate(
            replace(
                rig,
                joints={
                    key: joint
                    for key, joint in rig.joints.items()
                    if key != name
                },
            ),
            joint_dto,
        ),
        request_id,
    )


def _remove_mate(session: Session, params: dict, request_id: object) -> dict:
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    name = _require_str(params, "name")
    if name not in rig.joints:
        return _error(request_id, "bad_request", f"no mate named {name!r}")
    remaining = {key: joint for key, joint in rig.joints.items() if key != name}
    return _commit_rig(
        session, handle, lambda: replace(rig, joints=remaining), request_id
    )


def _add_part(session: Session, params: dict, request_id: object) -> dict:
    """Incremental part authoring: append one part to the rig graph.

    The part DTO is exactly the ``load_character`` part entry shape
    (``name`` required; ``parent``/``model``/``model_node``/rest
    transform/``grounded``/``suppressed`` optional). An unknown parent or
    unsafe ``model`` path fails rig validation → ``format_error``.
    """
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    part_dto = params.get("part")
    if not isinstance(part_dto, dict):
        raise _BadRequest("'part' must be an object")
    name = part_dto.get("name")
    if not isinstance(name, str) or not name:
        raise _BadRequest("part 'name' must be a non-empty string")
    if name in rig.parts:
        return _error(request_id, "bad_request", f"part {name!r} already exists")

    def build() -> Rig:
        parts = {**rig.parts, name: _part_from_dto(part_dto)}
        return replace(rig, parts=parts)

    return _commit_rig(session, handle, build, request_id)


def _update_part(session: Session, params: dict, request_id: object) -> dict:
    """Replace one part's fields (same full-entry DTO as ``add_part``).

    The name is the key and cannot change here; moving a FREE part's rest
    transform is the primary use (viewport drag → ``position_m``).
    """
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    part_dto = params.get("part")
    if not isinstance(part_dto, dict):
        raise _BadRequest("'part' must be an object")
    name = part_dto.get("name")
    if not isinstance(name, str) or name not in rig.parts:
        return _error(request_id, "bad_request", f"no part named {name!r}")

    def build() -> Rig:
        parts = {**rig.parts, name: _part_from_dto(part_dto)}
        return replace(rig, parts=parts)

    return _commit_rig(session, handle, build, request_id)


def _remove_part(session: Session, params: dict, request_id: object) -> dict:
    """Remove a part; a part still referenced by a joint/child part fails
    rig validation and reports ``format_error`` (nothing is deleted)."""
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    name = _require_str(params, "name")
    if name not in rig.parts:
        return _error(request_id, "bad_request", f"no part named {name!r}")
    remaining = {key: part for key, part in rig.parts.items() if key != name}
    return _commit_rig(
        session, handle, lambda: replace(rig, parts=remaining), request_id
    )


def _add_relation(session: Session, params: dict, request_id: object) -> dict:
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    relation_dto = params.get("relation")
    if not isinstance(relation_dto, dict):
        raise _BadRequest("'relation' must be an object")
    driven = relation_dto.get("driven")
    if any(relation.driven == driven for relation in rig.relations):
        return _error(
            request_id, "bad_request", f"dof {driven!r} is already driven"
        )
    return _commit_rig(
        session,
        handle,
        lambda: replace(
            rig, relations=rig.relations + (_relation_from_dto(relation_dto),)
        ),
        request_id,
    )


def _update_relation(session: Session, params: dict, request_id: object) -> dict:
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    relation_dto = params.get("relation")
    if not isinstance(relation_dto, dict):
        raise _BadRequest("'relation' must be an object")
    driven = relation_dto.get("driven")
    if not any(relation.driven == driven for relation in rig.relations):
        return _error(request_id, "bad_request", f"no relation drives {driven!r}")

    def build() -> Rig:
        replacement = _relation_from_dto(relation_dto)
        return replace(
            rig,
            relations=tuple(
                replacement if relation.driven == driven else relation
                for relation in rig.relations
            ),
        )

    return _commit_rig(session, handle, build, request_id)


def _remove_relation(session: Session, params: dict, request_id: object) -> dict:
    rig, handle, err = _rig_or_error(session, params, request_id)
    if err is not None:
        return err
    driven = _require_str(params, "driven")
    if not any(relation.driven == driven for relation in rig.relations):
        return _error(request_id, "bad_request", f"no relation drives {driven!r}")
    return _commit_rig(
        session,
        handle,
        lambda: replace(
            rig,
            relations=tuple(
                relation for relation in rig.relations if relation.driven != driven
            ),
        ),
        request_id,
    )


def _release(session: Session, params: dict, request_id: object) -> dict:
    # Idempotent: dropping an unknown handle is not an error, so a client
    # can release freely without tracking exactly what the engine holds.
    session.drop(_require_str(params, "handle"))
    return _ok(request_id, {})


def _shutdown(session: Session, params: dict, request_id: object) -> dict:
    session.exit = True
    return _ok(request_id, {})


# Canvas2D (2D character) verbs -----------------------------------------------
# The engine side of the 2D workspace bridge
# (dev/docs/roadmap/2D_Character_Workspace.md). ``canvas2d`` is stdlib, so
# describe/new/evaluate work anywhere; only ``render_frame``/``matrix_preview``
# need the optional ``media`` extra (Pillow), imported lazily so the core bridge
# stays dependency-light — a missing extra returns ``media_unavailable``, never
# an import crash.


def _canvas2d_summary(canvas: Canvas2D) -> dict:
    return canvas2d_to_mapping(canvas)


def _canvas2d_from_dto(dto: dict) -> Canvas2D:
    try:
        return canvas2d_from_mapping(dto)
    except (KeyError, ValueError, TypeError) as error:
        raise _BadRequest(f"invalid canvas2d: {error}") from error


def _values_param(params: dict) -> dict:
    values = params.get("values", {})
    if not isinstance(values, dict):
        raise _BadRequest("'values' must be an object of name -> number")
    resolved: dict[str, float] = {}
    for key, value in values.items():
        try:
            resolved[str(key)] = float(value)
        except (TypeError, ValueError):
            raise _BadRequest(f"value {key!r} must be a number") from None
    return resolved


def _canvas_or_error(session, params, request_id):
    handle = _require_str(params, "handle")
    canvas = session.get_canvas(handle)
    if canvas is None:
        return None, handle, _error(request_id, "unknown_handle", f"no canvas {handle!r}")
    return canvas, handle, None


def _canvas2d_describe(session, params, request_id):
    try:
        from animacore.raster.procedural import default_faces

        faces = list(default_faces().names())
        media = True
    except Exception:  # noqa: BLE001 — media extra not installed
        faces = []
        media = False
    return _ok(
        request_id,
        {
            "source_kinds": [kind.value for kind in SourceKind],
            "faces": faces,
            "media_available": media,
            "matrix_default": {"width": 64, "height": 64, "gamma": 1.0, "brightness": 1.0},
        },
    )


def _canvas2d_new(session, params, request_id):
    dto = params.get("canvas", {})
    if not isinstance(dto, dict):
        return _error(request_id, "bad_request", "'canvas' must be an object")
    canvas = _canvas2d_from_dto(dto)
    handle = session.add_canvas(canvas)
    return _ok(request_id, {"handle": handle, "canvas": _canvas2d_summary(canvas)})


def _canvas2d_load(session, params, request_id):
    """Load a canvas from ``.character.anima`` (or a bare block) YAML ``text``."""
    text = _require_str(params, "text")
    try:
        canvas = parse_canvas2d(text)
    except ValueError as error:
        return _error(request_id, "bad_request", f"invalid canvas2d: {error}")
    if canvas is None:
        return _error(request_id, "no_canvas2d", "document has no canvas2d block")
    handle = session.add_canvas(canvas)
    return _ok(request_id, {"handle": handle, "canvas": _canvas2d_summary(canvas)})


def _canvas2d_save(session, params, request_id):
    """Serialize a canvas to its ``canvas2d:`` YAML block."""
    canvas, handle, err = _canvas_or_error(session, params, request_id)
    if err:
        return err
    return _ok(request_id, {"handle": handle, "yaml": canvas2d_to_yaml(canvas)})


def _canvas2d_get(session, params, request_id):
    canvas, handle, err = _canvas_or_error(session, params, request_id)
    if err:
        return err
    return _ok(request_id, {"handle": handle, "canvas": _canvas2d_summary(canvas)})


def _require_object(params: dict, key: str) -> dict:
    value = params.get(key)
    if not isinstance(value, dict):
        raise _BadRequest(f"{key!r} must be an object")
    return value


def _commit_canvas(session, handle, mutate, request_id):
    """Rebuild a session canvas after ``mutate`` edits its mapping; revalidates."""
    canvas = session.get_canvas(handle)
    if canvas is None:
        return _error(request_id, "unknown_handle", f"no canvas {handle!r}")
    data = canvas2d_to_mapping(canvas)
    try:
        mutate(data)
        new_canvas = canvas2d_from_mapping(data)
    except (KeyError, ValueError, TypeError) as error:
        return _error(request_id, "bad_request", f"invalid canvas2d edit: {error}")
    session.set_canvas(handle, new_canvas)
    return _ok(request_id, {"handle": handle, "canvas": _canvas2d_summary(new_canvas)})


def _canvas2d_add_surface(session, params, request_id):
    handle = _require_str(params, "handle")
    surface = _require_object(params, "surface")

    def mutate(data):
        if any(entry["id"] == surface.get("id") for entry in data["surfaces"]):
            raise ValueError(f"duplicate surface id {surface.get('id')!r}")
        data["surfaces"].append(surface)

    return _commit_canvas(session, handle, mutate, request_id)


def _canvas2d_update_surface(session, params, request_id):
    handle = _require_str(params, "handle")
    surface = _require_object(params, "surface")
    surface_id = surface.get("id")

    def mutate(data):
        for index, existing in enumerate(data["surfaces"]):
            if existing["id"] == surface_id:
                data["surfaces"][index] = surface
                return
        raise ValueError(f"no surface {surface_id!r}")

    return _commit_canvas(session, handle, mutate, request_id)


def _canvas2d_remove_surface(session, params, request_id):
    handle = _require_str(params, "handle")
    surface_id = _require_str(params, "surface_id")

    def mutate(data):
        remaining = [entry for entry in data["surfaces"] if entry["id"] != surface_id]
        if len(remaining) == len(data["surfaces"]):
            raise ValueError(f"no surface {surface_id!r}")
        data["surfaces"] = remaining

    return _commit_canvas(session, handle, mutate, request_id)


def _canvas2d_add_source(session, params, request_id):
    handle = _require_str(params, "handle")
    source = _require_object(params, "source")

    def mutate(data):
        if any(entry["id"] == source.get("id") for entry in data["sources"]):
            raise ValueError(f"duplicate source id {source.get('id')!r}")
        data["sources"].append(source)

    return _commit_canvas(session, handle, mutate, request_id)


def _canvas2d_remove_source(session, params, request_id):
    handle = _require_str(params, "handle")
    source_id = _require_str(params, "source_id")

    def mutate(data):
        remaining = [entry for entry in data["sources"] if entry["id"] != source_id]
        if len(remaining) == len(data["sources"]):
            raise ValueError(f"no source {source_id!r}")
        data["sources"] = remaining  # Canvas2D rejects a surface left referencing it

    return _commit_canvas(session, handle, mutate, request_id)


def _canvas2d_evaluate(session, params, request_id):
    canvas, handle, err = _canvas_or_error(session, params, request_id)
    if err:
        return err
    states = evaluate_surfaces(
        canvas, _values_param(params), float(params.get("time_seconds", 0.0))
    )
    return _ok(
        request_id,
        {
            "states": [
                {
                    "id": state.id,
                    "source": state.source,
                    "frame_index": state.frame_index,
                    "x": state.x,
                    "y": state.y,
                    "width": state.width,
                    "height": state.height,
                    "rotation_deg": state.rotation_deg,
                    "opacity": state.opacity,
                    "visible": state.visible,
                    "z": state.z,
                }
                for state in states
            ]
        },
    )


def _canvas2d_render_frame(session, params, request_id):
    canvas, handle, err = _canvas_or_error(session, params, request_id)
    if err:
        return err
    values = _values_param(params)
    time_seconds = float(params.get("time_seconds", 0.0))
    try:
        from animacore.raster.player import render_canvas
    except Exception as error:  # noqa: BLE001 — media extra not installed
        return _error(request_id, "media_unavailable", f"media extra required: {error}")
    import base64
    import io

    frame = render_canvas(canvas, values, time_seconds)
    buffer = io.BytesIO()
    frame.to_pil().convert("RGB").save(buffer, format="PNG")
    return _ok(
        request_id,
        {
            "width": frame.width,
            "height": frame.height,
            "png_base64": base64.b64encode(buffer.getvalue()).decode("ascii"),
        },
    )


def _canvas2d_matrix_preview(session, params, request_id):
    canvas, handle, err = _canvas_or_error(session, params, request_id)
    if err:
        return err
    values = _values_param(params)
    time_seconds = float(params.get("time_seconds", 0.0))
    target_dto = params.get("target", {}) or {}
    try:
        from animacore.frame_output import LedMatrixTarget, downsample_canvas
        from animacore.raster.player import render_canvas
    except Exception as error:  # noqa: BLE001 — media extra not installed
        return _error(request_id, "media_unavailable", f"media extra required: {error}")
    try:
        target = LedMatrixTarget(
            width=int(target_dto.get("width", 64)),
            height=int(target_dto.get("height", 64)),
            gamma=float(target_dto.get("gamma", 1.0)),
            brightness=float(target_dto.get("brightness", 1.0)),
        )
    except (ValueError, TypeError) as error:
        raise _BadRequest(f"invalid matrix target: {error}") from error
    frame = render_canvas(canvas, values, time_seconds)
    rows = downsample_canvas(frame.to_rgb_rows(), target)
    return _ok(
        request_id,
        {
            "width": target.width,
            "height": target.height,
            "rows": [[list(pixel) for pixel in row] for row in rows],
        },
    )


def _canvas2d_release(session, params, request_id):
    handle = _require_str(params, "handle")
    return _ok(request_id, {"released": session.drop_canvas(handle)})


_VERBS = {
    "hello": _hello,
    "load_character": _load_character,
    "validate_character": _validate_character,
    "evaluate": _evaluate,
    "resolve_pose": _resolve_pose,
    "forward_kinematics": _forward_kinematics,
    "solve_ik": _solve_ik,
    "mate_types": _mate_types,
    "relation_types": _relation_types,
    "preview_mate": _preview_mate,
    "add_mate": _add_mate,
    "add_part": _add_part,
    "update_part": _update_part,
    "remove_part": _remove_part,
    "update_mate": _update_mate,
    "remove_mate": _remove_mate,
    "add_relation": _add_relation,
    "update_relation": _update_relation,
    "remove_relation": _remove_relation,
    "serialize_character": _serialize_character,
    "serialize_scene": _serialize_scene,
    "canvas2d.describe": _canvas2d_describe,
    "canvas2d.new": _canvas2d_new,
    "canvas2d.load": _canvas2d_load,
    "canvas2d.save": _canvas2d_save,
    "canvas2d.get": _canvas2d_get,
    "canvas2d.add_surface": _canvas2d_add_surface,
    "canvas2d.update_surface": _canvas2d_update_surface,
    "canvas2d.remove_surface": _canvas2d_remove_surface,
    "canvas2d.add_source": _canvas2d_add_source,
    "canvas2d.remove_source": _canvas2d_remove_source,
    "canvas2d.evaluate": _canvas2d_evaluate,
    "canvas2d.render_frame": _canvas2d_render_frame,
    "canvas2d.matrix_preview": _canvas2d_matrix_preview,
    "canvas2d.release": _canvas2d_release,
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
