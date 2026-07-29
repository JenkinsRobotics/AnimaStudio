# STATUS

> Truthful, or it's worthless. Any commit that changes behavior updates
> this file in the same commit — see `CONVENTIONS.md` → "STATUS stays
> truthful."

## Current state — 2026-07-21

- **Repo:** `AnimaStudio` — open-source unified character animation
  system for AI robots (digital avatars + physical animatronics from
  one rig, one format, one authoring tool)
- **Version:** 0.1.0 (see `animacore/__init__.py`)
- **2D character pipeline (engine foundation, not yet wired to the app):**
  `animacore/canvas2d.py` models VTuber-style 2D characters — `VisualSource`
  (image/sprite/gif/video), `Surface` display windows, DOF/parameter-driven
  `SurfaceDriver`s — and `evaluate_surfaces` resolves them to renderer-neutral
  `SurfaceState` (source, frame index, transform, opacity, z-order) using the
  same evaluated-value stream the 3D rig uses. `animacore/frame_output.py` adds
  the frame hardware-node side: `LedMatrixTarget` + `downsample_canvas`
  (the 64x64 area-average/gamma/brightness math) and a `FrameOutput` protocol
  with a `SimulatorFrameOutput`. `animacore/raster/` is the host-side rasterizer:
  it turns evaluated `SurfaceState`s into actual pixels for the hardware frame
  path (and as a reference for the Swift preview renderer). The media decoders
  are **ported from Mochi** (Apache-2.0) — real, not stubs: an RGBA8 `FrameBuffer`
  and Mochi's `open`/`close`/`next_frame(t)` decoder contract, with working
  `ImageAdapter` (Pillow), `BitmapAdapter` (numpy 1-bit), `SpriteAdapter`
  (sheet-cell crop, grid-index or explicit rect), `GifAdapter` (Pillow
  ImageSequence, per-frame durations, loop), `VideoAdapter` (imageio/ffmpeg
  decode-by-index), and a `ProceduralAdapter` + parametric `SimpleFace` (eyes+mouth
  driven by the same `eye_open`/`mouth_open`/`mouth_curve`/`look_*` value stream,
  auto blink/breathing). `CanvasPlayer` opens one adapter per surface and
  alpha-composites them back-to-front (Pillow) into a `FrameBuffer`, feedable to
  `downsample_canvas`. Two more real pipelines ship beside it: `frame_serial.py`
  `SerialFrameOutput` streams frames to a physical RGB matrix over serial
  (`MM`/`BM`/`FM`, verified on a pyserial loopback), and `raster/mscript.py` is
  the ported Mscript timeline language (parser + `update(t)` WAIT/duration flow
  control + GIF/video auto-duration). Media deps are the optional `media` extra
  (pillow/imageio); the core engine never imports `animacore.raster`. 30 raster
  tests decode real generated PNG/GIF/sprite/bitmap/mp4. The `.character.anima`
  `canvas2d:` loader is still pending — design in
  `dev/docs/roadmap/2D_Character_Pipeline.md`.
- **2D character workspace (groundwork — engine + app scaffold):**
  `animacore/raster/preview.py` is a headless preview/export tool: render any
  canvas to a PNG, an animated GIF, an LED-matrix simulator image, or ASCII, plus
  a `python -m animacore.raster.preview` CLI. `animacore/bridge.py` gains a
  `canvas2d.*` verb family (`describe`/`new`/`get`/`evaluate`/`render_frame`/
  `matrix_preview`/`release`) so the app can build, evaluate, and rasterize a 2D
  character over the Studio↔AnimaCore bridge; evaluation is stdlib and only
  `render_frame`/`matrix_preview` need the optional `media` extra (returning
  `media_unavailable` if absent). In the app, a new **2D** workspace
  (`StudioWorkspaceKind.canvas2d`, ⌘8, tab after Animate), routed through every
  workspace switch, with Surfaces/Media/Faces/Output sidebar tabs. Its center is a
  **live preview**: `Canvas2DWorkspaceView` spawns an engine client, builds a
  procedural-face canvas (`canvas2d.new`), renders it (`canvas2d.render_frame` →
  decoded PNG), and drives `mouth_open`/`mouth_curve`/`eye_open`/time from sliders
  — so the app shows exactly what the engine (and hardware) produce. Persistence:
  `animacore/canvas2d_io.py` reads/writes a `canvas2d:` block in a
  `.character.anima` (one shape shared with the bridge DTO), the loader accepts it
  (a pure-2D character loads as an empty-mechanics Rig; hybrid = rig + canvas2d),
  `bridge.py` has `canvas2d.load`/`save`, and `examples/pixel_face_2d.character.anima`
  is a runnable pure-2D character. Still to come: the real surface/media/face
  editors and load-into-preview UI. Design in
  `dev/docs/roadmap/2D_Character_Workspace.md`.
- **2D asset conventions (the create ↔ play interchange, ported from Mochi):**
  AnimaStudio is the *create* method; the playback middleware consumes these.
  `animacore/asset_props.py` — the `.props.yaml` sidecar (`asset-props/v1`:
  name/mood/tags, `ideal_size`, `framing`, `playback_speed`, `loop`, `type_props`
  sprite-grid/fps), read+authored, with `visual_source_from_asset`.
  `animacore/asset_catalog.py` — `build_catalog` indexes a media folder to
  JSON. `animacore/pack.py` — packs (`pack/v1`) mapping emotion/action **slots**
  to asset files. `animacore/skin.py` + `animacore/raster/skin_compositor.py` —
  skins (`skin/v1`): a `body.png` bezel + `screen_bbox`, and `apply_skin` paints a
  frame into the cutout. `animacore/raster/mscript_runner.py` — `MscriptRunner`/
  `render_mscript` play the Mscript command stream into real frames. Bridge gains
  incremental `canvas2d.add_surface`/`update_surface`/`remove_surface`/`add_source`/
  `remove_source` verbs for editor CRUD. Stdlib + pyyaml (skin compositing +
  Mscript playback need the `media` extra). Design in
  `dev/docs/roadmap/2D_Character_Pipeline.md` §11.
- **2D media library + in-app picker:** `examples/assets/2d/` mirrors the Mochi
  project's media asset tree (png/bmps images, ~70 gifs, ~31 videos, 8×8 bitmaps,
  math/mscripts/procedural/packs/skins; ~37 MB, mostly `video/`), with `.props.yaml`
  sidecars + a built `CATALOG.json` (149 renderable assets), plus two example
  characters that use it: `examples/pixel_pet_2d.character.anima` (colorwheel image
  + procedural face) and `examples/dino_screen_2d.character.anima` (animated gif
  surface). Both render imported media end-to-end (tested). The 2D workspace
  preview gained a subject picker (Face / Pixel Pet / Dino GIF) that renders each
  live via the bridge. `SimpleFace` now draws over a faint translucent breathing
  tint (was opaque) so a face composites *over* a media background instead of
  hiding it. The media is a dev fixture — see `examples/assets/2d/README.md` on
  provenance/licensing before distributing.
- **Character types (3D / 2D / VR) + VR character workspace:** a Character now has
  a **type** (`StudioCharacterType`), chosen from a picker beside the workspace
  tabs. The second tab is **character-specific** — it routes to Rig (3D), 2D
  (`canvas2d`), or VR based on the type (replacing the fixed Rig tab):
  `visibleStages` returns one authoring tab per type. New `StudioWorkspaceKind.vr`
  "VR" workspace with a `VRCharacterWorkspaceView` — a live avatar preview
  rendered by the engine, driven by ARKit-style blendshape sliders (jaw/smile/
  blink/head) mapped to the face. Engine: `animacore/tracking.py` is the
  tracker-neutral contract — Apple's 52 ARKit blendshapes + head pose, and a
  `FaceTrackingFrame` → evaluated `values`; a tracked `jawOpen` drives an avatar
  through the *existing* `evaluate_surfaces` (so the avatar half of VR already
  works — only the tracker input is new). Face tracking on the Mac will use the
  webcam via Apple's Vision framework (the capture pipeline is the next piece).
  Also: fixed the floating expanded tool ribbon spanning full window width (its
  category strip now hugs content when floating). Design: `2026-07-24`, roadmap
  `VR_Character.md`.
- **Consolidated viewport controls:** the production right sidebar is now the
  single operator surface for camera/display controls, navigation profiles and
  help, materials, lighting, background, reflections, shadows, section view,
  and viewport appearance. The spatial HUD retains only the ViewCube and Home
  action; the old floating Visualization pill and duplicate display menu have
  been removed. Material and Environment share the reusable Visualization
  panel and remain bound to the real persisted viewport/project settings.
- **Standalone CAD benchmark:** `dev/Codex Bench/` builds a separate clickable
  Apple-focused `Codex Bench.app` for deciding the future CAD viewport/import
  architecture without coupling experiments to Anima Studio. Its active catalog
  now has four locally working STEP routes: Open CASCADE Technology feeding
  RealityKit (P1), raw MetalKit (P2), Three.js WebGPU in Swift WebKit (P7),
  and direct `navigator.gpu`/WGSL WebGPU in Swift WebKit (P10). P7 uses Three.js
  `WebGPURenderer`, reports the backend actually selected, and keeps its
  automatic WebGL 2 fallback. Historical pipeline IDs
  remain stable; removed P3, P4, P6, P8, and P9 are not renumbered.
  The Qt/Open CASCADE and Qt WebEngine experiments were removed from the Apple
  catalog, runtime, Settings window, automated benchmark, Swift package
  dependencies, and signed bundle after the normalized study showed their host
  and event-loop cost was not competitive for the Apple-first product. The
  `qt/` sources remain archived as implementation reference for a future
  separate non-Apple Qt application; their current AppKit/IOSurface host is
  macOS-specific and is not advertised as cross-platform product code.
  The desktop Open CASCADE OpenGL viewer, per-feature RealityKit entity graph,
  and SceneKit comparison are also absent from the active package and picker:
  they were macOS-only, resource-prohibitive, or legacy product directions.
  OpenGeometry and its WASM probe were removed completely because it could not
  import the operator STEP model. P7 now uses Three.js WebGPU; P10 uses direct
  GPU buffers, four-sample render/depth attachments, and WGSL surface/edge
  shaders without a scene framework or WebGL fallback. P5's small raw WebGL 2
  implementation was retained through the fair comparison and then removed
  from the active app after P10 matched its throughput.
  Every active renderer receives the same operator-selected STEP/STP file and
  shared Open CASCADE extraction where applicable; no app route inserts fixture
  geometry. The importer preserves assembly labels/transforms, B-Rep faces and
  feature edges, XDE colors, staged timings, and model tolerance. Shared CAD
  navigation supplies orbit/tilt, pan, roll, zoom, and fit. A standard Settings
  window owns renderer selection and complete shared themes covering background,
  material color policy, roughness/metallic response, edge display, selection,
  and key/fill/rim lighting.
  All 46 STEP files in `CAD DEMO/ARCADA001-2` pass isolated import probes
  (8,931 faces, 24,778 edges, 247,030 triangles). The historical nine-pipeline
  decision record and raw runs remain in
  `dev/Codex Bench/Reports/2026-07-19-pipeline-study/`; they identify P2 Open
  CASCADE → raw MetalKit as the production direction at 60 FPS and 19.7% median
  CPU, while documenting why the discarded routes were retired. A new retained
  catalog pass on the same 54,830-triangle part measured P1 at 50.7 FPS/70.6%
  CPU, P2 at 59.8 FPS/23.5% CPU, raw WebGL at 61.2 FPS, and direct Three.js at
  62.7 FPS. WebKit CPU/memory cover only the Swift host, so those figures are
  not directly comparable native totals; Three.js added only 6 ms over raw
  WebGL upload and remains a useful optional environment experiment. A true
  combined-assembly pass loads all 46 CAD DEMO files into one shared document
  (8,931 faces, 24,778 edges, 247,030 triangles; 230,466 compact render
  vertices, 63 material/part batches, 46 rigid parts). The first pass exposed
  P1's per-face entity graph as unusable; the follow-up retained every pipeline
  and replaced that graph with one RealityKit `LowLevelMesh`, added one shared
  renderer projection, cached STEP imports across pipeline switches, moved P2
  static buffers to GPU-private storage with a stable per-part transform table,
  triple-buffered uniforms and topology IDs, and changed P5/P7 to one compact
  binary typed-array payload. On the optimized signed build P2 delivered 59.92
  FPS at 19.71% CPU and 231.21 MB app footprint; P1 completed at 59.83
  display-link Hz, 21.29% CPU, and 378.83 MB. P5 and P7 reported 52.71/52.68
  WebGL animation frames per second, but their 254.43/227.81 MB figures omit
  system-managed WebKit content/GPU processes and are not comparable native
  totals. Roles are therefore explicit: P2 production candidate, P1 secondary
  Apple renderer, P7 optional environment renderer, and P10 browser renderer
  candidate.
  A subsequent signed-app experiment moved P7 to Three.js WebGPU and confirmed
  that this machine's `WKWebView` selected native **WebGPU**, not the fallback.
  On the same 46-file assembly, a same-build P5/P7 comparison measured raw
  WebGL 2 at 78.02 FPS/11.77% app CPU/286.61 MB and Three.js WebGPU at 65.54
  FPS/9.53% app CPU/386.46 MB, with 42/45 ms buffer upload. WebKit helper
  processes remain excluded, so this validates compatibility and relative
  behavior rather than claiming complete GPU-process totals or a universal
  WebGPU performance win.
  The direct-WebGPU follow-up compared all three browser paths on that same
  document and measured P5 raw WebGL 2 at 60.80 FPS/9.43% app CPU/376.23 MB,
  P7 Three.js WebGPU at 61.24 FPS/8.18% app CPU/422.78 MB, and P10 raw WebGPU
  at 60.78 FPS/10.23% app CPU/223.70 MB, with 41/47/42 ms buffer setup.
  Repeated isolated P10 launches ranged from 51.63 to 60.78 reported FPS while
  upload held at 41–43 ms, confirming WebKit frame-callback scheduling is too
  variable for a finer browser FPS ranking. Direct WebGPU completed the full
  workload and uses the modern API, so P10 replaces P5 in the active catalog as
  a product-direction decision rather than a claimed benchmark win. P7 retains
  an automatic WebGL 2 fallback;
  P10 reports unsupported WebGPU as an error rather than silently changing
  renderer APIs.
  Historical measurements remain in
  `dev/Codex Bench/Reports/2026-07-19-assembly-benchmark/`; the optimized run is
  in `dev/Codex Bench/Reports/2026-07-19-optimized-pipelines/`; the WebGPU run
  is in `dev/Codex Bench/Reports/2026-07-19-webgpu-pipeline/`; the direct-WebGPU
  comparison is in `dev/Codex Bench/Reports/2026-07-19-raw-webgpu/`. Sixteen Swift
  tests, recursive format lint, release packaging, deep signing, headless
  46-file probe, and all four signed-app assembly runs pass.
