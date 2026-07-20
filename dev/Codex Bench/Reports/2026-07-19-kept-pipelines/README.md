# Codex Bench — retained pipeline comparison

This is the first normalized run after pruning Codex Bench to the four
architectures still relevant to an Apple-first Anima Studio. Every pipeline
loaded the same operator STEP file and ran the same three-second warmup plus
five-second scripted orbit.

## Test model

- File: `ARCADA001 - Part 1 (12).step`
- Source size: 5.3 MB
- Extracted geometry: 2,631 faces, 7,443 feature edges, 54,830 triangles
- Machine: Apple Silicon Mac, local signed Codex Bench app

## Results

| ID | Pipeline | Ready to view | Renderer upload | Effective FPS | CPU | Memory |
|---:|---|---:|---:|---:|---:|---:|
| P1 | Open CASCADE → RealityKit | 6.90 s | 2,161 ms* | 50.7 | 70.6% | 693.3 MB |
| P2 | Open CASCADE → MetalKit | **2.34 s** | 2,148 ms* | 59.8 | 23.5% | 390.5 MB |
| P5 | Open CASCADE → raw WebGL 2 | 2.73 s | **3 ms** | 61.2 | 15.7%† | 374.1 MB† |
| P7 | Open CASCADE → Three.js → WebGL 2 | 2.78 s | 9 ms | 62.7 | 12.4%† | 382.0 MB† |

`*` P1/P2's reported load is the shared Open CASCADE read, XDE transfer, and
triangulation. P5/P7's upload value is only the browser buffer construction
after that same import; their `Ready to view` number is the fair end-to-end
comparison.

`†` WebKit runs rendering work in system-managed WebContent/GPU processes. The
current telemetry reports the Swift host, so P5/P7 CPU and memory must not be
treated as directly comparable native-process totals.

## Decision

1. **P2 MetalKit remains the production renderer.** It is the fastest complete
   native route, reaches the 60 FPS target, and provides the control needed for
   CAD picking, edges, video textures, LED matrices, and stage effects.
2. **P7 Three.js is worth retaining as an optional environment pipeline.** On
   this model its higher-level scene layer added only about 6 ms beyond raw
   WebGL upload and 56 ms end-to-end. It can accelerate experiments involving
   materials, lights, cameras, animation, picking, and media textures.
3. **P5 raw WebGL remains the browser baseline.** It proves the minimum WebGL
   cost and gives P7 a fair comparison without a second geometry kernel.
4. **P1 RealityKit remains the Apple scene-integration comparison**, but its
   current projection needs batching before it can compete with MetalKit on
   heavier CAD assemblies.

This is one retained-catalog pass, not a statistical replacement for the
earlier three-trial study. Raw JSON is in [`raw/`](raw/), and the run is
reproducible with `scripts/run-kept-pipelines.sh`.
