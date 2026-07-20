# Codex Bench

Codex Bench is a standalone macOS CAD-pipeline benchmark. Its source remains
under the internal `GeomBench` module name so the visible rename does not churn
the benchmark contracts. It is deliberately
isolated from Anima Studio: no app target or engine contract is reused. Its job
is to compare importer and renderer boundaries before one is selected for the
product.

## Pipeline matrix

| # | Pipeline | Assigned role | STEP topology/XDE |
|---|---|---|---|
| 1 | Codex · Open CASCADE Technology C ABI → Swift → Apple RealityKit | Secondary Apple renderer | Yes |
| 2 | Codex · Open CASCADE Technology C ABI → Swift → Apple MetalKit | Production candidate | Yes |
| 7 | Codex · Open CASCADE Technology → Three.js → WebGPU | Optional environment renderer | Yes |
| 10 | Codex · Open CASCADE Technology → Swift → Raw WebGPU | Browser renderer candidate | Yes |

P10 consumes the operator-selected STEP/STP tessellation from Open CASCADE and
renders it directly with `navigator.gpu`, explicit GPU buffers, multisampled
render/depth targets, and WGSL shaders inside Swift WebKit. P7 uses the same
document through Three.js `WebGPURenderer`, which
provides a higher-level scene, material, lighting, media-texture, animation, and
picking layer. Three.js automatically falls back to WebGL 2 when WebGPU is not
available, and Codex Bench reports the backend it actually selected rather than
assuming WebGPU from the pipeline name. The obsolete OpenGeometry bounds probe
is gone. The two active browser routes now compare raw WebGPU control against a
modern Three.js WebGPU environment without changing the STEP importer or source
geometry. The measured raw WebGL 2 experiment is retired from the active app;
P7 may still use Three.js's compatibility fallback when native WebGPU is
unavailable. Mesh-only Model I/O, desktop OpenGL,
per-feature RealityKit entities, SceneKit, Qt, MetalANGLE, and Unity are absent
rather than being presented as retained product directions.

Codex Bench opens with an empty workspace and never inserts sample geometry.
Use **Open** or **Import** to select your own STEP/STP files for all four active
catalog routes. The active Apple catalog intentionally keeps the historical
pipeline numbers, so retired P3, P4, P6, P8, and P9 remain absent rather than
renumbering saved reports or preferences. Small generated geometry remains
inside unit tests only and is never loaded by the app.

## Build and run

The only native dependency is Homebrew `opencascade` at its standard Apple
Silicon prefix. Qt is not required for the Apple application.

```bash
cd "dev/Codex Bench"
swift test
./scripts/build.sh
./scripts/make-app.sh       # packages the Apple application/resources
./scripts/launch.sh         # launches the packaged app
```

For a repeatable importer-only measurement without opening a GUI:

```bash
swift run geom-probe /path/to/assembly.step
# Multiple files are imported and merged into one renderer document:
swift run geom-probe /path/to/parts/*.step
```

The probe prints assembly-node, face, edge, and triangle counts plus the read,
XDE transfer, triangulation, and maximum-tolerance measurements.

For a normalized renderer measurement, launch the packaged app with a pipeline,
an operator file, and an output path. The app waits for that renderer to become
ready, drives the same 60 Hz orbit, writes structured JSON, and exits:

```bash
open -n "Codex Bench.app" --args \
  --pipeline 2 \
  --file /path/to/assembly.step \
  --benchmark-output /tmp/pipeline-2.json \
  --benchmark-warmup 3 \
  --benchmark-duration 5
```

The first nine-pipeline study and its raw measurements are in
[`Reports/2026-07-19-pipeline-study/`](Reports/2026-07-19-pipeline-study/).
Its current recommendation is Open CASCADE for STEP/XDE/topology feeding a
custom MetalKit production viewport.
The pruned four-pipeline comparison, including the direct Three.js replacement,
is in [`Reports/2026-07-19-kept-pipelines/`](Reports/2026-07-19-kept-pipelines/).
The 46-file, 247,030-triangle combined-assembly study is in
[`Reports/2026-07-19-assembly-benchmark/`](Reports/2026-07-19-assembly-benchmark/).
That historical run exposed the former per-face RealityKit graph as unusable.
The production-shape optimization and comparable rerun are in
[`Reports/2026-07-19-optimized-pipelines/`](Reports/2026-07-19-optimized-pipelines/).
P1 now completes via one retained `LowLevelMesh`; P2 keeps independent rigid
part transforms in one GPU transform table and remains the production choice.
The subsequent WebGPU-first P7 experiment and its raw, same-build P5 comparison
are in
[`Reports/2026-07-19-webgpu-pipeline/`](Reports/2026-07-19-webgpu-pipeline/).
The direct P10 WebGPU implementation and final P5/P7/P10 comparison are in
[`Reports/2026-07-19-raw-webgpu/`](Reports/2026-07-19-raw-webgpu/).

