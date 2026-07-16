"""Persistent object states: part/joint/relation ``suppressed`` and part
``grounded``.

These are *rig-semantic* states stored in the canonical
``.character.anima`` file (unlike the app's transient hidden/lock
view-state): they change what the rig solves and they must survive a
save → quit → relaunch cycle, so the load ⇄ serialize round-trip is the
headline contract here. The evaluation tests pin the deterministic solve
semantics (``evaluate_pose`` driven-DOF exclusion, ``resolve_pose`` FK
activity) that the app's tree toggles wire to.
"""

import math

import pytest

from animacore.bridge import (
    Session,
    handle_request,
    rig_from_dict,
)
from animacore.kinematics import IDENTITY, resolve_pose
from animacore.loader import CharacterFormatError, parse_character
from animacore.mates import describe_mate
from animacore.rig import (
    Identity,
    Joint,
    JointType,
    Part,
    Relation,
    RelationKind,
    Rig,
    RotationDof,
    TranslationDof,
    describe_relation,
    evaluate_pose,
)
from animacore.serialize import rig_to_yaml

TOL = 1e-9


# Rig builders ----------------------------------------------------------------


def _prismatic_rig(**state) -> Rig:
    """base → arm → hand via two Z-prismatic joints (each neutral 0.5 m).

    ``state`` overrides individual object states by keyword (e.g.
    ``j1_suppressed=True``, ``arm_grounded=True``, ``hand_suppressed=True``)
    so each test isolates one behavior. When active a joint shifts its
    child +0.5 m along Z, so an inactive/grounded/orphan part staying at
    IDENTITY (translation 0) is directly observable.
    """
    parts = {
        "base": Part(name="base"),
        "arm": Part(
            name="arm",
            suppressed=state.get("arm_suppressed", False),
            grounded=state.get("arm_grounded", False),
        ),
        "hand": Part(
            name="hand",
            suppressed=state.get("hand_suppressed", False),
            grounded=state.get("hand_grounded", False),
        ),
    }
    joints = {
        "j1": Joint(
            name="j1",
            joint_type=JointType.PRISMATIC,
            parent_part="base",
            child_part="arm",
            dofs=(TranslationDof(name="translation", neutral_meters=0.5),),
            suppressed=state.get("j1_suppressed", False),
        ),
        "j2": Joint(
            name="j2",
            joint_type=JointType.PRISMATIC,
            parent_part="arm",
            child_part="hand",
            dofs=(TranslationDof(name="translation", neutral_meters=0.5),),
            suppressed=state.get("j2_suppressed", False),
        ),
    }
    return Rig(
        identity=Identity(name="test"), parts=parts, joints=joints
    )


def _gear_rig(relation_suppressed: bool = False) -> Rig:
    """Two revolute joints coupled by a gear relation (ratio 2.0).

    Driver ``j1.rotation`` has neutral 1.0 rad; driven ``j2.rotation``
    has its own neutral 0.0. Active relation → driven = 2.0; suppressed
    relation → driven falls back to its own neutral 0.0.
    """
    parts = {
        "base": Part(name="base"),
        "arm": Part(name="arm"),
        "hand": Part(name="hand"),
    }
    joints = {
        "j1": Joint(
            name="j1",
            joint_type=JointType.REVOLUTE,
            parent_part="base",
            child_part="arm",
            dofs=(RotationDof(name="rotation", neutral_radians=1.0),),
        ),
        "j2": Joint(
            name="j2",
            joint_type=JointType.REVOLUTE,
            parent_part="arm",
            child_part="hand",
            dofs=(RotationDof(name="rotation", neutral_radians=0.0),),
        ),
    }
    relations = (
        Relation(
            kind=RelationKind.GEAR,
            driver="j1.rotation",
            driven="j2.rotation",
            ratio=2.0,
            suppressed=relation_suppressed,
        ),
    )
    return Rig(
        identity=Identity(name="test"),
        parts=parts,
        joints=joints,
        relations=relations,
    )


# THE round-trip: Jonathan's save → quit → relaunch flow ----------------------


def test_states_survive_serialize_reload():
    # Suppress a joint AND a part, ground a part, suppress a relation —
    # serialize to canonical YAML, reparse, and the states must persist.
    rig = _gear_rig(relation_suppressed=True)
    parts = dict(rig.parts)
    parts["arm"] = Part(name="arm", suppressed=True)
    parts["hand"] = Part(name="hand", grounded=True)
    joints = dict(rig.joints)
    j1 = joints["j1"]
    joints["j1"] = Joint(
        name=j1.name,
        joint_type=j1.joint_type,
        parent_part=j1.parent_part,
        child_part=j1.child_part,
        dofs=j1.dofs,
        suppressed=True,
    )
    rig = Rig(
        identity=rig.identity,
        parts=parts,
        joints=joints,
        relations=rig.relations,
    )

    reloaded = parse_character(rig_to_yaml(rig))

    assert reloaded.parts["arm"].suppressed is True
    assert reloaded.parts["hand"].grounded is True
    assert reloaded.joints["j1"].suppressed is True
    assert reloaded.relations[0].suppressed is True
    # And the defaults stay False (no accidental leakage).
    assert reloaded.parts["base"].suppressed is False
    assert reloaded.parts["base"].grounded is False
    assert reloaded.joints["j2"].suppressed is False