- **Production STEP/CAD rendering:** the retained Codex Bench architecture is
  now integrated under `app/` rather than remaining a prototype-only result.
  `AnimaCADShim` is a crash-guarded C++ boundary over Open CASCADE 7.9 XDE;
  `AnimaCAD` projects STEP/STP into one renderer-neutral document containing
  metre-space triangles, assembly labels, per-face XDE colors, exact B-Rep
  feature-edge polylines, topology IDs, transforms, tolerances, and staged load
  timings. `RealityKitModelLoader` consumes that same document, so STEP is a
  first-class picker/drop/import format and a multi-node STEP assembly can
  author rigid Parts just like a multi-node USD. Malformed STEP becomes a
  readable import error rather than allowing a native exception to abort
  Studio.

  The production renderer catalog contains only the four retained paths: Open
  CASCADE → MetalKit (preferred high-volume STEP visualization), Open CASCADE → RealityKit
  (native Studio editing/selection/media path), Open CASCADE → Three.js WebGPU
  (optional virtual-stage experiment with reported WebGL 2 fallback), and Open
  CASCADE → raw WebGPU (diagnostic WGSL path). All consume the same imported
  document; none reparses STEP or changes saved rig meaning. Settings → CAD
  Renderer owns backend selection, ten coordinated themes, XDE-color policy,
  exact-edge visibility/strength, roughness, metallic response, key/fill/rim
  intensity, and optional live telemetry. Browser-renderer assets live in
  `App/Resources/CADWeb`, so archiving Codex Bench cannot break production.
  The 3D Modeling assembly tree's Origin, Front, Top, and Right rows now own
  view-only workspace-reference visibility. `CADPipelineViewport` derives one
  bounds-scaled reference presentation from the imported document: Metal draws
  an RGB origin triad plus independent wire grids, while Three.js WebGPU draws
  the same presentation with `AxesHelper`/`GridHelper`. Each tree eye toggles
  only its matching reference on both renderers. This state is editor
  presentation only and never enters `.anima` or changes mate semantics.
  Selecting a primary Part now adds a second, part-local RGB origin triad on
  Metal and Three.js WebGPU. The shared pipeline expands the existing
  source-to-node mapping into one column-major rest-transform map using
  AnimaCore's intrinsic XYZ convention (`R = Rx · Ry · Rz`), then hands the
  same selected-origin presentation to both thin draw adapters. The Inspector
  exposes the corresponding editable values under **Part origin (in
  assembly)** with metre position and degree rotation fields; edits continue
  through the existing AnimaCore-backed rest-transform path.
  CAD Parts now also consume that shared transform map: Metal updates the
  already-bound `partTransformBuffer`, while Three.js sets each node mesh's
  column-major `matrix` with `matrixAutoUpdate = false`. Neither path rebuilds
  imported geometry for a transform edit. A renderer-independent selected-Part
  overlay supplies local X/Y/Z translation and rotation handles; its pointer
  deltas produce rest-transform edits through the existing guarded workspace
  setters, so the mesh, local origin, and numeric Inspector stay synchronized.
  The overlay is anchored to the selected Part or sub-assembly frame rather
  than the viewport center. Metal projects that frame with the exact shared
  render view-projection matrix, while Three.js reports its helper's projected
  world origin through the existing web bridge. The control follows camera and
  transform edits and hides when its origin is behind the camera or offscreen;
  there is no cosmetic center-screen fallback.
  Grounded Parts now remain visibly fixed throughout that same flow. The
  pipeline expands `Part.isGrounded` through the shared source-to-node map;
  Metal consumes a retained Part-state bit and Three.js consumes the same
  grounded Part IDs to draw a blue fixed cue, with active selection still
  taking precedence. The transform overlay and Inspector identify the pinned
  state and disable editing, and the workspace rest-transform setters reject
  grounded edits so the engine-owned placement cannot be moved indirectly.
  Sub-assemblies are now first-class editor hierarchy nodes with their own
  assembly-space origin/rotation and optional parent. Both assembly trees show
  acyclic nesting. Selecting a sub-assembly highlights every descendant Part
  and displays the shared origin/transform overlay; Inspector exposes the same
  frame numerically. A group move computes one rigid assembly-space delta and
  applies it to descendant group frames and canonical Part rest transforms, so
  Metal and Three.js continue drawing the existing common Part-transform map.
  Hide acts on all descendant presentation states, and Ground batches the
  descendant engine Part states through AnimaCore before one reload. Metadata
  v6 persists the hierarchy/frame and decodes older flat groups at the identity
  frame. Group metadata does not define mate semantics or introduce a Swift
  assembly solver.
  The 40-Part/60-FPS target still needs an operator benchmark on production
  hardware; automated coverage proves transform identity/order and edit math,
  not a display-link frame rate.
  The root-app builder follows the linked Homebrew OCCT Mach-O dependency
  graph, copies the required dylibs into `Contents/Frameworks`, rewrites them
  to `@rpath`, and signs them with the app. The local Homebrew bottle targets
  macOS 26; a release for older supported macOS versions must build/vend OCCT
  with the product deployment target before notarization. Verification passes:
  recursive Swift format lint, 321 XCTest tests, 26 Swift Testing tests, the
  native Xcode build, root-app rebuild, strict deep signing, a scan proving no
  absolute Homebrew dylib links remain, and a clean root-app launch. Synthetic
  topology and malformed-STEP crash containment are automated; a user-supplied
  production STEP assembly remains the final manual import walkthrough because
  the prior CAD DEMO corpus is absent from the current working tree.
- **Production Studio interface:** the real Swift app under `app/` now uses one
  shared `StudioWorkspaceScaffold` for every workspace without replacing its
  AnimaCore, project, import, selection, timeline, or RealityKit behavior. The
  frame has one center and three deliberately separate authorities: the
  centered top Tool sidebar creates or modifies model content; the left
  Workspace sidebar chooses what content is being worked on; and the right View
  sidebar controls camera, environment, appearance, and inspection. Both side
  rails use one panel-stack engine and default to no selected panel. Each tab
  independently opens or closes its panel, so several panels can stack in rail
  order. Floating panel headers reorder with a panel-width insertion line or
  tear off into canvas-clamped windows; a torn-off window re-docks when returned
  near its home edge. Opening and closing stacks use mirrored edge transitions
  beneath a higher rail layer, so neither side can cover or disable its icons
  during animation. The rail remains vertically centered independently of the
  growing stack, and a persistent setting can put panels on the outer edge while
  retaining the margin. Tool and camera navigation modes are mutually exclusive,
  only one tool can be armed, and the shared prompt bar owns repeat,
  background-click commit, and Escape/cancel behavior.

  One app-global layout state drives exactly three Studio modes. Floating keeps
  the center full-bleed and overlays content-sized translucent pill sidebars,
  vertically centered at the window edges. Docked moves the same sidebar
  content into fixed-width, flat, divided, full-height in-flow side panels;
  the Tool sidebar occupies only the top of the center column and is forced to
  Expanded density. Canvas hides the floating chrome, leaves plain
  capsule handles, and uses 16-point edge hot zones plus bridged zone/sidebar
  hover tracking so reveal does not flicker. Compact, Standard, and Expanded
  tool densities share shell-wide settings. Expanded is the launch default and
  renders one captioned Fusion-style row: catalogs of up to 24 tools show all groups
  together, with horizontal overflow available in a narrow window. A
  divider-free category strip appears only when a catalog is actually larger.
  Animate therefore exposes Transport, Keyframes, Curves, Tracks, and Reference
  as bounded categories; Nodes condenses its ten source families into Canvas,
  Authoring, Logic, Data, AI + Voice, and Outputs. Standard collapses each
  family into a labelled menu. Compact shows one icon per family; selecting it
  opens an anchored visual icon-and-label tool palette without removing
  less-used commands. Sidebar
  tabs live in workspace-observable state, right presentation and camera state
  are app-wide, tool density/category is shared, and the Studio mode is global,
  so switching workspaces or view branches does not reset the shell. The
  pre-scaffold `WorkspaceToolBar`/`WorkspaceRibbonPresentation` rendering path
  has been removed; the retained `WorkspaceRibbonCatalog` is now data consumed
  only by the live shared Tool sidebar. Rig actions carry typed payloads instead
  of parsed command strings and one dispatcher now owns ribbon enablement,
  selection, and execution. The two former rail implementations are one shared
  rail, and the View sidebar edits the same persisted viewport bindings that
  drive RealityKit rather than maintaining a second display-state copy. The
  internal layout case is now named `floating` while retaining its legacy
  `"studio"` raw value for preference compatibility.

  Demo tool catalogs are imported additively through a namespaced adapter.
  Existing production commands always win a title collision; missing
  Character, Rig, Animate, Show, and Hardware concepts remain visible but
  unavailable until their real operation exists. A **Design** destination is
  explicitly labelled as a sandbox. Its six Fusion-style categories (Design,
  Sketch, Surface, Mesh, Sheet Metal, Assemble) arm typed placeholder tools;
  canvas clicks create selectable feature cards, and its
  Documents/Features/Bodies/Mates browser plus editable Part Properties use the
  same production shell. It is not a CAD kernel and does not persist geometric
  semantics.

  The condensed 54-point document header keeps project/save state at the far
  left, all eight workspace destinations in a window-centered capsule, and
  engine, preview, layout, and help controls at the right. Its regions collapse
  independently at the demo's 1320/1060/880-point breakpoints: file commands
  move into overflow first, workspace labels become icons next, and runtime
  labels compact last. Home uses a dedicated Home/New/Open/Settings header
  rather than showing document-only workspace and engine controls. A
  preference-controlled bottom status bar and non-layout walkthrough overlay
  complete the frame. The empty-Rig call to action remains centered in the
  usable viewport. UI Dev retains the actual production specimens. The shared
  Tool sidebar now has three deliberately different densities: Compact is a
  centered category capsule whose icons open anchored labelled tool menus;
  Standard is a centered primary-tool capsule with per-group overflow
  chevrons; Expanded is a captioned group ribbon that hugs its content while
  floating and becomes full-width at the top of the center column when Docked.
  The center content's safe inset follows the selected density so none of these
  presentations clips or covers its content. All 344 XCTest tests and 27 Swift
  Testing tests, recursive format lint, the native Xcode build, root-app helper
  embedding, strict deep signing, and launch pass.
  The empty-Rig call to action is centered in the usable viewport instead of
  inheriting the viewport overlay stack's top alignment.
  The project header follows the compact CAD layout used by the approved demo:
  project identity and file commands remain left, an absolutely centered stage
  capsule shows all workspace names at normal widths and switches the entire
  capsule to icons below its responsive breakpoint, while runtime plus
  Studio-mode controls remain right. The Studio-mode
  control cycles Floating, Docked, and Canvas, and the same global choice is
  available from its menu and Settings.
  The main macOS window uses full-size content with a hidden transparent title
  bar, so the native traffic-light controls share the header's continuous
  surface instead of occupying a separate dark title strip. The Window scene
  explicitly uses content-minimum resizability, preserving standard macOS edge
  and corner resize hit regions/cursors above the 1100x720 minimum. A transparent
  AppKit control area behind the custom document header restores native window
  dragging and preference-aware double-click behavior (zoom, minimize, or no
  action) without intercepting the header's SwiftUI controls.

  Home is now the demo-faithful three-column workspace inside the same app
  window. Its dedicated header carries only app identity and project actions;
  document pipeline, Live, and Preview controls do not appear before a project
  is open. The left column owns direct default-location New, native Open,
  section navigation, and disk-backed recent rows with thumbnails, relative
  time, and revision chips. Workspace-root discovery is unioned with the stored
  recent list on every appearance, unresolved entries are pruned safely, and
  representative rows are shown only when the real list is empty. The middle
  column switches among Get Started archetypes, real recents, and honest
  Character/Library availability states; Hardware Character routes to
  Character authoring, Digital Character is marked Preview, and Show Control
  routes to Show. The right column carries Open & Connected and Learn links.
  New Studio Project creates a unique plain project folder directly beneath the
  configured workspace root without a save-panel interruption.

  The setting-controlled footer is a shared 24-point status surface on Home and
  every open workspace. It reads rather than owns state: workspace name,
  selected Part, renderer-derived triangle count, active render backend,
  viewport theme, and the linked Open CASCADE kernel version. RealityKit mesh
  loading and the retained CAD pipelines publish per-Part/source triangle
  counts to the workspace; no geometry count or renderer preference was added
  to AnimaCore semantics.
