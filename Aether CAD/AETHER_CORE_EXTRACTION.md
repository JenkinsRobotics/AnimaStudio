# Aether Core extraction boundary

Aether CAD now consumes a real root `@aether/core` package. There is one
implementation of each extracted semantic and kernel behavior; the files left
under `Aether CAD/src/` are temporary import-compatible adapters, not parallel
evaluators.

## Extracted now

- renderer-neutral geometry, topology, connector, mate, and worker DTOs;
- versioned Part and Sketch state, constraints, validation, migration, and
  deterministic serialization;
- coordinate-frame and topology-inference policy;
- pure homogeneous transform math and the Fastened mate solve;
- the supported Replicad/OpenCascade.js WASM worker;
- exact B-Rep face/edge topology and analytic connector candidates;
- STEP import, tessellated render projection, and parametric Part evaluation.

`src/aether-core.ts` remains Aether CAD's product-facing facade. It combines
the shared Core exports with the app-specific lifetime boundary used to create
the embedded worker client.

## Still owned by Aether CAD

- React application shell and commands;
- browser file pickers and downloads;
- Three.js/WebGPU viewport presentation, camera, ViewCube, and gizmos;
- topology and connector visualization;
- session-only UI state and presentation preferences.

Three.js/WebGPU is expected to move into the internal `render` module of the
single `@aether/core` foundation after its CAD and Animation adapters converge.
It does not become a separate top-level project. Until then, CAD remains its
working source and no duplicate renderer is introduced.

## Remaining extraction gates

1. Move connector/mate registry state after its ID allocation is injected and
   deterministic rather than calling browser globals directly.
2. Define one renderer-neutral scene/entity/material/picking stream used by
   both Aether CAD and Aether Animation.
3. Move the proven Three.js/WebGPU adapter behind that Core render contract.
4. Introduce the canonical `.aether` workspace graph around the current Part
   projection, then add Assembly and Drawing views.
5. Rename the Python `animacore` namespace atomically after the active Aether
   Animation bridge work releases; no half-renamed dual engine is permitted.

## Extraction rules

1. Never introduce a second evaluator while moving files.
2. Never expose OCCT or Three.js objects in semantic contracts.
3. Preserve explicit units and stable IDs in every DTO.
4. B-Rep and render buffers are derived caches; deterministic graph state is
   the authority.
5. Prove byte-stable serialization, equal mate transforms, full CAD tests,
   type-check, and production build at each boundary move.
