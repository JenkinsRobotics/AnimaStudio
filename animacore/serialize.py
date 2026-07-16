"""Serialize the runtime model back to canonical ``.anima`` YAML — the
inverse of ``animacore.loader`` / ``animacore.scene``.

The engine owns ``.anima`` *writing* as well as reading, so a project
Save has one format author: the app hands the engine a rig/scene and
gets back canonical text. ``rig_to_dict`` / ``rig_to_yaml`` emit a
``.character.anima`` document from a ``Rig``; ``scene_to_dict`` /
``scene_to_yaml`` emit a ``.scene.anima`` document from a ``Scene``.

Round-trip is the contract: ``parse_character(rig_to_yaml(rig))`` yields
a rig equal to ``rig`` (and likewise for scenes), for every file in
``examples/``. Two conventions make that hold and keep the files clean:

- **Units mirror the loader.** Rotation limits/neutrals/track values/
  offsets/output ranges are radians in the model and **degrees** in the
  file; translations and connector origins stay metres. Scene
  ``pose`` targets are already stored in file units by the parser (the
  scene AST is rig-independent), so scenes need no unit conversion.
- **Defaults are omitted, not echoed.** A value the loader would default
  (``simulation_connection: true``, a disabled zero offset, an
  all-default ``controls`` block, ``loop: false``, ``linear``
  interpolation, a zero relation offset) is left out of the output; the
  loader restores it on the way back in. Clean minimal output that still
  round-trips beats echoing every default.

Deterministic: ``yaml.safe_dump(..., sort_keys=False)`` over a dict
built in a fixed, readable field order. Tuples are emitted as lists so
``safe_dump`` never trips on a Python tuple.
"""

from __future__ import annotations

import math

import yaml

from animacore.mates import (
    DofKind,
    JointType,
    MateConnector,
    MateControls,
    MateOffset,
    RotationAxis,
)
from animacore.rig import (
    RELATION_KIND_DOF_KINDS,
    DegreeOfFreedom,
    Joint,
    Rig,
)
from animacore.tracks import Interpolation

ANIMA_VERSION = "2.0"


# Character serialization ------------------------------------------------------


def rig_to_dict(rig: Rig) -> dict:
    """Build the ``.character.anima`` document dict for ``rig``.

    Every field the loader round-trips is emitted (radians→degrees for
    angles, metres kept), and only non-default fields are written.
    """
    document: dict = {
        "anima_version": ANIMA_VERSION,
        "type": "character",
        "identity": _identity_dict(rig.identity),
    }
    dof_paths = rig.dof_paths()
    parts = _parts_dict(rig)
    if parts:
        document["parts"] = parts
    joints = _joints_dict(rig)
    if joints:
        document["joints"] = joints
    parameters = _parameters_dict(rig)
    if parameters:
        document["parameters"] = parameters
    clips = _clips_list_dict(rig, dof_paths)
    if clips:
        document["clips"] = clips
    relations = _relations_list(rig, dof_paths)
    if relations:
        document["relations"] = relations
    outputs = _outputs_list(rig, dof_paths)
    if outputs:
        document["outputs"] = outputs
    return document


def rig_to_yaml(rig: Rig) -> str:
    """Serialize ``rig`` to canonical ``.character.anima`` YAML text."""
    return _dump(rig_to_dict(rig))


def _identity_dict(identity) -> dict:
    entry: dict = {"name": identity.name}
    for key in ("display_name", "description", "version", "author"):
        value = getattr(identity, key)
        if value:
            entry[key] = value
    return entry


