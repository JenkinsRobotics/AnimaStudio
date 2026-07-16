"""Canonical ``.anima`` serialization — the inverse of the loaders.

The contract is round-trip: for every file in ``examples/``,
``parse_character(rig_to_yaml(parse_character(text)))`` yields a rig
*equal* to the first parse (and the scene analog). Equality is compared
on the model objects — with float tolerance for the radians↔degrees
conversion the character file format mandates. Scenes carry no unit
conversion (their AST stores file units), so scene equality is exact
dataclass ``==``.
"""

import math
from pathlib import Path

import pytest

from animacore.loader import parse_character
from animacore.scene import parse_scene
from animacore.serialize import (
    rig_to_dict,
    rig_to_yaml,
    scene_to_dict,
    scene_to_yaml,
)

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "examples"
CHARACTER_FILES = sorted(EXAMPLES_DIR.glob("*.character.anima"))
SCENE_FILES = sorted(EXAMPLES_DIR.glob("*.scene.anima"))


# Model equality (tolerant of the radians↔degrees float round-trip) -----------


def _numbers_close(a: float, b: float) -> bool:
    if a == b:  # covers exact matches and matching infinities
        return True
    if math.isfinite(a) and math.isfinite(b):
        return math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-12)
    return False


def _dof_fingerprint(dof) -> dict:
    return {
        "name": dof.name,
        "kind": dof.kind.value,
        "min": dof.minimum,
        "max": dof.maximum,
        "neutral": dof.neutral,
        "axis": None if dof.axis is None else list(dof.axis),
        "description": dof.description,
    }


def _connector_fingerprint(connector) -> dict | None:
    if connector is None:
        return None
    return {
        "part": connector.part,
        "origin": list(connector.origin_m),
        "primary": list(connector.primary_axis),
        "secondary": list(connector.secondary_axis),
        "flipped": connector.flipped,
        "feature": connector.feature,
    }


def _controls_fingerprint(controls) -> dict | None:
    if controls is None:
        return None
    offset = controls.offset
    return {
        "a": _connector_fingerprint(controls.connector_a),
        "b": _connector_fingerprint(controls.connector_b),
        "offset": {
            "enabled": offset.enabled,
            "translation": list(offset.translation_m),
            "axis": offset.rotation_axis.value,
            "rotation": offset.rotation_radians,
        },
        "flip": controls.flip_primary_axis,
        "secondary": controls.secondary_axis_rotation_deg,
        "simulation": controls.simulation_connection,
    }


def _joint_fingerprint(joint) -> dict:
    return {
        "name": joint.name,
        "type": joint.joint_type.value,
        "parent": joint.parent_part,
        "child": joint.child_part,
        "id": joint.id,
        "description": joint.description,
        "dofs": [_dof_fingerprint(dof) for dof in joint.dofs],
        "controls": _controls_fingerprint(joint.controls),
        "tangent": (
            None
            if joint.tangent is None
            else {
                "a": joint.tangent.selection_a,
                "b": joint.tangent.selection_b,
                "propagation": joint.tangent.propagation,
            }
        ),
    }


def _clip_fingerprint(rig_clip) -> dict:
    clip = rig_clip.clip
    return {
        "name": clip.name,
        "duration": clip.duration_seconds,
        "loop": rig_clip.loop,
        "tracks": {
            str(target): {
                "min": track.minimum_value,
                "max": track.maximum_value,
                "keyframes": [
                    (kf.time_seconds, kf.value, kf.interpolation.value)
                    for kf in track.keyframes
                ],
            }
            for target, track in clip.tracks.items()
        },
    }


def _rig_fingerprint(rig) -> dict:
    identity = rig.identity
    return {
        "identity": (
            identity.name,
            identity.display_name,
            identity.description,
            identity.version,
            identity.author,
        ),
        "parts": {
            part.name: (
                part.parent,
                part.model_node,
                part.description,
                part.model,
            )
            for part in rig.parts.values()
        },
        "joints": [_joint_fingerprint(j) for j in rig.joints.values()],
        "parameters": {
            p.name: (p.neutral_value, p.description)
            for p in rig.parameters.values()
        },
        "clips": [_clip_fingerprint(rc) for rc in rig.clips.values()],
        "relations": [
            (
                r.kind.value,
                r.driver,
                r.driven,
                r.ratio,
                r.offset,
                dict(r.display),
            )
            for r in rig.relations
        ],
        "outputs": [
            (m.target, m.channel, m.value_at_zero, m.value_at_one)
            for m in rig.outputs
        ],
    }


