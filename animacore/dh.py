"""Denavit-Hartenberg serial kinematic chains + forward kinematics.

DH1 (see ``dev/docs/roadmap/DH_Kinematics.md``) — the articulated-arm
rig type. A serial manipulator (6-axis arm and the like) described by
the standard four-parameter-per-link Denavit-Hartenberg convention,
with forward kinematics. This is a *distinct rig type* from the general
parts + typed-mate assembly, not a property of every character.

Scope of this module: **forward kinematics (DH1)** and **inverse
kinematics (DH2)**, self-contained. FK is stdlib + ``math`` +
``animacore.kinematics.Transform`` and stays pure; IK (``solve_ik``,
damped least-squares on the geometric Jacobian) is the one path that uses
**numpy**, isolated below the FK. This module does not touch ``rig.py`` /
``loader.py`` / ``serialize.py`` / ``bridge.py``: the character-format /
bridge integration is DH3 and analytic per-geometry IK is DH4.

Convention — STANDARD (distal) Denavit-Hartenberg
=================================================
This module uses the **standard** (a.k.a. *distal*, *classic*, Spong /
Siciliano) DH convention — **not** the modified (Craig / proximal) one.
The two place the link frame differently and are not interchangeable;
mixing a modified-DH parameter table into this module gives wrong poses.

The homogeneous transform placing link *i*'s frame in link *(i-1)*'s
frame, for joint variable ``q_i``, is::

    A_i = Rotz(theta_eff) . Transz(d_eff) . Transx(a) . Rotx(alpha)

where ``.`` is the matrix product (``Transform.compose``), read as
"apply ``Rotx(alpha)`` first, then ``Transx(a)``, then ``Transz``, then
``Rotz`` last" — the rightmost factor acts on the point first. For a
**revolute** link ``theta_eff = theta + q_i`` and ``d_eff = d``; for a
**prismatic** link ``theta_eff = theta`` and ``d_eff = d + q_i``. The
``theta`` / ``d`` fields are the *home offset* added to the joint
variable (a revolute link's rest angle, a prismatic link's rest
extension).

The full chain pose is::

    T = base_frame . A_1 . A_2 . ... . A_n . tool_frame

``forward_kinematics`` returns every cumulative link frame plus the tool
pose, all as ``Transform`` values in the chain-base's parent space.

# ponytail: STANDARD (distal) DH only — one convention, documented, so a
# parameter table is never silently misread. Modified (proximal) DH and
# analytic per-geometry IK are deliberately out of scope here (DH2/DH4).
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass
from enum import StrEnum

import numpy as np

from animacore.kinematics import (
    IDENTITY,
    Transform,
    quat_conjugate,
    quat_multiply,
    quat_normalize,
    quat_rotate_vector,
)

_X_AXIS = (1.0, 0.0, 0.0)
_Z_AXIS = (0.0, 0.0, 1.0)


class DHError(ValueError):
    """Invalid DH chain, or a joint value outside its declared limits.

    A subclass of ``ValueError`` so existing ``except ValueError`` paths
    keep working, while callers (IK in DH2, the bridge in DH3) can catch
    the kinematics-specific failure precisely.
    """


class JointKind(StrEnum):
    """Which DH variable a link drives."""

    REVOLUTE = "revolute"  # theta is the joint variable; d is fixed
    PRISMATIC = "prismatic"  # d is the joint variable; theta is fixed


@dataclass(frozen=True)
class DHLink:
    """One link of a serial chain, in standard DH parameters.

    Fields (all lengths in **metres**, all angles in **radians**):

    - ``a``     — link length: offset along the (rotated) X axis.
    - ``alpha`` — link twist: rotation about the X axis.
    - ``d``     — link offset along Z. For a **prismatic** joint this is
      the *home extension* (the joint variable adds to it); for a
      revolute joint it is fixed.
    - ``theta`` — joint angle about Z. For a **revolute** joint this is
      the *home angle* (the joint variable adds to it); for a prismatic
      joint it is fixed.
    - ``joint_type`` — ``REVOLUTE`` (``theta`` variable) or ``PRISMATIC``
      (``d`` variable).
    - ``min`` / ``max`` — optional inclusive limits on the *joint
      variable* (radians for revolute, metres for prismatic). ``None``
      means unbounded on that side.
    - ``neutral`` — the joint variable's rest value (radians / metres).

    So the driven quantity is the *joint variable*, added on top of the
    home offset carried by the ``theta`` (revolute) or ``d`` (prismatic)
    field. See ``variable`` for which one a link drives.
    """

    a: float
    alpha: float
    d: float
    theta: float
    joint_type: JointKind = JointKind.REVOLUTE
    min: float | None = None
    max: float | None = None
    neutral: float = 0.0

    def __post_init__(self) -> None:
        if (
            self.min is not None
            and self.max is not None
            and self.min > self.max
        ):
            raise DHError(
                f"DH link limits invalid: min {self.min} > max {self.max}"
            )
        if self.min is not None and self.neutral < self.min:
            raise DHError(
                f"DH link neutral {self.neutral} below min {self.min}"
            )
        if self.max is not None and self.neutral > self.max:
            raise DHError(
                f"DH link neutral {self.neutral} above max {self.max}"
            )

    @property
    def variable(self) -> str:
        """Which DH parameter this link drives: ``"theta"`` or ``"d"``."""
        return "theta" if self.joint_type is JointKind.REVOLUTE else "d"

    def within_limits(self, joint_value: float) -> bool:
        """Whether ``joint_value`` lies within this link's limits."""
        if self.min is not None and joint_value < self.min:
            return False
        return not (self.max is not None and joint_value > self.max)


