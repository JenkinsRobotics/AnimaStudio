"""Spatial pose resolution: quaternion/Transform math, the connector
coincidence convention, per-mate motion, and forward kinematics.

Stdlib + ``math`` only — no numpy. Tolerances via ``math.isclose`` /
absolute ``abs`` checks.
"""

import json
import math
from pathlib import Path

from animacore.bridge import Session, handle_request
from animacore.kinematics import (
    IDENTITY,
    Transform,
    child_in_parent,
    connector_frame,
    mate_motion,
    quat_from_axis_angle,
    quat_multiply,
    resolve_pose,
    transform_to_json,
)
from animacore.loader import parse_character
from animacore.mates import (
    MateConnector,
    MateControls,
    MateOffset,
)
from animacore.rig import (
    Identity,
    Joint,
    JointType,
    Part,
    Pose,
    RotationDof,
    TranslationDof,
    Rig,
    evaluate_pose,
)

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "examples"
ARM = (EXAMPLES_DIR / "six_axis_arm.character.anima").read_text()

TOL = 1e-9


def _vclose(a, b, tol=TOL):
    return all(math.isclose(x, y, abs_tol=tol) for x, y in zip(a, b))


# Quaternion / Transform correctness ------------------------------------------


def test_identity_apply_point_is_noop():
    assert _vclose(IDENTITY.apply_point((1.0, 2.0, 3.0)), (1.0, 2.0, 3.0))


def test_axis_angle_rotates_known_vector():
    # 90° about Z maps +X onto +Y.
    t = Transform.from_axis_angle((0.0, 0.0, 1.0), math.pi / 2)
    assert _vclose(t.apply_point((1.0, 0.0, 0.0)), (0.0, 1.0, 0.0))
    # 90° about X maps +Y onto +Z.
    t = Transform.from_axis_angle((1.0, 0.0, 0.0), math.pi / 2)
    assert _vclose(t.apply_point((0.0, 1.0, 0.0)), (0.0, 0.0, 1.0))


def test_from_translation_apply_point():
    t = Transform.from_translation((1.0, -2.0, 0.5))
    assert _vclose(t.apply_point((0.0, 0.0, 0.0)), (1.0, -2.0, 0.5))
    assert _vclose(t.apply_point((3.0, 3.0, 3.0)), (4.0, 1.0, 3.5))


def test_compose_applies_b_then_a():
    a = Transform.from_translation((10.0, 0.0, 0.0))
    b = Transform.from_axis_angle((0.0, 0.0, 1.0), math.pi / 2)
    composed = Transform.compose(a, b)
    # b rotates (1,0,0)->(0,1,0), then a translates by (10,0,0).
    assert _vclose(composed.apply_point((1.0, 0.0, 0.0)), (10.0, 1.0, 0.0))


def test_compose_associativity():
    a = Transform.from_axis_angle((0.0, 1.0, 0.0), 0.7)
    b = Transform(quat_from_axis_angle((1.0, 0.0, 0.0), 0.3), (1.0, 2.0, 3.0))
    c = Transform.from_translation((-1.0, 0.5, 4.0))
    left = Transform.compose(Transform.compose(a, b), c)
    right = Transform.compose(a, Transform.compose(b, c))
    p = (0.3, -1.2, 2.5)
    assert _vclose(left.apply_point(p), right.apply_point(p))


def test_inverse_round_trips_to_identity():
    t = Transform(quat_from_axis_angle((0.4, -0.2, 1.0), 1.1), (2.0, -3.0, 0.5))
    both = Transform.compose(t.inverse(), t)
    p = (1.3, -0.7, 2.1)
    assert _vclose(both.apply_point(p), p)
    other = Transform.compose(t, t.inverse())
    assert _vclose(other.apply_point(p), p)


def test_quat_multiply_matches_sequential_rotation():
    qz = quat_from_axis_angle((0.0, 0.0, 1.0), math.pi / 2)
    qx = quat_from_axis_angle((1.0, 0.0, 0.0), math.pi / 2)
    combined = Transform(quat_multiply(qz, qx))
    seq = Transform.compose(Transform(qz), Transform(qx))
    p = (0.0, 0.0, 1.0)
    assert _vclose(combined.apply_point(p), seq.apply_point(p))