def _parts_dict(rig: Rig) -> dict:
    parts: dict = {}
    for part in rig.parts.values():
        entry: dict = {}
        if part.parent is not None:
            entry["parent"] = part.parent
        if part.model_node is not None:
            entry["model_node"] = part.model_node
        if part.model:
            entry["model"] = part.model
        if part.description:
            entry["description"] = part.description
        # Rest transform (part-in-character): emitted only when non-zero,
        # radians→degrees for the orientation (metres kept). A zero
        # transform stays out of the file and round-trips as identity.
        if any(part.position_m):
            entry["position_m"] = list(part.position_m)
        if any(part.rotation_euler_rad):
            entry["rotation_euler_deg"] = [
                math.degrees(angle) for angle in part.rotation_euler_rad
            ]
        # Persistent rig-semantic states — emitted only when set, so a
        # default part stays clean and the round-trip is lossless.
        if part.suppressed:
            entry["suppressed"] = True
        if part.grounded:
            entry["grounded"] = True
        parts[part.name] = entry
    return parts


def _parameters_dict(rig: Rig) -> dict:
    parameters: dict = {}
    for parameter in rig.parameters.values():
        entry: dict = {}
        if parameter.neutral_value != 0.0:
            entry["default"] = parameter.neutral_value
        if parameter.description:
            entry["description"] = parameter.description
        parameters[parameter.name] = entry
    return parameters


def _joints_dict(rig: Rig) -> dict:
    joints: dict = {}
    for joint in rig.joints.values():
        joints[joint.name] = _joint_dict(joint)
    return joints


def _joint_dict(joint: Joint) -> dict:
    entry: dict = {"type": joint.joint_type.value}
    if joint.id:
        entry["id"] = joint.id
    entry["parent"] = joint.parent_part
    entry["child"] = joint.child_part
    if joint.joint_type is JointType.TANGENT:
        entry["tangent"] = _tangent_dict(joint.tangent)
    else:
        _write_controls(entry, joint)
        dofs = _dofs_dict(joint)
        if dofs:
            entry["dofs"] = dofs
    if joint.description:
        entry["description"] = joint.description
    if joint.suppressed:
        entry["suppressed"] = True
    return entry


def _tangent_dict(tangent) -> dict:
    entry = {
        "selection_a": tangent.selection_a,
        "selection_b": tangent.selection_b,
    }
    # propagation defaults to true in the loader.
    if not tangent.propagation:
        entry["propagation"] = False
    return entry


def _write_controls(entry: dict, joint: Joint) -> None:
    """Write the universal-control fields a mate needs, kind-appropriate.

    Width keeps only connectors/flip/simulation (no offset, no secondary
    reorientation — the loader's width field set rejects both); the
    kinematic mates carry the full block. An all-default ``controls``
    (or ``None``) writes nothing, so re-parsing yields ``controls=None``.
    """
    controls = joint.controls
    if controls is None or _controls_are_default(controls, joint.joint_type):
        return
    connectors = _connectors_dict(controls)
    if connectors:
        entry["connectors"] = connectors
    if joint.joint_type is not JointType.WIDTH:
        offset = _offset_dict(controls.offset)
        if offset:
            entry["offset"] = offset
        if controls.secondary_axis_rotation_deg != 0:
            entry["secondary_axis_rotation_deg"] = (
                controls.secondary_axis_rotation_deg
            )
    if controls.flip_primary_axis:
        entry["flip_primary_axis"] = True
    if not controls.simulation_connection:
        entry["simulation_connection"] = False


def _controls_are_default(
    controls: MateControls, joint_type: JointType
) -> bool:
    if controls.connector_a is not None or controls.connector_b is not None:
        return False
    if controls.flip_primary_axis:
        return False
    if not controls.simulation_connection:
        return False
    if joint_type is JointType.WIDTH:
        return True
    if controls.secondary_axis_rotation_deg != 0:
        return False
    return _offset_is_default(controls.offset)


def _offset_is_default(offset: MateOffset) -> bool:
    return (
        not offset.enabled
        and not any(offset.translation_m)
        and offset.rotation_axis is RotationAxis.Z
        and offset.rotation_radians == 0.0
    )


def _connectors_dict(controls: MateControls) -> dict:
    connectors: dict = {}
    if controls.connector_a is not None:
        connectors["a"] = _connector_dict(controls.connector_a)
    if controls.connector_b is not None:
        connectors["b"] = _connector_dict(controls.connector_b)
    return connectors


