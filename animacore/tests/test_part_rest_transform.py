"""Part rest transform (location, part-in-character) + the coordinate-frame
model. A part carries a rest transform — ``position_m`` +
``rotation_euler_rad`` — that persists in the ``.character.anima`` and drives
``resolve_pose`` for ROOT and GROUNDED parts; a MATED child is positioned by
its mate, not by its rest transform. Euler is intrinsic XYZ, matching the app.

Stdlib + ``math`` only; tolerances via ``math.isclose``.
"""

import math
from pathlib import Path

from animacore.bridge import Session, handle_request, rig_from_dict
from animacore.kinematics import (
    IDENTITY,
    Transform,
    part_rest_transform,
    resolve_pose,
)
from animacore.loader import CharacterFormatError, parse_character
from animacore.mates import MateControls, MateOffset
from animacore.rig import (
    Identity,
    Joint,
    JointType,
    Part,
    Pose,
    Rig,
    RotationDof,
    evaluate_pose,
)
from animacore.serialize import rig_to_yaml

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "examples"

TOL = 1e-9


def _vclose(a, b, tol=TOL):
    return all(math.isclose(x, y, abs_tol=tol) for x, y in zip(a, b))


# Transform.from_euler_xyz correctness ----------------------------------------


def test_from_euler_xyz_zero_is_identity():
    assert part_rest_transform(Part(name="p")) == IDENTITY
    t = Transform.from_euler_xyz(0.0, 0.0, 0.0)
    assert _vclose(t.rotation, (0.0, 0.0, 0.0, 1.0))


def test_from_euler_xyz_single_axis_rotations():
    # Rz(90°): +X -> +Y.
    tz = Transform.from_euler_xyz(0.0, 0.0, math.pi / 2)
    assert _vclose(tz.apply_point((1.0, 0.0, 0.0)), (0.0, 1.0, 0.0))
    # Rx(90°): +Y -> +Z.
    tx = Transform.from_euler_xyz(math.pi / 2, 0.0, 0.0)
    assert _vclose(tx.apply_point((0.0, 1.0, 0.0)), (0.0, 0.0, 1.0))
    # Ry(90°): +Z -> +X.
    ty = Transform.from_euler_xyz(0.0, math.pi / 2, 0.0)
    assert _vclose(ty.apply_point((0.0, 0.0, 1.0)), (1.0, 0.0, 0.0))


def test_from_euler_xyz_intrinsic_order_rotates_known_vector():
    # Intrinsic XYZ (R = Rx·Ry·Rz): the Z-rotation is applied innermost.
    # rx=90°, ry=0, rz=90°: (1,0,0) --Rz--> (0,1,0) --Rx--> (0,0,1).
    t = Transform.from_euler_xyz(math.pi / 2, 0.0, math.pi / 2)
    assert _vclose(t.apply_point((1.0, 0.0, 0.0)), (0.0, 0.0, 1.0))


# Rest transform round-trip (degrees in file <-> radians in model) ------------


def _rig_with_part(position_m, rotation_euler_rad):
    return Rig(
        identity=Identity(name="anchored"),
        parts={
            "root": Part(
                name="root",
                position_m=position_m,
                rotation_euler_rad=rotation_euler_rad,
            )
        },
    )


def test_rest_transform_round_trips_through_file():
    rotation = tuple(math.radians(d) for d in (10.0, -25.0, 90.0))
    rig = _rig_with_part((0.3, -1.2, 0.75), rotation)
    reloaded = parse_character(rig_to_yaml(rig))
    part = reloaded.parts["root"]
    assert _vclose(part.position_m, (0.3, -1.2, 0.75))
    assert _vclose(part.rotation_euler_rad, rotation, tol=1e-9)


def test_zero_rest_transform_omitted_from_file():
    text = rig_to_yaml(_rig_with_part((0.0, 0.0, 0.0), (0.0, 0.0, 0.0)))
    assert "position_m" not in text
    assert "rotation_euler_deg" not in text


def test_rest_transform_round_trips_through_bridge_dto():
    rotation = (0.1, 0.2, -0.3)
    rig = _rig_with_part((1.0, 2.0, 3.0), rotation)
    session = Session()
    loaded = handle_request(
        session,
        {"id": 0, "method": "load_character",
         "params": {"text": rig_to_yaml(rig)}},
    )
    dto = loaded["result"]["rig"]
    part_dto = dto["parts"][0]
    assert part_dto["position_m"] == [1.0, 2.0, 3.0]
    # Native radians in the DTO.
    assert _vclose(part_dto["rotation_euler_rad"], rotation)
    rebuilt = rig_from_dict(dto).parts["root"]
    assert _vclose(rebuilt.position_m, (1.0, 2.0, 3.0))
    assert _vclose(rebuilt.rotation_euler_rad, rotation)