def test_serialize_omits_default_states():
    # A rig with no states set writes no suppressed/grounded keys at all.
    text = rig_to_yaml(_prismatic_rig())
    assert "suppressed" not in text
    assert "grounded" not in text


def test_serialize_emits_only_true_states():
    rig = _prismatic_rig(arm_grounded=True, j1_suppressed=True)
    text = rig_to_yaml(rig)
    assert "grounded: true" in text
    assert "suppressed: true" in text


# evaluate_pose semantics -----------------------------------------------------


def test_suppressed_joint_contributes_no_driven_dof():
    active = evaluate_pose(_prismatic_rig())
    assert "j1.translation" in active.dof_values

    suppressed = evaluate_pose(_prismatic_rig(j1_suppressed=True))
    # The suppressed joint's DOF is not part of the active solve.
    assert "j1.translation" not in suppressed.dof_values
    # The other joint is untouched.
    assert "j2.translation" in suppressed.dof_values


def test_suppressed_relation_not_applied():
    active = evaluate_pose(_gear_rig())
    assert math.isclose(active.dof_values["j2.rotation"], 2.0, abs_tol=TOL)

    suppressed = evaluate_pose(_gear_rig(relation_suppressed=True))
    # Driven DOF falls back to its own neutral (0.0), not the coupling.
    assert math.isclose(
        suppressed.dof_values["j2.rotation"], 0.0, abs_tol=TOL
    )
    # Driver is unchanged.
    assert math.isclose(suppressed.dof_values["j1.rotation"], 1.0, abs_tol=TOL)


def test_relation_on_suppressed_joint_dof_is_skipped():
    # Suppressing the driver's joint removes its DOF from the solve; the
    # relation must be skipped rather than crash on a missing driver.
    rig = _gear_rig()
    joints = dict(rig.joints)
    j1 = joints["j1"]
    joints["j1"] = Joint(
        name=j1.name,
        joint_type=j1.joint_type,
        parent_part=j1.parent_part,
        child_part=j1.child_part,
        dofs=j1.dofs,
        suppressed=True,
    )
    rig = Rig(
        identity=rig.identity,
        parts=rig.parts,
        joints=joints,
        relations=rig.relations,
    )
    pose = evaluate_pose(rig)
    assert "j1.rotation" not in pose.dof_values
    # Driven DOF stays at its own neutral (relation not applied).
    assert math.isclose(pose.dof_values["j2.rotation"], 0.0, abs_tol=TOL)


# resolve_pose semantics ------------------------------------------------------


def _translation(rig: Rig, part: str):
    pose = evaluate_pose(rig)
    return resolve_pose(rig, pose)[part].translation


def test_active_joint_moves_child():
    # Sanity: with no states, the prismatic joints stack (+0.5, then +1.0).
    rig = _prismatic_rig()
    world = resolve_pose(rig, evaluate_pose(rig))
    assert math.isclose(world["arm"].translation[2], 0.5, abs_tol=TOL)
    assert math.isclose(world["hand"].translation[2], 1.0, abs_tol=TOL)


def test_suppressed_joint_does_not_move_child():
    # j1 suppressed → arm has no active incoming joint → identity root.
    rig = _prismatic_rig(j1_suppressed=True)
    world = resolve_pose(rig, evaluate_pose(rig))
    assert world["arm"].translation == IDENTITY.translation
    # hand is still positioned by the (active) j2 relative to arm@identity.
    assert math.isclose(world["hand"].translation[2], 0.5, abs_tol=TOL)


def test_grounded_part_is_identity_root_despite_incoming_joint():
    # arm grounded → fixed root at identity even though j1 feeds into it.
    rig = _prismatic_rig(arm_grounded=True)
    world = resolve_pose(rig, evaluate_pose(rig))
    assert world["arm"].translation == IDENTITY.translation
    # j2 (arm → hand) stays active: hand rides +0.5 off the grounded arm.
    assert math.isclose(world["hand"].translation[2], 0.5, abs_tol=TOL)