def _connector_dict(connector: MateConnector) -> dict:
    entry: dict = {"part": connector.part}
    if any(connector.origin_m):
        entry["origin_m"] = list(connector.origin_m)
    if connector.primary_axis != (0.0, 0.0, 1.0):
        entry["primary_axis"] = list(connector.primary_axis)
    if connector.secondary_axis != (1.0, 0.0, 0.0):
        entry["secondary_axis"] = list(connector.secondary_axis)
    if connector.flipped:
        entry["flipped"] = True
    if connector.feature:
        entry["feature"] = connector.feature
    return entry


def _offset_dict(offset: MateOffset) -> dict:
    if _offset_is_default(offset):
        return {}
    entry: dict = {}
    if offset.enabled:
        entry["enabled"] = True
    if any(offset.translation_m):
        entry["translation_m"] = list(offset.translation_m)
    if offset.rotation_axis is not RotationAxis.Z:
        entry["rotate_about"] = offset.rotation_axis.value
    if offset.rotation_radians != 0.0:
        entry["angle_deg"] = math.degrees(offset.rotation_radians)
    return entry


def _dofs_dict(joint: Joint) -> dict:
    dofs: dict = {}
    for dof in joint.dofs:
        dofs[dof.name] = _dof_dict(dof)
    return dofs


def _dof_dict(dof: DegreeOfFreedom) -> dict:
    entry: dict = {}
    if dof.kind is DofKind.ROTATION:
        min_key, max_key, neutral_key = "min_deg", "max_deg", "neutral_deg"
        convert = math.degrees
    else:
        min_key, max_key, neutral_key = "min_m", "max_m", "neutral_m"
        convert = _identity_number
    if dof.has_limits:
        entry["limits"] = {
            min_key: convert(dof.minimum),
            max_key: convert(dof.maximum),
        }
    # The neutral key is always written: it is required to infer the unit
    # family of an unlimited dof, and harmless (an explicit neutral)
    # otherwise — matching the examples.
    entry[neutral_key] = convert(dof.neutral)
    if dof.axis is not None:
        entry["axis"] = list(dof.axis)
    if dof.description:
        entry["description"] = dof.description
    return entry


def _identity_number(value: float) -> float:
    return value


def _clips_list_dict(rig: Rig, dof_paths: dict[str, DegreeOfFreedom]) -> dict:
    clips: dict = {}
    for rig_clip in rig.clips.values():
        clip = rig_clip.clip
        entry: dict = {"duration_s": clip.duration_seconds}
        if rig_clip.loop:
            entry["loop"] = True
        entry["tracks"] = _tracks_entries(clip, dof_paths)
        clips[clip.name] = entry
    return clips


def _tracks_entries(clip, dof_paths: dict[str, DegreeOfFreedom]) -> list:
    """Invert the per-target ``Track`` map back into per-time keyframe
    entries (the file shape: a time, an interpolation, a ``values`` map).

    All targets keyed at one time share the file entry's single
    interpolation — which is exactly how the loader built them (one file
    entry, one interpolation, many targets), so grouping by time is
    lossless. Rotation values convert radians→degrees.
    """
    grouped: dict[float, dict] = {}
    for target, track in clip.tracks.items():
        target = str(target)
        is_rotation = _is_rotation_target(target, dof_paths)
        for keyframe in track.keyframes:
            bucket = grouped.setdefault(
                keyframe.time_seconds,
                {"interpolation": keyframe.interpolation, "values": {}},
            )
            value = keyframe.value
            if is_rotation:
                value = math.degrees(value)
            bucket["values"][target] = value
    entries = []
    for time_seconds in sorted(grouped):
        bucket = grouped[time_seconds]
        entry: dict = {"time": time_seconds, "values": bucket["values"]}
        if bucket["interpolation"] is not Interpolation.LINEAR:
            entry["interpolation"] = bucket["interpolation"].value
        entries.append(entry)
    return entries


