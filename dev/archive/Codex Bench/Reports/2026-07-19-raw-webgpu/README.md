# Raw WebGPU comparison

Pipeline 10 renders the shared Open CASCADE STEP projection directly through
`navigator.gpu`. It has no Three.js dependency and no WebGL fallback. The
implementation uses explicit vertex/index/uniform buffers, WGSL surface and
edge shaders, a cached camera matrix, four-sample color/depth attachments, and
the same themes and CAD controls as every retained renderer.

## Same-build full-assembly result

All three browser pipelines loaded the same 46-file, 247,030-triangle,
46-rigid-part CAD DEMO assembly in the signed application.

| Pipeline | Backend | FPS | App CPU | App memory | Buffer upload |
|---|---|---:|---:|---:|---:|
| P5 direct baseline | WebGL 2 | 60.80 | 9.43% | 376.23 MB | 41 ms |
| P7 environment | Three.js WebGPU | 61.24 | 8.18% | 422.78 MB | 47 ms |
| P10 direct candidate | Raw WebGPU | 60.78 | 10.23% | 223.70 MB | 42 ms |

WebKit content and GPU helper processes are system-managed and excluded from
the app-process CPU/memory measurements. Repeated isolated P10 launches ranged
from 51.63 to 60.78 reported FPS while upload remained stable at 41–43 ms;
earlier P5/P7 runs showed similar callback-scheduling variance. Treat the table
as a compatibility/throughput snapshot, not a statistically decisive FPS
ranking. Memory is useful as a Swift-host regression signal, not a complete GPU
allocation total.

## Decision

- **P10 raw WebGPU replaces P5 raw WebGL 2 in the active picker.** It completed
  the same workload with stable upload time and the expected interactive frame
  range while using the modern API that maps to Apple's Metal stack. This is an
  API/product-direction choice, not a claim that one noisy run proved WebGPU
  faster.
- **P7 Three.js WebGPU remains the optional rich-environment route** for stage,
  media, avatar, and extension experiments.
- **P2 native MetalKit remains the production CAD viewport candidate.** Raw
  WebGPU validates a credible portable renderer; it does not displace the
  lower-overhead native integration without broader selection/media testing.
- P7 retains Three.js's automatic WebGL 2 fallback for systems without WebGPU.
  P10 intentionally fails clearly instead of silently changing APIs.

`first-run/` records the initial direct implementation. `comparison/` contains
the same-build P5/P7/P10 measurement used for the decision; `final/` and
`clean-final/` retain the post-removal signed-app checks and observed scheduling
variance.
