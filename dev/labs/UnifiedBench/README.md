# Unified Bench

The unified CAD-pipeline benchmark — harvests the best of the three demo apps
(Codex / Claude / Gemini) into one workspace so every pipeline can be compared
side by side, then culled.

Launch: `dev/labs/apps/UnifiedBench.app` (rebuild via `dev/labs/build.sh`).

## What was harvested from whom

| From | What | Where |
|---|---|---|
| **Codex** | camera model with **roll/tilt** (their `CADCameraState`) + modular structure | `BenchModel` camera (`cameraRoll`, `cameraUp`, `roll()`); shift+drag rolls |
| **Claude** | **theme system** (10 themes, cross-engine) + **face/edge selection** depth | `CADTheme.swift`, `featureMaterial`, selection components |
| **Gemini** | **SceneKit engine** + clean per-face color packing | `SceneKitBackend.swift` |

Honest correction to the earlier review: all three used a C-ABI OCCT shim (not
Swift/C++ interop), so there was no "drop the C shim" win — the proven shim
(`OcctShim`, per-face + per-edge + XCAF colors) is kept. Gemini's real
contribution was the SceneKit renderer, not the bridge.

## Pipelines (8 — the most of any bench)

In-app viewport backends (radio buttons):
1. Open CASCADE → **RealityKit** (face/edge select, CAD colors, themes) — the one that ships (option A)
2. Open CASCADE → **Metal** (custom MTKView, raw buffers)
3. Open CASCADE → **SceneKit** (Apple scene graph, PBR + vertex colors) — Gemini's
4. Open CASCADE **built-in GL viewer** (NSViewRepresentable)
5. Open CASCADE → **WebGL** (Three.js in WKWebView)
6. **OpenGeometry** (Rust/WASM — no STEP import; shows its own primitives)
7. **Qt + Open CASCADE** (separate window — Qt owns its event loop)
8. **Unity** (shim → OBJ+colors → Unity editor; separate window)

Blocked: Qt + GLES + MetalANGLE (needs MetalANGLE + OCCT rebuilt with GLES).

## Controls

drag orbit · **shift+drag roll** · middle-drag pan · scroll zoom · shift+scroll
pan · click face/edge to select · Theme dropdown · Fit View.

## Purpose

Compare all pipelines on the same file with the same camera/theme, then
eliminate the ones that don't earn their place. The expected survivor for the
Apple/AR product is #1 (RealityKit); #3 (SceneKit) and #2 (Metal) are the
native alternates; the web/Qt/Unity ones are the cross-platform data points.