def _assert_close(a, b, path="") -> None:
    """Recursive structural equality, floats compared with tolerance."""
    if isinstance(a, float) or isinstance(b, float):
        assert _numbers_close(a, b), f"{path}: {a!r} != {b!r}"
        return
    if isinstance(a, dict):
        assert isinstance(b, dict), f"{path}: type mismatch"
        assert set(a) == set(b), f"{path}: keys {set(a) ^ set(b)}"
        for key in a:
            _assert_close(a[key], b[key], f"{path}.{key}")
        return
    if isinstance(a, (list, tuple)):
        assert isinstance(b, (list, tuple)), f"{path}: type mismatch"
        assert len(a) == len(b), f"{path}: length {len(a)} != {len(b)}"
        for index, (x, y) in enumerate(zip(a, b)):
            _assert_close(x, y, f"{path}[{index}]")
        return
    assert a == b, f"{path}: {a!r} != {b!r}"


def assert_rigs_equal(a, b) -> None:
    _assert_close(_rig_fingerprint(a), _rig_fingerprint(b))


# Character round-trip ---------------------------------------------------------


@pytest.mark.parametrize(
    "path", CHARACTER_FILES, ids=lambda p: p.name
)
def test_character_round_trips(path):
    original = parse_character(path.read_text())
    reparsed = parse_character(rig_to_yaml(original))
    assert_rigs_equal(original, reparsed)


def test_character_serialization_is_deterministic():
    rig = parse_character(
        (EXAMPLES_DIR / "six_axis_arm.character.anima").read_text()
    )
    assert rig_to_yaml(rig) == rig_to_yaml(rig)


def test_rig_to_dict_header():
    rig = parse_character(
        (EXAMPLES_DIR / "rc_car.character.anima").read_text()
    )
    document = rig_to_dict(rig)
    assert document["anima_version"] == "2.0"
    assert document["type"] == "character"
    assert document["identity"]["name"] == "rc_car"


def test_clean_output_omits_defaults_but_round_trips():
    """Defaults are omitted, not echoed — yet the file still round-trips.

    six_axis_arm exercises the default-omission paths: ``base_yaw`` keeps
    the non-default connector origin/offset but drops the default primary
    axis, the ``simulation_connection: true`` and ``flip_primary_axis:
    false`` defaults, and the zero ``secondary_axis_rotation_deg``;
    ``shoulder_pitch`` declared no controls at all, so no ``connectors``
    block is written.
    """
    rig = parse_character(
        (EXAMPLES_DIR / "six_axis_arm.character.anima").read_text()
    )
    document = rig_to_dict(rig)
    base_yaw = document["joints"]["base_yaw"]
    # Kept: the genuinely non-default controls.
    assert base_yaw["connectors"]["a"]["origin_m"] == [0.0, 0.0, 0.05]
    assert base_yaw["offset"]["enabled"] is True
    # Omitted: every default.
    assert "primary_axis" not in base_yaw["connectors"]["a"]
    assert "simulation_connection" not in base_yaw
    assert "flip_primary_axis" not in base_yaw
    assert "secondary_axis_rotation_deg" not in base_yaw
    assert "loop" not in document["clips"]["pick"]  # loop: false default
    # A joint that declared no controls writes no connectors block.
    assert "connectors" not in document["joints"]["shoulder_pitch"]
    # And it all still parses back to an equal rig.
    assert_rigs_equal(rig, parse_character(rig_to_yaml(rig)))


def test_unlimited_dof_emits_neutral_and_no_limits():
    """rc_car's free-spinning axle: no limits block, but an explicit
    neutral (the loader needs it to infer the unit family)."""
    rig = parse_character(
        (EXAMPLES_DIR / "rc_car.character.anima").read_text()
    )
    spin = rig_to_dict(rig)["joints"]["drive"]["dofs"]["spin"]
    assert "limits" not in spin
    assert spin["neutral_deg"] == 0.0