# Connector frame -------------------------------------------------------------


def test_connector_frame_canonical_axes():
    # Canonical connector: Z=+Z, X=+X at origin (5,0,0).
    conn = MateConnector(
        part="p",
        origin_m=(5.0, 0.0, 0.0),
        primary_axis=(0.0, 0.0, 1.0),
        secondary_axis=(1.0, 0.0, 0.0),
    )
    frame = connector_frame(conn)
    assert _vclose(frame.translation, (5.0, 0.0, 0.0))
    # Local X/Y/Z map to world X/Y/Z.
    assert _vclose(frame.apply_point((1.0, 0.0, 0.0)), (6.0, 0.0, 0.0))
    rot = Transform(frame.rotation)
    assert _vclose(rot.apply_point((0.0, 0.0, 1.0)), (0.0, 0.0, 1.0))
    assert _vclose(rot.apply_point((0.0, 1.0, 0.0)), (0.0, 1.0, 0.0))


def test_connector_frame_gram_schmidt_orthonormalizes_secondary():
    # Secondary not perpendicular to primary: it is projected ⊥ Z.
    conn = MateConnector(
        part="p",
        primary_axis=(0.0, 0.0, 1.0),
        secondary_axis=(1.0, 0.0, 0.5),
    )
    frame = connector_frame(conn)
    x = Transform(frame.rotation).apply_point((1.0, 0.0, 0.0))
    z = Transform(frame.rotation).apply_point((0.0, 0.0, 1.0))
    assert _vclose(x, (1.0, 0.0, 0.0))  # 0.5*Z component removed
    assert _vclose(z, (0.0, 0.0, 1.0))


def test_connector_frame_flipped_negates_z():
    conn = MateConnector(
        part="p",
        primary_axis=(0.0, 0.0, 1.0),
        secondary_axis=(1.0, 0.0, 0.0),
        flipped=True,
    )
    frame = connector_frame(conn)
    z = Transform(frame.rotation).apply_point((0.0, 0.0, 1.0))
    assert _vclose(z, (0.0, 0.0, -1.0))


# child_in_parent convention --------------------------------------------------


def _revolute(name, parent, child, controls, neutral=0.0):
    return Joint(
        name=name,
        joint_type=JointType.REVOLUTE,
        parent_part=parent,
        child_part=child,
        dofs=(RotationDof(name="rotation", neutral_radians=neutral),),
        controls=controls,
    )


def test_coincidence_zero_dof_zero_offset_opposes_z():
    # Two connectors on different origins; at zero DOF/offset the child
    # connector origin maps onto the parent connector origin, Z opposed.
    conn_a = MateConnector(
        part="base",
        origin_m=(0.0, 0.0, 1.0),
        primary_axis=(0.0, 0.0, 1.0),
        secondary_axis=(1.0, 0.0, 0.0),
    )
    conn_b = MateConnector(
        part="link",
        origin_m=(0.0, 0.0, 2.0),
        primary_axis=(0.0, 0.0, 1.0),
        secondary_axis=(1.0, 0.0, 0.0),
    )
    joint = _revolute("j", "base", "link", MateControls(conn_a, conn_b))
    cip = child_in_parent(joint, {"rotation": 0.0})

    # The child connector origin (in child-local frame) maps onto the
    # parent connector origin (in parent-local frame).
    child_conn_origin = conn_b.origin_m
    mapped = cip.apply_point(child_conn_origin)
    assert _vclose(mapped, conn_a.origin_m)

    # Child connector Z (fixed in child part) opposes parent connector Z.
    cframe_b = connector_frame(conn_b)
    child_z_in_child = Transform(cframe_b.rotation).apply_point((0.0, 0.0, 1.0))
    child_z_in_parent = Transform(cip.rotation).apply_point(child_z_in_child)
    assert _vclose(child_z_in_parent, (0.0, 0.0, -1.0))


