# Conventions

The operating checklist for this repo. Inherited from the Jaeger
ecosystem's rules, trimmed to what Anima Studio actually uses.

## The two laws

1. **Modularize CONTRACTS early; modularize IMPLEMENTATIONS late.**
   One copy of every truth — format fields, wire commands, DOF
   semantics, dependency direction — from day one. A
   two-copies-of-one-truth bug is the worst kind: both copies look
   right in isolation. Don't split a boundary into a separate package
   or frozen interface until a *second real consumer* exists.
   **Units are part of the contract:** every contract field is SI with
   a unit-suffixed name (`_s`/`_ms`/`_m`/`_rad`/`_deg`/`_hz`; Swift
   spells them out: `timeSeconds`, `angleRadians`) — no bare numeric
   field ships without one.

2. **The nervous-system rule.** Lower layers never wait on higher
   ones; higher layers cannot bypass lower safety. Concretely here:
   AnimaCore's model/evaluation modules and the Swift model/evaluation targets
   never import UI or AI layers;
   hardware adapters consume evaluated targets and never reach into
   authoring state; firmware failsafes cannot be disabled from above.

## Where things live

- **`animacore/` (Python) — AnimaCore, the engine** — the headless
  animation core: `.anima` loading, rig/DOF evaluation, relations,
  scene execution, wire protocol host, simulator, extensions.
  Mechanism-agnostic: domain vocabulary (faces, cars, arms) appears
  only in `examples/` data, never in core types. Cross-platform; the
  app and firmware author for it.
- **`app/` (Swift)** — the macOS
  authoring app. Package ownership table and boundaries live in
  `AGENTS.md`.
- **`firmware/`** — the open microcontroller firmware speaking
  `dev/docs/roadmap/Wire_Protocol.md`.
## AnimaCore is the one engine (canonical)

`animacore/` is the **single canonical implementation** of animation
meaning: typed mates/DOF/limits/relations, validation, keyframe and
scene evaluation, mate alignment + kinematic pose resolution, `.anima`
parsing/writing, output mapping, transport, hardware safety, and
node-graph compilation. There is **no second engine.** The Swift app is
a **front end** that speaks the Studio↔AnimaCore protocol
(`dev/docs/roadmap/Studio_Bridge.md`) to a bundled AnimaCore helper; it
owns presentation, editing, rendering, and `.animastudio` editor
metadata, and holds DTOs that mirror engine results — it never
independently defines what a rig, pose, or frame means. The Swift
`AnimaEvaluation`/`RigPoseResolver` logic is transitional and is being
*replaced* by bridge calls, not extended. (Superseded the earlier
"parallel Swift/Python implementations with fixture parity" policy,
2026-07-15 — parity of two engines invited drift; one engine removes
the failure mode entirely.)

## Versioning & contract changes

- A **contract change** (a format field's meaning, a wire command, DOF
  semantics) is announced in the active briefing before editing both
  producer and consumer — see `AGENTS.md` → Cross-agent communication.
- Inside this repo's own boundary, delete-freely applies — no
  back-compat shims for internal refactors (pre-1.0; revisit when the
  format has external consumers).

## No spec ahead of code

A doc never describes behavior the code doesn't implement yet. If it's
designed but not built, label it **`(planned)`** inline — planned
behavior lives in `dev/docs/roadmap/`, shipped truth in
`dev/docs/reality/STATUS.md`. A doc describing a phantom feature costs
someone a debugging session before they find out it was fiction.

## STATUS stays truthful

Any commit that changes behavior updates `dev/docs/reality/STATUS.md`
in the **same commit**. STATUS.md is the one place a new contributor
(human or agent) reads to get current truth without archaeology.
Stale STATUS.md is a bug.

## Walk the flow before shipping

Inspection is not verification. Before shipping a user-facing flow
change, run it start to finish as the operator would — launch the app,
click the flow, watch the servo move. Don't ship on "the code looks
right."
