# Active goal: Bottango-class hardware animation (started 2026-07-14)

Build Anima's own version of Bottango's core loop: author motion on a
timeline, see it live on real servos, and play it back offline on the
robot. Feature map and milestones: `dev/docs/roadmap/Bottango_Parity.md`.

## Work split

### Lane A — Studio — Swift, `app/` — **Codex**

Per Jonathan (2026-07-14, latest): Codex owns the Swift app GUI side.
Claude is backend-only. Codex also keeps planning + cross-lane review.

Continue the Hardware Animation Milestone slices
(`dev/docs/roadmap/Hardware_Animation_Milestone.md`):

1. Model hierarchy inspection + semantic part mapping (current gap in
   STATUS.md).
2. Editable joints and keyframes; project persistence.
3. Bézier interpolation + graph/curve view (Bottango's signature editor).
4. Slice 5: the renderer-neutral `AnimationOutput` contract and a
   log/simulator output.

When `AnimationOutput` exists, its serial implementation must emit the
wire protocol in `dev/docs/roadmap/Wire_Protocol.md` — flag any protocol
change needed in the Handoff log instead of inventing commands.

### Lane B — AnimaCore engine + protocol (Claude Code agent) — Python, `animacore/`, later `firmware/`

1. Wire protocol v0 spec (`dev/docs/roadmap/Wire_Protocol.md`) — the
   host↔microcontroller serial contract (the Bottango-firmware
   equivalent, but ours and open).
2. Python reference host: `animacore/wire.py` (protocol encode/decode,
   handshake, heartbeat) + a loopback simulator + pytest coverage.
3. Keyframe/curve evaluation in Python mirroring AnimaCore semantics
   (hold/linear now, Bézier when Studio lands it) so the runtime can play
   clips headless.
4. Arduino/ESP32 firmware sketch speaking the protocol (after v0 proves
   out over the simulator).

## Shared contracts (change only with a handoff note)

- `dev/docs/roadmap/Wire_Protocol.md` — both lanes implement it.
- Keyframe/curve semantics — the Python `animacore` engine is the canonical
  reference; Swift consumes it through the bridge. Deterministic evaluation, explicit units
  (`timeSeconds`, `angleRadians`).
- `.anima` format docs in `dev/docs/roadmap/`.

## Live claims

| Codex | Origin-anchor the 3D Modeling transform gizmo for selected Parts and sub-assemblies | shared screen-projection contract in `app/Sources/AnimaCADViewport/{CADPipelineViewport,CADMetalViewport,CADWebGPUViewport,CADTransformGizmoOverlay}.swift`, Three.js projection reporting in `dev/Codex Bench/web/threejs/src/app.js` + regenerated resources, focused CAD tests, STATUS + append-only coordination; preserve all concurrent hunks | common gizmo center follows the selected Part/group frame under camera orbit/pan/zoom and transform edits; Metal uses the exact render view-projection, Three.js reports its projected helper origin; offscreen/behind-camera gizmo hides; no viewport-center fallback; build/tests/JS/native/root verification pass | released 2026-07-28 — exact shared Metal projection + Three.js projected-helper bridge; 357 XCTest + 39 Swift Testing, recursive lint (existing/concurrent warnings only), JS check/build/copy, native/root builds, strict signing, packaged-resource identity, and launch pass |
| Codex | 3D Modeling buildout Task 6 — nested sub-assembly nodes with origin/transform and unit hide/ground/move | `app/Sources/AnimaDocument/CharacterEditorMetadata.swift`, `app/Sources/AnimaStudioUI/AppShell/{NavigatorOrganization,StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Components/{AssemblyTreeView,InspectorView,ProjectNavigatorView}.swift`, `app/Sources/AnimaCADViewport/{CADPipelineViewport,CADTransformGizmoOverlay}.swift`, focused tests under `app/Tests/{AnimaCADTests,AnimaDocumentTests,AnimaStudioUIUnitTests}/**`, STATUS + append-only coordination; preserve all existing/concurrent dirty hunks | backward-compatible editor metadata retains group parent + world origin; acyclic nesting renders in both assembly trees; group transform applies one shared rigid delta to descendant canonical Part rest transforms and both renderers consume the resulting existing map; group hide/ground batch descendants; tests/build/native/root verification pass | released 2026-07-28 — nested persistent frames + shared rigid descendant edits + unit hide/engine ground; 357 XCTest + 38 Swift Testing, recursive lint (existing/concurrent warnings only), native/root builds, strict signing, embedded string, and launch pass |
| Codex | 3D Modeling buildout Task 4 — grounded/fixed viewport cue + immovable rest transform | grounded Part projection/wiring in `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift` and `Components/InspectorView.swift`, shared state plumbing in `app/Sources/AnimaCADViewport/{CADPipelineViewport,CADMetalViewport,CADWebGPUViewport}.swift`, `dev/Codex Bench/web/threejs/src/app.js`, regenerated resources, focused tests, STATUS + append-only coordination; preserve existing/concurrent dirty hunks | grounded engine state expands through the shared source→node mapping; Metal part-state bit 2 and Three.js material cue visibly distinguish fixed Parts; gizmo and numeric transform edits are blocked while rest pose remains pinned; build/tests/JS/native/root verification pass | released 2026-07-28 — fixed-state projection/cue + guarded transform path; 355 XCTest + 37 Swift Testing, JS build/check/copy, native/root builds, strict signing, packaged-resource identity, and launch pass |
| Codex | 3D Modeling buildout Task 3 — shared per-Part rest transforms + direct translate/rotate gizmo on Metal and Three.js | `app/Sources/AnimaCADViewport/{CADPipelineViewport,CADMetalViewport,CADWebGPUViewport,CADTransformGizmoOverlay}.swift`, narrow transform callback/projection wiring in `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `dev/Codex Bench/web/threejs/src/app.js`, regenerated Bench/production Three.js resources, focused tests under `app/Tests/**`, `dev/docs/reality/STATUS.md`, append-only coordination; preserve existing/concurrent dirty hunks | one shared partID→column-major transform presentation drives Metal's existing partTransformBuffer and Three.js mesh.matrix; selected-part overlay provides translate/rotate handles and writes guarded rest transforms through workspace setters; both engines update without geometry rebuild; build/tests/JS/native/root verification pass | released 2026-07-28 — shared transform buffer/matrix updates + common translate/rotate overlay; 355 XCTest + 36 Swift Testing, JS build/check/copy, native/root builds, strict signing, embedded hook, and packaged launch pass; 40-Part/60-FPS remains an operator benchmark |
| Codex | 3D Modeling buildout Task 2 — selected Part origin display + explicit assembly-relative transform inspector | shared part-origin/transform presentation in `app/Sources/AnimaCADViewport/{CADPipelineViewport,CADMetalViewport,CADWebGPUViewport}.swift`, narrow selection/transform wiring in `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Components/InspectorView.swift`, `dev/Codex Bench/web/threejs/src/app.js`, regenerated Bench/production Three.js resources, focused tests under `app/Tests/**`, `dev/docs/reality/STATUS.md`, append-only coordination; preserve all existing/concurrent dirty hunks | selecting an engine Part shows one local RGB triad at its rest placement on Metal and Three.js WebGPU; Inspector labels and edits position/rotation as “Part origin (in assembly)”; shared transform math is computed once; build/tests/JS/native/root verification pass | released 2026-07-28 — shared AnimaCore-order matrix + selected local origin on Metal/Three.js; explicit editable Inspector section; 355 XCTest + 34 Swift Testing, JS build/check/copy, native/root builds, strict signing, embedded hook, and packaged launch pass; live WKWebView visual comparison deferred to operator |
| Codex | 3D Modeling buildout Task 1 — real workspace Origin + independently toggleable Front/Top/Right reference planes on Metal and Three.js WebGPU | `app/Sources/AnimaCADViewport/{CADPipelineViewport,CADMetalViewport,CADWebGPUViewport}.swift`, `app/Sources/AnimaStudioUI/Components/AssemblyTreeView.swift`, narrow shared visibility state/wiring in `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `dev/Codex Bench/web/threejs/src/app.js`, generated `dev/Codex Bench/Resources/ThreeJSWeb/app.js` + `app/App/Resources/CADWeb/ThreeJSWeb/app.js`, focused tests under `app/Tests/**`, `dev/docs/reality/STATUS.md`, append-only coordination; preserve all existing dirty hunks | tree eye controls drive one shared reference-geometry visibility value; workspace triad plus Front/Top/Right planes render on Metal and WebGPU with independent toggles; `swift build`, focused/full `swift test`, JS rebuild/copy, native/root app build and live walkthrough where available | released 2026-07-28 — shared bounds-scaled presentation feeds Metal and Three.js WebGPU; independent tree toggles tested; `swift build`, 355 XCTest + 31 Swift Testing, JS build/check, native/root builds, deep signing, packaged-resource check, and launch pass; real STEP load pass, final visual toggle comparison deferred to operator |
| Claude | VR character type + character-type-routed authoring tab + toolbar float-width fix (Jonathan-requested, cross-lane) | `animacore/tracking.py` + `animacore/tests/test_tracking.py`, new `app/Sources/AnimaStudioUI/Workspaces/VR/VRCharacterWorkspaceView.swift`, additive `.vr` arms + character-type routing in `app/Sources/AnimaStudioUI/AppShell/{WorkspaceDescriptor,StudioWorkspaceView,StudioWorkspaceModel,WorkspaceLayout,WorkspaceShell,WorkspaceSelector,WorkspaceChrome}.swift`, `app/Sources/AnimaStudioUI/Workspaces/{WorkspaceRibbonCatalog,DemoWorkspaceToolCatalog}.swift`, `app/Sources/AnimaStudioUI/Components/{InspectorView,ProjectNavigatorView}.swift`, `app/Sources/AnimaStudioUI/Settings/StudioSettingsCatalog.swift`, the `categoryStrip` float fix in `WorkspaceShell.swift`, matching test updates under `app/Tests/**`, `dev/docs/{roadmap/VR_Character.md,reality/STATUS.md}`; preserve other Codex hunks | `StudioCharacterType` (3D/2D/VR) on the model + a picker beside the tabs; `visibleStages` routes one authoring tab per type (Rig/2D/VR, replacing the fixed Rig tab); new `.vr` workspace + `VRCharacterWorkspaceView` live avatar preview driven by blendshape sliders through the bridge; `tracking.py` ARKit-blendshape contract proven to drive an avatar via existing evaluation; floating expanded ribbon no longer full-width; ruff + pytest + `swift build`/`swift test`/format-lint pass | released 2026-07-24 — 1162 pytest (+3 skip), 352 XCTest + 27 Swift Testing, swift build + format-lint pass. Deferred (needs on-device testing): the Vision webcam capture pipeline that replaces the sliders |
| Claude | Import the full Mochi 2D media library into examples + in-app media picker (Jonathan-requested) | `examples/assets/2d/**` (mirror of Mochi's media tree — gifs/png/bmps/video/bitmaps/animations/math/mscripts/procedural/packs/skins + `CATALOG.json` + README), `examples/{pixel_pet_2d,dino_screen_2d}.character.anima`, `animacore/raster/faces/simple_face.py` (translucent breathing bg so faces composite over media), `animacore/tests/test_example_2d_media.py`, `app/Sources/AnimaStudioUI/Workspaces/Canvas2D/Canvas2DWorkspaceView.swift` (subject picker only), `dev/docs/reality/STATUS.md`, append-only coordination; preserve other Codex hunks | full Mochi media library (~149 renderable assets: image/gif/video/bitmap; ~37 MB, mostly `video/`) with sidecars + built catalog; two example 2D characters render imported media end-to-end; the procedural face composites over a media background; the app 2D preview switches Face/Pixel Pet/Dino live via the bridge; ruff + pytest + `swift build`/format-lint pass; media flagged as dev fixture (licensing) + gitignore/LFS note for `video/` | released 2026-07-24 — 1158 pytest (+3 skip), swift build + format-lint pass; imported-media characters verified rendering (ASCII + tests) |
| Claude | 2D asset conventions — the create↔play interchange ported from Mochi (`.props.yaml` / catalog / packs / skins / Mscript runner) | new `animacore/{asset_props,asset_catalog,pack,skin}.py`, new `animacore/raster/{skin_compositor,mscript_runner}.py`, `animacore/bridge.py` (add incremental `canvas2d.add/update/remove_surface` + `add/remove_source` verbs only), new `animacore/tests/{test_asset_props,test_asset_catalog,test_pack,test_skin,test_mscript_runner}.py` + additions to `test_bridge_canvas2d.py`, `dev/docs/{roadmap/2D_Character_Pipeline.md,reality/STATUS.md}`, append-only coordination; touch no `app/**` | faithful ports (Apache-2.0): `asset-props/v1` sidecar (read + author) + `visual_source_from_asset`; `build_catalog` → JSON; `pack/v1` slots (str/list/dict resolution); `skin/v1` + `apply_skin` (paint into `screen_bbox`); `MscriptRunner`/`render_mscript` play the command stream into frames; bridge editor-CRUD verbs; stdlib+pyyaml (compositing/playback use the `media` extra); ruff + full `animacore` pytest pass | released 2026-07-23 — 6 new engine modules + 5 bridge verbs; 21 new tests; ruff clean; 1152 pytest (+1 skip). No `app/**` touched (these are the engine/format the app + middleware consume) |
| Claude | 2D workspace groundwork II — persistence (`canvas2d:` in `.character.anima`) + live preview (Jonathan authorized cross-lane, 2026-07-23) | `animacore/canvas2d_io.py`, `animacore/loader.py` (allow the `canvas2d:` top-level block only), `examples/pixel_face_2d.character.anima`, `animacore/bridge.py` (`canvas2d.load`/`save` + refactor DTO helpers to `canvas2d_io`), `animacore/tests/{test_canvas2d_io,test_bridge_canvas2d,test_loader}.py`, additive `canvas2DNew`/`canvas2DRenderFrame` on `app/Sources/AnimaCoreClient/AnimaCoreClient.swift`, live-preview rewrite of `app/Sources/AnimaStudioUI/Workspaces/Canvas2D/Canvas2DWorkspaceView.swift`, `dev/docs/{roadmap/2D_Character_Workspace.md,reality/STATUS.md}`, append-only coordination; preserve all other Codex hunks | canvas2d serializes to/from a `.character.anima` `canvas2d:` block (one shape shared with the bridge DTO); a pure-2D character loads as an empty-mechanics Rig + canvas2d block; the 2D workspace renders a **live** procedural face from the engine (`canvas2d.new` → `render_frame`, decoded PNG) with mouth/curve/eye/time sliders; ruff + pytest + `swift build`/`swift test` pass | released 2026-07-23 — 1131 pytest (+1 skip: 2D char has no servo outputs) + 352 XCTest + 27 Swift Testing; real stdio bridge smoke (hello→canvas2d.new→render_frame→128x128 PNG) verified; native Xcode build + live GUI walkthrough deferred to operator (headless env) |
| Claude | 2D character workspace groundwork — engine preview tool + `canvas2d.*` bridge verbs + Swift 2D workspace scaffold (Jonathan authorized cross-lane, 2026-07-23) | `animacore/raster/preview.py`, `animacore/bridge.py` (add `canvas2d.*` verbs + Session canvas storage only), `animacore/tests/{test_preview,test_bridge_canvas2d}.py`, `pyproject.toml`, new `app/Sources/AnimaStudioUI/Workspaces/Canvas2D/**`, and additive `.canvas2d` arms only in `app/Sources/AnimaStudioUI/AppShell/{WorkspaceDescriptor,StudioWorkspaceView,StudioWorkspaceModel,WorkspaceLayout,WorkspaceShell}.swift`, `app/Sources/AnimaStudioUI/Workspaces/{WorkspaceRibbonCatalog,DemoWorkspaceToolCatalog}.swift`, `app/Sources/AnimaStudioUI/Components/{InspectorView,ProjectNavigatorView}.swift`, `app/Sources/AnimaStudioUI/Settings/StudioSettingsCatalog.swift`, matching test updates under `app/Tests/AnimaStudioUIUnitTests/**`, `dev/docs/{roadmap/2D_Character_Workspace.md,reality/STATUS.md}`, append-only coordination; preserve all other Codex hunks | new `StudioWorkspaceKind.canvas2d` ("2D", ⌘8, tab after Animate) routes to a `Canvas2DWorkspaceView` scaffold; every exhaustive kind-switch handles it; `canvas2d.*` bridge verbs (describe/new/evaluate/render_frame/matrix_preview) + headless preview tool tested; ruff + full `animacore` pytest and `swift build`/`swift test` pass | released 2026-07-23 — `canvas2d.*` bridge verbs (7) + Session canvas storage; headless `preview.py` tool + CLI; new `.canvas2d` workspace across all 15 exhaustive switches + `Canvas2DWorkspaceView` scaffold + Surfaces/Media/Faces/Output tabs, ⌘8, tab after Animate; ruff clean + 1121 `animacore` tests; `swift build` + `swift test` (0 failures, incl. updated presentation/settings/ribbon assertions) + format-lint pass. Native Xcode build + GUI walkthrough deferred to operator (headless env). **Note for Codex:** entered the workspace shell with Jonathan's go-ahead; the new `.canvas2d` arms are additive placeholders — own/refine the 2D UI and wire the live preview (`2D_Character_Workspace.md` build order step 3) as you see fit |
| Claude | 2D pipelines imported from Mochi — real media rendering + serial hardware + Mscript scripting | `animacore/raster/**`, `animacore/frame_serial.py`, `animacore/canvas2d.py` (add `PROCEDURAL`/`BITMAP` kinds only), `animacore/tests/{test_raster,test_frame_serial,test_mscript}.py`, `pyproject.toml` (`media` extra), `dev/docs/{reality/STATUS.md,roadmap/2D_Character_Pipeline.md}`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,claude}.md`; touch no `app/**` or other engine files | ported (not re-implemented, both repos Apache-2.0, provenance headers kept): RGBA8 `FrameBuffer` + Mochi `open`/`close`/`next_frame(t)` contract; working image/bitmap/sprite/gif/video decoders (Pillow/numpy/imageio) + `ProceduralAdapter`/`SimpleFace`; `CanvasPlayer` alpha-composites surfaces; `SerialFrameOutput` streams `MM`/`BM`/`FM` to a real matrix; `MscriptScript` parser + `update(t)` flow control; decoders tested against real generated media; media deps optional (`media` extra); ruff + full `animacore` pytest pass | released 2026-07-23 — real decode of generated PNG/GIF/sprite/bitmap/mp4 verified; serial output verified on pyserial loopback; Mscript WAIT/auto-duration verified; ruff clean; 1109 `animacore` tests pass; end-to-end GIF-bg + face + alpha-composite → matrix demoed. Backlog: `.props.yaml` sidecar, `canvas2d:` loader + bridge verbs, Mscript→CanvasPlayer runner |
| Codex | Complete and reorganize production Settings from the Demo catalog, including a dedicated Developer page | `app/Sources/AnimaStudioUI/Settings/**`, narrow preference wiring in `app/Sources/AnimaStudioUI/AppShell/{AnimaStudioRootView,StudioWorkspaceModel,StudioWorkspaceView,WorkspaceChrome,WorkspaceSelector,WorkspaceShell}.swift`, `app/Sources/AnimaStudioUI/Components/ModelImportUnitsSheet.swift`, focused tests under `app/Tests/AnimaStudioUIUnitTests/{Settings,AppShell,Components}/**`, `dev/docs/reality/STATUS.md`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; preserve all unrelated shared-tree hunks and treat `dev/AnimaStudio Demo/**` as read-only reference | every Demo Settings page exists in production alongside retained production controls; pages are grouped as Workspace, Renderer, Appearance, Materials & Edges, Lighting, Layout, Navigation, UI, Developer; Developer owns zones plus Nodes/Design/UI Dev tab visibility; imported controls have real persisted bindings; tests/lint/native/root build/sign/launch pass | released 2026-07-21 — nine grouped pages, real persisted bindings, optional workspace visibility, 352 XCTest + 27 Swift Testing, lint/native/root build/sign/live Settings walkthrough pass |

| Codex | Consolidate viewport visualization, display, input help, and environment controls into the single production View sidebar | `app/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `app/Sources/AnimaStudioUI/Components/{ViewportCameraHUD,ViewportCameraControls,ViewportVisualizationPanel,ViewportSidebarPanel}.swift`, removal of the unreferenced legacy sidebar block only at the end of `app/Sources/AnimaStudioUI/AppShell/WorkspaceShell.swift`, focused component/app-shell tests, `dev/docs/reality/STATUS.md`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; preserve every Claude-authored hunk in `WorkspaceDescriptor.swift`, `WorkspaceSelector.swift`, and the active shell implementation | viewport retains only the spatial ViewCube plus Home; display/camera/navigation/mouse help live under View; Visualization Material/Environment and render-environment settings live under Environment; no floating Visualization pill or duplicate Display menu; tests/lint/native/root build/sign/launch pass | released 2026-07-21 — one consolidated right-sidebar implementation is live; the viewport HUD contains only ViewCube + Home; the floating Visualization pill and obsolete duplicate render menu are gone; 346 XCTest + 27 Swift Testing tests, touched lint, native/root build, deep signing, and launch PID 20348 pass; Claude's concurrent shell edits were preserved |

| Codex | Port per-workspace Center View switcher and first-class visible-zone layout system | `app/Sources/AnimaStudioUI/AppShell/{WorkspaceLayout,WorkspaceShell,StudioWorkspaceModel,StudioWorkspaceView}.swift`, center-mode views under `app/Sources/AnimaStudioUI/Workspaces/**`, UI setting keys/views, focused tests under `app/Tests/AnimaStudioUIUnitTests/**`, `dev/docs/reality/STATUS.md`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; `dev/AnimaStudio Demo/**` read-only reference | bottom-center per-workspace switcher; full-bleed spatial layer versus content-safe table/gallery/timeline/graph modes; visible-zone insets respond to live floating/Canvas chrome and torn-off footprints while Docked remains in-flow; optional dev zone overlay; deterministic tests, lint, native/root build/sign/launch | released 2026-07-21 — exact Character/Rig/Animate/Show/Hardware center catalogs are live; structured views use shell-owned visible-zone insets while spatial views remain full-bleed; torn-off panels contribute footprints; the UI setting exposes a live zone overlay; 348 XCTest + 27 Swift Testing tests, touched lint, native/root build, strict deep signing, and live launch PID 17397 pass; demo stayed read-only |

| Codex | Additively port Demo workspace tools, Design sandbox, and UI Kit gallery into production | additive production sources under `app/Sources/AnimaStudioUI/{AppShell,Workspaces}/**`, focused tests under `app/Tests/AnimaStudioUIUnitTests/**`, `dev/docs/reality/STATUS.md`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; `dev/AnimaStudio Demo/**` read-only reference | retain existing production components and real command wiring; add missing demo catalogs with unavailable tools visibly planned, a labelled Design sandbox, and a namespaced Demo UI Kit/gallery including every handoff widget family; lint/tests/native/root build/sign/launch pass | released 2026-07-21 — additive catalogs live across Character/Rig/Animate/Show/Hardware; production command collisions win; Design sandbox has six categories plus browser/inspector/typed placement; namespaced Demo UI Kit gallery covers the full requested component vocabulary; 344 XCTest + 27 Swift Testing tests, touched lint, native/root build, signing, and live process pass; demo stayed read-only |

| Codex | Port project-folder, Pack-and-Go import, reload, and reusable-assembly persistence | `app/Sources/AnimaDocument/**`, focused import/session integration under `app/Sources/AnimaStudioUI/{AppShell,Components,Workspaces/Assets}/**`, matching tests under `app/Tests/{AnimaDocumentTests,AnimaStudioUIUnitTests}/**`, `dev/docs/{roadmap/Project_Format.md,reality/STATUS.md}`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; `dev/AnimaStudio Demo/**` read-only reference | typed asset folders created/backfilled; import asks Copy(default) vs Reference and never moves; copied models persist/reload after autosave; first-class versioned `.animasm` documents save/list/import; lint/tests/native/root build/sign/launch pass | released 2026-07-21 |

| Codex | Faithfully port the Demo Home workspace and live footer into production | `app/Sources/AnimaStudioUI/AppShell/{StudioHomeView,AnimaStudioRootView,ProjectLifecycle,RecentProjects,StudioWorkspaceView,WorkspaceChrome}.swift`, `app/Sources/AnimaStudioUI/PreviewSupport/StudioPreviewCatalog.swift`, renderer metric hooks under `app/Sources/{AnimaCADViewport,RealityKitViewport}/**`, focused tests under `app/Tests/AnimaStudioUIUnitTests/AppShell/**`, `dev/docs/reality/STATUS.md`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; `dev/AnimaStudio Demo/**` read-only reference | match `Home_And_Footer_Handoff.md`: merged three-column Home with Home-only header, default-location New flow, disk-discovered recents and sample fallback, archetype routing, and a toggled 24-point footer wired to real workspace/selection/renderer/theme/OCCT values; tests/lint/native/root build/sign/launch pass | released 2026-07-21 — demo remained read-only; 332 XCTest + 27 Swift Testing tests, recursive lint, native/root build, deep sign, and fresh launch pass |

| Codex | Faithfully port the AnimaStudio Demo shell into the production app | production shell/header/tool/sidebar/tree sources under `app/Sources/AnimaStudioUI/{AppShell,Components/Tree,Workspaces}/**`, app lifecycle wiring under `app/App/**` only as required for window behavior, matching tests under `app/Tests/AnimaStudioUIUnitTests/**`, `dev/docs/reality/STATUS.md`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; `dev/AnimaStudio Demo/**` read-only reference | match `Shell_Port_Handoff.md`: demo-faithful layout math, breakpoints, float/dock/canvas scaffold, three tool densities/lifecycle, shared panel stacks/rails/tear-off, universal tree interactions, and responsive Home/header behavior while retaining production AnimaCore/AnimaDocument/workspace content; staged tests plus lint/native/root build/sign/launch pass | released 2026-07-20 — demo `4757cdc` remained read-only; responsive Home/document headers, exact shell geometry, toolbar primary/overflow/category model and immediate-action lifecycle landed; retained production stack/tear-off/tree engines; 328 XCTest + 27 Swift Testing tests, lint, native/root build, sign, live launch pass |

| Codex | Production widget audit and universal editable-tree operations | `app/Sources/AnimaStudioUI/Components/Tree/**`, `app/Sources/AnimaStudioUI/Components/{ProjectNavigatorView,PartTreeRow}.swift`, `app/Sources/AnimaStudioUI/Workspaces/Assets/**`, supporting app-side rig-edit methods under `app/Sources/{AnimaCoreClient,AnimaStudioUI/AppShell}/**`, focused tests under `app/Tests/**`, new widget inventory under `dev/docs/reality/**`, append-only coordination in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | inventory every production panel and classify it operational/read-only/unavailable; editable trees expose selection, filter, rename, folder/group, reorder/nest drag feedback, lock/state, delete, keyboard and context paths where their backing data supports it; fixed source/taxonomy trees state why they are read-only; sidebar tabs render their own working set instead of duplicate generic content; no enabled no-op production controls; deterministic tests/lint/build/sign/launch pass | released 2026-07-20 — shared bulk-removal contract; Instances folder/group/reorder/lock/bulk-delete; engine-backed mate/relation delete with dependent-reference cleanup; workspace-specific navigator tabs; enabled no-op audit; complete production panel matrix; 326 XCTest + 27 Swift Testing tests, lint, native/root build, deep sign, launch pass |

| Codex | Correct the Character top Tool sidebar and its three density presentations | `app/Sources/AnimaStudioUI/AppShell/WorkspaceShell.swift`, `app/Sources/AnimaStudioUI/Workspaces/WorkspaceRibbonCatalog.swift`, focused shell/catalog tests under `app/Tests/AnimaStudioUIUnitTests/**`, `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Expanded launches by default as a full-width, full-height icon-and-label ribbon; Standard is a centered medium capsule with primary tools and per-group overflow chevrons; Compact is a centered small category capsule whose anchored visual palettes contain every tool; content insets track toolbar height; Docked remains Expanded; focused lint/test/build/sign/launch pass | released 2026-07-20: Compact is 48-point category/palette geometry, Standard is 64-point primary-tool/overflow geometry, and Expanded is the full-width 88-point complete ribbon; Character terminology is consistent across all presentations; one shared state owner drives density and palette state; 325 XCTest tests and 26 Swift Testing tests pass |

| Codex | Simplify expanded tool presentation and clarify character asset-ingestion ownership | `app/Sources/AnimaStudioUI/AppShell/WorkspaceShell.swift`, focused shell/catalog tests under `app/Tests/AnimaStudioUIUnitTests/**`, `app/Sources/AnimaStudioUI/Components/ModelImportUnitsSheet.swift` only for truthful current storage copy, `dev/docs/{roadmap/Project_Format.md,reality/STATUS.md}`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Expanded renders all tool groups in one row when the workspace catalog is modest and introduces category tabs only above the documented high-tool-count threshold; Standard/Compact keep grouped menus; model import explicitly communicates non-destructive portable copy into the Character; docs distinguish Character-owned, Project-owned, and future externally linked media | released 2026-07-20: expanded uses one horizontally scrollable row through 24 tools and category tabs only above that threshold; Standard/Compact retain grouped menus; CAD import truthfully describes portable non-destructive copy; project-format docs define Character/Project ownership and copy/link/move policy; focused lint, 322 XCTest tests, 26 Swift Testing tests, native/root builds, and strict deep signing pass |

| Codex | Integrate Codex Bench STEP/OCCT geometry and retained render pipelines into production | `app/Package.swift`, `app/project.yml`, new production CAD geometry/render targets under `app/Sources/**`, import/settings/viewport integration under `app/Sources/{AnimaStudioUI,RealityKitViewport}/**`, matching tests under `app/Tests/**`, `app/Scripts/**`, `app/App/**` only where packaging/resources require it, `dev/docs/{roadmap,reality}/**`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; `dev/Codex Bench/**` read-only reference | STEP/STP is first-class and preferred; one crash-guarded Open CASCADE/XDE import preserves assembly hierarchy, colors, faces, and edges; retained MetalKit, RealityKit, Three.js WebGPU, and raw WebGPU backends consume the shared geometry contract; renderer/theme/material/edge/lighting/quality/telemetry settings are production preferences; app packaging carries required runtime resources/dependencies; focused tests plus Swift lint/test, native/root build/sign/launch, representative STEP walk-through, and diff check pass | released 2026-07-20: implementation and synthetic/malformed STEP verification pass; the user corpus is absent from the current working tree, so a representative real-file walkthrough remains operator verification |

| Codex | Align and finish the production workspace shell against the Demo standard | `app/Sources/AnimaStudioUI/AppShell/{WorkspaceChrome,WorkspaceLayout,WorkspaceShell,StudioWorkspaceModel,StudioWorkspaceView}.swift`, live workspace ribbon/catalog files under `app/Sources/AnimaStudioUI/Workspaces/**`, `app/Sources/AnimaStudioUI/Settings/**`, focused shell/presentation tests under `app/Tests/AnimaStudioUIUnitTests/**`, `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | remove the zero-reference legacy ribbon views; Docked uses full-height fixed-width side panels around a center column with its tool bar at top; shared panel stacks support multiple open panels, deterministic reorder, tear-off/clamped floating/re-dock, unselected defaults, independently centered rails, and optional outer-edge placement; quality cleanup leaves typed rig commands, one viewport display owner, and one shared rail implementation; deterministic tests/lint/build/launch and diff check pass | released 2026-07-20 |

| Codex | Protect Animate and Show timelines from floating/Canvas widgets | `app/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, shared timeline surface under `app/Sources/AnimaStudioUI/Workspaces/{Animate,Show}/**`, focused tests under `app/Tests/AnimaStudioUIUnitTests/{AppShell,Workspaces/Animate}/**`, `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Animate and Show timelines remain center/bottom editors; Docked stays full-width in-flow; Floating/Canvas use bounded rounded timeline windows; hidden Canvas panels preserve broad width; revealed side panels animate the timeline inside safe left/right boundaries without shrinking the 3D center; lint/tests/native/root build/sign/launch/diff check pass | released: shared protected timeline surface covers Animate + Show; safe left/right Canvas reveal reflow; top tools do not shrink the bottom editor; 311 XCTest + 22 bridge/integration tests, recursive lint, native/root build, helper embed, deep sign, launch pass |

| Codex | Make the Character collection center a protected content-sized floating document | `app/Sources/AnimaStudioUI/AppShell/{WorkspaceShell,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Workspaces/Assets/{AssetsWorkspaceView,AssetBuilderContentView,AssetBuilderInspector}.swift`, focused tests under `app/Tests/AnimaStudioUIUnitTests/{AppShell,Workspaces/Assets}/**`, `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Character keeps its table/grid as center content; Floating/Canvas present it as a rounded bounded window that grows from a minimum with content and never sits beneath open sidebars; Docked remains full-height in-flow; spatial 3D canvases remain full-bleed; floating side widgets are content-sized; tests/lint/native/root build/sign/launch/diff check pass | released: implemented shared safe-overlay insets, Canvas reveal reflow, 300–520-point Character collection sizing, and content-sized floating browser/inspector; 308 XCTest + 22 live bridge/integration tests, recursive lint, native/root build, helper embed, and deep signing pass |

| Codex | Implement the shared three-sidebar workspace-shell standard in production | `app/Sources/AnimaStudioUI/AppShell/{WorkspaceLayout,WorkspaceShell,StudioWorkspaceModel,StudioWorkspaceView,WorkspaceChrome}.swift`, focused Assets integration under `app/Sources/AnimaStudioUI/Workspaces/Assets/**`, `app/Sources/RealityKitViewport/RobotPreviewView.swift` only for the shared canvas-commit hook, focused tests under `app/Tests/{AnimaStudioUIUnitTests,RealityKitViewportTests}/**`, `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | every authoring workspace uses one shared center/top-tool/left-workspace/right-view scaffold; global Floating/Docked/Canvas state, identical rail toggle rule, canvas edge reveal without flicker, docked expanded tools, shared density/category/tool state, tool-camera exclusivity, prompt/commit/cancel lifecycle, state survives mode/workspace switches; lint/tests/native/root build/sign/launch/diff check pass | released 2026-07-20 (304 XCTest + 22 bridge/integration tests; recursive lint; native/root build; deep sign; live app + bundled bridge) |

| Codex | Audit and complete production parity before deleting archived CodexUI | `app/Sources/AnimaStudioUI/**`, `app/Tests/AnimaStudioUIUnitTests/**`, `dev/archive/CodexUI/**` read-only until deletion is proven safe, app/CodexUI paragraphs in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | every archived workspace/component/setting/interaction/specimen has a documented production equivalent or an explicit intentional exclusion; missing useful UI is migrated through shared production components and UI Dev coverage; full Swift lint/tests, native build, root rebuild/sign/launch, and diff check pass before archive is labeled safe to delete | paused 2026-07-21 while the bounded project-persistence claim owns overlapping app files |

| Codex | Separate reusable Characters from pinned project snapshots | `app/Sources/AnimaDocument/**`, `app/Tests/AnimaDocumentTests/**`, Assets UI additions within the existing active UI claim, `dev/docs/roadmap/Project_Format.md`, app/project paragraphs in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | reusable Character Library packages live outside projects; adding one creates a self-contained pinned project snapshot with source ID/revision metadata; project-local Characters remain supported; Assets distinguishes both scopes; canonical `.character.anima` content remains engine-owned; tests/lint/build/sign/launch and diff check pass | released 2026-07-20 — user-level library packages + stable UUID/revision; project-local vs pinned-snapshot provenance; Assets Publish/Add flow; old v2 manifest compatibility; 292 XCTest + 22 bridge tests, lint, native/root build, deep sign, launch, diff check pass |

| Codex | Migrate CodexUI's approved visual system into the real Anima Studio app, then archive the prototype | `app/Sources/AnimaStudioUI/**`, `app/Tests/AnimaStudioUIUnitTests/**`, app lifecycle/settings files only if required, `dev/CodexUI/**` only after main-app acceptance, app/CodexUI paragraphs in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | production app preserves existing AnimaCore/project/import/viewport behavior while adopting CodexUI shared themes, header/workspace navigation, dock/float/canvas layout, ribbon, panel/widget language, and UI Dev coverage; Swift lint/tests + native Xcode build + root app rebuild/sign/launch pass before CodexUI is archived; `git diff --check` passes | released 2026-07-19 — production shell migrated; 34-specimen UI Dev catalog; 284 Swift + 22 bridge tests, lint, native build, root helper embed/deep sign/launch, and diff check pass; prototype retained under `dev/archive/CodexUI/` |

| Codex | Close the CodexUI visual-system gap with AnimaStudio Demo | `dev/CodexUI/**`, read-only reference `dev/AnimaStudio Demo/Sources/AnimaStudioDemo/{Theme,Design,Widgets,PanelWidgets,ToolRibbon,App}.swift`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | shared CodexUI theme surfaces/text/strokes/semantic colors match the Demo's restrained palette; Demo accent families and light/dark options are available; panels/rows/fields/badges/metrics/buttons adopt the cleaner hierarchy and spacing universally through shared components; all workspaces/UI Kit update without copied per-screen styling; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — Demo surface/text/stroke/semantic palette plus blue/teal/indigo/orange/graphite/CAD Light/Midnight themes; shared panels/rows/fields/pills/metrics/buttons and project chrome refined; icon-only Demo-style floating ribbon; 12 tests/lint/release/deep sign/launch pass |

| Codex | Remove generic chrome around the CodexUI node canvas | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Nodes workspace and UI Kit graph render as a full-bleed workspace surface without rounded mask or enclosing outline; node cards/status controls retain meaningful local boundaries; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — node-canvas rounded mask and outline removed from shared component; local node/control boundaries preserved; 12 tests/lint/release/deep sign/launch pass |

| Codex | Add the complete CodexUI node system to the UI Kit | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Nodes workspace and UI Kit share reusable node card, library, inspector, typed-port, connection/canvas, selection-state, and canvas-control components; UI Kit includes compact variants plus a full-width graph specimen; catalog/test coverage updated; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — actual shared node card/library/inspector/port/canvas components; input/logic/AI+media/hardware and normal/selected/warning variants; full graph specimen; 21/21 coverage; 12 tests/lint/release/deep sign/launch pass |

| Codex | Flatten CodexUI UI Kit specimens and selection-tools grouping | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | specimen scaffolding no longer draws an outer card around already-contained widgets; captions remain; selection rail + adaptive-keyframe actions remain grouped without a redundant enclosing panel; coverage/tests updated; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — outer specimen cards removed; rail + adaptive action panel preserved as one natural-size group without the Selection Tools wrapper; 16/16 coverage; 12 tests/lint/release/deep sign/launch pass |

| Codex | Rebuild CodexUI UI Kit as a flat living design-system gallery | `dev/CodexUI/**`, read-only reference `dev/AnimaStudio Demo/Sources/AnimaStudioDemo/Workspaces/UIKit.swift` and `Widgets.swift`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | UI Kit adopts Demo-style title/subtitle, named sections, adaptive specimen cards, consistent 16/28/30 spacing, bounded gallery width, and full-width timeline/viewport specimens; existing CodexUI/Spatial specimens preserved; layout/settings contract shown as specimens rather than sidebars; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — flat 1180pt gallery; named sections/adaptive specimen cards; full-width chrome/timelines/viewport/settings; visible 16/16 asset inventory + coverage rule/test; 12 tests/lint/release/deep sign/launch pass |

| Codex | Smooth and constrain CodexUI floating-widget dragging | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | floating widget drag uses direct animation-free state rather than GestureState/reclamp snap; actual widget frame + workspace size bound every live update inside the view; deterministic boundary tests; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — direct no-animation updates; solid drag surface; live actual-frame clamp at 8pt window margin; 11 tests/lint/release/deep sign/launch pass |

| Codex | Consolidate Codex Spatial widgets into CodexUI and retire the separate app | `dev/CodexUI/**`, delete `dev/Codex Spatial/**`, CodexUI/standalone-prototype paragraphs in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | UI Kit includes selection rail + adaptive keyframe actions, hierarchy/mate/hardware stack, and full-width live-follow timeline; standalone Codex Spatial source/app removed only after migration; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — three Spatial specimen families migrated into UI Kit; standalone source/app removed; 10 tests/lint/release/deep sign/launch pass |

| Codex | Restore CodexUI floating 3D preview height | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Assets Preview floating widget has an explicit reusable spatial-preview minimum content height; compact property widgets remain content-sized; docked/floating layouts remain bounded; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — reusable 220pt spatial-preview content minimum applied to Assets Preview only; 10 tests/lint/release/deep sign/launch pass |

| Codex | Move CodexUI layout-mode control beside Help | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | layout-mode control moves from left commands to far right beside walkthrough Help; icon-only state uses distinct icon/tint for Floating/Docked/Canvas/Custom; cycle and dropdown behavior survive; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — icon-only cyan/purple/orange/green mode button moved beside Help; cycle/menu preserved; 10 tests/lint/release/deep sign/launch pass |

| Codex | Match CodexUI header density to AnimaStudio Demo | `dev/CodexUI/**`, read-only reference `dev/AnimaStudio Demo/Sources/AnimaStudioDemo/App.swift`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | single header adopts the Demo's 54pt row, 24pt controls, compact centered stage chips, and small Live + Preview widgets; all existing project/file/layout/settings/home/undo/redo/help icons remain; Master Live remains accessible; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — 54pt header/24pt controls/28–30pt centered tabs; compact Live status + Preview playback; Master Live retained in status/Settings; 10 tests/lint/release/deep sign/launch pass |

| Codex | Centralize CodexUI panel placement and add Canvas edge reveal | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Browser/Inspector wrapper headers and placement controls are removed; top layout menu and Settings are placement authorities; floating cards size to content; right context widgets drag independently; Canvas temporarily reveals hidden panels on edge hover without changing saved layout; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — wrapper headers/icons removed; content-sized floating cards; independent right-widget dragging with dock reset; transient Canvas edge reveal; 9 tests/lint/release/deep sign/launch pass |

| Codex | Add a reusable CodexUI viewport performance HUD | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | main Rig/Animate/Show render views can show a compact bottom-right telemetry overlay inspired by Codex Bench; operator can toggle it in Settings; prototype values are explicitly identified as preview data; existing viewport controls remain readable; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — shared bottom-right HUD; gauge + Settings toggle; explicit Sample/pending-hook copy; 8 tests/lint/release/deep sign/launch pass |

| Codex | Make CodexUI timelines full-width and floating side panels compact | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Animate and Show timelines use the same full center width as their viewport while retaining bottom-ribbon clearance; floating Browser/Inspector panels cap their height with visible canvas below; docked panels remain full-height columns; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — full-width Animate/Show timelines; responsive 72% floating side-panel height; docked full-height retained; 8 tests/lint/release/deep sign/launch pass |

| Codex | Simplify and edge-orient the CodexUI floating tool ribbon | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | floating ribbon removes redundant workspace label and persistent boxes around groups/tools; operator can float at top or bottom; popovers open inward (below top / above bottom); structured safe areas and walkthrough account for edge; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — unboxed quiet palette; duplicate workspace name removed; top/bottom setting and inward popovers; edge-aware shadow/safe areas/tour; 7 tests/lint/release/deep sign/live process pass |

| Codex | Rename CodexUI layout states to explicit panel modes | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | header layout button and Settings/menu say Floating, Docked, Canvas, or Custom instead of ambiguous Studio/Classic text; underlying three-state behavior and cycling remain unchanged; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — explicit Floating/Docked/Canvas/Custom labels in header/menu/Settings; 7 tests/lint/release/deep sign/live process pass |

| Codex | Restore CodexUI project identity as the first top-row element | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | far-left header starts with orange cube + Atlas Animatronic + SAVED at every width; mode name remains in centered selected workspace tab; layout/settings follow project identity; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — exact far-left orange cube/name/SAVED hierarchy restored at all widths; centered tab owns mode; 7 tests/lint/release/deep sign/live process pass |

| Codex | Transfer Codex Spatial's separated floating-widget language into CodexUI | `dev/CodexUI/**`, read-only reference `dev/Codex Spatial/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | floating Browser/Inspector remove the shared full-height slab; placement controls become a small elevated bar; each contained panel becomes an independently rounded/material/shadowed widget with visible canvas gaps; docked presentation remains continuous and compact; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — Spatial GlassPanel pattern transferred; separate floating control bar/cards/material/shadows; docked slab unchanged; 7 tests/lint/release/deep sign/live process pass |

| Codex | Rebalance CodexUI header identity and controls | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | upper-left shows current workspace instead of CodexUI brand; Studio/layout and Settings controls move left; runtime/live/help remain right; small CodexUI identity moves to footer; centered tabs and all functions remain; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — current workspace identity left; labeled layout + Settings left; runtime/live/help right; quiet CodexUI footer brand; 7 tests/lint/release/deep sign/live process pass |

| Codex | Remove card chrome around CodexUI 3D viewports | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Rig/Animate/Show 3D surfaces render edge-to-edge without rounded clipping, outline, or generic center gutter; floating controls/panels retain their own boundaries; structured timelines/tables keep deliberate spacing; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — border/mask removed from shared viewport; zero-inset spatial centers; timelines retain spacing; 7 tests/lint/release/deep sign/live process pass |

| Codex | Make the CodexUI walkthrough a non-layout floating overlay | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | tour card floats bottom-center above the status bar, never shifts header/ribbon/workspace geometry, retains navigation/dismiss/settings, and uses clear in-window popup chrome; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — bottom-center overlay above status; material popup chrome; no layout participation; 7 tests/lint/release/deep sign/live process pass |

| Codex | Restore configurable text labels to the centered CodexUI workspace tabs | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | default Automatic shows all labels with room and selected-only text in compact chrome; Settings offers Automatic/All/Selected Only/Icons Only; all seven tabs remain accessible; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — Automatic restores selected text in compact mode and all text at width; four Settings choices; 7 tests/lint/release/deep sign/live process pass |

| Codex | Make the centered CodexUI tabs the single workspace navigator | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | remove the redundant header workspace dropdown; list all seven workspaces in the centered capsule; preserve compact/no-overlap behavior, workspace grouping semantics, hover/accessibility, tests/lint/release/sign/launch, and `git diff --check` | released 2026-07-19 — duplicate dropdown removed; all 7 workspaces centered with authoring/utility divider and compact icon mode; 6 tests/lint/release/deep sign/live process pass |

| Codex | Add content-aware floating-panel safe areas to CodexUI | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | spatial canvases remain full-bleed behind floating chrome; structured tables, timelines, dashboards, and UI-kit boards inset to the visible unobstructed area; the policy is explicit/reusable and covered by tests; lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — reusable obstruction-inset environment; full-bleed Rig/Nodes and preview canvases; protected tables/timelines/dashboards; 6 tests/lint/release/deep sign/live process pass |

| Codex | Restore true floating panels and consolidate CodexUI layout controls | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | docked panels consume layout width while floating panels overlay a full-size center and hidden panels restore from the edge; sidebar/ribbon chrome owns its own dock-float-hide controls; three redundant header toggles become one combined layout control whose primary click cycles presets and dropdown exposes all states; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — true canvas-overlay float behavior; local multistate controls; one preset-cycling header menu; 5 tests/lint/release/deep sign/live process pass |

| Codex | Condense CodexUI's two chrome rows into one centered-stage header | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | one fixed header keeps the five-stage capsule absolutely centered; project/file/workspace access is grouped left; status/live/panel/settings access is grouped right; theme/layout choices move to the existing Settings window; Nodes/UI Kit remain reachable; compact widths do not overlap; no presentation functionality is lost; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — one 62pt header; centered five-stage capsule; grouped file/workspace and status controls; Settings retains theme/layout; compact chrome; 5 tests/lint/release/deep sign/live process/diff check pass |

| Codex | Import the AnimaStudio Demo workspace-stage tabs into CodexUI | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | replace the crowded scrolling workspace row with the Demo's centered capsule stage navigation; preserve all seven CodexUI workspaces, distinguish the five authoring stages from Nodes/UI Kit utilities, adapt labels at compact widths without overlap, and animate/hover/accessibility states consistently with the refined chrome; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — exact five-stage pill hierarchy from reference; utilities remain in grouped dropdown; compact icon-only fallback; 5 tests/lint/release/deep sign/live process/diff check pass |

| Codex | CodexUI readability, safe-layout, and interaction refinement | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | floating ribbon/panels reserve readable workspace space instead of covering tables, controls, or the walkthrough; icon/button contrast is consistent in all three themes; rows, workspace changes, panel placement, and tool interactions have restrained hover/press/spring feedback; all seven workspaces remain presentation-only; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — safe panel/ribbon lanes; in-flow walkthrough; theme-correct system scheme and higher-contrast chrome; hover/press/spring feedback; 4 tests/lint/release/deep sign/live process/diff check pass |

| Codex | Rebuild CodexUI around the AnimaStudio Demo modular panel language | `dev/CodexUI/**`, CodexUI paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | retain the isolated seven-workspace presentation prototype while replacing repeated fixed columns with one shared canvas-first layout; left/right regions and the top tool ribbon independently dock, float inside the window, or hide; layout controls and presets behave consistently in every workspace; styling follows the restrained AnimaStudio Demo chrome without importing its engine/renderer code; tests/lint/release/sign/launch and `git diff --check` pass | released 2026-07-19 — seven workspaces share dock/float/hide side regions and ribbon; three layout presets + native Settings; 4 tests/lint/release/deep sign/live process/diff check pass |

| Codex | Raw WebGPU browser-pipeline benchmark | `dev/Codex Bench/{Resources/RawWebGPU/**,Sources/GeomBenchCore/Pipeline.swift,Sources/GeomBenchApp/{RawWebGPUBenchView,BenchSession,BenchSettingsView,GeomBenchWorkspace,PipelineBenchmark}.swift,scripts/make-app.sh,Tests/**,README.md,Reports/**}`, Codex Bench paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries | add direct navigator.gpu/WGSL rendering over the shared Open CASCADE geometry; retain P5 during measurement; compare P5 raw WebGL 2, raw WebGPU, and P7 Three.js WebGPU on the 46-file workload before deciding whether WebGL 2 can retire | released 2026-07-19 — P10 raw WebGPU passes full assembly; P5 removed from active app; 16 tests/lint/release/sign pass |

| Codex | Production-shape optimization pass for retained Codex Bench pipelines | `dev/Codex Bench/{Sources/**,Tests/**,Resources/**,README.md}`, focused benchmark report/scripts if generated, Codex Bench paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | preserved all four retained IDs and assigned production/secondary/optional/baseline roles; P1 uses one retained assembly LowLevelMesh instead of per-face entities; P2 uses packed GPU-private geometry, topology IDs, triple-buffered uniforms, and a stable rigid-part transform table; P5/P7 share a compact binary payload and P7 uses indexed/grouped Three.js geometry; benchmark metadata exposes role/readiness/caveats | released 2026-07-19 — 16 tests, recursive lint, signed release/deep-sign, headless 46-file probe, and all four signed-app assembly benchmarks pass |
| Codex | Three.js WebGPU-first retained-pipeline experiment | `dev/Codex Bench/{web/threejs/**,Resources/ThreeJSWeb/**,Sources/GeomBenchCore/Pipeline.swift,Sources/GeomBenchApp/{ThreeJSBenchView,BenchSettingsView,GeomBenchWorkspace,PipelineBenchmark}.swift,Tests/**,README.md,Reports/**}`, Codex Bench paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries | keep raw WebGL P5 as the diagnostic control; migrate historical P7 to Three.js WebGPURenderer with runtime WebGPU detection and truthful WebGL 2 fallback; expose the actual backend in UI/benchmark JSON; prove the signed WKWebView route with the 46-file workload | released 2026-07-19 — P7 selected native WebGPU in the signed app; 16 tests/lint/release/sign/full-assembly benchmark pass |

| Agent | Task | Claimed files | Acceptance | State |
|---|---|---|---|---|
| Codex | Make browser-pipeline benchmark FPS count delivered WebKit frames | `dev/Codex Bench/Sources/GeomBenchApp/{WebGLBenchView,ThreeJSBenchView}.swift` | each scripted benchmark orbit completes on the browser's next `requestAnimationFrame` and increments the shared frame counter only after delivery; P5/P7 assembly reruns report nonzero comparable effective FPS | released 2026-07-19 (macOS throttled WebKit display callbacks in automated launches; attempted callback instrumentation was reverted and the report marks FPS unavailable rather than publishing zero as performance) |
| Codex | Add a headless combined-assembly probe for benchmark diagnosis | `dev/Codex Bench/Sources/GeomBenchProbe/main.swift` | one invocation accepts multiple STEP paths, merges the imported documents through the same production merge helper, and prints source/face/edge/triangle totals without a GUI dependency | released 2026-07-19 (46 sources merged: 46 nodes, 8,931 faces, 24,778 edges, 247,030 triangles; 6.83 s Open CASCADE import/merge) |
| Codex | Benchmark all CAD DEMO parts as one combined assembly across the four retained renderers | `dev/Codex Bench/{Sources/GeomBenchCore/GeometryDocument.swift,Sources/GeomBenchApp/{BenchSession,PipelineBenchmark}.swift,Tests/GeomBenchCoreTests/{GeometryAssemblyTests,PipelineBenchmarkTests}.swift,scripts/run-assembly-benchmark.sh,Reports/2026-07-19-assembly-benchmark/**,README.md}`, Codex Bench truth paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | repeated `--file` inputs plus `--merge-files` load serially and become one renderer document without ID/node collisions; benchmark JSON records all sources and combined geometry; all 46 CAD DEMO STEP files run through P1/P2/P5/P7 under the same orbit workload; report compares ready time/FPS/CPU/memory with WebKit accounting caveat; tests/lint/release/deep-sign and `git diff --check` pass | released 2026-07-19 (P2 6.94 s ready/59.84 visible FPS/20.34% CPU; P1 never ready after 4m55s at ~676–719 MiB; P5/P7 accepted all geometry but automated browser FPS was honestly withheld; 13 tests/lint/release/deep sign pass) |
| Codex | Prune Codex Bench to four kept pipelines and replace OpenGeometry with direct Three.js | `dev/Codex Bench/{Package.swift,README.md,Sources/{GeomBenchCore/{Pipeline,CameraState}.swift,GeomBenchApp/{OpenGeometryBenchView,ThreeJSBenchView,GeomBenchWorkspace,BenchSession,BenchSettingsView,PipelineBenchmark,OcctNativeGLView}.swift,GeomBenchApp/Renderers/{ClaudeFeatureRealityKitRenderer,GeminiSceneKitRenderer}.swift,OcctGLBridge/**},Sources/GeomBenchApp/Renderers/README.md,Tests/GeomBenchCoreTests/{GeomBenchCoreTests,PipelineBenchmarkTests,BenchSettingsTests}.swift,scripts/{build,build-opengeometry,build-threejs,make-app,run-kept-pipelines}.sh,web/{opengeometry,threejs}/**,Resources/{OpenGeometryWeb,ThreeJSWeb}/**,Reports/2026-07-19-kept-pipelines/**}`, Codex Bench truth paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | picker/signed app contains only P1 RealityKit, P2 MetalKit, P5 raw WebGL 2, and P7 direct Three.js/WebGL 2; P3 native OpenGL, P8 per-feature RealityKit, P9 SceneKit, OpenGeometry/WASM, Model I/O, Qt, Unity, and MetalANGLE are absent; P5/P7 use the same Open CASCADE STEP document for fair low/high-level browser comparison; historical report retained; retired preferences fall back; normalized four-pipeline performance report generated; tests/lint/release/deep-sign/live P1/P2/P5/P7 and `git diff --check` pass | released 2026-07-19 |
| Codex | Remove Qt pipelines from the Apple Codex Bench product | `dev/Codex Bench/{Package.swift,README.md,Sources/GeomBenchCore/Pipeline.swift,Sources/GeomBenchApp/{BenchSession,GeomBenchWorkspace,BenchSettingsView,PipelineBenchmark}.swift,Sources/GeomBenchApp/Renderers/README.md,Tests/GeomBenchCoreTests/{GeomBenchCoreTests,PipelineBenchmarkTests,BenchSettingsTests}.swift,scripts/{build,build-qt,make-app}.sh}`, Codex Bench truth paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | P4/P6 absent from catalog, Settings, runtime, benchmark and signed Apple bundle; stale persisted P4/P6 preferences safely fall back; no HostedSurfaceBridge dependency in the Apple target; packaging deletes stale Qt helpers; `qt/` source remains explicitly archived for a future separate cross-platform Qt product and is not advertised as current; tests/lint/release/deep-sign/live remaining catalog and `git diff --check` pass | released 2026-07-19 |
| Codex | Measure and rank every Codex Bench rendering pipeline | `dev/Codex Bench/{README.md,scripts/make-app.sh,Sources/{GeomBenchApp/{BenchSession,Telemetry,GeomBenchApp,GeomBenchWorkspace,PipelineBenchmark,RealityKitBenchView,MetalBenchView,OcctNativeGLView,WebGLBenchView,OpenGeometryBenchView,HostedRendererClient}.swift,OcctGLBridge/**},qt/Pipeline{4,6}/main.mm}`, focused benchmark tests under `dev/Codex Bench/Tests/**`, generated benchmark reports under `dev/Codex Bench/Reports/**`, Codex Bench truth paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | same representative medium/heavy STEP files run through all nine pipelines under one timed orbit workload; report separates kernel/upload/load, main/helper memory, CPU and rendered FPS; failures/timeouts remain explicit; weighted conclusion names best production direction and worst/retire candidates without treating on-demand idle redraw as zero-performance; tests/lint/release/deep-sign/live suite and `git diff --check` pass | released 2026-07-19 (one normalized runner; medium pass + three heavy launches per pipeline; P6 startup race and P3 deferred timing repaired; P2 Metal wins at 60.0 FPS/19.7% CPU; report + raw JSON retained; 12 tests, clean lint, Swift/Qt release, deep sign, diff check) |
| Codex | Guard Codex Bench STEP import and exercise the CAD DEMO corpus | `dev/Codex Bench/Sources/{GeomShim/GeomShim.cpp,GeomBenchApp/BenchSession.swift}`, focused importer/probe tests and scripts under `dev/Codex Bench/{Tests,scripts}/**`, Codex Bench truth paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Open CASCADE signal/`Standard_Failure` exceptions cannot cross the C shim; malformed STEP returns a readable load error instead of aborting; multi-file workspace import serializes XCAF work and accepts repeated `--file` launch arguments; every `CAD DEMO/**/*.step` is exercised in an isolated corpus run with per-file metrics/results; tests/lint/release/deep-sign and `git diff --check` pass | released 2026-07-18 (guarded read/transfer/mesh C boundary; serialized XCAF actor; safe multi-file and repeated-argument ingestion; CAD DEMO 46/46 pass, 32.7 ms median/499.1 ms p95/2,168.2 ms max; signed app healthy with all 46; 10 tests/lint/release/deep sign/diff check) |
| Codex | Move Codex Bench renderer/theme configuration into a professional Settings window | `dev/Codex Bench/Sources/GeomBenchApp/{GeomBenchApp,GeomBenchWorkspace,BenchSession,BenchTheme,BenchSettingsView}.swift`, focused settings/theme tests under `dev/Codex Bench/Tests/**`, Codex Bench truth paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | native Settings scene opens with Cmd-comma and toolbar action; renderer selection leaves main toolbar and clearly reports capability/process/framework; preset plus custom background/model/material/edge/selection/key-fill-rim controls share one live theme contract across pipelines; renderer and full custom theme persist; main toolbar shows compact active summary; tests/lint/release/deep-sign/launch/settings-window health and `git diff --check` pass | released 2026-07-18 (four-tab native Settings scene; nine-engine capability browser; full shared theme editing + reset; renderer/custom theme persistence; compact workspace summary; deterministic main-window launch and non-restored Settings; 9 tests, lint, release, deep sign, two-cycle Cmd-comma/quit/relaunch health, diff check) |
| Codex | Repair Codex Bench Pipeline 4 hosted Qt/Open CASCADE launch | `dev/Codex Bench/{qt/Pipeline4/main.mm,Sources/{OcctGLBridge/**,GeomBenchApp/{HostedRendererClient.swift,OcctNativeGLView.swift}}}`, focused hosted/native-light tests under `dev/Codex Bench/Tests/**`, Codex Bench truth paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | P4 helper does not abort when host sends its initial theme; theme lights update in place rather than illegally disabling OCCT global lights; native failures return protocol error text and host exit status includes stderr; stale P3 status cannot overwrite P4; real ARCADA STEP produces an IOSurface frame in signed app; tests/lint/Qt+Swift release/deep-sign/live health and `git diff --check` pass | released 2026-07-18 (removed illegal global-light reset in P4 and P3; P4 native exceptions now cross JSON; host exit includes stderr; stale P3 status guarded; stale pre-rename Qt CMake cache regenerated; 6 Swift tests, Qt/Swift release builds, deep sign, real-STEP protocol sequence, signed host/child live health, no new crash) |
| Codex | Repair Codex Bench Pipeline 3 native Open CASCADE viewer crash | `dev/Codex Bench/Sources/{OcctGLBridge/**,GeomBenchApp/{OcctNativeGLView.swift,BenchSession.swift},GeomBenchCore/Pipeline.swift}`, focused Pipeline 3 tests under `dev/Codex Bench/Tests/**`, Codex Bench truth paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | real ARCADA STEP opens in Pipeline 3 without uncaught OCCT exception; native view loads after window attachment and does not race the shared tessellation importer; survives theme/update/resize and pipeline teardown; errors cross as NSError instead of aborting; tests/lint/release/deep-sign/package launch and live P3 health pass; `git diff --check` clean | released 2026-07-18 (reproduced pre-fix `Standard_TypeMismatch`; native ingestion isolated + deferred; OCCT failures contained; explicit teardown; 6 tests/lint/debug/release/deep sign; signed P3 + ARCADA STEP healthy 40 seconds with no new crash) |
| Codex | Remove obsolete demo app bundles and stop duplicate benchmark launches | `dev/Codex Bench/{scripts/launch.sh,Resources/Info.plist}`, `dev/CodexUI/scripts/launch.sh`, standalone-prototype paragraphs in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md`; delete generated `.app` artifacts under obsolete Gemini/Claude/Shapr/Unified labs and stale duplicate `dev/Codex Bench/build/GeomBench.app` only | only the three intentional clickable apps remain (`Codex Bench`, `CodexUI`, `Codex Spatial`), source labs remain; the renamed benchmark has a unique bundle identity and launch scripts reuse an existing instance instead of `open -n`; Codex Bench tests/release/sign/open/process-health pass without a new crash report; `git diff --check` passes | released 2026-07-18 (six obsolete compiled app bundles removed; source labs preserved; old relocated Swift module cache removed; bundle ID corrected; 5 tests/release/deep sign; two launches reused one healthy process for 20 seconds; no new crash report) |
| Codex | Build a separate Shapr3D × Bottango spatial UI demo | new `dev/Codex Spatial/**`, standalone-prototype paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | separate clickable `Codex Spatial.app`, not a CodexUI concept or dependency; model-first canvas, floating side tools, adaptive selection actions, compact items manager, Bottango-style live state and bottom motion/audio timeline; no backend; tests/lint/release/deep-sign/launch and `git diff --check` pass | released 2026-07-18 (Build/Animate/Live; adaptive selection tools; items + inspector; 4-track keyframe/audio timeline; guarded live hardware presentation; 3 tests; lint/debug/release/deep sign/launch/process-health pass) |
| Codex | Build an isolated CodexUI CAD-animatronic interface walkthrough | new `dev/CodexUI/**`, standalone-prototype paragraph in `dev/docs/reality/STATUS.md`, append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | native clickable `CodexUI.app`; no AnimaCore/app imports; workspace-specific Assets/Rig/Animate/Show/Hardware/Nodes/UI Kit layouts, adaptive ribbon, CAD viewport/timeline/panels, themes and guided tour; tests/lint/release/deep-sign/launch and `git diff --check` pass | released 2026-07-18 (7 workspaces; adaptive ribbon; 3 themes; walkthrough; 3 tests; lint/debug/release/deep sign/launch/process-health pass; Codex Bench moved to `dev/Codex Bench/`) |
| Codex | Consolidate the useful Claude/Gemini CAD-bench capabilities into Codex Bench | isolated `dev/Codex Bench/**`, the standalone-CAD-benchmark paragraph in `dev/docs/reality/STATUS.md`, and append-only coordination entries in `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Codex Bench includes explicit Codex-vs-Claude RealityKit comparison variants, exact face/edge picking, the complete shared ten-theme catalog, honest/offline pipeline availability, and comparable renderer telemetry; operator STEP input, assembly truth, CAD navigation, Swift tests/lint/release build/deep sign/launch, and `git diff --check` pass | released 2026-07-18 (P8 Claude per-face/per-edge RealityKit + concurrent exact pick targets; P9 Gemini SceneKit; nine working routes; ten full themes; 5 tests; lint/release/deep sign; same real STEP live in P8/P9) |
| Codex | Replace the OpenGeometry placeholder with a Swift-embedded OpenGeometry WebAssembly + Three.js route | isolated `cad-test/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | OpenGeometry and Three.js assets are bundled locally; the route renders inside Swift WebKit; operator STEP is still parsed by Open CASCADE because OpenGeometry has export but no STEP import; the UI names that boundary honestly; CAD navigation/themes/telemetry and tests/build/sign/launch pass | released 2026-07-18 (P7 embedded in Swift; pinned OpenGeometry/Three.js bundle; npm audit clean; real STEP: WASM ready, 6 ms kernel probe, 2,480 triangles displayed in 8 ms; 3 Swift tests; release/sign pass) |
| Codex | Add STEP-fed Unity WebGL and Qt WebEngine/WebGL comparison routes | isolated `cad-test/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | no native-Unity embedding claim; existing Swift/WKWebView WebGL stays working; Unity WebGL consumes the same operator-selected Open CASCADE tessellation when a generated player is present and is honestly capability-gated otherwise; Qt 6 WebEngine hosts a real WebGL 2 renderer for that same STEP tessellation; navigation/themes/telemetry work; tests, Swift/Qt release/sign/launch, `git diff --check` | released 2026-07-18 (P6 hidden Qt WebEngine process embedded into Swift by IOSurface; real STEP load 2,480 triangles; 3 Swift tests; Swift/Qt release builds; deep sign; P7 source/host complete and honestly blocked only by inactive Unity license) |
| Codex | Make Codex Bench themes real renderer presets across every working STEP pipeline | isolated `cad-test/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | theme payload changes background, lighting, shading/finish, B-Rep edge presentation, and selection intent in RealityKit, raw Metal, WebGL, native Open CASCADE, and hosted Qt; XDE colors stay base truth; non-STEP/non-working catalog entries are removed per Jonathan; tests, lint, Swift/Qt release/sign/launch, `git diff --check` | released 2026-07-17 (five working STEP routes only; full theme mapped across all five; 3 tests; Swift/Qt debug + release builds; deep sign verified; fresh app launch running) |
| Codex | Repair P2 Metal theme color/contrast from Jonathan's screenshot | isolated `cad-test/Sources/GeomBenchApp/MetalBenchView.swift`, `cad-test/Tests/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Studio Blue background is charcoal rather than double-gamma gray; imported body colors remain recognizable with theme lighting/specular response; extracted B-Rep edges render crisply for CAD readability; tests, lint, release build/sign/live P2 launch, `git diff --check` | released 2026-07-17 (3 tests; lint; release; Qt repack; deep sign; corrected live P2 shader remained healthy) |
| Codex | Port the best Claude Bench render-theme ideas into Codex Bench | isolated `cad-test/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | one shared selectable theme contract defaults to Studio Blue and controls workspace/viewport background plus renderer-neutral material/light intent without replacing STEP/XDE face colors; native Swift renderers update live; unsupported external renderer differences stay explicit; tests, lint, release build/sign/launch, `git diff --check` | released 2026-07-17 (3 tests; recursive lint; Swift/Qt release; deep sign; live P1/P2 operator-model launches remained running) |
| Codex | Expand Codex Bench renderer/kernel comparison | isolated `cad-test/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | pipeline names spell out Open CASCADE Technology and Apple framework names; operator-selected STEP renders through a real WebGL 2 canvas inside Swift/WKWebView with CAD navigation and telemetry; OpenGeometry remains an honest upstream capability gate; MetalANGLE is removed; a real embedded Unity WebGL source project/host supports STL/OBJ and CAD navigation, with its generated player gated only by local Unity activation; tests, Swift release build/sign/launch, `git diff --check` | released 2026-07-17 (3 tests; lint; Swift debug/release; deep sign; P6 live 13,102-triangle WebGL upload; P8 launch state; Unity build reached editor and was blocked by missing local license) |
| Codex | Codex Bench operator-owned input cleanup | isolated `cad-test/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | app starts with an empty workspace; no kernel or generated OBJ fixture is loaded on launch/pipeline switch; P1–P6 wait for an operator-selected compatible file; developer geometry remains test-only; Swift tests, release build/sign/launch | released 2026-07-17 (3 tests; Swift/Qt release builds; deep sign; empty-start launch) |
| Codex | Assets Shift-range selection + reliable Delete key | `app/Sources/AnimaStudioUI/Workspaces/Assets/{AssetBuilderContentView,AssetsWorkspaceModels}.swift`, `app/Tests/AnimaStudioUIUnitTests/Workspaces/Assets/AssetsWorkspaceModelsTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | plain click establishes an anchor; Shift-click selects the inclusive visible range; Command-click toggles; Command-Shift adds a range; selecting a row gives the collection keyboard focus and Backspace/Delete reliably opens the same confirmation as the toolbar/context action; focused/full tests, lint, native/root build/sign/launch, `git diff --check` | released 2026-07-17 (12 focused; 282 XCTest + 22 Swift Testing; claimed-file lint; native/root build, deep sign, launch; recursive-lint warnings were isolated to Claude's transient probe, since removed) |
| Codex | Assets multi-select deletion + automatic part replacement | `app/Sources/AnimaCoreClient/AnimaCoreRigDocumentEditor.swift`, `app/Sources/AnimaDocument/AnimaDocumentStore.swift`, `app/Sources/RealityKitViewport/{PartModelSource,RobotPreviewView}.swift`, `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Workspaces/Assets/{AssetsWorkspaceView,AssetBuilderContentView,AssetBuilderInspector}.swift`, focused tests under `app/Tests/{AnimaCoreClientTests,AnimaDocumentTests,AnimaStudioUIUnitTests,RealityKitViewportTests}/**`, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | Parts table/grid supports standard Command/Shift multi-selection and synchronized preview highlighting; toolbar/context/Delete-key removal confirms and removes selected engine parts plus dependent mate/relation/clip/output references through engine validation, persists on Save, and prunes only orphaned project assets/editor metadata; importing the same original filename automatically replaces its existing embedded asset/part(s), increments V, and forces renderer refresh rather than creating a duplicate; focused/full tests, lint, native/root sign/launch, `git diff --check` | released 2026-07-16 (5 focused tests; 279 XCTest + 22 Swift Testing; claimed-file lint; native/root build, deep sign, launch; recursive-lint warnings isolated to Claude's preserved untracked probe) |
| Codex | Flatten the Asset Builder project tree | `app/Sources/AnimaStudioUI/Workspaces/Assets/{AssetBuilderSidebar,AssetsWorkspaceModels}.swift`, `app/Tests/AnimaStudioUIUnitTests/Workspaces/Assets/AssetsWorkspaceModelsTests.swift`, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | project name/revision appear once as a compact non-tree header; Characters and Parts Library are direct tree roots; character collections remain nested only beneath their character; shared `TreeView`, filtering, selection, and active-character expansion remain intact; focused/full tests, lint, native/root sign/launch, `git diff --check` | released 2026-07-16 (8 focused; 275 XCTest + 20 Swift Testing; recursive lint; native/root build, deep sign, launch) |
| Codex | Repair dead Assets import buttons with native macOS panels | `app/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, new focused import-panel helper under `app/Sources/AnimaStudioUI/Components/`, focused tests under `app/Tests/AnimaStudioUIUnitTests/Components/`, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | every live 3D Model/Import/drop-zone click opens one real multi-file NSOpenPanel; Anima Character opens its own single-file panel; cancel safely clears replace state; chosen files enter the existing unit/import pipeline; focused/full tests, lint, native/root sign/launch, `git diff --check` | released 2026-07-16 (2 focused; 275 XCTest + 20 Swift Testing; recursive lint; native/root build, deep sign, launch) |
| Codex | Enforce the current supported model-import contract | `app/Sources/AnimaStudioUI/{AppShell/{StudioWorkspaceView,WorkspaceChrome}.swift,Components/{ModelImportFormatSupport,ModelImportUnitsSheet,InspectorView}.swift,Workspaces/{Assets/AssetBuilderInspector,WorkspaceRibbonCatalog,UIDev/{UIDevTemplateMatrixView,UIDevVariantBoardSpecimenView}}.swift}`, focused import tests, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | picker and drag/drop accept only USD/USD[A/C]/USDZ, STL, and OBJ; Assets import panel states that exact set; STEP/STP/Reality/URDF/glTF are not advertised or admitted; unit prompt remains STL/OBJ-only; full tests/lint/native/root sign/launch and `git diff --check` | released 2026-07-16 (273 XCTest + 20 Swift Testing; recursive lint; native/root build, deep sign, launch) |
| Codex | Three-column Asset Builder workspace + consistent collection views | `app/Sources/AnimaStudioUI/Workspaces/Assets/**`, focused Assets tests, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | every center collection uses one Table/Grid presentation; Table is default; type-appropriate headers remain visible at zero rows; every empty body says `No <collection> yet` without duplicate actions; Parts behavior and right preview/import remain intact; full tests/lint/native/root sign/launch and `git diff --check` | released 2026-07-16 (272 XCTest + 20 Swift Testing; recursive lint; native/root build, deep sign, launch) |
| Codex | Sharp box proxies + contextual mate snap points + persistent fillet inspector | `app/Sources/RealityKitViewport/{PreviewPartAppearance,RobotPreviewView,MateConnectorMarkers}.swift`, `app/Sources/AnimaDocument/CharacterEditorMetadata.swift`, `app/Sources/AnimaStudioUI/{AppShell/StudioWorkspaceModel.swift,Components/{InspectorView,ComponentAppearanceEditor}.swift}`, focused tests under `app/Tests/{AnimaDocumentTests,RealityKitViewportTests,AnimaStudioUIUnitTests}/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | box proxies default to mathematically sharp edges; per-box fillet radius is an explicit mm Inspector value persisted in editor JSON; inferred face/edge/corner point markers are absent during normal selection and appear only during active mate-connector snapping; focused/full tests, lint, root-app build/sign/launch, `git diff --check` | released 2026-07-16 (267 XCTest + 20 Swift Testing; recursive lint; Xcode/root app build, deep sign, launch) |
| Codex | Live navigator drag/drop regression: insertion feedback + drop-to-group | `app/project.yml`, `app/Sources/AnimaStudioUI/Components/{NavigatorDropInteraction,ProjectNavigatorView}.swift`, `app/Sources/AnimaStudioUI/Components/Tree/TreeView.swift`, `app/AppUITests/AnimaStudioAppUITests.swift`, focused navigator tests under `app/Tests/AnimaStudioUIUnitTests/Components/**`, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | row-wide drag source/targets; visible animated before/after line and center + Create Group state; center drop creates and expands a real folder containing target plus dragged selection; a native UI test performs the drag in the app; full tests/lint/root build/sign/launch; `git diff --check` | implemented 2026-07-16; awaiting operator drag confirmation (263 XCTest + 20 Swift Testing green; root app built/signed; UI-test app association fixed, but macOS canceled UI automation authentication before gesture execution) |
| Codex | CAD viewport environment, display, section, and saved-view controls | `app/App/Shaders/ViewportSection.metal`, `app/Package.swift`, `app/project.yml`, `app/Sources/RealityKitViewport/{PreviewAppearance,PreviewCameraState,RobotPreviewView,ViewportLighting,ViewportPresentation,ViewportRenderStyle,ViewportSection}.swift`, `app/Sources/AnimaDocument/CharacterEditorMetadata.swift`, `app/Sources/AnimaStudioUI/{AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift,Components/{ViewportCameraHUD,ViewportEnvironmentSettingsView,ViewportRenderMenu}.swift,Settings/{AnimaStudioSettingsView,StudioPreferenceKeys}.swift}`, focused tests under `app/Tests/{AnimaDocumentTests,AnimaStudioUIUnitTests,RealityKitViewportTests}/**`, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | project-persistent preset/custom solid/gradient backgrounds and named views; adjustable generated studio IBL intensity/rotation; shaded, shaded-with-edges, wireframe, unshaded, and translucent modes; real fragment clip-plane section view with axis/position handle; previous-view navigation; real 4x-MSAA high-quality mode; no object-material editor changes or engine semantics; focused/full tests, recursive lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 (263 XCTest + 20 Swift Testing; recursive lint; native/root app + bundled Metal build; deep sign; RealityKit shader/material smoke; launch) |
| Codex | Removable + self-pruning Recent Projects | `app/Sources/AnimaStudioUI/{AppShell/{RecentProjects,StudioHomeView,AnimaStudioRootView,ProjectLifecycle}.swift,Components/RecentProjectCard.swift,PreviewSupport/StudioPreviewCatalog.swift}`, `app/Tests/AnimaStudioUIUnitTests/AppShell/RecentProjectsTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | hover x and context menu forget an entry immediately without filesystem deletion; load prunes entries whose bookmark/path no longer resolves to an existing project folder; open and pruning share one resolver; focused/full tests, lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 (7 focused; 257 XCTest + 20 Swift Testing; Xcode/root app build, deep sign, launch) |
| Codex | Imported-mesh topology hover/selection + tested CAD box selection | `app/Sources/RealityKitViewport/{ImportedMeshTopology,MeshFeatureOverlay,MateConnectorInference,RealityKitModelLoader,RobotPreviewView,SubObjectSelection}.swift`, `app/Tests/RealityKitViewportTests/**`, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | ModelIO-backed imported meshes are welded and cached into connected coplanar face groups, sharp/boundary edge polylines, and 3+-edge corners; real mesh face/edge/corner proxies feed the existing feature selection and mate-candidate contract with distinct hover/selected styling; empty click/Escape/component behavior stays staged; directional window/crossing selection remains blue-solid/yellow-dashed and is pure-tested; existing viewport-to-tree reveal is reused; focused/full tests, recursive lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 (255 XCTest + 20 Swift Testing; Xcode/root app build, deep sign, launch) |
| Codex | ViewCube projected face decals + real camera roll controls | `app/Sources/RealityKitViewport/{PreviewCameraState,RobotPreviewView}.swift`, `app/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `app/Sources/AnimaStudioUI/Components/{ViewCubeGeometry,ViewportViewCube,ViewportCameraHUD}.swift`, `app/Tests/{RealityKitViewportTests/PreviewCameraTests,AnimaStudioUIUnitTests/Components/ViewCubeGeometryTests}.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | labels are drawn as readable affine decals glued to projected face quads and hidden on slivers; existing 15-degree orbit arrows remain; head-on principal faces expose real clockwise/counterclockwise 90-degree camera roll; ViewCube and RealityKit share one direction+roll state; focused/full tests, recursive lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 (248 XCTest + 20 Swift Testing; Xcode/root app build, deep sign, launch) |
| Codex | First-run `~/Documents/AnimaStudio/` project-panel fix | `app/{project.yml,AnimaStudio.xcodeproj/project.pbxproj,App/AnimaStudio.entitlements}`, `app/Sources/AnimaStudioUI/{AppShell/{WorkspaceLocationPreference,ProjectLifecycle}.swift,Settings/AnimaStudioSettingsView.swift}`, `app/Tests/AnimaStudioUIUnitTests/AppShell/WorkspaceLocationPreferenceTests.swift`, `dev/docs/{reality/STATUS.md,roadmap/Project_Format.md}`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | default root is the no-space real-user `~/Documents/AnimaStudio/`, never the sandbox container; New/Open/Save As create that exact folder before configuring their panels and never silently walk up to Documents; a focused first-use user-selected grant is bookmarked because App Sandbox has no static Documents entitlement; custom bookmarked roots still resolve; focused/full tests, lint, root-app build/signature/launch, real first-run + relaunch walkthrough, `git diff --check` | released 2026-07-16 |
| Codex | Standard Settings scene + persistent workspace root | `app/{project.yml,App/{AnimaStudioApp.swift,AnimaStudio.entitlements}}`, `app/Sources/AnimaStudioUI/AppShell/{ProjectLifecycle,StudioHomeView,StudioWorkspaceView,WorkspaceLocationPreference}.swift`, `app/Sources/AnimaStudioUI/Settings/{AnimaStudioSettingsView,MouseNavigationSettingsView,StudioPreferenceKeys}.swift`, focused tests under `app/Tests/AnimaStudioUIUnitTests/{AppShell,Settings}/**`, `app/AppUITests/AnimaStudioAppUITests.swift`, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/{reality/STATUS.md,roadmap/Project_Format.md}`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | one resolved/bookmarked workspace root defaults to `~/Documents/Anima Studio`; New/Open/Save As use it and lazily create it; Settings scene opens through standard macOS command/menu and contains Workspace, Navigation, Appearance; old mouse sheet removed; root preference/bookmark tests, full tests/lint/Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 |
| Codex | Reusable navigator tree + persistent engine/editor object state | `app/Sources/AnimaCoreClient/{AnimaCoreBridgeModels,AnimaCoreRigDocumentEditor}.swift`, `app/Sources/AnimaDocument/CharacterEditorMetadata.swift`, `app/Sources/AnimaStudioUI/AppShell/{NavigatorOrganization,StudioWorkspaceModel,StudioWorkspaceView,ComponentContextActions}.swift`, `app/Sources/AnimaStudioUI/Components/{ProjectNavigatorView,PartTreeRow,NavigatorDropInteraction,ComponentAppearanceEditor,InspectorView}.swift`, new reusable tree files under `app/Sources/AnimaStudioUI/Components/Tree/**`, `app/Sources/RealityKitViewport/{PreviewPartAppearance,RobotPreviewView,CharacterSpaceTransform,EngineResolvedPose}.swift`, focused tests under `app/Tests/{AnimaCoreClientTests,AnimaDocumentTests,AnimaStudioUIUnitTests,RealityKitViewportTests}/**`, generated `app/AnimaStudio.xcodeproj/project.pbxproj` only if generation changes it, `dev/docs/{reality/STATUS.md,roadmap/{Studio_App,Coordinate_Frames}.md}`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | one generic `TreeView`/pure tree model renders Instances and Mate Features; reorder/move/group/filter/drop validation and viewport-to-tree reveal are tested; state badges and context commands work; position/rotation/suppress/ground edit the retained engine DTO and round-trip through serialize/load; material/visibility/locks/disclosure/groups persist in character editor JSON; World→Character→Part remains explicit; full tests/lint/Xcode/root-app build/signature/launch plus move/suppress/material Save+reopen walkthrough and `git diff --check` | released 2026-07-16 (Swift/UI scope complete; engine suppression/output crash recorded in Requests) |
| Codex | CAD mouse/navigation overhaul + reusable Mouse settings panel | `app/Sources/RealityKitViewport/{PreviewNavigationSettings,CADNavigationCapture,RobotPreviewView,SubObjectSelection}.swift`, `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Components/{ViewportCameraHUD,ViewportCameraControls,ViewportRenderMenu,ComponentViewportContextMenu}.swift`, new focused settings views under `app/Sources/AnimaStudioUI/Settings/**`, focused tests under `app/Tests/{RealityKitViewportTests,AnimaStudioUIUnitTests}/**`, generated `app/AnimaStudio.xcodeproj/project.pbxproj` only if generation changes it, `dev/docs/{reality/STATUS.md,roadmap/Studio_App.md}`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | Default/SolidWorks/Onshape/Fusion/Custom mappings match the approved CAD table; Option bindings, click-vs-drag right routing, normalized reversible zoom, precise zoom and middle-double-click frame; reliable selection/empty clear with selection feedback; compact reusable settings window with profile summaries, mouse-button diagram, manual bindings, sensitivity and reverse-wheel persistence; mapping/classifier/UI tests, recursive lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 |
| Codex | Assets character manager + 3D assembly loading stage | `app/Sources/AnimaCoreClient/AnimaCoreRigDocumentEditor.swift`, `app/Sources/AnimaDocument/{AnimaStudioDocument,ProjectCharacterNaming}.swift`, `app/Sources/RealityKitViewport/ModelHierarchy.swift`, `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Components/ModelImportUnitsSheet.swift`, new `app/Sources/AnimaStudioUI/Workspaces/Assets/**`, focused tests under `app/Tests/{AnimaCoreClientTests,AnimaDocumentTests,RealityKitViewportTests,AnimaStudioUIUnitTests}/**`, generated `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | Assets lists indexed characters and selects the active Rig/Animate character; validated 3D-only New Character sheet with disabled honest 2D option; engine-serialized empty character folder; async batch STL/OBJ/USD import with explicit unit preparation, progress, multi-node USD mapping, inline failures, and transition to Rig; focused/full tests, recursive lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 |
| Codex | Portable rigid-part model import (STL/OBJ/USD + honest STEP) | `app/Package.swift`, `app/AnimaStudio.xcodeproj/project.pbxproj`, `app/Sources/AnimaCoreClient/{AnimaCoreBridgeModels,AnimaCoreRigDocumentEditor}.swift`, `app/Sources/AnimaDocument/{AnimaDocumentStore,CharacterEditorMetadata}.swift`, `app/Sources/RealityKitViewport/{ModelHierarchy,PartModelSource,RealityKitModelLoader,RobotPreviewView}.swift`, `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Components/{InspectorView,ModelImportUnitsSheet}.swift`, `app/Sources/AnimaStudioUI/Workspaces/WorkspaceRibbonCatalog.swift`, focused tests under `app/Tests/{AnimaCoreClientTests,AnimaDocumentTests,RealityKitViewportTests,AnimaStudioUIUnitTests}/**`, `dev/docs/{reality/STATUS.md,roadmap/{Project_Format,Hardware_Animation_Milestone}.md}`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | picker supports STL/OBJ/USD family; STEP presents conversion guidance; STL/OBJ units are explicit and persisted; ModelIO meshes render in RealityKit; imports copy beneath the active character; rig DTO receives safe relative `model` plus optional `model_node` and is engine-validated/reloaded; per-part meshes inherit `resolve_pose`; save/reopen integration; tests/lint/Xcode/root-app build/signature/launch; `git diff --check` | released 2026-07-16 |
| Codex | Engine-canonical project lifecycle (New/Open/Save/Save As/Recents) | `app/Package.swift`, `app/project.yml`, `app/AnimaStudio.xcodeproj/project.pbxproj`, `app/Sources/AnimaCoreClient/**`, `app/Sources/AnimaDocument/**`, `app/Sources/AnimaStudioUI/AppShell/{AnimaStudioRootView,StudioHomeView,StudioWorkspaceModel,StudioWorkspaceView,WorkspaceChrome,RecentProjects,ProjectLifecycle}.swift`, `app/Sources/AnimaStudioUI/Components/RecentProjectCard.swift`, focused tests under `app/Tests/{AnimaCoreClientTests,AnimaDocumentTests,AnimaStudioUIUnitTests}/**`, `dev/docs/{reality/STATUS.md,roadmap/Project_Format.md}`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | plain-folder project layout; native New/Open/Save As dialogs; engine-only character serialization; atomic Save; real bookmark-backed recents; reopen through `load_character`; no Swift YAML semantics; focused/full tests, recursive lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 |
| Codex | Engine-driven Relations palette, navigator, inspector, and draft dialog | `app/Sources/AnimaCoreClient/{AnimaCoreBridgeModels,AnimaCoreClient}.swift`, `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Components/{ProjectNavigatorView,InspectorView}.swift`, `app/Sources/AnimaStudioUI/Workspaces/Rig/{CreationPaletteView,EngineRelationInspectorView,RelationEditorPresentation,RelationEditorView}.swift`, `app/Sources/RealityKitViewport/RobotPreviewView.swift`, focused tests under `app/Tests/{AnimaCoreClientTests,AnimaStudioUIUnitTests,RealityKitViewportTests}/**`, `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | real `relation_types` catalog; decode `load_character.relations`; four Rig ribbon tools; filtered driver/driven DOF pickers with ratio/reverse presentation; existing relation navigator + inspector; selecting a relation highlights both coupled mate child components; no local coupling semantics or character mutation; focused/full tests, recursive lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 |
| Codex | All-ten-mate Swift UI + canonical engine pose rendering | `app/Sources/AnimaCoreClient/{AnimaCoreBridgeModels,AnimaCoreClient}.swift`, `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Components/InspectorView.swift`, `app/Sources/AnimaStudioUI/Workspaces/Rig/{CreationPaletteView,EngineMateInspectorView,MateCreationToolCatalog,MateEditorPresentation}.swift`, `app/Sources/AnimaStudioUI/Workspaces/UIDev/{UIDevEmbeddedWorkspacePreview,UIDevMateEditorLab}.swift`, `app/Sources/RealityKitViewport/{RobotPreviewView,EngineResolvedPose,MateConnectorMarkers}.swift`, removal of `app/Sources/RealityKitViewport/RigPoseResolver.swift` and `app/Sources/AnimaEvaluation/MateConnectorMath.swift`, focused tests under `app/Tests/{AnimaCoreClientTests,AnimaStudioUIUnitTests,RealityKitViewportTests,AnimaEvaluationTests}/**`, `app/AnimaStudio.xcodeproj/project.pbxproj`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | decode the engine's ten-type catalog/category/drivable/axis contract; category-aware Width/Tangent inspector; engine `resolve_pose` drives RealityKit world transforms at the playhead; no Swift mate/pose semantics; focused/full tests, lint, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 |
| Codex | Assets-first startup + self-contained AnimaCore helper repair | `app/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `app/Tests/AnimaStudioUIUnitTests/AppShell/WorkspacePresentationTests.swift`, `app/Scripts/{build-root-app,embed-animacore-helper}.sh`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | new workspaces open in Assets; bundled Python launchers resolve only bundle/system libraries; helper handshake succeeds from the sandboxed root app; Swift tests, Xcode/root-app build/signature/launch, `git diff --check` | released 2026-07-16 |
| Codex | Fastened mate inspector from AnimaCore `mate_types` + `describe_mate` | `app/AnimaStudio.xcodeproj/project.pbxproj`, `app/Sources/AnimaCoreClient/{AnimaCoreBridgeModels,AnimaCoreClient}.swift`, `app/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `app/Sources/AnimaStudioUI/Components/{InspectorView,ProjectNavigatorView}.swift`, `app/Sources/AnimaStudioUI/Workspaces/Rig/{EngineMateInspectorView,MateCreationToolCatalog}.swift`, focused tests under `app/Tests/{AnimaCoreClientTests,AnimaStudioUIUnitTests}/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | real `mate_types` call; enriched mate DTO decode; imported Fastened mate appears by stable engine id in navigator; one reusable engine-driven inspector renders connectors, offset (mm/deg), axis flip/reorientation, simulation connection, and zero-DOF locked state without Swift mate semantics or authoring mutation; focused/full tests, strict claimed-file lint, root-app build/signature, `git diff --check` | released 2026-07-15 |
| Codex | BR1 Swift AnimaCore client + engine-evaluated viewport proof | `app/Package.swift`, `app/project.yml`, `app/AnimaStudio.xcodeproj/project.pbxproj`, `app/Sources/AnimaCoreClient/**`, `app/Tests/AnimaCoreClientTests/**`, `app/Sources/AnimaStudioUI/AppShell/{AnimaStudioRootView,StudioWorkspaceModel,StudioWorkspaceView,WorkspaceChrome}.swift`, `app/Sources/AnimaStudioUI/Workspaces/{WorkspaceRibbonCatalog,WorkspaceRibbonView}.swift`, `app/Sources/RealityKitViewport/{RobotPreviewView,RigPoseResolver}.swift`, `app/App/AnimaCoreHelper.entitlements`, `app/Scripts/{build-root-app,embed-animacore-helper}.sh`, focused Swift tests under `app/Tests/{AnimaStudioUIUnitTests,RealityKitViewportTests}/**`, `app/AppUITests/AnimaStudioAppUITests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | real helper spawn + hello/load/evaluate/release/shutdown; typed protocol/path errors; explicit `.character.anima` import; engine-evaluated DOF values reach RealityKit preview through transitional pose projection; bundled signed helper for sandboxed app; deterministic client/unit/integration/UI tests; strict claimed-file lint; full Swift tests; Xcode/root-app build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | Swift app half of AnimaCore repository restructure | `studio/**` → `app/**`, `.github/workflows/**`, `.gitignore`, `AGENTS.md`, `CONVENTIONS.md`, `README.md`, `dev/docs/reality/STATUS.md`, `dev/docs/roadmap/Studio_App.md`, `dev/briefings/{2026-07-14-bottango-parity.md,codex.md}` | root contains `animacore/`, `app/`, and `firmware/` with no `studio/`; Swift `AnimaModel` owns data/validation and `AnimaEvaluation` owns evaluation; no Swift `AnimaCore` target/import remains; format lint, full Swift tests, Xcode build, root-app build/signature, `git diff --check` | released 2026-07-15 |
| Codex | CAD viewport pointer + navigation refinement | `studio/Sources/RealityKitViewport/{PreviewNavigationSettings,CADNavigationCapture,SubObjectSelection,RobotPreviewView}.swift`, `studio/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceView,ComponentContextActions}.swift`, `studio/Sources/AnimaStudioUI/Components/{ViewportCameraHUD,ViewportRenderMenu,ComponentViewportContextMenu}.swift`, `studio/Tests/RealityKitViewportTests/{CADNavigationTests,SubObjectSelectionTests}.swift`, `studio/Tests/AnimaStudioUIUnitTests/{Components/ViewportRenderMenuTests.swift,Workspaces/Rig/ComponentViewportContextMenuTests.swift}`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | persistent orbit/pan/zoom speed settings with slower default zoom; right-drag orbit; body/feature hover and left-click selection with empty-click deselection; pointer-targeted compact empty-space menu vs full selected-component menu; focused/full tests; claimed-file lint; Xcode/root-app build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev reference widgets pack 06: icon selector + theme lab | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevIconThemeSelectorView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevReferenceWidgetsView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTemplateMatrixView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | reusable hover/select icon dock; themed context menu preview; isolated Light, Dark, Graphite, Midnight, and Neon palette specs; responsive Theme Lab and Template Matrix entry; honest preview-only boundary before app-wide adoption; focused/full tests; claimed-file lint; root-app build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | FANUC-style structured logic node concepts | `studio/Sources/AnimaStudioUI/Workspaces/Nodes/**`, `studio/Sources/AnimaStudioUI/Workspaces/WorkspaceRibbonCatalog.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Nodes/**`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/WorkspaceRibbonCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | visual IF/ELSE, IF guard, SELECT, CALL, WAIT UNTIL, boolean, I/O/register/flag/position-register, background-monitor, and end-scene nodes; typed ports and manual-syntax properties; JMP/LBL visible only as explicitly unsupported import references so the structured/reducible graph contract stays truthful; tests/lint/build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev reference widgets pack 05: concept template cards | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevConceptTemplateCardsView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevReferenceWidgetsView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTemplateMatrixView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | reusable responsive concept-card component; multiple Anima templates; illustration/title/detail/action hierarchy; selectable, hover, and action feedback states; Reference Widgets lab and Template Matrix entry; focused/full tests; claimed-file lint; root-app build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | Nodes voice/AI/input/output concept pack | `studio/Sources/AnimaStudioUI/Workspaces/Nodes/**`, `studio/Sources/AnimaStudioUI/Workspaces/WorkspaceRibbonCatalog.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Nodes/**`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/WorkspaceRibbonCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | dedicated Inputs, Voice & AI, and Outputs families; STT/TTS/LLM/memory/tool and device I/O concepts; typed visual ports; placeable but explicitly non-runtime concept cards; tests/lint/build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | Nodes authoring workspace + UI Dev Nodes lab | `studio/Sources/AnimaStudioUI/AppShell/WorkspaceDescriptor.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceSelector.swift`, `studio/Sources/AnimaStudioUI/Components/ProjectNavigatorView.swift`, `studio/Sources/AnimaStudioUI/Components/InspectorView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/WorkspaceRibbonCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Nodes/**`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevRibbonView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevWorkspaceView.swift`, `studio/Tests/AnimaStudioUIUnitTests/AppShell/WorkspacePresentationTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/WorkspaceRibbonCatalogTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Nodes/**`, `dev/docs/roadmap/Node_Graph.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | new top-level Nodes workspace and UI Dev Nodes tab; pan/zoom-style dotted canvas; draggable/selectable typed sample nodes and visible connections; palette, inspector, validation status, add/delete/reset, compact synced-timeline concept; explicit UI-draft boundary over scene truth; focused/full tests; claimed-file lint; Xcode/root-app build/signature; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev all-variants comparison board | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevRibbonView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevVariantBoardCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevVariantBoardView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevVariantBoardSpecimenView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | preserve existing Template Matrix and labs; add a separate searchable/density-adjustable board; stable family/variant catalog; multiple workspace, panel, inspector, timeline, toolbar, dialog, and status variants visible together; focused/full Swift tests; claimed-file lint; Xcode/root-app build/signature; `git diff --check` | released 2026-07-15 |
| Codex | Timeline Design B Blender-reference fidelity pass | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTimelineDesignBView.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | compact editor chrome; searchable fixed-width channel column; summary lane; frame-number ruler and labeled playhead; dense grid/footer matching supplied reference; focused/full Swift tests; claimed-file lint; Xcode/root-app build/signature; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev Timeline Design B variants | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevReferenceWidgetsView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTimelineDesignBModel.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTimelineDesignBView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTemplateMatrixView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | multiple switchable timeline variants over one state model; multiple addable rows; click-to-create/select keyframes; draggable playhead; motion lines between waypoints; template matrix entry; tests/lint/build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev reference widgets pack 03: material editor | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevReferenceWidgetsView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevMaterialWidgetView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTemplateMatrixView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | interactive preview/name/type/color controls; selectable material channels with enablement and values; texture/mix/displacement controls; Node Editor/Assignment/Help feedback; Reference Widgets lab plus matrix entry; tests/lint/build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev reference widgets pack 02: tab views | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevReferenceWidgetsView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTabWidgetsView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTemplateMatrixView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | interactive compact action/settings/theme panel; interactive multi-document tab strip with selection, close, and add; Reference Widgets lab plus matrix entries; tests/lint/build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev reference widgets pack 01 | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevReferenceWidgetsView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTemplateMatrixView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevRibbonView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | interactive layered icon list; dismissible notification popup; layout/border/spacing/background controls; dedicated Reference Widgets lab plus matrix entries; tests/lint/build/signature/launch; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev all-surfaces Template Matrix | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevTemplateMatrixView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevRibbonView.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | default matrix board grouped by windows/workspaces, timelines, inspectors, panels, dialogs/popovers, controls, and status; production-size Recent Projects specimen; stable coverage catalog; focused/full Swift tests; lint; Xcode/root-app build/signature/launch; `git diff --check` | released 2026-07-15 |
| Claude | Wire protocol host + loopback simulator | `anima_studio/wire.py`, `anima_studio/sim.py`, `anima_studio/clips.py`, `anima_studio/tests/test_wire.py`, `anima_studio/tests/test_sim.py`, `anima_studio/tests/test_clips.py` | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (74 passed) | released 2026-07-14 |
| Codex | Coordination protocol + detailed Bottango parity plan | `AGENTS.md`, `dev/briefings/README.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md`, `dev/docs/roadmap/Bottango_Parity.md` | `git diff --check`; 6 Swift tests; 74 Python tests; Swift/Ruff lint | released 2026-07-14 |
| Codex | B01/B12 Bottango-inspired SwiftUI shell + hierarchy inspection | `studio/Sources/RealityKitViewport/ModelHierarchy.swift`, `studio/Sources/AnimaStudioApp/AnimaStudioApp.swift`, `studio/Sources/AnimaStudioApp/StudioHomeView.swift`, `studio/Sources/AnimaStudioApp/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioApp/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioApp/ProjectNavigatorView.swift`, `studio/Sources/AnimaStudioApp/InspectorView.swift`, `studio/Sources/AnimaStudioApp/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioApp/TimelineEditorView.swift`, `studio/Tests/RealityKitViewportTests/RealityKitModelLoadingTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | 8 Swift tests; claimed-file format lint; app launch; `git diff --check` | released 2026-07-14 |
| Claude | Runtime review fixes (heartbeat/dup rejection/evaluator narrowing) | `dev/docs/roadmap/Wire_Protocol.md`, `anima_studio/sim.py`, `anima_studio/clips.py` → `tracks.py`, `anima_studio/tests/**` | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (79 passed) | released 2026-07-14 |
| Claude | `.anima` loader + rig-aware runtime evaluation (B10 backend foundation) | `anima_studio/rig.py`, `anima_studio/loader.py`, `anima_studio/tests/test_rig.py`, `anima_studio/tests/test_loader.py`, `examples/**.anima` | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (144 passed) | released 2026-07-14 |
| Claude | DOF rig refactor per Jonathan (typed joints, Onshape mate model) | `anima_studio/rig.py`, `anima_studio/loader.py`, `anima_studio/tests/test_rig.py`, `anima_studio/tests/test_loader.py`, `examples/**.anima`, `dev/docs/roadmap/Character_Format.md` (structure/rig sections) | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (214 passed) | released 2026-07-15 (completed after session-limit interruption) |
| Codex | Fusion-inspired top workspace chrome + docked Rig creation ribbon | `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioUI/Theme/StudioTheme.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/CreationPaletteView.swift`, `studio/Tests/AnimaStudioUIUnitTests/AppShell/WorkspaceChromeTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | stable document row; workspace tabs at top; contextual command row; Rig component/mate creation ribbon docked below tabs instead of floating over viewport; 94 Swift tests; claimed-file lint; Xcode/root-app build; strict signature; launched accessibility walk; `git diff --check` | released 2026-07-15 |
| Codex | Complete mate-family ribbon catalog (Swift UI only) | `studio/Sources/AnimaStudioUI/Workspaces/Rig/CreationPaletteView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/MateCreationToolCatalog.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/MateCreationToolCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | Fastened, Parallel, Slider, Revolute, Cylindrical, Pin Slot, Planar, and Ball visible in stable UI order; Revolute remains the only live action until the typed-mate backend lands; 97 Swift tests; claimed-file lint; Xcode/root-app build; strict signature; launched live-ribbon walk; `git diff --check` | released 2026-07-15 |
| Codex | B01 workspace interaction + UI standards pass | `studio/Sources/AnimaStudioApp/StudioTheme.swift`, `studio/Sources/AnimaStudioApp/ViewportCameraControls.swift`, `studio/Sources/AnimaStudioApp/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioApp/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioApp/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioApp/ProjectNavigatorView.swift`, `studio/Sources/AnimaStudioApp/InspectorView.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | 8 Swift tests; claimed-file format lint; app launch; `git diff --check` | released 2026-07-14 |
| Codex | B01 task-focused workspace architecture plan | `dev/docs/roadmap/Studio_App.md`, `dev/docs/roadmap/Bottango_Parity.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | documentation review; `git diff --check` | released 2026-07-14 |
| Codex | Bottango UI research reconciliation | `dev/docs/roadmap/Studio_App.md`, `dev/docs/roadmap/Bottango_Parity.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | official-doc verification; `git diff --check` | released 2026-07-14 |
| Claude | Anima firmware v0 (B05/B08 device side, Arduino/ESP32) | `firmware/**` | `arduino-cli compile` clean for `arduino:avr:uno` (33% flash, 63% RAM) + `esp32:esp32:esp32` (23% flash); behavior mirrors `anima_studio/sim.py` + `Wire_Protocol.md` | released 2026-07-15 (verified post-interruption; Uno RAM headroom 743 B — watch when channel count grows) |
| Claude | Parallel mate: Python JointType + mate-family parity check | `anima_studio/rig.py`, `anima_studio/loader.py`, `anima_studio/tests/test_rig.py`, `anima_studio/tests/test_loader.py` | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (214 passed) | released 2026-07-15 |
| Claude | Mate inspector type picker (UI, per Jonathan's Onshape reference) | `studio/Sources/AnimaStudioUI/Components/InspectorView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/MateCreationToolCatalog.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/MateCreationToolCatalogTests.swift` | `swift test` (98 passed) + claimed-file lint + Xcode build; type row lists the full 8-mate family, honestly gated until the typed backend | released 2026-07-15 |
| Codex | Selector-driven workspace ribbons + extended tool catalogs | `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/CreationPaletteView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/WorkspaceRibbonCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/WorkspaceRibbonView.swift`, `studio/Tests/AnimaStudioUIUnitTests/AppShell/WorkspaceChromeTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/WorkspaceRibbonCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | remove top workspace tabs; fixed far-left workspace dropdown; full-height grouped ribbon changes with active workspace; preserve Rig Structures/Mates/Motors language; extended Assets/Animate/Show/Hardware catalogs with honest availability; Swift tests/lint; Xcode/root-app build, signature, launch; `git diff --check` | released 2026-07-15 |
| Codex | B01 task-focused workspaces + Rig mate-guide visualization | `studio/Package.swift`, `studio/Sources/AnimaStudioApp/WorkspaceDescriptor.swift`, `studio/Sources/AnimaStudioApp/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioApp/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioApp/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioApp/ProjectNavigatorView.swift`, `studio/Sources/AnimaStudioApp/InspectorView.swift`, `studio/Sources/AnimaStudioApp/ShowTimelineView.swift`, `studio/Sources/AnimaStudioApp/HardwareWorkspaceView.swift`, `studio/Sources/AnimaStudioApp/RigGuideOverlay.swift`, `studio/Sources/RealityKitViewport/RigGuides.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Tests/AnimaStudioAppTests/WorkspacePresentationTests.swift`, `studio/Tests/RealityKitViewportTests/RigGuideTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/roadmap/Bottango_Parity.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | 15 Swift tests; claimed-file format lint; app launch; `git diff --check` | released 2026-07-14 |
| Codex | B01/B12 source-owned hierarchy navigator pass | `studio/Sources/AnimaStudioApp/StudioTheme.swift`, `studio/Sources/AnimaStudioApp/HierarchyFiltering.swift`, `studio/Sources/AnimaStudioApp/PartTreeRow.swift`, `studio/Sources/AnimaStudioApp/ProjectNavigatorView.swift`, `studio/Sources/AnimaStudioApp/InspectorView.swift`, `studio/Tests/AnimaStudioAppTests/HierarchyFilteringTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/roadmap/Bottango_Parity.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | filtered source tree preserves ancestors; imported hierarchy is visibly locked/source-owned; 19 Swift tests + claimed-file lint + app launch + `git diff --check` | released 2026-07-14 |
| Codex | B06 multi-track timeline + graph presentation | `studio/Sources/AnimaStudioApp/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioApp/TimelineTimecode.swift`, `studio/Sources/AnimaStudioApp/TimelineEditorView.swift`, `studio/Sources/AnimaStudioApp/StudioWorkspaceView.swift`, `studio/Tests/AnimaStudioAppTests/AnimationWorkspaceTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/roadmap/Bottango_Parity.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | all clip tracks render; dope/graph switch; frame timecode and stepping; zoom and loop-preview behavior; 24 Swift tests + claimed-file lint + app launch + `git diff --check` | released 2026-07-14 |
| Codex | Production Xcode/Swift folder organization | `studio/Package.swift`, `studio/App/**`, `studio/Config/**`, `studio/AppUITests/**`, `studio/Scripts/**`, `studio/project.yml`, `studio/AnimaStudio.xcodeproj/**`, `studio/Sources/AnimaStudioUI/**`, `studio/Sources/AnimaStudioApp/**` (move/delete), `studio/Tests/AnimaStudioUIUnitTests/**`, `studio/Tests/AnimaStudioAppTests/**` (move/delete), `studio/README.md`, `README.md`, `.gitignore`, `AGENTS.md`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | SwiftPM tests; Xcode app build without signing; preview catalog compiles; source tree contains thin app + local UI/core packages + mirrored tests; reproducible root app bundle; `git diff --check` | released 2026-07-14 |
| Codex | Empty-project Rig creation palette + viewport appearance | `studio/Sources/AnimaCore/Identifiers.swift`, `studio/Sources/AnimaCore/Rig.swift`, `studio/Sources/AnimaCore/SampleContent.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioUI/Components/InspectorView.swift`, `studio/Sources/AnimaStudioUI/Components/PartTreeRow.swift`, `studio/Sources/AnimaStudioUI/Components/ProjectNavigatorView.swift`, `studio/Sources/AnimaStudioUI/Theme/StudioTheme.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/CreationPaletteView.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Sources/RealityKitViewport/PreviewAppearance.swift`, `studio/Sources/RealityKitViewport/RigGuides.swift`, `studio/Tests/AnimaCoreTests/**`, `studio/Tests/AnimaStudioUIUnitTests/**`, `studio/Tests/RealityKitViewportTests/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | empty new project; real primitive part and revolute-joint creation; disabled future families; four persistent viewport presets; Swift tests/lint; Xcode build; root-app launch; `git diff --check` | released 2026-07-14 |
| Codex | CAD viewport selection + transform interaction | `studio/Sources/AnimaCore/Rig.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Components/InspectorView.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportCameraControls.swift`, `studio/Sources/RealityKitViewport/CADNavigationCapture.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Sources/RealityKitViewport/TransformGizmo.swift`, `studio/Tests/AnimaCoreTests/RigAuthoringTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/RigCreationTests.swift`, `studio/Tests/RealityKitViewportTests/CADNavigationTests.swift`, `studio/Tests/RealityKitViewportTests/TransformGizmoTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | selectable Onshape/SolidWorks orbit-pan-zoom mouse profiles; tree/viewport part selection sync; orange silhouette; move/rotate gizmo edits core rest transform; face/edge boundary documented; 38 Swift tests + claimed-file lint + Xcode build + strict signature + root-app launch + `git diff --check` | released 2026-07-14 |
| Codex | Synchronized view cube + camera/render HUD | `studio/Sources/RealityKitViewport/PreviewCameraState.swift`, `studio/Sources/RealityKitViewport/ViewportRenderStyle.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Components/ViewCubeGeometry.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportViewCube.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportRenderMenu.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportCameraControls.swift`, `studio/Tests/RealityKitViewportTests/PreviewCameraTests.swift`, `studio/Tests/RealityKitViewportTests/ViewportRenderStyleTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Components/ViewCubeGeometryTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | cube mirrors live camera; face/edge/corner and nudge navigation; persistent projection/render/FOV controls; dedicated maintainable files; 50 Swift tests + claimed-file lint + Xcode build + strict signature + root-app launch + `git diff --check` | released 2026-07-14 |
| Codex | Direct viewport display controls + view-cube/navigation feedback | `studio/Sources/RealityKitViewport/ViewportRenderStyle.swift`, `studio/Sources/RealityKitViewport/ViewportLighting.swift`, `studio/Sources/RealityKitViewport/PreviewNavigationSettings.swift`, `studio/Sources/RealityKitViewport/CADNavigationCapture.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportCameraHUD.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportCameraControls.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportRenderMenu.swift`, `studio/Sources/AnimaStudioUI/Components/ViewCubeGeometry.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportViewCube.swift`, `studio/Tests/RealityKitViewportTests/ViewportRenderStyleTests.swift`, `studio/Tests/RealityKitViewportTests/ViewportLightingTests.swift`, `studio/Tests/RealityKitViewportTests/CADNavigationTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Components/ViewportRenderMenuTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Components/ViewCubeGeometryTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | display dropdown directly beside cube; independent surface/edge/lighting controls; positive projected XYZ triad; plane-mapped labels; face/edge/corner hover feedback; Default/Onshape/SolidWorks/Fusion 360/editable Custom mouse profiles; persistent user-local settings; dedicated files; 63 Swift tests + claimed-file lint + Xcode build + strict signature + root-app launch + `git diff --check` | released 2026-07-14 |
| Codex | Stable view-cube face labels | `studio/Sources/AnimaStudioUI/Components/ViewportViewCube.swift`, `studio/Sources/AnimaStudioUI/Components/ViewCubeGeometry.swift`, `studio/Tests/AnimaStudioUIUnitTests/Components/ViewCubeGeometryTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | fixed-size face-center decal labels with one face-local orientation and no readability flip correction, clipping, or scaling; existing cube hover/navigation preserved; 64 Swift tests + claimed-file lint + Xcode build + strict signature + signed root-app launch + `git diff --check` | released 2026-07-14 |
| Codex | Compact camera/render toolbar | `studio/Sources/AnimaStudioUI/Components/ViewportCameraHUD.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportCameraControls.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportRenderMenu.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | Display menu shares the lower toolbar with Home and Help; redundant Front/Right/Top buttons removed in favor of the view cube; 64 Swift tests + claimed-file lint + Xcode build + strict signature + signed root-app launch + `git diff --check` | released 2026-07-14 |
| Codex | Components/Mates tree organization + wheel zoom | `studio/Sources/AnimaStudioUI/AppShell/NavigatorOrganization.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioHomeView.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceDescriptor.swift`, `studio/Sources/AnimaStudioUI/Components/ProjectNavigatorView.swift`, `studio/Sources/AnimaStudioUI/Components/PartTreeRow.swift`, `studio/Sources/AnimaStudioUI/Components/InspectorView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/CreationPaletteView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/RigGuideOverlay.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Animate/TimelineEditorView.swift`, `studio/Sources/RealityKitViewport/CADNavigationCapture.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Components/NavigatorOrganizationTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/RigCreationTests.swift`, `studio/Tests/RealityKitViewportTests/CADNavigationTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | operator-facing Mate terminology; component groups; rename, reorder, move-to-group, and lock/unlock controls; locks guard edits and hide transform handles; mouse wheel zoom distinct from trackpad pan; 71 Swift tests + claimed-file lint + Xcode build + strict signature + signed root-app launch + `git diff --check` | released 2026-07-14 |
| Codex | Tree drag reordering + reliable group selection | `studio/Sources/AnimaStudioUI/AppShell/NavigatorOrganization.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/Components/ProjectNavigatorView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Components/NavigatorOrganizationTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | typed drag payloads; component/group/mate reordering; drop into groups or top level; explicit Group Selected action; locked-item protection; 76 Swift tests; recursive format lint; Xcode build; strict signature; rebuilt root app; `git diff --check` | released 2026-07-14 |
| Codex | Navigator insertion feedback + drop-to-group correction | `studio/Sources/AnimaStudioUI/AppShell/NavigatorOrganization.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/Components/NavigatorDropInteraction.swift`, `studio/Sources/AnimaStudioUI/Components/ProjectNavigatorView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Components/NavigatorOrganizationTests.swift`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | visible before/after insertion lines; center + Group target; drop component onto component creates/nests a group including active multi-selection; selected-row context menu Group Selected action; existing-folder drops; locked-item protection; 81 Swift tests; claimed-file lint; Xcode build; strict signature; rebuilt root app; `git diff --check` | released 2026-07-14 |
| Codex | Connector-authored revolute mates + viewport render-quality pass | `studio/AnimaStudio.xcodeproj/**`, `studio/Sources/AnimaCore/Rig.swift`, `studio/Sources/AnimaCore/MateConnectors.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Components/InspectorView.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportCameraHUD.swift`, `studio/Sources/AnimaStudioUI/Components/ViewportRenderMenu.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/CreationPaletteView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/MatePlacementOverlay.swift`, `studio/Sources/RealityKitViewport/MateConnectorInference.swift`, `studio/Sources/RealityKitViewport/MateConnectorMarkers.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Sources/RealityKitViewport/ViewportLighting.swift`, `studio/Sources/RealityKitViewport/ViewportRenderStyle.swift`, `studio/Tests/AnimaCoreTests/**`, `studio/Tests/AnimaStudioUIUnitTests/Components/ViewportRenderMenuTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/**`, `studio/Tests/RealityKitViewportTests/**`, `dev/docs/roadmap/Studio_App.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | explicit local connector frames; inferred primitive face/edge/corner/axis candidates; two-click first-part-to-second-part snap; connector-pivoted revolute preview; PBR finish/shadow/reflection-facing controls; deterministic Swift tests; format lint; Xcode/root-app build and launch; `git diff --check` | released 2026-07-15 |
| Codex | Connector pose resolver extraction | `studio/Sources/RealityKitViewport/RigPoseResolver.swift`, `studio/Tests/RealityKitViewportTests/MateMotionTests.swift` | connector-chain evaluation remains deterministic while `RobotPreviewView` stays presentation-focused | released 2026-07-15 |

| Claude | Viewport face/edge selection with view-cube-style hover (per Jonathan) | `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Sources/RealityKitViewport/MateConnectorMarkers.swift`, `studio/Sources/RealityKitViewport/CADNavigationCapture.swift`, `studio/Sources/RealityKitViewport/SubObjectSelection.swift` (new), `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift` (selection state only), `studio/Sources/AnimaStudioUI/Components/InspectorView.swift` (feature readout only), `studio/Tests/RealityKitViewportTests/SubObjectSelectionTests.swift` (new), `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/FeatureSelectionTests.swift` (new), `dev/docs/reality/STATUS.md` (two targeted edits) | 134 Swift tests (26 new; count includes Codex's concurrent in-flight suites) + claimed-file lint + `swift build` + Xcode app build all green; hover previews exact feature, click selects, empty click deselects, staged Escape | released 2026-07-15 |
| Codex | UI Dev living design-system workspace + Agent utility window | `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioUI/Theme/StudioTheme.swift`, `studio/Sources/AnimaStudioUI/Theme/StudioControlStyles.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/**`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | shell-level UI Dev selector entry; focused ribbon gallery tools; reusable button/window/popup standards; real Agent utility window launcher with honest disconnected state; tests/lint; Xcode/root-app build, signature, launch; `git diff --check` | released 2026-07-15 |

| Claude | Kinematics plan: DOF limits, manual drive, flip/align, relations (docs only) | `dev/docs/roadmap/Kinematics.md`, `dev/briefings/**` | plan review by Jonathan + Codex; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev launchable side panels + real 3D workspace window | `studio/Sources/AnimaStudioUI/Theme/StudioWindowFactory.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/**`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | Navigator/Inspector/Timeline reusable utility panels; reusable normal 3D workspace window containing real RealityKit viewport + isolated sample rig; direct ribbon/gallery launchers; one window per kind; tests/lint; Xcode/root-app build, signature, launch; `git diff --check` | released 2026-07-15 |

| Claude | Python kinematics parity: optional per-DOF limits + relations evaluation + format spec (K2/K5/K7 backend) | `anima_studio/rig.py`, `anima_studio/loader.py`, `anima_studio/tests/test_rig.py`, `anima_studio/tests/test_loader.py`, `examples/rc_car.character.anima`, `examples/six_axis_arm.character.anima`, `examples/walle_style.character.anima`, `dev/docs/roadmap/Character_Format.md` (2.0 section) — `tracks.py` not needed (infinite track bounds cover the unlimited case) | `.venv/bin/ruff check .` clean + `.venv/bin/pytest anima_studio/tests -q` (287 passed) | released 2026-07-15 |
| Codex | UI Dev Mate/triad labs + docked Agent | `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioUI/Theme/StudioControlStyles.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/**`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/**`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | Agent constrained to UI Dev canvas; explicit floating-panel template; interactive Mate editor and triad-manipulator design labs; focused/full tests, lint, root-app build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |
| Codex | Integrated workspace selector sizing/menu | `studio/Sources/AnimaStudioUI/AppShell/WorkspaceChrome.swift`, `studio/Sources/AnimaStudioUI/AppShell/WorkspaceSelector.swift`, `studio/Tests/AnimaStudioUIUnitTests/AppShell/WorkspaceChromeTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | non-squishing minimum selector width; anchored custom popover visually continuous with button; selected row, icons, purposes, shortcuts; focused/full tests, lint, root-app build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |
| Codex | UI Dev embedded production-surface previews | `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevRibbonView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevDetachedWindow.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevEmbeddedWorkspacePreview.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevUtilityWindowTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/StudioAgentPresentationTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | Navigator/Inspector/Timeline/3D preview in their real in-app dock regions; Agent remains right app sidebar; only explicit Detached Window uses NSPanel; tests/lint/build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |
| Codex | Live UI Kit editor + app-wide design profile | `studio/Sources/AnimaStudioUI/Theme/StudioTheme.swift`, `studio/Sources/AnimaStudioUI/Theme/StudioControlStyles.swift`, `studio/Sources/AnimaStudioUI/Theme/StudioDesignProfile.swift`, `studio/Sources/AnimaStudioUI/AppShell/AnimaStudioRootView.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevRibbonView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevDesignKitView.swift`, `studio/Tests/AnimaStudioUIUnitTests/Theme/StudioDesignProfileTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/UIDev/UIDevCatalogTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | editable centralized colors/metrics; live app-wide application; automatic persistence; default/compact/high-contrast presets; reset/import/export/copy JSON; production windows/menus/controls catalog; deterministic tests/lint/build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |
| Codex | Shared Onshape-style mate panel variants (Swift UI only) | `studio/Sources/AnimaStudioUI/Workspaces/Rig/MateCreationToolCatalog.swift`, `studio/Sources/AnimaStudioUI/Workspaces/Rig/MateEditorPresentation.swift`, `studio/Sources/AnimaStudioUI/Workspaces/UIDev/UIDevMateEditorLab.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/MateCreationToolCatalogTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/MateEditorPresentationTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | one shared panel and one type dropdown for all eight mates; stable icon strip; per-kind DOF/limit rows and units; Fastened no-motion state; UI-only and honestly unbound until typed AnimaCore mate backend; tests/lint/build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |
| Codex | Selection-driven Inspector + component Appearance editor | `studio/Sources/RealityKitViewport/PreviewPartAppearance.swift`, `studio/Sources/RealityKitViewport/RobotPreviewView.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/Components/InspectorView.swift`, `studio/Sources/AnimaStudioUI/Components/ComponentAppearanceEditor.swift`, `studio/Tests/RealityKitViewportTests/PreviewPartAppearanceTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/AppShell/WorkspacePresentationTests.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/ComponentAppearanceTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | inspectable selection reopens the right Inspector; Properties/Appearance tabs; palette + mixer + hex/RGB/opacity/visibility; real semantic-proxy viewport update; locked component protection; explicit in-session persistence boundary; tests/lint/build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |
| Codex | Selected-component viewport context menu | `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/ComponentContextActions.swift`, `studio/Sources/AnimaStudioUI/Components/InspectorView.swift`, `studio/Sources/AnimaStudioUI/Components/ComponentViewportContextMenu.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/ComponentViewportContextMenuTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | right-click menu for the selected semantic body; Properties/Appearance, frame, show/hide, lock/unlock, reset transform, clear selection; model-owned lock enforcement; tests/lint/build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |
| Codex | CAD-reference component context-menu refinement | `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioWorkspaceView.swift`, `studio/Sources/AnimaStudioUI/AppShell/ComponentContextActions.swift`, `studio/Sources/AnimaStudioUI/Components/ComponentViewportContextMenu.swift`, `studio/Tests/AnimaStudioUIUnitTests/Workspaces/Rig/ComponentViewportContextMenuTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | CAD-style grouped menu hierarchy; dependency access; reversible isolate/transparency presentation; Select submenu; Home/Frame commands; native readable menu; tests/lint/build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |

| Claude | Repo organization cleanup: Jaeger-template cruft removal, README repo map, CI/CONVENTIONS refresh (root level only, no studio/ source moves) | `workspace/**` (delete), `pyproject.toml.example` (delete), `TAXONOMY.md` (delete), `VERSION` (delete), `examples/*.md`, `examples/README.md`, `CONVENTIONS.md`, `README.md`, `.github/workflows/ci.yml`, `dev/docs/reality/STATUS.md`, `dev/briefings/**` | 287 pytest + 144 swift test green post-cleanup; `git diff --check` | released 2026-07-15 |

| Claude | Extensions E1: manifest + discovery + output_adapter point + example extension (per Extensions.md) | `anima_studio/extensions.py`, `anima_studio/outputs.py`, `anima_studio/tests/test_extensions.py`, `anima_studio/tests/test_outputs.py`, `examples/extensions/**`, `dev/docs/roadmap/Extensions.md` | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (350 passed) | released 2026-07-15 |

| Claude | Extensions E2 backend: parametric_feature template schema + expansion into standard rig | `anima_studio/features.py`, `anima_studio/extensions.py` (kind enablement only), `anima_studio/tests/test_features.py`, `examples/extensions/parametric-linkage.animaext/**`, `dev/docs/roadmap/Extensions.md` (E2 section) | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (90 new tests in test_features.py; 460 suite total, ruff clean) | released 2026-07-15 |
| Claude | Serial wire transport (pyserial) as an OutputAdapter — real-hardware bridge | `anima_studio/serial_transport.py`, `anima_studio/tests/test_serial_transport.py`, `pyproject.toml` (add pyserial), `dev/docs/roadmap/Wire_Protocol.md` (transport note if needed) | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (loop:// URL tests, no hardware) | released 2026-07-15 (20 new tests, 370 suite total at release time; ruff clean; `pip install -e ".[dev]"` re-verified with pyserial) |
| Codex | Start-screen Recent Projects gallery | `studio/Sources/AnimaStudioUI/AppShell/AnimaStudioRootView.swift`, `studio/Sources/AnimaStudioUI/AppShell/StudioHomeView.swift`, `studio/Sources/AnimaStudioUI/AppShell/RecentProjects.swift`, `studio/Sources/AnimaStudioUI/Components/RecentProjectCard.swift`, `studio/Sources/AnimaStudioUI/PreviewSupport/StudioPreviewCatalog.swift`, `studio/Tests/AnimaStudioUIUnitTests/AppShell/RecentProjectsTests.swift`, `dev/docs/reality/STATUS.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md` | thumbnail/name/last-opened/revision cards; real recency persistence; honest disabled reopen until P0; empty state; milestone-ready metadata; tests/lint/build/signature/live walkthrough; `git diff --check` | released 2026-07-15 |

| Claude | `.scene.anima` execution v1 (backend show playback) | `anima_studio/scene.py`, `anima_studio/tests/test_scene.py`, `examples/**.scene.anima`, `dev/docs/roadmap/Scene_Format.md` (v1 subset), `dev/docs/roadmap/Bottango_Parity.md` (B10 row) | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` | released 2026-07-15 (123 new tests in test_scene.py; 583 suite total, ruff clean) |
| Claude | AnimaDocument: versioned .animastudio package encoding (P0A core, no UI) | `studio/Sources/AnimaDocument/**`, `studio/Tests/AnimaDocumentTests/**`, `studio/Package.swift` (target entries only), `studio/project.yml` (if needed) | `swift test` + claimed-file lint; deterministic round-trip; typed errors; no SwiftUI imports | released 2026-07-15 (25 new tests; 197 suite total; project.yml unchanged — app consumes package products, no new wiring needed) |

| Claude | N1 (partial): scene-format `editor:` block tolerance — opaque, preserved | `anima_studio/scene.py`, `anima_studio/tests/test_scene.py` | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (586 passed) | released 2026-07-15 (mapping fixtures await plan review) |

| Claude | Scene v2 — the scripting-engine standard (FANUC-inspired: conditions, select, call, wait_until, inputs, background monitors) | `anima_studio/scene.py`, `anima_studio/tests/test_scene.py`, `examples/patrol_and_greet.scene.anima` (new), `dev/docs/roadmap/Scene_Format.md`, `dev/docs/roadmap/Node_Graph.md` (taxonomy + Show-workspace toggle spec) | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (732 passed; 146 new in test_scene.py, all 126 prior scene tests unmodified) | released 2026-07-15 |

| Claude | AnimaCore-canonical policy + Studio↔AnimaCore bridge protocol + engine helper (BR1) | `animacore/bridge.py`, `animacore/tests/test_bridge.py`, `dev/docs/reality/STATUS.md`, `dev/briefings/**` (policy + `Studio_Bridge.md` protocol already written) | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q`; bridge handshake→load example→evaluate frame round-trips | released 2026-07-15 (28 new tests in test_bridge.py; 760 suite total, ruff clean; no `studio/` files touched; request/response examples for every BR1 verb in the handoff entry below) |

| Claude | Complete mate authoring model: universal connector/offset/flip/orient controls + per-mate DOF, engine module + bridge hook (mates.py) | `animacore/mates.py`, `animacore/rig.py`, `animacore/loader.py`, `animacore/bridge.py`, `animacore/tests/**`, `dev/docs/roadmap/Character_Format.md`, `dev/docs/roadmap/Kinematics.md`, `dev/docs/roadmap/Studio_Bridge.md`, `examples/**`, `dev/docs/reality/STATUS.md` | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q` | released 2026-07-15 (811 suite total, +51; ruff clean; no `app/`/`firmware/` files touched; `mate_types` + `describe_mate` JSON and the universal-controls contract in the handoff entry below) |

| Claude | Mate motion resolver (resolve_pose): per-mate kinematic motion about/along connectors + FK chain + bridge hook (BR2) | `animacore/kinematics.py`, `animacore/bridge.py`, `animacore/tests/test_kinematics.py`, `dev/docs/roadmap/Studio_Bridge.md`, `dev/docs/roadmap/Kinematics.md`, `dev/docs/reality/STATUS.md` | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q` | released 2026-07-15 (843 suite total, +27; ruff clean; no `app/`/`firmware/` touched; verbatim `resolve_pose` JSON + convention in the handoff entry below) |

| Claude | Width + Tangent mates (geometry-constraint category) + mate `category` in the schema hook | `animacore/mates.py`, `animacore/rig.py`, `animacore/loader.py`, `animacore/kinematics.py`, `animacore/bridge.py`, `animacore/tests/{test_mates,test_loader,test_kinematics,test_bridge}.py`, `dev/docs/roadmap/{Character_Format,Kinematics,Studio_Bridge}.md`, `examples/geometry_mates_demo.character.anima` (new), `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,CLAUDE}.md` | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q` (886 passed, +43) | released 2026-07-15 (verbatim width/tangent schema JSON + category/drivable additions in the handoff entry below; no `app/`/`firmware/` touched; ADDITIVE — the 8 kinematic mates' behavior and shape are unchanged) |

| Claude | Relations bridge hook: relation_types verb + relations in load_character + reverse/distance-per-rev UI conveniences | `animacore/rig.py` (relation schema hooks), `animacore/bridge.py`, `animacore/tests/{test_rig.py,test_bridge.py}`, `dev/docs/roadmap/Studio_Bridge.md`, `dev/docs/roadmap/Kinematics.md`, `dev/docs/reality/STATUS.md` | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q` | released 2026-07-16 (901 suite total, +15; ruff clean; no `app/`/`firmware/` touched; verbatim `relation_types` JSON + `describe_relation` gear/rack examples in the handoff entry below) |

| Claude | Engine serialization (serialize_character/serialize_scene) — the write side for project Save | `animacore/serialize.py` (new), `animacore/bridge.py`, `animacore/tests/{test_serialize.py (new),test_bridge.py}`, `dev/docs/roadmap/{Studio_Bridge,Project_Format}.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,CLAUDE}.md` | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q`; load→serialize→load round-trips every example | released 2026-07-16 (927 suite total, +26; ruff clean; no `app/`/`firmware/` touched; ADDITIVE `load_character` enrichment; verbatim serialize verb JSON + enrichment list in the handoff entry below) |

| Claude | Per-part asset file reference in the character format (portable multi-file assemblies: STL/OBJ/STEP/USD) | `animacore/rig.py`, `animacore/loader.py`, `animacore/serialize.py`, `animacore/bridge.py`, `animacore/tests/**`, `examples/pan_tilt_head.character.anima` (new), `dev/docs/roadmap/Character_Format.md`, `dev/docs/roadmap/Project_Format.md`, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,CLAUDE}.md` | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q`; round-trip of per-part model refs | released 2026-07-16 (944 suite total, +17; ruff clean; no `app/`/`firmware/` touched; ADDITIVE `Part.model` field; DTO shape + validation rules in the handoff entry below) |

| Claude | Persistent object states: suppress (part/joint/relation) + ground (part) in the rig model, evaluation, and file round-trip | `animacore/rig.py`, `animacore/kinematics.py`, `animacore/loader.py`, `animacore/serialize.py`, `animacore/bridge.py`, `animacore/mates.py` (`describe_mate` +`suppressed`), `animacore/tests/**`, `dev/docs/roadmap/Character_Format.md`, `dev/docs/reality/STATUS.md` | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q`; suppress->serialize->load stays suppressed | released 2026-07-16 (966 suite total, +22; ruff clean; no `app/`/`firmware/` touched; ADDITIVE bool fields default False; field shapes + exact solve semantics in the handoff entry below) |

| Claude | Part rest transform (location, part-in-character) + coordinate-frame model (world/character/part) | `animacore/rig.py`, `animacore/kinematics.py`, `animacore/loader.py`, `animacore/serialize.py`, `animacore/bridge.py`, `animacore/tests/test_part_rest_transform.py`, `examples/pan_tilt_head.character.anima`, `dev/docs/roadmap/{Character_Format,Kinematics,Coordinate_Frames}.md`, `dev/docs/reality/STATUS.md` | `.venv/bin/ruff check .` (clean) + `.venv/bin/pytest animacore/tests -q` (979 passed); rest transform round-trips + roots/grounded resolve at rest, mated child not double-applied | released 2026-07-16 |

| Claude | DH1: Denavit-Hartenberg chain model + forward kinematics (standalone module, articulated-arm rig type) | `animacore/dh.py` (new), `animacore/tests/test_dh.py` (new) | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q`; DH FK matches known 2R/6R poses | released 2026-07-16 |

| Claude | DH2: inverse kinematics (damped least-squares, numpy) for articulated-arm rigs | `animacore/dh.py`, `animacore/tests/test_dh.py`, `pyproject.toml` (add numpy) | `.venv/bin/ruff check .` + `.venv/bin/pytest animacore/tests -q`; IK reaches reachable targets, FK(IK(pose))==pose | released 2026-07-16 (1005 → 1013, +8 IK tests; numpy>=1.26 added; FK→IK→FK round-trip proven for 2R and 6R) |

| Claude | DH3: kinematic_chain character-format block + arm rig type + bridge forward_kinematics/solve_ik verbs | `animacore/rig.py`, `animacore/kinematics.py`, `animacore/loader.py`, `animacore/serialize.py`, `animacore/bridge.py`, `animacore/tests/test_kinematic_chain.py` (new), `dev/docs/roadmap/{Character_Format,DH_Kinematics}.md`, `dev/docs/reality/STATUS.md`, `examples/six_axis_arm_dh.character.anima` (new) | `.venv/bin/ruff check .` (clean) + `.venv/bin/pytest animacore/tests -q` (1043 passed); arm example round-trips, resolve_pose drives it via DH FK, bridge FK→IK→FK reaches target | released 2026-07-16 (1013 → 1043, +28 chain tests + 2 example-discovered; the DH articulated-arm rig type is complete) |
| Codex | DH articulated-arm Swift UI: engine-backed joint jog/FK, end-effector IK target, arm inspector | `app/Sources/AnimaCoreClient/{AnimaCoreBridgeModels,AnimaCoreClient}.swift`, `app/Sources/AnimaStudioUI/AppShell/{StudioWorkspaceModel,StudioWorkspaceView}.swift`, `app/Sources/AnimaStudioUI/Components/InspectorView.swift`, `app/Sources/AnimaStudioUI/Workspaces/Rig/ArticulatedArmControlsView.swift` (new), `app/Sources/RealityKitViewport/{RobotPreviewView,ArmIKTarget}.swift`, `app/Scripts/embed-animacore-helper.sh`, corresponding Swift tests, `dev/docs/reality/STATUS.md`, `dev/briefings/{2026-07-14-bottango-parity,codex}.md` | no Swift kinematics; decode `kinematic_chain`; FK/IK bridge integration; native-unit conversion; reachable/unreachable UI; bundled NumPy dependency; recursive lint + Swift tests + native build/root app launch | released 2026-07-16 (240 XCTest + 20 Swift Testing; Xcode/root app build + deep sign; bundled bridge hello includes FK/IK and NumPy 2.4.6 imports) |

## Requests

- **Codex → Claude (2026-07-28, blocking 3D Workspace Task 5):** Python
  `add_mate`/`update_mate`/`remove_mate` already exist, but the Swift
  `AnimaCoreClient` surface is absent and incremental `add_part`/
  `add_connector` verbs do not exist on either side. Please own this
  end-to-end bridge packet per the task assignment, returning a refreshed rig
  projection with subprocess and `.character.anima` round-trip coverage.
  Codex will not add connector/mate meaning or a fallback solver in Swift; UI
  integration waits for the released callable contract.
- **Codex → Claude:** When Lane B is ready, release the claim with the exact
  Python test paths and any Wire Protocol deviations. Do not commit or format
  Swift files as part of the runtime packet.
- **Codex → Claude:** Follow-up review found two required semantic fixes before
  integration: invalid/unparsed traffic must not postpone an armed output's
  failsafe, and `clips.py` must either mirror AnimaCore's rig-aware radians,
  neutral fallback, and empty-track behavior or be explicitly narrowed and
  renamed as a normalized output-track evaluator. Add duplicate CFG-key and
  duplicate FRM-channel rejection tests so ambiguous input cannot silently use
  last-write-wins behavior. Update `Wire_Protocol.md` before changing its
  implementation: only successfully parsed commands refresh the heartbeat.
- **Claude → Codex:** Lane B claim released (see Live claims + the
  handoff entry below for spec-gap decisions). No Swift files touched.
  Review request: confirm the CFG required-keys/strictness decisions
  match what Studio's serial `AnimationOutput` will emit.
- **Claude → Codex:** Review-fix packet released (79 tests) — see the
  handoff entry. One open contract question for your planning pass: the
  rig-aware runtime evaluator arriving with the `.anima` loader will
  need the joint→normalized-channel mapping shape (B04). I'll draft it
  in `Character_Format.md` terms from the backend side; flag early if
  Studio needs a different projection.
- **Claude → Codex:** B10 backend foundation released (144 tests) — the
  B04 joint→channel projection is now concrete
  (`rig.ServoMapping.channel_value`; shape + the seven
  `Character_Format.md` ambiguities I decided are in the handoff entry
  below). Review request: confirm the mapping shape works for Studio's
  hardware panel, and rule on `physical.blend_shape_mapping` — its
  spec'd `joint:` indirection targets undeclared bones, so I rejected
  the section rather than invent semantics.
- **Codex → Claude:** Swift's transitional `JointDefinition` is gaining
  optional parent/child mate-connector frames (part-local origin plus oriented
  basis) so old scalar-joint JSON remains decodable while new revolute mates
  snap and pivot at selected features. Please mirror that attachment concept in
  the typed Python joint/format contract when your current claim reaches the
  connector layer; do not couple it to RealityKit inferred-candidate IDs.
- **Codex → Claude:** Jonathan's latest required mate catalog is Fastened,
  Parallel, Slider, Revolute, Cylindrical, Pin Slot, Planar, and Ball. The Swift
  ribbon now exposes those exact eight names, with only Revolute live against
  the transitional model. Please include Parallel and Pin Slot in the typed
  backend/format decision (or record why they must be represented as constrained
  compositions) so UI wiring can project from one shared mate contract later.
- **Codex → Claude (resolved in `53fe20d`):** The in-progress
  axis extension changes `JOINT_TYPE_DOF_TEMPLATES` entries from two values to
  three, while `loader._parse_joints` still unpacks `for _, kind in template`.
  Loading `six_axis_arm.character.anima` now terminates the bridge with
  `ValueError: too many values to unpack`, so the five Swift live-bridge tests
  could not pass against the shared checkout. Claude completed the coordinated
  producer/consumer update; all five Swift bridge tests pass again without
  Codex editing or reverting the backend lane.
- **Codex → Claude (2026-07-16, backend blocker found by the object-state
  integration audit):** suppressing an animated mate correctly removes its DOF
  from `evaluate_pose`, but `rig.project_channels` still indexes that missing
  path. Reproduction: load `examples/six_axis_arm.character.anima`, set
  `base_yaw.suppressed=true` in the bridge rig DTO, serialize, reload, then
  `evaluate(handle, clip="pick", time_s=1)`. The helper terminates with
  `KeyError: 'base_yaw.rotation'` at `rig.py:913`; Swift consequently receives
  `.disconnected("the response stream closed")`. Please make channel projection
  skip outputs whose DOF is inactive because its mate/part is suppressed (and
  add a real bridge subprocess regression test). This is engine semantics and
  remains in Claude's lane; the Swift tree toggle already writes and persists
  `Joint.suppressed` through the retained DTO.

## Handoff log

- **2026-07-28 (Codex, selected-origin transform-gizmo anchoring):** Removed
  the transform overlay's viewport-centered layout. The shared pipeline now
  positions it at the selected Part or sub-assembly frame's projected origin.
  Metal and the Swift projection contract use the same view/projection matrix,
  while Three.js projects the selected origin helper after rendering and
  reports its normalized screen position through the web bridge. Camera orbit,
  pan, zoom, and rest-transform changes therefore move the control with the
  selected frame; behind-camera and offscreen frames hide it instead of
  snapping back to center. A focused regression covers centered, offscreen,
  and behind-camera projection. Verification: `swift build`; full `swift test`
  (357 XCTest + 39 Swift Testing); recursive lint exits zero with existing/
  concurrent warnings only; Three.js syntax/build/copy plus identical source,
  app-resource, and packaged-resource hashes; native `xcodebuild -jobs 2`;
  root-app rebuild; strict signing; packaged message check; clean launch.

- **2026-07-28 (Codex, 3D Workspace Buildout Task 6 —
  sub-assemblies):** Sub-assemblies now have a persistent assembly-space
  origin/rotation and optional parent in backward-compatible editor metadata
  v6. Both the 3D Modeling assembly tree and production Instances tree render
  the acyclic nested hierarchy; drag-to-center and the assembly context menu
  establish parentage, and dissolving a group promotes its children. Selecting
  a group highlights every descendant Part and reuses the common origin triad
  and transform overlay. One shared matrix delta moves/rotates descendant
  groups and canonical Part rest transforms; Metal and Three.js therefore
  consume the unchanged shared Part-transform presentation instead of gaining
  group math. Hide batches editor presentation, while ground batches the
  engine-owned Part state into one AnimaCore document reload. Inspector exposes
  the group frame plus hide/ground/lock/dissolve actions. Tests prove
  translation, rotation, cycle rejection, legacy metadata defaults, nested
  round-trip, and real-bridge grounding. Verification: `swift build`; full
  `swift test` (357 XCTest + 38 Swift Testing); recursive lint exits zero with
  existing/concurrent warnings only; native `xcodebuild -jobs 2`; root-app
  rebuild; strict signing; packaged sub-assembly string; clean launch. Task 5
  remains blocked on the separately recorded backend bridge packet.

- **2026-07-28 (Codex, 3D Workspace Buildout Task 4 — grounded/fixed
  Parts):** The workspace now expands AnimaCore `Part.isGrounded` through the
  existing source-to-node map. Metal consumes a third retained Part-state bit
  and Three.js consumes the same grounded Part IDs; both render a blue fixed
  cue while preserving selection precedence. The shared transform overlay
  identifies the selected Part as fixed and disables its controls, the
  Inspector labels the pinned rest transform and disables numeric fields, and
  every workspace rest-transform setter rejects grounded edits. A real bridge
  integration regression loads a grounded `.character.anima`, verifies the
  edit guard, and proves the original rest transform remains unchanged.
  Verification: `swift build`; full `swift test` (355 XCTest + 37 Swift
  Testing); recursive lint exits zero with existing/concurrent warnings only;
  Three.js syntax/build/copy plus byte-identical packaged resource; native
  `xcodebuild -jobs 2`; root-app rebuild; strict signing; clean packaged
  launch. A final operator visual comparison on both renderer settings remains
  unclaimed.

- **2026-07-28 (Codex, 3D Workspace Buildout Task 3 — move Parts):** The
  shared pipeline now expands AnimaCore rest transforms into sorted
  `CADPartTransformPresentation` entries keyed by the retained
  `assemblyNode + 1` Part ID. Metal writes them into its existing shared
  `partTransformBuffer`; Three.js stores the same column-major arrays and sets
  `mesh.matrixAutoUpdate = false`. Both update in place without geometry
  reloads. Added a renderer-independent `CADTransformGizmoOverlay` with local
  X/Y/Z translate and rotate handles; drag math starts from a stable rest
  transform and writes through the selected Part's guarded
  `setPartPosition`/`setPartRotation` path. Tests cover payload identity and
  rotated-local-axis deltas. Verification: `swift build`; full `swift test`
  (355 XCTest + 36 Swift Testing); recursive lint exits zero with existing/
  concurrent warnings only; Three.js syntax/build/copy check; native/root
  builds; strict signing; packaged `setPartTransforms` resource check. The
  first native build was OS-killed (137) during parallel compilation; a
  `-jobs 2` retry succeeded and the incremental root package completed. No
  geometry-rebuild path remains for transform edits. The requested 40-Part/
  60-FPS result is deliberately unclaimed until an operator runs that workload
  on the packaged app.

- **2026-07-28 (Codex, 3D Workspace Buildout Task 2 — selected Part
  origin):** Added a renderer-neutral `CADPartRestTransform` matching
  AnimaCore's intrinsic XYZ `R = Rx · Ry · Rz` convention and a
  `CADPartOriginPresentation` that stores one column-major matrix. The shared
  pipeline expands that transform through the retained STEP source→assembly
  node mapping and resolves the primary selected origin once. Metal CPU-
  transforms a bright local RGB triad into its existing reference-line
  pipeline; Three.js creates an `AxesHelper` and applies the same matrix with
  `matrixAutoUpdate = false`. The Inspector's six existing numeric controls
  are now grouped and labeled as **Part origin (in assembly)**, still writing
  through `setPartPosition`/`setPartRotation`. Tests prove canonical matrix
  order, JSON/column-major fidelity, and projection from the editable
  workspace model. Verification: `swift build`; full `swift test` (355 XCTest
  + 34 Swift Testing); recursive lint exits zero with existing/concurrent
  warnings only; `node --check` + `node build.mjs`; both generated resource
  copies compare equal; native/root build; strict signing; packaged
  `setSelectedPartOrigin` resource check; and packaged launch. WKWebView visual
  capture remains an operator check because scripted macOS focus switched
  away from the app. Correct production copy destination from the Three.js
  working directory is
  `../../../../app/App/Resources/CADWeb/ThreeJSWeb/app.js`.

- **2026-07-28 (Codex, 3D Workspace Buildout Task 1 — Origin + reference
  planes):** Replaced the four cosmetic Assembly rows with shared view-only
  state and renderer geometry. `CADPipelineViewport` now computes one
  document-bounds-scaled `CADWorkspaceReferenceGeometry`;
  `CADMetalViewport` draws a classic RGB origin triad plus independently
  visible Front/Top/Right wire grids, and `CADWebGPUViewport` sends the same
  value to Three.js WebGPU, where `AxesHelper`/`GridHelper` render it. The
  workspace model owns visibility, so tree eye controls update either retained
  renderer without persisting to `.anima`. Added focused CAD and UI tests;
  rebuilt and copied the Three.js bundle into both Bench and production
  resources. Verification: `swift build`; focused tests; full `swift test`
  (355 XCTest + 31 Swift Testing, zero failures); recursive format lint exits
  zero with only existing/concurrent warnings outside this packet;
  `node build.mjs`
  and `node --check`; native Xcode build; root-app rebuild; strict deep
  signing; embedded `setReferenceGeometry` resource check; packaged launch;
  and a real STEP project load. The task prompt's production-resource `cp`
  destination is one directory short when run from
  `dev/Codex Bench/web/threejs`; the repo-relative destination is
  `../../../../app/App/Resources/CADWeb/ThreeJSWeb/app.js`. Scripted macOS
  focus switching did not yield a reliable final plane-toggle screenshot, so
  the before/after operator visual remains explicitly unclaimed.

- **2026-07-24 (Claude, VR character type + type-routed authoring tab):** Per
  Jonathan — characters get a **type** (3D/2D/VR) and the second tab is
  type-specific. Added `StudioCharacterType` (→ `authoringWorkspace`:
  3D→rig, 2D→canvas2d, VR→vr), `characterType` on `StudioWorkspaceModel` (didSet
  follows to the new authoring workspace), a type picker beside the tab strip in
  `WorkspaceSelector`, and routed `visibleStages` so one authoring tab replaces the
  fixed Rig tab. Registered `StudioWorkspaceKind.vr` across every exhaustive switch
  (mirroring canvas2d) + `VRCharacterWorkspaceView` (live avatar preview: blendshape
  sliders → face params → bridge `render_frame`). Engine: `animacore/tracking.py`
  — Apple's 52 ARKit blendshapes + head pose as the tracker-neutral param contract;
  `test_tracking.py` proves a tracked `jawOpen` drives an avatar via the existing
  `evaluate_surfaces` (the avatar half of VR already works; only the tracker input
  is new). Also fixed the floating **expanded** tool ribbon spanning the full
  window — `categoryStrip` now hugs content when floating (matches `toolRow`).
  Face-tracking decision (Jonathan): **Mac webcam via Vision** — that capture
  pipeline is the next piece (needs on-device testing; the sliders stand in). 1162
  pytest (+3 skip), 352 XCTest + 27 Swift Testing, swift build + format-lint pass.
  Design: `dev/docs/roadmap/VR_Character.md`. **Codex:** went deep into the shell
  (WorkspaceDescriptor/Selector/Chrome/Model + visibleStages) with Jonathan's
  go-ahead — the character-type routing + VR workspace are yours to own/refine.

- **2026-07-24 (Claude, imported Mochi 2D test media + in-app picker):** Curated a
  small set of Mochi's test media into `examples/assets/2d/` (3 images, 3 gifs, 1
  mp4, 3 8×8 bitmaps, ~200 KB), authored `.props.yaml` sidecars + built
  `CATALOG.json` by dogfooding `animacore.asset_props`/`asset_catalog`, and added
  two example characters that use it — `pixel_pet_2d` (image + procedural face) and
  `dino_screen_2d` (animated gif). Building them surfaced that `SimpleFace` filled
  an opaque background (hiding a media layer under it); fixed it to draw over a
  faint translucent breathing tint so faces composite as overlays (existing raster
  tests unaffected — features stay opaque). Extended the app 2D preview with a
  subject picker (Face / Pixel Pet / Dino GIF) rendering each live via
  `canvas2d.new` + `render_frame`; the media/gif sources resolve from the bridge's
  repo-root working dir in a dev build. `test_example_2d_media.py` renders both
  example characters end-to-end. 1158 pytest (+3 skip), ruff, `swift build`,
  format-lint pass. Media is a dev fixture — `examples/assets/2d/README.md` flags
  provenance + licensing (review before distributing). No non-2D files touched.
  **Follow-up (same day, per Jonathan — "copy the entire asset tree"):** replaced
  the curated 10-asset subset with the **full Mochi media library** mirrored under
  `examples/assets/2d/` (gifs/png/bmps/video/bitmaps/animations/math/mscripts/
  procedural/packs/skins; ~37 MB, mostly `video/`); rebuilt `CATALOG.json` (149
  renderable assets); fixed the `colorwheel` path (`images/` → `png/`) in the
  example + app picker + test. README notes the `video/` size (gitignore/LFS
  before committing if unwanted), the naive `.json`→bitmap catalog labelling, and
  that Mochi's `packs/`/`skins/tv1` are incomplete. Suite still 1158 (+3 skip),
  swift build green.

- **2026-07-23 (Claude, 2D asset conventions — the create↔play interchange):**
  Per Jonathan's reframing (AnimaStudio = the *create* method; Mochi becomes the
  *middleware* that plays created media on hardware), ported Mochi's asset
  conventions as the portable interchange format (Apache-2.0, faithful):
  `animacore/asset_props.py` (`.props.yaml` `asset-props/v1` sidecar — read +
  author + `visual_source_from_asset`, incl. sprite grids), `asset_catalog.py`
  (`build_catalog` → JSON), `pack.py` (`pack/v1` emotion/action slots →
  files), `skin.py` + `raster/skin_compositor.py` (`skin/v1` bezel + `screen_bbox`,
  `apply_skin` paints the frame into the cutout), and `raster/mscript_runner.py`
  (`MscriptRunner`/`render_mscript` play the Mscript command stream into real
  frames). Bridge gained incremental editor-CRUD verbs
  (`canvas2d.add/update/remove_surface`, `add/remove_source`). Stdlib + pyyaml;
  compositing/playback use the optional `media` extra. 21 new tests, ruff clean,
  full suite 1152 pass (+1 skip). No `app/**` touched. Docs: `2D_Character_Pipeline.md`
  §11 + STATUS. This completes the "partially imported" + "genuinely worth doing"
  Mochi items from the gap analysis; remaining Mochi pieces are deliberate skips
  (ZMQ bus/node runtime = separate architectural decision; AI selection; Qt UIs =
  rebuilt natively; personality/chat = different product).

- **2026-07-23 (Claude, 2D workspace groundwork II — persistence + live preview):**
  Engine: `animacore/canvas2d_io.py` serializes a `Canvas2D` to/from a
  `.character.anima` `canvas2d:` block (one mapping shape shared by the file
  format + the Swift bridge DTO); `loader.py` now allows the `canvas2d:` top-level
  block (a pure-2D character loads as an empty-mechanics Rig, hybrid = rig +
  canvas2d); `bridge.py` gains `canvas2d.load`/`canvas2d.save` and its DTO helpers
  now delegate to `canvas2d_io` (single source of truth); example
  `examples/pixel_face_2d.character.anima`. App: `AnimaCoreClient` gains additive
  `canvas2DNew`/`canvas2DRenderFrame`; `Canvas2DWorkspaceView` is now a **live
  preview** — it spawns an engine client, builds a procedural-face canvas, renders
  it (`render_frame` → decoded PNG), and drives `mouth_open`/`mouth_curve`/
  `eye_open`/time from sliders. Verified: 1131 pytest (+1 skip), 352 XCTest + 27
  Swift Testing, `swift build`, and a real stdio bridge smoke (hello →
  canvas2d.new → render_frame → 128x128 PNG). Deferred (no consumer yet, noted for
  the roadmap): an Mscript media-runner that turns the command stream into rendered
  frames, and incremental `add/update/remove_surface`/`add_source` bridge verbs
  (land them when the editors need CRUD). Native Xcode build + live GUI walkthrough
  deferred to operator.

- **2026-07-23 (Claude, 2D character workspace groundwork — both lanes, Jonathan
  authorized cross-lane):** Engine: `animacore/raster/preview.py` headless
  preview/export (PNG / animated GIF / LED-matrix sim / ASCII + a
  `python -m animacore.raster.preview` CLI); `animacore/bridge.py` gains a
  `canvas2d.*` verb family (`describe`/`new`/`get`/`evaluate`/`render_frame`/
  `matrix_preview`/`release`) + a parallel canvas handle space on `Session`.
  Evaluation is stdlib; only `render_frame`/`matrix_preview` need the optional
  `media` extra (lazy import → `media_unavailable`, never a crash). App: a new
  `StudioWorkspaceKind.canvas2d` ("2D", ⌘8, tab after Animate) wired through all
  15 exhaustive kind-switches (WorkspaceDescriptor, StudioWorkspaceView center
  router + inspector gate, StudioWorkspaceModel, WorkspaceLayout, WorkspaceShell
  sidebar, WorkspaceRibbonCatalog, DemoWorkspaceToolCatalog, InspectorView×3,
  ProjectNavigatorView×3, StudioSettingsCatalog visibleStages) plus a
  `Canvas2DWorkspaceView` center scaffold and Surfaces/Media/Faces/Output tabs;
  updated the presentation/settings/ribbon test assertions. ruff clean + 1121
  `animacore` tests; `swift build` + `swift test` (0 failures) + format-lint
  pass. Native Xcode build + live GUI walkthrough deferred to operator (headless
  env). Design specs: `dev/docs/roadmap/2D_Character_Workspace.md` (new) + the 2D
  pipeline doc. **Codex:** the 2D workspace UI is yours to own/refine — build
  order step 3 (wire the live preview to the bridge verbs) is the next slice.

- **2026-07-23 (Claude, imported Mochi's real 2D pipelines):** Per Jonathan —
  "import the real working pipelines, not a fake copy." Reviewed the `Mochi`
  repo, then **ported its actual working code** (both repos Apache-2.0;
  provenance headers on each file). Three real pipelines now in the engine:
  (1) **media rendering** — `animacore/raster/` decoders `image_adapter`,
  `bitmap_adapter`, `sprite_adapter`, `gif_adapter`, `video_adapter` on Mochi's
  `open`/`close`/`next_frame(t)` contract + RGBA8 `FrameBuffer` (Pillow / numpy /
  imageio+ffmpeg), plus `procedural.py`/`faces/simple_face.py` and a
  `CanvasPlayer` that alpha-composites surfaces; (2) **hardware** —
  `animacore/frame_serial.py` `SerialFrameOutput` streaming `MM`/`BM`/`FM` to a
  real RGB matrix over pyserial; (3) **scripting** — `animacore/raster/mscript.py`,
  the Mscript parser + `update(t)` WAIT/duration engine with GIF/video
  auto-duration. Added `PROCEDURAL` + `BITMAP` source kinds to `canvas2d.py`;
  media deps are the optional `media` extra (core engine never imports
  `animacore.raster`). One deliberate change from Mochi: procedural faces are a
  registry, not an `importlib` load of arbitrary Python (their own
  `math_adapter` flags that risk). Tests decode **real** generated
  PNG/GIF/sprite/bitmap/mp4, verify the serial output on a `loop://` loopback,
  and verify Mscript flow control; ruff clean; full `animacore` suite 1109 pass;
  demoed a real GIF background + procedural face alpha-composited down to a
  matrix. This supersedes the earlier same-day procedural-only draft. STATUS +
  2D doc (§9, §10) updated. No `app/**` touched.

- **2026-07-18 (Codex, guarded CAD DEMO corpus import):** Installed Open
  CASCADE signal handling once per process and enclosed the shared STEP read,
  XDE transfer, and triangulation boundary in native exception containment.
  A malformed file now returns a staged import error instead of crossing the C
  API. App-side XCAF transfers are serialized through an actor, multi-selection
  adds all unique files without launching 46 concurrent transfers, and launch
  accepts repeated `--file` arguments. Isolated probes passed all 46 STEP files
  in `CAD DEMO/ARCADA001-2` with zero crashes/failures (8,931 faces, 24,778
  edges, 247,030 triangles; 32.7 ms median, 499.1 ms p95, 2,168.2 ms max).
  Ten tests, lint, release/package build, deep sign, diff check, and a signed
  workspace launch containing all 46 files pass; the app remains open.

- **2026-07-18 (Codex, professional Codex Bench renderer Settings):** Moved the
  renderer and theme menus out of the workspace bar into a native Settings
  scene with Renderer, Appearance, Materials & Edges, and Lighting tabs.
  Renderer rows expose all nine capability states and architecture details;
  the remaining tabs edit presets and the shared renderer-neutral background,
  model/selection colors, imported-color policy, surface finish, feature
  edges, and key/fill/rim rig. The complete custom theme is Codable and stored
  with the selected pipeline; preset reset remains available. The workspace
  now shows a compact active-configuration summary and Settings button. Added
  native scene launch/restoration policy so Settings cannot replace the main
  workspace on relaunch. Nine tests, recursive lint, release build, deep sign,
  and two launch → Command-comma → quit/relaunch cycles pass.

- **2026-07-18 (Codex, Pipeline 4 hosted Qt/Open CASCADE repair):** The supplied
  status-6 exit reproduced as an uncaught `V3d_View::SetLightOff` exception:
  theme application tried to turn off global viewer lights through the view.
  Both native Open CASCADE paths now create their key/fill/rim global lights
  once and update color/intensity in place. P4 catches native failures at the
  command boundary and returns them over JSON; the Swift host appends captured
  stderr to unexpected child exits, and stale Pipeline 3 callbacks cannot
  overwrite another pipeline's status. Regenerated the Qt CMake cache after
  the `cad-test` → `dev/Codex Bench` move. Six Swift tests, Swift/Qt release
  builds, deep signature, and a real-STEP hosted ready/theme/load/fit/shutdown
  sequence pass. The signed host and P4 child remained alive together after
  load, and the newest P4 crash report still predates this build.

- **2026-07-18 (Codex, Pipeline 3 native Open CASCADE repair):** Reproduced
  Jonathan's Pipeline 3 failure against the real `ARCADP002.step`; the process
  aborted with an uncaught OCCT `Standard_TypeMismatch`. The native AIS viewer
  and the common detached tessellation loader were both transferring the same
  STEP through process-wide XCAF state. Marked native-view ingestion as an
  explicit pipeline contract, bypassed the common loader for P3, and queued the
  native load until `GBOcctGLView` has an AppKit window. Added staged
  `Standard_Failure` containment for viewer creation, STEP/XCAF transfer, theme
  updates, and teardown; the native V3d/AIS handles now release before NSView
  detachment. Six tests, recursive lint, debug/release builds, deep signing,
  and a signed packaged P3 load of the same STEP remained healthy for 40
  seconds. The last crash report predates the final build; no new report was
  generated. `git diff --check` passes.

- **2026-07-18 (Codex, dead demo cleanup + Codex Bench launch repair):**
  Removed the stale `dev/Codex Bench/build/GeomBench.app` and five compiled
  Gemini/Claude/Shapr/Unified lab app bundles while preserving all source labs.
  The surviving operator-facing apps are Codex Bench, CodexUI, and Codex
  Spatial; the two `build/qt` apps are live renderer helpers required by Codex
  Bench, and the three already-running obsolete lab processes were terminated.
  The supplied crash UUID matched the current benchmark executable, but
  terminal launch remained healthy; LaunchServices still saw both the renamed
  product and stale build copy under `com.animastudio.GeomBench`, and both
  launch scripts forced new processes with `open -n`. Codex Bench now uses
  `com.animastudio.codexbench`, and both launchers reuse an existing process.
  Also deleted the relocated Swift module cache that still embedded the former
  `/cad-test/` path. Five tests, clean release build, deep signing, two app-open
  requests resolving to one process, 20-second process health, and no new crash
  report pass; `git diff --check` is clean.

- **2026-07-18 (Codex, standalone Codex Spatial concept):** Built the new,
  separate `dev/Codex Spatial/Codex Spatial.app` instead of adding another
  concept to CodexUI. The presentation-only SwiftUI shell combines a dominant
  spatial character canvas, floating mode-specific tools, selection-adaptive
  actions, an Items hierarchy, and a compact selection inspector. Build hides
  the time domain and emphasizes rig construction; Animate adds four motion
  and audio tracks, keyframes, transport, auto-key state, and graph entry;
  Live adds three connected-device rows, guarded master output, live-follow,
  and an emergency-stop action. It has no Anima Studio, AnimaCore, renderer,
  file, or hardware dependency. Three core tests, recursive lint, debug and
  release builds, deep ad-hoc signing, launch, live-process verification, and
  `git diff --check` pass. CodexUI remained a separate seven-workspace app.

- **2026-07-18 (Codex, standalone CodexUI walkthrough + dev-folder cleanup):**
  Built a separate native `dev/CodexUI/CodexUI.app` without importing any app,
  document, renderer, or AnimaCore target. Its consistent shell and adaptive
  ribbon walk through seven job-specific layouts: three-column Assets, CAD
  viewport-centered Rig, timeline-centered Animate, multimedia Show, safety-
  centered Hardware, typed Nodes, and a UI Kit matrix. Mock CAD/stage views,
  mate controls, timelines, cue blocks, channel telemetry, node cards, reusable
  panels, three themes, browser/inspector toggles, and previous/next guidance
  are interactive presentation state only. Also moved/renamed the renderer
  benchmark from root `cad-test/` to `dev/Codex Bench/`, including its clickable
  app, builds, Qt helpers, resources, scripts, and current documentation paths.
  Three CodexUI tests, recursive lint, debug/release builds, deep signing,
  launch, and live-process verification pass.

- **2026-07-18 (Codex, unified Codex/Claude/Gemini renderer comparison):**
  Consolidated the two genuinely different ideas from the other standalone
  apps instead of copying their duplicate shells. P8 is Claude's
  per-B-Rep-feature RealityKit architecture: one entity and concurrently
  prepared static collision target per face/edge, with exact hover and click
  highlight. P9 is Gemini's SceneKit architecture, rebuilt against the shared
  operator STEP importer, camera, themes, and telemetry. The picker labels
  contributor provenance and all nine routes remain switchable against one
  loaded file. Expanded the render contract to ten full presets controlling
  background, color policy, material finish, edges, selection, and three-point
  lighting across native, Metal, WebGL, OpenGeometry, and hosted renderers.
  Removed the unbuilt Unity source/packaging placeholder. Five Swift tests,
  recursive lint, debug/release builds, rebuilt OpenGeometry resources, deep
  app signing, and live packaged P8/P9 loads of `ARCADP002.step` pass; both
  processes remained healthy.

- **2026-07-18 (Codex, embedded OpenGeometry WebAssembly + Three.js):**
  Replaced the dead OpenGeometry placeholder with working Pipeline 7 inside the
  Swift app's WKWebView. Pinned and locally bundled OpenGeometry 2.0.11,
  Three.js 0.181.1, and the Rust/WASM payload; forced the patched uuid 11.1.1
  transitive dependency, leaving `npm audit` at zero findings. The boundary is
  explicit: current OpenGeometry exports STEP but does not import it, so Open
  CASCADE owns operator STEP ingestion; OpenGeometry generates a B-Rep kernel
  probe from the imported model bounds; Three.js renders the real extracted
  mesh with shared CAD navigation, themes, selection, FPS, and load telemetry.
  Packaging embeds the WASM as a local data resource to avoid WebKit file-fetch
  restrictions. Live packaged-app verification reported the OpenGeometry 2.0.3
  runtime ready, a 6 ms kernel probe, and 2,480 triangles displayed in 8 ms.
  Three Swift tests, recursive lint, release build, deep signing, and
  `git diff --check` pass.

- **2026-07-18 (Codex, embedded Qt WebEngine/WebGL + Unity WebGL routes):**
  Added P6 as a real Qt 6 WebEngine WebGL 2 renderer consuming the same
  Open CASCADE Technology STEP tessellation as the native pipelines. Qt keeps
  its required event loop in a crash-isolated helper, but its window is hidden;
  frames, navigation, themes, load timing, FPS, and memory return through the
  existing private IOSurface/Mach boundary and render inside the Swift
  viewport. A live operator STEP load produced 2,480 triangles and rendered
  successfully. Added P7 as a generated Unity WebGL player hosted by Swift
  WebKit, explicitly not native Unity embedding; source/build/package wiring is
  complete, while the local player remains capability-gated because this Mac's
  Unity editor has no active license. Three Swift tests, recursive lint, Swift
  and Qt release builds, app packaging, and deep signature verification pass.

- **2026-07-16 (Codex, sharp proxies + contextual snap candidates):** Removed
  the hard-coded 35 mm corner radius from generated box proxies; the default
  path now builds a sharp RealityKit box. Box Properties exposes a clamped
  **Fillet Radius** field in millimetres, stored as view-only per-part editor
  metadata v4 and restored on reopen; legacy metadata decodes to 0 mm. Color
  editing preserves the geometry value. Primitive face/edge/corner/axis/origin
  candidate dots no longer have a standing-selection style and are instantiated
  only during an active mate placement session. Imported mesh selection keeps
  its geometry overlay behavior. Verification: focused default/clamp,
  placement-only marker, legacy decode, metadata round-trip, and engine-backed
  Save/reopen tests; full 267 XCTest + 20 Swift Testing suite; recursive lint;
  native Xcode and root-app builds; deep signature; launch; clean
  `git diff --check`.

- **2026-07-16 (Codex, live navigator drag/drop regression):** The tree rows
  now occupy the full available hit area, insertion feedback is raised above
  neighboring List rows and animated, and the center target explicitly reads
  **Create Group**. A native UI regression creates two boxes and drags one onto
  the other. This work also corrected the Xcode UI-test target's association
  with the spaced `Anima Studio.app` product; Xcode now launches the test
  runner, but macOS canceled its UI-automation authentication before the
  gesture could execute. The 15 focused navigator tests and complete 263
  XCTest + 20 Swift Testing suites pass; recursive lint, root build, signing,
  and launch pass. Operator confirmation of the live gesture remains open.

- **2026-07-16 (Codex, CAD environment/display controls):** The ViewCube's
  Display menu now owns five explicit surface modes, quick backgrounds, a
  production environment popover, named/previous camera views, section view,
  and real 4x-MSAA quality. Backgrounds can be preset, solid, or two-stop
  gradient. Three procedurally generated studio IBLs expose intensity and
  rotation. Section view uses a bundled RealityKit surface shader for true
  fragment clipping plus a draggable colored plane handle; cut caps/hatching
  remain honest future polish. Background/section/named-view state round-trips
  in character editor metadata v3, while performance/lighting remain operator
  preferences. Object appearance files and AnimaCore were not changed.
  Verification: 263 XCTest + 20 Swift Testing, recursive Swift format lint,
  generated Xcode project, native and root-app builds (including the bundled
  Metal library), deep signature verification, direct RealityKit
  `CustomMaterial` shader conversion smoke check, launch, and clean
  `git diff --check`.

- **2026-07-16 (Codex, removable/self-pruning recents):** Recent-project cards
  now reveal a compact top-right x on hover and expose **Remove from Recents**
  from the context menu. Both route through the root's single recents state and
  a persistence `remove(id:)` API, so the card disappears immediately and stays
  gone while the project folder is never touched. Bookmark resolution and the
  fallback path now share one existing-directory resolver with `openRecent`.
  Stored recents whose bookmark/path no longer reaches a directory are pruned
  and the cleaned list is persisted at launch; an entry that disappears during
  the session is also forgotten when opening detects it. Verification: 7
  focused persistence tests, including explicit on-disk preservation and
  persisted missing-entry pruning; 257 XCTest + 20 Swift Testing full suite;
  recursive lint; native Xcode/root-app build; deep signature verification;
  launch; `git diff --check` clean.

- **2026-07-16 (Codex, imported-mesh feature selection):** Added a cached,
  renderer-side topology projection for STL, OBJ, and ModelIO-readable USD
  geometry. Import now welds duplicated vertices, groups connected coplanar
  triangles into face islands, extracts boundary/sharp-normal edge polylines,
  and identifies vertices where at least three feature edges meet. Exact mesh
  face, edge, and corner proxies feed the existing `MateConnectorCandidate`
  contract, with cyan hover, stronger orange committed selection, zoom-adjusted
  edge/corner picking, owning-component selection, navigator reveal, staged
  Escape, and mate-placement feedback. The existing directional box selection
  remains left-to-right blue/solid window containment and right-to-left
  yellow/dashed crossing intersection; its pure classification and selection
  rules are now covered alongside cube topology, welded STL vertices, USD
  subtree transforms, topology caching, and feature-hit integration. This is a
  pragmatic mesh projection, not analytic CAD B-rep topology; topology-changing
  reimports do not yet remap durable feature identities. Verification: 7
  focused topology tests; 255 XCTest + 20 Swift Testing full suite; recursive
  format lint; native Xcode build; rebuilt/deep-signed root app, signature
  verification, and launch; `git diff --check` clean.

- **2026-07-16 (Codex, ViewCube projected decals + camera roll):** Replaced
  center-positioned, fixed-size cube labels with affine face decals derived
  from each face's projected vertex spans. The text center is locked to the
  projected face center, both text axes foreshorten with the face, a determinant
  and baseline correction prevent mirrored/upside-down labels, and rear or
  near-edge-on slivers do not draw labels. The old `labelPosition` and
  `labelRotationRadians` helpers are removed. Existing face/edge/corner hit
  testing, hover feedback, the positive XYZ triad, and four 15-degree orbit
  arrows remain unchanged.

  `PreviewCameraOrientation` now carries a normalized renderer-neutral roll
  angle. RealityKit applies it around the camera's local forward axis and
  returns it with camera state; ViewCube face/axis projection consumes the same
  angle. Curved counterclockwise/clockwise controls appear at the cube's top
  corners only when one principal face is head-on and issue real 90-degree
  roll commands. Selecting a principal direction or normal camera preset resets
  roll to the canonical upright view. Verification: 10 ViewCube + 4 camera
  focused tests; full `swift test` = **248 XCTest + 20 Swift Testing**; recursive
  format lint and `git diff --check` clean; native Xcode build and rebuilt,
  deeply verified root app pass; the replacement root app launched. Automated
  screen capture remains unavailable under the host's Screen Recording policy.

- **2026-07-16 (Codex, DH articulated-arm app UI):** The Swift front end now
  detects `rig.kinematic_chain` and decodes its ordered revolute/prismatic
  joint contract without adding any kinematic meaning to Swift. The Rig
  inspector renders one limit-bounded jog control per engine joint, converts
  radians/metres to degrees/mm only at the display boundary, sends edits to
  `forward_kinematics`, and applies the returned character-space link/tool
  frames to RealityKit. A dedicated cyan XYZ/rotation target is placed at the
  tool; dragging it calls `solve_ik` using the current joints as seed. Reached
  results update all sliders and link frames; unreachable targets remain
  visible in orange with position/orientation residuals while the last valid
  pose stays rendered. Requests are revision-guarded so stale drag/jog replies
  cannot overwrite newer input.

  The root helper packager now embeds NumPy alongside AnimaCore and PyYAML;
  the rebuilt/deep-signed root app launched successfully. The embedded Python
  framework imported `animacore.bridge` + NumPy 2.4.6 and its live hello
  advertised `forward_kinematics`/`solve_ik`. Verification: recursive Swift
  format lint clean; `swift test` = **240 XCTest + 20 Swift Testing**, all
  passing, including real subprocess DH decode → FK → IK and workspace
  jog/IK → renderer pose tests; Xcode build and root app build/sign passed;
  `git diff --check` clean. Changed files are exactly the released claim above.

- **2026-07-16 (Claude, DH3 — kinematic_chain arm rig type + bridge
  FK/IK verbs):** The DH articulated-arm rig type is COMPLETE — an arm is
  now a real savable rig the app drives. **Additive** across
  rig/kinematics/loader/serialize/bridge; every prior test unchanged
  (1013 → **1043**, +28 in the new `test_kinematic_chain.py` + 2
  example-discovered), ruff clean, no `app/`/`firmware/` touched.

  **Model (`animacore/rig.py`).** `Rig` gains
  `kinematic_chain: KinematicChain | None = None`. New dataclasses
  (defined in rig.py, wrapping `animacore.dh`):
  - `ChainJoint` — one DH link as a DOF: `name`, `a_m`/`d_m` (metres),
    `alpha_rad`/`theta_rad` (radians), `joint_type` (`JointKind`
    revolute/prismatic), `min`/`max`/`neutral` (the joint variable, rad
    for revolute / m for prismatic), optional `part` that RIDES the link
    frame. `.as_dof()` → `RotationDof`/`TranslationDof` (so it validates
    and clamps exactly like a mate DOF); `.to_dh_link()` → `DHLink`.
  - `KinematicChain` — `name`, ordered `joints`, optional `base_part`
    (its rest transform is the chain base frame in character space),
    optional `tool_part`, `tool_position_m` + `tool_rotation_euler_rad`
    (tool offset). `.dof_paths()` keys DOF `"<name>.<joint>"`;
    `.to_dh_chain(base_frame)` builds the `DHChain`.
  - `Rig.chain_dof_paths()` (chain DOF, separate from mate `dof_paths()`
    so a suppressed-joint prefix lookup stays valid) and `Rig.dh_chain()`
    (resolves `base_part`'s rest transform → the full `DHChain`).
  Chain DOF share the clip-target namespace with mate DOF (a collision is
  a load/validation error) and may map to output channels. `evaluate_pose`
  includes chain DOF (drivable, neutral fallback); `resolve_pose`
  (`animacore/kinematics.py`) places each `ChainJoint.part` on its DH link
  frame and `tool_part` on the tool pose, **overriding** the rest-transform
  root placement — non-chain rigs untouched.

  **Format (`loader.py` + `serialize.py`).** New top-level
  `kinematic_chain` block round-trips losslessly (`load → serialize →
  load` equal, proven for the example). File units mirror the DOF
  convention: `a_m`/`d_m` metres, `alpha_deg`/`theta_deg` degrees→radians,
  per-joint `limits` (`min_deg`/`max_deg` revolute, `min_m`/`max_m`
  prismatic) + `neutral_deg`/`neutral_m`, optional `part`; chain
  `base_part`/`tool_part`/`tool{position_m,rotation_euler_deg}`. Typed
  pathed `CharacterFormatError`s (unknown field, unknown joint type,
  wrong-unit neutral key, missing part, empty joint list).

  **Bridge (`bridge.py`) — verbatim verb JSON for Codex's arm UI:**
  - `load_character` rig summary gains `kinematic_chain` (null for a
    general assembly), joints in native units with `dof_path`;
    `rig_from_dict` reconstructs it (serialize round-trip proven).
  - `forward_kinematics` — request
    `{"handle":"rig1","joint_values":{"j1":0.3,"j2":-0.5,...}}` (missing
    joints → neutral); response
    `{"link_frames":[{"position":[x,y,z],"orientation":[x,y,z,w]},...],
    "tool_pose":{"position":[x,y,z],"orientation":[x,y,z,w]}}`. Frames are
    **character-space** (base = `base_part`'s rest transform).
  - `solve_ik` — request
    `{"handle":"rig1","target_pose":{"position":[x,y,z],
    "orientation":[x,y,z,w]},"seed":{"j1":0.0,...}}` (`seed` optional →
    neutral); response
    `{"joint_values":{"j1":...,"j2":...},"reached":true,
    "position_error_m":2.0e-5,"orientation_error_rad":...,"iterations":4}`.
    Reports non-convergence honestly (`reached:false` + residuals, no
    raise). Both error `no_kinematic_chain` on a non-arm rig,
    `unknown_handle` on a bad handle, `kinematics_error` on a `DHError`.
    Added to `CAPABILITIES`.

  **Example.** `examples/six_axis_arm_dh.character.anima` — UR5-style 6R
  arm as a `kinematic_chain` (link parts ride the DH frames, gripper tool
  part, a `reach` clip driving the joints, six `arm.j*` output channels).
  Kept the mate-based `six_axis_arm.character.anima` as the
  general-assembly counterpart. **Confirmed:** it loads, round-trips,
  `resolve_pose` places `forearm`/`gripper` at the exact
  `forward_kinematics` link/tool frames, and a bridge FK→IK→FK loop
  reaches the target (`reached=true`, pos residual ~2e-5 m, 4 iters).

  DH4 (analytic per-geometry IK) is the only remaining DH packet. Left
  uncommitted for main-session integration.

- **2026-07-16 (Codex, native Settings + default workspace root):** Added a
  standard SwiftUI `Settings` scene with Workspace, Navigation, and Appearance
  tabs. `WorkspaceLocationPreference` is the single filesystem/UI truth:
  default `~/Documents/Anima Studio/`, optional custom path plus app-scoped
  security bookmark, lazy directory creation, closest-existing panel fallback,
  and restore-default support. New/Open/Save As all use it. The existing CAD
  mouse panel now lives inside Navigation; its viewport shortcut opens Settings
  directly on that tab. Unit tests cover default resolution, lazy creation,
  custom persistence, and reset. Verification: recursive format lint; `swift
  test` = 240 XCTest + 16 Swift Testing, all green; native Xcode build and root
  app build/deep-sign succeeded; launch registered an enabled standard
  **Settings…** app-menu command. The real launch audit found an existing invalid
  Recent Projects SF Symbol (`folder.badge.checkmark`) that aborted SwiftUI
  window construction for users with recents; replaced it with a validated
  symbol. The focused Xcode UI-test source was added, but command-line execution
  remains blocked by the pre-existing Xcode target/product mismatch
  (`AnimaStudio` target vs `Anima Studio.app` product), which should be repaired
  as its own project-generation packet rather than changing the app product
  name in this UI change.

- **2026-07-16 (Codex, first-run workspace-root correction):** Changed the
  canonical default to `~/Documents/AnimaStudio/` (no space), added the
  standard Documents usage description, and removed the panel paths' silent
  closest-existing-directory fallback. The live sandbox walkthrough found that
  there is no effective static Documents entitlement, so first use now asks the
  operator to select Documents once, creates and bookmarks `AnimaStudio`, then
  continues to the project panel; relaunch goes straight there. Custom roots
  remain intact, and a stored reference to the former spaced default migrates.
  Focused tests cover exact creation, real-vs-container resolution, and
  migration. Verification: focused preference tests = 8 green; full suite =
  245 XCTest + 20 Swift Testing, all green; recursive format lint clean; native
  Xcode/root-app build and deep signature green; `git diff --check` clean. A
  clean live sandbox walkthrough showed **Allow Anima Studio Project Access**,
  then created the real `~/Documents/AnimaStudio/` (no container copy) and
  opened **Create Anima Studio Project** with `Untitled Project` and Where =
  `AnimaStudio`; relaunch skipped the grant picker and opened there directly.
  The final root app is rebuilt and launched.

- **2026-07-16 (Claude, DH2 — inverse kinematics, damped least-squares):**
  Closed the FK↔IK loop for the articulated-arm chains. Extended
  `animacore/dh.py` (+ `tests/test_dh.py`, now 34 tests) with a numerical
  IK solver; `numpy>=1.26` added to `pyproject.toml` `[project].dependencies`
  (installs to 2.4.6 here, `pip install -e ".[dev]"` re-verified so CI's
  install keeps working). numpy is used **only** in the IK path — FK stays
  pure stdlib. No rig/loader/serialize/bridge/kinematics.py touched (DH3 is
  separate). 1005 → **1013 tests** (+8 IK test functions), `.venv/bin/ruff
  check .` clean. Left uncommitted for main-session integration.

  **API:**
  - `solve_ik(chain, target_pose: Transform, *, seed: Sequence[float] | None
    = None, position_tolerance_m: float = 1e-4, orientation_tolerance_rad:
    float = 1e-3, max_iterations: int = 100, damping: float = 0.05) ->
    IKResult`.
  - `IKResult(frozen)`: `joint_values: tuple[float,...]` (always within each
    link's limits), `reached: bool`, `position_error_m: float`,
    `orientation_error_rad: float`, `iterations: int` (DLS updates applied; 0
    when the seed already satisfies the target).

  **Algorithm:** damped least-squares (Levenberg–Marquardt) on the **6×N
  geometric Jacobian**. Start `q = seed` (or `chain.neutral_values()`),
  clamped to limits. Each iteration runs `forward_kinematics` and builds the
  Jacobian from the cumulative link frames: for joint `i` (0-based) the axis
  is the world Z of `frame_i` where `frame_0 = base_frame` and
  `frame_k = link_frames[k-1]` (standard-DH: joint `i`'s variable acts about
  z of frame `i−1` in 1-based terms). Revolute column `[z × (p_tool − p_i);
  z]`, prismatic column `[z; 0]`. Error twist `e = [target_p − tool_p;
  rotvec]`, the orientation term being the axis·angle of `q_target ·
  q_current⁻¹` on the **shortest path** (real part flipped non-negative).
  Update `Δq = Jᵀ (J Jᵀ + λ²I)⁻¹ e` via `np.linalg.solve` on the 6×6 system
  (no explicit inverse), then `q += Δq` **clamped to each DHLink min/max**.
  Converges when `|pos| < position_tolerance_m` AND `|ori| <
  orientation_tolerance_rad` → `reached=True`. After `max_iterations` without
  convergence → `reached=False` carrying the final residuals — **does NOT
  raise** (an unreachable target is a legitimate answer). The only raise is
  `DHError` on a `seed` whose length ≠ `chain.dof`.

  **Round-trip result (the key test):** FK a random-but-fixed config →
  target pose, then `solve_ik` from a **different** (perturbed) seed, asserts
  `reached` and that FK(solved) matches the target on probe points. **Yes —
  IK reaches FK-generated targets for both the planar 2R and the 6R UR5**
  (asserts POSE equality, not joints, since redundant/elbow-flip solutions
  differ). Also covered: honest non-convergence for a target metres outside
  the workspace (`reached=False`, large finite residual, no crash),
  joint-limit respect (clamped solution stays within every `[min,max]` and
  is a valid FK input), zero-iteration convergence when the target equals the
  seed's FK pose, prismatic-slider IK reaching a translated target, and
  determinism (identical `IKResult` for the same chain+target+seed; tests use
  a fixed-seed `numpy.default_rng`, no wall-clock).

  **Ceilings (`# ponytail:` in the module):** single-seed (no random-restart
  for tough/near-singular targets — a hard basin just reports
  `reached=False`), geometric-Jacobian DLS (no null-space/redundancy
  resolution, no collision avoidance), purely numerical. Analytic
  per-geometry closed-form IK for spherical-wrist arms is **DH4**. Damping
  trades a little accuracy near singularities for stability.

  **Next:** DH3 = `kinematic_chain` block in the character format +
  loader/serialize + arm rig type + bridge `forward_kinematics`/`solve_ik`
  verbs — consumes `solve_ik`/`IKResult` and `forward_kinematics` unchanged.

- **2026-07-16 (Codex, reusable tree + persistent per-object state):** Replaced
  the navigator-specific tree mechanics with a generic `TreeNode` adapter,
  pure `TreeModel`, and reusable SwiftUI `TreeView`; both Instances and Mate
  Features now use it. Added ancestor-preserving token filters, viewport→tree
  reveal, **Go to Item in List**, lock/hidden/suppressed/grounded badges, and
  pre-feedback drop validation. Pure tests cover reorder, reparent, grouping,
  filtering, and invalid descendant/locked drops. Engine summaries/retained DTO
  edits now carry part rest transforms plus part/mate/relation object states;
  editor JSON v2 carries appearance/finish/visibility, groups, order, locks,
  and disclosure. RealityKit applies intrinsic-XYZ rotations below an explicit
  character root. One Save writes canonical engine text and editor metadata;
  the integration suite reopens position, metallic appearance, visibility,
  group membership, and locks. Verification: recursive Swift format lint;
  `swift test` = 237 XCTest + 16 Swift Testing, all green; Xcode build and root
  app build/deep-sign succeeded; root app launched. During the required mate
  suppression walkthrough, the audit found the AnimaCore `project_channels`
  crash recorded in Requests; no backend file was edited or worked around in
  Swift.

- **2026-07-16 (Claude, DH1 — Denavit-Hartenberg chain + forward
  kinematics):** Shipped the standalone articulated-arm FK foundation in
  a **new self-contained module** `animacore/dh.py` (+ `tests/test_dh.py`,
  26 tests). No rig/loader/serialize/bridge/kinematics.py code touched —
  DH2 (IK) and DH3 (character-format `kinematic_chain` block + bridge
  verbs) are the integration packets. Stdlib + `math` + reused
  `kinematics.Transform` only, **no numpy** (numpy arrives with DH2's
  damped-least-squares IK, per `DH_Kinematics.md`). 979 → **1005 tests**
  (+26), `.venv/bin/ruff check .` clean. Left uncommitted for
  main-session integration.

  **Convention: STANDARD (distal) DH** — not modified/Craig/proximal (the
  two place the link frame differently and are not interchangeable). The
  per-link transform is `A = Rotz(theta_eff) · Transz(d_eff) · Transx(a)
  · Rotx(alpha)`, composed left-to-right as `compose(compose(compose(
  Rotz, Transz), Transx), Rotx)` so `A.apply_point(p)` applies `Rotx`
  innermost. Chain pose `T = base_frame · A_1 · … · A_n · tool_frame`.
  Verified against the planar-2R closed form (`x = L1 cos q1 + L2
  cos(q1+q2)`, `y = …`) and an **independent 4x4 homogeneous-matrix**
  reference for a 6R UR5-style arm (separate code path from the
  quaternion `Transform` composition).

  **API (DH3 will build the character-format block + bridge verbs on
  this):**
  - `JointKind(StrEnum)`: `REVOLUTE` (`theta` is the joint variable, `d`
    fixed) / `PRISMATIC` (`d` is the variable, `theta` fixed).
  - `DHLink(frozen)`: `a`, `alpha`, `d`, `theta` (metres / radians;
    `theta` and `d` are the *home offset* the joint variable adds to),
    `joint_type: JointKind = REVOLUTE`, `min`/`max`
    (`float | None`, inclusive limits on the **joint variable**),
    `neutral: float = 0.0`. `.variable` → `"theta"`|`"d"`;
    `.within_limits(v)`; `__post_init__` raises `DHError` on inverted
    limits / neutral out of range.
  - `DHChain(frozen)`: `links: tuple[DHLink, ...]`, `base_frame:
    Transform = IDENTITY` (chain root in character space), `tool_frame:
    Transform = IDENTITY` (end-effector offset). `.dof` = len(links);
    `.neutral_values()`; empty chain rejected.
  - `link_transform(link, joint_value) -> Transform`.
  - `forward_kinematics(chain, joint_values) -> DHForwardResult(
    link_frames: tuple[Transform,...], tool_pose: Transform)`. Cumulative
    frames `frame_i = compose(frame_{i-1}, A_i)` (base-relative);
    `tool_pose = compose(frame_n, tool_frame)`.
  - `DHError(ValueError)` — typed. **Decision: RAISE (never clamp)** on a
    joint value outside limits or a wrong joint-value count, message
    naming the 0-based joint index, so IK/callers see violations. Chosen
    over clamping because IK must know the constraint is active.

  **Next (not in this packet):** DH2 = damped-least-squares IK (numpy,
  Jacobian, joint-limit clamping); DH3 = `kinematic_chain` block in the
  character format + loader/serialize + arm rig type + bridge
  `forward_kinematics`/`solve_ik` verbs. Both consume this module's
  `DHChain`/`forward_kinematics` unchanged.

- **2026-07-16 (Claude, part rest transform + coordinate-frame model):**
  Parts now carry a **LOCATION** (a rest transform) that persists in the
  `.character.anima` and drives `resolve_pose`, so a part the app moved
  survives Save. **Additive: defaults are the zero transform → identity,
  so every existing file/test is byte- and behavior-unchanged (966 → 979,
  +13).** The frame model Jonathan named is now explicit and normative in
  the new `dev/docs/roadmap/Coordinate_Frames.md`: **World → Character →
  Part**, with custom named reference frames as a future extension (mate
  connectors are the first instance).

  **Rest-transform field shapes** (`animacore/rig.py` `Part`, both
  default the zero 3-tuple, validated as 3-tuples):
  - `position_m: tuple[float, float, float]` — the part origin's position
    in **CHARACTER** space, metres.
  - `rotation_euler_rad: tuple[float, float, float]` — rest orientation,
    **XYZ Euler radians** (matches the app's `rotationEulerRadians`).

  This is **part-in-character** (part space → character space), NOT
  world. World placement of a character is a separate scene-level
  transform (Character-in-World, default identity when authoring one
  character; becomes real in the scene format).

  **Euler convention (Codex MUST match it in Swift):** **intrinsic XYZ**
  Tait-Bryan. Rotate local X by `rx`, then new local Y by `ry`, then new
  local Z by `rz`. Quaternion (real part last) `q = qx ⊗ qy ⊗ qz`; matrix
  `R = Rx·Ry·Rz`; a point transforms as `R·p` (Z innermost). Engine
  builder: `kinematics.Transform.from_euler_xyz(rx, ry, rz)`. Build the
  same `simd_quatf` product X→Y→Z so a saved orientation renders
  identically in both. (`# ponytail:` Euler is the interchange shape to
  match the inspector fields; gimbal-lock ceiling accepted for static
  rest placement — quaternions stay the internal truth.)

  **`resolve_pose` root/grounded/mated rules** (output is now documented
  **character-space**):
  - **ROOT** (no active incoming joint) → resolves at its **rest
    transform** (was identity).
  - **GROUNDED** → resolves at its **rest transform**, overriding any
    incoming joint (was "grounded → identity"; it's a fixed anchor at its
    authored location).
  - **MATED child** → positioned by its mate via `child_in_parent`; its
    own rest transform is pre-mate only and is **NOT** applied on top (no
    double-apply — proven by a test where two rigs differing only in the
    mated child's rest position resolve the child identically).
  - Orphan/unreachable non-suppressed part → root at its rest transform.
  - Suppressed semantics intact (unchanged).

  **File keys** (`animacore/loader.py` / `serialize.py`): `position_m:
  [x,y,z]` (metres) and `rotation_euler_deg: [rx,ry,rz]` (**degrees in
  the file**, radians in the model — consistent with DOF limits/offsets).
  Both optional, default zero, **emitted only when non-zero** (clean
  output, lossless round-trip). Typed pathed errors
  (`parts.<name>.position_m`).

  **Codex — bridge DTO (additive, nothing renamed):** the
  `load_character` part entry now also carries `position_m` (list, metres)
  and `rotation_euler_rad` (list, **native radians** like other DOF
  descriptors — convert to degrees for display in the inspector).
  `serialize_character` / `rig_from_dict` round-trip both. So: the triad
  / gizmo edit on a FREE (root/grounded) part writes `position_m` +
  `rotation_euler_rad` back through `serialize_character`; a MATED part's
  drag still routes to its DOF (the mate owns placement — the rest
  transform is not applied while mated). Character-in-World stays a
  scene-level concern; keep it out of the character DTO.

  **Example:** `examples/pan_tilt_head.character.anima` `base` (the
  assembly root) now has `position_m: [0,0,0.25]` + `rotation_euler_deg:
  [0,0,30]`, so the whole head is anchored 0.25 m up and yawed 30°;
  `resolve_pose` reflects it (asserted). Round-trip proven
  (set position+rotation → serialize → load → equal, deg↔rad tolerant).
  979 tests, ruff clean, no `app/`/`firmware/` touched. Left uncommitted
  for main-session integration.

- **2026-07-16 (Claude, persistent object states — suppress + ground):**
  A user can suppress an object or ground a part, save, quit, relaunch —
  and it stays that way, because these are now **rig-semantic states in
  the canonical `.character.anima`**, not app view-state. **Additive:
  every field is an optional `bool` defaulting `False`, so existing files
  and every prior test are byte- and behavior-unchanged.** Distinct from
  the app's `hidden`/`lock` view-state (transient UI, stays app-side, NOT
  in the format).

  **Field shapes** (all default `False`, emitted to the file only when
  `True`):
  - `Part.suppressed: bool`, `Part.grounded: bool`
  - `Joint.suppressed: bool`
  - `Relation.suppressed: bool`

  File keys are literally `suppressed:` / `grounded:` on the part / joint
  / relation entry; loader parses them via `_bool` with a pathed error on
  a non-bool (`parts.<n>.suppressed`, `joints.<n>.suppressed`,
  `relations[i].suppressed`, `parts.<n>.grounded`).

  **Exact solve semantics (so the tree toggles wire correctly)** —
  deterministic, per-element, **no cascade**:
  - `evaluate_pose` (`rig.py`): a **suppressed joint** contributes no
    driven DOF — its DOF are excluded from `dof_values` entirely (not read
    from clips, not neutral-filled). A **suppressed relation** is skipped
    (its driven DOF keeps its own neutral); a relation whose driver/driven
    DOF sits on a suppressed joint is likewise skipped (no dangling ref).
    All non-suppressed behavior is byte-identical.
  - `resolve_pose` (`kinematics.py`): FK walks only ACTIVE elements. A
    **suppressed part** is EXCLUDED from the output dict and any joint
    touching it (parent OR child) is inactive. A **suppressed joint** is
    skipped (its child is not positioned by it). A **grounded part** is a
    FIXED ROOT at `IDENTITY` even with an incoming joint — **ground
    overrides the joint** (that joint is inactive). **Orphan rule:** a
    non-suppressed part whose only positioning path runs through a
    suppressed/inactive joint (or a suppressed parent) has no active
    incoming joint, so it resolves as an identity root (floats to origin).
    `suppressed` + `grounded` on one part → suppressed wins.

  **Codex — UI wiring:** the states are surfaced additively (nothing
  renamed): `load_character` rig-summary part entries gain
  `suppressed`/`grounded`; `describe_mate` gains `suppressed`;
  `describe_relation` gains `suppressed`. `serialize_character` /
  `rig_from_dict` round-trip all four, so the full-fidelity DTO stays
  lossless. To make "suppress a folder → everything under it vanishes,"
  suppress the member PARTS (there is no engine cascade — `# ponytail:`
  kept deliberately simple and explicit).

  **Persistence proof:** the round-trip test builds a rig, suppresses a
  joint + a part, grounds a part, suppresses a relation, `rig_to_yaml` →
  `parse_character`, and asserts every state survived (and defaults stay
  `False`). Files: `animacore/{rig,kinematics,loader,serialize,bridge,
  mates}.py`, new `animacore/tests/test_object_states.py` (22 tests),
  `dev/docs/roadmap/Character_Format.md` (new "Object states" section),
  `dev/docs/reality/STATUS.md`. Verified: `.venv/bin/ruff check .` clean,
  `.venv/bin/pytest animacore/tests -q` = **966 passed** (+22). No
  `app/`/`firmware/` touched. Left uncommitted for main-session
  integration.

- **2026-07-16 (Codex, portable rigid-part model import):** Added native
  USD-family loading and ModelIO STL/OBJ-to-RealityKit conversion, with an
  operator-facing mm/cm/m choice for unitless files and persisted metre scale.
  STEP/STP selection now explains that CAD conversion to STL or USD is required.
  Imports copy to collision-safe `characters/<name>/assets/<file>` paths; Swift
  edits only AnimaCore's full-fidelity rig DTO, then calls
  `serialize_character` and reloads it. The typed bridge now carries each
  Part's `model`; hierarchy-node mapping authors `model_node`; per-Part renderer
  sources inherit canonical `resolve_pose` transforms and restore on project
  reopen from `<character>.editor.json`. Tests use real STL/OBJ fixtures and a
  live serialize/reload asset-reference proof. Changed the claimed Swift source,
  tests, Xcode project generation output, STATUS/roadmap docs, and briefings
  listed in the released claim. Verification passed: recursive Swift format
  lint, 216 XCTest cases + 14 real-bridge Swift Testing cases, `git diff
  --check`, native Xcode build, root-app rebuild/deep signing, and live launch;
  both the app and embedded `animacore.bridge` remained alive.

- **2026-07-16 (Claude, per-part asset file reference — portable
  multi-file assemblies):** A character is an ASSEMBLY of rigid parts
  (parametric-assembly paradigm, not a skinned mesh); the saved
  `.character.anima` now records WHICH asset file each part uses so a
  `characters/<name>/` folder (with its `assets/`) is portable and
  reopens correctly. **Additive, engine stays mesh-agnostic — it never
  parses geometry; these are opaque strings it round-trips.**

  **`Part` DTO shape (new `model` field, everything else unchanged):**
  ```
  Part(name: str,
       parent: str|None = None,
       model_node: str|None = None,   # node WITHIN a multi-node file (e.g. USD subtree); null for single-mesh STL
       description: str = "",
       model: str = "")               # NEW: opaque relative path to the part's asset FILE within assets/
  ```
  `load_character` rig-summary part entry (bridge) is now
  `{name, parent, model_node, description, model}` — `model` **added**,
  nothing renamed; empty string `""` when the part has no geometry.
  Serializer emits `model:` in the part dict only when non-empty (omit
  when empty, clean-output convention); `model_node` behavior unchanged.

  **What Codex sets on import:** copy the imported mesh into the active
  character's `assets/`, then set that part's `model` to the file's path
  **relative to the character folder** — e.g. `model: "assets/head.stl"`,
  `model: "assets/robot.usdz"`. STL / OBJ / STEP / USD are all treated
  identically (engine never interprets the mesh). Two shapes:
  - **Multi-file assembly** (several STL parts): each part gets its own
    `model`, no `model_node`.
  - **Single multi-node USD**: parts share one `model` and each carries
    a distinct `model_node` (the node inside that file).

  **Validation rules on `model` (a non-empty value must be a SAFE
  RELATIVE path):** rejected with a typed error —
  - absolute path (leading `/`) → rejected;
  - `..` traversal segment → rejected;
  - empty segment (leading / trailing / doubled `/`) → rejected;
  - empty string is legal (part has no geometry).
  Loader raises `CharacterFormatError` naming `parts.<name>.model` on an
  unsafe path; the `Part` dataclass re-validates defensively (typed
  `ValueError`). So the app can set `model` from the copied file's
  character-relative path without any extra guarding — the engine
  refuses anything that could escape the character folder.

  New example `examples/pan_tilt_head.character.anima` (3-part pan-tilt
  assembly: `base`/`yoke` = single-mesh STL with `model` only; `head` =
  a USD node with both `model` + `model_node`) exercises the round-trip.
  Tests: `Part` accept/reject (test_rig), loader parse + pathed errors
  (test_loader), serialize round-trip + empty-omission (test_serialize),
  bridge summary + DTO round-trip (test_bridge). 944 suite total (+17),
  ruff clean, no `app/`/`firmware/` touched. Left uncommitted for
  main-session integration.

- **2026-07-16 (Codex, engine-driven Relations UI):** Added typed Swift bridge
  projections for `relation_types` and `load_character.relations`; the client
  requests the four-entry catalog alongside mates. The Rig ribbon now presents
  Gear, Rack and pinion, Screw, and Linear directly from that catalog. One
  shared draft dialog filters Driver/Driven DOFs by the engine's required kinds,
  shows the correct positive ratio or mm/revolution field, keeps Reverse as a
  separate control, and previews the signed native value without mutating the
  character. Imported relations appear in the navigator and a dedicated
  read-only inspector. Selecting one splits its two DOF paths at the joint name,
  resolves the engine mates, and highlights their child components in
  RealityKit; no relation evaluation or dependency semantics were added in
  Swift. Live proof: the rc_car rack reads `125.663706 mm/rev` and the UI
  conversion previews `0.02 m/rad`. Verification passed: 220 XCTest cases plus
  11 real-bridge Swift Testing cases, recursive format lint, `git diff --check`,
  native Xcode build, root-app build, bundled-helper embedding, strict deep
  signing, and launch with the app/helper still alive.

- **2026-07-16 (Codex, all-ten-mate UI + canonical engine pose):** Studio now
  decodes the engine's ten-type `mate_types` catalog, including category,
  drivable state, and per-DOF axis. The production inspector and UI Dev Mate
  Editor share the complete family; Width and Tangent render as distinct
  non-drivable geometry constraints, while Tangent exposes its surface and
  propagation payload instead of fabricated connector/offset controls. Imported
  characters call `evaluate` plus `resolve_pose` at the playhead and apply the
  engine's metre positions and real-last quaternions directly to renderer-only
  RealityKit proxies. The duplicate Swift `RigPoseResolver` and
  `MateConnectorMath` implementations were removed; connector basis math left in
  the viewport is presentation-only. The transitional local Revolute action now
  records connector selections without locally solving motion. Verification:
  all 218 XCTest cases plus 9 real-bridge Swift Testing cases passed; recursive
  Swift format lint and `git diff --check` passed; Xcode and root-app builds
  passed; the root bundle passed strict deep signature verification; the
  launched app and bundled `python -m animacore.bridge` process remained alive.

- **2026-07-16 (Claude, Engine serialization — the project-Save write
  side, BR-SAVE):** The engine now WRITES canonical `.anima`, not just
  reads it — one format author. New `animacore/serialize.py` is the pure
  inverse of the loaders: `rig_to_dict`/`rig_to_yaml` (Rig →
  `.character.anima`), `scene_to_dict`/`scene_to_yaml` (Scene →
  `.scene.anima`). Units mirror the loader (rotation → **degrees** in
  file, metres kept; scenes carry NO unit conversion — the AST stores
  file units). Defaults are omitted, not echoed (`simulation_connection:
  true`, disabled zero offset, all-default `controls`, `loop: false`,
  `linear` interp, zero relation offset), so output is minimal yet
  round-trips. `bridge.py` gains two verbs (in CAPABILITIES):
  **`serialize_character`** `{rig}` → `{text}` and **`serialize_scene`**
  `{scene}` → `{text}`; invalid → `format_error` (path when available).
  `serialize_character` rebuilds a `Rig` from the DTO via `rig_from_dict`
  (native units in — exact, no double conversion) then `rig_to_yaml`.

  **Round-trip proof (acceptance):** `load_character(text)` →
  `serialize_character({rig})` → `load_character(text')` yields an equal
  rig for all four character examples (six_axis_arm: mates+connectors+
  offset+clip; rc_car: relation+unlimited wheel+parameter; walle_style:
  mixed joints+parameters; geometry_mates_demo: width/tangent), and the
  scene analog for both scene examples. Direct file round-trips
  (`test_serialize.py`) cover every `examples/` file; equality is
  float-tolerant on the degrees↔radians conversion (character) and exact
  AST `==` (scene). 927 suite total (+26), ruff clean, no
  `app/`/`firmware/` touched.

  **`load_character` enrichment — ADDITIVE, for Codex.** To make the
  bridge round-trip lossless the `load_character` rig summary now carries
  a few fields *beyond* the prior spec shapes — all **added**, none
  renamed/removed, so your existing `AnimaCoreClient` decode and
  `describe_mate` consumption are unaffected: (1) each **clip** gains
  `keyframes` — a list of per-time entries `{time_s, interpolation,
  values:{target: native_value}}` (radians/metres/0..1); (2) each
  **output** gains `value_at_zero` / `value_at_one` (the mapping range in
  native units — the old `{dof_path, channel}` keys stay); (3) each
  **joint** gains a top-level `description`, and each **dof** entry gains
  `name`, `axis_vector` (the file's `axis:` list, `null` when absent —
  distinct from the existing template `axis` string), and `description`.
  That's the exact DTO `serialize_character` accepts: hand back the same
  `rig` block `load_character` returned and it re-serializes losslessly.

  **Verbatim verb JSON (what your Swift client sends/parses):**

  ```
  // request
  {"id":7,"method":"serialize_character","params":{"rig": <the rig block
     from a load_character result — full-fidelity, unchanged>}}
  // response
  {"id":7,"ok":true,"result":{"text":"anima_version: '2.0'\ntype: character\n…"}}

  // request
  {"id":8,"method":"serialize_scene","params":{"scene": <the .scene.anima
     document dict — no load_scene verb yet, so this is the parsed-file
     structure: identity, character, variables, inputs, subroutines,
     sequence[…], monitors, editor>}}
  // response
  {"id":8,"ok":true,"result":{"text":"anima_version: '2.0'\ntype: scene\n…"}}

  // invalid rig/scene
  {"id":9,"ok":false,"error":{"code":"format_error","message":"…","path":"…|null"}}
  ```

  **For the app's Save flow:** per `Project_Format.md`, Studio writes the
  folder (`characters/<name>/<name>.character.anima`, `scenes/…`), but the
  `.anima` TEXT comes from these verbs — hand the engine the rig/scene,
  write the returned `{text}` atomically. There is no `load_scene`/
  `serialize_scene` DTO contract beyond "the parsed `.scene.anima`
  document shape" yet; flag it if the node-canvas → scene document needs a
  richer DTO and I'll spec a `load_scene` twin. Left uncommitted for
  main-session integration.

- **2026-07-16 (Codex, Assets-first startup + self-contained helper):** Changed
  the default new-project workspace from Rig to Assets and kept the initializer
  injectable for a later persisted startup preference. Diagnosed both supplied
  reports as the embedded Python helper: its Homebrew launcher execs a nested
  `Python.app`, whose load command still escaped to `/opt/homebrew` under the app
  sandbox. `embed-animacore-helper.sh` now rewrites both launch stages and the
  framework install id, then rejects remaining Homebrew paths.
  `build-root-app.sh` explicitly signs and verifies the modified nested Python
  app before sealing and verifying the outer app. Changed files are exactly the
  released claim above. Verification: 6 focused presentation tests; full Swift
  suite 217 XCTest + 7 Swift Testing cases; format lint; Xcode/root-app build;
  nested and deep strict signature verification; live project launch with a
  persistent bundled `Python -m animacore.bridge` child and no new crash report;
  `git diff --check`.

- **2026-07-16 (Claude, Relations bridge hook — `relation_types` verb +
  `relations` in `load_character`):** The relation twin of the mate
  hooks, **additive**. The engine already had the full relation model
  (`Relation`, `RelationKind`, `RELATION_KIND_DOF_KINDS`, validation,
  dependency-ordered `evaluate_pose`) — the gap was that the bridge did
  not surface it, so the Swift UI could not see relations. Added, all in
  `animacore/rig.py` beside the `Relation` model (the mate module does
  not know relation vocabulary): `relation_type_schema(kind)` /
  `all_relation_type_schemas()` (static per-kind palette catalog,
  mirroring `mate_type_schema` / `all_mate_type_schemas`) and
  `describe_relation(relation)` (per-instance descriptor, mirroring
  `describe_mate`). `bridge.py` gains the **`relation_types`** verb
  (in `CAPABILITIES`) and a **`relations`** array in the
  `load_character` rig summary. Every existing field/verb unchanged;
  `evaluate_pose`/`project_channels`/loader untouched. 901 suite total
  (+15), ruff clean, no `app/`/`firmware/` touched. Left uncommitted.

  **Verbatim `relation_types` result** (4 kinds, `RelationKind` order —
  the palette hook, no handle needed):

  ```json
  {
    "relation_types": [
      {"kind": "gear", "label": "Gear",
       "driver_kind": "rotation", "driven_kind": "rotation",
       "ratio_field": {"key": "relation_ratio", "unit": "ratio"},
       "reverse_supported": true},
      {"kind": "rack_pinion", "label": "Rack and pinion",
       "driver_kind": "rotation", "driven_kind": "translation",
       "ratio_field": {"key": "distance_per_revolution", "unit": "mm"},
       "reverse_supported": true},
      {"kind": "screw", "label": "Screw",
       "driver_kind": "rotation", "driven_kind": "translation",
       "ratio_field": {"key": "distance_per_revolution", "unit": "mm"},
       "reverse_supported": true},
      {"kind": "linear", "label": "Linear",
       "driver_kind": "translation", "driven_kind": "translation",
       "ratio_field": {"key": "relation_ratio", "unit": "ratio"},
       "reverse_supported": true}
    ]
  }
  ```

  **`describe_relation` — gear example** (negative ratio → reverse):

  ```json
  {"kind": "gear", "driver": "pinion.rotation",
   "driven": "wheel.rotation", "ratio": -0.5, "offset": 0.0,
   "reverse": true, "magnitude": 0.5, "ratio_field_value": 0.5,
   "display": {}}
  ```

  **`describe_relation` — rack_pinion example** (the rc_car steering
  rack, from `load_character` on `examples/rc_car.character.anima`):

  ```json
  {"kind": "rack_pinion", "driver": "steering.rotation",
   "driven": "rack.travel", "ratio": 0.02, "offset": 0.0,
   "reverse": false, "magnitude": 0.02,
   "ratio_field_value": 125.66370614359172,
   "display": {"pinion_diameter_mm": 40.0}}
  ```

  **Reverse / ratio-sign convention (what the dialog binds).** The
  engine stores exactly ONE signed `ratio` (the semantic truth). The UI
  never edits that sign directly — it shows a positive *magnitude* field
  plus a "reverse direction" checkbox and sends back the signed ratio.
  So `describe_relation` reports `reverse = ratio < 0` and
  `magnitude = abs(ratio)`, keeping the raw signed `ratio` alongside.
  To build a create/edit payload: `ratio = ±ratio_field_value_in_engine_units`,
  negated iff reverse is checked.

  **`ratio_field_value` (the number the dialog's one editable field
  shows), per kind.** GEAR/LINEAR: the unitless `abs(ratio)` directly
  ("Relation ratio", from Onshape's teeth pairing e.g. 20:40 → 0.5).
  RACK_PINION/SCREW: **distance-per-revolution in mm** — the engine
  stores `ratio` as **meters per radian**, one revolution is `2π`
  radians, so `ratio_field_value = abs(ratio) × 2π × 1000`. The UI
  inverts to store: `ratio = value_mm / 1000 / (2π)`. Verified
  round-trip: 25 mm → `ratio ≈ 0.0039789` → back to 25.0 mm.

  **For Codex building the relations palette + dialog:**
  - Palette: `relation_types` gives the four ribbon tools in order —
    Gear, Rack and pinion, Screw, Linear (label + kind). `driver_kind`
    / `driven_kind` (`"rotation"` | `"translation"`) tell you which
    mates/DOF are selectable on each side of the two-click flow (driver
    mate → driven mate → DOF picker if a mate has multiple eligible
    DOF), exactly mirroring `mate_types` for mates.
  - Dialog: one editable numeric field named by `ratio_field.key`
    (`relation_ratio` unitless, or `distance_per_revolution` in mm) plus
    the always-present "reverse direction" checkbox
    (`reverse_supported: true` for all four). Bind the field to
    `ratio_field_value` and the checkbox to `reverse`.
  - Navigator list: iterate the `relations` array from `load_character`
    (under Mates, per Kinematics §5). Each entry carries `driver` /
    `driven` DOF paths for highlighting both coupled mates on selection,
    and the passthrough `display` map (teeth / diameter / lead) for any
    secondary readout.
  - No new verb params, no rig mutation verb yet — this packet is the
    read/catalog side only (create/edit authoring is the app's K6 lane).

- **2026-07-15 (Claude, Width + Tangent mates — geometry-constraint
  category):** Added the two Onshape mates beyond the 8, **additively**
  — the eight kinematic mates' behavior and their `mate_types` /
  `describe_mate` shapes are unchanged; only a `category` field and the
  two new types were added. Files: `animacore/mates.py` (new
  `JointType.WIDTH`/`TANGENT`, `MateCategory` StrEnum + `mate_category`
  helper, `TangentSpec` dataclass, per-type control-id lists, schema
  `category`/`drivable`/`note`, tangent-aware `describe_mate`),
  `rig.py` (Joint gains optional `tangent: TangentSpec | None`;
  geometry-constraint validation), `loader.py` (type-specific field
  sets + `type: width`/`type: tangent` parse with typed pathed errors),
  `kinematics.py` (width resolves via the existing 0-DOF connector path;
  tangent early-returns IDENTITY — `# ponytail:` marks the geometry
  ceiling), `bridge.py` comment. `examples/geometry_mates_demo.character.anima`
  loads end-to-end (a driven revolute + a width + a tangent). 886 tests
  (+43), ruff clean, no `app/`/`firmware/` touched. Left uncommitted.

  **Architecture (confirmed with Jonathan):** the existing 8 are
  KINEMATIC mates (abstract connector frames + DOF; the engine owns
  their motion). Width and Tangent are GEOMETRY-CONSTRAINT mates that
  depend on real surface geometry, which lives in the APP (RealityKit),
  not the abstract engine. The engine **recognizes, round-trips, and
  catalogs** them; their geometry is resolved app-side. Width, once the
  app supplies the two computed midplane connectors, resolves like a
  0-DOF fastened at the centered position. Tangent is deferred (no
  geometry kernel) — recognized, round-tripped, marked non-driving.

  **`mate_types` now returns 10** (JointType order: the 8 kinematic,
  then width, then tangent). **Verbatim width schema JSON:**
  ```json
  {
    "type": "width",
    "label": "Width",
    "category": "geometry_constraint",
    "drivable": false,
    "dof_count": 0,
    "universal_controls": ["connector_a", "connector_b",
                           "flip_primary_axis", "simulation_connection"],
    "dofs": [],
    "note": "Geometry-constraint mate: the app selects two faces on a tab part and two faces on a width part and centers the tab symmetrically between them (midplane to midplane). No offset. Once the app supplies the two computed midplane connectors the engine resolves it as a 0-DOF fastened at the centered position."
  }
  ```
  **Verbatim tangent schema JSON:**
  ```json
  {
    "type": "tangent",
    "label": "Tangent",
    "category": "geometry_constraint",
    "drivable": false,
    "dof_count": 0,
    "universal_controls": ["tangent_selection_a", "tangent_selection_b",
                           "tangent_propagation", "simulation_connection"],
    "dofs": [],
    "note": "Geometry-constraint mate: forces two surfaces (face/edge/vertex) to stay in contact. No mate connectors, no offset; its free DOF are geometry-dependent. Deferred — the engine has no geometry kernel, so it recognizes and round-trips the mate and marks it non-driving (not for use as a driving mate). Contact is resolved app-side."
  }
  ```

  **`category`/`drivable` additions to the kinematic schemas** — every
  one of the 8 gains exactly these two keys (nothing else changed).
  Example (revolute):
  ```json
  {
    "type": "revolute", "label": "Revolute",
    "category": "kinematic", "drivable": true,
    "dof_count": 1,
    "universal_controls": ["connector_a", "connector_b", "offset",
                           "flip_primary_axis", "secondary_axis_rotation",
                           "simulation_connection"],
    "dofs": [{"name": "rotation", "kind": "rotation",
              "unit": "radians", "axis": "z"}]
  }
  ```
  All 8 kinematic schemas: `"category": "kinematic"`, `"drivable": true`,
  and NO `note` key. Only width/tangent carry `note`.

  **`describe_mate` additions Codex must decode:** every mate now carries
  a top-level `"category"` (`"kinematic"` | `"geometry_constraint"`).
  Kinematic mates AND `width` keep the existing `"controls"` block
  unchanged (width's two connectors are the app-computed midplanes; its
  offset is inert/default-disabled). `tangent` carries **no** `controls`
  key — instead `"tangent": {"selection_a": <str>, "selection_b": <str>,
  "propagation": <bool>}` (opaque app-side surface ids). Both geometry
  mates have `"dofs": []`.

  **Decisions Codex must know:**
  1. **Additive only.** No kinematic mate's `universal_controls`, DOF
     slots, or `describe_mate` shape changed — the Swift
     `AnimaCoreClient` decode of the 8 keeps working; just add optional
     `category`/`drivable`/`note` to the schema DTO and a `category`
     (+ optional `tangent`) to the mate DTO.
  2. **Width control set** = `[connector_a, connector_b,
     flip_primary_axis, simulation_connection]` — **no** offset, **no**
     secondary reorientation (Onshape allows none). The loader REJECTS
     `offset`, `secondary_axis_rotation_deg`, and `dofs` on a width with
     a pathed error, and `Joint` rejects a non-zero/enabled offset on a
     width. The app computes the two midplane connectors and supplies
     them; the engine then places the child rigidly (coincidence).
  3. **Tangent control set** = `[tangent_selection_a,
     tangent_selection_b, tangent_propagation, simulation_connection]` —
     no connectors, no offset. The loader REJECTS `connectors`,
     `offset`, `dofs` and REQUIRES a `tangent` block with `selection_a`
     + `selection_b` (`propagation` optional, default `true`). The two
     selections are OPAQUE strings the engine never interprets (it has
     no geometry kernel) — the app owns their meaning.
  4. **Tangent is non-driving.** `resolve_pose` leaves a tangent child
     at its parent frame (identity relative). It should NOT be offered
     as a driving mate in the UI, and it produces no DOF to animate.
  5. **Width is 0-DOF rigid in FK.** With both connectors present it
     resolves through the same `C_A ∘ ALIGN ∘ inverse(C_B)` path as a
     0-DOF fastened (no offset, no motion), so the RealityKit render
     hook needs no width-specific code — it already positions the child
     at the centered/coincidence pose.

- **2026-07-15 (Codex, Fastened engine-backed mate inspector):** Added the
  `mate_types` client call and complete typed DTOs for the enriched
  `describe_mate` joint summary. On engine connection/import, Studio retains
  the engine type catalog and per-instance descriptors. The production navigator
  prefers those engine mates over the transitional Swift joint projection and
  keys selection by the engine's stable `id` (with a clearly session-only
  fallback for legacy empty ids), so Fastened mates remain present with zero
  DOFs. The new generic inspector displays identity/type, parent/child,
  connector A/B frames and flips, offset in operator mm/deg, whole-mate axis
  controls, simulation connection, and engine-provided DOFs; Fastened shows the
  locked fully-bonded state. It is deliberately read-only until the follow-up
  canonical document edit/revalidate packet. Verification: seven live helper
  tests across the client/workspace, all 216 XCTest cases (223 total), strict
  claimed-file format lint, root-app/Xcode build, deep signature verification,
  and a clean claimed-file `git diff --check`; no `animacore/` file was edited
  by Codex. The concurrent Width/Tangent backend claim currently leaves one
  repo-wide whitespace diagnostic in `animacore/tests/test_loader.py`, which
  remains in Claude's lane.

- **2026-07-15 (Claude, BR2 — mate motion resolver / `resolve_pose`):**
  Shipped `animacore/kinematics.py` (the canonical forward-kinematics
  engine, stdlib + `math` only, no numpy) and the bridge `resolve_pose`
  verb. Each mate now actually MOVES the child part relative to the
  parent about/along the **mate connector as the relative origin**, per
  its DOF, chained through the rig. Supersedes the Swift
  `RigPoseResolver` + `MateConnectorMath` (Studio_Bridge migration step
  2 — engine side done; app work = route RealityKit through the verb and
  delete both Swift files). 843 suite total (+27 in
  `test_kinematics.py`), ruff clean, no `app/`/`firmware/` touched.
  `evaluate_pose`/`project_channels` unchanged.

  **Convention I implemented (canonical — Codex renders/replaces
  `RigPoseResolver` against this):**
  - `Transform` = unit quaternion `(x, y, z, w)` (**real part last** —
    build RealityKit `simd_quatf(ix: o[0], iy: o[1], iz: o[2], r: o[3])`
    directly) + metre translation. `compose(a, b) = a ∘ b` (apply `b`
    then `a`). `apply_point(p) = rotate(p) + translation`.
  - `connector_frame`: translation = `origin_m`; basis `Z =
    normalize(primary_axis)` (negated first if `flipped`), `X =
    normalize(secondary ⊥ Z)` (Gram-Schmidt), `Y = Z × X`.
  - `child_in_parent = C_A ∘ ALIGN ∘ Offset ∘ Motion ∘ inverse(C_B)`,
    `C_A/C_B` = parent-/child-local connector frames. **`ALIGN` = 180°
    about X (opposes the two Z axes — matches your
    `opposingPrimaryAxisMatrix`) UNLESS `flip_primary_axis` (then Z
    aligned), composed with a Z rotation of
    `secondary_axis_rotation_deg`.** Coincidence property (tested): zero
    DOF + disabled offset → child connector origin maps exactly onto the
    parent connector origin, primary(Z) opposed, secondary(X) aligned.
  - `Offset` (when enabled) = `translate(translation_m) ∘
    rotate(rotation_axis, rotation_radians)` — rotation first, then
    translation.
  - `Motion` composes one sub-transform per DOF in template order, about/
    along the **canonical connector-frame axis** from
    `JOINT_TYPE_DOF_TEMPLATES` (revolute about Z, slider along Z,
    pin-slot rotates Z + translates X). Missing DOF → its neutral.
  - No connectors (`controls is None` or a connector `None`) → motion at
    the part origin: `child_in_parent = Offset ∘ Motion`. Fastened (no
    DOF) → rigid `C_A ∘ ALIGN ∘ Offset ∘ inverse(C_B)`.
  - `resolve_pose(rig, pose)`: parts that are no joint's `child_part` are
    ROOTS at identity (parts carry no rest transform); walk
    parents-before-children; `world[child] = compose(world[parent],
    child_in_parent(...))`. Deterministic.

  **Decisions Codex must know:**
  1. **Canonical axis, not the DOF's stored vector.** Motion direction
     comes from the connector frame + the template axis (Z for every
     revolute), never the per-DOF `axis:[...]` vector some examples still
     carry (that vector is legacy/decorative now, per Kinematics §1).
     Consequence: **a connectorless revolute rotates about part-origin
     Z.** `examples/six_axis_arm` only gives `base_yaw` connectors, so
     the other five joints all rotate about Z and the arm does not
     articulate in alternating planes — the parts still visibly *move*
     (orientations change frame-to-frame; the end-to-end test asserts
     `tool_flange` moves between t=0 and t=1.0), but making it a
     realistic serial arm is a **data task**: give each joint connectors
     orienting its Z. Not a code bug. Flag if you want me to author those
     connectors into the example.
  2. **Opposed-Z is the default** (matches your Swift default). `flip_
     primary_axis` flips to aligned-Z. This is now the single source of
     truth — the Swift `opposingPrimaryAxisMatrix` should be deleted, not
     mirrored.
  3. **Quaternion order `(x, y, z, w)`** in the wire JSON — real part
     LAST. `transform_to_json` normalizes before emitting.
  4. `resolve_pose` params mirror `evaluate` (`{handle, clip?, time_s?}`);
     unknown handle → `unknown_handle`; unknown clip → `bad_request`
     (same as `evaluate`).

  **Verbatim `resolve_pose` request / response** (real output,
  `six_axis_arm` `pick` clip at `time_s: 1.0`; floats rounded to 4 dp
  here for readability — the wire carries full precision):

  ```json
  {"id": 2, "method": "resolve_pose",
   "params": {"handle": "rig1", "clip": "pick", "time_s": 1.0}}
  ```
  ```json
  {"id": 2, "ok": true, "result": {"parts": {
    "base":        {"position": [0.0, 0.0, 0.0],   "orientation": [0.0, 0.0, 0.0, 1.0]},
    "shoulder":    {"position": [0.0, 0.0, 0.038], "orientation": [0.8594, -0.5113, 0.0, 0.0]},
    "upper_arm":   {"position": [0.0, 0.0, 0.038], "orientation": [0.6659, -0.7461, 0.0, 0.0]},
    "forearm":     {"position": [0.0, 0.0, 0.038], "orientation": [-0.1002, -0.995, 0.0, 0.0]},
    "wrist_inner": {"position": [0.0, 0.0, 0.038], "orientation": [0.3706, -0.9288, 0.0, 0.0]},
    "wrist_outer": {"position": [0.0, 0.0, 0.038], "orientation": [-0.3947, -0.9188, 0.0, 0.0]},
    "tool_flange": {"position": [0.0, 0.0, 0.038], "orientation": [-0.3947, -0.9188, 0.0, 0.0]}
  }}}
  ```
  (Positions cluster near the base connector origin `z=0.038` precisely
  because the connectorless joints are collinear on Z — decision 1;
  orientation is the moving quantity here.) Left uncommitted for
  main-session integration.

- **2026-07-15 (Claude, mate authoring model — universal controls +
  `mates.py`):** Shipped the dedicated mate-authoring module
  `animacore/mates.py` and its two UI hooks; `rig.py` re-exports the
  moved vocabulary (`JointType`, `DofKind`, `JOINT_TYPE_DOF_TEMPLATES`,
  `RotationDof`, `TranslationDof`, `DegreeOfFreedom`) so
  `from animacore.rig import JointType` still works. `Joint` gained a
  stable `id: str = ""` (verbatim, app-assigns) and
  `controls: MateControls | None`; the old `offset: JointOffset` field
  is gone (offset now lives at `controls.offset` as `MateOffset`).
  `evaluate_pose`/`project_channels` behaviour is byte-identical
  (connectors/offset are round-trip-only — no spatial math added). New
  `.character.anima` joint fields (all optional, closed schema, typed
  pathed errors, degrees→radians): `id`, `connectors:{a,b}`,
  `offset:{enabled,translation_m,rotate_about,angle_deg}`,
  `flip_primary_axis`, `secondary_axis_rotation_deg` (0/90/180/270),
  `simulation_connection`. Bridge: `load_character`'s joint summary is
  now `describe_mate(joint)`; new **`mate_types`** verb (added to
  `CAPABILITIES`). 811 suite total (+51), ruff clean, no `app/` /
  `firmware/` touched, **not committed**. Codex — the three things you
  build the UI hook against:

  **(a) Universal-controls list** (identical for all 8 kinds; the one
  shared hook):
  `["connector_a", "connector_b", "offset", "flip_primary_axis",
  "secondary_axis_rotation", "simulation_connection"]`. Only the DOF
  set differs per kind.

  **(b) `mate_types` response** (`result` shape) — the static
  palette/panel catalog, 8 kinds in `JointType` order. Each entry:
  ```json
  {"type": "revolute", "label": "Revolute", "dof_count": 1,
   "universal_controls": ["connector_a", "connector_b", "offset",
     "flip_primary_axis", "secondary_axis_rotation",
     "simulation_connection"],
   "dofs": [{"name": "rotation", "kind": "rotation", "unit": "radians"}]}
  ```
  Full set: `fastened` "Fastened" 0 dofs `[]`; `parallel` "Parallel" 4
  (translation_x/y/z + rotation); `revolute` "Revolute" 1 (rotation);
  `prismatic` **"Slider"** 1 (translation); `cylindrical` "Cylindrical"
  2 (rotation, translation); `pin_slot` "Pin Slot" 2 (rotation,
  translation); `planar` "Planar" 3 (translation_x/y + rotation);
  `ball` "Ball" 3 (rotation_x/y/z). Units: rotation→radians,
  translation→meters.

  **(c) `describe_mate(joint)`** — the per-instance hook, one per joint
  in the `load_character` `rig.joints` array (native units: radians /
  meters):
  ```json
  {"id": "Revolute 1", "name": "base_yaw", "type": "revolute",
   "parent_part": "base", "child_part": "shoulder",
   "controls": {
     "connectors": {
       "a": {"part": "base", "origin_m": [0.0, 0.0, 0.05],
             "primary_axis": [0.0, 0.0, 1.0],
             "secondary_axis": [1.0, 0.0, 0.0],
             "flipped": false, "feature": "base/top_face"},
       "b": {"part": "shoulder", "origin_m": [0.0, 0.0, 0.0],
             "primary_axis": [0.0, 0.0, 1.0],
             "secondary_axis": [1.0, 0.0, 0.0],
             "flipped": false, "feature": ""}},
     "offset": {"enabled": true, "translation_m": [0.0, 0.0, 0.012],
                "rotation_axis": "z",
                "rotation_radians": 0.026179938779914945},
     "flip_primary_axis": false, "secondary_axis_rotation_deg": 0,
     "simulation_connection": true},
   "dofs": [{"path": "base_yaw.rotation", "kind": "rotation",
             "unit": "radians", "min": -2.9670597283903604,
             "max": 2.9670597283903604, "neutral": 0.0}]}
  ```
  A mate that declared no controls reports
  `"controls": {"connectors": {"a": null, "b": null},
  "offset": {"enabled": false, "translation_m": [0.0,0.0,0.0],
  "rotation_axis": "z", "rotation_radians": 0.0},
  "flip_primary_axis": false, "secondary_axis_rotation_deg": 0,
  "simulation_connection": true}` and `"id": ""` (see `shoulder_pitch`,
  now `id "Revolute 2"` but no connectors).

  **Spec decisions (flag conflicts with the Swift mate model):**
  (1) file offset keys are `rotate_about` (`x`/`y`/`z`) + `angle_deg`
  (degrees); the runtime/`describe_mate` reports `rotation_axis` +
  `rotation_radians` (native, matching the DOF descriptors). (2)
  `MateConnector.part` must be a **declared** part (pathed error
  `…connectors.a.part`); connector primary/secondary axes must be
  non-zero and non-parallel (cross-product magnitude > 1e-9). (3)
  `controls` is `None` (absent) only when the joint declares no control
  field at all; if any is present the whole block materializes with
  defaults. (4) The old `offset:{translation_m,rotation_deg}` shape and
  `JointOffset` type are **removed** (pre-1.0 replace); `rc_car`
  migrated to the new offset schema, `six_axis_arm` now carries stable
  ids on all six joints + connectors + a non-zero offset on `base_yaw`.
  (5) `prismatic` keeps its raw value but its UI label is `"Slider"`.

- **2026-07-15 (Codex, BR1 — Swift client + engine-evaluated viewport):**
  Shipped the `AnimaCoreClient` Swift target with typed protocol DTOs and one
  session-long, serialized newline-JSON process connection. The client covers
  hello/load/validate/evaluate/release/shutdown, preserves engine field paths in
  errors, and converts JSON channel keys back to integer indexes. Assets now has
  a live `.character.anima` import action; the workspace loads the canonical
  character, evaluates its first clip at `min(duration, 1s)`, and supplies those
  exact DOF values as the `EvaluatedFrame` consumed by RealityKit. The BR1
  presentation adapter creates one clearly diagnostic proxy per rotational DOF
  only; it intentionally does not guess hierarchy, connector frames, or axes
  before `resolve_pose` lands. The header exposes engine connection/load state.

  `build-root-app.sh` now embeds a normalized Python 3.11 framework, AnimaCore,
  and PyYAML under the app bundle, rewrites the interpreter load path, removes
  Homebrew's external site-packages symlink, and signs the helper with sandbox
  inheritance before resealing the outer app. A direct bundled-helper handshake
  returned AnimaCore 0.1.0, and strict deep signature verification passes.
  Verification: 5 focused bridge/integration tests and all 216 pre-existing
  Swift tests pass; claimed-file strict format lint and Xcode/root-app builds
  pass. The XCUITest host was stopped by macOS LocalAuthentication before test
  execution, and clean-state GUI launches hit that same host authentication
  layer before the workspace task; no entitlement was weakened to bypass it.

- **2026-07-15 (Claude, BR1 — Studio↔AnimaCore bridge engine helper):**
  Shipped `animacore/bridge.py`, the long-running stdio helper that
  makes AnimaCore the single canonical engine (28 new tests in
  `animacore/tests/test_bridge.py`; 760 suite total; ruff clean; no
  `studio/` files touched; **not committed** — left for main-session
  integration). Protocol logic is a pure `handle_request(session,
  request) -> response` over dicts (fully unit-testable without stdio);
  `main(stdin, stdout)` is the thin newline-JSON loop. `Session` holds
  rigs by deterministic monotonic handle (`rig1`, `rig2`, … — no
  uuid/random). `PROTOCOL_VERSION = 1`. Format/protocol/shape errors
  become typed `{ok:false,error:{code,message,path}}` envelopes and
  never crash the loop; only a truly unexpected engine bug propagates.
  The passthrough is proven: an `evaluate` response's `dof_values`
  equal a direct `evaluate_pose(rig, clip, t)` call.

  **Invocation (Codex's Swift client):** spawn once per session,
  `python -m animacore.bridge`, keep alive; write one compact JSON
  object per line to its stdin, read one JSON object per line from its
  stdout, flush per line, match on echoed `id`. EOF or a `shutdown`
  response ends the process cleanly.

  **Verbatim request/response examples** (values from
  `examples/six_axis_arm.character.anima`):

  `hello` —
  req `{"id":1,"method":"hello","params":{"client":"AnimaStudio","protocol_version":1}}`
  res `{"id":1,"ok":true,"result":{"engine":"animacore","engine_version":"0.1.0","protocol_version":1,"capabilities":["hello","load_character","validate_character","evaluate","release","shutdown"]}}`
  (a mismatched `protocol_version` → `{"id":1,"ok":false,"error":{"code":"protocol_mismatch","message":"…","path":null}}`).

  `load_character` —
  req `{"id":2,"method":"load_character","params":{"text":"<file bytes>"}}`
  res `{"id":2,"ok":true,"result":{"handle":"rig1","rig":{"identity":{"name":"six_axis_arm","display_name":"Six-axis arm","description":"…","version":"0.1.0","author":"…"},"parts":[{"name":"base","parent":null,"model_node":null,"description":"…"},…],"joints":[{"name":"base_yaw","type":"revolute","dofs":[{"path":"base_yaw.rotation","kind":"rotation","unit":"radians","min":-2.9670597283903604,"max":2.9670597283903604,"neutral":0.0}]},…],"parameters":[{"name":"…","neutral":0.0,"description":"…"}],"clips":[{"name":"pick","duration_s":3.0,"loop":false}],"outputs":[{"dof_path":"base_yaw.rotation","channel":0},…]}}}`.
  Invalid file → `{"id":2,"ok":false,"error":{"code":"format_error","message":"<loader message>","path":"joints.bad.type"}}` (`path` is the loader's field path verbatim; `null` when there is none). `min`/`max` are `null` for an unlimited DOF (e.g. rc_car `drive.spin`).

  `validate_character` —
  req `{"id":3,"method":"validate_character","params":{"text":"<file bytes>"}}`
  res `{"id":3,"ok":true,"result":{"diagnostics":[]}}` (valid; **no handle allocated**), or on failure still `ok:true` with `{"diagnostics":[{"code":"format_error","message":"…","path":"joints.bad.type"}]}`.

  `evaluate` —
  req `{"id":4,"method":"evaluate","params":{"handle":"rig1","clip":"pick","time_s":1.0}}` (`clip` optional/null → neutral pose; `time_s` optional, default `0.0`)
  res `{"id":4,"ok":true,"result":{"dof_values":{"base_yaw.rotation":1.0471975511965976,…},"parameters":{},"channels":{"0":0.676…,"1":0.305…},"limit_violations":[]}}`.
  Units are native (radians/meters); `channels` is exactly
  `project_channels` output, **keyed by channel-index-as-string** (JSON
  object keys). When a mapped DOF is in `limit_violations`
  (`[{"dof_path":…,"value":…,"min":…,"max":…}]`) its channel is omitted
  and evaluate still succeeds — hardware refuses to arm, evaluate never
  fails on a violation. Unknown handle → `error.code
  "unknown_handle"`; unknown clip name → `bad_request`.

  `release` —
  req `{"id":5,"method":"release","params":{"handle":"rig1"}}`
  res `{"id":5,"ok":true,"result":{}}`. **Idempotent** — releasing an
  unknown handle also returns `ok` `{}` (a client can release freely).

  `shutdown` —
  req `{"id":6,"method":"shutdown"}`
  res `{"id":6,"ok":true,"result":{}}`, then the process exits.

  Unknown method or missing/mistyped params → `bad_request` with a
  human message. A non-JSON stdin line → best-effort
  `{"id":null,"ok":false,"error":{"code":"bad_request","message":"invalid JSON: …","path":null}}`.

  **Spec deviations / decisions (for Codex review):**
  1. `evaluate` `channels` object is keyed by the channel index as a
     **string** (`"0"`, `"1"`) — JSON object keys must be strings; the
     Swift client parses back to `Int`. The spec wrote `{channel:0..1}`;
     this is the faithful JSON encoding of `project_channels`'
     `dict[int,float]`.
  2. `release` of an **unknown handle returns ok** (idempotent drop)
     rather than `unknown_handle` — chosen so a client teardown never
     needs to track exactly what the engine still holds.
  3. Summary field-name choices the spec left as `[…]`: `parts` entries
     are `{name,parent,model_node,description}`; `parameters` entries are
     `{name,neutral,description}` (`neutral` = the model's
     `neutral_value`); `outputs` use the spec's `dof_path` key even
     though the target may be a parameter name (parameters carry no
     `.`). Adjust names freely on your side — these are DTOs the app
     mirrors, not engine truth.
  4. An **unknown clip name** maps to `bad_request` (the spec defines no
     dedicated code); `evaluate_pose`'s `KeyError` is caught and never
     propagates.
  5. `# ponytail:` — the `load_character` `{path}` variant is deferred
     (spec says "later"); only `{text}` is implemented. Later verbs
     (`resolve_pose`, scene/`SceneRunner`, `open_output`/`send_frame`,
     `compile_graph`) are not started — each is gated on its engine
     feature per the migration order.

- **2026-07-15 (Codex, AnimaCore restructure — Swift app half):** Renamed
  `studio/` to `app/`; updated XcodeGen, CI, the packaging script, repository
  maps, contributor contracts, and current-truth docs. Replaced the combined
  Swift `AnimaCore` module with dependency-directed `AnimaModel` (data,
  validation, mate definitions, animation data) and `AnimaEvaluation`
  (evaluated frames, interpolation/evaluation, mate math); no Swift
  `AnimaCore` target or import remains. All 216 Swift tests, strict format
  lint, native Xcode build, packaged build/signature, launch command, and
  `git diff --check` pass. Its parity-direction note was subsequently
  superseded by Jonathan's AnimaCore-canonical policy and BR1.

- **2026-07-15 (Claude, AnimaCore restructure — Python half):** Engine
  now owns the name AnimaCore. `anima_studio/` → `animacore/`
  (import + package `animacore`, distribution `animacore`);
  pyproject, CI, firmware comments, and every contract/current-truth
  doc updated; `pip install -e .` re-runs clean, 732 tests pass, ruff
  clean. Swift half (studio/→app/, AnimaCore→AnimaModel+AnimaEvaluation)
  handed to Codex in its mailbox — its lane, to run at a clean commit.

- **2026-07-15 (Codex, CAD viewport pointer/navigation refinement):** Added
  persistent per-axis Slow/Reduced/Standard/Fast/Very Fast response settings;
  zoom now defaults to Reduced while the established CAD mouse profiles and
  right-drag orbit remain intact. Semantic and imported model geometry now gets
  cyan hover preselection, while selected proxies retain the orange outline and
  inferred face-center/edge-midpoint/corner/axis/origin markers keep their own
  exact hover/selection treatment. Pointer identity is reduced to semantic IDs
  before reaching UI: the full component menu appears only over the selected
  body or its feature marker, and empty space uses Show All, Zoom to Fit, and
  Isometric. Actual imported-mesh face/edge topology selection remains deferred
  and is not misrepresented. All 216 Swift tests pass with focused interaction
  suites, strict claimed-file lint, native Xcode/root-app builds, signature
  verification, launch, and `git diff --check`.
- **2026-07-15 (Codex, UI Dev Reference Widgets pack 06):** Added a reusable
  Icon Selector & Theme Lab with a rounded four-tool dock, hover and selected
  states, selected glow, native context actions, and a persistent themed
  Edit/Duplicate/Delete menu specimen. The responsive lab switches among
  isolated Light, Dark, Graphite, Midnight, and Neon palette specs and shows
  their tokens for comparison; selected foreground/accent pairs are contrast
  checked. It appears in Reference Widgets and raises the Template Matrix to 31
  entries. Palette switching is intentionally local to UI Dev pending human
  approval and an app-wide appearance-token refactor. Thirteen focused and all
  209 Swift tests pass with claimed-file strict lint, root-app build, signature
  verification, launch, and `git diff --check`.
- **2026-07-15 (Codex, FANUC-style structured logic node concepts):** Expanded
  Nodes with Program Logic, Conditions, I/O & Registers, and Background Logic
  families. Placeable cards now cover IF/ELSE, single-line IF, SELECT, CALL,
  WAIT Until, AND/OR/XOR/NOT, input reads, output writes, numeric registers,
  flags, position registers, background monitors, and monitor-only End Scene.
  Typed ports and sample Manual Syntax properties communicate the future
  Visual/Script equivalence. JMP and LBL are deliberately red IMPORT ONLY
  references that raise validation guidance toward Loop, SELECT, or CALL,
  preserving the scene format's structured/reducible graph rule. Eleven focused
  and all 208 Swift tests pass with claimed-file strict lint, root-app build,
  signature verification, launch, and `git diff --check`.
- **2026-07-15 (Codex, UI Dev Reference Widgets pack 05):** Added a reusable,
  responsive concept-template card component and six Anima starting points:
  Organize Rig Components, Generate a Node Flow, Add Tools and Resources,
  Import an Assembly, Build a Motion Sequence, and Configure Character Outputs.
  Each card has a purpose-built illustration, readable title/detail/action
  hierarchy, hover and selected states, and explicit prototype-action feedback.
  The pack appears in Reference Widgets and raises the Template Matrix to 30
  entries. Twelve focused and all 207 Swift tests pass, along with claimed-file
  strict lint, root-app build/signature, launch, and `git diff --check`.
- **2026-07-15 (Codex, Nodes voice/AI/I/O concepts):** Expanded the node
  vocabulary into Inputs, Voice & AI, and Outputs. The library and workspace
  ribbon now cover text, microphone, event, and hardware inputs; STT, LLM,
  conversation memory, tool calls, TTS, and AI behavior; plus audio, motion,
  event, screen, LED, and hardware outputs. Concept cards can be placed and
  inspected with typed visual ports and editable sample properties, but remain
  explicitly labeled CONCEPT and validation-blocked from execution. All 206
  Swift tests, claimed-file strict lint, root-app build/signature, launch, and
  `git diff --check` pass.
- **2026-07-15 (Codex, Nodes workspace UI draft):** Added Nodes as the sixth
  project-authoring workspace (⌘5; Hardware shifts to ⌘6, UI Dev to ⌘7) and as
  a dedicated UI Dev tab. The modular surface contains a searchable library,
  draggable/selectable typed node cards, dotted zoomable canvas, live curved
  sample edges, inspector, validation feedback, grid/frame/zoom controls,
  add/delete/reset actions, and a compact timeline concept. Audio, screen/LED,
  and AI nodes remain visibly planned. The draft is intentionally in-memory and
  does not claim `.scene.anima` persistence, compilation, connection authoring,
  or execution; N2/N3 still promote it onto the one scene document/engine.
  Twenty-six focused tests and all 206 Swift tests pass, along with strict
  claimed-file format lint, native Xcode/root-app build, strict signature
  verification, launch, and `git diff --check`.
- **2026-07-15 (Codex, UI Dev Timeline Design B):** Added three timeline
  presentations—Dopesheet, Motion Curves, and Waypoint Lanes—over one shared
  multi-row keyframe state. The lab supports Add Row, click-to-create keys,
  proximity-based key selection, deletion, playhead insertion, ruler scrubbing,
  transport stepping, and state-preserving variant switching. Every row draws
  motion connections between its ordered waypoints; curves use smooth cubic
  presentation and the other variants use direct segments. It appears in UI
  Dev → References and the 29-template matrix without replacing the production
  timeline. Ten focused catalog tests, all 201 Swift tests, recursive strict
  format lint, native Xcode/root-app build, strict signature verification, and
  `git diff --check` pass.
- **2026-07-15 (Codex, UI Dev Reference Widgets pack 03):** Added the supplied
  material reference as an isolated interactive SwiftUI specimen. It includes a
  live HSB preview sphere, editable name/type/color, Diffuse/Specular/Roughness/
  Bump/Normal/Displacement selection and enablement, Float/Texture input, value
  and mix controls, lock behavior, and explicit Node Editor/Assignment/Help
  feedback. It appears in UI Dev → References and the 28-template matrix but is
  deliberately UI-only until material persistence and renderer contracts exist.
  Nine focused catalog tests, all 200 Swift tests, recursive strict format lint,
  native Xcode/root-app build, strict signature verification, and
  `git diff --check` pass.
- **2026-07-15 (Codex, UI Dev Reference Widgets pack 02):** Added the two
  supplied tab references as isolated, reusable SwiftUI specimens. The compact
  panel has primary/settings commands, visible shortcuts, command feedback, and
  a live Light/Dark segmented switch. The multi-document strip supports tab
  selection, hover, close-with-neighbor-selection, and new-tab creation beside
  macOS traffic-light context. Both are available in UI Dev → References and
  the 27-template matrix without replacing production navigation. Eight focused
  catalog tests, all 199 Swift tests, recursive strict format lint, native
  Xcode/root-app build, strict signature verification, and `git diff --check`
  pass. The app launches, but accessibility reports zero windows in this session.
- **2026-07-15 (Claude, `.scene.anima` execution v1 — B10 offline
  playback, backend):** Shipped `anima_studio/scene.py` (123 new tests
  in `anima_studio/tests/test_scene.py`; 583 suite total, ruff clean;
  claim released above). **Format v1 subset (Scene_Format.md
  restructured shipped-vs-draft, Character_Format 2.0 style):**
  `anima_version: "2.0"` + `type: scene` + `identity:` (character
  identity shape) + `character:` (plain relative path, resolved
  against the scene file's directory; the draft's `meta:` and
  `character: {file:}` forms get superseded-section errors) +
  `variables:` (scalar initial values) + `sequence:` of nine actions —
  `clip` (speed ratio; `wait: false` = background; looping clip
  REQUIRES `duration_s`, validated against the loaded rig; inside a
  clip entry `wait:` is the completion flag, disambiguated from the
  wait action), `pose` (one-off lerp from start values captured at
  action start; file units; load-validated against limits and
  relation-driven DOF rejected), `wait: {seconds}`, `wait_for:
  {event, timeout_s?, on_timeout: skip|end}` (edge-triggered, no
  event queue), `set` (literal or variable-name copy — expression
  arithmetic is a `# ponytail:` ceiling), `if` (literal equality,
  bool≠int guarded), `loop` (`count` XOR `while_var`, bool-typed,
  checked per iteration; a zero-time iteration with the var still
  true is a typed runtime error, never a hang), `parallel` (all
  tracks to completion; steps execute in timestamp order, ties by
  track declaration order), `event: {emit}`. Deferred spec actions
  (`speak`, `expression`, `blend_shapes`, `lights`, `ai_response`,
  `goto`/`label`) are loud pathed load errors. **SceneRunner API
  (what JaegerOS integration and the Studio Show workspace consume):**
  `load_scene_file(path) -> (Scene, Rig)`;
  `SceneRunner(scene, rig, adapter, frame_interval_ms=33,
  on_event=None)` over any `OutputAdapter` (caller owns
  open/close); `advance(now_s)` monotonic explicit-time ticks (sim.py
  discipline — deterministic to exact frame values; due actions run
  at their exact timestamps regardless of tick size);
  `post_event(name)` between ticks delivers gates at the current
  scene time; `stop()` = adapter e-stop + result `stopped`; `result`
  = `finished | ended_by_gate_timeout | stopped` (None while
  running); `emitted_events` log + `on_event` callback; `variables`
  snapshot property. Motion model: held last-settled values per
  target, active sources override in start order (a finished short
  source holds only until an earlier still-active source reasserts —
  documented ceiling), relation-driven DOF recomputed every frame
  with the existing refuse-to-arm `LimitViolationError` semantics
  reused, scene finishes when root sequence AND background clips
  complete. **Worked example:**
  `examples/pick_and_wave.scene.anima` drives the six-axis arm
  through the whole surface (parallel gate-track + scan loop; posting
  `visitor_detected` cuts the scan short) with end-to-end simulator
  tests asserting servo values at exact timestamps on both branches.
  Docs: Scene_Format.md v1 section, Bottango_Parity B10 row (offline
  playback foundation shipped backend-side), STATUS.md Python
  sentences. For the JaegerOS layer later: bus topics translate to
  `post_event`; feedback/cancel wrap `advance`/`stop`; nothing in
  scene.py imports beyond loader/rig/tracks/outputs. Not committed
  per packet instructions.

- **2026-07-15 (Claude, AnimaDocument P0A — versioned `.animastudio`
  package encoding, no UI):** Shipped the durable document layer as a
  new Foundation-only SwiftPM target `AnimaDocument` (depends on
  AnimaCore only; 25 new tests in
  `studio/Tests/AnimaDocumentTests/AnimaDocumentStoreTests.swift`;
  197 Swift suite total, lint clean, `swift build`, `xcodegen generate`
  + Xcode app build all green over the shared tree; `project.yml`
  untouched — the app links package *products*, and nothing app-side
  consumes AnimaDocument yet). **Package format:** `.animastudio` is a
  directory: `project.json` + `Assets/`. Manifest v1 (snake_case keys
  on the manifest's own fields; the nested AnimaCore project keeps its
  native camelCase Codable keys — do NOT put a key-conversion strategy
  on the encoder, it breaks `parentPartID`-style keys):
  `format_version` "1", `display_name` (projection of `project.name` —
  core stays the one truth), `revision` (bumped per save; feeds the
  V-badge), optional `milestone_name`, `modified_date` (ISO-8601,
  truncated to whole seconds so round trips compare equal), `project`,
  `assets[]` (`id`, `original_filename`, `kind` string, `mode`
  embedded|linked, `package_path` | `external_path`+`bookmark`
  base64). Encoding is deterministic: `.sortedKeys + .prettyPrinted +
  .withoutEscapingSlashes`, assets sorted by ID (byte-identical output
  for identical input — tested; with a fixed clock a no-change re-save
  differs in exactly the revision field). **Atomicity:** save stages
  the whole package (manifest + embedded payload copies from the live
  package) in an `itemReplacementDirectory` temp dir, then
  `replaceItemAt`/`moveItem` — a failed save leaves the old package
  byte-identical (tested) and no staging leftovers. **Linked assets
  (SolidWorks reference-part behavior):** `linkAsset` records absolute
  path + bookmark `Data`; `resolveAsset` returns
  `.needsRelink(reason)` (missingBookmark / staleBookmark /
  unresolvableBookmark / fileMissing) instead of throwing — broken
  links are user-fixable state, not errors. Bookmarks are
  security-scoped by default with a documented seam
  (`BookmarkStyle.plain`) because the un-sandboxed swiftpm test runner
  can't reliably create security-scoped bookmarks; tests link a real
  temp file, delete it, and assert needs-relink. **Typed errors**
  (`AnimaDocumentError`, all `LocalizedError`): packageNotFound,
  corruptManifest(path:detail:), unsupportedVersion(found:supported:),
  missingAsset, duplicateAssetName, duplicateAssetID, pathTraversal
  (validated *before* any filesystem access; `../`, absolute, and
  `Assets/../x` manifest paths all rejected — payload paths must be
  `Assets/<component>`), writeFailed. **AnimaCore Codable gaps found
  (not fixed — core untouched):** (1) synthesized `init(from:)`
  bypasses the memberwise-init preconditions, so a hand-edited
  manifest can decode an AnimaProject violating core invariants
  (duplicate joint IDs, min>max limits) without error — core
  validation should eventually run post-decode; (2)
  `ProjectAsset.sourcePath` overlaps the document asset table: the
  document layer keys `DocumentAssetReference` by the same `AssetID`
  so the core row keeps owning meaning (name/kind enum) while the
  document owns storage — P0B must keep the two in sync when
  importing. Codex: P0B task with the exact API surface is in your
  mailbox IN. Not committed per packet instructions.

- **2026-07-15 (Claude, Extensions E2 backend — parametric_feature
  templates + expansion):** Shipped `anima_studio/features.py` plus the
  extensions.py kind enablement and the packaged
  `examples/extensions/parametric-linkage.animaext/` example (90 new
  tests in `anima_studio/tests/test_features.py`; 460 suite total,
  ruff clean; claim released above). **The template contract (all
  decisions in Extensions.md "shipped semantics"):** a
  `parametric_feature` entry is a YAML file (`.yaml`/`.yml` enforced
  at manifest parse; `config:` rejected — pure data, no Python ever
  runs, so the example declares `capabilities: []`). Template =
  `anima_feature: "1.0"` + `name`/`description` + typed `parameters:`
  (`float` with required explicit `unit: deg|m|mm|ratio|count` as a
  form-display hint only — values substitute verbatim, templates
  convert in expressions like `${length_mm / 1000}`; `int`; `bool`;
  `choice` with `choices:`; `default` required, optional `min`/`max`)
  + `body:` of parts/joints/relations/rig-parameters in the exact
  loader shapes plus two template-only constructs: `${expr}` in scalar
  values AND mapping keys (safe recursive-descent evaluator: numbers,
  parameter/loop names, `+ - * /`, unary minus, parens; bool coerces
  to 1/0; a choice string is legal only as the whole expression;
  unknown name / div-by-zero / syntax = typed `FeatureExpansionError`
  naming the site; `# ponytail:` grammar ceiling noted — upgrade path
  is a whitelisted function table, never eval) and nestable `repeat:`
  `{count, var, body}` blocks (0-based; count accepts an int or
  `${expr}`; a bool count = optional block, which is how the example's
  `end_slider` works; `var` cannot shadow parameters or outer vars —
  parse-time error). **Expansion:** `expand_feature(template,
  instance_name, parameter_values=None, parent_part=None)` validates
  values (unknown/kind/range/choice = typed errors, defaults fill in),
  prefixes every part/joint/relation-target/rig-parameter name with
  `<instance_name>_` (instances coexist — two-instance loader test),
  rewrites internal references, resolves reserved `$parent` (part
  parent → `parent_part`, or dropped = unattached root when None;
  `$parent` in a joint requires attachment). `merge_fragment` inserts
  with collision errors and mutates nothing; the merged mapping is
  re-parsed by `loader.parse_character` — the loader stays the single
  gatekeeper (tested: a loader-invalid joint type expands fine and is
  rejected at parse). End-to-end test: discover real bundle → load →
  expand (2 links + slider) → merge → loader → `evaluate_pose` →
  `project_channels` (channels {0: 0.5, 1: 0.0}). **For E3 (Codex):**
  `registry.load_parametric_feature(id)` → `FeatureTemplate`;
  `template.parameters` (name/kind/unit/min/max/choices/default/
  description) is the insertion-form model, `FloatUnit` is the unit
  label; flow = form → `expand_feature` (instance name + optional
  attach part picked in UI) → `merge_fragment` → reload via loader;
  `FeatureError`/`FeatureTemplateError`/`FeatureExpansionError` carry
  `.path` + `.message` for form-side display. Sibling serial-transport
  work untouched; its 20 tests pass in the same suite run. Not
  committed per packet instructions.

- **2026-07-15 (Claude, serial wire transport — the real-hardware
  bridge):** Shipped `anima_studio/serial_transport.py`:
  `SerialWireOutput`, the third `OutputAdapter` consumer, drives real
  boards over pyserial (`pyserial>=3.5` added to `pyproject.toml`;
  `pip install -e ".[dev]"` re-verified). Constructor: `port` (device
  path like `/dev/tty.usbmodem*`, or any `serial_for_url` URL —
  `loop://` for tests), `baudrate=115200`, `handshake_timeout_s=2.0`,
  `reply_timeout_s=0.5`. `open` = HELLO handshake (ANIMA reply with
  protocol-version check) then CFG+EN per channel, each OK-checked;
  `send_frame` = `wire.encode_frm` → write → require OK. **Error
  semantics:** every failure is typed and names what happened —
  `HandshakeError` (non-ANIMA or wrong-version reply),
  `DeviceRejectedError` (carries the device's ERR code + message),
  `ReplyTimeoutError` (silent device within the read timeout),
  `ProtocolError` (undecodable bytes, unparseable line, >256-byte
  garbage without a newline, wrong reply type). No polling/sleeps:
  pyserial's own read timeouts do all waiting. A reply timeout is the
  *operator signal*; the device-side failsafe stays the *safety net*
  (short host-guidance note added to `Wire_Protocol.md` Transport).
  `stop()` is idempotent, works before open and after close, and
  swallows dead-port errors into `.last_error` (an e-stop must never
  raise past the caller); `close()` is explicitly not stop. No
  reconnect/threading in v1 (`# ponytail:` ceiling noted — lands with
  Studio live control). Tests
  (`anima_studio/tests/test_serial_transport.py`, 20 new; suite 370,
  ruff clean) run host bytes through a REAL pyserial `loop://` port
  with the reference `SimulatedDevice` answering from inside the
  loopback — exact-line sequencing asserts, frame motion on the sim
  clock, ERR code propagation, wrong-version/timeout/garbage paths,
  stop idempotence incl. post-close, and end-to-end rig
  `evaluate_pose` → `project_channels` → serial bytes → servo values.
  **First physical smoke test (Jonathan):** 1) flash: `arduino-cli
  compile --fqbn arduino:avr:uno firmware/anima_firmware &&
  arduino-cli upload -p <port> --fqbn arduino:avr:uno
  firmware/anima_firmware` (ESP32: swap fqbn for `esp32:esp32:esp32`);
  2) find the port: `ls /dev/tty.usbmodem*` (macOS; the board must be
  plugged in — pass that path below; Unos reset on port open, so use
  `handshake_timeout_s=3.0` if the default 2 s handshake times out);
  3) drive one servo on pin 9 from the repo root:
  `python3 -c "from anima_studio.serial_transport import
  SerialWireOutput; from anima_studio.outputs import ChannelConfig;
  o = SerialWireOutput('/dev/tty.usbmodemXXXX');
  o.open([ChannelConfig(channel=0, pin=9, min_us=600, max_us=2400)]);
  o.send_frame({0: 1.0}, duration_ms=1000); import time;
  time.sleep(1.5); o.stop()"` — the servo sweeps neutral→max over 1 s,
  then STOP disarms it (and if anything is unplugged mid-run, the
  2000 ms firmware failsafe disarms it anyway). Not committed per
  packet instructions.

- **2026-07-15 (Claude, Extensions E1 — manifest + discovery +
  output_adapter point + packaged example):** Shipped per
  `Extensions.md` (350 tests, +63; ruff clean; claim released above).
  **The adapter API (`anima_studio/outputs.py`) — the contract E3's
  browser and future transports consume:** `OutputAdapter` is a
  `runtime_checkable` Protocol with `open(channel_configs:
  Sequence[ChannelConfig])` (configure + arm), `send_frame(targets:
  Mapping[int, float], duration_ms: int)` (normalized 0..1, exactly
  `project_channels` output), `stop()` (e-stop, idempotent), and
  `close()` (release transport; close is NOT stop — a device losing
  its host is the failsafe's job). `ChannelConfig` mirrors wire CFG
  fields exactly (channel/pin/min_us/max_us/invert/neutral/
  failsafe_ms); validation stays in `wire.encode_cfg` (one truth).
  Constructor kwargs carry transport config; a manifest `config:`
  mapping passes through as those kwargs. Two consumers on day one
  (law 1): `SimulatorOutput` wraps — never reimplements —
  `SimulatedDevice` (encodes via `wire`, feeds `receive_line`, raises
  `WireError` on ERR replies, exposes `.device` for assertions), and
  `examples/extensions/udp-wire-output.animaext/` streams wire lines
  as one-datagram-per-line UDP (stdlib socket; tested end-to-end from
  its real bundle path against a loopback socket, exact-line
  assertions, no sleeps). **Manifest decisions (Extensions.md updated
  in-packet):** (1) `provides[]` entries gained an optional `config:`
  mapping (identifier keys → constructor kwargs) — adapters need
  per-install transport config and the manifest is the bundle's one
  truth; (2) ids are lowercase slugs `[a-z0-9_-]`; (3) contribution
  ids are unique per kind across the registry (flat v1 namespace —
  `load_output_adapter("udp_wire")` needs no extension qualifier;
  relax later if the ecosystem collides); (4) known kinds =
  output_adapter/parametric_feature/scene_action/motor_backend; the
  latter three parse but raise "not yet supported" on load;
  `studio_panel` and anything else are manifest errors; (5)
  `discover_extensions(search_dirs)` bakes in no default paths —
  callers pass dirs (conventional user/project dirs documented in the
  docstring); nonexistent search dirs skip silently, but a broken
  `*.animaext` (file, missing manifest, invalid manifest) fails
  loudly; (6) entry modules import via `importlib.util` under an
  extension-namespaced module name — no `sys.path` pollution, and an
  entry path escaping the bundle is rejected. **For E3 (Codex):** the
  registry surface for the Studio browser is
  `ExtensionRegistry.extensions` (id → `Extension(manifest,
  bundle_dir)`; manifest carries name/version/author/license/
  description/capabilities for the installed list + capability
  display) and `contributions(kind)`; enable/disable state is NOT in
  the registry — it's Studio-side persistence, decide where it lives.
  Swift never loads adapter code; it lists/inspects bundles and the
  Python runtime executes them. Not committed per packet instructions.

- **2026-07-15 (Claude, repo cleanup):** Per Jonathan, removed the
  Jaeger-template cruft the repo was cloned with: `workspace/` (robot
  bringup templates), `TAXONOMY.md`, `pyproject.toml.example`,
  `VERSION`, and the eight Jaeger taxonomy docs in `examples/`
  (git history preserves all). `examples/README.md` now documents the
  real `.anima` files. Deleted the empty leftover
  `studio/Sources/AnimaStudioApp/` dir (the app target lives at
  `studio/App` — this was the "multiple studio folders" confusion).
  CI: Python job now installs the real package and FAILS on lint/test
  errors (the template's `|| true` was silently passing failures).
  CONVENTIONS.md rewritten Anima-specific (two laws kept, Jaeger
  module/slot/workspace framing dropped). README: stale "(planned —
  nothing implemented yet)" runtime claims replaced with current
  truth + a repository map table. No studio/ source moves — Swift
  structure changes stay in Codex's lane.

- **2026-07-15 (Claude, Python kinematics parity — K2/K5/K7/K9 backend):**
  Shipped the backend half of `Kinematics.md` in `rig.py`/`loader.py`
  (287 tests, ruff clean; claim released above). **Limits (§2):**
  per-DOF limits are now optional — `RotationDof`/`TranslationDof`
  take `min_*`/`max_*` of `None` (both or neither), neutral stays
  required, an unlimited DOF evaluates unclamped (its tracks get
  ±inf bounds, so `tracks.py` needed no change), and an output
  mapping on an unlimited DOF is a load/validation error naming the
  fix. **Relations (§5):** new `Relation` core type
  (`driven = ratio × driver + offset`, kinds gear/rack_pinion/screw/
  linear with DOF-kind pairing validation), acyclic + one-driver-per-
  DOF + no-animation-on-driven enforced at construction/load; ratio is
  one signed nonzero float; per-kind `display` fields (teeth,
  pinion_diameter_mm, lead_mm_per_rev) round-trip non-semantically.
  **Violation API (the decision Codex must mirror):** `evaluate_pose`
  applies relations in dependency order after clip resolution and
  returns violations *on the pose* — `Pose.limit_violations:
  tuple[LimitViolation, ...]` (dof_path, value, min_value, max_value,
  native units; empty without relations) — nothing clamps; and
  `project_channels` raises `LimitViolationError` if a *mapped* DOF is
  violated (hardware refuses to arm; unmapped violated DOF don't block
  other channels). **Format (Character_Format.md, new 2.0 section,
  K2/K5/K9-marked):** `limits:` is a nested optional block
  (`{min_deg,max_deg}`/`{min_m,max_m}`) — the old flat spelling is
  rejected; an unlimited DOF declares its unit family via required
  `neutral_deg`/`neutral_m`; per-joint `offset:` block
  (`translation_m: [x,y,z]`, `rotation_deg`) is stored for round-trip
  only (runtime computes DOF values, not spatial transforms — Studio
  consumes it spatially); `relations:` list carries kind, driver,
  driven, `ratio` (**model units**: driven-model-unit per
  driver-model-unit — unitless for gear/linear, m/rad for
  rack_pinion/screw), optional `offset_deg`/`offset_m` (file units,
  key must match driven kind, mirrors outputs' range_deg/range_m
  pattern), optional `display`. **Ambiguities I resolved (flag if
  wrong):** (1) translation file units stay meters `_m` — Kinematics
  §2's "millimeters" is dialog display, not file format; (2) `ratio`
  is stored in model units since it's the semantic float; (3) ratio
  0 is rejected (pins the driven DOF instead of coupling); (4) file
  keeps `anima_version: "2.0"` despite the limits-block schema change
  (pre-release format, loader is reference). All three examples moved
  to the block syntax; rc_car now has a steering rack_pinion relation
  (driven `rack.travel` mapped to channel 2), a joint `offset`, and an
  unlimited free-spinning `drive.spin` DOF, streamed end-to-end into
  `SimulatedDevice`. Not committed per packet instructions.

- **2026-07-15 (Claude, kinematics plan):** Per Jonathan (Onshape mate
  dialog + relations as the reference), wrote
  `dev/docs/roadmap/Kinematics.md`: per-DOF optional hard-stop limits
  (Limits checkbox, min/max in operator units, unlimited = continuous,
  bounded-actuator mapping requires a range), inspector + viewport
  manual-drive handles per DOF, connector flip/reorient controls, and
  Relations as one linear-coupling core type (gear / rack-and-pinion /
  screw / linear; acyclic, one driver per driven DOF, warn-don't-clamp
  on limit violations, no collision detection). Packet sequencing
  K1–K7 with lane assignments and the cross-lane contract points is in
  the doc. Awaiting Jonathan/Codex review before implementation.

- **2026-07-15 (Codex, UI Dev + Agent utility panel):** Added UI Dev as a
  shell-level workspace so it cannot leak development-only presentation into
  character project state. Its contextual ribbon opens Windows, Controls, and
  Foundations galleries; the canvas is a living standard for button roles and
  states, labeled/unit-aware inputs, native menus, reusable panel chrome,
  blocking dialogs, contextual popovers, semantic colors, and shared geometry.
  Moved the existing primary-button call sites onto the new canonical
  `StudioButtonStyle` family and added shared icon/card/popover treatments. The
  Agent tool opens one reusable AppKit utility panel rather than a document
  window; prompt starters fill its composer, while voice and Send are visibly
  disabled under an explicit “agent service not connected” status. Verified
  claimed-file lint, 134 Swift tests in the merged tree (including a real
  one-panel reuse test), Xcode/root-app build, strict signature, live UI Dev
  selector/gallery accessibility labels, and `git diff --check`.

- **2026-07-15 (Codex, launchable UI Dev windows):** Extended the UI Dev
  workspace from a component gallery into a live window lab. Navigator,
  Inspector, and Timeline commands open the production views in reusable
  floating utility panels; 3D Workspace opens a normal resizable window with
  the production RealityKit viewport and a private sample rig. The viewport
  carries real selection, transforms, mate feature picking, camera state,
  guides, shading, mesh edges, reflections, shadows, and grid controls without
  touching the user's active project. Added a shared AppKit/SwiftUI window
  factory for saved frames, readable minimum sizes, and consistent lifecycle,
  then moved the Agent panel onto it. Repeated launches reuse one instance per
  surface. Verified claimed-file lint, 136 merged Swift tests, Xcode/root-app
  build, strict signature, live window launch checks, and `git diff --check`.

- **2026-07-15 (Claude, viewport sub-object selection):** Jonathan's
  view-cube hover interaction now works on components in the main viewport.
  Outside mate placement, the focused component shows its inferred
  face/edge/corner/axis/origin candidates as quiet cyan markers; hover
  highlights the exact clickable feature (view-cube cyan language,
  distinguishable from orange placement markers), click selects it
  persistently and keeps the owning component selected for
  navigator/inspector sync, and the inspector gains a read-only Feature
  section (component, kind, part-local origin). Empty viewport clicks —
  previously silently dropped because taps only targeted entities — now
  deselect feature and components via an invisible camera-locked collision
  backdrop 250 m behind the scene. Escape is staged: feature first (a
  window-scoped key monitor in `RealityKitViewport` that defers to text
  editing and to mate placement), then existing `onExitCommand`
  component/placement clearing. **Key decisions for Codex review:** (1) the
  untouchable `StudioWorkspaceView` wiring is preserved by retyping the
  existing `onSelectMateCandidate` callback to a new
  `ViewportPickEvent` enum (`.feature/.clearFeature/.clearAll`) with a
  matching `selectMateConnector(_:)` model overload — the old
  candidate-typed method and the whole placement flow are unchanged and
  placement always wins (feature taps forward, empty clicks ignored);
  (2) standing markers appear on the focused component only (select
  component first, then pick its feature) to avoid scene-wide marker
  clutter — true pre-selection scene-wide hover is a named follow-up;
  (3) feature selection is allowed on locked components (inspection only —
  locks keep guarding all edits, consistent with locked components being
  selectable in the navigator); (4) the model's `selectedFeature` is
  computed against the focused part and placement state so it can never
  dangle; the viewport keeps a display-only mirror that self-clears on
  focus change/placement (known cosmetic edge: a render-settings change
  rebuilds the scene and drops the marker while the inspector row remains
  until the next click). **Named follow-ups:** imported-topology features
  (triangle identity through reimport), full edge-curve/midline
  highlighting (extend `MateConnectorInference` in place), scene-wide
  hover preview without idle dots, gizmo-arrow/face-marker overlap
  polish. New files: `RealityKitViewport/SubObjectSelection.swift` (pure
  hit/transition/Escape rules), `SubObjectSelectionTests.swift` (14),
  `FeatureSelectionTests.swift` (12 model-level). MateConnectorInference
  needed no changes (single candidate source preserved).
  Verified: 134 Swift tests green (includes Codex's concurrent in-flight
  work in the shared tree), claimed-file `swift format lint` clean,
  `swift build` + `xcodegen generate` + unsigned Xcode app build green.
  Not committed per packet instructions; GUI walk not performed
  (headless session) — the empty-click backdrop and hover-on-marker feel
  deserve one manual viewport pass.

- **2026-07-15 (Codex):** Replaced the separate workspace-tab row with one
  selector-driven ribbon. A fixed far-left menu switches Assets, Rig, Animate,
  Show, and Hardware (Command-1…5); the grouped tools beside it change with the
  workspace. Rig keeps its Structures/Mates language and now exposes planned
  connector, assembly, and inspection families. The other four workspaces have
  focused catalogs covering the extended authoring plan, with existing actions
  wired and unimplemented backend work visibly gated. Verified claimed-file
  format lint, 105 Swift tests, Xcode/root-app build, strict app signature,
  launch, live Assets→Rig selector behavior, accessibility-tree labels, and
  `git diff --check`.

- **2026-07-15 (Claude):** Mate-family refinement per Jonathan: Python
  `JointType` gains `parallel` (translation X/Y/Z + rotation Z) so the
  backend carries the full eight Onshape mate types with DOF templates
  (214 tests, ruff clean). Mate inspector Type row is now an
  Onshape-style menu over `MateCreationToolKind` with per-kind
  `dofSummary`; unimplemented kinds are visible but disabled — no fake
  kind switching, ready to bind to the typed joint kind when your
  backend lands (98 Swift tests, claimed-file lint, Xcode build green).
  Note for typed-mate backend: keep `parallel` in your AnimaCore kind
  enum so Swift/Python stay in lockstep; suggest raw values match the
  Python `JointType` strings (snake_case `pin_slot` etc.) for the
  `.anima` format.

- **2026-07-15 (Codex):** Added the complete eight-entry mate family requested
  by Jonathan to the top Rig ribbon. Presentation metadata lives in a dedicated
  `MateCreationToolCatalog`; order, implementation availability, icons, and
  motion-summary coverage are tested. Revolute keeps its real two-connector
  action. Seven backend-dependent options are disabled and explicitly explain
  their wait state. Verified 97 Swift tests, claimed-file format lint,
  Xcode/root-app build, strict signature, final bundle launch, and the expected
  21 live ribbon buttons (4 Structures + 8 Mates + 9 future tools).

- **2026-07-15 (Codex):** Shipped the CAD-style Studio header requested by
  Jonathan: global document/live controls, top workspace selector and tabs,
  then a contextual ribbon. The Rig creation families are now a docked top row
  with a compact collapsed state, and no longer overlay the bottom of the 3D
  viewport. Added deterministic ribbon-presentation tests. Verified 94 Swift
  tests, format lint, unsigned Xcode build, rebuilt/ad-hoc-signed root app,
  strict signature, live launch, accessibility-tree presence of the complete
  header/empty-rig controls, and `git diff --check`. Screen capture remains
  unavailable because macOS did not grant the shell Screen Recording access.

- **2026-07-14 (Claude):** Created this briefing system (`dev/briefings/`),
  the Bottango parity map, and the work split above. Starting Lane B
  step 1–2 (protocol spec + Python host/simulator).
- **2026-07-14 (Claude, later):** Lane B steps 2–3 shipped:
  `anima_studio/wire.py` (protocol v0 host encode/parse),
  `anima_studio/sim.py` (in-process device simulator: handshake, servo CFG,
  device-side linear FRM interpolation on an explicit `tick(now_ms)` clock,
  EN/STOP, per-channel failsafe, spec ERR codes), and `anima_studio/clips.py`
  (hold/linear keyframe evaluation mirroring AnimaCore, time + limit
  clamping; Bézier waits on Studio). 74 tests incl. an end-to-end
  clip → 30 Hz FRM stream → simulated servo → failsafe run
  (`.venv/bin/pytest anima_studio/tests -q`). `Wire_Protocol.md` is now
  implemented reference-side — Lane A's serial `AnimationOutput` can be
  developed against `SimulatedDevice` over any str-line transport.
  Decisions the spec leaves open (flag here if Lane A needs different):
  CFG requires `pin`/`min_us`/`max_us` and rejects unknown keys (ERR 1);
  `neutral` defaults to 0.5; channels start disabled until `EN,<ch>,1` and
  stay disabled after STOP/failsafe until re-enabled; FRM frames are
  atomic (any bad target rejects the whole line); ERR messages are
  hyphenated tokens (no spaces, per the "no spaces" transport rule).
- **2026-07-14 (Claude):** Per Jonathan: roles are Claude = heavy
  implementation, Codex = planning + review; mailboxes
  `dev/briefings/claude.md` / `codex.md` added for directed
  messages/tasks (claims stay here — see AGENTS.md). Kept Codex's
  B01–B13 rewrite of `Bottango_Parity.md` over my simpler checklist.
  Lane B wire-protocol packet still in flight (background agent);
  will release the claim with test paths when it lands.
- **2026-07-14 (Codex review):** Accepted the mailbox + authoritative goal-file
  hybrid and rewrote the parity map as B01–B13 with P0–P5 dependency gates.
  Reviewed Wire Protocol v0 and the Python packet: device-linear interpolation
  plus host curve sampling is the correct boundary. All 74 Python tests and
  Ruff pass; safety/parity findings remain in Requests and the Codex mailbox.
- **2026-07-14 (Claude, review fixes):** All three findings fixed, spec first:
  `Wire_Protocol.md` now states only successfully parsed commands refresh the
  failsafe heartbeat and adds a Strictness section (duplicate CFG keys /
  duplicate FRM channels → `ERR,1`, no last-write-wins); `sim.py` implements
  both; `clips.py` narrowed + renamed to `tracks.py` (normalized 0..1
  output-track evaluator, parity claim dropped — rig-aware radians/neutral
  fallback ship with the `.anima` loader packet). 5 regression tests added;
  79 pass, ruff clean. Claim released. Also per Jonathan: lane ownership is
  now Codex = Swift GUI, Claude = backend; P0A reassigned to Codex
  (see mailboxes). My STATUS.md edit touches only the Python paragraph —
  flagging because your active B01/B12 claim also covers STATUS.md.
- **2026-07-14 (Claude, B10 backend foundation):** `.character.anima` loader +
  rig-aware runtime evaluation shipped. New: `anima_studio/rig.py` (Joint with
  explicit `*_radians` range/neutral, BlendShape, RigClip with loop,
  `evaluate_pose` — clip drives some parameters, every unanimated joint/blend
  shape falls back to its neutral, empty/missing tracks legal; reuses
  `tracks.py` for interpolation — and `project_channels`, the B04 joint→
  normalized 0..1 channel seam feeding `wire.encode_frm`),
  `anima_studio/loader.py` (YAML via `safe_load`, version/type check,
  `CharacterFormatError` naming the offending path, closed-spec unknown-field
  rejection), `examples/jp01_minimal.character.anima` (3-joint head, 1 blend
  shape, 1 clip, 3 servo mappings incl. an inverted one), tests
  `anima_studio/tests/test_rig.py` (23) + `test_loader.py` (42). 144 total
  pass, ruff clean; end-to-end: character file → rig eval → channel projection
  → FRM → `SimulatedDevice` pulse assertions, incl. a round-trip proving a
  descending mapping range equals CFG `invert=1`. **Accepted format subset:**
  `identity`, `blend_shapes`, `bones` (`neutral_deg` default 0, ascending
  `range_deg` required), `clips` (`duration_s`, `loop` default false,
  `tracks.bones`/`tracks.blend_shapes` sparse keyframe entries), and
  `physical.enabled` + `physical.bone_mapping` (`servo_channel`, `range`).
  **Rejected loudly (not silently dropped):** `expressions`, `lip_sync`,
  `digital`, `voice`, `physical.blend_shape_mapping`, `physical.led_mapping`,
  `smoothing`, `easing`, unknown fields anywhere. **B04 mapping shape:**
  `bone_mapping.<joint>.range: [deg_at_channel_0, deg_at_channel_1]` — a
  descending pair expresses inversion; projection clamps to 0..1; pulse
  widths/pins stay wire-CFG-side. **Spec ambiguities I decided (please
  review, Codex):** (1) file keyframes carry no interpolation field — I added
  optional per-entry `interpolation: hold|linear` (default linear); (2) bone
  clip/track values are degrees in the file, radians in the rig; (3) joints
  and blend shapes share one parameter namespace (collisions rejected);
  (4) keyframe values outside the joint range / 0..1 are load errors, not
  clamps; (5) `blend_shape_mapping` rejected because its `joint:` targets
  (e.g. `head_jaw`) aren't declared bones and servo-degree ranges aren't
  projectable to 0..1 without CFG knowledge — needs a contract decision;
  (6) duplicate servo channels across mappings rejected; (7) `loop` wraps
  time modulo duration in `evaluate_pose`. STATUS.md: Python sentences only
  (your active claim covers the Studio ones). No Swift files touched.
- **2026-07-14 (Codex, SwiftUI):** Implemented the Bottango-inspired native
  home and project chrome plus B12 hierarchy inspection. Build/Animate/Import/
  Hardware modes now reshape the workspace; Animate owns the timeline dock;
  imported RealityKit entity trees are value-projected, selectable, and shown
  in the inspector. Disabled actions are labeled as planned rather than
  pretending persistence or hardware is wired. Eight Swift tests and claimed-
  file format lint pass; the app launches. Automated screenshots were blocked
  by macOS Screen Recording/Accessibility permissions.
- **2026-07-14 (Codex, workspace interactions):** Extended the main-window
  slice through Bottango's camera, selection, and configuration workflow.
  Added shared palette/metrics and reusable panel, field, picker, readout, and
  button components; applied them to the live app. Parts now use native
  file-browser multi-selection, direct viewport geometry picking extends the
  same selection with Command/Shift, single selection controls configuration,
  and Escape/header close clears it. Project/asset/joint names and joint axis edit
  the actual AnimaCore-backed in-memory project. The viewport has a grid toggle,
  Home/front/right/top camera commands, perspective/orthographic switching, a
  gesture guide, and selected imported-node framing. Persistent name/color/
  visibility/delete part controls remain correctly gated on the single durable
  semantic-part model rather than an app-local duplicate. Eight Swift tests and
  claimed-file format lint pass.
- **2026-07-14 (Codex, workspace architecture):** Added the professional-app
  workspace model requested by Jonathan. One open project now plans five
  task-focused presentations: Assets, Rig, Animate, Show, and Hardware. The
  stable global header owns document/workspace/live state; the active workspace
  owns its contextual header, tools, panels, shortcuts, and default layout.
  Layout preferences remain user-local presentation state by default and never
  create a duplicate project model. This is documented in `Studio_App.md` and
  incorporated into B01 acceptance.
- **2026-07-14 (Codex, supplied UI research):** Verified the provided Bottango
  analysis against current official documentation and incorporated the useful
  interaction requirements: workspace+selection contextual tools, one shared
  selection across tree/viewport/timeline/graph, progressive inspectors,
  precise and scrubbable numeric fields, dope-sheet/graph separation, media
  waveforms, and a searchable/filterable/exportable hardware log. Explicitly
  kept Anima continuous-time with configurable display fps, kinematic-only,
  external-model-first, and safely offline until separately connected and
  armed; those boundaries supersede Bottango-specific 30 fps, modeling,
  physics, and automatic live-mirroring assumptions.
- **2026-07-14 (Codex, workspaces + mate guides):** Replaced the cosmetic
  four-mode shell with five task-focused descriptors: Assets, Rig, Animate,
  Show, and Hardware. Each owns contextual header actions, navigator/inspector
  content, and an independent in-session panel layout; Command-1…5 switches
  workspaces. Show now has a distinct character/audio/screen/event timeline
  scaffold. Hardware now has structured offline connection, mapping, safety,
  and diagnostic-log surfaces. The sample RealityKit rig renders a mate
  connector with labeled XYZ axes, revolute DOF ring, optional reference plane,
  and limit arc; the Rig overlay toggles each layer. The formal mate/handle
  contract is in `Studio_App.md`. Editable handles and imported attachment wait
  for the shared typed-joint/DOF contract. Fifteen Swift tests, claimed-file
  format lint, `git diff --check`, and a fresh app launch pass.
- **2026-07-14 (Codex, source hierarchy navigator):** Incorporated Jonathan's
  Parts Menu/import research as a two-layer navigation contract. Imported
  RealityKit nodes are now grouped under a searchable, blue, visibly locked
  Source Model tree; the semantic mechanism and joints remain distinct
  project-owned roles. Filtering retains matching descendants and their
  ancestors. The inspector explains source ownership, source-authored
  appearance, mapping, and reimport prerequisites, with unimplemented actions
  honestly disabled. `Studio_App.md` now requires immutable source hierarchy,
  editable semantic hierarchy, mapping cardinality, durable synchronization
  identity, and non-destructive material handling. Nineteen Swift tests,
  claimed-file format lint, `git diff --check`, and native app launch pass.
- **2026-07-14 (Codex, B06 animation workspace):** Rebuilt Animate's bottom
  editor as a multi-track dope sheet plus switchable graph presentation. Every
  motion track gets a colored row; keyframes seek on click; scrubbing, adjacent
  key navigation, single-frame stepping, horizontal zoom, and 24/25/30/60 fps
  display timecode work over AnimaCore's continuous seconds. Preview looping is
  now a real toggle, and non-loop playback stops at clip end. The graph draws
  existing hold/linear curves and isolates selected joints; Audio and Event
  lanes are explicit empty capabilities, and editing/Bézier/live-output actions
  remain honestly gated. Twenty-four Swift tests, claimed-file format lint,
  `git diff --check`, and native app launch pass.
- **2026-07-14 (Codex, production macOS app):** Reorganized the Studio lane
  around a thin native Xcode application target and reusable `AnimaStudioUI`
  Swift package. UI code is grouped by app shell, components, theme, previews,
  and task workspace; tests mirror that structure. Added an XcodeGen project
  specification plus checked-in generated project, centralized `.xcconfig`
  settings, sandbox entitlements, localization catalog, macOS UI-test target,
  three-state Canvas preview catalog, and a complete custom icon asset catalog.
  `studio/Scripts/build-root-app.sh` produces the ignored, ad-hoc-signed
  `Anima Studio.app` at the repo root. Twenty-four Swift tests and format lint
  pass; the native Xcode build, icon/resource presence, strict signature check,
  and root-app launch pass. No Python or firmware files were staged.
- **2026-07-14 (Codex, empty Rig + creation palette):** Removed the automatic
  sample mechanism from new Studio projects. The Rig workspace now starts empty
  with an Add to Rig palette modeled on Jonathan's supplied reference: working
  Box, Cylinder, Sphere, Empty Point, and New Joint actions; disabled reference
  icons for Insert Joint, Motors, 3D Models & Media, and Events. The working
  actions create real Codable AnimaCore semantic parts and revolute parent/child
  joint connections, drive the navigator and inspector, and render in
  RealityKit. Parts expose names and XYZ metres; joints expose names, axis,
  connection, and degree limits. Created joint guides all obey the Rig overlay
  visibility toggles. The settings menu persists Midnight, Graphite, CAD Light,
  or Blueprint viewport background/grid appearance outside project data.
  Thirty-one Swift tests and claimed-file format lint pass; native Xcode build,
  strict signature verification, replacement root-app build, and launch pass.
  Swift's proxy-part representation is a Studio authoring foundation; Claude's
  active Python typed-joint/DOF contract remains authoritative for the later
  cross-runtime file-format alignment and was not modified here.
- **2026-07-14 (Codex, CAD viewport interaction):** Added explicit user-local
  Onshape and SolidWorks mouse profiles over the RealityKit camera: right/middle
  orbit-pan mappings, modifier variants, wheel/pinch zoom, and trackpad pan are
  implemented and mapping-tested. Semantic proxy collisions now drive the same
  stable selection used by the tree and inspector. Selection adds an orange
  silhouette plus local XYZ translation arrows and rotation rings; handle drags
  update core-backed metre position / Euler-radian rest orientation, with joint
  animation composed afterward. New parts now begin with their local origin at
  workspace zero per Jonathan; legacy Swift project JSON defaults missing rest
  transforms to zero. `Studio_App.md` records the imported-origin rule and the
  staged triangle-face / topology-edge selection boundary. Thirty-eight Swift
  tests, claimed-file format lint, Xcode build, strict signature check, replaced
  root app, and launch pass. Cross-runtime note for Claude: this adds a Swift
  authoring-side `rotationEulerRadians` field only; do not mirror that spelling
  into `.anima` until the shared typed-joint/connector transform schema is
  reconciled. No Python, firmware, or example file was touched.
- **2026-07-14 (Codex, synchronized view cube + render HUD):** Added a live
  view cube backed by the RealityKit camera's actual orientation rather than a
  parallel UI-only estimate. Face, edge, and corner hit regions choose
  principal, two-axis, and trimetric views; surrounding arrows nudge by 15
  degrees. A separate camera/render menu persists projection, 30–90 degree
  field of view, Shaded/Shaded + Mesh Edges/Wireframe/Translucent style, grid,
  viewport appearance, and input profile as user-local presentation state.
  Camera state, render application, cube geometry, cube UI, and menu UI are
  isolated in focused files with direct tests. Triangle mesh lines are labeled
  honestly; hidden-line, section, roll, and named-view contracts remain future
  work. Fifty Swift tests, claimed-file format lint, native Xcode build, strict
  signature verification, rebuilt root-app launch, and `git diff --check` pass.
  Claude's Python, firmware, and example changes remain untouched.
- **2026-07-14 (Codex, direct viewport display/navigation controls):** Moved
  HUD composition into its own component and placed a labeled Display dropdown
  directly beside the view cube. Operators can independently choose
  Shaded/Wireframe/Translucent surfaces, mesh-edge visibility,
  Balanced/Soft/Bright/High Contrast two-light RealityKit rigs, projection,
  field of view, grid, background appearance, and input profile. Cube labels
  rotate and clip with their projected faces; the triad shares one origin and
  projects positive X/Y/Z directions; face, edge, and corner hover targets show
  exactly what will be selected. Input profiles are Default (Onshape-like),
  SolidWorks, Onshape, Fusion 360, and conflict-free editable Custom; wheel
  zoom and trackpad gestures remain profile-independent. Sixty-three Swift
  tests, claimed-file format lint, native Xcode build, strict signature check,
  rebuilt root-app launch, and `git diff --check` pass. Hidden-line, section,
  and classified feature-edge rendering remain deferred. Claude's Python,
  firmware, examples, and active files remain untouched.
- **2026-07-14 (Codex, stable view-cube face decals):** Replaced the
  readability-adjusted view-cube text transform with a fixed face-local decal
  transform. Each fixed-size label stays centered on its assigned face and
  follows that face's projected orientation without automatic 180-degree
  readability flips, clipping, or dynamic scaling. Cube orientation, positive
  XYZ triad projection, hover targets, and face/edge/corner navigation are
  unchanged. Sixty-four Swift tests, claimed-file format lint, native Xcode
  build, strict signature verification, rebuilt root-app launch, and
  `git diff --check` pass. Claude's Python, firmware, examples, and active files
  remain untouched.
- **2026-07-14 (Codex, compact camera/render toolbar):** Moved Display from
  its separate block beside the view cube into the shared lower camera toolbar,
  where it now sits between Home and Help. Removed the redundant Front, Right,
  and Top toolbar buttons; the synchronized cube remains the single direct
  control for all six principal faces plus edge and corner views. Display keeps
  the same render, lighting, projection, grid, appearance, and input settings.
  Sixty-four Swift tests, claimed-file format lint, native Xcode build, strict
  signature verification, rebuilt root-app launch, and `git diff --check` pass.
  Claude's Python, firmware, examples, and active files remain untouched.
- **2026-07-14 (Codex, Components/Mates organization + wheel zoom):** Renamed
  operator-facing Joint language to the Mate umbrella, with the current authoring
  action identified as a Revolute Mate while internal `JointDefinition` remains
  transitional. The navigator now has expandable component groups, contextual
  rename, move up/down, move-to-group, dissolve, and lock/unlock actions; Mates
  have rename, reorder, and lock/unlock actions. Locks are enforced in the
  workspace model, prevent new mate attachment to locked components, disable
  inspector edits, and hide transform handles. Groups/locks are honest
  in-session Studio organization until P0 persists editor metadata. Discrete
  mouse-wheel events now classify as zoom, while precise trackpad phases remain
  pan and magnification remains zoom. Seventy-one Swift tests, claimed-file
  format lint, native Xcode build, strict signature verification, rebuilt
  root-app launch, and `git diff --check` pass. Claude's Python, firmware,
  examples, and active files remain untouched.
- **2026-07-14 (Codex, tree drag reordering + reliable grouping):** Added typed
  component/group/Mate drag payloads and model-owned deterministic mutations.
  Components drop before peers, onto groups, or onto the Components heading;
  groups and Mates drop before peers. Locked sources and destinations reject
  organization changes. The footer now exposes selected unlocked components as
  **Group Selected (N)**, stays usable as **New Empty Group** without a
  selection, and explains skipped locked selections. Drag rules and ordering
  are isolated in `NavigatorOrganization.swift`, state mutations remain in the
  workspace model, and the SwiftUI tree only wires interactions. Seventy-six
  Swift tests, recursive format lint, native Xcode build, strict signature
  verification, rebuilt root app, and `git diff --check` pass. No Python,
  firmware, example, or runtime-format file was touched.
- **2026-07-14 (Codex, insertion feedback + drop-to-group correction):** The
  prior whole-row drop treatment did not expose the requested grouping
  affordance. Added the focused `NavigatorDropInteraction.swift` module:
  component edges show before/after insertion lines, while the center shows a
  bordered **+ Group** target. Center-drop creates an expanded folder containing
  the target and the dragged component's active multi-selection. Existing
  folders and top-level drops move that selection together; group and Mate rows
  use insertion lines. Selected-component context menus now expose **Group
  Selected (N)** in addition to the footer button. Eighty-one Swift tests,
  claimed-file format lint, native Xcode build, strict signature verification,
  rebuilt root app, and `git diff --check` pass. No backend, firmware, example,
  or runtime-format file was touched.
- **2026-07-15 (Codex, connector mates + render quality):** Added optional
  renderer-neutral parent/child connector frames to the transitional Swift
  joint contract and announced the mirror requirement to Claude without
  touching its active Python/format files. Rig authoring now uses an explicit
  moving-first/fixed-second placement session with hoverable proxy feature
  candidates, opposing-axis snap alignment, cycle prevention, and an inspector
  attachment summary. A focused RealityKit pose resolver evaluates revolute
  motion around connector-local Z through parent/child chains. Viewport shading
  now uses PBR proxy finishes, a generated softbox image-based-light environment,
  and toggleable key-light shadows. Changed only the released Swift/docs claim;
  Claude's runtime, firmware, examples, and `Character_Format.md` remain
  untouched. Ninety-two Swift tests, claimed-file format lint, native Xcode
  build, strict app signature, rebuilt root-app launch, and `git diff --check`
  pass.

- **2026-07-15 (Codex, UI Dev Mate/Triad labs + docked Agent):** Replaced the
  Agent's always-floating AppKit panel with a 360-point trailing panel inside
  the UI Dev canvas, including an explicit close action; a separately labeled
  Floating Template retains the reusable utility-panel pattern for tools that
  truly need it. Added dedicated interactive Mate Editor and Triad Manipulator
  labs. Mate Editor covers type selection, connector focus, progressive Offset
  XYZ/rotation fields with units, simulation disclosure, accept/cancel, and
  flip/reorient/preview/solve actions. Triad is a code-drawn hover/select/drag
  prototype with center, XYZ arrows, rotation rings, plane pads, ghosted
  restricted motion, live readout, scale, and stroke tuning. These remain UI
  prototypes and do not claim the planned typed-mate/DriveTarget backend.
  Reviewed Kinematics v2 and agree with its single `DriveTarget` routing rule:
  free parts edit rest transforms; mated parts drive permitted DOF; ambiguous
  motion stays ghosted instead of guessing. Verified claimed-file lint, 138
  merged Swift tests, focused seven-test recheck, Xcode/root-app build, strict
  signature, live Agent/Mate/Triad accessibility walkthrough, and
  `git diff --check`; Claude's active Python/format files were untouched.
- **2026-07-15 (Codex, integrated workspace selector):** Extracted the
  workspace selector into a focused SwiftUI component and replaced its cramped
  fixed-width system menu with a readable CAD-style selector. The control has
  a tested 228-point minimum, 242-point ideal, and 260-point maximum width; the
  live app measured 260 by 72 points. Its anchored 280-point menu uses large
  icon-and-purpose rows, full-row selected emphasis, visible Command-1…6
  shortcuts, and matching Studio surfaces so the button and dropdown read as
  one control. The complete 139-test Swift suite, strict format lint,
  Xcode/root-app build, strict signature verification, live accessibility
  sizing/menu interaction, and `git diff --check` pass.
- **2026-07-15 (Codex, embedded UI Dev production surfaces):** Removed the
  AppKit window launch path for Navigator, Inspector, Timeline, and 3D View.
  Their ribbon commands now render the real production surfaces inside the UI
  Dev canvas in the same regions operators use: left, right, bottom, and center.
  Agent remains the existing 360-point right app sidebar. The only auxiliary
  `NSPanel` is now the explicitly labeled **Detached Window**, isolated in its
  own focused source file. Live accessibility checks confirmed Navigator plus
  the production viewport and Agent all remain in the single main window;
  opening Detached Window alone increases the window count to two. Claimed-file
  lint, six focused tests, the complete 140-test suite, Xcode/root-app build,
  strict signature, and `git diff --check` pass.
- **2026-07-15 (Codex, live UI Kit + shared design profile):** UI Dev now opens
  on a resizable Live UI Kit instead of a disconnected specimen page. Its
  Design Inspector edits the centralized Studio colors, semantic colors,
  opacity, chrome/ribbon sizes, panel geometry, control geometry, and dock
  widths used by the production app. Changes apply immediately and persist as
  one versioned profile; Standard, Compact, and High Contrast presets plus
  reset, import, export, and copy-JSON workflows make final operator review
  repeatable. The catalog lays out docked windows, the production viewport,
  buttons and states, fields, menus/popovers, and panel chrome using the real
  shared styles. Four profile tests, six focused UI Dev tests, all 144 Swift
  tests, strict claimed-file format lint, Xcode/root-app build, strict
  signature verification, live preset/restoration walkthrough, and
  `git diff --check` pass. The root app remains open on the Standard UI Kit.
- **2026-07-15 (Codex, shared Onshape-style mate panel variants):** Kept one
  Mate Editor panel and made both its eight-icon strip and Type dropdown drive
  the same selected kind. A focused presentation projection mirrors the agreed
  mate/DOF template order and derives per-kind limit rows, operator units, and
  constrained Offset axes without changing AnimaCore or Claude's Python
  backend. Slider now shows X/Y constrained offsets and Z translation limits;
  compound types expose every permitted DOF; Fastened clearly shows no motion
  controls. The Rig ribbon remains honest: only Revolute authors data until the
  typed Swift backend lands. Nine focused tests and all 149 Swift tests pass,
  along with strict claimed-file format lint, Xcode/root-app build, strict
  signature verification, and `git diff --check`. The accessibility service
  became unreliable during final scripted workspace navigation, so the live
  visual feel still merits Jonathan's normal human review in UI Dev.
- **2026-07-15 (Codex, selection-driven Inspector + component Appearance):**
  Inspectable selections now restore the right Inspector after an operator
  hides it. Semantic proxy components have a focused Properties/Appearance
  switch; the new modular Appearance editor offers 40 palette colors, a live
  ColorPicker and RGB mixer, editable validated hex, RGB readout, opacity,
  visibility, reset, and an honest Automatic tessellation readout. A small
  renderer-facing appearance value drives the real RealityKit body without
  entering AnimaCore; locked components reject changes and imported materials
  remain source-owned. Overrides are explicitly in-session until the document
  layer defines saved non-destructive material overrides. Twelve focused tests
  and all 157 Swift tests pass, along with strict claimed-file format lint,
  native Xcode/root-app build, strict signature verification, and
  `git diff --check`. Launch Services created app processes but macOS exposed no
  accessible window during the scripted walk, so final visual density remains
  a human click-through in the rebuilt root app.
- **2026-07-15 (Codex, selected-component viewport context menu):** Added one
  native macOS context menu to the production viewport whenever exactly one
  semantic proxy component is selected. It opens Properties or Appearance,
  frames the component, toggles visibility, resolves component- versus
  group-owned locking, resets position/rotation separately or together, and
  clears selection. The menu is a focused SwiftUI modifier and its tested state
  projection/commands are isolated in a workspace-model extension; every
  mutation flows through the existing model guards. Five focused tests and all
  162 Swift tests pass, along with recursive format lint, native Xcode/root-app
  builds, strict signature verification, and `git diff --check`. The rebuilt
  app launched, but macOS returned no accessible window for scripted menu
  traversal, so Jonathan should perform the final right-click feel review.
- **2026-07-15 (Codex, CAD-reference component-menu refinement):** Reordered
  the production menu around the supplied CAD example: body identity first,
  then Properties and navigable attached-mate dependencies, visibility tools,
  selection/camera controls, lock and transform commands, and body Appearance
  last. Added reversible Isolate and Make Transparent viewport overlays that
  compose over the real component appearances without mutating rig or saved
  appearance data. Select All Components, Clear Selection, Home View, and Zoom
  to Selection reuse shared workspace state. Four new tests bring the focused
  suite to nine and the full suite to 166; recursive format lint, native
  Xcode/root-app builds, strict signature verification, launch, and
  `git diff --check` pass.
- **2026-07-15 (Codex, start-screen Recent Projects gallery):** Replaced the
  home screen's permanent empty placeholder with compact reusable project cards
  modeled on Jonathan's reference. Each card carries a cached render path with
  a project-type fallback, project name, real last-opened time, V-number, and an
  optional milestone label. User-local records are Codable, recency-sorted,
  deduplicated, and capped at twelve; creating the scratch project records its
  V1 entry. Cards remain honestly non-opening until P0 durable documents can
  resolve their IDs. Four focused tests and all 170 Swift tests pass, along
  with recursive format lint, Xcode/root-app builds, strict signature
  verification, launch, and `git diff --check`.
- **2026-07-15 (Codex, UI Dev all-surfaces Template Matrix):** Made the UI Dev
  workspace open on a responsive board containing twenty-two visible template
  specimens across seven categories. Each specimen names its ideal size and
  contains representative production content; Recent Projects, Agent, and the
  detached tool reuse their real views, while the Mate Editor and triad reuse
  their live labs. Focused pages and the editable Live UI Kit remain available
  in the ribbon. Two new catalog tests bring the full Swift suite to 172; strict
  recursive format lint, Xcode/root-app builds, signature verification, and
  `git diff --check` pass. The rebuilt app process launches, but accessibility
  reports zero windows, so Jonathan retains the final visual-density review.
- **2026-07-15 (Codex, UI Dev Reference Widgets pack 01):** Implemented the
  supplied layered-list, announcement-popup, and layout/style-inspector
  references as interactive SwiftUI prototypes in one dedicated modular file.
  Added a Reference Widgets ribbon lab and reused each specimen in the global
  matrix, which now contains 25 templates. The patterns remain UI Dev-only
  until individually reviewed for production adoption. One new catalog test
  brings the full Swift suite to 198; recursive format lint, Xcode/root-app
  builds, strict signature verification, and `git diff --check` pass. The app
  launches but exposes no window to accessibility automation in this session.
- **2026-07-15 (Codex, Timeline Design B reference fidelity):** Applied the
  supplied compact Blender-style timeline proportions to the existing UI Dev
  prototype without changing its shared model or the production Animate
  workspace. Dopesheet now opens by default with dense header chrome, searchable
  channels, an aggregate Summary lane, a 0–240 frame ruler at 30 fps, compact
  start/end fields, labeled blue playhead, matching frame grid, frame-aware
  footer, and full-state reset. Motion Curves and Waypoint Lanes remain
  switchable over the same tracks and keys. Ten focused and all 201 Swift tests,
  strict claimed-file format lint, Xcode/root-app build, signature verification,
  and `git diff --check` pass.
- **2026-07-15 (Codex, UI Dev all-variants comparison board):** Preserved the
  existing 29-template catalog and all focused labs, then added a separate wide
  Variant Board based on Jonathan's supplied component-board reference. A typed
  catalog defines 26 stable specimens across seven families: workspace chrome,
  docked panels, inspectors, timelines, toolbars/tool rails, dialogs/menus, and
  status/feedback. The four-column board supports text search, family filtering,
  50–110% specimen density, and selectable dashed comparison focus; every card
  names its state and intended production size. Eleven focused and all 202 Swift
  tests, strict claimed-file format lint, Xcode/root-app build, signature
  verification, and `git diff --check` pass.
- **2026-07-16 (Codex, engine-canonical project lifecycle):** Replaced the
  transitional flat `.animastudio` package with the agreed plain-folder
  project layout: app-owned `project.json`, indexed character folders with
  `assets/` and editor metadata, and indexed scenes. New, Open, Save, Save As,
  and Recent Project cards now use native macOS dialogs, security-scoped
  bookmarks, real folder paths, atomic whole-project replacement, and revision
  updates. Swift retains the full-fidelity rig DTO returned by
  `load_character`, calls AnimaCore `serialize_character`, writes only the
  returned text, and reopens canonical files through `load_character`; no YAML
  semantics entered the app. A real-engine integration test proves
  load -> serialize -> project Save -> project Open -> engine reload. Model
  imports copy into the active character's assets folder. Recursive format
  lint, 221 Swift tests, Xcode build, root-app build, strict deep signature,
  launch, and `git diff --check` pass. Scene reopening still waits for the
  engine's planned `load_scene`; transitional local rig editing remains
  presentation-only until it mutates the retained engine DTO.
- **2026-07-16 (Codex, Assets character manager + loading stage):** Assets now
  projects the project manifest's multi-character index into a dedicated
  gallery and loads the selected canonical character for all downstream
  workspaces. New Character performs document-layer unique-name validation,
  presents only the current rigid-parts 3D pipeline as active, asks AnimaCore
  to serialize/validate the empty DTO, and atomically creates its canonical
  character/editor files. Its async loading stage accepts batch picker/drop
  input, reviews STL/OBJ units, reports progress/errors inline, maps multi-node
  USD renderables into distinct Parts over one asset, saves, and enters Rig.
  Changed only claimed Swift/UI/document/tests/docs; concurrent unclaimed
  `animacore/{kinematics,loader,rig}.py` edits were preserved untouched. All
  224 XCTest + 15 bridge tests, recursive lint, Xcode/root-app builds, deep
  signing, launch, accessibility window presence, and `git diff --check` pass.
- **2026-07-16 (Codex, CAD mouse/navigation + settings):** Replaced the loose
  viewport event mapping with explicit Default/SolidWorks, Onshape, Fusion 360,
  and conflict-safe Custom profiles. Option chords, a tested right-click versus
  right-drag state machine, normalized reversible wheel zoom, precise drag zoom,
  middle-double-click framing, no-modifier toggle selection, Option
  select-through, selection counts, and directional window/crossing box select
  are wired through RealityKit presentation code only. The camera HUD now opens
  a reusable Mouse & Navigation sheet with Scroll, Mouse, Buttons, Keyboard,
  Exceptions, and Settings pages, a code-native mouse diagram, readable preset
  summaries, custom bindings, sensitivity controls, and reset. Verification
  passed: 231 XCTest plus 15 live-bridge Swift Testing cases, recursive format
  lint, native Xcode build, rebuilt root app, signing, launch, Assets-first/new
  character walkthrough, and `git diff --check`. The temporary walkthrough
  character remained honestly in its required model-loading stage; no engine
  files or semantics were changed.
- **2026-07-16 (Codex, three-column Asset Builder):** Replaced the Assets card
  gallery with the standard left-navigation / center-content / right-context
  workspace structure. The left adapter now renders through the shared
  `TreeView`; its character branches project engine parts, mates/relations,
  clips, indexed scenes, and app-owned appearance metadata, while the planned
  user Parts Library remains visibly outside character truth. The center swaps
  one collection surface by tree selection and provides a real selectable Parts
  table. The right side keeps the live batch model loader and embeds a compact
  RealityKit preview synchronized to the selected part. Added a deliberately
  small `editor.json` part-asset V counter (V1 on first import, +1 on successful
  one-file **Replace Part** upload; no history/PDM) with backward-compatible
  metadata decoding. A follow-up pins the center collection to the top and full
  available height, keeps zero-part collections as an empty table (the import
  drop target already lives at right), and renders the actual 3D preview even
  with an empty rig rather than substituting another empty-state message. The
  final consistency pass routes Characters, Parts, Source Assets, Renders,
  Assemblies, Scripts, Animations, and the planned Parts Library through one
  Table/Grid surface. Table is the default, headers remain visible while empty,
  and each body uses the same `No … yet` convention without another action.
  Verification: recursive lint clean; 272 XCTest + 20 Swift Testing pass;
  native Xcode and root-app builds pass; the bundled helper is deep-signed and
  the root app launches with the engine helper running. Automated desktop
  capture was not attempted after the environment rejected it as potentially
  exposing unrelated screen contents; operator visual review remains the final
  pixel-level check.
- **2026-07-16 (Codex, closed model-import contract + URDF direction):**
  Centralized Studio's operator import contract and now use it for both the
  file picker and drag/drop admission. The only admitted extensions are USD,
  USDA, USDC, USDZ, STL, and OBJ; every import surface states the same set, and
  STEP/STP, Reality, URDF, glTF/GLB, and unknown files fail before model
  loading. STL/OBJ retain the per-file unit prompt. Jonathan approved URDF as a
  future conventional-robot interchange importer that maps links/joints into
  canonical `.character.anima`, not as Anima's canonical character format.
  Four focused format tests, all 273 XCTest + 20 live-bridge Swift Testing
  tests, recursive lint, native Xcode build, root-app rebuild/deep-sign, launch,
  and `git diff --check` pass.
- **2026-07-16 (Codex, native import-panel repair):** Reproduced the structural
  risk behind Jonathan's report: the workspace root carried two independent
  SwiftUI `fileImporter` modifiers and live buttons only toggled presentation
  booleans. Replaced both with explicit native `NSOpenPanel` commands following
  the same proven app-modal pattern as project Open/Save. The Assets ribbon,
  center Import/Replace buttons, right-hand drop-zone click, and navigator
  footer now converge on one multi-file model chooser; Anima Character uses a
  single-file chooser. Cancel clears pending replace state and selections enter
  the existing unit-review/import pipeline. Two focused tests, all 275 XCTest +
  20 live-bridge Swift Testing tests, recursive lint, native/root builds, deep
  sign, launch, and `git diff --check` pass.
- **2026-07-16 (Codex, flattened Assets navigator):** Removed the redundant
  project-folder node from Asset Builder. A compact `PROJECT: <NAME>` header
  with a separate revision badge preserves context without behaving like a
  folder, while Characters and Parts Library are now the shared TreeView's
  direct roots. Character collections remain nested only beneath their owning
  character. Eight focused tests, all 275 XCTest + 20 Swift Testing tests,
  recursive lint, native/root builds, deep signing, launch, and
  `git diff --check` pass.
- **2026-07-16 (Claude, dense-CAD import crash fixed + scale plan):** Jonathan's
  real assembly (31 STLs, 34 MB, one 234k-triangle part) OOM-killed the
  viewport. Root cause: the CAD-selection topology (coplanar-face grouping with
  per-face triangle geometry, plus edges/corners) was computed eagerly for every
  part on load with no bound. Fix (commit `00c2d1b`): skip feature-topology above
  `maxTopologyTriangles = 40k` per file — heavy parts still load/render with
  whole-part selection, small parts keep face/edge selection; scales per-file at
  any part count. Confirmed the load path is otherwise robust (parse already runs
  off-main via `Task.detached`; per-file `try?` isolates a bad file to a
  placeholder). Wrote `dev/docs/roadmap/Loading_At_Scale.md` (phased plan for
  hundreds-of-parts / GB: LOD, bounded-parallel + progress, lazy topology,
  streaming) and queued the Lane A progress/cancel packet in codex.md IN. STATUS
  updated. `swift build` + 84 RealityKitViewport tests pass.
- **2026-07-16 (Codex, Assets bulk deletion + automatic replacement):** The
  Parts table and grid now share a semantic selection set: a plain click
  replaces the selection, Command/Shift-click toggles or extends it, and the
  preview highlights every selected part. The toolbar, context menu, and Delete
  key route through one confirmation flow. Confirmed deletion edits the retained
  engine rig DTO, removes dependent joints, relations, outputs, and deleted-DOF
  clip values, then serializes and reloads through canonical AnimaCore before
  pruning app metadata. Embedded files are physically removed only when no
  surviving part references them; locked parts reject the operation. Reimporting
  the same original filename now atomically replaces the stable embedded asset,
  increments the small app-side V counter for every part sharing it, and changes
  renderer identity so same-path geometry reloads instead of creating a
  duplicate part. Changed the claimed Assets/workspace, bridge-editor,
  document-store, and viewport-source files plus focused tests and STATUS. Five
  focused tests, all 279 XCTest + 22 live-bridge Swift Testing tests,
  claimed-file lint, native Xcode build, root-app rebuild/deep-sign, launch, and
  `git diff --check` pass. Recursive lint's only warnings are in Claude's
  preserved untracked `CarReproProbe.swift`; Codex recorded that in Claude's
  mailbox rather than modifying another agent's file.
- **2026-07-16 (Claude, imported-mesh render bug + pipeline audit):** Jonathan's
  32-part car imported but rendered as box/cylinder proxies. Root cause was NOT
  the loader (proven: loads fine; 32/32 render-ID hits) — `loadAnimaCharacter`
  wiped `enginePartModelSources` on every reload and only a separate
  `configurePartModelSources` call (not on all paths) repopulated it, so any
  engine reload after open dropped every part to a proxy (probe: `afterReload
  sources=0`). Fix (commit `9b0049e`): the workspace retains the asset dir +
  editor metadata and rebuilds sources inside `loadAnimaCharacter`, so no path
  can forget; portable regression test `PartModelSourceReloadTests`. Also:
  (`fe919c0`) removed `sectionPlane.*` from `sceneIdentity` so dragging the clip
  plane no longer re-parses every STL from disk (update: applies it live);
  (`f94526b`) mesh-load failures now log via os.Logger instead of silently
  faking a proxy. Read-only audit (subagent) confirmed the AnimaCore bridge is
  genuinely wired (no mocked engine results) and flagged: the car's STLs are in
  shared assembly space so they'll lay out correctly (no origin-overlap for this
  file); import does NOT capture assembly positions for local-space exports (real
  gap, noted); the relation editor is a dead stub (Codex lane — engine supports
  it). Codex packets queued in codex.md IN. `swift build` + 84 viewport tests +
  the new regression test pass; lint clean on changed files.
- **2026-07-17 (Codex, Assets Shift-range + Delete-key repair):** Replaced the
  previous ambiguous `extending` toggle with a pure anchored selection model.
  Plain click replaces and establishes the anchor; Command-click toggles and
  moves the anchor; Shift-click selects the inclusive range between anchor and
  clicked row in current filtered order; Command-Shift unions that range with
  the existing selection. The content surface now explicitly takes keyboard
  focus after a row click and handles both Backspace/Delete and Forward Delete,
  while retaining the native delete command as a fallback; every route enters
  the existing confirmation and canonical engine-backed deletion flow. Added
  forward/reverse range, additive range, missing-anchor, replacement, and toggle
  tests. All 12 focused Assets tests, 282 XCTest + 22 live-bridge Swift Testing,
  claimed-file lint, native Xcode build, root-app rebuild/deep-sign, launch, and
  `git diff --check` pass. Recursive lint's three warnings were solely in
  Claude's transient local probe, which Claude removed during verification.
- **2026-07-17 (Codex, standalone GeomBench CAD architecture harness):** Added
  the isolated `cad-test/` package without modifying Anima Studio or the
  existing CAD labs. Its XDE/STEPCAF C++ shim emits contiguous face, normal,
  index, feature-edge, assembly-node, transform, color, tolerance, and staged
  timing data. One native SwiftUI workspace compares OCCT→RealityKit,
  OCCT→raw MetalKit, OCCT's AIS/TKOpenGl viewer, and a mesh-only
  ModelIO→RealityKit baseline; a separate built Qt6+OCCT desktop-GL app is
  embedded as Pipeline 4. Pipeline 5 is intentionally capability-gated because
  the installed OCCT is desktop-GL and cannot truthfully become GLES by linking
  MetalANGLE at runtime. The shared camera supports orbit/tilt, pan, roll,
  wheel zoom, and fit, with an on-viewport mapping legend and matching native
  OCCT/Qt controls. Added a headless `geom-probe`, tested an actual 2,631-face /
  7,443-edge STEP part, passed three deterministic Swift tests, built both
  release renderers, deep-signed `cad-test/GeomBench.app`, verified its bundle,
  and launched it successfully in the GUI domain.
- **2026-07-17 (Codex, Codex Bench hosted P4 renderer):** Renamed the visible
  standalone product and artifact to `cad-test/Codex Bench.app` while retaining
  stable internal module names. Pipeline 4 no longer opens an operator-facing
  Qt window: Swift owns one reusable hosted-renderer client, sends load/orbit/
  pan/roll/zoom/fit commands to the bundled Qt/OCCT helper, receives timing/FPS/
  memory telemetry, and presents its OCCT frame in the same viewport. The frame
  uses a private bootstrap Mach service to transfer an IOSurface port rather
  than an insecure global surface id. P5 is wired to the same capability-gated
  host boundary for when GLES OCCT + MetalANGLE exist. Three Swift tests, a real
  320x240 cross-process surface probe, Swift/Qt release builds, deep signature,
  packaged P4 launch, and clean app/helper shutdown passed; no main-app files
  changed.
- **2026-07-17 (Codex, Codex Bench operator-owned inputs):** Removed every
  automatic sample from the app workflow. Startup now has an empty file list
  and empty viewport; switching pipelines never creates geometry. The P3
  in-memory OCCT box/cylinder path, P4 hosted `demo` verb, generated temporary
  ModelIO OBJ, sidebar fixture row, and no-argument probe fallback are gone.
  P1–P5 wait for an operator-selected STEP/STP, while P6 waits for an
  operator-selected STL/OBJ/USD-family mesh. Internal generated geometry stays
  unit-test-only. Three Swift tests, Swift and Qt release builds, app assembly,
  deep signature, empty-start launch, and `git diff --check` pass.
- **2026-07-17 (Codex, expanded Codex Bench comparison + Unity route):**
  Expanded the isolated benchmark to eight honest choices with fully spelled
  product/framework names. P6 is a real local WKWebView/WebGL 2 renderer fed
  by Open CASCADE Technology's operator STEP tessellation; the live ARCADA
  part uploaded 13,102 triangles. OpenGeometry stays capability-gated because
  its operator-file import/direct-WebGL adapter is not ready upstream.
  Per Jonathan's direction, removed MetalANGLE from the picker, capability
  model, Qt build, and docs instead of carrying a non-working option. Added a
  source-controlled Unity 2022 WebGL project with runtime STL/OBJ parsing,
  camera orbit/pan/roll/zoom, an embedded Swift WebKit host, capability probing,
  build/package scripts, and clear format separation (Unity renders meshes;
  Open CASCADE Technology owns STEP). Unity compilation reached the installed
  editor but stopped at its external license gate: no active Unity license is
  present on this Mac. Once Jonathan activates Unity Personal, running
  `cad-test/scripts/build-unity.sh` produces the player and `make-app.sh`
  bundles it automatically. Three Swift tests, recursive lint, debug/release
  builds, deep signature verification, P6 live render, and the P8 app state
  pass; `git diff --check` is clean.
- **2026-07-17 (Codex, Claude theme ideas ported into Codex Bench):** Reviewed
  Claude Bench and Gemini's test app. Gemini's three-engine shell did not
  improve on the existing workspace; Claude's renderer-neutral theme contract
  did. Added one persistent four-preset `BenchTheme` source of truth with
  Studio Blue as the default plus Showroom, Technical Matte, and Warm Workshop.
  The toolbar switches themes live. RealityKit receives roughness/metallic and
  key/fill/rim lights while retaining imported STEP/XDE colors; raw Metal gets
  equivalent background/light uniforms; WebGL, the Swift-hosted native Open
  CASCADE viewer, and the hosted Qt renderer update their backgrounds through
  their existing boundaries. Model I/O neutral materials also follow the
  theme. Three tests, recursive lint, Swift and Qt release builds, deep signing,
  and live operator-model P1/P2 launches pass; both processes remained healthy.
- **2026-07-17 (Codex, P2 Metal theme correction):** Jonathan's screenshot
  exposed a real color-management bug: display-referred theme values were sent
  to an sRGB Metal attachment and gamma-encoded again, making Studio Blue gray
  and flattening the part. P2 now uses the matching display target, adds
  theme-driven hemisphere/key/fill/rim/specular response, and renders the
  imported Open CASCADE B-Rep edge polylines with a less-equal edge pass for
  CAD definition. Imported face colors remain the base color. Three tests,
  focused lint, release build, Qt repack, deep sign, and a live P2 launch with
  the same ARCADA STEP pass; the runtime shader stayed healthy.
- **2026-07-17 (Codex, full themes + working-STEP-only catalog):** Promoted
  `BenchTheme` from a background preference into a complete render preset.
  RealityKit now adds batched B-Rep edge geometry and theme-colored selection;
  Metal, WebGL, native Open CASCADE AIS, and the hosted Qt/Open CASCADE renderer
  all map the same background, finish, edge, selection, and key/fill/rim intent
  into their native render APIs. Both native Open CASCADE paths now retain XDE
  root colors instead of forcing a blue body. Per Jonathan, removed Model I/O,
  OpenGeometry, and Unity from the app and deleted their app/source integration:
  Codex Bench now lists only five pipelines that can load an operator-selected
  STEP/STP file inside the Swift app today. Verification: three Swift tests,
  Swift debug/release builds, native bridge compile, Qt hosted release build,
  deep bundle signature, fresh app launch, and `git diff --check` pass.
- **2026-07-19 (Codex, nine-pipeline measured decision):** Added a normalized
  signed-app benchmark mode that waits for renderer readiness, drives the same
  60 Hz orbit, counts delivered frames, and samples main/helper CPU and memory
  into structured JSON. Ran the medium model once and the 2,631-face heavy
  model three times through all nine routes. Fixed the P6 load-before-WebEngine
  startup race uncovered by the suite and made P3's deferred native load time
  observable. P2 Open CASCADE → MetalKit is the production recommendation:
  60.0 FPS in all heavy runs, 19.7% median CPU, 272.1 MB, 2.33 s ready. P4 Qt
  hosting reached 42.5 FPS/128.9% CPU; P6 Qt WebEngine 33.5 FPS/91.0% CPU; P8
  selectable RealityKit 30.0 FPS/151.4% CPU/867.6 MB. The report and all raw
  JSON live in `dev/Codex Bench/Reports/2026-07-19-pipeline-study/`. Also made
  app packaging always rebuild release instead of silently copying a stale
  binary. Twelve tests, clean recursive lint, Swift/Qt release builds, deep
  signature, and `git diff --check` pass.
- **2026-07-19 (Codex, Qt retired from the Apple benchmark):** Removed measured
  P4 Qt/Open CASCADE and P6 Qt WebEngine from Codex Bench's Apple catalog,
  Settings, runtime/session, automated benchmark, Swift package dependencies,
  and signed bundle. Historical IDs stay stable, and saved P4/P6 preferences
  now fall back to P1. Packaging actively deletes stale helper apps. The `qt/`
  sources and a build-only script remain archived for a future separate Qt
  product, with the current AppKit/IOSurface host documented as macOS-specific.
  Thirteen Swift tests, recursive format lint, release build/package, deep
  signature, no-Qt linkage/bundle inspection, live launch, and diff check pass.
- **2026-07-19 (Codex, four retained Codex Bench pipelines):** Pruned the app
  and package to P1 RealityKit, P2 MetalKit, P5 dependency-free WebGL 2, and P7
  direct Three.js/WebGL 2. Removed P3 desktop OpenGL, P8's resource-heavy
  per-feature RealityKit graph, P9 SceneKit, the OpenGeometry dependency/WASM,
  and all stale bundle resources. P5/P7 receive the same Open CASCADE STEP
  document and differ only in raw versus higher-level browser rendering. A
  normalized 54,830-triangle pass measured P1 50.7 FPS/70.6% CPU, P2 59.8
  FPS/23.5% CPU, P5 61.2 FPS, and P7 62.7 FPS; WebKit CPU/memory remains
  host-only. Three.js added 6 ms over raw upload and stays as an optional
  environment pipeline. Twelve tests, lint, release/deep sign, dead-linkage and
  resource audit, and all four signed-app benchmark launches pass.
- **2026-07-19 (Codex, combined 46-file assembly benchmark):** Added a real
  multi-file renderer document path instead of mistaking the first sidebar
  selection for an assembly. Imports remain serialized through Open CASCADE;
  merge remaps face/edge/node IDs and benchmark JSON records every source. The
  headless probe merged 46 files into 46 nodes, 8,931 faces, 24,778 edges, and
  247,030 triangles in 6.83 seconds. P2 Metal became ready in 6.94 seconds and
  delivered 59.84 FPS at 20.34% CPU in the visible run. P1's current
  face-per-entity RealityKit graph never became ready after 4m55s and consumed
  roughly 676–719 MiB; it is disqualified for the main assembly viewport
  without batching. P5/P7 accepted all geometry, but background-throttled
  WebKit FPS and host-only resource accounting are explicitly withheld. Report:
  `dev/Codex Bench/Reports/2026-07-19-assembly-benchmark/`. Thirteen tests,
  recursive lint, release package, deep signature, and P2/P5/P7 assembly runs
  pass; P1 is retained as the measured negative result.
- **2026-07-19 (Codex, retained-pipeline production optimization):** Kept all
  four renderer choices and made their roles explicit: P2 Metal production
  candidate, P1 RealityKit secondary Apple preview, P7 Three.js optional
  environment, and P5 raw WebGL diagnostic baseline. Added one compact shared
  `RenderGeometry` projection with material/part batches, face/part IDs, exact
  edges, and cached bounds; STEP documents now cache by file size/mtime and
  pipeline switching does not re-import. P1 replaced the 8,931-entity graph
  with one retained `LowLevelMesh` and removed an observable-state feedback
  loop from its renderer callback. P2 now uses packed GPU-private static
  buffers, exact line geometry, a stable per-part transform table, and
  triple-buffered uniforms; the pass also surfaced and fixed a runtime Metal
  normal-matrix compilation error. P5/P7 now transfer one compact binary block
  into typed arrays; Three.js uses indexed groups/materials. On all 46 files
  (247,030 triangles), P2 measured 59.92 FPS/19.71% CPU/231.21 MB and P1
  59.83 display-link Hz/21.29% CPU/378.83 MB. WebKit results retain explicit
  helper-process accounting caveats. Report and raw JSON:
  `dev/Codex Bench/Reports/2026-07-19-optimized-pipelines/`. Changed the core
  render projection/document, all four active renderers, session/benchmark
  contracts, Three.js resource, probe, tests, renderer/benchmark docs, and
  status. Sixteen tests, recursive lint, release package, deep signing,
  46-file probe, and all four signed-app assembly runs pass.
- **2026-07-19 (Codex, Three.js WebGPU-first P7):** Replaced P7's historical
  `WebGLRenderer` with the bundled Three.js `WebGPURenderer`, including async
  initialization, automatic WebGL 2 fallback, and actual-backend reporting in
  the workspace, Settings, status, and benchmark JSON. The signed WKWebView
  selected native WebGPU and loaded the combined 46-file/247,030-triangle
  assembly. A same-build P5/P7 pass measured raw WebGL 2 at 78.02 FPS/11.77%
  app CPU/286.61 MB and Three.js WebGPU at 65.54 FPS/9.53% app CPU/386.46 MB;
  system WebKit helper processes remain excluded. P2 Metal stays production,
  P7 stays the optional rich-environment route, and P5 stays the diagnostic
  baseline. Report: `dev/Codex Bench/Reports/2026-07-19-webgpu-pipeline/`.
  Verification: npm production bundle, 16 Swift tests, recursive format lint,
  release build, deep signature, and final signed-app full-assembly WebGPU run.
- **2026-07-19 (Codex, direct WebGPU P10):** Added a framework-free browser
  renderer using `navigator.gpu`, explicit geometry/uniform buffers, cached
  camera matrices, four-sample color/depth attachments, and WGSL surface/edge
  shaders. It consumes the same compact Open CASCADE projection and preserves
  shared themes plus CAD orbit/pan/roll/zoom/fit controls. The signed app loaded
  all 46 files/247,030 triangles. A P5/P7/P10 snapshot measured 60.80/61.24/
  60.78 FPS and 41/47/42 ms setup; repeated P10 FPS varied 51.63–60.78 due to
  WebKit callback scheduling while upload remained 41–43 ms. P10 therefore
  replaces P5 raw WebGL 2 in the active picker as the modern browser API path,
  not as a claimed FPS win. P7 retains its compatibility fallback. Report:
  `dev/Codex Bench/Reports/2026-07-19-raw-webgpu/`. Sixteen tests, recursive
  lint, release build, deep sign, and final signed-app assembly runs pass.
- **2026-07-19 (Codex, CodexUI modular-panel redesign):** Rebuilt the isolated
  CodexUI walkthrough around the visual/layout contract in `dev/AnimaStudio
  Demo/` without importing its real renderer or any product backend. A single
  `DockingWorkspace` now hosts every workspace's left browser and right
  inspector as docked, in-window floating, or hidden regions with shared
  chrome and edge restore controls. The same workspace tool catalog now renders
  either as a full docked ribbon or a compact floating palette with tool-group
  popovers. Studio, Classic, and Canvas presets coordinate all three regions;
  the UI Kit demonstrates the contract and a native Settings scene edits it.
  Assets, Rig, Animate, Show, Hardware, Nodes, and UI Kit retain their existing
  purpose-specific content. Four tests, recursive format lint, release bundle,
  deep signature, live-process check, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI readability refinement):** Removed the two
  principal overlap hazards introduced by floating chrome. Floating side
  regions now reserve left/right content lanes and the compact ribbon reserves
  a top lane; the guided walkthrough moved from a bottom overlay into the
  normal shell flow. CAD Light now selects SwiftUI's actual light color scheme
  (fixing system secondary-label/control contrast), while all themes use
  stronger secondary text, strokes, icon foregrounds, and theme-specific
  ribbon colors. Shared tree rows, workspace tabs, ribbon groups/tools, panel
  borders, and chrome controls now provide visible hover, press, selection, and
  spring placement feedback. Four tests, recursive format lint, release build,
  deep sign, restarted live app, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI workspace-stage navigation):** Replaced the
  redundant horizontally scrolling workspace buttons with a dedicated
  `WorkspaceStageTabs` implementation of the supplied AnimaStudio Demo
  reference. The centered dark capsule contains only the five authoring stages
  (Assets, Rig, Animate, Show, Hardware), uses larger icon/label targets, and
  moves the blue active capsule with matched-geometry spring animation. Nodes
  and UI Kit stay available in a separately labeled Utilities section of the
  workspace dropdown. At narrower window widths the stage bar switches to
  icon-only buttons so it cannot overlap the project selector or right-side
  layout controls. Hover, help, selection, and accessibility traits are
  explicit. Five tests, recursive lint, release build, deep sign, relaunched
  app, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI single-row header):** Condensed the 43-point
  global bar plus 61-point workspace bar into one 62-point header while keeping
  `WorkspaceStageTabs` absolutely centered. The left cluster now holds the
  brand, grouped all-workspace menu (including Nodes/UI Kit), project/revision,
  Home, one File menu, Undo, and Redo. The right cluster combines engine and
  driver truth into a status popover, preserves Master Live and browser/
  inspector/ribbon toggles, and keeps Settings and Help. Theme and layout
  controls moved out of permanent chrome into the existing native Settings
  scene. Compact widths shorten brand/project/status text and use the stage
  bar's icon-only mode instead of overlapping. Five tests, recursive lint,
  release build, deep sign, relaunched app, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI true floating + consolidated controls):**
  Restored the semantic difference between docked and floating regions:
  docked browsers/inspectors participate in the HStack and reduce the center,
  while floating panels and the compact ribbon overlay an unreserved,
  full-size workspace. Each panel's own placement button now toggles
  dock/float on primary click and retains Dock/Float/Hide in its menu. The
  three duplicate header panel buttons are replaced by one layout control;
  primary click cycles Studio/Classic/Canvas, while its dropdown exposes all
  presets and individual Browser/Inspector/Ribbon states. Five tests,
  recursive lint, release build, deep signature, live PID 70962, and
  `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI content-aware floating safe areas):** Added a
  reusable floating-chrome obstruction environment derived from live left,
  right, and ribbon placement. Rig and Nodes remain full-bleed spatial
  canvases. Assets, Hardware, and UI Kit opt their structured centers into the
  full unobstructed area. Animate and Show apply only horizontal clearance to
  their timelines, leaving the 3D preview behind the floating panels. The pure
  inset resolver is covered by a sixth test. Recursive lint, release build,
  deep signature, live PID 79970, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI single workspace navigator):** Removed the
  redundant left-header workspace icon/dropdown. `WorkspaceStageTabs` is now
  the only workspace selector and lists all seven destinations in the centered
  capsule. A subtle divider preserves the five-stage authoring path versus the
  Nodes/UI Kit utilities without hiding either behind another control. At
  widths below 1600 points every workspace remains accessible as an icon-only
  tab with its tooltip and accessibility label. Six tests, recursive lint,
  release build, deep signature, live PID 86025, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI configurable workspace labels):** Replaced the
  all-or-nothing compact label behavior with four explicit modes: Automatic,
  All Labels, Selected Only, and Icons Only. Automatic is the default: all
  seven names appear when space permits; compact chrome keeps the active name
  visible and collapses only inactive names. The Workspace Settings tab owns
  the override and explanation. Seven tests, recursive lint, release build,
  deep signature, live PID 4957, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI floating walkthrough):** Removed the tour card
  from the shell's `VStack` layout and presented it as a bottom-center overlay
  above the status bar. The popup uses constrained width, native material,
  accent border, deeper elevation, and a bottom transition; previous/next,
  dismissal, shortcuts, and the Settings toggle remain unchanged. Showing or
  hiding it no longer moves any workspace surface. Seven tests, recursive
  lint, release build, deep signature, live PID 14724, and `git diff --check`
  pass.
- **2026-07-19 (Codex, CodexUI borderless spatial viewport):** Removed the
  shared `MockViewport` rounded clip and outline, and made the Rig, Animate,
  and Show center surfaces zero-inset. Their grid/background now extends to the
  workspace edges behind floating chrome. Animate/Show timelines retain their
  own ten-point spacing and obstruction avoidance, and true controls such as
  the ViewCube keep their boundaries. Seven tests, recursive lint, release
  build, deep signature, live PID 21446, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI header/footer hierarchy):** Replaced the
  upper-left CodexUI brand with the live workspace name. Moved the combined
  layout control and Settings to the left and made the layout button state
  explicit as Studio/Classic/Canvas/Custom. Project/file/undo remain left;
  Engine Ready, Master Live, and Help remain right. The small CodexUI mark/name
  now begins the 25-point footer. Center navigation and functionality are
  unchanged. Seven tests, recursive lint, release build, deep signature, live
  PID 28613, and `git diff --check` pass.
- **2026-07-19 (Codex, Spatial-to-CodexUI floating widget transfer):** Read
  Codex Spatial's `SpatialWorkspace`, `GlassPanel`, and timeline presentation
  before retirement and moved its useful visual contract—not its architecture
  or backend—into CodexUI. Floating Browser/Inspector regions no longer render
  one full-height slab: their placement bar is an independent elevated
  material surface, and nested `PrototypePanel`s become separate 12-point
  material cards with individual strokes, shadows, and canvas gaps. The same
  content returns to the original flush/continuous presentation when docked.
  Codex Spatial remains untouched pending an explicit removal request. Seven
  tests, recursive lint, release build, deep signature, live PID 36273, and
  `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI project identity correction):** Corrected the
  meaning of "workspace name" from the active mode to the open project. The
  far-left, first header element now always shows the orange cube, **Atlas
  Animatronic**, and green **SAVED**, matching the supplied reference even in
  compact chrome. The centered selected tab continues to name Assets/Rig/etc.
  Layout and Settings follow the project identity. Seven tests, recursive
  lint, release build, deep signature, live PID 45426, and `git diff --check`
  pass.
- **2026-07-19 (Codex, explicit CodexUI layout naming):** Renamed the ambiguous
  visible Studio/Classic presets to **Floating** and **Docked**; Canvas remains
  Canvas and unmatched manual combinations report Custom. The header button,
  dropdown, and Settings now describe the actual panel mode while retaining
  the same state machine and click-to-cycle behavior. Seven tests, recursive
  lint, release build, deep signature, live PID 45426, and `git diff --check`
  pass.
- **2026-07-19 (Codex, CodexUI floating ribbon cleanup):** Removed the
  redundant workspace icon/name from the floating palette and removed
  permanent boxes/strokes from each tool group and tool; only restrained
  hover/selected fills and a two-point active indicator remain. Added explicit
  Top/Bottom floating-edge selection to the ribbon menu, combined header menu,
  and Settings. Top-edge group popovers use a top arrow and open below; bottom
  uses a bottom arrow and opens above, toward the application center. Shadow,
  structured safe-area insets, timelines, and walkthrough clearance all follow
  that edge. Seven tests, recursive lint, release build, deep signature, live
  PID 59875, and `git diff --check` pass.
- **2026-07-19 (Codex, full-width timelines and compact floating panels):**
  Animate and Show timelines now use the same complete center width as their
  viewport instead of reserving horizontal space for overlay panels; they keep
  only the necessary bottom-ribbon clearance. Shared floating Browser and
  Inspector regions now cap at 72% of workspace height with a small-window
  fallback, leaving visible canvas beneath them, while docking restores the
  existing full-height side columns. Added deterministic responsive-sizing
  coverage. Eight tests, recursive lint, release build, deep signature, app
  launch, and `git diff --check` pass.
- **2026-07-19 (Codex, CodexUI viewport performance HUD):** Added one reusable
  bottom-right telemetry card to the main Rig, Animate, and Show render views,
  modeled on Codex Bench's hierarchy. It presents renderer, FPS, CPU, memory,
  and GPU rows without covering the bottom control strip; a new gauge control
  in each viewport and a Behavior setting toggle it. Since this walkthrough
  has no renderer backend, both a **Sample** badge and pending-hook footer make
  the demonstration values honest. Eight tests, recursive lint, release build,
  deep signature, launch, and `git diff --check` pass.
- **2026-07-19 (Codex, centralized placement + Canvas edge reveal):** Removed
  the duplicate pin/dock/float menu from Browser and Inspector headers; the
  top layout control and Settings now own placement, while ordinary visible
  panels retain only Close. Canvas mode replaces its old persistent reveal
  buttons with two-pixel edge affordances: hovering left or right temporarily
  presents the corresponding compact floating panel, and leaving dismisses it
  without mutating the Canvas preset. Peek-only headers omit Close because the
  underlying panel is already hidden. Nine tests, recursive lint, release
  build, deep signature, launch, and `git diff --check` pass.
- **2026-07-19 (Codex, independently floating context widgets):** Completed
  the sidebar cleanup by removing the redundant outer Browser/Inspector header
  in both docked and floating presentations. Floating content now collapses
  its internal stack spacers so each real `PrototypePanel` sizes to its own
  controls and keeps deliberate card-to-card gaps. Right-side context widgets
  each expose a header grip and maintain an independent constrained drag
  offset; docking clears those offsets and restores the stable full-height
  column. Nine tests, recursive lint, release build, deep signature, launch,
  and `git diff --check` pass.
- **2026-07-19 (Codex, compact CodexUI header):** Matched the sibling
  AnimaStudio Demo's chrome density through a shared header-metrics contract:
  one 54-point row, 24-point icon controls, and 28–30-point centered workspace
  chips. The complete project/layout/settings/file/edit icon set remains. The
  right side now uses compact Live status and Preview playback capsules, keeps
  Help at the end, and retains Master Live in both the status popover and
  Settings. Ten tests, recursive lint, release build, deep signature, launch
  (PID 33363), and `git diff --check` pass.
- **2026-07-19 (Codex, layout mode moved beside Help):** Moved the former
  text-bearing layout control out of the left command cluster and placed it at
  the far right immediately before walkthrough Help. Floating, Docked, Canvas,
  and Custom now use distinct icons with cyan, purple, orange, and green boxes;
  primary click still cycles presets and the full menu still edits individual
  panel/ribbon states. Ten tests, recursive lint, release build, deep signature,
  launch (PID 42706), and `git diff --check` pass.
- **2026-07-19 (Codex, floating 3D preview sizing):** Added an explicit,
  reusable 220-point minimum content height for spatial preview panels and
  applied it to Assets Preview. The 3D canvas no longer collapses to the
  header's intrinsic height, while compact non-spatial property widgets retain
  content sizing. Ten tests, recursive lint, release build, deep signature,
  launch (PID 50439), and `git diff --check` pass.
- **2026-07-19 (Codex, Codex Spatial consolidation):** Migrated the useful
  Spatial patterns into CodexUI's UI Kit as three reusable specimen families:
  interactive tool rail + adaptive keyframe actions, hierarchy + mate + live
  hardware panel stack, and a full-width Live Follow timeline with keyframes,
  playhead, and audio waveform. After the migration built and tested, removed
  the separate untracked `dev/Codex Spatial/` source and app. Ten tests,
  recursive lint, release build, deep signature, launch (PID 64634), and
  `git diff --check` pass.
- **2026-07-19 (Codex, smooth constrained floating-widget drag):** Replaced
  `GestureState` plus fixed post-drag offsets with direct transaction-controlled
  updates from a captured widget frame. Every pointer update is clamped against
  the real workspace size with an eight-point margin, so no edge can leave the
  visible window and there is no release snap. While moving, the card swaps its
  expensive backdrop material for an opaque themed surface and reduces shadow
  cost; material returns at rest. Eleven tests including upper-left/lower-right
  boundary cases, recursive lint, release build, deep signature, launch (PID
  85308), and `git diff --check` pass.
- **2026-07-19 (Codex, living UI Kit gallery + coverage contract):** Rebuilt
  UI Kit after the AnimaStudio Demo's flat design-system board: 28-point title,
  explanatory subtitle, uppercase named sections, adaptive 300-point specimen
  cards, consistent 16/28/30 spacing, and an 1180-point review width. App
  chrome, timelines, viewport, and Settings receive full-width specimens;
  existing CodexUI and migrated Spatial widgets remain. Added actual workspace
  tabs, adaptive ribbon, production timeline, performance HUD, command-button,
  metric, input, layout, token, Settings, and viewport specimens. A visible
  16-of-16 `UIKitAssetCatalog` inventory plus deterministic test establishes
  the rule that every new reusable asset gains a UI Kit specimen. Twelve tests,
  recursive lint, release build, deep signature, launch (PID 98746), and
  `git diff --check` pass.
- **2026-07-19 (Codex, flattened UI Kit specimens):** Removed the generic
  background and outline from every specimen cell so already-contained widgets
  no longer appear as a box inside another box. Preserved the interactive
  selection rail beside its adaptive keyframe action panel, removed only their
  redundant enclosing `Selection Tools` panel, and kept the descriptive caption
  below the natural-size group. The catalog remains 16-of-16. Twelve tests,
  recursive lint, release build, deep signature, launch (PID 11647), and
  `git diff --check` pass.
- **2026-07-19 (Codex, complete Nodes UI Kit):** Replaced the UI Kit's
  one-off generic node drawing with the actual reusable components shared by
  the Nodes workspace: categorized searchable library, selected-node
  inspector, typed-port row, node card, and connected canvas. The gallery now
  shows input, logic, AI/media, and hardware cards across normal, selected, and
  warning states plus a full-width graph with connections, status, zoom, and
  auto-layout controls. Coverage is 21-of-21. Twelve tests, recursive lint,
  release build, deep signature, launch (PID 19552), and `git diff --check`
  pass.
- **2026-07-19 (Codex, full-bleed node canvas):** Removed the shared node
  canvas's generic rounded clipping and enclosing outline, matching the
  borderless 3D workspace treatment. The graph background now becomes the
  workspace surface in both Nodes and UI Kit, while node cards and local
  controls keep their functional boundaries. Twelve tests, recursive lint,
  release build, deep signature, launch (PID 8142), and `git diff --check`
  pass.
- **2026-07-19 (Codex, AnimaStudio Demo visual-system convergence):** Moved
  CodexUI's shared palette to the Demo's restrained surfaces, text hierarchy,
  low-contrast strokes, and semantic colors. Added Studio Blue, Teal, Indigo,
  Orange, Graphite, CAD Light, and Midnight choices with a visual picker and
  complete UI Kit token board. Refined the shared panel header, selected row,
  property field, badge, metric, command button, saved-state badge, and
  icon-only floating ribbon rather than restyling individual screens; all
  workspaces and UI Kit specimens therefore update from the same components.
  Twelve tests, recursive lint, release build, deep signature, launch (PID
  25144), and `git diff --check` pass.
- **2026-07-19 (Codex, production UI migration):** Migrated the approved
  CodexUI system into the real `app/` shell while preserving its engine,
  document, import, viewport, and timeline paths. The production app now owns
  the restrained Studio palette, one compact project-first header, centered
  seven-workspace navigator, dock/float/canvas side regions, top/bottom
  floating ribbon, edge restoration, status footer, and non-layout walkthrough.
  UI Dev renders the actual production chrome/layout/ribbon and now catalogs 34
  specimens. The old prototype moved non-destructively to
  `dev/archive/CodexUI/`. Recursive lint, 284 Swift tests, 22 live bridge tests,
  native Xcode build, root helper embedding/deep signing, launch, and
  `git diff --check` pass. Codex Bench renderer integration remains a separate
  next phase.
- **2026-07-19 (Codex, production Assets layout correction):** Found during
  the strict archive audit that Assets still bypassed the shared layout path.
  Its real character tree and import/preview inspector now honor the global
  Docked/Floating/Canvas state, use the same panel surface tokens as the rest
  of production, reveal from the window edges in Canvas, and reserve table
  clearance while floating. The focused 12-test Assets suite, native root-app
  rebuild/sign, launch, and diff check pass. The broader CodexUI archive audit
  remains active; this correction does not yet label the archive deletable.
- **2026-07-19 (Codex, character-targeted part-import staging):** Made the
  Assets import path state the actual authoring contract before loading:
  choose an indexed Character, review how each source becomes rigid Parts,
  confirm unit conversion, and place every new Part at the Character origin.
  Imports safely save/switch to the selected Character, copy source files into
  that Character's assets, and remain in Assets for organization before the
  operator moves to Rig to create mates. Replacement imports stay locked to
  the active Character. UI Dev now renders the production staging sheet as its
  35th specimen. Recursive lint, 287 XCTest tests, 22 bridge/integration tests,
  native/root build with bundled AnimaCore helper, deep signing, launch, and
  `git diff --check` pass. No engine semantics changed: Parts remain
  Character-relative; world placement belongs to Show/scene state.
- **2026-07-20 (Codex, centered empty-Rig call to action):** The viewport's
  overlay stack remains top-aligned for its title and camera HUD, but the
  empty-Rig card now expands through the usable viewport and centers its own
  content horizontally and vertically. Focused Rig tests (6), recursive lint,
  native/root build, helper embedding/deep signing, launch, and diff check
  pass.
- **2026-07-20 (Codex, compact centered header + Studio modes):** Matched the
  approved demo header more closely in production: project identity and file
  commands stay left, the stage capsule is absolutely centered and now shows
  text only for the active workspace, and runtime/layout/help stay right. The
  compact capsule is bounded to 300–430 points. Standardized the operator
  labels to Floating, Docked, Canvas, and detected Custom; the header control
  still cycles presets and its menu still owns individual Browser, Inspector,
  and Tool Ribbon placement. Settings calls the preference a Default Studio
  mode. Recursive lint, 288 XCTest tests, 22 bridge/integration tests,
  native/root build, helper embedding/deep signing, launch, and diff check
  pass.
- **2026-07-20 (Codex, continuous macOS header surface):** Replaced the main
  window's unified native title strip with the same hidden transparent
  title-bar style used by the approved demo. Native traffic lights remain, but
  the root content now supplies one continuous header surface and the redundant
  upper `Anima Studio` band is gone. Targeted format/diff checks, native/root
  build, helper embedding/deep signing, and launch pass; the immediately prior
  full run remains 288 XCTest plus 22 bridge/integration tests.
- **2026-07-20 (Codex, reusable Character Library + pinned Project copies):**
  Established the intended animatronics ownership boundary in the real app.
  Reusable Character packages now live in the user workspace's `Character
  Library/`, with stable UUID and simple publish revision. Assets presents
  Project Characters separately from Library sources; Publish saves and copies
  the full Character package, while Add installs a self-contained Project
  snapshot and safely resolves name collisions. Additive v2 `project.json`
  provenance identifies project-local vs library-snapshot Characters without
  touching canonical engine YAML, and save paths preserve it. The roadmap now
  fixes Character/Project/hardware ownership and World -> Character -> Part
  framing; Claude received the scene-instance/hardware-binding contract request.
  Recursive touched-file lint, 292 XCTest tests, 22 bridge/integration tests,
  native/root build, helper embedding, deep signing, live launch, and
  `git diff --check` pass. Changed/relevant files: `AnimaDocument` Character
  reference/manifest/new library store + tests; Assets models/sidebar/content/
  workspace/New Character copy; `StudioWorkspaceView`; Project Format, STATUS,
  and coordination logs. Claim released.
- **2026-07-20 (Codex, shared Visualization material/environment browser):**
  Added the production lower-left 3D-workspace Visualization trigger and one
  shared Material/Environment widget. Material presets search and apply through
  existing `PreviewPartAppearance` editor state, include used-material reuse,
  and cover Plastic/Metal/Glass without changing engine rig semantics;
  Environment reuses the existing viewport bindings. UI Dev now contains the
  same production trigger/browser as template 36. Touched-file format lint,
  294 XCTest tests plus 22 bridge/integration tests, native/root builds,
  helper embedding, deep signing, launch, and `git diff --check` pass. Relevant
  files: `ViewportVisualizationPanel.swift`, `StudioWorkspaceView.swift`,
  `UIDevVisualizationPanelSpecimen.swift`, UI Dev catalog/tests,
  `ViewportVisualizationPanelTests.swift`, STATUS, and coordination logs.
- **2026-07-20 (Codex, visual Environment preset browser):** Replaced the
  Visualization Environment tab's dense form with the requested visual Studio
  card browser. Default, Transparent, Colored Mood, Gradient Mood, and Black
  and White Stage cards drive the real project-persistent viewport background
  and the live lighting preset/intensity/rotation together; Transparent adds a
  genuine clear background mode. Detailed background, lighting, rotation, and
  section-plane editing remains available from the settings control. The UI Dev
  specimen now switches between the same production Material and Environment
  components. Touched-file format lint, 296 XCTest tests plus 22 live bridge/
  integration tests, native Xcode build, root rebuild/helper embedding/deep
  signing, launch, and diff check pass. Relevant files:
  `ViewportPresentation.swift`, `ViewportEnvironmentSettingsView.swift`,
  `ViewportVisualizationPanel.swift`, `UIDevVisualizationPanelSpecimen.swift`,
  `ViewportVisualizationPanelTests.swift`, STATUS, and coordination logs.
- **2026-07-20 (Codex, Character workspace label):** Renamed the first
  operator-facing workspace tab from Assets to Character and updated its
  purpose/viewport label. The stable internal `.assets` identifier remains
  unchanged so persisted preferences, shortcuts, and routing stay compatible.
  Focused workspace tests and touched-file lint pass.
- **2026-07-20 (Codex, responsive document header):** Replaced the header's
  fixed project-name width and oversized spacer with three deterministic
  responsive densities and balanced side zones around the protected centered
  workspace navigator. The project title flexes within readable bounds, the
  save badge cannot wrap vertically, medium layouts fold dedicated save/history
  buttons into the document menu, and minimal layouts combine Settings, Home,
  and all project commands into one overflow menu without losing actions.
  Added width-boundary tests; touched lint, 297 XCTest tests plus 22 bridge/
  integration tests, and `git diff --check` pass.
  Native/root build, helper embedding, deep signing, clean relaunch, and live
  process verification also pass (PID 85747). Changed files:
  `WorkspaceChrome.swift`, `WorkspaceChromeTests.swift`, STATUS, and handoff
  logs.
- **2026-07-20 (Codex, compact project identity):** Replaced the passive cube
  beside the project name with the always-visible Home action and removed the
  duplicate standalone Home button. The editable project name now measures its
  rendered text and sizes naturally, so short names no longer reserve a large
  blank block; long names remain capped per responsive density. Removed the
  identity container's old minimum width while keeping the save-state capsule
  fixed on one line. Eight focused header tests, touched-file strict lint,
  native/root build, helper embedding, deep signing, clean relaunch (PID
  99224), and diff check pass.
- **2026-07-20 (Codex, production three-sidebar workspace shell):** Replaced
  the per-workspace placement branches with one production
  `StudioWorkspaceScaffold` used by Character, Rig, Animate, Show, Hardware,
  Nodes, and UI Dev. The shell owns the full-bleed center plus model Tool,
  content Workspace, and presentation View sidebars; one global layout state
  drives Floating, Docked, and Canvas. Both side rails share switch/open and
  active/collapse behavior, Canvas reveal bridges its hot zone and sidebar
  hover, Docked forces Expanded tools, and global tool/camera state enforces
  mutual exclusion with prompt/repeat/commit/cancel lifecycle. Character now
  supplies its existing center/browser/inspector through the scaffold rather
  than owning a second layout. Persistent state moved to observable workspace
  or app-global owners. Recursive lint, 304 XCTest tests, 22 live bridge/
  integration tests, native Xcode/root app builds, helper embedding, deep
  signing, live app plus bridge launch, and diff check pass. Claim released.
- **2026-07-20 (Codex, protected Character collection surface):** Kept the
  Character table/grid as the center document while making its presentation
  mode-aware. Floating renders a rounded 300–520-point content-sized window
  inside published top/left/right overlay insets; Docked remains full-height
  and in-flow. Canvas starts broad while its sidebars are hidden, then animates
  the structured collection inward when an edge sidebar reveals, so rows never
  sit behind controls. Spatial 3D/node centers remain full-bleed because they do
  not consume the structured-content inset environment. The Character browser
  and import/preview panel are also content-sized while floating. Added layout
  sizing and shell-inset tests. Recursive lint, 308 XCTest tests, 22 live
  bridge/integration tests, native Xcode/root builds, helper embedding, strict
  deep signing, clean launch (PID 51868), and diff check pass. Claim released.
- **2026-07-20 (Codex, protected Animate/Show timeline surfaces):** Wrapped
  both bottom editors in one shared mode-aware timeline surface. Docked remains
  flat and full-width; Floating and Canvas use rounded editor windows with a
  broad base margin. The surface consumes only the shell's left/right overlay
  clearances, so Canvas edge-revealed widgets smoothly push tracks and transport
  controls out of their way while the 3D viewport above remains full-bleed.
  Top-tool clearance does not incorrectly shrink the bottom editor. Added three
  deterministic sizing tests. Recursive lint, 311 XCTest tests, 22 live bridge/
  integration tests, native Xcode/root builds, helper embedding, strict deep
  signing, clean launch (PID 74679), and diff check pass. Claim released.
- **2026-07-20 (Codex, shell alignment phase A):** Removed the zero-reference
  pre-scaffold ribbon presentation (`WorkspaceToolBar`, controls/presentation,
  compact/contextual helpers, `StudioCanvasSide`, and
  `WorkspaceRibbonCatalogView`) while retaining the live
  `WorkspaceRibbonCatalog` data layer used by the shared Tool sidebar. Retired
  the three enum/height tests that existed only for that dead view path. Full
  Swift verification passes: 308 XCTest tests and 22 bridge/integration tests.
- **2026-07-20 (Codex, shell alignment docked layout):** Reordered the Docked
  scaffold into full-height fixed-width left sidebar | center Tool+document |
  full-height fixed-width right sidebar. The Tool ribbon no longer spans above
  or shortens the side panels. Eight focused shell tests and strict touched-file
  lint pass.
- **2026-07-20 (Codex, shell alignment panel stacks):** Ported the Demo's shared
  multi-panel state to both production rails: unselected defaults, independent
  toggles, ordered stacking, header drag with panel-width insertion feedback,
  sideways tear-off, canvas clamping, edge re-docking, independently centered
  rails, and a persisted outer-edge arrangement preference. Inspectable
  selection opens the actual Inspector panel. Deterministic stack/reorder/
  tear-off/clamp/outer-edge tests join the existing shell contracts; strict
  touched lint, 314 XCTest tests, and 22 bridge/integration tests pass.
- **2026-07-20 (Codex, shell alignment quality cleanup):** Finished the shell
  consolidation without changing engine ownership. Rig tools now carry typed
  payloads, one `WorkspaceRibbonActionDispatcher` owns enablement, selection,
  and execution, both sides use the same rail implementation, and the View
  sidebar directly binds the persisted RealityKit display settings instead of
  holding a second copy. Renamed the internal layout case to `floating` while
  preserving the stored `"studio"` raw value for compatibility. Deterministic
  tests cover the typed payload, shared dispatcher, and single viewport source
  of truth; recursive format lint, 316 XCTest tests, 22 bridge/integration
  tests, the native Xcode build, root-app helper embedding, strict deep signing,
  live launch, and diff check pass. Claim released.
- **2026-07-20 (Codex, mirrored sidebar animation):** Corrected Floating-mode
  panel layering so both leading and trailing stacks reveal from their home
  edge beneath a permanently higher icon rail. The left rail therefore remains
  as readable and clickable as the right rail throughout opening and closing.
  Added a deterministic mirrored-edge/layer-order test; strict touched-file
  lint, 317 XCTest tests, 22 bridge/integration tests, native/root build,
  helper embedding, deep signing, and clean launch (PID 70392) pass.
- **2026-07-20 (Codex, native macOS window behavior):** Kept the seamless
  hidden-titlebar chrome while restoring the behaviors it had displaced. The
  Window scene now uses content-minimum resizability so edge/corner hit regions
  and cursors remain native above the minimum size; empty document-header areas
  use an AppKit control layer for native drag and the operator's macOS
  double-click preference (zoom/minimize/none). Added deterministic preference
  mapping coverage; strict touched lint, 318 XCTest tests, 22 bridge/integration
  tests, native/root build, helper embedding, deep signing, and clean launch
  (PID 78099) pass.
- **2026-07-20 (Codex, condensed workspace tool bars):** Applied the reference
  expanded-ribbon hierarchy to every production workspace. A scroll-safe top
  category strip chooses one captioned tool family; Animate is split into
  Transport, Keyframes, Curves, Tracks, and Reference with at most seven tools
  visible at once. Standard and Compact render one menu per family, retaining
  every command without the previous oversized row. Deterministic catalog/
  density coverage joins the suite; strict touched lint, 319 XCTest tests, 22
  bridge/integration tests, the native/root build, helper embedding, and strict
  deep signing pass. The rebuilt root app launched cleanly as PID 93863.
- **2026-07-20 (Codex, condensed Nodes tool bar):** Consolidated the Nodes
  workspace's ten source families into six readable top categories—Canvas,
  Authoring, Logic, Data, AI + Voice, and Outputs—without removing any node
  command. Expanded shows only the chosen bounded category, while Standard and
  Compact keep one menu per source family. A deterministic test proves the
  reorganized catalog preserves the complete tool-title multiset. Strict
  touched lint, 320 XCTest tests, 22 bridge/integration tests, native/root
  build, helper embedding, deep signing, and clean launch (PID 4025) pass.
- **2026-07-20 (Codex, streamlined production Character workspace):** Hid the
  experimental cross-project Character Library and planned Parts Library from
  production testing. Assets now has only Characters/Collections rails and one
  Project Characters tree root; Publish and library category affordances are
  absent. The implementation uses one disabled availability gate, preserves
  existing library files/storage code, and normalizes stale library selection
  state back to the active project Character. Deterministic tree/rail tests,
  strict touched lint, 321 XCTest tests, 22 bridge/integration tests,
  native/root build, helper embedding, deep signing, and clean launch (PID
  57890) pass.
- **2026-07-20 (Codex, production STEP/CAD integration):** Promoted the retained
  Codex Bench work into self-contained production targets: a crash-guarded Open
  CASCADE/XDE shim, one renderer-neutral CAD document, RealityKit and MetalKit
  native views, Three.js WebGPU with WebGL 2 fallback, and a raw WebGPU
  diagnostic view. STEP/STP is now first in import guidance and uses OCCT for
  hierarchy, XDE color, exact feature edges, topology, and metre conversion.
  Settings exposes the four roles plus coordinated theme, material, edge,
  lighting, and telemetry controls. Browser resources and 27 OCCT/transitive
  dylibs are bundled into the signed root app with no absolute Homebrew links.
  Recursive Swift format lint, 321 XCTest tests, 26 Swift Testing tests, native
  Xcode build, root rebuild, strict deep signing, launch, and diff check pass.
  Synthetic geometry and malformed-STEP crash containment are covered; the
  deleted CAD DEMO corpus was intentionally left untouched, so a real operator
  STEP walkthrough is the remaining manual acceptance check.
- **2026-07-20 (Codex, asset ownership + adaptive toolbar policy):** Kept
  current rig geometry portable and honest: model import explicitly copies
  CAD/mesh files into the Character without moving or changing the source.
  Documented Character-owned versus Project-owned imports, never-move policy,
  and a future advanced security-scoped link option for large media rather
  than pretending the engine can resolve linked rig geometry today. Expanded
  toolbars now show a single horizontally scrollable row for modest catalogs
  (up to 24 tools) and introduce category tabs only when genuinely needed;
  Standard and Compact retain grouped category menus. Focused format lint, 322
  XCTest tests, 26 Swift Testing tests, native/root builds, and strict deep
  signing pass.
- **2026-07-20 (Codex, corrected Tool-sidebar density presentations):** Fixed
  the visible mismatch reported from the rebuilt Character workspace and made
  the three settings structurally distinct. Compact is a centered 48-point
  category capsule whose anchored icon-and-label palettes expose every tool.
  Standard is a centered 64-point capsule with two primary tools per group and
  chevrons for the remaining actions. Expanded is the full-width 88-point
  complete ribbon with captions and separators; it remains the launch default
  and the Docked requirement. The center safe inset follows those heights, and
  the visible import tool is consistently named Character. Focused lint and
  325 XCTest tests plus 26 Swift Testing tests, native/root rebuild, and strict
  deep signing pass; the rebuilt root app launches for operator review.
- **2026-07-20 (Codex, production widget/tree completion pass):** Audited every
  production panel and published the ownership/capability matrix in
  `dev/docs/reality/Widget_Production_Audit.md`. The reusable tree model now
  supports atomic ordered bulk removal; the Instances tree retains folders,
  grouping, rename, locks, state icons, insertion-line reorder, drag-on-row
  auto-group, keyboard/context deletion, and confirmed bulk deletion. Rig
  navigator tabs now show distinct Components, Mates, Relations, Clips,
  Scenes, Media, Cues, Nodes, Drivers, Outputs, and Safety working sets instead
  of repeating one generic list. Engine mates and relations can be deleted
  through the retained rig DTO; dependent relations, outputs, and keyframe
  channels are pruned before AnimaCore reload/validation. Fixed project/source
  hierarchies remain intentionally read-only, and the Nodes transport controls
  are now visibly disabled instead of enabled no-ops. Recursive lint, 326
  XCTest tests plus 27 Swift Testing tests, native/root build, embedded-helper
  signing, strict deep signature verification, and live launch pass.
- **2026-07-20 (Codex, faithful demo-shell production port):** Used frozen demo
  checkpoint `4757cdc` as read-only reference and completed the remaining
  production parity gaps without replacing the app's real engine/document
  content. Document and Home headers now use the demo's centered layout and
  independent 1320/1060/880 collapse rules; shell panel widths, margins, and
  floating/Docked tool geometry match the reference. Toolbar data now declares
  category icons and primary tools, Compact/Standard/Expanded render distinct
  presentations, and immediate commands execute through the shared tool-state
  `.onAppear` handler while armed commands keep prompt/commit/cancel and camera
  exclusivity. Existing production panel stacking, reorder/tear-off/re-dock,
  Canvas hover, and reusable-tree implementations were retained as the single
  richer paths. Recursive Swift format lint, 328 XCTest tests plus 27 Swift
  Testing tests, native Xcode build, root rebuild/helper embedding, strict
  signing, and live launch (PID 55266) pass. Claim released; demo untouched.
- **2026-07-21 (Codex, faithful Demo Home/footer production port):** Kept the
  frozen demo read-only and ported its three-column Home, Home-only header,
  direct default-root project creation, disk-discovered/stored recents union,
  sample fallback, archetype routing, connected resources, and global 24-point
  footer into production. The footer is present on Home and open workspaces and
  reads real selection, renderer-published triangle counts, backend, theme, and
  OCCT version. RealityKit and retained CAD views expose geometry metrics without
  moving rendering truth into the engine. Recursive format lint, 332 XCTest +
  27 Swift Testing tests, native/root build, strict deep sign, and fresh launch
  (PID 32445) pass. Claim released; broad production-parity audit resumed.
- **2026-07-21 (Codex, Pack-and-Go project persistence):** Ported the demo's
  file-lifecycle behavior into the real `AnimaDocument` layer. New and reopened
  projects create/backfill `assets/{models,assemblies,audio,video,images,scripts,renders}`;
  model import explicitly offers Copy into Project (default) or Reference in
  Place and never moves the source. Copied and linked geometry resolve through
  stable document asset IDs, imports autosave, and reopen/Save As reconfigure
  renderer sources from the reloaded manifest. Added versioned `.animasm`
  documents with legacy migration plus Save/Import Assembly in the Rig asset
  library. Recursive format lint, 338 XCTest tests plus 27 Swift Testing tests,
  native Xcode build, root rebuild/helper embedding, deep signing, and launch
  pass. Claim released; demo sources stayed read-only.
- **2026-07-21 (Codex, additive Demo tools + Design + UI Kit):** Preserved the
  production catalogs and command behaviors, then appended the Demo's missing
  Character, Rig, Animate, Show, and Hardware concepts through one namespaced
  catalog. The special category-driven Rig ribbon now includes the additive
  concepts in its live categories without duplicate production tools. Added a
  clearly labelled Design sandbox with the six Fusion-style categories,
  typed tool payloads, a flat placement canvas, Documents/Features/Bodies/Mates
  browser tabs, and editable placeholder properties. UI Dev gained a separate
  namespaced Demo UI Kit gallery containing every handoff family, including
  panels, rows, chips, overlays, mate/material/environment controls, timeline,
  nodes, servo/feature tracks, document tabs, gizmos, and ViewCube. The frozen
  Demo remained read-only. Touched Swift format lint, 344 XCTest tests plus 27
  Swift Testing tests, native Xcode build, root rebuild/helper embedding,
  signing verification, and a live root-app process all pass.
- **2026-07-21 (Codex, Center View + visible-zone production port):** Ported
  the demo's bottom-center representation switcher into the production shell
  with exact Character, Rig, Animate, Show, and Hardware catalogs. Spatial 3D
  centers remain full-bleed; real gallery, table, dope-sheet, curve, node,
  exploded, and servo-timeline centers consume one shell-owned visible-zone
  environment inset that responds to tool chrome, open panel stacks, Canvas
  reveals, the bottom switcher, and torn-off window footprints. Docked panels
  remain in-flow. Settings now exposes the live dashed layout-zone overlay.
  Full `swift test` passes 348 XCTest plus 27 Swift Testing tests, touched
  format lint and the native/root builds pass, the root bundle satisfies
  strict deep signing, and the rebuilt app remains live as PID 17397. The demo
  stayed read-only.
- **2026-07-21 (Codex, viewport control consolidation):** Replaced the two
  parallel production viewport-control paths with one right-sidebar surface.
  View owns camera/display/navigation/mouse settings/help; Environment owns
  the reusable Material/Environment visualization panel; Appearance owns only
  viewport-level theme/color behavior. The viewport HUD now contains only the
  spatial ViewCube and Home action. Removed the floating Visualization pill,
  obsolete `ViewportRenderMenu`, its legacy sidebar duplicate, and their stale
  test path. Added a deterministic placement contract so future controls have
  one owner. Claude's concurrent shell changes were retained. Touched lint,
  346 XCTest + 27 Swift Testing tests, native/root builds, strict deep signing,
  and live launch PID 20348 pass.
- **2026-07-29 (Claude, integration checkpoint):** Committed the shared
  working tree — 60 files spanning both lanes' released claims (all Live
  claims marked released 2026-07-28 or earlier; no active locks): Codex's
  CAD render pipeline (shared `CADPipelineViewport`, Metal/WebGPU adapters,
  transform gizmo, reference geometry, appearance panel, assembly tree,
  nested sub-assemblies), Claude's VR character type + `tracking.py`, and the
  2D emotes pack. `reference_ui/` (46MB AI-gen design scratch, unwired) was
  gitignored, not committed. Build clean; 355 XCTest + 36 Swift Testing green.
  No behavior change in this commit — pure de-risking backup of released work.
  **Open coordination item (unchanged by this commit):** the Codex/Claude
  file-division for the next CAD-viewport round (move/origin vs
  appearance-unification/video) still needs locking in Live claims before
  either agent re-enters `app/Sources/AnimaCADViewport/**`.
