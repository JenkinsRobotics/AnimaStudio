# Aether Studio contributor contract

## Current suite direction — 2026-09-08

**Aether Studio is the server** (Jonathan, 2026-09-11). The repo root is not a
grab-bag of shared code: it holds the backend — accounts, sessions, document
storage, the wire protocol — in `core/host/` and `core/session/`. Products are
self-contained and sit beside it.

| Tier | Path | Owns |
|---|---|---|
| Server | `core/host/`, `core/session/` | accounts, sessions, documents, protocol |
| Product | `Aether CAD/` | its kernel binding, solver, feature layer, UI |
| Product | `aether-animation/` (+ `animacore/`) | its own engine and UI |
| Shared | `core/ui/`, `core/assets/` | design system and artwork — nothing else |

A product owns everything specific to it, the way Onshape owns its kernel
binding and feature library. Do not add a third tier of "shared logic": if only
one product uses it, it belongs to that product. The animation product is
**Aether Animation**. The primary applications are web-based React/TypeScript:
`Aether CAD/` and `aether-animation/web/`, sharing `core/ui/`. The single locally
hosted installation and multiple application packages remain planned; see
`dev/docs/roadmap/Aether_Studio_Suite.md`. The Onshape mockup is an interaction
reference, not the production CAD engine. Codex owns web GUI and cross-lane review;
Claude owns the Python backend/protocol. Older Swift lane/path instructions below
are historical and superseded: Swift is archived at `aether-animation/archive/`.
The `core/` parent groups shared infrastructure. `core/ui/` is `@aether/ui`,
the only genuinely cross-product asset — Aether CAD, `studio/`, and
`aether-animation/web/` all consume it.

**`Aether CAD/engine/` is the CAD engine** (`@aether/core`), owned by the CAD
product — not suite-shared. It was `core/engine/` until 2026-09-11; measured
then, its only consumers were Aether CAD (104 files) and two `core/ui/gallery`
demos, and `aether-animation/web` never imported it (the animation lane's
engine is `animacore/`, Python). Moved per Jonathan's Onshape-product-shape
decision; record and acceptance gates in
`dev/briefings/2026-09-11-engine-ownership-move.md`. Do not move it back on
the strength of older wording elsewhere, and do not add a consumer of
`@aether/core` outside Aether CAD — if a second product needs a capability,
that is a design conversation, not an import.

`core/ui` must never depend on a product's engine. Its `@aether/core` entry is
a **devDependency** used only by the gallery's validated feature demos;
`core/ui/src/` stays clean of it. Verified 2026-09-11:
`aether-animation/web/node_modules/@aether/` contains only `ui`.
Shared artwork belongs in `core/assets/`: SVG interface icons in `icons/`,
identity artwork in `branding/`. `core/ui/` supplies the presentation components;
products must not copy icon geometry or substitute emoji for shared icons.

Visual authority: the old native Anima Studio interface, ported into shared
`core/ui/` and consumed by both web apps. ViewCube, trees/tables, fields, icons,
typography, themes and panel behavior must be consistent; tool sets and layout
may differ. See `dev/docs/roadmap/Aether_Studio_UI_Convergence.md`. Keep the
Onshape mockup until its useful interactions are integrated and verified.
Existing semantic ownership and file-claim rules still apply.


This repository is building an open animation, motion-authoring, and show-control
system for digital characters and physical audio-animatronic robots. The first
product milestone is hardware animation authoring: import an existing model,
define its movable structure, animate it on a timeline, preview it, and later
route the same evaluated motion to hardware.

This file is the shared briefing for every agent working the repo —
Claude Code reads it as `CLAUDE.md` (a symlink to this file), Codex
reads it as `AGENTS.md`. Edit this one file only.

Two channels, two jobs (per Jonathan, 2026-07-14 — resolving an earlier
conflict between agent edits):