def test_flip_primary_axis_aligns_z_instead_of_opposing():
    conn_a = MateConnector(part="base", primary_axis=(0.0, 0.0, 1.0),
                           secondary_axis=(1.0, 0.0, 0.0))
    conn_b = MateConnector(part="link", primary_axis=(0.0, 0.0, 1.0),
                           secondary_axis=(1.0, 0.0, 0.0))
    joint = _revolute("j", "base", "link",
                      MateControls(conn_a, conn_b, flip_primary_axis=True))
    cip = child_in_parent(joint, {"rotation": 0.0})
    child_z = Transform(cip.rotation).apply_point((0.0, 0.0, 1.0))
    assert _vclose(child_z, (0.0, 0.0, 1.0))  # aligned, not opposed


def test_revolute_motion_rotates_point_about_connector_z():
    # Connector at (0,0,0) with Z up; rotating pi/2 sends a point on the
    # connector X axis to the connector Y axis, in the parent frame.
    conn_a = MateConnector(part="base", origin_m=(0.0, 0.0, 0.0),
                           primary_axis=(0.0, 0.0, 1.0),
                           secondary_axis=(1.0, 0.0, 0.0))
    conn_b = MateConnector(part="link", origin_m=(0.0, 0.0, 0.0),
                           primary_axis=(0.0, 0.0, 1.0),
                           secondary_axis=(1.0, 0.0, 0.0))
    joint = _revolute("j", "base", "link", MateControls(conn_a, conn_b))
    cip0 = child_in_parent(joint, {"rotation": 0.0})
    cip90 = child_in_parent(joint, {"rotation": math.pi / 2})
    # A point fixed at connector X (child frame after opposition) — track
    # how a generic point on the rotation plane moves. Use a point on the
    # +X axis in the child part.
    p = (1.0, 0.0, 0.0)
    moved0 = cip0.apply_point(p)
    moved90 = cip90.apply_point(p)
    # The two poses differ (the DOF actually moves the part).
    assert not _vclose(moved0, moved90)
    # Rotation is about Z: the Z coordinate is preserved.
    assert math.isclose(moved0[2], moved90[2], abs_tol=TOL)


def test_slider_translates_along_connector_z():
    conn_a = MateConnector(part="base", origin_m=(0.0, 0.0, 0.0),
                           primary_axis=(0.0, 0.0, 1.0),
                           secondary_axis=(1.0, 0.0, 0.0))
    conn_b = MateConnector(part="link", origin_m=(0.0, 0.0, 0.0),
                           primary_axis=(0.0, 0.0, 1.0),
                           secondary_axis=(1.0, 0.0, 0.0))
    joint = Joint(
        name="s",
        joint_type=JointType.PRISMATIC,
        parent_part="base",
        child_part="link",
        dofs=(TranslationDof(name="translation"),),
        controls=MateControls(conn_a, conn_b),
    )
    origin0 = child_in_parent(joint, {"translation": 0.0}).apply_point((0.0, 0.0, 0.0))
    origin1 = child_in_parent(joint, {"translation": 0.25}).apply_point((0.0, 0.0, 0.0))
    delta = (origin1[0] - origin0[0], origin1[1] - origin0[1], origin1[2] - origin0[2])
    # Motion is along connector Z. After opposition the child Z is -Z of
    # the parent frame, so a positive slide moves along ±Z only (X,Y=0).
    assert math.isclose(delta[0], 0.0, abs_tol=TOL)
    assert math.isclose(delta[1], 0.0, abs_tol=TOL)
    assert abs(delta[2]) > 0.1


def test_pin_slot_translates_x_and_rotates_z():
    # No connectors: motion at the part origin. Pin-slot rotates about Z
    # and translates along X (the two distinct canonical axes).
    joint = Joint(
        name="ps",
        joint_type=JointType.PIN_SLOT,
        parent_part="base",
        child_part="link",
        dofs=(RotationDof(name="rotation"), TranslationDof(name="translation")),
        controls=None,
    )
    # Pure translation along X.
    only_x = child_in_parent(joint, {"rotation": 0.0, "translation": 0.4})
    assert _vclose(only_x.apply_point((0.0, 0.0, 0.0)), (0.4, 0.0, 0.0))
    # Pure rotation about Z.
    only_rot = child_in_parent(joint, {"rotation": math.pi / 2, "translation": 0.0})
    assert _vclose(only_rot.apply_point((1.0, 0.0, 0.0)), (0.0, 1.0, 0.0))
    # Rotation is about Z: Z preserved.
    assert math.isclose(only_rot.apply_point((1.0, 0.0, 0.0))[2], 0.0, abs_tol=TOL)


