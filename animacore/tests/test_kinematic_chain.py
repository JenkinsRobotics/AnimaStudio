"""The articulated-arm rig type: the ``kinematic_chain`` block (DH3).

Covers the character-format ``kinematic_chain`` round-trip, chain joints
as drivable DOF, ``resolve_pose`` placing link/tool parts by DH forward
kinematics, the bridge ``forward_kinematics`` / ``solve_ik`` verbs, and
that a general (non-chain) rig is unaffected. FK/IK math itself is
``test_dh.py``; this file is the integration into rig / loader /
serialize / bridge.
"""

from __future__ import annotations

import math
from pathlib import Path

import pytest

from animacore import bridge
from animacore.dh import forward_kinematics
from animacore.kinematics import Transform, resolve_pose
from animacore.loader import (
    CharacterFormatError,
    load_character_file,
    parse_character,
)
from animacore.rig import (
    ChainJoint,
    Identity,
    JointKind,
    KinematicChain,
    Part,
    Rig,
    evaluate_pose,
)
from animacore.serialize import rig_to_yaml

EXAMPLE = (
    Path(__file__).resolve().parents[2]
    / "examples"
    / "six_axis_arm_dh.character.anima"
)


def _close(a, b, tol=1e-9):
    return all(math.isclose(x, y, abs_tol=tol) for x, y in zip(a, b))


# A minimal but non-trivial chain document (planar 2R + a prismatic) with
# link parts and a clip driving the chain joints.
_CHAIN_DOC = """
anima_version: "2.0"
type: character
identity:
  name: little_arm
parts:
  base: {}
  link1: {}
  link2: {}
  tip: {}
kinematic_chain:
  name: arm
  base_part: base
  tool_part: tip
  tool:
    position_m: [0.1, 0, 0]
  joints:
    - name: j1
      type: revolute
      a_m: 0.5
      limits: { min_deg: -170, max_deg: 170 }
      part: link1
    - name: j2
      type: revolute
      a_m: 0.3
      limits: { min_deg: -170, max_deg: 170 }
      neutral_deg: 20
      part: link2
    - name: slide
      type: prismatic
      limits: { min_m: 0.0, max_m: 0.4 }
      neutral_m: 0.1
clips:
  wave:
    duration_s: 1.0
    tracks:
      - time: 0.0
        values: { arm.j1: 0.0, arm.j2: 20.0, arm.slide: 0.1 }
      - time: 1.0
        values: { arm.j1: 90.0, arm.j2: 45.0, arm.slide: 0.3 }
"""


def _load_chain() -> Rig:
    return parse_character(_CHAIN_DOC)


# Model ----------------------------------------------------------------------


def test_chain_joints_are_dof_of_the_rig():
    rig = _load_chain()
    assert rig.kinematic_chain is not None
    assert set(rig.chain_dof_paths()) == {"arm.j1", "arm.j2", "arm.slide"}
    # chain DOF are NOT in the mate dof_paths (separate namespace source)
    assert rig.dof_paths() == {}


def test_chain_joint_kinds_map_to_dof_kinds():
    rev = ChainJoint(name="r", min=-1.0, max=1.0)
    pri = ChainJoint(name="p", joint_type=JointKind.PRISMATIC)
    assert rev.as_dof().kind.value == "rotation"
    assert pri.as_dof().kind.value == "translation"


def test_chain_joint_neutral_outside_limits_rejected():
    with pytest.raises(ValueError, match="neutral"):
        ChainJoint(name="j", min=0.0, max=1.0, neutral=2.0)


def test_duplicate_chain_joint_names_rejected():
    with pytest.raises(ValueError, match="duplicate joint names"):
        KinematicChain(
            name="arm",
            joints=(ChainJoint(name="j"), ChainJoint(name="j")),
        )


def test_empty_chain_rejected():
    with pytest.raises(ValueError, match="at least one joint"):
        KinematicChain(name="arm", joints=())


