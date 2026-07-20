# Three.js WebGPU-first experiment

Codex Bench Pipeline 7 now uses the bundled Three.js `WebGPURenderer` rather
than `WebGLRenderer`. The renderer initializes asynchronously, reports the
backend Three.js actually selected, and remains usable through Three.js's
automatic WebGL 2 fallback on systems where WebGPU is unavailable.

## Result on the full CAD DEMO assembly

The signed macOS app selected **native WebGPU** in `WKWebView` and loaded all
46 STEP files as one 247,030-triangle, 46-rigid-part document.

| Pipeline | Actual backend | FPS | App CPU | App memory | Buffer upload |
|---|---|---:|---:|---:|---:|
| P5 raw browser baseline | WebGL 2 | 78.02 | 11.77% | 286.61 MB | 42 ms |
| P7 Three.js environment | WebGPU | 65.54 | 9.53% | 386.46 MB | 45 ms |

These are a same-build scripted-orbit comparison. WebKit content and GPU helper
processes are system-managed and excluded from the app-process CPU/memory
figures, so those columns are useful for regression tracking but are not full
renderer totals. FPS can exceed 60 on the ProMotion display.

## Decision

- Keep **P2 MetalKit** as the native production CAD viewport candidate.
- Keep **P7 Three.js/WebGPU** as the optional rich environment path for stage,
  media, and avatar experiments.
- Keep **P5 raw WebGL 2** as a low-level diagnostic control; WebGPU did not make
  it redundant, and this run did not show a universal performance win.

WebGPU is a modern GPU API and a strong web-CAD direction, but the measurement
does not justify calling one library a universal industry standard. The useful
architecture is Open CASCADE for STEP/B-Rep truth feeding a capability-gated
renderer, with the selected backend visible in telemetry.

Raw outputs are under `raw/` (first WebGPU confirmation), `comparison/`
(same-build P5/P7 comparison), and `final/` (post-package signed-app check).
