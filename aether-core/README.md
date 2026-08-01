# Aether Core

**Aether Core** is the universal headless engine of the Aether ecosystem: the
mathematical kernel, parametric B-Rep DAG, geometric/assembly constraint
solver, and deterministic state authority shared by every product. Product-free
by definition: nothing here knows a specific product, UI, or hardware brand.

Everything baked into this engine carries the Aether identity as its
module prefix: **AetherScene**, **AetherViewport**, **AetherKernel**,
**AetherRender**. When a capability is extracted from a product into
Aether, it is renamed into that identity (e.g. `AnimaCADViewport` →
`AetherViewport`); product-branded names never live here.

## What lives here (target state)

- **AetherKernel** — the supported Open CASCADE build, WebAssembly/C++ bridge,
  B-Rep operations, STEP/IGES import/export, topology identity, tolerances, and
  exact geometric queries. OCCT is adopted; Aether owns its stable seam.
- **Parametric state engine** — versioned feature DAGs, deterministic rebuild,
  stable IDs, migrations, diagnostics, and undoable semantic operations.
- **Constraint solvers** — 2D sketch constraints plus 3D assembly mates, DOF,
  limits, and kinematic transforms.
- **Deterministic evaluation** — pure state in → state out contracts usable by
  CAD and animation products without renderer or platform dependencies.
- **Workspace authority** — the planned `.aether` graph, semantic hashing,
  migrations, and deterministic serialization. Part/Assembly/Drawing are
  projections of this one graph; B-Rep and render snapshots are derived caches.
- **AetherScene** — the 3D world model: entities with one stable ID space
  (part instances, connectors, mates), transforms, selection, interaction
  operations. Being built now inside Anima Studio; extracted here once it
  serves its first product.
- **AetherViewport / AetherRender** — the entity stream Metal and WebGPU
  both consume, and the GPU pick contract. Currently in
  `app/Sources/AnimaCADViewport`.

## What never lives here

- application UI, file pickers, window state, or product workflows;
- Three.js, Metal, or other concrete presentation behavior;
- serial, CAN, Art-Net, vendor SDKs, or raw hardware drivers;
- product-specific puppetry, timeline, library, or show-control experiences.

Aether Core may produce deterministic motion/trajectory values. Aether
Animation owns routing those values to real hardware output buses.

## Language boundary (2026-08-01, per Jonathan)

Aether Core holds **no Swift**. Core is the platform-universal engine —
the OCCT/C++/WASM kernel seam, the web (WebGPU) engine pieces designated
by `Aether CAD/AETHER_CORE_EXTRACTION.md`, and the Python semantics
engine. Swift is product code: the native bindings and viewport contracts
extracted from Anima Studio live in `aether-animation/AetherKit`
(`AetherKernel` + `AetherViewport`), which BINDS this Core. When the
C++/WASM kernel consolidates here, AetherKit's shim becomes a thin
consumer of the Core-owned OCCT build.

## The one rule

Aether is EXTRACTED from working products, never designed speculatively.
A capability enters Aether Core only when a product needs it today. See
`dev/docs/roadmap/Engine_Family_Architecture.md`.
