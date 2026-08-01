# Aether Core

**Aether Core** is the universal engine of the Aether ecosystem — the
CAD, rendering, and scene core every end product shares. Product-free by definition: nothing
in here may know a specific product, UI, or hardware brand exists.

Everything baked into this engine carries the Aether identity as its
module prefix: **AetherScene**, **AetherViewport**, **AetherKernel**,
**AetherRender**. When a capability is extracted from a product into
Aether, it is renamed into that identity (e.g. `AnimaCADViewport` →
`AetherViewport`); product-branded names never live here.

## What lives here (target state)

- **Semantics engine** — mates, DOF, kinematics, scenes, evaluation,
  hardware output contracts. Currently `/animacore/` (Python); migrates
  here as the split solidifies.
- **AetherScene** — the 3D world model: entities with one stable ID space
  (part instances, connectors, mates), transforms, selection, interaction
  operations. Being built now inside Anima Studio; extracted here once it
  serves its first product.
- **AetherViewport / AetherRender** — the entity stream Metal and WebGPU
  both consume, and the GPU pick contract. Currently in
  `app/Sources/AnimaCADViewport`.
- **AetherKernel seam** — Open CASCADE stays adopted, isolated behind our
  shim (`app/Sources/AnimaCADShim`). Aether defines the boundary; the
  kernel is a swappable component, never the architecture.

## The one rule

Aether is EXTRACTED from working products, never designed speculatively.
A capability enters Aether Core only when a product needs it today. See
`dev/docs/roadmap/Engine_Family_Architecture.md`.