- **Character-workspace shell parity:** The production Character workspace is
  split into center collection, left browser, and right import/preview content
  and supplies those pieces to the same scaffold as Rig, Animate, Show,
  Hardware, Nodes, and UI Dev. Its selection and left-tab state are model-owned
  and initialize only once, so changing Studio mode cannot reset the active
  collection or selected Part. The structured collection is intentionally not
  treated like an unbounded 3D canvas: Floating presents it as a rounded,
  content-sized document (300–520 points tall) inside safe top/left/right
  overlay insets, while Docked remains a full-height in-flow table. Canvas uses
  the broad center while its sidebars are hidden, then animates the collection
  inside the same safe boundary when an edge-revealed sidebar enters. Spatial
  3D and node canvases remain full-bleed because only structured center content
  consumes the shell's overlay-inset environment. The Character browser and
  import/preview inspector are likewise content-sized in Floating mode.
- **Timeline-workspace shell parity:** Animate and Show keep their timelines as
  center/bottom structured editors without constraining the spatial viewport
  above them. Docked timelines remain flat, full-width, and in-flow. Floating
  and Canvas render the same editors as bounded rounded windows with a broad
  default width; when a left or right overlay is present—or is temporarily
  revealed from a Canvas edge—the timeline animates inside the published safe
  boundary so transport controls, track headers, keys, and cues are never
  covered. Top-tool clearance is intentionally ignored by the bottom editor.
- **Archived interface walkthrough:** `dev/archive/CodexUI/` contains the
  separate,
  clickable `CodexUI.app`, a presentation-only exploration of a modern CAD
  animatronic authoring environment. It imports no Anima Studio or AnimaCore
  target and performs no project, engine, model, hardware, or filesystem work.
  One consistent native SwiftUI shell provides a workspace selector, three
  visual themes, and a guided previous/next walkthrough across seven
  intentionally different layouts. Its layout now follows the sibling
  AnimaStudio Demo's canvas-first panel language: one reusable browser region,
  inspector region, and workspace tool ribbon can each dock into the layout,
  float inside the app window, or hide and restore. The compact floating ribbon
  omits the workspace name already present in the centered tabs and presents
  tool groups as unboxed icon/label targets on one quiet material pill. It can
  float at the top or bottom: top popovers open below and bottom popovers open
  above, always toward the workspace center; shadow direction, structured
  content clearance, and walkthrough clearance follow the chosen edge. Its
  existing tool groups still open as popovers. Floating, Docked, and Canvas
  presets reconfigure all three regions together, and a native
  Settings window exposes the same appearance/layout contract. Docked regions
  participate in layout and reduce the center area; floating regions instead
  overlay the full-size center so the canvas can use the complete workspace,
  while hidden side panels remain recoverable. Browser and Inspector headers no
  longer duplicate pin/dock controls: the combined header layout control and
  Settings are their placement authorities; side regions have no redundant
  wrapper title bar. In Canvas mode, moving to the thin left or right edge
  temporarily reveals that hidden panel as a compact floating window; leaving
  the edge dismisses it without changing the saved Canvas layout. The floating
  ribbon retains its own edge/placement menu. The header layout control cycles
  Floating, Docked, and Canvas, while its menu exposes both presets and the
  individual region states. Floating presentation retains the strongest
  pattern from the retired Codex Spatial exploration: the full-height sidebar slab and duplicate
  outer header both disappear, and each contained panel becomes a content-sized,
  independently rounded/material-backed widget with its own border, shadow,
  spacing, and visible canvas between cards. Right-side context widgets can be
  dragged independently by their header grip. Dragging uses direct,
  animation-free state updates and temporarily replaces expensive backdrop
  material with an opaque themed surface for smooth pointer tracking. Each
  live update clamps the actual widget frame to an eight-point workspace
  margin, so cards cannot be lost beyond any window edge; material returns at
  rest. Docking clears those offsets and returns the same widgets to a flush,
  continuous, full-height column. Spatial preview cards opt into a reusable 220-point
  minimum content height, so the Assets 3D preview remains a usable viewport
  instead of collapsing like a compact property card. Floating side regions
  cap their invisible layout lane at a
  responsive 72% of the workspace height (using all available space only in a
  short window), leaving visible canvas below and making their detached state
  unmistakable. The walkthrough is a constrained,
  bottom-center in-window popup above the status bar; showing, advancing, or
  dismissing it does not change header, ribbon, or workspace layout.
  Floating-panel clearance is content-aware:
  spatial 3D and node canvases remain full-bleed underneath floating chrome;
  the Rig, Animate, and Show 3D surfaces have no generic card outline, rounded
  mask, or center gutter, so their grids visually become the workspace itself;
  Assets tables, Hardware tables/dashboards, and the UI Kit matrix inset to the
  unobstructed visible area. Animate and Show treat both preview and timeline as
  center content: each spans the full center width beneath compact floating side
  panels, while the timeline reserves only a bottom floating-ribbon clearance.
  The main Rig, Animate, and Show render views share an optional bottom-right
  performance HUD for renderer, frame rate, CPU, memory, and GPU presentation.
  A viewport gauge button and Settings toggle control it; because CodexUI has no
  live renderer backend, its values are visibly marked **Sample** and the card
  says that the real telemetry hook is pending.
  CodexUI now shares the sibling AnimaStudio Demo's restrained surface system:
  near-black/white canvas and panel layers, three-level text hierarchy,
  intentionally subtle strokes, and common accent/success/warning/danger
  colors. Settings offers Studio Blue, Teal, Indigo, Orange, Graphite, CAD
  Light, and Midnight through a visual theme picker; the UI Kit exposes the
  complete surface and semantic token set. Shared panel headers, rows,
  property fields, pills, metrics, command buttons, project save badge, and
  the compact icon-only floating ribbon inherit those rules, so every
  workspace and specimen updates from the same implementation rather than
  copied screen styling. Real light/dark SwiftUI color-scheme switching and
  hover/press/spring feedback cover shared chrome, tree rows, workspace tabs,
  panels, and ribbon tools. The
  scrolling workspace row and duplicate header dropdown have been replaced by
  one centered capsule navigator. It lists all workspaces—Character, Rig,
  Animate, Show, Hardware, Nodes, and UI Kit—with a subtle divider preserving
  the authoring/utility distinction and a spring-traveling active capsule.
  Workspace-tab labels are operator-configurable in Settings as Automatic,
  All Labels, Selected Only, or Icons Only. Automatic keeps all names when
  space permits and retains the selected workspace's name alongside icon-only
  inactive tabs in compact windows. The former global bar plus workspace bar
  is condensed into one 54-point header matching the sibling AnimaStudio
  Demo's density: 24-point icon controls and 28–30-point workspace chips keep
  the stage capsule centered without making the chrome feel oversized. The
  first upper-left element is always the open project identity: a directly
  actionable Home icon, **Atlas Animatronic**, and **SAVED**, including at
  compact widths. The Home icon returns to the project browser without needing
  a second header control. The document bar resolves explicit expanded,
  compact, and minimal densities instead of allowing SwiftUI to crush its
  contents. The editable project-name field follows the rendered name's natural
  width and only caps long names, while save state remains a single-line fixed
  capsule. The centered workspace navigator keeps a protected width, and both
  sides occupy balanced zones around it. File/history commands
  progressively fold into the document menu; at the minimum supported window
  width, Settings and project commands become one overflow menu while
  retaining every action. The centered selected tab owns the current
  workspace/mode name. Settings, project/file access, and undo/redo follow left. Compact **Live**
  status and **Preview** playback capsules remain right. The layout-mode
  control sits at the far right immediately before walkthrough Help: it is
  icon-only, cycles on primary click, retains its complete placement menu, and
  uses distinct cyan/purple/orange/green boxes for
  Floating/Docked/Canvas/Custom so its current state remains readable without
  consuming text width.
  Master Live remains available from the Live popover and Settings rather than
  consuming permanent header width.
  The CodexUI app name and mark are deliberately quiet in the footer. Theme
  and detailed layout preferences remain in the native Settings window. The
  workspaces remain:
  Character (three-column content manager), Rig (semantic tree + CAD viewport +
  mate inspector), Animate (viewport + multi-track keyframe/audio timeline),
  Show (stage preview + multimedia cues), Hardware (device/channel/safety
  dashboard), Nodes (typed visual logic canvas), and UI Kit (reusable panels,
  fields, dialogs, tabs, notifications, material controls, and states). The UI
  Kit now follows the sibling AnimaStudio Demo's living-design-system gallery:
  a 28-point title and explanatory subtitle lead uppercase named sections,
  adaptive 300-point specimen cells use consistent 16/28/30-point spacing
  inside an 1180-point review width, and app chrome, timelines, viewport, and
  Settings receive full-width specimens where their real proportions matter.
  It presents actual shared components including workspace tabs, adaptive tool
  ribbon, production timeline, viewport/performance HUD, panel/row/field/pill/
  metric/button primitives, layout contract, and Settings. A visible 21-of-21
  coverage inventory backed by `UIKitAssetCatalog` establishes the rule that
  every new reusable UI asset must also gain a UI Kit specimen and catalog
  entry. The UI Kit also preserves the useful pieces of the retired Codex
  Spatial prototype. The interactive selection rail and adaptive keyframe
  actions remain one useful grouped control without a redundant outer panel;
  the UI Kit also includes a combined
  hierarchy/revolute-mate/live-hardware stack, and a full-width four-track
  Live Follow timeline with keyframes, playhead, and audio waveform. Its Nodes
  section now renders the same reusable node card, categorized library,
  selected-node inspector, typed-port row, and connected canvas as the Nodes
  workspace. Input, logic, AI/media, and hardware cards show normal, selected,
  and warning states; a full-width graph demonstrates connections, canvas
  status, zoom, and auto-layout controls. The node graph is a full-bleed
  workspace surface like the 3D viewport: it has no generic rounded mask or
  enclosing outline, while its node cards and controls retain meaningful local
  boundaries. Twelve
  deterministic catalog/tour/layout/header-density/drag-boundary/UI-Kit-coverage tests,
  recursive Swift format lint,
  debug/release builds, deep signature verification, launch, and process-health
  verification pass. The prototype is retained as a read-only design-history
  reference after its approved system was migrated into the production app.
  Its launcher also reuses an existing
  CodexUI process rather than forcing duplicate instances. The separate
  `dev/Codex Spatial/` source and app were removed after those useful specimens
  were consolidated here.
- **JaegerOS pin:** not yet set — for now the runtime is standalone and
  Jaegers read `.anima` files natively; the `jaeger-os` dependency and
  `animation`-slot module land later (see `dev/docs/roadmap/`)
