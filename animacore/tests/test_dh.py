"""Denavit-Hartenberg forward kinematics (DH1).

Standard (distal) DH convention. Stdlib + ``math`` only — no numpy.
Tolerances via ``math.isclose`` / absolute ``abs`` checks.

Two independent oracles guard the FK math:

- the planar **2R** arm has a pure-trig closed form for the tool
  position (``x = L1 cos q1 + L2 cos(q1+q2)`` etc.), and
- a standalone 4x4 homogeneous-matrix DH implementation
  (``_ref_fk`` below, plain nested lists) cross-checks the full pose of
  a **6R** UR5-style arm — a wholly separate code path from the module's
  quaternion ``Transform`` composition.
"""

import math

import numpy as np
import pytest

from animacore.dh import (
    DHChain,
    DHError,
    DHForwardResult,
    DHLink,
    IKResult,
    JointKind,
    forward_kinematics,
    link_transform,
    solve_ik,
)
from animacore.kinematics import Transform

TOL = 1e-9


def _vclose(a, b, tol=TOL):
    return all(math.isclose(x, y, abs_tol=tol) for x, y in zip(a, b))


# Independent reference: standard-DH 4x4 homogeneous matrices ------------------


def _dh_matrix(a, alpha, d, theta):
    """The standard-DH homogeneous 4x4 matrix (plain nested lists).

    A = Rotz(theta) . Transz(d) . Transx(a) . Rotx(alpha), written out
    in closed form — the textbook matrix, independent of the module's
    quaternion Transform path.
    """
    ct, st = math.cos(theta), math.sin(theta)
    ca, sa = math.cos(alpha), math.sin(alpha)
    return [
        [ct, -st * ca, st * sa, a * ct],
        [st, ct * ca, -ct * sa, a * st],
        [0.0, sa, ca, d],
        [0.0, 0.0, 0.0, 1.0],
    ]


def _matmul(m, n):
    return [
        [sum(m[i][k] * n[k][j] for k in range(4)) for j in range(4)]
        for i in range(4)
    ]


def _apply(m, p):
    x, y, z = p
    return (
        m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3],
        m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3],
        m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3],
    )


def _ref_fk(params, q):
    """Reference tool matrix for links ``params`` at joint values ``q``.

    ``params`` are ``(a, alpha, d, theta, kind)`` tuples matching the
    module links; revolute adds q to theta, prismatic adds q to d.
    """
    result = [[float(i == j) for j in range(4)] for i in range(4)]
    for (a, alpha, d, theta, kind), value in zip(params, q):
        if kind is JointKind.REVOLUTE:
            result = _matmul(result, _dh_matrix(a, alpha, d, theta + value))
        else:
            result = _matmul(result, _dh_matrix(a, alpha, d + value, theta))
    return result


# link_transform primitives ---------------------------------------------------


def test_link_transform_pure_revolute_is_z_rotation():
    # a = d = alpha = 0, home theta 0.1, joint value 0.2 -> Rotz(0.3).
    link = DHLink(a=0.0, alpha=0.0, d=0.0, theta=0.1)
    t = link_transform(link, 0.2)
    expected = Transform.from_axis_angle((0.0, 0.0, 1.0), 0.3)
    # +X maps onto the rotated direction; no translation.
    assert _vclose(t.translation, (0.0, 0.0, 0.0))
    assert _vclose(t.apply_point((1.0, 0.0, 0.0)),
                   expected.apply_point((1.0, 0.0, 0.0)))


def test_link_transform_pure_prismatic_extends_along_z():
    link = DHLink(a=0.0, alpha=0.0, d=0.0, theta=0.0,
                  joint_type=JointKind.PRISMATIC)
    t = link_transform(link, 0.3)
    assert _vclose(t.translation, (0.0, 0.0, 0.3))
    # No rotation: +X stays +X.
    assert _vclose(t.apply_point((1.0, 0.0, 0.0)), (1.0, 0.0, 0.3))


def test_link_transform_a_offsets_along_x():
    link = DHLink(a=0.5, alpha=0.0, d=0.0, theta=0.0)
    t = link_transform(link, 0.0)
    assert _vclose(t.translation, (0.5, 0.0, 0.0))


# Planar 2R closed form -------------------------------------------------------


def _planar_2r(l1, l2):
    return DHChain(
        links=(
            DHLink(a=l1, alpha=0.0, d=0.0, theta=0.0),
            DHLink(a=l2, alpha=0.0, d=0.0, theta=0.0),
        )
    )


