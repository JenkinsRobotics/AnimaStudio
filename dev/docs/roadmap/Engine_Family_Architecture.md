# Engine Family Architecture (decision record)

Decided with Jonathan, 2026-08-01. This is the standing strategy every
agent plans against.

## The family

One universal **Core**, consumed by thin end products, temporarily
co-located in this repo as sibling root folders:

- `core/` — the universal engine (product-free)
- `open-animation-studio/` — the animatronics/animation product
- `open-cad-studio/` — the CAD authoring product (started 2026-08-01)

Later products (simulation, show control) sit on the same Core. The
folders are scaffolds today; existing code (`animacore/`, `app/`)
migrates as the split solidifies rather than in one disruptive move.

## Layering

| Layer | Strategy | Today |
|---|---|---|
| Kernel (B-Rep math) | **Adopt, never build**: Open CASCADE behind our shim; swappable, never load-bearing for architecture | `app/Sources/AnimaCADShim` |
| Core / semantics | **Build & own**: mates, DOF, kinematics, scenes, evaluation, hardware contracts | `animacore/` |
| Core / SceneCore | **Build & own**: the one 3D world — entities with a single stable ID space (part instances, connectors, mates), transforms, selection, interaction ops | being built inside Anima Studio |
| Core / render contracts | **Build & own**: one entity stream consumed by Metal and WebGPU; GPU pick contract | `app/Sources/AnimaCADViewport` |
| Products | Thin front-ends over Core | `app/` today |

Renderer commitments: **OCCT and WebGPU stay** (with Metal as the native
co-primary). RealityKit is retired from CAD paths.

## Why SceneCore is the linchpin

Consistent progress on "place, interact, control, edit" stalled because
the 3D world existed as five hand-stitched partial copies (local rig vs
engine parts, rest vs resolved transforms, partID vs URL vs name keys,
per-renderer projections, per-feature join paths). Every regression of
the 2026-07-31 recovery week was one of those joins diverging. SceneCore
replaces the joins with one world model; renderers become "draw entities,
answer picks"; interactions become "read scene, write scene."

## The extraction discipline

Core is extracted from working products, never designed in a vacuum:

1. Build capabilities inside the product that needs them.
2. When a second product needs one, move it to Core unchanged-in-meaning.
3. A capability no product needs today does not enter Core.

## Non-negotiables carried forward

- AnimaCore remains the single canonical owner of animation/mate meaning.
- Viewport elements are real 3D geometry (CONVENTIONS.md).
- Picking is a GPU task.
- Dedicated files per subsystem, with behavior-pinning tests.
