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
   `AnimaCore` and the Python runtime never import UI or AI layers;
   hardware adapters consume evaluated targets and never reach into
   authoring state; firmware failsafes cannot be disabled from above.

## Where things live

- **`anima_studio/` (Python)** — the headless runtime: `.anima`
  loading, rig/DOF evaluation, relations, wire protocol host,
  simulator. Mechanism-agnostic: domain vocabulary (faces, cars, arms)
  appears only in `examples/` data, never in core types.
- **`studio/` (Swift)** — the macOS authoring app. Package ownership
  table and boundaries live in `AGENTS.md`.
- **`firmware/`** — the open microcontroller firmware speaking
  `dev/docs/roadmap/Wire_Protocol.md`.
- **Cross-implementation parity:** the `.anima` format and Wire
  Protocol docs in `dev/docs/roadmap/` are the contracts; Swift and
  Python implement the same semantics with fixture parity tests, and a
  contract change updates the doc before either implementation.

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