Run the same assembly workload locally with:

```bash
./scripts/run-assembly-benchmark.sh /path/to/step-corpus
```

The clickable app bundle is generated at `dev/Codex Bench/Codex Bench.app`. Add several
files to the sidebar and switch pipelines without changing the source data.

## Shared render themes

The toolbar theme menu keeps visual comparisons readable without replacing
imported STEP/XDE face colors unless the selected preset intentionally supplies
a diagnostic override. **Studio Blue** is the default, adapted from the
strongest part of Claude Bench's presentation work. The ten presets also cover
Showroom, Technical Matte, Warm Workshop, SolidWorks, Onshape, Fusion 360,
Blueprint, Clay, and Midnight Glow. A theme is a complete render preset:
background, material color policy, roughness/metallic finish, B-Rep edge
visibility/color, hover/selection colors, and key/fill/rim lighting. Every
working renderer maps the preset onto its native material, light, edge, and
highlight APIs. The chosen theme persists between launches.

## Fair comparison contract

- Every selectable pipeline receives the same operator-selected STEP/STP file.
- STEP/XDE parsing and tessellation happen once through the shared Open CASCADE
  Technology shim; an in-memory file/mtime/size cache lets renderer switching
  reuse that exact document instead of reparsing or substituting a fixture.
- Every renderer consumes one compact `RenderGeometry` projection with indexed
  triangles, material/rigid-part batches, topology IDs, exact edge segments,
  and cached bounds. Renderers no longer flatten the same CAD document four
  different ways.
- P1 and P2 compare Apple's higher-level RealityKit scene integration against
  direct Metal control.
- P10 and P7 compare dependency-free raw WebGPU against Three.js WebGPU on the
  same Open CASCADE geometry and WebKit host. P7 records an honest WebGL 2
  fallback if WebGPU is unavailable; P10 intentionally has no fallback.

Renderer implementations and their ownership map are documented in
`Sources/GeomBenchApp/Renderers/README.md`.

## Production-shape implementation notes

- **P2 MetalKit:** packed static vertex/index/edge buffers live in GPU-private
  storage; vertex records retain face and part IDs; one stable part-transform
  table supports animation without rebuilding geometry; uniforms are triple
  buffered. This is the architecture to carry into Anima Studio.
- **P1 RealityKit:** one retained assembly `LowLevelMesh` avoids the former
  8,931-entity explosion. RealityKit remains useful for a simpler preview, but
  its public path omits the large-assembly edge overlay and does not retain P2's
  independent part-transform table.
- **P10/P7 WebKit:** a compact binary payload is base64-transported once and
  decoded directly into typed arrays. P10 creates explicit GPU buffers and
  WGSL surface/edge pipelines; P7 uses one indexed Three.js geometry with
  material groups through `WebGPURenderer`. The backend name is sent back to
  Swift after initialization. These remain browser candidates because benchmark
  memory excludes WebKit's content and GPU helper processes.

## Archived Qt prototypes

The measured P4 and P6 Qt experiments were removed from the Apple catalog,
runtime, Settings window, automated benchmark, and signed bundle after the
first nine-pipeline study. Their source remains under `qt/`, and
`scripts/build-qt.sh` can still build those historical macOS prototypes into
`build/qt` for reference. They are not shipped by `make-app.sh`.

That prototype host uses AppKit and IOSurface, so it is not itself the future
cross-platform Qt application. A non-Apple Qt product can reuse the useful
Open CASCADE and Qt renderer work later behind a separate application target
and platform-appropriate process/window integration.

## CAD controls

- Right drag: orbit
- Middle drag: pan
- Shift + left drag: pan
- Shift + right drag: roll around the viewing axis
- Scroll: zoom
- Fit toolbar button: frame geometry

The Open CASCADE Technology native viewers use its built-in face hover and selection.

## Precision contract

GeomBench does not claim impossible `1e-16` STEP fidelity. OCCT uses double
precision, while each STEP model carries its own authoring and B-Rep
tolerances. The shim reports the maximum imported face/edge tolerance in
metres. A future round-trip test should report measured deviation against that
source tolerance instead of advertising a fixed universal tolerance.
