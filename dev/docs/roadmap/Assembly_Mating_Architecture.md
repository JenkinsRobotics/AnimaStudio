# Assembly & Mating — System Architecture

Status: design (planned). Author: Claude (backend), 2026-07-28.
Scope: the whole-system architecture for authoring assemblies and mating
parts, so all four implementation phases slot in without rework. This
document defines the data model, solver interface, and bridge surface once;
each phase gets its own implementation spec + plan.

Related: [`Character_Format.md`](Character_Format.md),
[`Assets_And_Assembly_Handoff.md`](Assets_And_Assembly_Handoff.md),
[`Coordinate_Frames.md`](Coordinate_Frames.md),
[`DH_Kinematics.md`](DH_Kinematics.md),
[`Studio_Bridge.md`](Studio_Bridge.md).

## 1. Goal

Author animatronic and robotic mechanisms by moving/reorienting parts,
placing mate connectors, and creating permanent mates. A *fixed* mate rigidly
connects components; other mates carry a set DOF and allow motion. Joints are
driven directly or via designated **actuators**, and the remaining joints
resolve as an actuator moves. The system must handle both **trees** (arms,
pan-tilt heads, hinged jaws) and **closed loops** (four-bars, parallelograms,
piston-cranks) — from one data model.

## 2. Principles & boundary

1. **AnimaCore (Python) is the single source of truth** for the model *and*
   the solve. Swift authors by calling bridge verbs and renders the poses
   returned; it never computes mate meaning.
2. **The data model is fixed across all phases; only the solver grows.** Trees
   and loops use the same parts/connectors/mates. Phase 2 adds solver
   capability, not new data. This is what makes "no half-measure" real without
   building everything at once.
3. **Mates are permanent, persisted constraints**, round-tripped to
   `.character.anima` — never one-time snaps.
4. **Renderer / UI / hardware stay out of the model.** Actuators reference DOF
   abstractly; hardware-channel binding is a later, separate concern.
5. **Transitional Swift logic migrates behind the bridge.** Swift keeps the
   gizmo, connector picking/rendering, and HUD; it loses local mate authoring,
   DOF templates, cycle detection, and connector-frame authority.

## 3. Canonical data model (AnimaCore)

| Entity | Role | Status |
|---|---|---|
| **Part** | Rigid body: rest transform (`position_m`, `rotation_euler_rad`) + `suppressed`/`grounded` states | Exists (`rig.py`) |
| **MateConnector** | Part-local oriented frame: `origin_m`, `primary_axis` (connector Z, the mated axis), `secondary_axis` (connector X), `flipped`, opaque `feature` provenance | Exists but nested inside a mate only → **promote to first-class, part-owned** |
| **Mate** | Constraint between connector A (parent) and B (child): `type` (all 10), per-type DOF set, `controls` (offset, flip, secondary rotation), `category` (kinematic/geometry) | Exists (`mates.py`); UI creates only revolute |
| **Relation** | Couples DOF values by formula (gear ratio, mirror, N:1), resolved in dependency order | Exists (`rig.py`) |
| **Assembly** | Named node grouping parts **and/or other assemblies** (nesting); own transform; groundable / suppressible / reusable (`.animasm`) | **New in engine** (today: flat, app-only groups) |
| **Actuator** | Marks a mate's DOF as *driven* (an animation/hardware channel); drives the DOF partition | **New concept** |

**The 10 mate types** and their DOF (from `JOINT_TYPE_DOF_TEMPLATES`):
`fastened` (0), `revolute` (Rz), `prismatic`/Slider (Tz), `cylindrical`
(Rz,Tz), `pin_slot` (Rz,Tx), `planar` (Tx,Ty,Rz), `ball` (Rx,Ry,Rz),
`parallel` (Tx,Ty,Tz,Rz), plus geometry constraints `width` (0) and `tangent`
(0, deferred).

**Relationships:** Assembly contains Parts + Assemblies (nesting tree) · Part
owns Connectors · Mate joins two Connectors on two Parts · Mates form a graph
over parts — a **tree** normally, a **loop** when a part carries two or more
mates that form a cycle · Relation and Actuator both reference DOF.

**The only structural change to what exists:** connectors become part-owned
entities (not mate-internal only), so they can be placed, listed, and reused
before mating. `Assembly` and `Actuator` are additive; everything else is
present.

## 4. Solver interface

One entry point that works for trees now and loops later without changing
callers:

```
solve_assembly(rig, drivers) -> AssemblySolution {
    part_poses:  { part -> world Transform },
    dof_values:  { dof  -> value },
    diagnostics: { converged, residual, iterations, limit_violations }
}
```

**DOF partition** (computed per solve): every DOF is exactly one of —
- **Driven** — set by an actuator or animation keyframe (explicit value).
- **Dependent** — computed by a Relation formula, in dependency order.
- **Free** — solved by the constraints (loops) or held at rest/neutral (trees).

**Algorithm:**
1. Resolve **driven** + **dependent** DOF (exists: `evaluate_pose`).
2. Split the mate graph into a **spanning tree** + **loop-closure** edges.
3. **Tree:** forward kinematics from grounded roots
   (`world[child] = compose(world[parent], child_in_parent(mate, dofs))`) —
   exists: `resolve_pose` / `child_in_parent` in `kinematics.py`.
