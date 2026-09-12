# Aether Core module architecture

Aether has two shared foundations: **Aether Core** for behavior and data, and
**Aether UI** for visual components. Product applications compose those two;
they do not create product-local copies of shared truth.

Both packages live under the shared `core/` parent: this package in `engine/`,
and the UI package in `ui/`. Directory grouping does not add an engine-to-UI
dependency.

## Current production modules

| Module | Responsibility | May depend on |
| --- | --- | --- |
| `contracts` | Renderer-neutral geometry, topology, connector, mate, and worker DTOs | TypeScript only |
| `sketch` | Sketch entities, constraints, dimensions, validation, and definition state | `contracts` when needed |
| `document` | Versioned Part state, stable IDs, migrations, deterministic serialization | `sketch`, `contracts` |
| `geometry` | Coordinate frames and topology-inference policy | `contracts` |
| `assembly` | Homogeneous transforms and mate solving | `contracts` |
| `kernel` | OCCT/Replicad WASM startup, STEP import, exact topology, B-Rep evaluation, disposable render tessellation | semantic modules, OCCT/Replicad |

The semantic modules never import React, Three.js, WebGPU, browser UI, or a
product application. The `kernel` module is the supported browser/WASM adapter
over the exact geometry engine.

## Next extracted modules

These remain one `@aether/core` package with subpath modules—not separate
top-level projects:

- `render`: shared scene/entity/material/camera/picking contracts plus the
  Three.js/WebGPU implementation already proven by Aether CAD and Animation;
- `assets`: source identity, packing/reference policy, dependency resolution,
  render caches, and media metadata;
- `physics`: deterministic collision, rigid-body, and dynamics contracts once
  Aether Dynamics supplies a working implementation;
- `connection`: application-to-Core session/RPC contracts, never raw product UI;
- `workspace`: the canonical `.aether` graph and Part/Assembly/Drawing/
  Animation view projections.

Concrete render code may live in Core because it is shared engine behavior,
but semantic modules must never depend upward on that implementation. Physics
is not represented by placeholders: it enters Core only when a working product
needs and verifies it.

## Dependency direction

```text
Aether CAD ───────┐
Aether Animation ─┼──> Aether UI
Aether Dynamics ──┘

Aether CAD ───────┐
Aether Animation ─┼──> Aether Core render/kernel adapters
Aether Dynamics ──┘              │
                                 v
                     Aether Core semantic modules
```

A product may supply file pickers, windows, workflows, and inspectors. It may
not define a second Part format, mate solver, topology identity, or animation
meaning.
