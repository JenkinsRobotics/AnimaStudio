"""Studio ↔ AnimaCore bridge: protocol logic driven through
``handle_request`` (no stdio), plus one subprocess smoke test.

The passthrough tests prove the whole point of the seam: an ``evaluate``
response's DOF values equal a direct ``evaluate_pose`` call, so the
bridge redefines nothing — it forwards the canonical engine result.
"""

import json
import math
import subprocess
import sys
from pathlib import Path

import pytest

from animacore.bridge import (
    CAPABILITIES,
    PROTOCOL_VERSION,
    Session,
    handle_request,
    main,
)
from animacore.loader import parse_character
from animacore.rig import evaluate_pose, project_channels

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "examples"
ARM = (EXAMPLES_DIR / "six_axis_arm.character.anima").read_text()

# A load that fails validation at a known, stable field path.
BROKEN = """
anima_version: "2.0"
type: character
identity: { name: broken }
parts: { a: {}, b: { parent: a } }
joints:
  bad:
    type: not_a_joint
    parent: a
    child: b
    dofs: {}
"""

# A gear relation driving the driven DOF (limited to ±90°) to 270°, past
# its limit — evaluate must report the violation and omit only its
# channel. six_axis_arm/rc_car never drive a mapped DOF past its limit
# through their clips, so the reachable-violation case needs its own rig.
VIOLATOR = """
anima_version: "2.0"
type: character
identity: { name: violator }
parts:
  base: {}
  link: { parent: base }
  gear: { parent: base }
joints:
  drive:
    type: revolute
    parent: base
    child: link
    dofs:
      rotation: { limits: { min_deg: -180, max_deg: 180 }, neutral_deg: 0 }
  driven:
    type: revolute
    parent: base
    child: gear
    dofs:
      rotation: { limits: { min_deg: -90, max_deg: 90 }, neutral_deg: 0 }
relations:
  - kind: gear
    driver: drive.rotation
    driven: driven.rotation
    ratio: 3.0
clips:
  push:
    duration_s: 1.0
    tracks:
      - { time: 0.0, values: { drive.rotation: 0.0 } }
      - { time: 1.0, values: { drive.rotation: 90.0 } }
outputs:
  - { target: drive.rotation, channel: 0, range_deg: [-180, 180] }
  - { target: driven.rotation, channel: 1, range_deg: [-90, 90] }
"""


def _load(session: Session, text: str) -> str:
    response = handle_request(
        session, {"id": 1, "method": "load_character", "params": {"text": text}}
    )
    assert response["ok"], response
    return response["result"]["handle"]


# hello -----------------------------------------------------------------------


def test_hello_ok():
    response = handle_request(
        Session(),
        {"id": 7, "method": "hello", "params": {"protocol_version": 1}},
    )
    assert response == {
        "id": 7,
        "ok": True,
        "result": {
            "engine": "animacore",
            "engine_version": "0.1.0",
            "protocol_version": PROTOCOL_VERSION,
            "capabilities": CAPABILITIES,
        },
    }


