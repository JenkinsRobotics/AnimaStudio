# Codex Bench pipeline study — 2026-07-19

## Decision

Use **Open CASCADE Technology for STEP/XDE import and topology**, then render the
interactive Anima Studio viewport with a **custom Apple MetalKit renderer**.
Keep RealityKit available for higher-level stage/media experiments, but do not
make a face-per-entity RealityKit scene the primary CAD viewport.

The custom Metal pipeline was the only implementation that held the 60 FPS
target on every heavy-model trial while remaining near 20% CPU. The Qt-hosted
paths add measurable process, copy, and synchronization cost. Qt is not needed
as a middle layer in the production macOS app.

## Method

- Hardware/OS: Apple Silicon Mac13,1, macOS 26.5.1.
- Import kernel: Open CASCADE Technology 7.9.3, STEPCAF/XDE, 0.2 mm linear
  deflection and 0.35 rad angular deflection.
- Medium file: `ARCADA001 - ARCADP001.step` — 218 faces, 578 edges,
  13,102 triangles.
- Heavy file: `ARCADA001 - Part 1 (12).step` — 2,631 faces, 7,443 edges,
  54,830 triangles.
- Workload: three-second warmup followed by a five-second, 60 Hz scripted orbit.
  Renderer work that delayed the main loop lengthened the measured interval
  rather than being hidden.
- Heavy results are medians of three separate signed-app launches. FPS ranges
  show run-to-run variation.
- The Open CASCADE import guard was also exercised across all 46 STEP files in
  `CAD DEMO/ARCADA001-2`: 46/46 loaded, totaling 8,931 faces, 24,778 edges, and
  247,030 triangles.

## Heavy-model results

| ID | Pipeline | Effective FPS | Combined CPU | Memory | Ready to view | Assessment |
|---:|---|---:|---:|---:|---:|---|
| P1 | Open CASCADE → RealityKit | 40.7 (31.0–46.3) | 71.6% | 447.7 MB | 6.95 s | Strong native scene/media integration, but the current face-granular entity design scales poorly. |
| P2 | Open CASCADE → MetalKit | **60.0 (60.0–60.0)** | **19.7%** | 272.1 MB | **2.33 s** | **Best production viewport candidate.** Fast, stable, native, and gives direct control over picking, edges, shading, and video textures. |
| P3 | Native Open CASCADE OpenGL viewer | 38.9 (38.6–39.2) | 40.5% | **134.4 MB** | 2.71 s | Efficient CAD reference/validator, but OpenGL is deprecated on macOS and its viewer is harder to integrate with Anima's stage/media UX. |
| P4 | Qt 6 + Open CASCADE OpenGL, hosted | 42.5 (41.8–44.1) | 128.9% | 211.5 MB | 2.98 s | Works, but Qt/helper/IOSurface hosting costs about 3.2× P3's CPU for only ~3.6 FPS more. Not justified for the native app. |
| P5 | Open CASCADE → Swift WKWebView WebGL 2 | 60+ (vsync saturated) | 12.1%* | 288.3 MB* | 2.89 s | Visually fast and useful as a web experiment. The starred process figures exclude WebKit content/GPU processes, so they are not comparable to native totals. |
| P6 | Open CASCADE → Qt WebEngine WebGL 2, hosted | 33.5 (32.4–36.5) | 91.0% | 233.0 MB | 3.16 s | **Worst architecture.** Qt + Chromium + frame grab + CPU copy + IOSurface adds layers while producing the lowest general-renderer FPS. |
| P7 | Open CASCADE → OpenGeometry WASM probe + Three.js | 60+ (vsync saturated) | 10.9%* | 261.7 MB* | 2.89 s | Not an independent STEP pipeline: Open CASCADE still imports the file and OpenGeometry only runs a probe. It duplicates P5 without replacing the kernel. |
| P8 | Open CASCADE → selectable RealityKit features | **30.0 (30.0–30.1)** | **151.4%** | **867.6 MB** | **9.48 s** | **Worst current implementation by resources.** Per-face selectable/collision entities prove the feature UX, but must be replaced by Metal ID-buffer/topology picking. |
| P9 | Open CASCADE → SceneKit | 60.0 (60.0–60.1) | 112.1% | 244.0 MB | 2.54 s | Reaches target FPS but at high CPU. SceneKit is a legacy direction, so it is a useful comparison—not the long-term renderer. |

`*` P5/P7 memory and CPU cover the Swift host only. macOS manages WKWebView's
WebContent and GPU helper processes separately; the benchmark deliberately does
not pretend those un-attributed resources are free.

The load number shown in each raw result must be read with its `loadMetricScope`.
For P5 and P7 the tiny 4–14 ms number is only WebGL upload after the shared
~2.1-second Open CASCADE import. `Ready to view` is the fairer end-to-end value.

## Medium-model check

The medium model confirmed the same direction: P2 held 60 FPS at 21.1% CPU and
102 MB; P3 delivered 38.8 FPS; P4 delivered 41.2 FPS at 120.7% CPU; P6 delivered
34.7 FPS at 97.0% CPU. P8 was acceptable on the small file at 59.8 FPS, which
shows why small demos hid its scaling problem.

## What to keep

1. **P2 as the production renderer:** batch triangles by material, retain the
   Open CASCADE face/edge IDs, render edges in dedicated Metal passes, and add
   an off-screen ID buffer for face/edge/body hover and selection.
2. **Open CASCADE as the one CAD importer/topology source:** STEP/XDE colors,
   assemblies, exact faces, and edge polylines remain upstream of rendering.
3. **Native media beside/inside Metal:** AVFoundation/Core Image/Metal textures
   cover audio, video, GIF/image sequences, LED matrices, and virtual screens
   without requiring Unity or Qt.
4. **P1 as a selective integration tool:** RealityKit remains valuable for
   quick stage prototypes and Apple ecosystem features, provided geometry is
   batched rather than represented as thousands of independent entities.
5. **P3 as a diagnostic reference:** useful for comparing tessellation and CAD
   appearance while developing P2, not as the shipping macOS viewport.

## What to retire from the product path

- P4 and P6: hosted Qt renderers.
- P7: the current OpenGeometry label/probe path; it adds no independent import
  capability over P5.
- P9: SceneKit as a production candidate.
- P8's per-face RealityKit collision/entity architecture. Preserve its UX,
  implement it with Metal picking.

The raw JSON for every run is retained under [`raw/`](raw/) so later renderer
changes can be compared against this baseline rather than relying on screenshots
or subjective feel.

Raw-data note: the first P6 run in `raw/{medium,heavy}` records the startup race
that this packet discovered. `raw/fixed/` contains the corrected P6 results.
P3's canonical first-trial result is in `raw/final-release/`, after its deferred
native-view load timing was made observable. The heavy medians use those
corrected first trials plus `heavy-trial-2` and `heavy-trial-3`; the superseded
files remain available as an audit trail.