def test_no_connector_joint_offset_then_motion():
    # child_in_parent = Offset ∘ Motion when no connectors.
    offset = MateOffset(enabled=True, translation_m=(1.0, 0.0, 0.0))
    joint = _revolute("j", "base", "link",
                      MateControls(None, None, offset=offset))
    cip = child_in_parent(joint, {"rotation": 0.0})
    assert _vclose(cip.apply_point((0.0, 0.0, 0.0)), (1.0, 0.0, 0.0))


def test_fastened_no_dof_is_rigid_alignment():
    conn_a = MateConnector(part="base", origin_m=(0.0, 0.0, 1.0),
                           primary_axis=(0.0, 0.0, 1.0),
                           secondary_axis=(1.0, 0.0, 0.0))
    conn_b = MateConnector(part="link", origin_m=(0.0, 0.0, 0.5),
                           primary_axis=(0.0, 0.0, 1.0),
                           secondary_axis=(1.0, 0.0, 0.0))
    joint = Joint(
        name="f",
        joint_type=JointType.FASTENED,
        parent_part="base",
        child_part="link",
        dofs=(),
        controls=MateControls(conn_a, conn_b),
    )
    cip = child_in_parent(joint, {})
    # Child connector origin maps onto parent connector origin (rigid).
    assert _vclose(cip.apply_point(conn_b.origin_m), conn_a.origin_m)


def test_mate_motion_missing_dof_uses_neutral():
    joint = _revolute("j", "base", "link", None, neutral=0.5)
    motion = mate_motion(joint, {})  # DOF absent -> neutral 0.5 rad
    expected = Transform.from_axis_angle((0.0, 0.0, 1.0), 0.5)
    p = (1.0, 0.0, 0.0)
    assert _vclose(motion.apply_point(p), expected.apply_point(p))


# Forward kinematics ----------------------------------------------------------


def _chain_rig():
    parts = {n: Part(name=n) for n in ("base", "a", "b")}
    # base->a translate/rotate; a->b translate along X then rotate.
    off_a = MateOffset(enabled=True, translation_m=(1.0, 0.0, 0.0))
    off_b = MateOffset(enabled=True, translation_m=(1.0, 0.0, 0.0))
    j1 = Joint(
        name="j1", joint_type=JointType.REVOLUTE, parent_part="base",
        child_part="a", dofs=(RotationDof(name="rotation"),),
        controls=MateControls(None, None, offset=off_a),
    )
    j2 = Joint(
        name="j2", joint_type=JointType.REVOLUTE, parent_part="a",
        child_part="b", dofs=(RotationDof(name="rotation"),),
        controls=MateControls(None, None, offset=off_b),
    )
    return Rig(
        identity=Identity(name="chain"),
        parts=parts,
        joints={"j1": j1, "j2": j2},
    )


def test_fk_two_joint_chain_composes():
    rig = _chain_rig()
    # j1 rotates 90° about Z, j2 rotates 0.
    pose = Pose(
        dof_values={"j1.rotation": math.pi / 2, "j2.rotation": 0.0},
        parameter_values={},
    )
    world = resolve_pose(rig, pose)
    assert _vclose(world["base"].translation, (0.0, 0.0, 0.0))
    # a: offset (1,0,0) after 90° rotation of base(identity) -> (1,0,0).
    # child_in_parent(j1) = Offset∘Motion: rotate then translate? No:
    # Offset∘Motion applies Motion(rot) then Offset(translate). At the
    # part origin the point (0,0,0) -> rot -> (0,0,0) -> +（1,0,0).
    assert _vclose(world["a"].translation, (1.0, 0.0, 0.0))
    # b = world[a] ∘ (Offset∘Motion). world[a] rotation is 90° about Z,
    # translation (1,0,0). b origin = a.apply((1,0,0)) since j2 offset
    # (1,0,0), motion 0. a rotates (1,0,0)->(0,1,0), +trans (1,0,0).
    assert _vclose(world["b"].translation, (1.0, 1.0, 0.0))