@pytest.mark.parametrize(
    "q1,q2",
    [
        (0.0, 0.0),
        (math.pi / 2, 0.0),
        (0.0, math.pi / 2),
        (math.pi / 2, math.pi / 2),
        (-math.pi / 3, math.pi / 4),
        (1.1, -0.7),
    ],
)
def test_planar_2r_matches_closed_form(q1, q2):
    l1, l2 = 0.5, 0.3
    result = forward_kinematics(_planar_2r(l1, l2), (q1, q2))
    x = l1 * math.cos(q1) + l2 * math.cos(q1 + q2)
    y = l1 * math.sin(q1) + l2 * math.sin(q1 + q2)
    assert _vclose(result.tool_pose.translation, (x, y, 0.0))


def test_planar_2r_intermediate_frame_is_first_joint():
    # link_frames[0] is the elbow: at L1 along the first link direction.
    l1, l2 = 0.5, 0.3
    result = forward_kinematics(_planar_2r(l1, l2), (math.pi / 2, 0.0))
    assert _vclose(result.link_frames[0].translation, (0.0, l1, 0.0))
    assert _vclose(result.tool_pose.translation, (0.0, l1 + l2, 0.0))


# 6R UR5-style arm ------------------------------------------------------------
# Standard-DH parameters for the Universal Robots UR5, as published by
# Universal Robots (Kinematics coefficients / Kufieta, "UR5 kinematics"):
# (a, alpha, d) per link, all theta home offsets 0.
_UR5 = (
    (0.0, math.pi / 2, 0.089159, 0.0, JointKind.REVOLUTE),
    (-0.425, 0.0, 0.0, 0.0, JointKind.REVOLUTE),
    (-0.39225, 0.0, 0.0, 0.0, JointKind.REVOLUTE),
    (0.0, math.pi / 2, 0.10915, 0.0, JointKind.REVOLUTE),
    (0.0, -math.pi / 2, 0.09465, 0.0, JointKind.REVOLUTE),
    (0.0, 0.0, 0.0823, 0.0, JointKind.REVOLUTE),
)


def _ur5_chain():
    return DHChain(
        links=tuple(
            DHLink(a=a, alpha=alpha, d=d, theta=theta, joint_type=kind)
            for a, alpha, d, theta, kind in _UR5
        )
    )