@dataclass(frozen=True)
class DHForwardResult:
    """The result of forward kinematics over a :class:`DHChain`.

    ``link_frames[i]`` is the cumulative frame of link ``i`` (after
    applying ``A_1 ... A_{i+1}`` onto the base frame), and ``tool_pose``
    is the end-effector frame (``link_frames[-1]`` composed with the
    chain's ``tool_frame``). All are ``Transform`` values in the chain
    base's parent space.
    """

    link_frames: tuple[Transform, ...]
    tool_pose: Transform


@dataclass(frozen=True)
class DHChain:
    """An ordered serial chain of DH links plus base and tool frames.

    ``base_frame`` places the chain root in character space (the first
    link is expressed relative to it); ``tool_frame`` is the
    end-effector offset from the last link (e.g. a gripper TCP). Both
    default to identity. ``dof`` is the number of links (one joint
    variable each).
    """

    links: tuple[DHLink, ...]
    base_frame: Transform = IDENTITY
    tool_frame: Transform = IDENTITY

    def __post_init__(self) -> None:
        object.__setattr__(self, "links", tuple(self.links))
        if not self.links:
            raise DHError("DH chain must have at least one link")

    @property
    def dof(self) -> int:
        """Degrees of freedom — one joint variable per link."""
        return len(self.links)

    def neutral_values(self) -> tuple[float, ...]:
        """Each link's neutral joint value, in link order."""
        return tuple(link.neutral for link in self.links)


def link_transform(link: DHLink, joint_value: float) -> Transform:
    """The standard-DH link transform ``A`` for one link at ``joint_value``.

    ``A = Rotz(theta_eff) . Transz(d_eff) . Transx(a) . Rotx(alpha)``
    (see the module docstring). For a revolute link the joint value adds
    to ``theta``; for a prismatic link it adds to ``d``.

    Built by composing ``Transform`` primitives left-to-right so that
    ``A.apply_point(p)`` applies ``Rotx`` innermost — verified against
    the planar-2R closed form in the tests.
    """
    if link.joint_type is JointKind.REVOLUTE:
        theta_eff = link.theta + joint_value
        d_eff = link.d
    else:
        theta_eff = link.theta
        d_eff = link.d + joint_value

    rot_z = Transform.from_axis_angle(_Z_AXIS, theta_eff)
    trans_z = Transform.from_translation((0.0, 0.0, d_eff))
    trans_x = Transform.from_translation((link.a, 0.0, 0.0))
    rot_x = Transform.from_axis_angle(_X_AXIS, link.alpha)

    result = Transform.compose(rot_z, trans_z)
    result = Transform.compose(result, trans_x)
    result = Transform.compose(result, rot_x)
    return result