def _is_rotation_target(
    target: str, dof_paths: dict[str, DegreeOfFreedom]
) -> bool:
    dof = dof_paths.get(target)
    return dof is not None and dof.kind is DofKind.ROTATION


def _relations_list(rig: Rig, dof_paths: dict[str, DegreeOfFreedom]) -> list:
    relations = []
    for relation in rig.relations:
        entry: dict = {
            "kind": relation.kind.value,
            "driver": relation.driver,
            "driven": relation.driven,
            "ratio": relation.ratio,
        }
        if relation.offset != 0.0:
            _, driven_kind = RELATION_KIND_DOF_KINDS[relation.kind]
            if driven_kind is DofKind.ROTATION:
                entry["offset_deg"] = math.degrees(relation.offset)
            else:
                entry["offset_m"] = relation.offset
        if relation.display:
            entry["display"] = dict(relation.display)
        if relation.suppressed:
            entry["suppressed"] = True
        relations.append(entry)
    return relations


def _outputs_list(rig: Rig, dof_paths: dict[str, DegreeOfFreedom]) -> list:
    outputs = []
    for mapping in rig.outputs:
        entry: dict = {"target": mapping.target, "channel": mapping.channel}
        dof = dof_paths.get(mapping.target)
        if dof is not None and dof.kind is DofKind.ROTATION:
            entry["range_deg"] = [
                math.degrees(mapping.value_at_zero),
                math.degrees(mapping.value_at_one),
            ]
        elif dof is not None:
            entry["range_m"] = [mapping.value_at_zero, mapping.value_at_one]
        else:
            entry["range"] = [mapping.value_at_zero, mapping.value_at_one]
        outputs.append(entry)
    return outputs


# Scene serialization ----------------------------------------------------------
#
# The scene AST is rig-independent and stores ``pose`` targets already in
# file units, so scene serialization is a pure structural inverse of the
# parser with NO unit conversion. Every action/condition/monitor shape
# mirrors ``animacore.scene``'s parsers.


def scene_to_dict(scene) -> dict:
    """Build the ``.scene.anima`` document dict for ``scene``."""
    document: dict = {
        "anima_version": ANIMA_VERSION,
        "type": "scene",
        "identity": _identity_dict(scene.identity),
        "character": scene.character,
    }
    if scene.variables:
        document["variables"] = dict(scene.variables)
    if scene.inputs:
        document["inputs"] = dict(scene.inputs)
    if scene.subroutines:
        document["subroutines"] = {
            name: _actions_list(body)
            for name, body in scene.subroutines.items()
        }
    document["sequence"] = _actions_list(scene.sequence)
    if scene.monitors:
        document["monitors"] = [
            _monitor_dict(monitor) for monitor in scene.monitors
        ]
    if scene.editor is not None:
        document["editor"] = dict(scene.editor)
    return document


def scene_to_yaml(scene) -> str:
    """Serialize ``scene`` to canonical ``.scene.anima`` YAML text."""
    return _dump(scene_to_dict(scene))


def _actions_list(actions) -> list:
    return [_action_dict(action) for action in actions]


