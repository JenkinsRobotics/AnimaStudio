# Where we are — Aether Suite pause checkpoint

_Resume here after the development pause · 2026-08-01_

## The short version

The repository is becoming the **Aether Suite**. There are several product
applications, but exactly two shared foundations:

1. **Aether Core** (`aether-core/`) owns reusable behavior and authoritative
   data: geometry, sketches, constraints, documents, topology, assembly math,
   OCCT, rendering, assets, physics, connections, and workspace state.
2. **Aether UI** (`aether-ui/`) owns reusable visual components and interaction
   patterns: trees, ribbons, dialogs, panels, timelines, themes, and workspace
   chrome.

Do not create more shared top-level frameworks. A new shared capability goes
inside Core or UI as an internal module. A product keeps only its workflows,
file/window integration, and domain-specific experience.

## Critical repository warning

The latest committed checkpoint is `11cc6c9`, but important work is still
**uncommitted** in the shared checkout:

- `Aether CAD/` is currently untracked as a directory;
- the new TypeScript `aether-core/` package is currently untracked except for
  the separately owned README;
- the Aether workspace-format document and coordination/status edits are dirty;
- the old `open-cad-studio/README.md` removal is part of the rename transition.

Do **not** run `git clean`, `git reset --hard`, broad restore commands, or delete
untracked directories when resuming. First run `git status --short`, review the
ownership log, and make an explicit integration commit for the Core/CAD work.

## Product state

### Aether CAD — working vertical slice, not yet safely committed

Location: `Aether CAD/`

Current capabilities:

- React 19 CAD shell using `@aether/ui`, with Items/History panels, floating
  tool rails, ViewCube, reference planes, and a persistent viewport;
- exact Open CASCADE Technology through Replicad/OpenCascade.js WebAssembly;
- Three.js WebGPU rendering with WebGL 2 fallback;
- STEP import with exact B-Rep faces, edges, analytic topology, and disposable
  tessellation;
- connector-first authoring with persistent Part-local anchors;
- Fastened mate transform proof using
  `W1new = W2 · T2 · RflipX · inverse(T1)`;
- principal-plane Sketch workflow, center rectangle, initial constraints and
  dimensions, blue/black definition feedback, and exact Extrude rebuild;
- deterministic transitional `.cadpart` save/open with version migration.

The product now consumes `@aether/core` for extracted semantics and the OCCT
worker. Temporary files in `Aether CAD/src/` re-export Core symbols only to
preserve imports; they are not a second engine.

Build a clickable root application from `Aether CAD/` with:

```bash
./Scripts/build-macos-app.sh
```

### Aether Animation — committed web rebuild

Locations: `aether-animation/web/` and `animacore/`

- React/Vite app uses the shared Aether UI workspace shell;
- left Character/Parts/Mates/Clips and right Inspector/Pose panels work across
  docked, floating, and canvas layouts;
- eight kinematic mate tools, two-connector selection, solve preview, and mate
  creation are wired to the Python engine;
- timeline/dope-sheet displays per-DOF tracks, scrubs, and plays evaluated
  motion;
- `Aether Animation.app` can launch the web UI and Python bridge together.

Important gaps:

- timeline keyframes are read-only until clip create/update/delete verbs land;
- web Assets/STEP import is not wired;
- Show and Hardware workspaces still need real session/output verbs;
- the Python package is still called `animacore` pending one atomic rename.

### Aether Dynamics — named product, implementation deferred

Location: `aether-dynamics/`

This is currently a product direction, not a shipped physics engine. Do not add
placeholder physics to Core. Extract collision, rigid-body, or simulation code
only after Dynamics has a working, tested implementation needed by a product.

## Shared foundation state

### Aether Core

Location: `aether-core/`

The first production TypeScript package now exists as `@aether/core`, organized
into internal modules rather than separate projects:

- `contracts` — renderer-neutral geometry/topology/worker DTOs;
- `sketch` — entities, constraints, dimensions, validation, definition state;
- `document` — stable Part state, migrations, deterministic serialization;
- `geometry` — frames and exact-topology inference policy;
- `assembly` — homogeneous transforms and Fastened mate solving;
- `kernel` — OCCT/Replicad WASM, STEP import, exact B-Rep topology,
  tessellation projection, and parametric Part evaluation.