def forward_kinematics(
    chain: DHChain, joint_values: Sequence[float]
) -> DHForwardResult:
    """Forward kinematics: every link frame and the tool pose.

    ``frame_0 = base_frame``; ``frame_i = compose(frame_{i-1},
    link_transform(link_i, q_i))``; the returned ``link_frames`` are
    ``frame_1 ... frame_n`` (one per link) and ``tool_pose =
    compose(frame_n, tool_frame)``.

    Raises :class:`DHError` if ``joint_values`` has the wrong length or
    any value violates its link's limits — the message names the joint
    index (0-based) so IK / the bridge see the violation rather than
    silently clamping.
    """
    if len(joint_values) != chain.dof:
        raise DHError(
            f"expected {chain.dof} joint values, got {len(joint_values)}"
        )

    frame = chain.base_frame
    link_frames: list[Transform] = []
    for index, (link, value) in enumerate(zip(chain.links, joint_values)):
        if not link.within_limits(value):
            raise DHError(
                f"joint {index} value {value} outside limits "
                f"[{link.min}, {link.max}]"
            )
        frame = Transform.compose(frame, link_transform(link, value))
        link_frames.append(frame)

    tool_pose = Transform.compose(frame, chain.tool_frame)
    return DHForwardResult(tuple(link_frames), tool_pose)


# Inverse kinematics (DH2) ----------------------------------------------------
#
# Numerical inverse kinematics by damped least-squares (Levenberg-Marquardt)
# on the 6xN geometric Jacobian. This is the one path in the module that uses
# numpy — FK above stays pure stdlib. Given a target end-effector pose, iterate
# joint values toward it, clamping each to its DHLink limits every step, and
# report convergence honestly (no raise on failure — the caller decides).
#
# ponytail: single-seed only (no random-restart for tough / near-singular
# targets — a hard target that needs a different basin just reports
# reached=False), geometric-Jacobian DLS (no null-space / redundancy
# resolution for the redundant DOF of a 7+-axis arm, no collision or
# self-intersection avoidance), and purely numerical (analytic per-geometry
# closed-form IK for spherical-wrist arms is DH4). Damping trades a little
# accuracy near singularities for stability — that is the intended ceiling.


@dataclass(frozen=True)
class IKResult:
    """The outcome of :func:`solve_ik`.

    ``joint_values`` is the best joint vector found (always within each
    link's limits). ``reached`` is ``True`` only when both residuals fell
    under their tolerances. ``position_error_m`` / ``orientation_error_rad``
    are the final residuals (metres / radians) — meaningful whether or not
    the solve converged, so a caller can accept a near-miss or retry.
    ``iterations`` is the number of damped-least-squares updates applied
    (0 when the seed already satisfies the target).
    """

    joint_values: tuple[float, ...]
    reached: bool
    position_error_m: float
    orientation_error_rad: float
    iterations: int


def _world_z_axis(frame: Transform) -> tuple[float, float, float]:
    """The world-space Z axis of ``frame`` (the joint's action axis)."""
    return quat_rotate_vector(frame.rotation, _Z_AXIS)


def _orientation_error_rotvec(
    current: tuple[float, float, float, float],
    target: tuple[float, float, float, float],
) -> tuple[float, float, float]:
    """Axis-angle vector rotating orientation ``current`` onto ``target``.

    ``q_err = q_target * q_current^-1`` in the world frame, mapped to an
    axis*angle 3-vector on the **shortest** path (the quaternion is sign-
    flipped so its real part is non-negative, i.e. angle in ``[0, pi]``).
    Returns the zero vector when the two orientations already agree.
    """
    q_err = quat_multiply(
        quat_normalize(target), quat_conjugate(quat_normalize(current))
    )
    x, y, z, w = quat_normalize(q_err)
    if w < 0.0:  # shortest path: pick the hemisphere with angle <= pi
        x, y, z, w = -x, -y, -z, -w
    vec_norm = math.sqrt(x * x + y * y + z * z)
    if vec_norm < 1e-12:
        return (0.0, 0.0, 0.0)
    angle = 2.0 * math.atan2(vec_norm, w)
    scale = angle / vec_norm
    return (x * scale, y * scale, z * scale)


