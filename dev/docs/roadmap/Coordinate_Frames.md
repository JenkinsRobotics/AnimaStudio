# Coordinate frames: World → Character → Part (normative)

> The explicit spatial-frame model both lanes build to (Jonathan,
> 2026-07-16). Short and normative: it fixes where a part's rest
> transform lives, what `resolve_pose` output means, and the Euler
> convention Swift and the engine must share. Everything here is
> kinematic — physics/dynamics stays deferred per AGENTS.md.

## The frame hierarchy

Three nested right-handed frames, metres and radians throughout:

1. **World space** — the shared scene coordinate system. Where a whole
   character (or prop, camera, light) sits in a show.
2. **Character space** — the character's own origin. Every part of one
   character is placed relative to this. When you author a single
   character in the Rig/Animate workspaces, character space **is** the
   working frame and Character-in-World is **identity** by default.
3. **Part space** — a rigid part's local origin (its mesh's own frame).

```
World  ──(Character-in-World: scene-level, default identity)──▶  Character
Character  ──(part rest transform / mate chain)──▶  Part
```

## A part's rest transform is part-in-CHARACTER

Each `Part` carries a **rest transform** — its placement expressed in
**character space**, i.e. the transform from part space to character
space. It is **not** world space.

- `position_m: (x, y, z)` — the part origin's position in character
  space, metres.
- `rotation_euler_rad: (rx, ry, rz)` — the part's rest orientation, XYZ
  Euler radians (file: `rotation_euler_deg`, degrees; radians in the
  model, matching the DOF limit/offset convention). Matches the app's
  `rotationEulerRadians`.

Both default to zero → the identity transform, so a part with no
authored location behaves exactly as before (roots at the character
origin).

### How the rest transform is used (`resolve_pose`)

`resolve_pose(rig, pose)` returns each part's **character-space**
transform. Per part:

- **ROOT** (no active incoming joint): resolves **at its rest
  transform** (`R(rotation_euler_rad)·p + position_m`).
- **GROUNDED**: a fixed anchor — resolves **at its rest transform**,
  overriding any incoming joint (ground wins).
- **MATED child**: positioned **by its mate** (`child_in_parent`)
  relative to its resolved parent. Its own rest transform is its
  *pre-mate* placement and is **not** applied on top — the mate defines
  where it goes. (So editing a mated part's rest transform does not move
  it while the mate holds; freeing the part makes the rest transform
  live again.)

A single character's `resolve_pose` output is therefore complete on its
own. Placing that character in the world is a **separate scene-level
transform** (Character-in-World), default identity, that becomes real in
the scene format — it never enters the character model or `resolve_pose`.

## The Euler convention (Swift and the engine MUST agree)

`rotation_euler_rad` is **intrinsic XYZ** Tait-Bryan Euler:

- Rotate about the local **X** axis by `rx`, then the new local **Y** by
  `ry`, then the new local **Z** by `rz`.
- As unit quaternions (real part last, `(x, y, z, w)`):
  `q = q_x ⊗ q_y ⊗ q_z` (Hamilton product).
- As a matrix: `R = R_x · R_y · R_z`, so a point transforms as `R·p`
  with the Z-rotation applied innermost.

This is exactly what the app / RealityKit produce when they build a
quaternion from `rotationEulerRadians` multiplied X→Y→Z (`simd_quatf`).
The engine builder is `kinematics.Transform.from_euler_xyz(rx, ry, rz)`;
the Swift side must construct the same product so a saved rest
orientation renders identically in both. (`# ponytail:` Euler is the
authoring/interchange shape because it matches the inspector fields;
quaternions remain the internal truth, and the gimbal-lock ceiling is
accepted for static rest placement — nothing interpolates through it.)

## Custom named reference frames (future extension)

The frame model is open to **named part-local reference frames** beyond
the part origin. The first instance already exists: **mate connectors**
(`MateConnector`) are part-local frames — an `origin_m` plus an oriented
basis — that a mate aligns. A future custom-frame concept generalizes
that same shape (a named frame on a part) for authoring, targeting, and
attachment, without changing the World → Character → Part spine above.

## Cross-references

- Pose resolution math: [`Kinematics.md`](Kinematics.md) §1a.
- Part fields in the file: [`Character_Format.md`](Character_Format.md)
  ("Parts").
