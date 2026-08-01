# Core

The universal engine every end product shares. Product-free by definition:
nothing in here may know a specific product, UI, or hardware brand exists.

## What lives here (target state)

- **AnimaCore** — semantics: mates, DOF, kinematics, scenes, evaluation,
  hardware output contracts. Currently at `/animacore/` (Python); it migrates
  here as the split solidifies.
- **SceneCore** — the 3D world model: entities with one stable ID space
  (part instances, connectors, mates), transforms, selection, interaction
  operations. Being built now inside Anima Studio; extracted here once it
  serves its first product.
- **Render contracts** — the entity stream Metal and WebGPU both consume,
  and the GPU pick contract. Currently in `app/Sources/AnimaCADViewport`.
- **Kernel seam** — Open CASCADE stays adopted, isolated behind our shim
  (`app/Sources/AnimaCADShim`). Core defines the boundary; the kernel is a
  swappable component, never the architecture.

## The one rule

Core is EXTRACTED from working products, never designed speculatively.
A capability enters Core only when a product needs it today. See
`dev/docs/roadmap/Engine_Family_Architecture.md`.