def _geometric_jacobian(chain: DHChain, forward: DHForwardResult) -> np.ndarray:
    """The 6xN geometric Jacobian at the configuration ``forward`` describes.

    Under standard (distal) DH, joint ``i``'s variable acts about/along the
    Z axis of frame ``i-1``. ``frame_0`` is the chain base; ``frame_k`` is
    ``forward.link_frames[k-1]``. For a revolute joint the column is
    ``[z x (p_tool - p); z]`` (angular velocity about z induces that linear
    velocity at the tool); for a prismatic joint it is ``[z; 0]`` (pure
    translation along z, no angular part).
    """
    frames = (chain.base_frame, *forward.link_frames)  # frame_0 .. frame_n
    p_tool = np.asarray(forward.tool_pose.translation, dtype=float)
    jac = np.zeros((6, chain.dof))
    for i, link in enumerate(chain.links):
        frame = frames[i]  # frame_{i}: the axis for joint i (0-based)
        z = np.asarray(_world_z_axis(frame), dtype=float)
        if link.joint_type is JointKind.REVOLUTE:
            p = np.asarray(frame.translation, dtype=float)
            jac[0:3, i] = np.cross(z, p_tool - p)
            jac[3:6, i] = z
        else:  # PRISMATIC: pure translation along z
            jac[0:3, i] = z
            jac[3:6, i] = 0.0
    return jac


def _clamp_to_limits(chain: DHChain, values: Sequence[float]) -> list[float]:
    """Each joint value clamped into its link's ``[min, max]`` (if set)."""
    clamped: list[float] = []
    for link, value in zip(chain.links, values):
        v = float(value)
        if link.min is not None and v < link.min:
            v = link.min
        if link.max is not None and v > link.max:
            v = link.max
        clamped.append(v)
    return clamped


def solve_ik(
    chain: DHChain,
    target_pose: Transform,
    *,
    seed: Sequence[float] | None = None,
    position_tolerance_m: float = 1e-4,
    orientation_tolerance_rad: float = 1e-3,
    max_iterations: int = 100,
    damping: float = 0.05,
) -> IKResult:
    """Inverse kinematics: joint values putting the tool at ``target_pose``.

    Damped least-squares (Levenberg-Marquardt) Jacobian IK. Starting from
    ``seed`` (or ``chain.neutral_values()``), each iteration builds the 6xN
    geometric Jacobian ``J`` and the 6-vector error twist
    ``e = [target_p - tool_p; rotvec(current -> target)]``, then applies the
    damped update ``dq = J^T (J J^T + lambda^2 I)^-1 e`` (``lambda`` =
    ``damping``, solved as a 6x6 linear system, never an explicit inverse).
    Every step clamps each joint to its :class:`DHLink` limits.

    Converges (``reached=True``) when the position residual is under
    ``position_tolerance_m`` **and** the orientation residual under
    ``orientation_tolerance_rad``. After ``max_iterations`` without
    convergence it returns ``reached=False`` carrying the final residuals —
    it does **not** raise; an unreachable target is a legitimate answer the
    caller interprets.

    Raises :class:`DHError` only for a structurally invalid request — a
    ``seed`` whose length does not match ``chain.dof``.
    """
    if seed is None:
        q = list(chain.neutral_values())
    elif len(seed) != chain.dof:
        raise DHError(
            f"IK seed expected {chain.dof} joint values, got {len(seed)}"
        )
    else:
        q = list(seed)
    q = _clamp_to_limits(chain, q)

    target_p = np.asarray(target_pose.translation, dtype=float)
    eye6 = np.eye(6)
    lambda_sq = float(damping) * float(damping)

    iteration = 0
    while True:
        forward = forward_kinematics(chain, q)
        tool = forward.tool_pose
        pos_err_vec = target_p - np.asarray(tool.translation, dtype=float)
        ori_err_vec = _orientation_error_rotvec(
            tool.rotation, target_pose.rotation
        )
        pos_err = float(np.linalg.norm(pos_err_vec))
        ori_err = float(np.linalg.norm(ori_err_vec))

        if (
            pos_err < position_tolerance_m
            and ori_err < orientation_tolerance_rad
        ):
            return IKResult(tuple(q), True, pos_err, ori_err, iteration)
        if iteration >= max_iterations:
            return IKResult(tuple(q), False, pos_err, ori_err, iteration)

        jac = _geometric_jacobian(chain, forward)
        twist = np.concatenate([pos_err_vec, np.asarray(ori_err_vec)])
        # dq = J^T (J J^T + lambda^2 I)^-1 e  — solve the 6x6 system.
        y = np.linalg.solve(jac @ jac.T + lambda_sq * eye6, twist)
        dq = jac.T @ y
        q = _clamp_to_limits(chain, [q[i] + dq[i] for i in range(chain.dof)])
        iteration += 1