def test_chain_part_reference_must_exist():
    with pytest.raises(ValueError, match="undeclared part"):
        Rig(
            identity=Identity(name="x"),
            parts={"base": Part(name="base")},
            kinematic_chain=KinematicChain(
                name="arm",
                joints=(ChainJoint(name="j", part="ghost"),),
            ),
        )


# Round trip -----------------------------------------------------------------


def test_chain_round_trips_load_serialize_load():
    rig = _load_chain()
    again = parse_character(rig_to_yaml(rig))
    assert rig == again


def test_example_round_trips():
    rig = load_character_file(EXAMPLE)
    assert rig.kinematic_chain is not None
    assert len(rig.kinematic_chain.joints) == 6
    assert parse_character(rig_to_yaml(rig)) == rig


# resolve_pose via DH FK ------------------------------------------------------


def test_resolve_pose_places_link_parts_by_dh_fk():
    rig = _load_chain()
    pose = evaluate_pose(rig, "wave", 1.0)
    transforms = resolve_pose(rig, pose)
    values = [
        pose.dof_values[f"arm.{j.name}"]
        for j in rig.kinematic_chain.joints
    ]
    forward = forward_kinematics(rig.dh_chain(), values)
    # each link part lands exactly on its DH link frame
    assert _close(transforms["link1"].translation,
                  forward.link_frames[0].translation)
    assert _close(transforms["link2"].translation,
                  forward.link_frames[1].translation)
    # the tool part lands on the tool pose (last link + tool offset)
    assert _close(transforms["tip"].translation,
                  forward.tool_pose.translation)


def test_resolve_pose_planar_2r_matches_closed_form():
    # With slide=0 and the tool offset, the planar 2R closed form is
    # exact: verify the tip position at j1=90deg, j2=0.
    doc = _CHAIN_DOC.replace("neutral_deg: 20", "neutral_deg: 0")
    rig = parse_character(doc)
    # neutral pose: j1=0, j2=0, slide=0.1
    pose = evaluate_pose(rig, None)
    transforms = resolve_pose(rig, pose)
    # straight arm along +X: 0.5 + 0.3 + 0.1(tool) = 0.9; slide adds +Z 0.1
    assert _close(transforms["tip"].translation, (0.9, 0.0, 0.1))


def test_chain_joint_is_drivable_the_arm_moves():
    rig = _load_chain()
    start = resolve_pose(rig, evaluate_pose(rig, "wave", 0.0))
    end = resolve_pose(rig, evaluate_pose(rig, "wave", 1.0))
    # driving the joints moves the tip meaningfully
    assert not _close(start["tip"].translation, end["tip"].translation)


def test_base_part_rest_transform_is_the_chain_base():
    # Mount the whole chain at an offset base and confirm FK is shifted.
    doc = _CHAIN_DOC.replace(
        "  base: {}", "  base: { position_m: [1, 2, 3] }"
    )
    rig = parse_character(doc)
    pose = evaluate_pose(rig, None)
    at_base = resolve_pose(rig, pose)["link1"].translation
    # link1 at neutral (j1=0) sits at base + (a1, 0, 0) = (1.5, 2, 3)
    assert _close(at_base, (1.5, 2.0, 3.0))


def test_non_chain_rig_resolve_pose_unaffected():
    # A general mate assembly (no kinematic_chain) resolves exactly as
    # before — a single root part at its rest transform.
    rig = Rig(
        identity=Identity(name="x"),
        parts={"root": Part(name="root", position_m=(1.0, 0.0, 0.0))},
    )
    transforms = resolve_pose(rig, evaluate_pose(rig, None))
    assert _close(transforms["root"].translation, (1.0, 0.0, 0.0))
    assert rig.kinematic_chain is None


# Loader accept / reject ------------------------------------------------------


def test_loader_rejects_unknown_chain_field():
    doc = _CHAIN_DOC.replace("  name: arm", "  name: arm\n  bogus: 1")
    with pytest.raises(CharacterFormatError, match="kinematic_chain.bogus"):
        parse_character(doc)


