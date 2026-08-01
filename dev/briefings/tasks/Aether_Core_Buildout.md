# Aether Core Buildout (handoff brief, 2026-08-01)

Goal for this session: **build out `aether-core/`** — the universal engine of
the Aether ecosystem — by (1) extracting the core-level pieces from the
animatronics stack, and (2) adopting the better-performing implementations
from Jonathan's live `Aether CAD/` web app as the reference for the web side.

Read first, in order:
1. `CLAUDE.md` (the contributor contract — mailboxes, claims, verification)
2. `dev/docs/roadmap/Engine_Family_Architecture.md` (the standing ADR:
   suite lineup, layering, extraction discipline, renderer priorities)
3. `aether-core/README.md` (target state and the Aether naming rule)
4. `Aether CAD/ARCHITECTURE.md` and `Aether CAD/AETHER_CORE_EXTRACTION.md`
   (Jonathan's own extraction notes from the CAD side)
5. `CONVENTIONS.md` (incl. "Viewport elements are real 3D geometry")

## Why Aether CAD is the reference

Jonathan reports the `Aether CAD/` web app renders faster/smoother and has a
better mating function than the Swift app. Its lineage is
`dev/OCCTMateLab/` (connector-first mate authoring, exact OCCT topology
inference, GPU-side picking, Three.js/WebGPU). Where the CAD app and the
animation stack implement the same capability, **the CAD app's
implementation wins** and gets extracted into Core; the animation stack
then consumes Core.

## What to extract into aether-core/

From the animatronics stack (rename into the Aether identity at the
border — product names never enter Core):

- `animacore/` (Python) — semantics engine: mates/DOF/kinematics/scenes/
  evaluation/hardware contracts. Owns all animation meaning; stays canonical.
- `app/Sources/AnimaCAD` + `AnimaCADShim` → the OCCT kernel seam
  (**AetherKernel**): STEP import, renderer-neutral document, exact topology.
- `app/Sources/AnimaCADViewport` core pieces → **AetherViewport** contracts:
  the entity/render presentations both Metal and WebGPU consume, GPU
  ID-buffer picking, engine-drawn in-world tools (gizmo, connector triads,
  snap-node illumination, `CADConnectorCandidateEngine`).

From `Aether CAD/` (Jonathan's live app — coordinate with him before moving
files he is editing): the web renderer setup, its mate/connector flow, and
whatever its `AETHER_CORE_EXTRACTION.md` already designates as Core.

## Standing rules that bind this work

- **WebGPU is the priority renderer** (web-first CAD); nothing lands
  Metal-only.
- **OCCT is adopted, never rebuilt**; it stays behind the kernel seam.
- **No CPU raycasting** — picking is a GPU task (ID buffer).
- **In-world tools are engine-drawn real 3D geometry**; app shells (Swift or
  web) are thin wrappers carrying flat chrome only. No screen-space decals.
- **Extraction discipline**: a capability enters Core only when a product
  needs it today; extract from working code, don't redesign in flight.
- **Segregation**: dedicated files per subsystem + behavior-pinning tests
  (pattern: `draggedPartTransformSurvivesPlayheadRefresh`).
- Shared checkout: claim before editing (briefing Live claims), stage
  explicit paths only, never commit others' in-flight files, append a
  Handoff log entry, update STATUS.md with behavior changes.

## Known open items (not this session's goal, don't lose them)

- Mate rows in the Swift navigator can't be selected/deleted (bug).
- Persistent Place-Connector anchors (engine-owned `mate_connectors` on
  parts + bridge verbs) — designed in
  `dev/docs/roadmap/Mate_Connector_Lab_Incorporation.md`.
- WebGPU port of the in-world toolset (gizmo/triads/snap nodes) — top
  renderer packet; Metal got them first, which predates the WebGPU-first
  directive.
- SwiftUI ViewCube → engine-side port. Box-select still CPU-side.

## Verification baseline at handoff

`cd app && swift build && swift test` → 378 XCTest + 72 Swift Testing green.
`.venv/bin/pytest animacore/tests` → ~1160+ green. Root app builds and
launches via `app/Scripts/build-root-app.sh`. Branch is ~70 commits ahead of
origin (unpushed); working tree carries Jonathan's and Codex's in-flight
files (`Aether CAD/`, README/briefing edits) — leave them uncommitted.
