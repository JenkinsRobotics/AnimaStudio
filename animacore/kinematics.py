"""Spatial pose resolution: forward kinematics over the typed-mate rig.

This is the canonical kinematic engine — the single home for the mate
motion math the Swift ``RigPoseResolver`` / ``MateConnectorMath`` used to
own (Studio_Bridge.md migration step 2). Each mate actually *moves* the
child part relative to the parent, about/along the **mate connector as
the relative origin**, per the mate's DOF, chained through the rig.
Everything is kinematic — physics/dynamics stays deferred per AGENTS.md.

Convention (matches the Swift "opposing primary axes" default, made
canonical here — see ``child_in_parent``):

- A ``MateConnector`` is a part-local frame: ``origin_m`` plus a basis
  built with ``Z = primary_axis``, ``X = secondary_axis`` (Gram-Schmidt
  ⊥ Z), ``Y = Z × X`` (right-handed). ``flipped`` negates Z first.
- With zero DOF and zero offset the child connector coincides with the
  parent connector, primary(Z) axes **opposed** and secondary(X)
  aligned — the CAD "first selection moves onto the second" default.
- ``child_in_parent = C_A ∘ ALIGN ∘ Offset ∘ Motion ∘ inverse(C_B)``,
  where ``C_A``/``C_B`` are the parent-/child-local connector frames,
  ``ALIGN`` is 180° about X (opposing Z) unless ``flip_primary_axis``
  plus a Z rotation of ``secondary_axis_rotation_deg``, ``Offset`` is
  the as-mated trim, and ``Motion`` is the DOF-driven motion. A joint
  with no connectors puts motion at the part origin
  (``child_in_parent = Offset ∘ Motion``).

Stdlib + ``math`` only — no numpy. Rotations are unit quaternions
stored ``(x, y, z, w)`` (real part last, matching RealityKit
``simd_quatf(ix, iy, iz, r)``); translations are metres.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from animacore.mates import JOINT_TYPE_DOF_TEMPLATES, JointType, MateOffset

Vec3 = tuple[float, float, float]
Quat = tuple[float, float, float, float]  # (x, y, z, w), w = real part

_EPS = 1e-12

_AXIS_UNIT: dict[str, Vec3] = {
    "x": (1.0, 0.0, 0.0),
    "y": (0.0, 1.0, 0.0),
    "z": (0.0, 0.0, 1.0),
}


# Vector helpers --------------------------------------------------------------


def _sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _scale(a: Vec3, s: float) -> Vec3:
    return (a[0] * s, a[1] * s, a[2] * s)


def _dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a: Vec3, b: Vec3) -> Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def _normalize_vec(v: Vec3, fallback: Vec3 = (0.0, 0.0, 1.0)) -> Vec3:
    length = math.sqrt(_dot(v, v))
    if length <= _EPS:
        return fallback
    return (v[0] / length, v[1] / length, v[2] / length)


# Quaternion helpers ((x, y, z, w), w real) -----------------------------------


def quat_normalize(q: Quat) -> Quat:
    """Return ``q`` scaled to unit length (identity if degenerate)."""
    length = math.sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3])
    if length <= _EPS:
        return (0.0, 0.0, 0.0, 1.0)
    return (q[0] / length, q[1] / length, q[2] / length, q[3] / length)


def quat_conjugate(q: Quat) -> Quat:
    """The conjugate ``(-x, -y, -z, w)`` — the inverse for a unit quat."""
    return (-q[0], -q[1], -q[2], q[3])


def quat_multiply(a: Quat, b: Quat) -> Quat:
    """Hamilton product ``a * b`` (apply ``b`` then ``a`` as rotations)."""
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def quat_from_axis_angle(axis: Vec3, radians: float) -> Quat:
    """Unit quaternion rotating ``radians`` about ``axis`` (auto-normalized)."""
    unit = _normalize_vec(axis)
    half = radians / 2.0
    s = math.sin(half)
    return (unit[0] * s, unit[1] * s, unit[2] * s, math.cos(half))


def quat_rotate_vector(q: Quat, v: Vec3) -> Vec3:
    """Rotate the 3-vector ``v`` by unit quaternion ``q``."""
    rotated = quat_multiply(quat_multiply(q, (v[0], v[1], v[2], 0.0)),
                            quat_conjugate(q))
    return (rotated[0], rotated[1], rotated[2])


def _quat_from_basis(x: Vec3, y: Vec3, z: Vec3) -> Quat:
    """Quaternion for the rotation whose columns are basis vectors x, y, z.

    (``x``/``y``/``z`` are the world directions of the frame's local
    X/Y/Z axes; Shepperd's numerically stable method.)
    """
    m00, m10, m20 = x
    m01, m11, m21 = y
    m02, m12, m22 = z
    trace = m00 + m11 + m22
    if trace > 0.0:
        s = math.sqrt(trace + 1.0) * 2.0
        w = 0.25 * s
        qx = (m21 - m12) / s
        qy = (m02 - m20) / s
        qz = (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2.0
        w = (m21 - m12) / s
        qx = 0.25 * s
        qy = (m01 + m10) / s
        qz = (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2.0
        w = (m02 - m20) / s
        qx = (m01 + m10) / s
        qy = 0.25 * s
        qz = (m12 + m21) / s
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2.0
        w = (m10 - m01) / s
        qx = (m02 + m20) / s
        qy = (m12 + m21) / s
        qz = 0.25 * s
    return quat_normalize((qx, qy, qz, w))


# Rigid transform -------------------------------------------------------------


@dataclass(frozen=True)
class Transform:
    """A rigid transform: unit-quaternion rotation + metre translation.

    ``rotation`` is ``(x, y, z, w)`` (real part last); ``translation``
    is metres. ``apply_point(p) = rotate(p) + translation``.
    """

    rotation: Quat = (0.0, 0.0, 0.0, 1.0)
    translation: Vec3 = (0.0, 0.0, 0.0)

    @staticmethod
    def from_translation(v: Vec3) -> Transform:
        """A pure translation (identity rotation)."""
        return Transform((0.0, 0.0, 0.0, 1.0), (float(v[0]), float(v[1]), float(v[2])))

    @staticmethod
    def from_axis_angle(axis_xyz: Vec3, radians: float) -> Transform:
        """A pure rotation of ``radians`` about ``axis_xyz`` (no translation)."""
        return Transform(quat_from_axis_angle(axis_xyz, radians), (0.0, 0.0, 0.0))

    @staticmethod
    def compose(a: Transform, b: Transform) -> Transform:
        """``a ∘ b``: apply ``b`` then ``a`` (``a.apply(b.apply(p))``)."""
        rotation = quat_multiply(a.rotation, b.rotation)
        translation = _add(quat_rotate_vector(a.rotation, b.translation),
                          a.translation)
        return Transform(rotation, translation)

    def inverse(self) -> Transform:
        """The inverse transform (``compose(t.inverse(), t) == IDENTITY``)."""
        inv_rotation = quat_conjugate(quat_normalize(self.rotation))
        inv_translation = _scale(quat_rotate_vector(inv_rotation, self.translation), -1.0)
        return Transform(inv_rotation, inv_translation)

    def apply_point(self, p: Vec3) -> Vec3:
        """Map point ``p``: ``rotate(p) + translation``."""
        return _add(quat_rotate_vector(self.rotation, p), self.translation)


def _add(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


# The shared identity transform.
IDENTITY = Transform()
Transform.IDENTITY = IDENTITY  # type: ignore[attr-defined]


# Connector, offset, motion ---------------------------------------------------


def connector_frame(connector) -> Transform:
    """The part-local frame of a ``MateConnector`` as a ``Transform``.

    Translation = ``origin_m``. Rotation from the orthonormal basis
    ``Z = normalize(primary_axis)`` (negated first when ``flipped``),
    ``X = normalize(secondary made ⊥ Z)``, ``Y = Z × X``.
    """
    z = _normalize_vec(connector.primary_axis)
    if connector.flipped:
        z = _scale(z, -1.0)
    secondary = connector.secondary_axis
    x = _normalize_vec(_sub(secondary, _scale(z, _dot(secondary, z))),
                       fallback=(1.0, 0.0, 0.0))
    y = _normalize_vec(_cross(z, x), fallback=(0.0, 1.0, 0.0))
    rotation = _quat_from_basis(x, y, z)
    origin = connector.origin_m
    return Transform(rotation, (float(origin[0]), float(origin[1]), float(origin[2])))


def mate_offset_transform(offset: MateOffset) -> Transform:
    """The as-mated offset as a ``Transform`` (identity when disabled).

    Enabled → ``translate(translation_m) ∘ rotate(rotation_axis,
    rotation_radians)`` — the rotation is applied first, then the
    translation (both in the aligned connector frame).
    """
    if not offset.enabled:
        return IDENTITY
    rotation = Transform.from_axis_angle(
        _AXIS_UNIT[offset.rotation_axis.value], offset.rotation_radians
    )
    translation = Transform.from_translation(offset.translation_m)
    return Transform.compose(translation, rotation)


def _joint_dof_axes(joint) -> list[tuple[str, str, str]]:
    """``(dof_name, dof_kind, canonical_axis)`` for this joint, in order.

    The canonical axis is the connector-frame axis the DOF acts on
    (revolute rotates about Z, a slider travels along Z, pin-slot
    translates along X) — from ``JOINT_TYPE_DOF_TEMPLATES``, never the
    DOF's own stored vector. Author renames keep the template order and
    kinds, so zipping ``joint.dofs`` with the template is safe.
    """
    template = JOINT_TYPE_DOF_TEMPLATES[joint.joint_type]
    return [
        (dof.name, dof.kind.value, axis)
        for dof, (_, _, axis) in zip(joint.dofs, template)
    ]


def mate_motion(joint, dof_values) -> Transform:
    """The DOF-driven motion for a joint, composed in template order.

    A rotation DOF (value θ radians) rotates θ about its canonical axis;
    a translation DOF (value d metres) translates d along its canonical
    axis. ``dof_values`` is keyed by DOF name for this joint; a missing
    DOF uses its neutral.
    """
    neutral_by_name = {dof.name: dof.neutral for dof in joint.dofs}
    motion = IDENTITY
    for name, kind, axis in _joint_dof_axes(joint):
        value = dof_values.get(name, neutral_by_name[name])
        unit = _AXIS_UNIT[axis]
        if kind == "rotation":
            sub = Transform.from_axis_angle(unit, value)
        else:
            sub = Transform.from_translation(_scale(unit, value))
        motion = Transform.compose(motion, sub)
    return motion


def child_in_parent(joint, dof_values) -> Transform:
    """The child part's transform relative to the parent part.

    Connector-authored:
    ``C_A ∘ ALIGN ∘ Offset ∘ Motion ∘ inverse(C_B)`` — the child
    connector coincides with the parent connector with primary(Z)
    opposed and secondary(X) aligned at zero DOF/offset. ``ALIGN`` is
    180° about X (opposing Z) unless ``flip_primary_axis``, plus a Z
    rotation of ``secondary_axis_rotation_deg``.

    No connectors (``controls is None`` or a connector is ``None``):
    motion happens at the part origin, ``Offset ∘ Motion``. Fastened
    with no DOF reduces to the rigid alignment (``Motion == IDENTITY``).

    Geometry-constraint mates (Kinematics.md "Mate categories"):
    ``WIDTH`` resolves exactly like a 0-DOF rigid mate through the
    connector path below — its two connectors are the app-computed
    midplanes, so ``C_A ∘ ALIGN ∘ inverse(C_B)`` places the child at the
    centered position (no offset, no motion). ``TANGENT`` is
    non-driving: the engine has no geometry kernel, so it leaves the
    child at the parent frame and Studio resolves the surface contact.
    """
    if joint.joint_type is JointType.TANGENT:
        # ponytail: TANGENT is a geometry-constraint mate whose contact
        # surfaces live app-side (RealityKit), not in this abstract
        # engine — there is no geometry kernel here to compute the
        # contact, and Onshape says don't drive with it. So the engine
        # does NOT invent contact math: the child sits at the parent
        # frame (identity relative) and Studio resolves it geometrically.
        return IDENTITY

    controls = joint.controls
    motion = mate_motion(joint, dof_values)
    offset = mate_offset_transform(controls.offset) if controls else IDENTITY

    if (
        controls is None
        or controls.connector_a is None
        or controls.connector_b is None
    ):
        return Transform.compose(offset, motion)

    c_a = connector_frame(controls.connector_a)
    c_b = connector_frame(controls.connector_b)
    if controls.flip_primary_axis:
        base_align = IDENTITY
    else:
        base_align = Transform.from_axis_angle((1.0, 0.0, 0.0), math.pi)
    secondary = Transform.from_axis_angle(
        (0.0, 0.0, 1.0), math.radians(controls.secondary_axis_rotation_deg)
    )
    align = Transform.compose(base_align, secondary)

    result = Transform.compose(c_a, align)
    result = Transform.compose(result, offset)
    result = Transform.compose(result, motion)
    result = Transform.compose(result, c_b.inverse())
    return result


# Forward kinematics ----------------------------------------------------------


def resolve_pose(rig, pose) -> dict[str, Transform]:
    """Forward kinematics over the joint graph: each part's world transform.

    A part that is no joint's ``child_part`` is a ROOT at ``IDENTITY``
    (parts carry no rest transform). For each joint,
    ``world[child] = compose(world[parent], child_in_parent(joint, ...))``,
    pulling the joint's DOF values from ``pose.dof_values`` (keyed
    ``"<joint>.<dof>"``). The graph is acyclic (rig-validated);
    parents are resolved before children by repeated passes.
    Deterministic — parts and joints keep their rig order.
    """
    joint_by_child: dict[str, object] = {}
    for joint in rig.joints.values():
        joint_by_child.setdefault(joint.child_part, joint)

    world: dict[str, Transform] = {}
    for part_name in rig.parts:
        if part_name not in joint_by_child:
            world[part_name] = IDENTITY

    dof_values = pose.dof_values
    pending = list(rig.joints.values())
    while pending:
        progressed = False
        still_pending: list[object] = []
        for joint in pending:
            parent_world = world.get(joint.parent_part)
            if parent_world is None:
                still_pending.append(joint)
                continue
            joint_dofs = {
                dof.name: dof_values.get(f"{joint.name}.{dof.name}", dof.neutral)
                for dof in joint.dofs
            }
            world[joint.child_part] = Transform.compose(
                parent_world, child_in_parent(joint, joint_dofs)
            )
            progressed = True
        if not progressed:
            # No parent resolvable for the remainder — a dangling parent
            # reference (rig validation forbids cycles, but a child whose
            # parent is another child of an unresolved joint lands here on
            # a later pass; a truly unreachable joint is left at identity).
            for joint in still_pending:
                world.setdefault(joint.child_part, IDENTITY)
            break
        pending = still_pending
    return world


def transform_to_json(t: Transform) -> dict:
    """Serialize a ``Transform`` for the wire / RealityKit render hook.

    ``{"position": [x, y, z], "orientation": [x, y, z, w]}`` — the
    quaternion has ``w`` (the real part) last, matching RealityKit
    ``simd_quatf(ix, iy, iz, r)`` argument order.
    """
    q = quat_normalize(t.rotation)
    return {
        "position": [t.translation[0], t.translation[1], t.translation[2]],
        "orientation": [q[0], q[1], q[2], q[3]],
    }
