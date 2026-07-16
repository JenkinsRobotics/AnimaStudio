"""Denavit-Hartenberg serial kinematic chains + forward kinematics.

DH1 (see ``dev/docs/roadmap/DH_Kinematics.md``) — the articulated-arm
rig type. A serial manipulator (6-axis arm and the like) described by
the standard four-parameter-per-link Denavit-Hartenberg convention,
with forward kinematics. This is a *distinct rig type* from the general
parts + typed-mate assembly, not a property of every character.

Scope of this packet: **forward kinematics only**, self-contained.
Stdlib + ``math`` + ``animacore.kinematics.Transform`` — **no numpy**
(FK stays pure; the numpy dependency arrives with DH2's inverse
kinematics). This module does not touch ``rig.py`` / ``loader.py`` /
``serialize.py`` / ``bridge.py``: inverse kinematics is DH2 and the
character-format / bridge integration is DH3.

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

from collections.abc import Sequence
from dataclasses import dataclass
from enum import StrEnum

from animacore.kinematics import IDENTITY, Transform

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