def test_suppressed_part_absent_and_its_joints_inactive():
    # hand suppressed → absent from the output; j2 (arm → hand) inactive.
    rig = _prismatic_rig(hand_suppressed=True)
    world = resolve_pose(rig, evaluate_pose(rig))
    assert "hand" not in world
    # arm is still positioned by the active j1.
    assert math.isclose(world["arm"].translation[2], 0.5, abs_tol=TOL)


def test_suppressed_parent_part_orphans_its_children():
    # arm suppressed → arm absent, AND j2 (arm → hand) inactive, so hand
    # has no active incoming joint and floats to the origin (orphan rule).
    rig = _prismatic_rig(arm_suppressed=True)
    world = resolve_pose(rig, evaluate_pose(rig))
    assert "arm" not in world
    assert "hand" in world
    assert world["hand"].translation == IDENTITY.translation


# Loader accept / reject ------------------------------------------------------


_BASE_DOC = """
anima_version: "2.0"
type: character
identity:
  name: test
parts:
  base: {{}}
  arm:{part_states}
joints:
  j1:
    type: prismatic
    parent: base
    child: arm{joint_state}
    dofs:
      travel:
        neutral_m: 0.5
{relations}
"""


def _doc(part_states="", joint_state="", relations=""):
    return _BASE_DOC.format(
        part_states=part_states,
        joint_state=joint_state,
        relations=relations,
    )


def test_loader_accepts_part_states():
    rig = parse_character(
        _doc(part_states="\n    suppressed: true\n    grounded: true")
    )
    assert rig.parts["arm"].suppressed is True
    assert rig.parts["arm"].grounded is True


def test_loader_defaults_states_false():
    rig = parse_character(_doc(part_states=" {}"))
    assert rig.parts["arm"].suppressed is False
    assert rig.parts["arm"].grounded is False
    assert rig.joints["j1"].suppressed is False


def test_loader_accepts_joint_suppressed():
    rig = parse_character(
        _doc(part_states=" {}", joint_state="\n    suppressed: true")
    )
    assert rig.joints["j1"].suppressed is True


def test_loader_rejects_non_bool_part_suppressed():
    with pytest.raises(CharacterFormatError) as excinfo:
        parse_character(_doc(part_states="\n    suppressed: yes-please"))
    assert excinfo.value.path == "parts.arm.suppressed"


def test_loader_rejects_non_bool_part_grounded():
    with pytest.raises(CharacterFormatError) as excinfo:
        parse_character(_doc(part_states="\n    grounded: 3"))
    assert excinfo.value.path == "parts.arm.grounded"


def test_loader_rejects_non_bool_joint_suppressed():
    with pytest.raises(CharacterFormatError) as excinfo:
        parse_character(
            _doc(part_states=" {}", joint_state="\n    suppressed: 1")
        )
    assert excinfo.value.path == "joints.j1.suppressed"


def test_loader_round_trips_relation_suppressed():
    rig = parse_character(rig_to_yaml(_gear_rig(relation_suppressed=True)))
    assert rig.relations[0].suppressed is True


# Bridge surfaces the fields --------------------------------------------------


def test_describe_mate_exposes_suppressed():
    joint = _prismatic_rig(j1_suppressed=True).joints["j1"]
    assert describe_mate(joint)["suppressed"] is True
    other = _prismatic_rig().joints["j1"]
    assert describe_mate(other)["suppressed"] is False


def test_describe_relation_exposes_suppressed():
    rel = _gear_rig(relation_suppressed=True).relations[0]
    assert describe_relation(rel)["suppressed"] is True


def test_rig_summary_exposes_part_states():
    rig = _prismatic_rig(arm_suppressed=True, hand_grounded=True)
    session = Session()
    handle = handle_request(
        session,
        {"id": 1, "method": "load_character",
         "params": {"text": rig_to_yaml(rig)}},
    )
    parts = {p["name"]: p for p in handle["result"]["rig"]["parts"]}
    assert parts["arm"]["suppressed"] is True
    assert parts["hand"]["grounded"] is True
    assert parts["base"]["suppressed"] is False


def test_bridge_dto_round_trip_preserves_states():
    # load_character DTO → rig_from_dict must rebuild the states losslessly.
    rig = _gear_rig(relation_suppressed=True)
    parts = dict(rig.parts)
    parts["arm"] = Part(name="arm", suppressed=True, grounded=False)
    rig = Rig(
        identity=rig.identity,
        parts=parts,
        joints=rig.joints,
        relations=rig.relations,
    )
    session = Session()
    loaded = handle_request(
        session,
        {"id": 1, "method": "load_character",
         "params": {"text": rig_to_yaml(rig)}},
    )
    rebuilt = rig_from_dict(loaded["result"]["rig"])
    assert rebuilt.parts["arm"].suppressed is True
    assert rebuilt.relations[0].suppressed is True