- **Mailboxes** `dev/briefings/claude.md` / `dev/briefings/codex.md` —
  directed messages and task assignment (IN = others write, owner
  checks off; OUT = owner's replies/findings). Jonathan drops tasks
  here too.
- **The active goal file** in `dev/briefings/` — Live claims (file
  ownership), Requests (blocking cross-lane questions), Handoff log
  (session summaries). File ownership never lives in mailboxes.

## Team roles

The current goal is Bottango-level capability, working straight down
[`dev/docs/roadmap/Bottango_Parity.md`](dev/docs/roadmap/Bottango_Parity.md).

- **Claude Code — backend** (per Jonathan, 2026-07-14, superseding the
  earlier all-implementation split): the Python AnimaCore engine
  (`animacore/`), the wire protocol and its simulator, `.anima`
  loading/execution, and the microcontroller firmware
  (`firmware/`, when it exists).
- **Codex — Swift app GUI** (`aether-animation/app/`), plus planning + review across
  both lanes: reviews commits/diffs, sequences the next checklist
  slices, assigns tasks.
- Planning is teamwork — either agent may propose; disagreements get a
  mailbox note, not a silent revert.

Agents communicate indirectly through mailboxes in `dev/briefings/`:
[`claude.md`](dev/briefings/claude.md) and
[`codex.md`](dev/briefings/codex.md). Each has **IN** (others write
tasks/messages there; the owner checks them off) and **OUT** (the owner
writes replies, findings, plans). **Every session: read your mailbox
IN before working, write your OUT before stopping.**

## Read before changing code

1. [`CONVENTIONS.md`](CONVENTIONS.md)
2. [`dev/docs/reality/STATUS.md`](dev/docs/reality/STATUS.md)
3. Your mailbox and the active briefing in
   [`dev/briefings/`](dev/briefings/README.md) — current goal, task
   assignments, claims, and the handoff log you append to after each
   session.
4. [`dev/docs/roadmap/Hardware_Animation_Milestone.md`](dev/docs/roadmap/Hardware_Animation_Milestone.md)
5. [`dev/docs/roadmap/Studio_App.md`](dev/docs/roadmap/Studio_App.md)
6. The format document affected by the change:
   [`Character_Format.md`](dev/docs/roadmap/Character_Format.md) or
   [`Scene_Format.md`](dev/docs/roadmap/Scene_Format.md)
7. For CAD import, viewport, or packaging work:
   [`CAD_Rendering.md`](dev/docs/roadmap/CAD_Rendering.md)

## One engine (canonical) — read this first

`animacore/` (Python) is the **single canonical engine**: it owns the
meaning of mates/DOF/limits/relations, validation, evaluation, mate
alignment + pose resolution, `.anima` I/O, output/transport/safety, and
node-graph compilation. The Swift app is a **front end** that calls it
over the Studio↔AnimaCore bridge (`dev/docs/roadmap/Studio_Bridge.md`)
and owns only presentation, editing, rendering, and `.animastudio`
editor metadata. **Do not add or extend animation-*meaning* logic in
Swift** — the existing `AnimaEvaluation`/`RigPoseResolver`/
`MateConnectorMath` code is transitional and gets replaced by bridge
calls. New semantics land in `animacore/`, surfaced through the bridge.

## Original branding preservation

Keep `core/assets/branding/originals/` permanently: Jonathan requested retaining
the original CAD and Anima Studio icons even when different icons are active.
Never overwrite or remove these archived sources during icon generation, app
rebuilds, or native-app cleanup. New variants belong in separate directories.

## Non-negotiable boundaries

- AnimaCore's model and evaluation layers are renderer-, UI-, AI-, and
  hardware-independent. The engine also hosts transport modules today; those
  consume evaluated targets and must not define animation semantics.
- RealityKit displays evaluated state; it does not define timeline or rig
  semantics.
- Hardware adapters consume evaluated targets; vendor channel details do not
  enter the core animation model.
- Contract fields use explicit units. Swift properties use names such as
  `timeSeconds`, `angleRadians`, and `velocityRadiansPerSecond`.
- Physics/dynamics simulation is deferred. Preview is kinematic.
- Model creation belongs in Blender/CAD tools. Studio imports and animates.
- AI assistance is optional authoring functionality; saved animation never
  requires an AI model to play.

## Swift package ownership

| Target | Owns | Must not own |
|---|---|---|
| `AnimaModel` | Swift in-memory projection of rigs, joints, clips, keyframes, projects, validation | evaluation, SwiftUI, RealityKit, file dialogs, hardware SDKs |
| `AnimaEvaluation` | Swift preview evaluation, curves, evaluated frames, mate transform math | SwiftUI, RealityKit, file dialogs, hardware SDKs |
| `AnimaDocument` | versioned project-package encoding, migrations, project-relative asset storage and resolution | SwiftUI views, RealityKit, timeline evaluation, hardware SDKs |
| `AnimaViewport` | renderer-neutral preview contracts | concrete renderer behavior |
| `RealityKitViewport` | model loading/display, camera, selection, joint gizmos | persisted format semantics, hardware mapping |
| `AnimaStudioUI` | workspace state and reusable SwiftUI views, commands, panels, presentation logic | app signing/resources, duplicate evaluator logic |
| `AnimaStudioApp` | thin macOS lifecycle target, app resources, entitlements, app-only document/file integration | reusable workspace views, evaluator logic |

Add a new target only when it represents a proven dependency boundary. Do not
create speculative plugin packages.

## Working agreements for parallel contributors

- **Read `git status` before every claim and before every commit.** An untracked
  or modified file may be another agent's in-flight work.
- Claim a bounded task and its file globs in the active briefing before editing.
  Only one active claim may cover a file at a time.
- Keep changes within one ownership area when possible.
- Announce or document contract changes before editing both producer and
  consumer targets.
- Never create a second representation of a shared truth merely for one view;
  add a projection/helper around the core type.
- New evaluator behavior requires deterministic unit tests.
- New visible behavior requires `dev/docs/reality/STATUS.md` to change in the
  same work unit.
- Planned behavior stays in `dev/docs/roadmap/`; shipped behavior stays in
  `dev/docs/reality/STATUS.md`.
- Preserve unrelated working-tree changes. This repo may be edited by multiple
  contributors at once.
- Stage explicit paths only. Never use `git add -A`, `git add .`, or commit an
  unclaimed file while another claim is active.
- Never stash, clean, reset, checkout, rebase, or run a repo-wide formatter in
  the shared checkout while another agent has an active claim.
- Run formatters only over files in the current claim.
- A generic role does not override the active lane split. By default Claude
  takes large implementation packets; Codex leads architecture, review,
  integration, and targeted implementation. The active briefing assigns the
  concrete files and acceptance test for each packet.

## Cross-agent communication

Mailboxes carry directed tasks and replies. The active briefing is the
authoritative coordination ledger for the shared checkout:

1. Add a row to **Live claims** before editing.
2. Put questions that block another lane in **Requests** with the contract or
   decision needed; do not silently invent a cross-lane API.
3. Append a concise **Handoff log** entry after verifying the work.
4. Mark the claim `released` only after listing changed files and test results.
5. The receiving/reviewing agent records its review result in the same log.

Commits are integration checkpoints, not the communication channel by
themselves. A commit without a handoff entry is incomplete multi-agent work.

## Verification

Web UI (Aether UI design system), from `core/ui/`:

```bash
npm test && npm run typecheck && npm run build
```

Aether Animation web app, from `aether-animation/web/` (the engine HTTP
bridge must be running for manual testing:
`.venv/bin/python -m animacore.httpbridge`):

```bash
npm run build   # tsc --noEmit + vite build
npm run dev     # live app on http://localhost:5178
```

The Swift app is ARCHIVED at `aether-animation/archive/` (2026-08-01) —
do not build it in CI; treat it as the behavior reference for the web
rebuild.

Python (AnimaCore engine), from the repo root:

```bash
.venv/bin/ruff check .
.venv/bin/pytest animacore/tests
```

For a user-facing workspace change, also launch the native app target (or the
root `Anima Studio.app`) and walk the changed flow when the environment permits
GUI execution.
