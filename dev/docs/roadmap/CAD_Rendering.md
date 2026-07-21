# CAD import and rendering

## Decision

STEP/STP is Anima Studio's preferred CAD source format. Open CASCADE Technology
is the one geometry kernel. It reads the file once and projects an XDE document
into the renderer-neutral `CADGeometryDocument` contract. Renderers consume
that projection; they do not parse STEP and they do not define rig, mate,
animation, or hardware semantics.

```text
STEP / STP
    │
    ▼
AnimaCADShim (Open CASCADE 7.9 + XDE, guarded C ABI)
    │ hierarchy · colours · faces · feature edges · tolerance · timings
    ▼
AnimaCAD.CADGeometryDocument (metres)
    ├── MetalKit                 preferred high-volume STEP visualization
    ├── RealityKit               Studio editing, selection, media, spatial UI
    ├── Three.js WebGPU/WebGL 2  optional virtual-stage experiment
    └── Raw WebGPU               direct WGSL diagnostic path
```

All four backends share vertex/index/color/topology/edge buffers and coordinated
theme inputs. Switching a renderer is a presentation preference and must never
alter `.character.anima`, `model`, `model_node`, mate meaning, or evaluated
poses.

## Target ownership

- `AnimaCADShim`: the only C++/OCCT boundary. It catches `Standard_Failure`,
  installs OCCT signal conversion, reads STEPCAF/XDE names and colors,
  tessellates B-Rep faces, samples exact B-Rep edges, and returns flat owned C
  buffers. Native exceptions and malformed input must not cross the ABI.
- `AnimaCAD`: renderer-neutral Swift value types, metrics, merge/projection,
  and the fixed renderer catalog. No SwiftUI, RealityKit, MetalKit, or WebKit.
- `AnimaCADViewport`: MetalKit, RealityKit, Three.js WebGPU, and raw WebGPU
  consumers plus shared camera/theme/telemetry presentation.
- `RealityKitViewport`: production Studio interaction and imported-model
  mapping. Its STEP branch calls `AnimaCAD`; it does not own a second parser.
- `AnimaStudioUI`: picker/drop workflow and persisted user preferences.
- `AnimaCore`: stores safe relative asset references and supplies evaluated
  character-space transforms. It never imports or tessellates mesh/CAD files.

## Import contract

Supported operator input is deliberately closed to:

- STEP/STP: Open CASCADE/XDE, dimensions converted to metres; hierarchy, names,
  colors, faces, feature edges, and tolerance retained.
- USD/USDA/USDC/USDZ: RealityKit-native hierarchy and units.
- STL/OBJ: ModelIO mesh import after explicit mm/cm/m interpretation.

STEP does not show the unitless STL/OBJ prompt. Imports are asynchronous, copied
to the active Character's `assets/` folder, and saved as a relative `model`
reference. An assembly node is saved as `model_node`; multiple Parts may point
to one STEP asset with distinct node paths.

## Renderer roles

1. **Open CASCADE → MetalKit** is the preferred high-volume STEP visualization
   path. It uses retained GPU-private geometry, triple-buffered uniforms, a
   part-transform table, and a separate exact-edge pass.
2. **Open CASCADE → RealityKit** is the app default and editing-native path. Selection,
   manipulators, audio/video/screens, spatial content, and existing Studio
   viewport tools remain here.
3. **Open CASCADE → Three.js WebGPU** is optional for richer virtual-stage
   experiments. It reports whether WebKit selected WebGPU or its WebGL 2
   fallback; the fallback is never mislabeled WebGPU.
4. **Open CASCADE → raw WebGPU** is an explicit WGSL comparison without a scene
   framework. Unsupported `navigator.gpu` is a visible error, not a silent API
   change.

RealityKit is therefore the production authoring default today. The MetalKit
and browser paths are selectable STEP inspection/visualization surfaces, but
they do not yet receive AnimaCore's changing per-Part pose table, semantic
selection IDs, mate handles, or media surfaces. Their geometry contracts retain
part IDs so those integrations can be added without re-importing STEP; until
then the Settings UI labels the distinction instead of implying feature parity.

No removed Codex Bench pipeline is part of production: Qt hosts, OCCT OpenGL,
MetalANGLE, SceneKit, OpenGeometry, Unity placeholders, ModelIO-only CAD, and
raw WebGL 2 stay retired.

## Preferences and diagnostics

Settings → CAD Renderer persists backend, coordinated theme, imported-color
policy, exact-edge visibility and strength, roughness, metallic response,
key/fill/rim intensity, and performance-HUD visibility. A coordinated theme
changes background, lighting, surface response, edge treatment, and selection;
it is not a background-only skin.

Telemetry is diagnostic rather than semantic: backend/role, OCCT load stages,
FPS, face/edge/triangle counts, and kernel version. Browser CPU/memory must not
be compared to native totals unless WebKit content/GPU processes are included.

## Packaging

Browser resources live in `app/App/Resources/CADWeb`; production never reaches
back into `dev/Codex Bench`. The root-app script embeds the linked OCCT and
Homebrew dependency closure in `Contents/Frameworks`, rewrites absolute paths
to `@rpath`, and signs nested binaries before sealing the app.

The current development bottle was built for macOS 26 even though Studio's
source deployment target is older. Before distribution, build a pinned OCCT
artifact with the product deployment target (and both required architectures),
then notarize that vendored dependency. Do not ship a release that silently
depends on `/opt/homebrew`.

## Acceptance

- A valid operator STEP opens through picker and drop flows without conversion.
- A malformed STEP returns an inline error and never terminates the app.
- XDE hierarchy and colors appear in RealityKit's mapping stage.
- All four retained renderers consume one imported document.
- Renderer/theme changes persist and never touch canonical rig data.
- Root `Anima Studio.app` launches with its own OCCT/Web resources and does not
  require Codex Bench at runtime.