def test_part_model_file_reference_round_trips():
    """A per-part ``model`` asset file emits when set, omits when empty,
    and round-trips losslessly (with or without a ``model_node``)."""
    rig = parse_character(
        (EXAMPLES_DIR / "pan_tilt_head.character.anima").read_text()
    )
    parts = rig_to_dict(rig)["parts"]
    # Emitted for parts that carry one; single-mesh STL has no model_node.
    assert parts["base"]["model"] == "assets/base.stl"
    assert "model_node" not in parts["base"]
    # A USD node: shared file plus its own node path.
    assert parts["head"]["model"] == "assets/head.usdz"
    assert parts["head"]["model_node"] == "head/mesh"
    assert_rigs_equal(rig, parse_character(rig_to_yaml(rig)))


def test_empty_part_model_is_omitted():
    from animacore.rig import Identity, Part, Rig

    rig = Rig(
        identity=Identity(name="bare"),
        parts={"solo": Part(name="solo")},
    )
    assert "model" not in rig_to_dict(rig)["parts"]["solo"]


def test_geometry_mates_serialize_width_and_tangent():
    rig = parse_character(
        (EXAMPLES_DIR / "geometry_mates_demo.character.anima").read_text()
    )
    document = rig_to_dict(rig)
    width = document["joints"]["center_tab"]
    assert width["type"] == "width"
    assert width["connectors"]["a"]["part"] == "frame"
    assert "offset" not in width  # width carries no offset
    tangent = document["joints"]["cam_contact"]
    assert tangent["type"] == "tangent"
    assert tangent["tangent"]["selection_a"] == "cam/lobe_surface"
    assert "connectors" not in tangent
    assert_rigs_equal(rig, parse_character(rig_to_yaml(rig)))


def test_relation_serialization_round_trips_display_and_ratio():
    rig = parse_character(
        (EXAMPLES_DIR / "rc_car.character.anima").read_text()
    )
    relation = rig_to_dict(rig)["relations"][0]
    assert relation["kind"] == "rack_pinion"
    assert relation["ratio"] == 0.02  # signed semantic truth, unconverted
    assert relation["display"] == {"pinion_diameter_mm": 40}
    assert "offset_m" not in relation  # zero offset omitted


# Scene round-trip -------------------------------------------------------------


@pytest.mark.parametrize("path", SCENE_FILES, ids=lambda p: p.name)
def test_scene_round_trips(path):
    original = parse_scene(path.read_text())
    reparsed = parse_scene(scene_to_yaml(original))
    # No unit conversion in scenes: the AST round-trips exactly.
    assert reparsed == original


def test_scene_to_dict_header():
    scene = parse_scene(
        (EXAMPLES_DIR / "pick_and_wave.scene.anima").read_text()
    )
    document = scene_to_dict(scene)
    assert document["anima_version"] == "2.0"
    assert document["type"] == "scene"
    assert document["character"] == "six_axis_arm.character.anima"


def test_scene_clean_output_omits_gate_default():
    """``on_timeout: skip`` is the loader default — a wait_for/wait_until
    using it writes no on_timeout key, and still round-trips."""
    scene = parse_scene(
        (EXAMPLES_DIR / "patrol_and_greet.scene.anima").read_text()
    )
    text = scene_to_yaml(scene)
    assert "on_timeout" not in text
    assert parse_scene(text) == scene


def test_scene_condition_tree_and_monitor_round_trip():
    """The v2 surface: an AND/OR condition tree, select, call, and a
    background monitor with end_scene all survive the round-trip."""
    scene = parse_scene(
        (EXAMPLES_DIR / "patrol_and_greet.scene.anima").read_text()
    )
    document = scene_to_dict(scene)
    # wait_until condition tree preserved as data.
    wait_until = document["sequence"][1]["wait_until"]
    assert "all" in wait_until["when"]
    assert wait_until["timeout_s"] == 6.0
    # Monitor with end_scene preserved.
    monitor = document["monitors"][0]
    assert monitor["name"] == "estop"
    assert monitor["do"][-1]["end_scene"]["result"] == "estop"
    assert parse_scene(scene_to_yaml(scene)) == scene