Core semantic modules contain no React or Three.js. The kernel is the supported
browser/WASM adapter. Planned capabilities stay inside the same package:

- `render` — renderer-neutral scene/material/camera/picking contracts and the
  shared Three.js/WebGPU implementation;
- `assets` — source identity, copy/reference policy, dependencies, media, and
  derived caches;
- `connection` — session/RPC contracts;
- `workspace` — canonical `.aether` graph and view projections;
- `physics` — only after a real verified implementation exists.

The Python `animacore` implementation is still the animation semantic authority
during the transition. Rename and merge it atomically; do not leave both
`animacore` and `aether_core` as competing engines.

### Aether UI

Location: `aether-ui/`

The React design system is committed and tested. It includes the definitive
Tree, Tabs, Dialog, Ribbon, TextField, Rail, StatusBar, ViewportCanvas,
WorkspaceShell, FloatingPanel, DocumentBar, LayoutPresetButton, and Timeline.
Use `aether-ui/WIDGETS.md` as the widget conformance/status matrix. Applications
provide data and actions; they should not fork these widgets.

## Format decisions that must survive the pause

- Start with one unified `.aether` workspace container. Part, Assembly,
  Drawing, Animation, and Show are projections of one stable-ID graph.
- The deterministic semantic graph is truth. OCCT B-Rep snapshots, render
  meshes, and thumbnails are disposable, hash-gated caches.
- CAD mates and Animation joints/DOFs are the same Core entity, not an export
  translation.
- Numeric contract fields use explicit units.
- STEP/IGES/STL/OBJ are realistic interop targets. Parasolid and DWG require
  licensing and must not be promised as free native support.
- Core and UI are the only shared foundations. CAD, Animation, and Dynamics are
  products—not general-purpose dependency packages.

## Last verification at this checkpoint

```text
Aether Core: 4 test files / 8 tests passed; TypeScript check passed
Aether CAD: 12 test files / 36 tests passed; TypeScript check passed
Aether CAD production build: passed, including OCCT worker + WASM output
Aether UI committed checkpoint: 32 tests green
```

Repeat the relevant checks after resuming:

```bash
cd aether-core
npm test
npm run check

cd "../Aether CAD"
npm test
npm run check
npm run build

cd ../aether-ui
npm test
npm run typecheck

cd ../aether-animation/web
npm run build
```

## Exact restart sequence

1. **Protect the current work.** Read `AGENTS.md`, `CONVENTIONS.md`, this file,
   the active briefing, and both mailboxes. Run `git status --short`; review and
   commit the untracked Aether CAD/Core extraction deliberately.
2. **Finish the Core render boundary.** Define one renderer-neutral
   scene/entity/material/camera/picking contract, then move the proven
   Three.js/WebGPU adapter behind the internal `render` module.
3. **Extract deterministic assembly authoring.** Move connector/mate registry
   state into Core after replacing browser-generated IDs with an injected,
   deterministic ID source.
4. **Introduce the `.aether` graph.** Wrap the working Part projection first;
   then add Assembly and Drawing views without creating parallel document
   truth.
5. **Unify the animation engine name.** After active bridge work is released,
   atomically rename/move Python `animacore` into Aether Core and update every
   entry point, test, example, and launcher in one change.
6. **Complete Aether Animation authoring.** Add clip CRUD, Assets import, then
   Hardware/Show session and output verbs.
7. **Start Dynamics only from a real need.** Do not invent speculative physics
   abstractions before an executable simulation slice exists.

## Navigation map

- `aether-core/ARCHITECTURE.md` — current Core/UI boundary and dependency law.
- `Aether CAD/AETHER_CORE_EXTRACTION.md` — what moved and remaining gates.
- `dev/docs/roadmap/Aether_Workspace_Format.md` — planned native format law.
- `aether-ui/WIDGETS.md` — reusable UI inventory and conformance status.
- `dev/docs/reality/STATUS.md` — shipped truth, chronologically recorded.
- `dev/briefings/2026-07-14-bottango-parity.md` — live claims and full handoffs.
- `dev/briefings/claude.md` and `dev/briefings/codex.md` — directed assignments.