def _action_dict(action) -> dict:
    # Imported here to avoid a module-load cycle (scene imports loader,
    # not serialize; serialize reaches into scene only when called).
    from animacore.scene import (
        CallAction,
        ClipAction,
        EmitAction,
        IfAction,
        LoopAction,
        ParallelAction,
        PoseAction,
        SelectAction,
        SetAction,
        WaitAction,
        WaitForAction,
        WaitUntilAction,
    )

    if isinstance(action, ClipAction):
        block: dict = {"clip": action.name}
        if action.speed != 1.0:
            block["speed"] = action.speed
        if not action.wait:
            block["wait"] = False
        if action.duration_s is not None:
            block["duration_s"] = action.duration_s
        return block
    if isinstance(action, PoseAction):
        return {"pose": dict(action.targets), "duration_s": action.duration_s}
    if isinstance(action, WaitAction):
        return {"wait": {"seconds": action.seconds}}
    if isinstance(action, WaitForAction):
        return {"wait_for": _gate_block(action.event, action)}
    if isinstance(action, WaitUntilAction):
        block = {"when": _condition_dict(action.when)}
        _write_gate_timeout(block, action)
        return {"wait_until": block}
    if isinstance(action, SetAction):
        return {"set": {"var": action.var, "value": action.value}}
    if isinstance(action, IfAction):
        return {"if": _if_block(action)}
    if isinstance(action, SelectAction):
        return {"select": _select_block(action)}
    if isinstance(action, LoopAction):
        return {"loop": _loop_block(action)}
    if isinstance(action, ParallelAction):
        return {
            "parallel": {
                "tracks": [_actions_list(track) for track in action.tracks]
            }
        }
    if isinstance(action, CallAction):
        return {"call": action.name}
    if isinstance(action, EmitAction):
        return {"event": {"emit": action.name}}
    raise TypeError(f"cannot serialize action {action!r}")


def _gate_block(event: str, action) -> dict:
    block: dict = {"event": event}
    _write_gate_timeout(block, action)
    return block


def _write_gate_timeout(block: dict, action) -> None:
    from animacore.scene import TimeoutPolicy

    if action.timeout_s is not None:
        block["timeout_s"] = action.timeout_s
        # on_timeout defaults to skip; only write a non-default policy.
        if action.on_timeout is not TimeoutPolicy.SKIP:
            block["on_timeout"] = action.on_timeout.value


def _if_block(action) -> dict:
    block: dict = {}
    if action.when is not None:
        block["when"] = _condition_dict(action.when)
    else:
        block["var"] = action.var
        block["equals"] = action.equals
    block["then"] = _actions_list(action.then)
    if action.orelse:
        block["else"] = _actions_list(action.orelse)
    return block


def _select_block(action) -> dict:
    block: dict = {"var": action.var, "cases": []}
    for case in action.cases:
        block["cases"].append(
            {"equals": case.equals, "then": _actions_list(case.then)}
        )
    if action.default:
        block["default"] = _actions_list(action.default)
    return block


def _loop_block(action) -> dict:
    block: dict = {}
    if action.count is not None:
        block["count"] = action.count
    else:
        block["while_var"] = action.while_var
    block["body"] = _actions_list(action.body)
    return block


def _monitor_dict(monitor) -> dict:
    return {
        "name": monitor.name,
        "when": _condition_dict(monitor.when),
        "do": [_monitor_action_dict(action) for action in monitor.do],
    }


def _monitor_action_dict(action) -> dict:
    from animacore.scene import EndSceneAction

    if isinstance(action, EndSceneAction):
        return {"end_scene": {"result": action.result}}
    return _action_dict(action)


def _condition_dict(condition) -> dict:
    from animacore.scene import (
        AllCondition,
        AnyCondition,
        CompareCondition,
        NotCondition,
        XorCondition,
    )

    if isinstance(condition, CompareCondition):
        entry: dict = {}
        if condition.var is not None:
            entry["var"] = condition.var
        else:
            entry["input"] = condition.input
        entry["op"] = condition.op.value
        entry["value"] = condition.value
        return entry
    if isinstance(condition, NotCondition):
        return {"not": _condition_dict(condition.operand)}
    if isinstance(condition, AllCondition):
        return {"all": [_condition_dict(op) for op in condition.operands]}
    if isinstance(condition, AnyCondition):
        return {"any": [_condition_dict(op) for op in condition.operands]}
    if isinstance(condition, XorCondition):
        return {"xor": [_condition_dict(op) for op in condition.operands]}
    raise TypeError(f"cannot serialize condition {condition!r}")


# Dump -------------------------------------------------------------------------


def _dump(document: dict) -> str:
    """Deterministic block-style YAML: field order preserved, tuples out."""
    return yaml.safe_dump(
        document,
        sort_keys=False,
        default_flow_style=False,
        allow_unicode=True,
    )