def test_fk_roots_at_identity():
    rig = _chain_rig()
    pose = Pose(dof_values={}, parameter_values={})
    world = resolve_pose(rig, pose)
    assert world["base"] == IDENTITY


def test_fk_deterministic():
    rig = _chain_rig()
    pose = Pose(
        dof_values={"j1.rotation": 0.3, "j2.rotation": -0.4},
        parameter_values={},
    )
    a = resolve_pose(rig, pose)
    b = resolve_pose(rig, pose)
    for name in a:
        assert a[name].rotation == b[name].rotation
        assert a[name].translation == b[name].translation


def test_offset_applied_in_fk():
    rig = _chain_rig()
    pose = Pose(dof_values={}, parameter_values={})
    world = resolve_pose(rig, pose)
    # With zero rotation, both offsets stack along X.
    assert _vclose(world["a"].translation, (1.0, 0.0, 0.0))
    assert _vclose(world["b"].translation, (2.0, 0.0, 0.0))


# transform_to_json -----------------------------------------------------------


def test_transform_to_json_shape_and_w_last():
    t = Transform(quat_from_axis_angle((0.0, 0.0, 1.0), math.pi / 2),
                  (1.0, 2.0, 3.0))
    js = transform_to_json(t)
    assert js["position"] == [1.0, 2.0, 3.0]
    assert len(js["orientation"]) == 4
    # 90° about Z -> (0,0,sin45,cos45); w (real) is last.
    x, y, z, w = js["orientation"]
    assert math.isclose(z, math.sin(math.pi / 4), abs_tol=TOL)
    assert math.isclose(w, math.cos(math.pi / 4), abs_tol=TOL)
    assert math.isclose(x, 0.0, abs_tol=TOL)
    assert math.isclose(y, 0.0, abs_tol=TOL)


# End-to-end via the bridge ---------------------------------------------------


def _bridge_resolve(session, handle, clip, time_s):
    response = handle_request(
        session,
        {"id": 1, "method": "resolve_pose",
         "params": {"handle": handle, "clip": clip, "time_s": time_s}},
    )
    assert response["ok"], response
    return response["result"]["parts"]


def test_bridge_resolve_pose_arm_every_part_present_and_moves():
    session = Session()
    loaded = handle_request(
        session,
        {"id": 0, "method": "load_character", "params": {"text": ARM}},
    )
    handle = loaded["result"]["handle"]
    rig = parse_character(ARM)

    at0 = _bridge_resolve(session, handle, "pick", 0.0)
    at_mid = _bridge_resolve(session, handle, "pick", 1.0)

    # Every part is present in the resolved pose.
    for part_name in rig.parts:
        assert part_name in at0
        assert part_name in at_mid
        assert set(at0[part_name]) == {"position", "orientation"}

    # A downstream part actually moved between t=0 and t=mid (the base
    # yaw + shoulder + elbow all change, so the tool flange reorients).
    flange0 = at0["tool_flange"]
    flange_mid = at_mid["tool_flange"]
    moved = not _vclose(flange0["orientation"], flange_mid["orientation"],
                        tol=1e-6) or not _vclose(
        flange0["position"], flange_mid["position"], tol=1e-6)
    assert moved


def test_bridge_resolve_pose_matches_direct_call():
    session = Session()
    loaded = handle_request(
        session,
        {"id": 0, "method": "load_character", "params": {"text": ARM}},
    )
    handle = loaded["result"]["handle"]
    rig = parse_character(ARM)
    pose = evaluate_pose(rig, "pick", 0.7)
    direct = {n: transform_to_json(t) for n, t in resolve_pose(rig, pose).items()}
    via_bridge = _bridge_resolve(session, handle, "pick", 0.7)
    assert json.loads(json.dumps(direct)) == via_bridge


def test_bridge_resolve_pose_unknown_handle():
    session = Session()
    response = handle_request(
        session,
        {"id": 9, "method": "resolve_pose", "params": {"handle": "nope"}},
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "unknown_handle"


def test_resolve_pose_in_capabilities():
    from animacore.bridge import CAPABILITIES

    assert "resolve_pose" in CAPABILITIES
