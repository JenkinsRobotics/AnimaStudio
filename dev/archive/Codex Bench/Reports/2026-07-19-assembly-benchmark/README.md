# Codex Bench combined-assembly study — 2026-07-19

## Decision

Use **Open CASCADE Technology for STEP/XDE/topology** and a **custom Apple
MetalKit viewport** for Anima Studio's primary assembly, rigging, animation,
and show-authoring view.

Do not use the current RealityKit face-per-entity implementation for the main
viewport. RealityKit remains useful selectively for Apple spatial/AR features
and small stage prototypes, but the renderer projection must be batched before
it is reconsidered for large assemblies.

## Workload

- 46 independently exported STEP files from `CAD DEMO/ARCADA001-2`, loaded
  serially through the same Open CASCADE 7.9.3 XDE importer and merged into one
  renderer document.
- 18,126,179 source bytes; 46 assembly roots; 8,931 B-Rep faces; 24,778 feature
  edges; 247,030 triangles.
- The merge remaps face, edge, and assembly-node identifiers while retaining
  every file's authored coordinates and XDE colors.
- Headless import/merge: 632.7 ms read + 5,110.2 ms XDE transfer + 1,091.6 ms
  triangulation = **6.83 seconds**.
- Renderer measurement: three-second warmup, then a five-second 60 Hz scripted
  orbit. macOS only drives display-backed render callbacks for visible windows;
  occluded/background launches that reported zero delivered frames are retained
  in `raw/` but excluded from FPS conclusions.

## Results

| Pipeline | Ready to view | Effective FPS | CPU | Memory | Result |
|---|---:|---:|---:|---:|---|
| P1 · Open CASCADE → RealityKit | **Not ready after 4m55s** | Not measurable | — | ~676–719 MiB observed | Failed the assembly workload. Creating 8,931 independent MeshResource/ModelEntity pairs is the bottleneck. |
| P2 · Open CASCADE → MetalKit | **6.94 s** | **59.84** in the visible draw-count run | **20.34%** | **401.9 MiB** in the visible run | Best production direction. One batched triangle buffer plus one batched edge buffer stayed interactive. |
| P5 · Open CASCADE → raw WebGL 2 | 8.31 s | Automation unavailable | 10.94% host-only | 261.5 MiB host-only | Accepted all geometry; 10 ms WebGL upload. WebKit child CPU/memory and background-throttled FPS prevent a fair native comparison. |
| P7 · Open CASCADE → Three.js/WebGL 2 | 8.50 s | Automation unavailable | 11.02% host-only | 273.0 MiB host-only | Accepted all geometry; 20 ms Three.js upload. Useful optional web environment, not the primary CAD viewport. |

P2's import/ready and main-process CPU were stable across five launches:
6.75–7.05 seconds ready and 19.84–22.51% CPU. Only one launch remained
display-visible for the full timed draw count; it delivered 360 frames over
6.016 seconds (59.84 FPS). The other zero-frame launches demonstrate macOS
window occlusion, not a GPU failure, and are not averaged into the FPS value.

The browser CPU and memory numbers cover only the Swift host. WebKit's
WebContent and GPU processes are system-managed children and are not included,
so P5/P7 cannot be claimed more efficient than P2 from those figures.

## Architecture consequence for Anima Studio

1. Open CASCADE stays upstream for STEP, assembly hierarchy, exact topology,
   XDE colors, and tessellation.
2. MetalKit owns the main viewport: batched faces/materials, a dedicated edge
   pass, and an off-screen ID buffer for body/face/edge hover and selection.
3. AVFoundation/Core Image feed video, GIF/image sequences, LED matrices, and
   virtual-screen textures into Metal; audio remains AVFoundation, not a
   renderer concern.
4. RealityKit is optional integration infrastructure, not the assembly scene
   graph. If retained, batch by material/part rather than face.
5. Three.js remains an optional environment/plugin experiment when a web scene
   is valuable; it does not replace the native CAD viewport.

Structured successful results and display-throttled audit runs are under
[`raw/`](raw/). P1 has no JSON because it never reached the benchmark task's
renderer-ready boundary before the bounded manual stop.
