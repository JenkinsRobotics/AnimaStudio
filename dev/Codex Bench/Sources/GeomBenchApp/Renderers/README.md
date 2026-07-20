# Codex Bench renderer catalog

Every renderer in the app consumes the same `GeometryDocument`, `BenchTheme`,
and `CADCameraState`. A contributor name records where the useful architectural
variant originated; it does not create a separate importer or benchmark.

## Assigned roles

- `../MetalBenchView.swift` — **production candidate**: packed GPU-private
  buffers, topology IDs, exact edges, triple-buffered uniforms, and a stable
  per-part transform table.
- `../RealityKitBenchView.swift` — **secondary Apple renderer**: one retained
  assembly `LowLevelMesh` and native PBR/light integration.
- `../ThreeJSBenchView.swift` — **optional environment renderer**: Three.js
  `WebGPURenderer` in Apple WebKit, fed by the same Open CASCADE STEP
  tessellation. It reports native WebGPU or the automatic WebGL 2 fallback.
- `../RawWebGPUBenchView.swift` — **browser renderer candidate**: direct
  `navigator.gpu`, explicit buffers, multisampled render/depth targets, and
  WGSL surface/edge shaders with no scene framework or WebGL fallback.

`GeomBenchCore.RenderGeometry` is the only renderer-ready projection. The
source `GeometryDocument` keeps complete B-Rep face/edge records; the compact
projection adds contiguous indexed geometry, material/part batches, face/part
IDs, edge segments, and bounds without changing source semantics.

Desktop OpenGL, per-feature RealityKit entities, SceneKit, Unity, and
MetalANGLE are not catalog entries. Generated test geometry is unit-test-only;
the app never substitutes it for an operator-selected file.

The retired Qt host/client prototype remains under `qt/` and in the excluded
`HostedRenderer*.swift` files as reference for a future separate Qt product.
It is not part of the Apple app's renderer catalog or signed bundle.

The OpenGeometry bounds-probe experiment was removed because it could not
import the operator's STEP model. The measured raw WebGL 2 route was retired
after direct WebGPU matched its full-assembly throughput. P10/P7 now compare a
small direct WebGPU implementation against a higher-level Three.js WebGPU
scene environment.