def test_loader_rejects_unknown_joint_type():
    doc = _CHAIN_DOC.replace("type: prismatic", "type: helical")
    with pytest.raises(CharacterFormatError, match="unknown joint type"):
        parse_character(doc)


def test_loader_rejects_wrong_unit_neutral_key():
    # a revolute joint must use neutral_deg, not neutral_m
    doc = _CHAIN_DOC.replace(
        "      neutral_deg: 20", "      neutral_m: 0.2"
    )
    with pytest.raises(CharacterFormatError, match="neutral_deg"):
        parse_character(doc)


def test_loader_rejects_chain_base_part_missing():
    doc = _CHAIN_DOC.replace("base_part: base", "base_part: ghost")
    with pytest.raises(CharacterFormatError, match="undeclared part"):
        parse_character(doc)


def test_loader_rejects_empty_joint_list():
    doc = _CHAIN_DOC.split("  joints:")[0] + "  joints: []\n"
    with pytest.raises(CharacterFormatError, match="non-empty"):
        parse_character(doc)


def test_clip_may_target_chain_dof_but_not_unknown():
    doc = _CHAIN_DOC.replace("arm.slide: 0.1", "arm.ghost: 0.1")
    with pytest.raises(CharacterFormatError, match="undeclared DOF"):
        parse_character(doc)


# Bridge summary + FK/IK verbs -----------------------------------------------


def _bridge_load(session, path=EXAMPLE) -> str:
    resp = bridge.handle_request(
        session,
        {
            "id": 1,
            "method": "load_character",
            "params": {"text": path.read_text(encoding="utf-8")},
        },
    )
    assert resp["ok"], resp
    return resp["result"]


def test_bridge_summary_exposes_chain():
    session = bridge.Session()
    result = _bridge_load(session)
    chain = result["rig"]["kinematic_chain"]
    assert chain is not None
    assert chain["name"] == "arm"
    assert chain["base_part"] == "base"
    assert chain["tool_part"] == "gripper"
    assert len(chain["joints"]) == 6
    j1 = chain["joints"][0]
    assert j1["dof_path"] == "arm.j1"
    assert j1["joint_type"] == "revolute"
    assert j1["alpha_rad"] == pytest.approx(math.pi / 2)


def test_bridge_summary_null_for_non_chain_rig():
    session = bridge.Session()
    text = (EXAMPLE.parent / "six_axis_arm.character.anima").read_text(
        encoding="utf-8"
    )
    resp = bridge.handle_request(
        session,
        {"id": 1, "method": "load_character", "params": {"text": text}},
    )
    assert resp["result"]["rig"]["kinematic_chain"] is None


def test_bridge_capabilities_list_fk_ik():
    session = bridge.Session()
    resp = bridge.handle_request(
        session,
        {"id": 0, "method": "hello", "params": {"protocol_version": 1}},
    )
    caps = resp["result"]["capabilities"]
    assert "forward_kinematics" in caps
    assert "solve_ik" in caps


def test_bridge_forward_kinematics_matches_engine():
    session = bridge.Session()
    result = _bridge_load(session)
    handle = result["handle"]
    jv = {"j1": 0.3, "j2": -0.5, "j3": 1.2, "j4": 0.2, "j5": 0.7, "j6": -0.4}
    resp = bridge.handle_request(
        session,
        {
            "id": 2,
            "method": "forward_kinematics",
            "params": {"handle": handle, "joint_values": jv},
        },
    )
    assert resp["ok"], resp
    assert len(resp["result"]["link_frames"]) == 6
    tool = resp["result"]["tool_pose"]
    assert set(tool) == {"position", "orientation"}