4. **Loops (Phase 2):** each closure edge requires its two connector frames to
   coincide. Form residuals `r(q_free) = frameA ⊖ frameB` (6-vector per
   closure), solve `r = 0` for the free DOF by Newton–Raphson (finite-diff or
   analytic Jacobian, iterate to tolerance). Report non-convergence in
   diagnostics rather than throwing.
5. Return part poses + limit violations + convergence diagnostics.

For a tree, step 4 is empty and this reduces to the existing forward solver;
the signature never changes as the solver grows.

## 5. Bridge surface

Fills the plumbing gaps so authoring goes through the engine with a **live
re-solve** on the retained handle — replacing today's serialize→reload
round-trip that only validates on save.

| Group | Verbs | Status |
|---|---|---|
| Parts | `add_part`, `update_part`, `remove_part`, `move_part` (rest transform) | New |
| Connectors | `add_connector`, `update_connector`, `remove_connector`, `list_connectors` | New (part-owned) |
| Mates | `add_mate`, `update_mate`, `remove_mate` — **all 10 types** | Engine verbs exist; **wire the Swift client** |
| Assemblies | `add_assembly`, `update_assembly`, `remove_assembly`, `move_to_assembly` | New |
| Actuators | `set_actuator(mate, dof, driven)`, `list_actuators` | New |
| Solve | `solve_assembly` (returns diagnostics); handle-scoped incremental mutation | Extends `resolve_pose` |

Each mutating verb returns the updated rig summary + a fresh solve, so the app
renders immediately and the engine validates every edit (cycle rules, DOF
templates, limits) — not just on save.

## 6. Frontend / backend split

**Swift keeps (presentation):**
- `TransformGizmo` (move/rotate handles + hit-test) and the gizmo drag gestures.
- Connector picking/rendering: `MateConnectorInference` candidates,
  `MeshFeatureOverlay`, `MateConnectorMarkers`, `MatePlacementOverlay` HUD.
- `EngineResolvedPose` (quaternion→`Transform` adapter, semantics-free).
- Navigator/inspector rendering; the component-group tree becomes the
  Assembly tree view.

**Swift loses (→ engine verbs):**
- Local `createRevoluteJoint` / `JointDefinition` construction → `add_mate`.
- UI DOF/limit/offset templates (`MateEditorPresentation`) → `mate_types`
  catalog from the engine.
- Local rest-transform patch + serialize/reload → incremental verbs + live
  solve.
- `wouldCreateMateCycle` → engine validation.
- Connector-frame *authority* — Swift still picks the feature (which
  face/edge/point); the engine owns the frame math.

**New move/reorient flow:** gizmo drag → `move_part` → engine re-solves →
poses back → render. (Today: gizmo → local rig + DTO patch, validated on save.)

## 7. Phasing

Each phase is its own implementation spec + plan. The data model (§3) and the
solver/bridge interfaces (§4–5) are frozen now so no phase reworks another.

| Phase | Implements | Ships |
|---|---|---|
| **1 — Mate authoring (tree)** | part + connector verbs; `add_mate` all types; `solve_assembly` (tree); migrate Swift authoring behind the bridge | robot arms, pan-tilt heads, hinged jaws |
| **2 — Loop solver** | loop-closure Newton solve inside `solve_assembly`; data model unchanged | four-bars, parallelograms, piston-cranks |
| **3 — Actuators & driving** | actuator verbs + DOF partition surfaced; timeline/hardware driving | driven mechanisms |
| **4 — Nested sub-assemblies** | `Assembly` entity + verbs + `.animasm` reuse; navigator → assembly tree | reusable nested assemblies |

## 8. Success criteria (per phase)

- **P1:** In the app, import parts, place connectors on two of them, create a
  revolute (and a fastened, and a slider) mate through the engine; the child
  snaps to aligned position; changing the DOF value moves it; the whole thing
  round-trips to `.character.anima` and reloads identically. Deterministic
  engine unit tests for each mate type's alignment.
- **P2:** A four-bar linkage authored from four parts + four revolutes solves
  to a consistent closed configuration; driving one joint moves the coupled
  ones; solver reports convergence. Deterministic loop-closure tests.
- **P3:** Marking a joint as an actuator and setting its value resolves all
  dependent + free joints in one solve; actuator list is queryable for the
  hardware layer.
- **P4:** Parts nest into named sub-assemblies that ground/suppress/transform
  as a unit and save to `.animasm`; the navigator shows the nested tree.

## 9. Open questions (resolve during phase specs, not now)

- Loop-solver numerics: analytic vs. finite-difference Jacobian; tolerance and
  iteration caps; behavior on non-convergence (last-good vs. flag).
- Redundant/over-constrained mates: detect and warn, or reject at `add_mate`.
- Whether `move_part` on a mate-driven part is blocked (as today) or
  re-solves the mate that drives it.
- `.animasm` reuse: instance vs. copy semantics when the same sub-assembly is
  placed twice.
- Actuator ↔ hardware-channel binding lives in the transport layer, not here —
  confirm the boundary when Phase 3 is specced.

## 10. Non-goals

- Physics/dynamics (deferred; preview is kinematic).
- CAD drag-to-snap constraint editing as the *authoring* gesture — mates are
  declared and permanent; dragging edits a part's rest transform or a driven
  DOF, not a live constraint search.
- Hardware channel mapping (transport layer; consumes solved/actuator output).
