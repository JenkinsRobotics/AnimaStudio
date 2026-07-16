# DH kinematics & IK — the articulated-arm rig type (planned)

> A serial kinematic chain (Denavit–Hartenberg parameterized) rig type
> for articulated robots — 6-axis arms and the like — enabling forward
> kinematics *and* inverse kinematics for simulation and control
> (Jonathan, 2026-07-16). Not universal: this is a **distinct rig type**,
> not a property of every character.

## Why it's its own rig type

The general model (parts + typed mates + `resolve_pose`) does forward
kinematics for *any* assembly. A DH chain adds two things the general
model doesn't:

1. **The standard parameterization** of a serial manipulator — 4
   params per link (`a`, `α`, `d`, `θ`) — the form every robotics tool,
   controller, and datasheet speaks.
2. **Inverse kinematics** — given a target end-effector pose, solve for
   the joint variables. This is only well-posed for a *structured serial
   chain*, which is exactly what DH describes.

So an articulated arm is a **rig kind** (`kinematic_chain`) distinct
from a general assembly. A character is one or the other for its
kinematic solving. This keeps IK/DH out of turrets, faces, and mixed
mechanisms that don't want it — matching Jonathan's "group them as a
different type."

## The model

`DHLink` (one per joint): `a` (link length, m), `alpha` (link twist,
rad), `d` (link offset, m), `theta` (joint angle, rad), `joint_type`
(`revolute` → `theta` is the variable, `d` fixed; `prismatic` → `d` is
the variable, `theta` fixed), plus the variable's `limits` (min/max) and
`neutral`. A `DHChain` is an ordered list of links + a `base_frame`
(chain root in character space — ties to `Coordinate_Frames.md`) and a
`tool_frame` (end-effector offset from the last link).

**Forward kinematics** (stdlib, reuses the `Transform` math):
`A_i = Rotz(θ_i)·Transz(d_i)·Transx(a_i)·Rotx(α_i)`, chained
`T = base · A_1 · … · A_n · tool` → the end-effector pose and every
intermediate link frame.

**Inverse kinematics:** numerical **damped least-squares (Jacobian)** —
general (any chain, no closed form), respects joint limits by clamping,
converges in ms for 6-DOF. Analytic closed-form IK (for spherical-wrist
6-DOF arms) is a later per-geometry optimization on top. IK needs real
linear algebra (a 6×N Jacobian + damped pseudoinverse), so this module
takes a **numpy** dependency — standard for a robotics runtime, and
isolated to the IK path (FK stays stdlib).

## How it relates to the assembly model

An articulated-arm rig can still carry parts/meshes for rendering (each
DH link maps to a part with a `model`), so import + display are
unchanged. The DH chain is the *kinematic truth*; `resolve_pose` for an
arm rig drives the link frames from DH FK (or from IK when a target is
set) and places the parts on them. A DH link frame is a coordinate
frame in the World→Character→Part hierarchy — the chain's `base_frame`
sits in character space, each link frame follows.

## Bridge & format

- Character format gains an optional `kinematic_chain` block (base
  frame, ordered DH links with params + limits, tool frame); a rig with
  it is the articulated-arm type. Round-trips like everything else.
- Bridge verbs: `forward_kinematics {chain, joint_values} → {tool_pose,
  link_frames}` and `solve_ik {chain, target_pose, seed?} →
  {joint_values, reached, error}` (reports non-convergence honestly).

## Packets

| # | Packet | Dep | Dependency |
|---|---|---|---|
| DH1 | `dh.py`: `DHLink`/`DHChain` + forward kinematics + tests | — | **shipped** |
| DH2 | Inverse kinematics (damped least-squares, joint-limit clamping) | DH1 | **shipped** (numpy) |
| DH3 | Character-format `kinematic_chain` block + loader/serialize + the arm rig type + bridge `forward_kinematics`/`solve_ik` verbs | DH1–2 | **shipped** |
| DH4 | Analytic IK for common arm geometries (spherical wrist) | DH3 | — |

**DH3 shipped (2026-07-16).** `Rig` gains an optional `KinematicChain`
(ordered `ChainJoint` DH links, `base_part`, `tool_part`, tool offset);
its joints are drivable DOF (`"<chain>.<joint>"`), `resolve_pose` places
the link/tool parts by DH forward kinematics, the loader/serializer
round-trip the `kinematic_chain` block, and the bridge adds
`forward_kinematics` / `solve_ik` verbs (character-space frames; IK
reports non-convergence honestly). Example:
`examples/six_axis_arm_dh.character.anima` (UR5-style 6R). See
`Character_Format.md` → "Kinematic chain".

## Open decisions (for Jonathan)

1. **numpy** for the IK module — recommended (standard robotics dep; FK
   stays pure). OK to add?
2. **Rig-type shape** — a character declares an optional
   `kinematic_chain` and *becomes* the articulated-arm type
   (recommended), vs. a wholly separate `.robotarm.anima` file. I lean
   optional-block-on-the-character so it reuses import/render/save.
3. **IK method** — numerical DLS first (general), analytic later
   (recommended).