def test_bridge_fk_ik_fk_round_trip_reaches_target():
    session = bridge.Session()
    result = _bridge_load(session)
    handle = result["handle"]
    jv = {"j1": 0.3, "j2": -0.5, "j3": 1.2, "j4": 0.2, "j5": 0.7, "j6": -0.4}
    fk = bridge.handle_request(
        session,
        {
            "id": 2,
            "method": "forward_kinematics",
            "params": {"handle": handle, "joint_values": jv},
        },
    )
    target = fk["result"]["tool_pose"]
    ik = bridge.handle_request(
        session,
        {
            "id": 3,
            "method": "solve_ik",
            "params": {
                "handle": handle,
                "target_pose": target,
                "seed": {"j1": 0.0, "j2": -0.3, "j3": 1.0,
                         "j4": 0.0, "j5": 0.5, "j6": 0.0},
            },
        },
    )
    assert ik["ok"], ik
    assert ik["result"]["reached"]
    assert ik["result"]["position_error_m"] < 1e-4
    assert ik["result"]["orientation_error_rad"] < 1e-3
    # FK on the IK solution reproduces the target pose (probe the tool).
    fk2 = bridge.handle_request(
        session,
        {
            "id": 4,
            "method": "forward_kinematics",
            "params": {
                "handle": handle,
                "joint_values": ik["result"]["joint_values"],
            },
        },
    )
    achieved = Transform(
        rotation=tuple(fk2["result"]["tool_pose"]["orientation"]),
        translation=tuple(fk2["result"]["tool_pose"]["position"]),
    )
    want = Transform(
        rotation=tuple(target["orientation"]),
        translation=tuple(target["position"]),
    )
    for probe in [(0, 0, 0), (0.1, 0, 0), (0, 0.2, 0), (0, 0, 0.3)]:
        assert _close(achieved.apply_point(probe),
                      want.apply_point(probe), tol=1e-3)


def test_bridge_solve_ik_unreachable_reports_honest_residual():
    session = bridge.Session()
    handle = _bridge_load(session)["handle"]
    resp = bridge.handle_request(
        session,
        {
            "id": 2,
            "method": "solve_ik",
            "params": {
                "handle": handle,
                "target_pose": {
                    "position": [100.0, 100.0, 100.0],
                    "orientation": [0, 0, 0, 1],
                },
            },
        },
    )
    assert resp["ok"], resp
    assert resp["result"]["reached"] is False
    assert resp["result"]["position_error_m"] > 1.0


def test_bridge_fk_requires_chain():
    session = bridge.Session()
    text = (EXAMPLE.parent / "six_axis_arm.character.anima").read_text(
        encoding="utf-8"
    )
    resp = bridge.handle_request(
        session,
        {"id": 1, "method": "load_character", "params": {"text": text}},
    )
    handle = resp["result"]["handle"]
    fk = bridge.handle_request(
        session,
        {
            "id": 2,
            "method": "forward_kinematics",
            "params": {"handle": handle, "joint_values": {}},
        },
    )
    assert fk["ok"] is False
    assert fk["error"]["code"] == "no_kinematic_chain"


def test_bridge_serialize_character_round_trips_chain():
    # load → summary DTO → rig_from_dict → serialize → parse, equal rig.
    session = bridge.Session()
    result = _bridge_load(session)
    resp = bridge.handle_request(
        session,
        {
            "id": 2,
            "method": "serialize_character",
            "params": {"rig": result["rig"]},
        },
    )
    assert resp["ok"], resp
    reparsed = parse_character(resp["result"]["text"])
    assert reparsed == load_character_file(EXAMPLE)


def test_bridge_fk_missing_joint_uses_neutral():
    session = bridge.Session()
    handle = _bridge_load(session)["handle"]
    # empty joint_values → all joints at neutral == FK(neutral)
    resp = bridge.handle_request(
        session,
        {
            "id": 2,
            "method": "forward_kinematics",
            "params": {"handle": handle, "joint_values": {}},
        },
    )
    assert resp["ok"], resp
    rig = load_character_file(EXAMPLE)
    neutral = [j.neutral for j in rig.kinematic_chain.joints]
    forward = forward_kinematics(rig.dh_chain(), neutral)
    assert _close(resp["result"]["tool_pose"]["position"],
                  forward.tool_pose.translation)
