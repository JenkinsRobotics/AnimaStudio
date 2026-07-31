# Optimized retained-pipeline assembly comparison

This is the production-shape follow-up to the initial 46-file assembly test.
No pipeline was deleted. The four retained renderers consume one shared,
indexed `RenderGeometry` projection from the same Open CASCADE import.

## Workload

- 46 operator STEP files from `CAD DEMO/ARCADA001-2`
- 46 rigid assembly nodes
- 8,931 B-Rep faces and 24,778 topology edges
- 247,030 triangles
- 230,466 compact render vertices
- 63 material/rigid-part batches
- 101,046 B-Rep line segments
- scripted 3-second warm-up plus 5-second orbit measurement

## Results

| Pipeline | Assigned role | Ready | FPS | CPU | App memory |
|---|---|---:|---:|---:|---:|
| P2 Open CASCADE → MetalKit | Production candidate | 7.32 s | 59.92 | 19.71% | 231.21 MB |
| P1 Open CASCADE → RealityKit | Secondary Apple renderer | 7.48 s | 59.83* | 21.29% | 378.83 MB |
| P7 Open CASCADE → Three.js/WebGL 2 | Optional environment renderer | 7.30 s | 52.68 | 11.18%† | 227.81 MB† |
| P5 Open CASCADE → raw WebGL 2 | Diagnostic baseline | 7.24 s | 52.71 | 12.07%† | 254.43 MB† |

\* RealityKit does not expose a presented-frame callback; this number counts
display-link opportunities and must not be read as GPU-present timing.

† WebKit content and GPU helper processes are system-managed and excluded from
the app-process CPU/memory figures. They are not evidence that the browser
paths are cheaper than native Metal.

`reportedLoadMilliseconds` in P1/P2 is Open CASCADE read + XDE transfer +
triangulation. In P5/P7 it is only the post-import browser buffer upload. Use
`readyWaitMilliseconds` for end-to-end readiness within this run.

## Decision

P2 is the production viewport architecture. It has the lowest complete native
memory footprint, exact B-Rep edges, face/part IDs for an ID-picking pass, and
a stable rigid-part transform buffer suitable for animation without geometry
rebuilds. P1 is kept for high-level Apple preview integration, but uses one
combined assembly mesh and omits the unreliable public RealityKit line bridge
for very large edge sets. P7 remains useful when rich web/media environments
justify WebKit; P5 remains the dependency-free WebGL control.

The older negative RealityKit result is still useful history: it measured the
per-face entity design, not RealityKit's optimized retained-mesh design. Raw
machine-readable results are in `raw/`.