def test_loader_rejects_malformed_position_with_pathed_error():
    text = (
        "anima_version: '2.0'\ntype: character\n"
        "identity: { name: x }\n"
        "parts: { root: { position_m: [1, 2] } }\n"
    )
    try:
        parse_character(text)
        raise AssertionError("expected CharacterFormatError")
    except CharacterFormatError as error:
        assert error.path == "parts.root.position_m"


# resolve_pose: ROOT / GROUNDED / MATED rules ---------------------------------


def test_root_part_resolves_at_its_rest_transform():
    rotation = (0.0, 0.0, math.pi / 2)
    rig = _rig_with_part((0.5, 0.0, 0.25), rotation)
    world = resolve_pose(rig, Pose(dof_values={}, parameter_values={}))
    assert _vclose(world["root"].translation, (0.5, 0.0, 0.25))
    # Orientation reflects the rest euler: a local +X points to world +Y.
    assert _vclose(
        Transform(world["root"].rotation).apply_point((1.0, 0.0, 0.0)),
        (0.0, 1.0, 0.0),
    )


def test_zero_rest_root_still_resolves_at_identity():
    rig = _rig_with_part((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))
    world = resolve_pose(rig, Pose(dof_values={}, parameter_values={}))
    assert world["root"] == IDENTITY


def _base_child_revolute(child_rest_pos):
    """base (root) -> link (mated by a connectorless revolute w/ offset)."""
    base = Part(name="base", position_m=(1.0, 0.0, 0.0))
    link = Part(name="link", parent="base", position_m=child_rest_pos)
    joint = Joint(
        name="hinge",
        joint_type=JointType.REVOLUTE,
        parent_part="base",
        child_part="link",
        dofs=(RotationDof(name="rotation"),),
        controls=MateControls(
            None, None, offset=MateOffset(enabled=True, translation_m=(0.2, 0.0, 0.0))
        ),
    )
    return Rig(
        identity=Identity(name="hinged"),
        parts={"base": base, "link": link},
        joints={"hinge": joint},
    )


def test_root_rest_transform_propagates_to_mated_child():
    rig = _base_child_revolute((5.0, 5.0, 5.0))
    world = resolve_pose(rig, Pose(dof_values={}, parameter_values={}))
    # base sits at its rest position.
    assert _vclose(world["base"].translation, (1.0, 0.0, 0.0))
    # link is placed by its mate on top of base's rest transform, NOT by
    # its own (5,5,5) rest position: base(1,0,0) + offset(0.2,0,0) = (1.2,0,0).
    assert _vclose(world["link"].translation, (1.2, 0.0, 0.0))


def test_mated_child_rest_transform_is_not_double_applied():
    # Two rigs differing only in the mated child's rest position resolve
    # the child identically — the mate owns its placement.
    a = resolve_pose(
        _base_child_revolute((0.0, 0.0, 0.0)),
        Pose(dof_values={}, parameter_values={}),
    )
    b = resolve_pose(
        _base_child_revolute((9.0, -3.0, 2.0)),
        Pose(dof_values={}, parameter_values={}),
    )
    assert _vclose(a["link"].translation, b["link"].translation)
    assert _vclose(a["link"].rotation, b["link"].rotation)


def test_grounded_part_sits_at_its_rest_transform():
    # link is grounded: ground overrides the incoming joint, pinning it at
    # its authored rest transform (not positioned by the hinge).
    rig = _base_child_revolute((3.0, -1.0, 0.5))
    grounded = Rig(
        identity=rig.identity,
        parts={
            "base": rig.parts["base"],
            "link": Part(
                name="link", parent="base",
                position_m=(3.0, -1.0, 0.5), grounded=True,
            ),
        },
        joints=rig.joints,
    )
    world = resolve_pose(grounded, Pose(dof_values={}, parameter_values={}))
    assert _vclose(world["link"].translation, (3.0, -1.0, 0.5))


# Example: the anchored pan-tilt head assembly --------------------------------


def test_pan_tilt_head_base_resolves_at_authored_rest():
    rig = parse_character(
        (EXAMPLES_DIR / "pan_tilt_head.character.anima").read_text()
    )
    base = rig.parts["base"]
    assert _vclose(base.position_m, (0.0, 0.0, 0.25))
    assert _vclose(base.rotation_euler_rad, (0.0, 0.0, math.radians(30.0)))
    world = resolve_pose(rig, evaluate_pose(rig, "look_around", 0.0))
    # The whole assembly is anchored at the base's rest position: base and
    # its (connectorless, zero-DOF-at-t0) mated children share the origin.
    assert _vclose(world["base"].translation, (0.0, 0.0, 0.25))
    assert _vclose(world["yoke"].translation, (0.0, 0.0, 0.25))