@pytest.mark.parametrize(
    "q",
    [
        (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
        (0.1, -0.5, 0.7, 0.2, -0.3, 0.9),
        (math.pi / 2, -math.pi / 4, math.pi / 3, 0.0, math.pi / 6, -1.0),
    ],
)
def test_ur5_fk_matches_reference_matrix(q):
    result = forward_kinematics(_ur5_chain(), q)
    ref = _ref_fk(_UR5, q)
    # Full pose check: both must map the same probe points identically.
    for probe in [(0.0, 0.0, 0.0), (0.1, 0.0, 0.0),
                  (0.0, 0.2, 0.0), (0.0, 0.0, 0.3)]:
        assert _vclose(result.tool_pose.apply_point(probe),
                       _apply(ref, probe))


def test_ur5_home_tool_position():
    # UR5 home (all joints zero) tool-flange position in the base frame,
    # from the reference matrix: the arm folded straight up/back.
    result = forward_kinematics(_ur5_chain(), (0.0,) * 6)
    ref = _ref_fk(_UR5, (0.0,) * 6)
    expected = _apply(ref, (0.0, 0.0, 0.0))
    assert _vclose(result.tool_pose.translation, expected)
    # Sanity anchor: the home flange sits well off the base origin.
    assert not _vclose(result.tool_pose.translation, (0.0, 0.0, 0.0))


# base_frame and tool_frame offsets -------------------------------------------


def test_base_frame_translates_whole_chain():
    base = Transform.from_translation((1.0, 2.0, 3.0))
    plain = forward_kinematics(_planar_2r(0.5, 0.3), (0.2, 0.4))
    shifted = forward_kinematics(
        DHChain(links=_planar_2r(0.5, 0.3).links, base_frame=base),
        (0.2, 0.4),
    )
    px = plain.tool_pose.translation
    sx = shifted.tool_pose.translation
    assert _vclose(sx, (px[0] + 1.0, px[1] + 2.0, px[2] + 3.0))


def test_base_frame_rotates_whole_chain():
    # 90 deg about Z maps the planar arm's +X reach onto +Y.
    base = Transform.from_axis_angle((0.0, 0.0, 1.0), math.pi / 2)
    chain = DHChain(links=_planar_2r(0.5, 0.3).links, base_frame=base)
    result = forward_kinematics(chain, (0.0, 0.0))
    # Without base the tool is at (0.8, 0, 0); rotated it is at (0, 0.8, 0).
    assert _vclose(result.tool_pose.translation, (0.0, 0.8, 0.0))


def test_tool_frame_offsets_end_effector():
    tool = Transform.from_translation((0.1, 0.0, 0.0))
    chain = DHChain(links=_planar_2r(0.5, 0.3).links, tool_frame=tool)
    result = forward_kinematics(chain, (0.0, 0.0))
    # Straight arm reaches 0.8 along X, tool adds 0.1 in the last frame's X.
    assert _vclose(result.tool_pose.translation, (0.9, 0.0, 0.0))
    # The last link frame itself is unaffected by the tool offset.
    assert _vclose(result.link_frames[-1].translation, (0.8, 0.0, 0.0))


# Joint limits ----------------------------------------------------------------


def test_out_of_range_joint_value_raises_naming_index():
    chain = DHChain(
        links=(
            DHLink(a=0.5, alpha=0.0, d=0.0, theta=0.0),
            DHLink(a=0.3, alpha=0.0, d=0.0, theta=0.0,
                   min=-1.0, max=1.0),
        )
    )
    with pytest.raises(DHError, match="joint 1"):
        forward_kinematics(chain, (0.0, 2.0))
    # In range is fine.
    forward_kinematics(chain, (0.0, 0.5))


def test_wrong_joint_value_count_raises():
    with pytest.raises(DHError, match="expected 2 joint values, got 1"):
        forward_kinematics(_planar_2r(0.5, 0.3), (0.1,))


def test_link_rejects_inverted_limits():
    with pytest.raises(DHError, match="min .* > max"):
        DHLink(a=0.0, alpha=0.0, d=0.0, theta=0.0, min=1.0, max=-1.0)


def test_link_rejects_neutral_outside_limits():
    with pytest.raises(DHError, match="neutral"):
        DHLink(a=0.0, alpha=0.0, d=0.0, theta=0.0,
               min=0.0, max=1.0, neutral=2.0)


def test_empty_chain_rejected():
    with pytest.raises(DHError, match="at least one link"):
        DHChain(links=())


# Metadata --------------------------------------------------------------------


def test_variable_property():
    rev = DHLink(a=0.0, alpha=0.0, d=0.0, theta=0.0)
    pri = DHLink(a=0.0, alpha=0.0, d=0.0, theta=0.0,
                 joint_type=JointKind.PRISMATIC)
    assert rev.variable == "theta"
    assert pri.variable == "d"


def test_chain_dof_and_neutrals():
    chain = DHChain(
        links=(
            DHLink(a=0.5, alpha=0.0, d=0.0, theta=0.0, neutral=0.1),
            DHLink(a=0.3, alpha=0.0, d=0.0, theta=0.0, neutral=-0.2),
        )
    )
    assert chain.dof == 2
    assert _vclose(chain.neutral_values(), (0.1, -0.2))


def test_result_type():
    result = forward_kinematics(_planar_2r(0.5, 0.3), (0.0, 0.0))
    assert isinstance(result, DHForwardResult)
    assert len(result.link_frames) == 2


# Determinism -----------------------------------------------------------------


def test_forward_kinematics_is_deterministic():
    chain = _ur5_chain()
    q = (0.1, -0.5, 0.7, 0.2, -0.3, 0.9)
    a = forward_kinematics(chain, q)
    b = forward_kinematics(chain, q)
    assert a.tool_pose.translation == b.tool_pose.translation
    assert a.tool_pose.rotation == b.tool_pose.rotation
    for fa, fb in zip(a.link_frames, b.link_frames):
        assert fa.translation == fb.translation
        assert fa.rotation == fb.rotation


# Inverse kinematics (DH2) ----------------------------------------------------
#
# numpy is allowed in these tests (the IK path uses it). Randomness is a
# fixed-seed ``numpy.default_rng`` only — deterministic, no wall-clock.


def _pose_probe_close(a, b, tol=1e-3):
    """Whether transforms ``a`` and ``b`` map probe points identically.

    Comparing several non-collinear probe points captures both position
    and orientation of the pose, independent of quaternion sign.
    """
    probes = [(0.0, 0.0, 0.0), (0.1, 0.0, 0.0),
              (0.0, 0.2, 0.0), (0.0, 0.0, 0.3)]
    return all(_vclose(a.apply_point(p), b.apply_point(p), tol) for p in probes)


def test_ik_round_trip_2r():
    # Planar 2R: FK a known config -> target, solve from a different seed,
    # assert the achieved POSE matches (joints may differ for the elbow-flip
    # solution). q2 kept away from 0 to avoid the straight-arm singularity.
    chain = _planar_2r(0.5, 0.3)
    rng = np.random.default_rng(42)
    for _ in range(8):
        q1 = float(rng.uniform(-2.5, 2.5))
        q2 = float(rng.uniform(0.3, 2.5))  # elbow bent: away from singular
        target = forward_kinematics(chain, (q1, q2)).tool_pose
        seed = (q1 + 0.3, q2 - 0.2)  # genuinely different starting config
        result = solve_ik(chain, target, seed=seed)
        assert isinstance(result, IKResult)
        assert result.reached
        achieved = forward_kinematics(chain, result.joint_values).tool_pose
        assert _pose_probe_close(achieved, target)


def test_ik_round_trip_ur5():
    # 6R UR5: FK a random-but-fixed config -> full 6-DOF target pose, solve
    # from a perturbed seed, assert the achieved pose matches the target.
    chain = _ur5_chain()
    rng = np.random.default_rng(7)
    for _ in range(6):
        q_true = rng.uniform(-1.8, 1.8, size=6)
        # keep the wrist off its singularity (q5 ~ 0) for a clean round-trip.
        if abs(q_true[4]) < 0.4:
            q_true[4] += 0.6
        target = forward_kinematics(chain, tuple(q_true)).tool_pose
        seed = tuple(q_true + 0.3)
        result = solve_ik(chain, target, seed=seed)
        assert result.reached, (
            f"IK did not reach; residual pos={result.position_error_m}, "
            f"ori={result.orientation_error_rad}"
        )
        achieved = forward_kinematics(chain, result.joint_values).tool_pose
        assert _pose_probe_close(achieved, target)


def test_ik_target_at_seed_converges_in_zero_iterations():
    chain = _ur5_chain()
    seed = (0.1, -0.5, 0.7, 0.2, -0.3, 0.9)
    target = forward_kinematics(chain, seed).tool_pose
    result = solve_ik(chain, target, seed=seed)
    assert result.reached
    assert result.iterations == 0
    # No update applied: the seed is returned verbatim.
    assert result.joint_values == seed


def test_ik_unreachable_target_reports_honest_residual():
    # A target metres outside the workspace: no convergence, no raise, a
    # large but finite position residual the caller can act on.
    chain = _ur5_chain()
    target = Transform.from_translation((100.0, 100.0, 100.0))
    result = solve_ik(chain, target, max_iterations=60)
    assert not result.reached
    assert result.position_error_m > 1.0
    assert math.isfinite(result.position_error_m)
    assert result.iterations == 60


def test_ik_respects_joint_limits():
    # Tightly limited 2R; drive at an out-of-reach target so the solver is
    # pushed against the stops, then assert every joint stayed within limits.
    chain = DHChain(
        links=(
            DHLink(a=0.5, alpha=0.0, d=0.0, theta=0.0, min=-0.6, max=0.6),
            DHLink(a=0.3, alpha=0.0, d=0.0, theta=0.0, min=-0.6, max=0.6),
        )
    )
    target = Transform.from_translation((0.85, 0.85, 0.0))
    result = solve_ik(chain, target, seed=(0.0, 0.0))
    for link, value in zip(chain.links, result.joint_values):
        assert link.within_limits(value)
    # The clamped solution is still a valid FK input (no limit violation).
    forward_kinematics(chain, result.joint_values)


def test_ik_is_deterministic():
    chain = _ur5_chain()
    target = forward_kinematics(
        chain, (0.3, -0.4, 0.5, 0.1, 0.2, -0.6)
    ).tool_pose
    seed = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    r1 = solve_ik(chain, target, seed=seed)
    r2 = solve_ik(chain, target, seed=seed)
    assert r1 == r2


def test_ik_seed_wrong_length_raises():
    with pytest.raises(DHError, match="IK seed expected 6"):
        solve_ik(_ur5_chain(), Transform(), seed=(0.0, 0.0))


def _prismatic_chain():
    # A revolute base that reorients the slider axis, then a prismatic
    # joint (a slider) — a mixed chain whose translation depends on the
    # prismatic DOF extending.
    return DHChain(
        links=(
            DHLink(a=0.2, alpha=math.pi / 2, d=0.1, theta=0.0),
            DHLink(a=0.0, alpha=0.0, d=0.15, theta=0.0,
                   joint_type=JointKind.PRISMATIC, min=0.0, max=0.8),
        )
    )


def test_ik_prismatic_reaches_translated_target():
    chain = _prismatic_chain()
    q_true = (0.5, 0.4)
    target = forward_kinematics(chain, q_true).tool_pose
    result = solve_ik(chain, target, seed=(0.0, 0.0))
    assert result.reached
    achieved = forward_kinematics(chain, result.joint_values).tool_pose
    assert _pose_probe_close(achieved, target)
    # The slider genuinely extended to reach the target (prismatic DOF used).
    assert result.joint_values[1] > 0.1
