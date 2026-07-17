# dev/labs — standalone test apps

Isolated dev apps for proving rendering/geometry combinations before anything
touches the main app. Each is its own process: one crashing never takes the
others down. Born 2026-07-17 while diagnosing the STL import failures.

## Quick start

```bash
brew install opencascade   # once
./build.sh                 # builds everything
./OcctSwift/.build/debug/TestLab   # the launcher
```

## The apps

| App | What it proves |
|---|---|
| **TestLab** | Launcher — buttons for every bench, captures the kernel report's output |
| **GeomBench** | OCCT → C shim → Swift → RealityKit (Metal). Multi-file workspace (STL/STEP/OBJ), per-face/per-edge click-selection on B-rep, FPS/CPU/MEM telemetry, Apple Metal GPU HUD |
| **OcctSwiftViewer** | Minimal kernel→Metal proof: OCCT demo part + one STL |
| **StlViewer** | The production loader (ModelIO → RealityKit) in isolation |
| **kernel_test/occt_test** | Headless OCCT precision report: boolean exactness (1e-16), fillets, STEP round-trip, tessellation quality dial |
| kernel_test/occt_viewer.mm | Parked: OCCT's built-in GL viewer in Cocoa (deprecated-GL path; 2 compile errors, only worth finishing if we ever evaluate MetalANGLE) |

## Findings so far (2026-07-17, Jonathan's ARCADA001 car in `CAD DEMO/`)

- The same part as STL = 234,414 frozen triangles (11.7 MB, crashed the app);
  as **STEP = 228 faces / 605 edges / 3,564 triangles** at 0.05 mm deflection —
  66× lighter, better shading (exact surface normals), fully selectable.
- OCCT kernel math is exact to ~1e-16; STEP round-trip preserves volume; all
  operations single-digit ms on Apple Silicon.
- STEP also carries **appearance**: via XCAF (`STEPCAFControl_Reader` +
  `XCAFDoc_ColorTool`) the shim extracts the CAD-authored color per face, with
  body-level fallback (Onshape exports one STYLED_ITEM per solid). Verified on
  the demo files: ARCADP001 = blue, LCD = dark gray, motor = black.
- STL also *destroys mating information*: a tessellated cylinder is flat quads
  with no axis; the B-rep face knows it IS a cylinder with an exact axis and
  radius — which is what mate connectors need. Surface-type extraction from
  STEP faces is the natural next lab experiment.
- Conclusion so far: **STEP import via OCCT (shim) feeding the existing
  RealityKit viewport** is the long-term architecture. No Qt, no MetalANGLE,
  no framework switch. STL/OBJ remain as fallback imports.

The C shim (`OcctSwift/Sources/OcctShim`) is deliberately app-shaped: when the
combination is approved, it becomes a package the app links and STEP joins the
import contract.