def test_hello_protocol_mismatch():
    response = handle_request(
        Session(),
        {"id": 1, "method": "hello", "params": {"protocol_version": 999}},
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "protocol_mismatch"


def test_hello_missing_protocol_version_is_bad_request():
    response = handle_request(
        Session(), {"id": 1, "method": "hello", "params": {}}
    )
    assert response["error"]["code"] == "bad_request"


# load_character --------------------------------------------------------------


def test_load_character_returns_handle_and_summary():
    session = Session()
    response = handle_request(
        session,
        {"id": 2, "method": "load_character", "params": {"text": ARM}},
    )
    assert response["ok"]
    result = response["result"]
    assert result["handle"] == "rig1"
    rig = result["rig"]
    assert rig["identity"]["name"] == "six_axis_arm"
    joints = {joint["name"]: joint for joint in rig["joints"]}
    base_yaw = joints["base_yaw"]
    assert base_yaw["type"] == "revolute"
    dof = base_yaw["dofs"][0]
    assert dof["path"] == "base_yaw.rotation"
    assert dof["kind"] == "rotation"
    assert dof["unit"] == "radians"
    assert dof["min"] == pytest.approx(math.radians(-170))
    assert dof["max"] == pytest.approx(math.radians(170))
    assert dof["neutral"] == pytest.approx(0.0)
    channels = {output["channel"] for output in rig["outputs"]}
    assert channels == {0, 1, 2, 3, 4, 5}


def test_load_character_handles_are_deterministic_and_monotonic():
    session = Session()
    assert _load(session, ARM) == "rig1"
    assert _load(session, ARM) == "rig2"
    assert _load(session, ARM) == "rig3"


def test_unlimited_dof_reports_null_limits():
    session = Session()
    response = handle_request(
        session,
        {
            "id": 1,
            "method": "load_character",
            "params": {
                "text": (
                    EXAMPLES_DIR / "rc_car.character.anima"
                ).read_text()
            },
        },
    )
    joints = {joint["name"]: joint for joint in response["result"]["rig"]["joints"]}
    spin = joints["drive"]["dofs"][0]
    assert spin["path"] == "drive.spin"
    assert spin["min"] is None
    assert spin["max"] is None


def test_load_character_format_error_carries_path():
    response = handle_request(
        Session(),
        {"id": 3, "method": "load_character", "params": {"text": BROKEN}},
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "format_error"
    assert response["error"]["path"] == "joints.bad.type"
    assert response["error"]["message"]


def test_load_character_missing_text_is_bad_request():
    response = handle_request(
        Session(), {"id": 1, "method": "load_character", "params": {}}
    )
    assert response["error"]["code"] == "bad_request"


def test_load_character_joint_summary_carries_id_and_controls():
    session = Session()
    response = handle_request(
        session,
        {"id": 2, "method": "load_character", "params": {"text": ARM}},
    )
    joints = {j["name"]: j for j in response["result"]["rig"]["joints"]}
    base_yaw = joints["base_yaw"]
    # The enriched summary is describe_mate: id + full universal controls.
    assert base_yaw["id"] == "Revolute 1"
    assert base_yaw["parent_part"] == "base"
    assert base_yaw["child_part"] == "shoulder"
    controls = base_yaw["controls"]
    assert controls["connectors"]["a"]["part"] == "base"
    assert controls["connectors"]["b"]["part"] == "shoulder"
    assert controls["offset"]["enabled"] is True
    assert controls["offset"]["translation_m"] == [0.0, 0.0, 0.012]
    assert controls["simulation_connection"] is True
    # A joint that declared no controls reports null connectors + defaults.
    shoulder = joints["shoulder_pitch"]
    assert shoulder["id"] == "Revolute 2"
    assert shoulder["controls"]["connectors"] == {"a": None, "b": None}
    assert shoulder["controls"]["offset"]["enabled"] is False


# mate_types ------------------------------------------------------------------


def test_mate_types_is_a_capability():
    assert "mate_types" in CAPABILITIES


def test_mate_types_returns_ten_schemas():
    response = handle_request(
        Session(), {"id": 9, "method": "mate_types", "params": {}}
    )
    assert response["ok"]
    schemas = response["result"]["mate_types"]
    # Eight kinematic mates + two geometry-constraint mates.
    assert len(schemas) == 10
    revolute = next(s for s in schemas if s["type"] == "revolute")
    assert revolute["label"] == "Revolute"
    assert revolute["dof_count"] == 1
    assert revolute["category"] == "kinematic"
    assert revolute["drivable"] is True
    assert revolute["universal_controls"] == [
        "connector_a",
        "connector_b",
        "offset",
        "flip_primary_axis",
        "secondary_axis_rotation",
        "simulation_connection",
    ]
    assert revolute["dofs"][0]["name"] == "rotation"


def test_mate_types_includes_geometry_constraint_pair():
    response = handle_request(
        Session(), {"id": 10, "method": "mate_types", "params": {}}
    )
    schemas = response["result"]["mate_types"]
    width = next(s for s in schemas if s["type"] == "width")
    tangent = next(s for s in schemas if s["type"] == "tangent")
    for schema in (width, tangent):
        assert schema["category"] == "geometry_constraint"
        assert schema["drivable"] is False
        assert schema["dof_count"] == 0
        assert schema["note"]
    assert "offset" not in width["universal_controls"]
    assert width["universal_controls"] == [
        "connector_a",
        "connector_b",
        "flip_primary_axis",
        "simulation_connection",
    ]
    assert tangent["universal_controls"] == [
        "tangent_selection_a",
        "tangent_selection_b",
        "tangent_propagation",
        "simulation_connection",
    ]


def test_mate_types_needs_no_handle():
    # It is the type catalog, answerable on a fresh session with no rig.
    response = handle_request(
        Session(), {"id": 1, "method": "mate_types", "params": {}}
    )
    assert response["ok"]


# relation_types --------------------------------------------------------------


def test_relation_types_is_a_capability():
    assert "relation_types" in CAPABILITIES


def test_relation_types_returns_four_schemas():
    response = handle_request(
        Session(), {"id": 11, "method": "relation_types", "params": {}}
    )
    assert response["ok"]
    schemas = response["result"]["relation_types"]
    assert [s["kind"] for s in schemas] == [
        "gear",
        "rack_pinion",
        "screw",
        "linear",
    ]
    gear = next(s for s in schemas if s["kind"] == "gear")
    assert gear["label"] == "Gear"
    assert gear["driver_kind"] == "rotation"
    assert gear["driven_kind"] == "rotation"
    assert gear["ratio_field"] == {"key": "relation_ratio", "unit": "ratio"}
    assert gear["reverse_supported"] is True
    rack = next(s for s in schemas if s["kind"] == "rack_pinion")
    assert rack["driven_kind"] == "translation"
    assert rack["ratio_field"] == {
        "key": "distance_per_revolution",
        "unit": "mm",
    }


def test_relation_types_needs_no_handle():
    response = handle_request(
        Session(), {"id": 1, "method": "relation_types", "params": {}}
    )
    assert response["ok"]


def test_load_character_summary_carries_relations():
    session = Session()
    response = handle_request(
        session,
        {
            "id": 12,
            "method": "load_character",
            "params": {
                "text": (
                    EXAMPLES_DIR / "rc_car.character.anima"
                ).read_text()
            },
        },
    )
    relations = response["result"]["rig"]["relations"]
    assert len(relations) == 1
    rack = relations[0]
    assert rack["kind"] == "rack_pinion"
    assert rack["driver"] == "steering.rotation"
    assert rack["driven"] == "rack.travel"
    assert rack["ratio"] == 0.02  # signed semantic truth
    assert rack["reverse"] is False
    # meters/radian → mm/revolution = ratio * 2π * 1000.
    assert rack["ratio_field_value"] == pytest.approx(0.02 * 2 * math.pi * 1000)
    assert rack["display"] == {"pinion_diameter_mm": 40}


# validate_character ----------------------------------------------------------


def test_validate_character_ok_has_empty_diagnostics():
    response = handle_request(
        Session(),
        {"id": 4, "method": "validate_character", "params": {"text": ARM}},
    )
    assert response["ok"]
    assert response["result"] == {"diagnostics": []}


def test_validate_character_failure_lists_diagnostic_no_handle():
    session = Session()
    response = handle_request(
        session,
        {"id": 4, "method": "validate_character", "params": {"text": BROKEN}},
    )
    assert response["ok"]  # validate never returns an error envelope
    diagnostics = response["result"]["diagnostics"]
    assert len(diagnostics) == 1
    assert diagnostics[0]["code"] == "format_error"
    assert diagnostics[0]["path"] == "joints.bad.type"
    # No handle was allocated, so a subsequent load is still rig1.
    assert _load(session, ARM) == "rig1"


# evaluate --------------------------------------------------------------------


def test_evaluate_neutral_matches_evaluate_pose():
    session = Session()
    handle = _load(session, ARM)
    response = handle_request(
        session,
        {"id": 5, "method": "evaluate", "params": {"handle": handle}},
    )
    assert response["ok"]
    expected = evaluate_pose(parse_character(ARM))
    assert response["result"]["dof_values"] == dict(expected.dof_values)
    assert response["result"]["parameters"] == dict(expected.parameter_values)


@pytest.mark.parametrize("time_s", [0.0, 1.0, 1.4, 3.0])
def test_evaluate_with_clip_matches_evaluate_pose(time_s):
    session = Session()
    handle = _load(session, ARM)
    response = handle_request(
        session,
        {
            "id": 5,
            "method": "evaluate",
            "params": {"handle": handle, "clip": "pick", "time_s": time_s},
        },
    )
    rig = parse_character(ARM)
    expected = evaluate_pose(rig, "pick", time_s)
    assert response["result"]["dof_values"] == dict(expected.dof_values)
    # channels are exactly project_channels (keyed by string for JSON).
    expected_channels = {
        str(ch): value
        for ch, value in project_channels(rig, expected).items()
    }
    assert response["result"]["channels"] == expected_channels
    assert response["result"]["limit_violations"] == []


def test_evaluate_reports_limit_violation_and_omits_channel():
    session = Session()
    handle = _load(session, VIOLATOR)
    response = handle_request(
        session,
        {
            "id": 6,
            "method": "evaluate",
            "params": {"handle": handle, "clip": "push", "time_s": 1.0},
        },
    )
    assert response["ok"]  # evaluate never fails on a violation
    result = response["result"]
    violations = result["limit_violations"]
    assert len(violations) == 1
    assert violations[0]["dof_path"] == "driven.rotation"
    assert violations[0]["value"] == pytest.approx(3.0 * math.radians(90))
    assert violations[0]["min"] == pytest.approx(math.radians(-90))
    assert violations[0]["max"] == pytest.approx(math.radians(90))
    # The violated channel (1) is omitted; the healthy one (0) projects.
    assert set(result["channels"]) == {"0"}


def test_evaluate_unknown_handle():
    response = handle_request(
        Session(),
        {"id": 6, "method": "evaluate", "params": {"handle": "rig99"}},
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "unknown_handle"


def test_evaluate_unknown_clip_is_bad_request():
    session = Session()
    handle = _load(session, ARM)
    response = handle_request(
        session,
        {
            "id": 6,
            "method": "evaluate",
            "params": {"handle": handle, "clip": "nope"},
        },
    )
    assert response["error"]["code"] == "bad_request"


def test_evaluate_bad_time_is_bad_request():
    session = Session()
    handle = _load(session, ARM)
    response = handle_request(
        session,
        {
            "id": 6,
            "method": "evaluate",
            "params": {"handle": handle, "time_s": "soon"},
        },
    )
    assert response["error"]["code"] == "bad_request"


# serialize_character / serialize_scene --------------------------------------


from test_serialize import assert_rigs_equal  # noqa: E402


def _serialize_round_trip(session: Session, text: str) -> str:
    """load_character → serialize_character → the re-serialized text."""
    load = handle_request(
        session,
        {"id": 1, "method": "load_character", "params": {"text": text}},
    )
    assert load["ok"], load
    rig_dto = load["result"]["rig"]
    serialized = handle_request(
        session,
        {"id": 2, "method": "serialize_character", "params": {"rig": rig_dto}},
    )
    assert serialized["ok"], serialized
    assert set(serialized["result"]) == {"text"}
    return serialized["result"]["text"]


def test_serialize_verbs_are_capabilities():
    assert "serialize_character" in CAPABILITIES
    assert "serialize_scene" in CAPABILITIES


@pytest.mark.parametrize(
    "filename",
    [
        "six_axis_arm.character.anima",  # mates + connectors + offset + clip
        "rc_car.character.anima",  # relation + unlimited wheel + parameter
        "walle_style.character.anima",  # mixed joints + parameters
        "geometry_mates_demo.character.anima",  # width/tangent geometry mates
    ],
)
def test_serialize_character_bridge_round_trip(filename):
    session = Session()
    text = (EXAMPLES_DIR / filename).read_text()
    text2 = _serialize_round_trip(session, text)
    # load(text) and load(text2) yield equal rigs — the acceptance test.
    assert_rigs_equal(parse_character(text), parse_character(text2))


def test_serialize_character_returns_canonical_text():
    session = Session()
    text2 = _serialize_round_trip(session, ARM)
    assert text2.startswith("anima_version:")
    assert "type: character" in text2
    assert "six_axis_arm" in text2


def test_serialize_character_invalid_rig_is_format_error():
    # A structurally well-formed DTO whose joint references an undeclared
    # part — Rig validation rejects it; the verb reports a format_error.
    session = Session()
    load = handle_request(
        session,
        {"id": 1, "method": "load_character", "params": {"text": ARM}},
    )
    rig_dto = load["result"]["rig"]
    rig_dto["joints"][0]["parent_part"] = "no_such_part"
    response = handle_request(
        session,
        {"id": 2, "method": "serialize_character", "params": {"rig": rig_dto}},
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "format_error"
    assert response["error"]["message"]


def test_serialize_character_missing_rig_is_bad_request():
    response = handle_request(
        Session(), {"id": 1, "method": "serialize_character", "params": {}}
    )
    assert response["error"]["code"] == "bad_request"


def test_serialize_scene_bridge_round_trip():
    # No load_scene verb yet, so the scene DTO is the .scene.anima
    # document structure (what scene_to_dict emits / a parsed file yields).
    from animacore.scene import parse_scene
    from animacore.serialize import scene_to_dict

    text = (EXAMPLES_DIR / "patrol_and_greet.scene.anima").read_text()
    scene = parse_scene(text)
    response = handle_request(
        Session(),
        {
            "id": 1,
            "method": "serialize_scene",
            "params": {"scene": scene_to_dict(scene)},
        },
    )
    assert response["ok"], response
    assert set(response["result"]) == {"text"}
    assert parse_scene(response["result"]["text"]) == scene


def test_serialize_scene_invalid_is_format_error():
    # A scene document missing its required sequence — the scene loader
    # rejects it with a pathed error.
    response = handle_request(
        Session(),
        {
            "id": 1,
            "method": "serialize_scene",
            "params": {
                "scene": {
                    "anima_version": "2.0",
                    "type": "scene",
                    "identity": {"name": "broken"},
                    "character": "x.character.anima",
                }
            },
        },
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "format_error"
    assert response["error"]["path"] == "sequence"


# load_character enrichment (full-fidelity fields for serialize) --------------


def test_load_character_summary_is_enriched_for_serialize():
    session = Session()
    rig = handle_request(
        session,
        {"id": 1, "method": "load_character", "params": {"text": ARM}},
    )["result"]["rig"]
    # Clips carry full keyframe data (not just name/duration/loop).
    pick = next(clip for clip in rig["clips"] if clip["name"] == "pick")
    assert pick["keyframes"]
    first = pick["keyframes"][0]
    assert set(first) == {"time_s", "interpolation", "values"}
    # Outputs carry their native-unit range endpoints.
    output = rig["outputs"][0]
    assert "value_at_zero" in output and "value_at_one" in output
    # Joint DOFs carry the per-DOF axis vector + name (distinct from the
    # template axis string) and description.
    base_yaw = next(j for j in rig["joints"] if j["name"] == "base_yaw")
    dof = base_yaw["dofs"][0]
    assert dof["name"] == "rotation"
    assert dof["axis_vector"] == [0.0, 0.0, 1.0]
    assert "description" in dof
    assert "description" in base_yaw


# release / shutdown / dispatch ----------------------------------------------


def test_release_drops_handle():
    session = Session()
    handle = _load(session, ARM)
    released = handle_request(
        session,
        {"id": 8, "method": "release", "params": {"handle": handle}},
    )
    assert released == {"id": 8, "ok": True, "result": {}}
    after = handle_request(
        session,
        {"id": 9, "method": "evaluate", "params": {"handle": handle}},
    )
    assert after["error"]["code"] == "unknown_handle"


def test_release_unknown_handle_is_ok_idempotent():
    response = handle_request(
        Session(),
        {"id": 8, "method": "release", "params": {"handle": "rig404"}},
    )
    assert response == {"id": 8, "ok": True, "result": {}}


def test_shutdown_sets_exit_and_returns_empty():
    session = Session()
    response = handle_request(session, {"id": 10, "method": "shutdown"})
    assert response == {"id": 10, "ok": True, "result": {}}
    assert session.exit is True


def test_unknown_method_is_bad_request():
    response = handle_request(Session(), {"id": 11, "method": "fly"})
    assert response["error"]["code"] == "bad_request"
    assert response["id"] == 11


def test_missing_method_is_bad_request():
    response = handle_request(Session(), {"id": None})
    assert response["error"]["code"] == "bad_request"


def test_bad_params_type_is_bad_request():
    response = handle_request(
        Session(), {"id": 1, "method": "hello", "params": []}
    )
    assert response["error"]["code"] == "bad_request"


# Vertical proof: the full envelope shape the Swift client parses --------------


def test_vertical_proof_hello_load_evaluate():
    session = Session()

    hello = handle_request(
        session,
        {"id": 1, "method": "hello", "params": {"protocol_version": 1}},
    )
    assert hello["ok"] and hello["result"]["engine"] == "animacore"

    load = handle_request(
        session,
        {"id": 2, "method": "load_character", "params": {"text": ARM}},
    )
    handle = load["result"]["handle"]

    evaluate = handle_request(
        session,
        {
            "id": 3,
            "method": "evaluate",
            "params": {"handle": handle, "clip": "pick", "time_s": 1.0},
        },
    )
    assert set(evaluate) == {"id", "ok", "result"}
    assert evaluate["id"] == 3 and evaluate["ok"] is True
    assert set(evaluate["result"]) == {
        "dof_values",
        "parameters",
        "channels",
        "limit_violations",
    }
    assert evaluate["result"]["dof_values"]["base_yaw.rotation"] == pytest.approx(
        math.radians(60)
    )


# stdio loop (in-process + one subprocess smoke test) -------------------------


def test_main_loop_answers_and_stops_on_shutdown():
    import io

    lines = [
        json.dumps({"id": 1, "method": "hello", "params": {"protocol_version": 1}}),
        "not json",
        json.dumps({"id": 2, "method": "shutdown"}),
        json.dumps({"id": 3, "method": "hello", "params": {"protocol_version": 1}}),
    ]
    stdout = io.StringIO()
    main(io.StringIO("\n".join(lines) + "\n"), stdout)
    responses = [json.loads(line) for line in stdout.getvalue().splitlines()]
    # hello, bad-json error, shutdown — then the loop exits (no 4th line).
    assert len(responses) == 3
    assert responses[0]["ok"] and responses[0]["id"] == 1
    assert responses[1]["ok"] is False and responses[1]["error"]["code"] == "bad_request"
    assert responses[2]["id"] == 2 and responses[2]["result"] == {}


def test_subprocess_smoke_module_invocation():
    repo_root = Path(__file__).resolve().parents[2]
    stdin = (
        json.dumps({"id": 1, "method": "hello", "params": {"protocol_version": 1}})
        + "\n"
        + json.dumps({"id": 2, "method": "shutdown"})
        + "\n"
    )
    completed = subprocess.run(
        [sys.executable, "-m", "animacore.bridge"],
        input=stdin,
        capture_output=True,
        text=True,
        timeout=30,
        cwd=repo_root,
    )
    responses = [json.loads(line) for line in completed.stdout.splitlines()]
    assert len(responses) == 2
    assert responses[0]["result"]["engine"] == "animacore"
    assert responses[1] == {"id": 2, "ok": True, "result": {}}