- **What works:** the native macOS foundation under `app/` builds both as a
  Swift package and as a real `Anima Studio.app`. The checked-in Xcode project
  is reproducibly generated from `project.yml`, with a thin native lifecycle
  target over the reusable `AnimaStudioUI` package, shared Debug/Release
  `.xcconfig` settings, least-privilege sandbox entitlements, localized-resource
  support, an asset-catalog app icon, a launch-level UI-test target, and Xcode
  Canvas previews for the home, complete workspace, and animation timeline.
  `app/Scripts/build-root-app.sh` assembles an ad-hoc-signed development app
  at the repository root for direct Finder launch. The root bundle now embeds
  a signed Python 3.11 helper, AnimaCore source, and PyYAML dependency; the
  helper inherits the app sandbox and requires no repository path or active
  virtual environment after the app is assembled. Packaging rewrites both the
  Homebrew framework launcher and its nested `Python.app` launcher to resolve
  only the bundled framework, explicitly re-signs that nested app, and fails the
  build if either launcher still references Homebrew. `AnimaModel` defines project
  assets, stable semantic-part IDs, box/cylinder/sphere/locator rig proxies,
  metre positions, XYZ rest rotations in radians, backward-compatible Codable
  rest transforms, joint parent/child connections, optional part-local mate
  connector frames (origin plus primary/secondary axes), connector alignment,
  joint rigs, clips, hold/linear keyframes, and Codable project round-tripping.
  `AnimaEvaluation` still provides the pre-bridge transitional preview evaluator,
  but new animation meaning belongs in the canonical Python engine rather than
  this Swift module. A dedicated `AnimaCoreClient` now owns the typed newline-JSON
  protocol, long-running helper process, handshake, character load/validation,
  frame and character-space pose evaluation, release, shutdown, engine errors, and
  channel-index decoding.
  The Assets ribbon can import a `.character.anima` document, load it through
  AnimaCore, evaluate its first clip at a deterministic preview time, and request
  the engine's per-part character-space transforms through `resolve_pose`. Studio creates
  one renderer-only proxy per engine part and applies the returned metre
  positions and real-last quaternions directly in RealityKit at the playhead;
  it no longer infers a second hierarchy, connector frame, or mate motion in
  Swift. Continuous playhead evaluation is live for imported engine clips.
  General mate/clip character mutation, scene loading/playback, and hardware
  output remain subsequent bridge packets. The SwiftUI app launches into a
  Bottango-inspired dark home screen with working New Studio Project and Open
  Project actions. Its Recent Projects section uses compact thumbnail
  cards with the project name, actual last-opened timestamp, revision badge,
  and optional milestone metadata. Records are recency-sorted, deduplicated,
  capped at twelve, and stored as versioned user-local metadata. Cards load a
  cached render path when one exists and otherwise show an honest project-type
  preview. Hovering a card reveals a top-right remove control, and the same
  forget-only action is available from **Remove from Recents** in its context
  menu; neither path touches the project folder. Recents are pruned on load
  when neither their security-scoped bookmark nor fallback path resolves to an
  existing directory, and a missing project discovered on click disappears
  immediately as well. Records carry the real project-folder path plus a
  security-scoped bookmark; clicking a card reopens the folder, reads its
  manifest, and loads its active character through AnimaCore. A standard macOS
  **Settings** scene is available from the app menu and Command-comma. It uses
  one grouped sidebar with nine complete pages: Workspace, Layout, UI,
  Renderer, Appearance, Materials & Edges, Lighting, Navigation, and
  Developer. Workspace owns the single default project root
  (`~/Documents/AnimaStudio/` initially), supports
  choosing/revealing/restoring the folder, and persists custom roots with an
  app-scoped security bookmark. New Project, Open Project, and Save As all
  create this exact root before configuring their native panels, so first run
  cannot silently fall back to the Documents parent. Because macOS App Sandbox
  does not provide a static Documents entitlement, first use presents a focused
  folder picker: the operator selects Documents once, Studio creates
  `AnimaStudio`, stores its security-scoped bookmark, and opens the project
  panel there. Later launches go straight to that root. Stored references to
  the old spaced default migrate to `AnimaStudio`, while real custom roots
  remain unchanged. Navigation embeds the existing CAD mouse profile,
  bindings, response, and reverse-wheel controls rather than presenting a
  separate sheet. Renderer, Appearance, Materials & Edges, and Lighting expose
  the existing production viewport controls without duplicating their state.
  UI owns the design preset, accent, tool density, floating chrome, and footer.
  Developer owns the live visible-zone diagnostic and independently persisted
  visibility switches for Nodes, Design, and UI Dev; hiding an optional
  workspace removes only its tab, never its implementation. A
  launch-only invalid Recent Projects SF Symbol that previously prevented
  window construction for operators with saved recents is also corrected. A
  new project now opens as a genuinely empty project in the first **Character**
  workspace rather than silently inserting the sample mechanism or jumping
  ahead to Rig. Character is now a dedicated character-management surface backed
  by `project.json`: it lists every indexed character, marks and switches the
  active character used by Rig/Animate, and gives an empty project a prominent
  first-character action. New Character validates a project-unique name and
  offers the live **3D Character** rigid-parts pipeline alongside a visibly
  disabled, honestly labeled **2D (Live2D-style) — coming later** option. On
  creation the document layer adds `characters/<name>/`, while AnimaCore
  validates and serializes the zero-part canonical character; Swift never
  hand-formats its YAML. The new character then enters an in-app 3D loading
  stage with file drop/picker controls, progress, and inline errors. The
  Assets workspace now uses the same three-column grammar as the other
  authoring workspaces: a persistent shared-`TreeView` character tree on the
  left, one context-sensitive collection surface in the center, and a compact
  import tool plus live RealityKit selection preview on the right. The current
  project name and revision appear once in a compact non-tree header;
  **Project Characters** is the sole production tree root, so the active
  project is not redundantly nested as a folder around its own contents.
  Character Library, Parts Library, their rail tab, and the Publish affordance
  are intentionally hidden for the current production-test phase; their
  underlying storage remains dormant rather than being deleted.
  The tree does not invent a parallel catalog: Parts, mates/relations/groups,
  clips, and scene scripts project the retained engine/project data, while
  material/appearance rows project the active character's `editor.json`.
  Source assets are scoped to the active character. Every center collection
  now uses the same Table/Grid component: Table is the default, collection-
  appropriate headers remain visible at zero rows, filtering is shared, and
  empty bodies consistently say **No … yet** without duplicating actions. Grid
  is an operator-selectable alternate view. The Parts table and grid use
  standard anchored selection: plain click selects one row and establishes the
  anchor, Shift-click selects every visible row in the inclusive range,
  Command-click toggles one row, and Command-Shift adds an inclusive range.
  Selecting a row gives the collection keyboard focus, so Backspace/Delete and
  Forward Delete reliably open the same confirmed bulk delete as the toolbar
  and context menu. Deletion edits the retained
  engine rig DTO, removes dependent mates, relations, outputs, and clip values,
  validates/serializes through AnimaCore, and prunes only model files no
  remaining part references. Parts show source, parent, engine state, and a
  deliberately simple app-side asset version: initial import is V1, while
  **Replace Part** or importing the same original filename again replaces the
  existing package asset and increments the integer in `editor.json`; no
  duplicate part or PDM/history system is implied. The collection surface is
  pinned to the top
  and fills the center column. The right Preview always remains a live 3D
  viewport, even before geometry is selected or imported. Dense CAD imports no
  longer crash the viewport: the CAD-selection topology (coplanar-face / edge /
  corner extraction) is skipped above a per-file triangle budget
  (`maxTopologyTriangles`, 40k), so a heavy part still loads and renders with
  whole-part selection while small parts keep face/edge selection. Model
  parsing already runs off the main thread and per-file import errors fall back
  to a placeholder body, so one bad file cannot crash an assembly load. Scaling
  further (hundreds of parts, GB workspaces) is planned in
  `dev/docs/roadmap/Loading_At_Scale.md`. A separate user-level Parts Library branch is visibly scaffolded
  for future cross-project reuse and is not stored in `.character.anima`.
  The
  workspace-model initializer accepts an alternate startup
  workspace so a future operator preference can choose it without changing
  workspace semantics. Its Bottango-inspired **Add to
  Rig** palette creates real core-backed box, cylinder, sphere, and empty-point
  proxy components with their local origin at the workspace origin, then
  creates a Revolute Mate through an explicit two-step placement flow. Orange,
  hover-reactive connector markers appear only while the mate-placement tool is
  active and expose proxy face centers, edge midpoints,
  corners, cylinder axes/circular centers, sphere cardinal points, and component
  origins. The first selection is the moving component; the second is fixed.
  The transitional local Revolute draft stores both connector frames but no
  longer performs a separate Swift mate solve; canonical document mutation and
  an AnimaCore reload/`resolve_pose` pass must perform alignment and motion.
  Component names, XYZ positions, XYZ rest rotations, and mate names, axis,
  parent/child
  connection, and angular limits are inspectable/editable in memory. The Rig
  ribbon presents the complete ten-type family: Fastened, Parallel, Slider,
  Revolute, Cylindrical, Pin Slot, Planar, Ball, Width, and Tangent. All ten are
  backed by the engine catalog for inspection; Revolute remains the sole
  transitional local draft-creation action until canonical character editing
  is wired. The mate inspector's Type row and UI Dev lab list the same family
  with per-kind DOF summaries. The Python rig model
  carries the same eight-type kinematic family (`JointType`, including
  `parallel`: XYZ translation + Z rotation) with per-type DOF templates,
  optional per-DOF limits, and gear/rack-and-pinion/screw/linear
  relations, plus two 0-DOF **geometry-constraint** mates — `width`
  (center a tab between two faces, no offset) and `tangent` (keep two
  surfaces in contact; non-driving, deferred with no geometry kernel).
  The engine recognizes, round-trips, and catalogs the geometry pair but
  their geometry is resolved app-side (`mate_category`); `width` resolves
  like a 0-DOF fastened once the app supplies its two midplane
  connectors, `tangent` leaves its child at the parent frame. The
  mate-authoring model lives in `animacore/mates.py`: every kinematic
  mate exposes one universal `MateControls` set — two flippable
  connector frames, an as-mated offset, a whole-mate primary-axis flip,
  a 90°-step secondary-axis reorientation, and a simulation-connection
  toggle — shared identically across all eight kinds, with only the DOF
  set differing per kind, plus a stable per-mate `id` distinct from the
  editable name; `width` reuses that control set minus offset/secondary,
  and `tangent` carries a two-selection `tangent` block instead of
  connectors. Two UI hooks surface it: the `mate_types` bridge verb (now
  ten schemas, each with `category`/`drivable` — static per-kind catalog
  of label, DOF slots, control ids) and `describe_mate` (per-instance
  descriptor carried in the `load_character` joint summary, with
  `category`). The Swift bridge mirrors category, drivable state, DOF axis,
  optional connector controls, and the Tangent-specific surface payload as
  typed DTOs and requests the engine-owned catalog when it connects. Imported
  engine mates are listed in the real Components navigator by their stable
  tracking id, so a zero-DOF Fastened mate remains selectable rather than
  disappearing from the rotational preview projection. Selecting one opens a
  reusable engine-driven mate inspector showing its type/name/id, parent and
  child, both connector frames and per-side flip state, offset values formatted
  in millimetres/degrees, whole-mate axis flip/reorientation, simulation
  connection, and its engine-supplied DOF rows with explicit axes. Fastened
  presents an explicit fully-bonded zero-DOF state; Width and Tangent present
  distinct non-drivable geometry-constraint states, and Tangent shows its two
  opaque surface selections plus propagation. This first panel is intentionally read-only;
  editing the canonical character text and revalidating it through the bridge
  is the next mate-authoring packet. Motors, 3D Models & Media, and Events are also
  present as clearly disabled reference groups rather than fake working
  features. The Rig ribbon also consumes AnimaCore's `relation_types` catalog
  and presents Gear, Rack and pinion, Screw, and Linear in engine order. Each
  opens one shared draft dialog whose Driver and Driven pickers are filtered by
  the engine-declared rotation/translation kinds. The dialog shows the positive
  Relation ratio or Distance per revolution field, a separate Reverse direction
  checkbox, and a read-only signed-native-ratio preview; it does not mutate the
  character yet. Imported `load_character.relations` entries appear in the
  navigator with a dedicated read-only inspector for their paths, ratio, offset,
  reverse state, and reference geometry. Selecting one resolves both DOF paths
  to their engine mates and highlights the two corresponding child components
  in RealityKit. Dependency ordering, coupling motion, limits, and sign meaning
  remain exclusively engine-owned; canonical create/edit is a later
  character-document authoring packet. Its project
  window now uses a CAD-style two-level header: a compact global document/live
  row followed by one full-width contextual command ribbon. A fixed far-left
  dropdown switches Assets, Rig, Animate, Show, Nodes, and Hardware with Command-1…6;
  the former workspace-tab row has been removed. Each workspace replaces the
  ribbon with focused, grouped tools. The selector now keeps a readable
  228-point minimum width and uses an anchored, visually continuous workspace
  popover with large icon rows, purpose text, selected-row emphasis, and visible
  Command-1…6 shortcuts instead of the cramped detached system menu. Assets
  exposes Import, Manage, and Prepare; Animate exposes Transport, Keyframes,
  Curves, Tracks, and Reference;
  Show exposes Sequence, Clips, Events, and Sync; Hardware exposes Connection,
  Outputs, Mapping, Calibration, Safety, and Monitor. Implemented commands are
  live, while backend-dependent commands remain visibly disabled as planned.
  **Nodes** is a dedicated scene-logic planning workspace with a dark dotted
  canvas, draggable and selectable typed sample nodes, live curved flow edges,
  a searchable node library, a selection-driven inspector, structural
  validation feedback, zoom/grid/frame controls, add/delete/reset actions, and
  a compact timeline concept that explicitly presents graph and timeline as two
  views of one future scene document. Flow, performance, timing, and event
  families are available in the UI draft. The concept library now separates
  Inputs, Voice & AI, and Outputs, with placeable STT/TTS/LLM, memory, tool,
  microphone, text, event, audio, motion, screen, LED, and hardware cards.
  The library also includes FANUC-inspired structured logic concepts: IF/ELSE,
  single-line IF guards, SELECT, CALL, WAIT Until, AND/OR/XOR/NOT, input reads,
  output writes, numeric registers, flags, position registers, background
  monitors, and monitor-only End Scene. Typed ports and inspector properties
  show the intended manual scene syntax so future Visual and Script editors can
  project the same program. JMP and LBL exist only as red IMPORT ONLY reference
  cards and validation errors; Anima scenes require the structured Loop, SELECT,
  and CALL equivalents rather than irreducible jump flow.
  Typed visual ports and editable sample properties support UI review, while
  every concept stays validation-blocked from execution until its runtime
  provider ships. This surface does not
  yet load, save, compile, execute, or author connections in `.scene.anima`;
  the in-memory draft is intentionally not a second runtime model.
  A shell-level **UI Dev** workspace follows the project-authoring workspaces
  and Design sandbox in the selector without becoming saved character data. Its ribbon
  opens Windows, Interaction Labs, Controls, and Foundations galleries for the living Studio UI
  standard: action hierarchy and states, labeled/unit-aware inputs, native
  menus, reusable panel chrome, blocking dialogs, contextual popovers, and
  semantic color/geometry tokens. Canonical reusable styles now cover primary,
  secondary, quiet, destructive, selected-icon, card, and popover treatments.
  UI Dev's Agent command toggles a right-side panel constrained inside the main
  app canvas, with voice/chat/docs/ideas presentation, prompt starters, a
  composer, and an explicit close affordance. It is labeled as a UI prototype;
  microphone and Send remain disabled until an agent service is connected.
  Navigator, Inspector, Timeline, and 3D View commands now render the real
  production surfaces inside the UI Dev canvas in their operator-facing dock
  regions: Navigator on the left, Inspector on the right, Timeline below the
  viewport, and the 3D view in the center. They use an isolated sample rig and
  never create auxiliary AppKit windows. The Agent likewise remains a real
  right-side app panel. One explicitly labeled **Detached Window** is the sole
  floating UI Dev surface; it demonstrates the always-above-workspace utility
  panel pattern for compact temporary tools and reuses one saved panel instance.
  UI Dev opens on an **all-surfaces Template Matrix**: thirty-six current app
  specimens grouped into Windows & Workspaces, Timelines & Editors, Inspectors,
  Panels & Tools, Dialogs/Menus/Popovers, Buttons & Inputs, and Status & Empty
  States. Every specimen is visible together in a responsive board and names
  its intended production size. The board includes the real reusable Recent
  Projects cards, docked Agent, detached-tool template, and live scaled Mate
  Editor and triad labs alongside Navigator, viewport, timeline, appearance,
  hardware, context-menu, control, and feedback specimens. A stable catalog
  guarantees every current template ID belongs to one visible section. A
  separate **Variant Board** preserves that matrix while adding a wide,
  component-board comparison of twenty-six states across Workspace Chrome,
  Docked Panels, Inspectors, Timelines, Toolbars, Dialogs/Menus, and Status.
  Its search and family filter narrow the visible comparison without mutating
  the catalog; 50–110% density controls resize the four-column board, and any
  specimen can be focused with a visible dashed selection outline. The ribbon
  also exposes a dedicated **Reference Widgets** lab for visual patterns
  being tested before production adoption. Pack 01 implements three interactive
  SwiftUI references: a layered icon list with hierarchy disclosure, selection,
  hover, tags, and trailing state/type icons; a dismissible/restorable
  notification popup with a primary-controller choice; and a two-column layout/
  style inspector covering display mode, corner and border treatment, editable
  box-model spacing, background mode, and clipping. The same three reusable
  specimens appear in the global Template Matrix. Pack 02 adds two interactive
  tab patterns: a compact primary-command/settings panel with shortcut labels
  and a live Light/Dark segmented switch, plus a multi-document strip with
  macOS window context, tab selection and hover states, per-tab close controls,
  and new-tab creation. Both tab specimens are isolated in a dedicated source
  file and appear in the same matrix. Pack 03 adds a dedicated interactive
  Material Editor reference with a live HSB-driven preview sphere, editable
  name and surface type, native color selection, six selectable and independently
  enabled material channels, Float/Texture inputs, per-channel value and mix
  controls, locking, and explicit Node Editor/Assignment/Help feedback. It is a
  UI-only draft until renderer material, texture-asset, assignment, and document
  contracts are defined. Pack 04 adds **Timeline Design B**, an interactive
  multi-row animation lab with Dopesheet, Motion Curves, and Waypoint Lanes
  projected from one shared track/keyframe model. Operators can add rows, click
  empty row space to create sorted bounded keys, select and delete keys, add a
  key at the playhead, scrub the ruler, and switch presentations without losing
  state. Every variant draws the authored motion connection between waypoints;
  Motion Curves uses a smooth value-aware path while the other variants use
  direct readable segments. The Dopesheet is the default reference presentation
  and now follows the supplied compact editor more closely: its chrome is denser,
  the channel column is searchable, a Summary lane aggregates authored keys, the
  ruler uses 0–240 frame numbers at 30 fps, and the blue playhead reports its
  current frame in both the ruler and status footer. This remains a UI Dev
  comparison and does not
  replace the production Animate timeline yet. Pack 05 adds six reusable
  **Concept Template Cards** for rig organization, AI node-flow generation,
  tools/resources, assembly import, motion sequencing, and character outputs.
  The responsive cards provide purpose-built illustrations, title/detail/action
  hierarchy, hover and selected states, and explicit prototype-action feedback;
  they are available in both Reference Widgets and the Template Matrix. Pack 06
  adds an interactive **Icon Selector & Theme Lab** with a hover/select icon
  dock and Edit/Duplicate/Delete menu patterns. The same specimen switches
  among isolated Light, Dark, Graphite, Midnight, and Neon palette specs;
  selected-icon foreground colors are contrast checked. These palettes remain
  local to UI Dev until human review and a deliberate refactor of the app's
  dark-only appearance assumptions. None of these reference widgets is wired
  into an
  operator workflow until it is reviewed and adopted there. The separate
  **Live UI Kit** remains available with a resizable Design Inspector
  beside a production-component catalog. The inspector edits the shared Studio surface
  and semantic colors, muted/border strength, chrome and ribbon heights, panel
  radius/padding, field and control geometry, and Navigator/Inspector/Agent
  widths. Changes are range-validated, applied immediately through the same
  `StudioPalette`/`StudioMetrics` source used by the rest of the app, and saved
  automatically as a versioned user design profile. Standard, Compact, and
  High Contrast presets, destructive reset confirmation, JSON import/export,
  and copy-as-JSON are live. The adjacent kit lays out the docked window map,
  all canonical button states, production fields, menus, popovers, panel
  chrome, and direct links to the real embedded surface previews.
  A separate **Demo UI Kit** section now preserves the incoming demo vocabulary
  additively under `DemoKit*` names so no production component is overwritten.
  Its responsive gallery renders the layout rows, fields, cards, chips,
  commands, notifications, dialogs, progress/status overlays, mate/curve/
  environment/visualization inspectors, performance HUD, node cards, ViewCube,
  gizmos, document tabs, and full-width dope-sheet/feature timelines together.
  This is a living comparison surface for later consolidation, not a second
  product theme or persistence model.
  UI Dev also includes a dedicated **Nodes** tab rendering the production-sized
  node workspace in place so its library, canvas, cards, ports, edges,
  inspector, and timeline can be refined alongside the rest of the living UI
  standard.
  Its Mate Editor interaction lab uses one shared Onshape-style panel for the
  complete ten-mate family. A stable icon strip and full-width Type dropdown
  both switch that panel; the title, degrees-of-freedom readout, constrained
  translation/rotation Offset controls, and optional minimum/maximum Limits
  rows update from the selected kind. Slider exposes Z translation limits,
  Revolute exposes Z rotation limits, compound mates expose every permitted
  freedom with mm/degree units, Fastened explicitly has no motion limits, and
  Width/Tangent are labeled as 0-DOF geometry constraints.
  Connector picking, simulation-connection disclosure, accept/cancel,
  flip/reorient, preview, and solve affordances remain shared rather than
  duplicated per mate. Its Triad Manipulator lab provides a code-drawn,
  hoverable/drag-responsive center ball, XYZ translation arrows, rotation
  rings, plane pads, ghosted restricted motion, live units, and controls for
  handle scale and stroke weight. Both are explicitly design prototypes for
  refining operator readability and interaction; they do not claim the planned
  canonical authoring-mutation/DriveTarget path is shipped; only Revolute
  remains a local Rig draft action until that path lands.
  Rig preserves Structures and the complete Mate family and adds focused
  Connectors, Assemble, and Inspect groups before the planned Motors, 3D Models
  & Media, and Events groups. Its creation families stay docked in the ribbon
  rather than floating over the viewport; collapsing them restores a compact
  Rig tool row. Panel visibility
  remains independently restorable in-session for the navigator, inspector,
  and bottom editor. Assets
  centers import and hierarchy inspection; Rig centers components and mates;
  Animate owns the working timeline dock with transport, every clip motion
  track, clickable keyframes, click/drag scrubbing, adjacent-key and frame
  stepping, a real loop-preview toggle, horizontal zoom, and configurable
  24/25/30/60 fps timecode over continuous seconds. Its Dope Sheet includes
  honest empty Audio/Event capability lanes and switches to a read-only Graph
  presentation of hold/linear curves; selecting mates isolates their curves.
  Show has a distinct multi-track
  character/audio/screen/event timeline scaffold; Hardware has structured
  connection, safety, mapping, and filterable-log surfaces that visibly remain
  safely offline. The gear settings menu stores a user-local viewport
  appearance choice with Midnight, Graphite, CAD Light, and Blueprint presets;
  each changes the RealityKit background and major/minor grid colors without
  altering project data. The viewport now provides a readable grid and a live
  view cube driven by the same camera state as RealityKit. It mirrors manual
  orbit/pan/zoom changes; its faces, edges, and corners select principal,
  two-axis, and trimetric views, while its surrounding arrows rotate the view
  in 15-degree steps. When a principal face is head-on, curved corner controls
  roll the real camera and cube together by 90 degrees clockwise or
  counterclockwise. A dedicated camera/render menu provides
  perspective/orthographic projection, 30–90° perspective field-of-view
  presets and selection framing. The lower camera toolbar now contains Home,
  Display, and Help; Front, Right, and Top shortcuts are omitted because the
  view cube owns principal, edge, and corner navigation. Display independently
  controls Shaded, Shaded with Edges, Wireframe, Unshaded, and Translucent
  surfaces, mesh-edge visibility, grid, viewport appearance, and
  Balanced/Soft/Bright/High Contrast RealityKit lighting rigs. Shaded proxies
  use physically based materials with Matte/Satin/Glossy/Metallic finishes;
  Subtle/Studio reflection modes now use selectable Neutral Softbox, Cool Rim,
  or Warm Stage generated image-based-light environments with live intensity
  and rotation. Directional shadows remain independently switchable. The
  environment panel retains Midnight/Graphite/CAD Light/Blueprint quick picks
  and adds project-persistent solid and two-color gradient backgrounds. A real
  section view converts render materials to a bundled RealityKit clip-plane
  shader and exposes X/Y/Z selection, numeric/slider position, and a colored
  draggable viewport handle; it intentionally does not yet cap or hatch the
  cut surface. Named camera views save/restore orientation, target, distance,
  and projection in character editor metadata, while Previous View swaps with
  the last completed camera interaction. High-quality rendering enables real
  4x MSAA. Lighting/environment/render-quality choices persist as user-local
  preferences; backgrounds, section state, and named views live in
  `<character>.editor.json`; none enter `.character.anima`. A lower-left
  **Visualization** control now joins the main 3D workspace.
  Its shared Material/Environment widget searches reusable Plastic, Metal, and
  Glass presets, lists deduplicated materials already assigned in the active
  Character, and applies color/PBR finish/opacity to the selected Part through
  the existing `PreviewPartAppearance` editor state. The Environment tab is a
  visual Studio browser with five live presets: Default, Transparent, Colored
  Mood, Gradient Mood, and Black and White Stage. Each card applies the real
  viewport background, generated studio environment, intensity, and rotation;
  Transparent is a true clear viewport-background mode, not a checkerboard-only
  sample. A detailed-settings button still exposes the same background,
  studio-lighting, rotation, and section-plane bindings as the Display menu.
  The production trigger and both browser tabs are also the thirty-sixth UI Dev
  specimen, so their styling remains a shared component rather than a separate
  mock. Material assignment remains renderer-only
  `<character>.editor.json` data and never changes `.character.anima` solve
  semantics. Cube face names are
  affine-projected decals:
  each label is centered in and foreshortens with its projected face quad,
  receives a readability correction rather than becoming mirrored or
  upside-down, and disappears when the face becomes an edge-on sliver. Its XYZ
  triad shares one origin, follows only the positive axis directions, and rolls
  with the same camera orientation; hovering previews the exact clickable face,
  edge, or corner. The viewport also provides trackpad pan/pinch and
  persistent Default, SolidWorks, Onshape, Fusion 360, and Custom mouse
  profiles. Default now intentionally mirrors SolidWorks: middle drag orbits,
  Option + middle drag pans, and Shift + middle drag performs precise zoom.
  Onshape uses right drag to orbit and middle drag to pan; Fusion 360 uses
  Shift + middle drag to orbit and middle drag to pan. Custom exposes
  conflict-free orbit, pan, and precise-zoom chords, including Option-based
  bindings. A dedicated Mouse & Navigation sheet opens from the camera HUD and
  follows the supplied compact control-panel reference: Scroll, Mouse, Buttons,
  Keyboard, Exceptions, and Settings icon tabs; a code-native mouse diagram;
  preset mapping summaries; Custom binding pickers; independent Slow-through-
  Very-Fast orbit/pan/zoom sliders; reverse-wheel direction; and a reset action.
  The settings persist through user-local `AppStorage` and never enter a
  project. Exception-driver integration is visibly labeled Coming later.
  Discrete wheel acceleration is normalized to one fixed notch and Standard
  speed changes distance by approximately 13%; precise wheel/trackpad deltas
  use a smaller clamped coefficient. Trackpad scroll phases still pan, pinch
  still zooms, and reverse direction applies only to wheel zoom. Right-button
  events now use one click-vs-drag router: a click opens the pointer-targeted
  Studio menu, a drag drives the active profile and suppresses the menu, and a
  double middle click returns to the framed home view. Semantic proxy geometry is
  directly selectable in the viewport and resolves to the same stable part ID
  used by the Components tree and inspector. Viewport clicks now toggle parts
  without a modifier, empty clicks clear selection, Option-click walks the
  RealityKit hit stack to select through overlapping geometry, and a small
  cursor-adjacent badge reports multi-selection count. Empty-space drag adds
  directional CAD box selection: left-to-right is a blue solid window requiring
  full projected enclosure; right-to-left is a yellow dashed crossing selecting
  projected bounds it touches. The selected component receives
  an orange silhouette highlight plus local XYZ translation arrows and rotation
  rings at its origin; dragging them edits the core-backed rest transform, and
  connector-authored mate rotation composes through parent/child chains. During
  pointer inspection, semantic proxy bodies and imported model surfaces use a
  cyan preselection glow before left-click commit. Imported STL, OBJ, and
  ModelIO-readable USD geometry now receives a cached topology projection at
  import/reimport time: duplicate mesh vertices are welded, connected coplanar
  triangles become selectable face islands, boundary/sharp-normal edges become
  selectable polylines, and vertices where at least three feature edges meet
  become selectable corners. A hovered face gets a translucent cyan surface
  overlay; an edge or corner gets a crisp cyan overlay with zoom-adjusted pick
  thickness; committed features turn stronger orange while the owning body and
  navigator row stay selected. These mesh features use the same
  `MateConnectorCandidate` contract as proxy candidates, so selection,
  inspection, staged Escape, and two-click mate placement do not fork into a
  second state model. Normal proxy selection no longer draws face-center,
  edge-midpoint, corner, axis, or origin dots over the body; those candidate
  points are placement aids rather than permanent model decoration.
  During any inspectable selection, Studio now restores the right-side Inspector if
  the operator had hidden it. A selected semantic proxy component exposes
  **Properties** and **Appearance** tabs. Appearance provides a 40-color
  industrial palette, an RGB/ColorPicker mixer, editable six-digit hex color,
  explicit RGB values, opacity, visibility, reset, a truthful Automatic
  tessellation readout, and Matte/Satin/Glossy/Metallic PBR finishes. Color,
  finish, opacity, and visibility update proxy and imported RealityKit geometry
  immediately; locked components reject these edits. Overrides persist by
  engine part name in the active character's app-owned
  `<character>.editor.json`, never in renderer-independent `.character.anima`.
  Generated box proxies now default to a mathematically sharp `0 mm` corner
  radius instead of the former hard-coded 35 mm rounding. Their Properties
  inspector exposes an explicit Fillet Radius field in millimetres; the
  clamped view-only value saves beside appearance in editor JSON, reloads
  without changing the engine solve, and legacy metadata defaults to `0 mm`.
  A selected
  semantic component also has a Studio-owned, CAD-ordered viewport context menu. It
  identifies the body and groups property editing, attached-mate navigation,
  show/hide, reversible isolate and transparency previews, mate-guide
  visibility, select-all/clear, Zoom to Fit and Zoom to Selection, lock/unlock,
  transform reset, and Appearance. Context routing now follows the pointer:
  right-clicking the selected component or one of its feature markers opens
  that full menu, while right-clicking empty space opens a compact Show All /
  Zoom to Fit / Isometric canvas menu. Right-drag remains camera orbit rather
  than a selection gesture.
  Isolation and transparency are renderer-only overlays that leave the saved
  rig and underlying appearance override unchanged. Menu commands use the same
  model-owned lock guards as the Inspector and transform gizmo. During
  mate placement, transform handles are suppressed so connector markers own the
  click target. Outside mate placement, the focused component shows the same
  inferred face-center/edge-midpoint/corner/axis/origin candidates as quiet
  cyan markers with view-cube-style hover: pointing at one highlights the
  exact clickable feature before commit-click. Clicking a marker selects that
  feature persistently (stronger cyan treatment) and keeps the owning
  component selected; the inspector shows a read-only Feature section with
  the owning component, feature kind, and part-local origin. Clicking empty
  viewport space now deselects the feature and all components; Escape clears
  the feature first, then component selection, and feature inspection is
  allowed on locked components while locks keep guarding every edit. The
  Instances outline follows macOS file-browser
  selection conventions:
  Command/Shift select multiple, one item opens its configuration, and Escape
  or the inspector close control clears selection. Imported geometry can also
  be selected directly in the viewport, with Command/Shift extending the same
  Instances-tree selection. Viewport selection requests reveal the matching
  row and expands its ancestors; **Go to Item in List** provides the same
  behavior from row and viewport context menus. Instances and **Mate Features**
  render through one generic `TreeView`/`TreeNode` adapter and one pure,
  renderer-independent tree model. Its filter accepts names plus `:part`,
  `:mate`, `:suppressed`, `:grounded`, `:hidden`, and `:locked` tokens.
  Imported assemblies appear in a separate blue, locked **Source Model ·
  Read Only** tree; filtering preserves the ancestors of matching nodes. The
  semantic Components and Mates remain separate editable-role rows in teal and
  purple. Component disclosure groups support contextual rename, move up/down,
  move-to-group, dissolve, and lock/unlock; Mates support contextual rename,
  reorder, and lock/unlock. Every component row is now a full-width drag and
  drop target. Its upper/lower zones show a raised, animated insertion line for
  before/after placement; the center shows a bordered **+ Create Group** target and
  creates an expanded folder containing the target plus the dragged active
  multi-selection. Existing folders accept the dragged selection, while the
  Components heading returns it to top level. Groups and Mates show peer
  insertion lines. Invalid drops (self/descendant cycles, incompatible node
  kinds, or locked source/target) are rejected before feedback or mutation.
  Rows display lock, hidden, suppressed, and grounded state icons. The footer
  and selected-row context menu expose **Group
  Selected (N)** and report when locked selections will be skipped. Locked
  items reject inspector, transform, and organization edits, hide transform
  handles, and locked groups protect their members. Group membership, ordering,
  locks, and disclosure state persist in the character's `editor.json`.
  Source-node inspection explains ownership, source appearance, mapping, and
  reimport prerequisites. Shared theme metrics and
  reusable panel, text-field, picker, readout, and primary-button styles keep
  new Studio windows visually consistent. The sample Rig viewport also renders
  a mate-guide foundation: labeled local XYZ axes, a revolute DOF ring, an
  optional reference plane, and a highlighted limit arc with independent layer
  toggles on every created mate. Project and asset names are also editable in
  memory. The operator-facing import contract is deliberately closed to STEP,
  STP, USD, USDA, USDC, USDZ, STL, and OBJ models; picker and drop flows reject
  Reality, URDF, glTF/GLB, and other extensions before loading. STEP/STP passes
  through the app's Open CASCADE/XDE boundary and preserves assembly labels,
  CAD colors, B-Rep faces, and feature edges in metres. USD-family files load
  through RealityKit; ModelIO converts STL/OBJ geometry into RealityKit meshes
  after an explicit mm/cm/m prompt (STL defaults to mm). Every live model-import
  entry point — the Assets ribbon, center Import/Replace controls, right-hand
  drop-zone click, and navigator footer — calls one explicit native macOS
  `NSOpenPanel`; the Anima Character command uses a separate single-file native
  panel. This replaces competing SwiftUI importer modifiers that could accept a
  click without presenting a chooser. A single
  character-targeted staging sheet reviews the batch, makes its destination
  explicit, explains that source files become rigid Parts, and gives each
  unitless file its own mm/cm/m setting; loading remains asynchronous and
  reports the current file. The destination may be any indexed character in
  the project; Studio safely saves and switches to it before loading. Imports
  default to **Copy into Project** under `assets/models/`; the staging sheet
  also offers **Reference in Place** through a security-scoped bookmark and
  never offers Move. Stable asset IDs in character editor metadata map either
  storage mode to safe relative per-part `model` tokens in AnimaCore's full rig
  DTO. Those tokens are serialized/reloaded by the engine and
  rendered at each part's `resolve_pose` transform. A multi-node USD can create
  persistent semantic parts sharing the same model with distinct `model_node`
  paths. A multi-renderable-node USD is automatically expanded into persistent
  Parts sharing the source asset with distinct `model_node` references. On a
  successful batch Studio saves the project and remains in Assets so the
  operator can review and organize the imported assembly before moving to Rig;
  failed imports stay on Assets with a readable inline error. Unitless-file scale lives in
  `<character>.editor.json`, so save/reopen
  restores the same metre-sized rendering. The complete entity hierarchy is
  projected into value-only nodes with unique sibling paths, shown as a
  selectable Structure outline, and described in the inspector. Package tests
  include real USD hierarchy loading/projection and real STL/OBJ metre-scaling
  bounds, duplicate/unnamed entity identity coverage, hierarchy
  filtering/ancestor retention, frame timecode and stepping, adjacent-key
  navigation, and loop/non-loop playback. The Swift side also ships the
  durable document layer as a UI-free `AnimaDocument` package target.
  `AnimaDocumentStore` saves/loads the version-2 **plain folder** layout:
  `project.json` owns project id/name, dates, revision, milestone,
  character/scene indices, editor state, and an asset table;
  `characters/<name>/<name>.character.anima` and
  `scenes/<name>.scene.anima` remain separate canonical engine documents;
  the Pack-and-Go source store has typed
  `assets/{models,assemblies,audio,video,images,scripts,renders}/` directories,
  created for new projects and backfilled on open. Legacy character-local
  assets remain readable. The manifest never
  encodes the Swift rig or clips.
  The user-level `Character Library/` now stores reusable, self-contained
  Character packages outside projects. Assets distinguishes **Project
  Characters** from **Character Library**: Publish creates/updates a stable
  library UUID with a simple revision counter; Add copies the complete package
  into the Project as a pinned, portable snapshot. `project.json` records
  `source_kind`, `library_character_id`, and `library_revision` without putting
  app bookkeeping into `.character.anima`. Project-local Characters remain
  supported and older version-2 manifests decode them as `project_local`.
  This intentionally prevents a later library edit from silently changing a
  deployed show. Saves are
  atomic (staged temp directory swapped into place — a crashed save never
  corrupts an existing package) and deterministic (sorted keys, stable
  asset ordering: identical input encodes byte-identically). Assets are
  SolidWorks-assembly style: `embedded` copies the payload into the
  package, `linked` records the external absolute path plus a
  security-scoped bookmark, and resolution returns an explicit needs-relink
  state for stale/missing links instead of throwing. Save accepts canonical
  text as an opaque write only after `serialize_character`; that same atomic
  save writes app-owned appearance/tree state to `<character>.editor.json`.
  Open sends the indexed file through `load_character` and restores that editor
  metadata. Save As copies the source folder,
  applies dirty files atomically, increments revision, and retargets the open
  session without modifying the source. Native New/Open/Save/Save As controls
  are live. Successful imports autosave, and reopening through either recents
  or a chosen folder reloads the canonical Character plus its resolved model
  sources. Versioned reusable `.animasm` documents save under
  `assets/assemblies/`, migrate the demo's original assembly JSON on read,
  appear in Rig's Asset Library, and can group or recreate referenced Parts in
  the active Character. Corrupt manifests, unsupported versions, duplicate
  character/scene/asset names or IDs, missing canonical documents/payloads,
  and any path escaping the project are
  rejected with typed, user-presentable errors (traversal is validated
  before the path touches the filesystem). A live integration test proves
  engine load → engine serialize → atomic project save → project reopen →
  engine reload. The Python package skeleton also
  installs with `pip install -e ".[dev]"`. The Python runtime now implements
  the Anima Wire Protocol v0 reference host (`animacore/wire.py` — encode
  HELLO/CFG/FRM/EN/STOP/PING, parse ANIMA/OK/ERR/PONG, 3-decimal normalized
  values), an in-process simulated device (`animacore/sim.py` — handshake,
  servo CFG, device-side linear FRM interpolation on an explicit `tick(now_ms)`
  clock, E-stop, per-channel 2000 ms failsafe, spec ERR codes), and a
  normalized output-track evaluator (`animacore/tracks.py` — hold/linear,
  time and limit clamping, deterministic; explicitly not a rig evaluator —
  AnimaCore keeps rig semantics; no Bézier yet). Per review: only successfully
  parsed commands refresh the failsafe heartbeat, and duplicate CFG keys or
  duplicate FRM channels are rejected (no last-write-wins). The runtime also
  loads `.character.anima` 2.0 files (`animacore/loader.py` — version/type
  check, typed errors naming the offending path, unknown-field rejection;
  unsupported/superseded spec sections are rejected loudly, never
  silently dropped) into a mechanism-rig model (`animacore/rig.py` —
  parts plus the eight typed Onshape-style mates whose type defines the
  DOF set; a character is an assembly of rigid parts, each carrying an
  opaque per-part `model` asset-file reference (relative to the
  character's `assets/`, validated as a safe relative path — no
  absolute/`..`/empty segments) alongside its optional `model_node`
  (node within a multi-node file), round-tripped for the app and never
  parsed by the engine, so asset references are format-opaque there even though
  Studio currently admits only its documented USD-family/STL/OBJ import set;
  per-DOF limits are optional per Kinematics.md §2: an
  unlimited DOF is legal and never clamped, but mapping one to a
  bounded output channel is a load error naming the fix; per-joint
  as-mated `offset` blocks round-trip for Studio's spatial use; and
  gear / rack_pinion / screw / linear `relations` couple DOF pairs as
  `driven = ratio × driver + offset` with acyclic/single-driver/
  no-animated-driven validation. `evaluate_pose` resolves clip-driven
  DOF with neutral fallback and loop wrapping, applies relations in
  dependency order, and reports — never clamps — driven values outside
  their limits as `Pose.limit_violations`; `project_channels` (the
  target→normalized 0..1 channel seam feeding `wire.encode_frm`)
  raises `LimitViolationError` for a mapped violated DOF so hardware
  refuses to arm). `examples/six_axis_arm|rc_car|walle_style
  .character.anima` load end-to-end; rc_car exercises a steering
  rack-and-pinion relation and an unlimited free-spinning axle.
  Parts, joints, and relations carry persistent **object states** —
  `Part.suppressed` / `Part.grounded` and `Joint.suppressed` /
  `Relation.suppressed` (all default `false`, written to the file only
  when `true`, so round-trip is lossless) — that change the solve and
  survive save/quit/relaunch, distinct from app-owned hidden/lock view-state.
  Studio binds tree actions to these retained engine DTO fields, then
  serializes/reloads for engine validation; it does not duplicate suppress or
  ground as Swift-only flags. `evaluate_pose` drops a suppressed joint's DOF
  from the active solve and skips a suppressed relation; `resolve_pose`
  excludes a suppressed part (and deactivates its joints), skips a
  suppressed joint, and pins a grounded part at its authored rest transform
  overriding any incoming joint. Suppression is per-element (no cascade);
  an orphaned non-suppressed part floats to the origin. The bridge
  surfaces the states in the `load_character` rig summary (`describe_mate`
  / `describe_relation` / part entries) and round-trips them through
  `serialize_character`. Known bridge defect: if an output mapping targets a
  DOF removed by part/mate suppression, `project_channels` currently indexes
  that absent path and terminates the helper instead of omitting the inactive
  output; the Swift integration audit has handed an exact `base_yaw` repro to
  the engine lane.
  The runtime also ships the community-extension foundation
  (Extensions.md packet E1): `animacore/outputs.py` defines the
  `OutputAdapter` extension-point protocol (`open(channel_configs)` /
  `send_frame(targets, duration_ms)` / `stop()` e-stop / `close()`,
  with `ChannelConfig` mirroring the wire CFG fields) plus the
  built-in `SimulatorOutput` wrapping `SimulatedDevice` through that
  exact API, and `animacore/extensions.py` loads `<slug>.animaext`
  bundles — closed-schema `extension.yaml` manifests with typed errors
  naming offending paths, capability declarations (hardware/network/
  filesystem), `discover_extensions(search_dirs)` over caller-passed
  directories with duplicate-id rejection, and
  `entry: "module.py:ClassName"` class loading namespaced per
  extension with no `sys.path` pollution; `output_adapter` (E1) and
  `parametric_feature` (E2) contributions load, other known kinds
  parse but refuse with "not yet supported". The packaged
  `examples/extensions/udp-wire-output.animaext/` example streams
  wire lines as UDP datagrams and is tested from its real bundle path.
  Parametric features (Extensions.md packet E2 backend,
  `animacore/features.py`) are pure-data YAML templates — a
  `parametric_feature` entry must be a `.yaml` file, never Python —
  declaring typed parameters (float with explicit unit hint / int /
  bool / choice, defaults and ranges) and a body of standard
  parts/joints/relations/rig-parameters in loader shapes, with safe
  `${expr}` arithmetic substitution (no `eval`; unknown names and
  division by zero are typed errors) and nestable `repeat:` blocks
  for indexed copies. `expand_feature` validates parameter values,
  prefixes every emitted name with the instance name (two instances
  coexist), and resolves the `$parent` attachment sentinel;
  `merge_fragment` inserts the fragment into a character mapping that
  is then re-parsed by the standard loader — expansion never bypasses
  loader validation. The packaged
  `examples/extensions/parametric-linkage.animaext/` example (an
  N-link serial revolute arm with an optional prismatic end slider,
  `capabilities: []`) is tested end-to-end from its real bundle path
  through discover → load template → expand → merge → loader →
  `evaluate_pose` → `project_channels`.
  The runtime also ships the real-hardware serial bridge
  (`animacore/serial_transport.py`): `SerialWireOutput` implements
  the same `OutputAdapter` contract over pyserial (`pyserial>=3.5` is
  now a package dependency) — `serial_for_url` port opening (device
  paths like `/dev/tty.usbmodem*` or URLs like `loop://` for tests),
  HELLO handshake with protocol-version check, CFG+EN per channel,
  OK-checked FRM streaming, and best-effort idempotent STOP that
  swallows dead-port errors into `last_error` during an e-stop.
  Typed errors name what happened (`HandshakeError`,
  `ReplyTimeoutError`, `ProtocolError`, `DeviceRejectedError` carrying
  the device's ERR code/message); reply reads use pyserial timeouts
  only (0.5 s default, 2 s handshake — no polling, no sleeps), and a
  host-side timeout is the operator signal while the device failsafe
  stays the safety net. Tested over a real pyserial `loop://` port
  against the reference `SimulatedDevice` with exact-line assertions
  (no reconnect/threading yet — that lands with Studio live control).
  The runtime also executes `.scene.anima` shows headless
  (`animacore/scene.py`, the B10 offline-playback foundation):
  the execution-v1 subset of `Scene_Format.md` — `clip` (speed ratio,
  background `wait: false`, required `duration_s` for looping clips),
  one-off `pose` interpolation from captured start values, `wait`,
  `wait_for` event gates with optional timeout (`skip`/`end`), `set`/
  `if` over declared scalar variables (literals and variable copies
  only — no expressions yet), bounded and variable-gated `loop`,
  deterministic `parallel` (timestamp order, ties by track order), and
  outbound `event` emission — with the deferred spec actions (`speak`,
  `expression`, `blend_shapes`, `lights`, `ai_response`, `goto`)
  rejected loudly at load. Scene execution v2 adds the FANUC-inspired
  scripting constructs, additively within format 2.0: structured
  condition trees (`var`/`input` compare leaves with typed
  `eq/ne/lt/le/gt/ge`, `all`/`any`/`xor` (exactly two)/`not`
  combinators, unlimited nesting — data, never string expressions),
  `if: {when}` guards, `select` multi-way branches (first match, no
  fallthrough, duplicate literals rejected), `call` + top-level
  `subroutines:` (shared variable scope; recursion rejected at load
  with the cycle named), read-only externally driven `inputs:`
  (`runner.set_input` applies at the next tick boundary),
  level-triggered `wait_until` condition gates with `wait_for`-style
  timeouts, and background `monitors:` (BG-Logic interlocks scanned
  every tick before the main sequence, edge-triggered with re-arm,
  bodies restricted to `set`/`event`/the monitor-only `end_scene`,
  which e-stops the adapter and finishes with a result string such as
  `"estop"`). The `character:` path resolves relative to
  the scene file; `SceneRunner` has no wall clock (caller-driven
  `advance(now_s)` ticks plus `post_event(name)` gates and
  `set_input(name, value)` between ticks, mirroring the
  simulator's explicit-time discipline), merges active motion sources
  over held values, recomputes relation-driven DOF each frame with the
  same refuse-to-arm limit semantics, streams frames through any
  `OutputAdapter`, and reports `finished` /
  `ended_by_gate_timeout` / `stopped` / a monitor's result string,
  plus an emitted-events log.
  `examples/pick_and_wave.scene.anima` drives the six-axis arm through
  the whole v1 surface and `examples/patrol_and_greet.scene.anima`
  through the v2 surface (input-gated wait_until, select, a twice-
  called subroutine, an estop monitor).
  The runtime also exposes AnimaCore as the single canonical engine
  behind a stdio bridge (`animacore/bridge.py`, protocol
  `dev/docs/roadmap/Studio_Bridge.md`, BR1 slice): the Swift app spawns
  `python -m animacore.bridge` once per session and speaks
  newline-delimited JSON to it — `hello` handshake, `load_character`
  (returns a deterministic handle + a rig summary the app mirrors),
  `validate_character`, `evaluate` (DOF values, parameters, projected
  channels, and reported limit violations for one frame), `resolve_pose`
  (per-part world transforms — see below), `mate_types`,
  `relation_types` (the four relation kinds — Gear, Rack and pinion,
  Screw, Linear — as a static palette catalog), `serialize_character` /
  `serialize_scene` (the project-Save write side — see below), `release`,
  and `shutdown`. `load_character` also carries a `relations` array
  (`describe_relation` per instance: signed semantic `ratio` split into
  a display `magnitude` + `reverse` flag, plus a `ratio_field_value`
  that is the unitless ratio for gear/linear or distance-per-revolution
  in mm — `abs(ratio) × 2π × 1000` — for rack_pinion/screw). This is
  the seam that keeps the app a front end: it
  holds DTOs that mirror engine results and never redefines what a rig,
  pose, or frame means. Protocol logic is a pure
  `handle_request(session, request)` over dicts (format/protocol errors
  become typed `{ok:false,error:{code,message,path}}` envelopes, never a
  loop crash); an `evaluate` response's DOF values equal a direct
  `evaluate_pose` call, tested as a faithful passthrough. The engine also
  owns canonical **forward kinematics** (`animacore/kinematics.py`): a
  stdlib-only rigid `Transform` (unit quaternion `(x,y,z,w)`, real part
  last per RealityKit `simd_quatf`, plus a metre translation),
  `connector_frame`/`mate_motion`/`mate_offset_transform`/
  `child_in_parent`, and `resolve_pose(rig, pose)` walking the joint
  graph parents-before-children. Each mate moves the child relative to
  the parent about/along the **mate connector as the relative origin**
  per its DOF; at zero DOF/offset the child connector coincides with the
  parent connector with primary(Z) axes opposed, unless `flip_primary_axis` aligns
  them, plus a `secondary_axis_rotation_deg` twist. A part also carries a
  **rest transform** (`position_m` + `rotation_euler_rad`, its
  part-in-character location; intrinsic-XYZ Euler, degrees in the file):
  roots and grounded parts resolve at their rest transform (identity when
  unauthored), a mated child is placed by its mate instead, and
  `resolve_pose` output is character-space (Character-in-World is a
  scene-level transform, default identity — see
  `dev/docs/roadmap/Coordinate_Frames.md`). The bridge `resolve_pose` verb returns
  `{parts:{name:{position:[x,y,z], orientation:[x,y,z,w]}}}` — the
  RealityKit render hook. Studio now calls it for imports and every playhead
  update, maps the result to renderer-only part IDs, and applies it below an
  explicit character root (Character-in-World remains a separate identity
  transform while authoring one character). Free/grounded gizmo edits update
  engine `position_m` and intrinsic-XYZ `rotation_euler_rad`; save/reopen
  round-trips them. The duplicate Swift `RigPoseResolver` and
  `MateConnectorMath` implementations and their semantic tests are removed.
  The engine also owns `.anima` **writing** (`animacore/serialize.py`) — the
  project-Save contract: `serialize_character` rebuilds a `Rig` from the full
  `load_character` rig DTO and emits canonical `.character.anima` text
  (radians→degrees, metres kept, defaults omitted, deterministic);
  `serialize_scene` emits `.scene.anima` from a scene document. Both validate
  (an invalid rig/scene is a `format_error`, so the app never writes a broken
  file). Round-trip is the acceptance test — `load → serialize → load` yields
  an equal rig/scene for every `examples/` file. To keep the round-trip
  lossless the `load_character` rig summary was additively enriched (clip
  `keyframes`, output ranges, per-DOF `axis_vector`/`name`/`description`,
  joint `description`; nothing renamed or removed).
  The runtime also ships the standalone **Denavit-Hartenberg
  articulated-arm foundation** (DH1+DH2, `animacore/dh.py`): serial
  kinematic chains parameterized by the standard (distal) DH convention
  with **forward and inverse kinematics** — `DHLink` (`a`/`alpha`/`d`/`theta`
  + `joint_type` revolute/prismatic + optional `min`/`max`/`neutral`
  limits on the joint variable), `DHChain` (ordered links + optional
  `base_frame`/`tool_frame`, `dof`), `link_transform` (the standard
  `A = Rotz·Transz·Transx·Rotx` link matrix built from the shared
  `Transform` primitives), and `forward_kinematics` returning every
  cumulative link frame plus the tool pose, raising a typed `DHError`
  naming the joint index on a limit or arity violation. FK is stdlib +
  `math` + `Transform` only (no numpy — FK stays pure); verified against
  the planar-2R closed form and an independent 4x4-matrix reference for a
  6R UR5-style arm. **Inverse kinematics** (DH2) is `solve_ik(chain,
  target_pose, *, seed=None, position_tolerance_m=1e-4,
  orientation_tolerance_rad=1e-3, max_iterations=100, damping=0.05) ->
  IKResult` — damped least-squares (Levenberg-Marquardt) on the 6×N
  geometric Jacobian, clamping each joint to its limits every step and
  returning `IKResult(joint_values, reached, position_error_m,
  orientation_error_rad, iterations)`, reporting non-convergence honestly
  (`reached=False` with the final residual, no raise). This is the one path
  that uses **numpy** (added as an `animacore` dependency, `numpy>=1.26`),
  isolated below the pure-stdlib FK; verified by FK→IK→FK round-trips (the
  achieved pose matches an FK-generated target for the 2R and 6R arms),
  joint-limit respect, honest unreachable-target residuals, prismatic-slider
  IK, and determinism.
  The DH chain is now a real **articulated-arm rig type** (DH3): a `Rig`
  may carry an optional `KinematicChain` (`animacore/rig.py`) — an ordered
  list of `ChainJoint` DH links (`a_m`/`d_m` metres, `alpha_deg`/`theta_deg`
  degrees→radians, per-joint-variable `limits`/`neutral`, an optional
  `part` that rides the link frame), a `base_part` whose rest transform is
  the chain base frame in character space, an optional `tool_part`, and a
  tool offset. Declaring the top-level `kinematic_chain` block makes the
  character that type. Its joints are **drivable DOF** (`"<chain>.<joint>"`)
  that clips animate, evaluate to neutral otherwise, and may map to bounded
  output channels; `resolve_pose` places each link/tool part by **DH forward
  kinematics** (character-space, overriding the rest-transform root
  placement) while non-chain rigs are unchanged. The loader/serializer
  round-trip the block losslessly (`load → serialize → load` equal), and the
  bridge adds two verbs on a loaded arm rig's chain: `forward_kinematics
  {handle, joint_values:{joint:value}} -> {link_frames:[{position,
  orientation}...], tool_pose:{position,orientation}}` and `solve_ik
  {handle, target_pose:{position,orientation}, seed?:{joint:value}} ->
  {joint_values:{joint:value}, reached, position_error_m,
  orientation_error_rad, iterations}` (missing joints fall to neutral; no
  chain → a `no_kinematic_chain` error; FK/IK frames are character-space).
  `load_character` exposes the chain in its rig summary (null for a general
  assembly) so the app knows the rig is an arm and can drive it, and
  `rig_from_dict` reconstructs it for `serialize_character`. Example:
  `examples/six_axis_arm_dh.character.anima` (UR5-style 6R, alongside the
  mate-based `six_axis_arm.character.anima`). The Swift app now consumes that
  contract directly: a non-null chain adds a docked Articulated Arm inspector
  with one limit-bounded joint jog per axis (degrees/mm are display conversions
  only), calls `forward_kinematics` for every jog, and applies the returned
  character-space link/tool frames in RealityKit. A cyan XYZ/rotation target
  sits at the end effector; dragging it calls `solve_ik` with the current joint
  pose as seed, updates every joint and link on success, and stays orange at the
  requested pose with metre/radian residuals on honest non-convergence. No DH
  or IK math exists in Swift. The root app bundle also carries NumPy beside the
  explicit AnimaCore/PyYAML resources, so the signed helper has no virtual-env
  dependency. Live Swift bridge and workspace tests load the 6R example and
  prove decode → FK → IK → RealityKit-frame projection; 240 XCTest + 20 Swift
  Testing tests pass. Analytic per-geometry IK (DH4) is a later packet.
  1043 Python tests pass with `.venv/bin/pytest animacore/tests -q` (lint:
  `.venv/bin/ruff check .`), including end-to-end clip → FRM stream →
  simulated servo → failsafe, character file → rig evaluation →
  relation coupling → channel projection → simulated servo tests,
  rig evaluation → `OutputAdapter.send_frame` → simulated/UDP output
  tests, rig evaluation → serial bytes → simulated servo tests, and
  scene file → `SceneRunner` → simulated servo values at exact
  timestamps with logic-gate branching and monitor-driven e-stop.
- **What's stubbed:** every `*.example` file under `animacore/` —
  `module.yaml`, `config.py`, `node.py`, the module-contract test —
  these are the JaegerOS-module shape for later
- **Known gaps:** imported model hierarchies can be inspected, filtered, and
  mapped to persistent semantic parts, but still use temporary sibling-index
  paths; durable source identity, reimport reconciliation, collapse, and
  topology remapping are not implemented. Source nodes are intentionally locked,
  and semantic-part drag reparenting waits for the persistent part/undo model.
  Proxy connector inference and two-click Revolute Mate placement are live,
  but connector orientation flip/reorientation controls, persistent custom
  connectors, and attachment to imported source nodes are not yet implemented.
  Automatic imported-hole centers require durable mesh/topology references;
  current hole-like snapping is available on cylinder proxy axes and circular
  face centers. The shipped part transform gizmo edits semantic-part rest
  transforms outside mate placement. Sub-object selection covers inferred proxy
  candidates and cached imported-mesh face islands, feature-edge polylines, and
  3+-edge corners. Imported feature IDs are deterministic for unchanged
  topology, but durable identity remapping after a topology-changing reimport
  remains open; this is a mesh projection rather than a CAD-kernel B-rep, so
  analytic holes/cylinders and tangent curves are not inferred. Transform gizmos are currently
  world-scaled rather than screen-size-stable. Mesh Edges and Wireframe display
  triangle mesh lines, not classified CAD feature edges; hidden-line removal
  remains unimplemented. The Open CASCADE → MetalKit, Three.js/WebGPU, and raw
  WebGPU selections are currently STEP inspection/visualization surfaces; live
  AnimaCore per-Part pose transforms, semantic selection/manipulation, and media
  surfaces remain on the RealityKit authoring renderer. Section views and saved
  named views are now live. Typed
  prismatic/cylindrical/ball/planar/fastened joints and keyframes are not yet
  editable in the canonical rig DTO. Project folders and imported canonical
  characters persist. Rest-transform, suppress, and ground edits are projected
  into the retained DTO; transitional proxy creation/rename and mate creation
  are not all canonical yet. Scene Open is deferred because the
  bridge has no `load_scene` twin. Undo/redo and live hardware controls remain
  visibly disabled; Home archetype routing is now live, while the Digital
  Character archetype is explicitly marked Preview. Studio never parses `.anima` itself:
  AnimaCore loads and serializes `.character.anima` and executes the
  `.scene.anima` v1+v2 subset; the deferred scene actions — speech, expressions,
  lights/LEDs, AI handoff, and goto — execute nowhere. There are no
  editable Bézier curves/handles, audio, screens/LEDs, Live2D, Studio Show
  workspace playback, output
  node, JaegerOS connection, or full 52-blend-shape JP01 character file (a
  minimal example head ships in `examples/`). The root app bundle is a local
  development artifact rather than a notarized distribution; release signing,
  notarization, updater/distribution packaging, and App Store policy work have
  not started. Studio is a working workspace
  foundation, not yet a complete authoring workflow.

- **Production widget/tree contract (2026-07-20):** editable navigator trees
  now share deterministic filtering, disclosure/reveal, state badges,
  lock-aware selection, reorder/group drop feedback, and atomic bulk-removal
  behavior. The Rig Instances tree exposes confirmed single/multi-part Delete;
  engine Mate and Relation rows expose confirmed semantic Delete, with mate
  removal pruning dependent relations, outputs, and keyframe values before the
  edited DTO returns to AnimaCore for validation. Workspace-sidebar tabs now
  show their actual working sets (Mates, Relations, Clips, Cues, Outputs,
  Safety) instead of repeating the generic component navigator. Fixed project
  taxonomy and imported source hierarchy remain explicitly locked reference
  trees. Production node transport controls are disabled instead of enabled
  no-ops. The complete surface-by-surface capability and honest-gap matrix is
  in `Widget_Production_Audit.md`.

- **Demo Home/footer production port (2026-07-21):** the frozen demo remained
  read-only while its merged three-column Home, Home-only header, direct
  default-root project creation, disk-discovered/stored recents union, sample
  fallback, archetype routing, connected resources, and global 24-point footer
  moved into production. The footer appears on Home and open workspaces and
  reads real selection, renderer-published triangle counts, backend, theme, and
  OCCT version. Recursive format lint, 332 XCTest tests plus 27 Swift Testing
  tests, native/root builds, embedded dependency signing, strict deep
  verification, and fresh live launch pass.

- **Center View and visible-zone production shell (2026-07-21):** Character
  exposes 3D/Gallery/Table; Rig exposes 3D/Table/Exploded; Animate exposes
  3D/Dope Sheet/Curves; Show exposes Node Graph/Table/3D; and Hardware exposes
  Servo Timeline/Table/3D through one bottom-center switcher. Spatial centers
  remain full-bleed. Structured centers consume shell-computed environment
  insets for the top tool bar, open left/right panel stacks, Canvas reveals,
  bottom switcher, and torn-off panel footprints, while Docked chrome remains
  in-flow. Settings > UI > Chrome includes a live dashed visible-zone overlay.
  Full `swift test` passes 348 XCTest plus 27 Swift Testing tests; focused
  format lint, native/root builds, strict deep signing, and live launch pass.

## How to update this file

1. Ship a behavior change.
2. In the same commit, add or edit a line above reflecting the new truth.
3. If something moves from "planned" to "shipped," delete it from
   `../roadmap/` (or mark it done there) — don't leave the same fact
   living in two docs, per `CONVENTIONS.md` law 1.
