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

| Agent | Task | Claimed files | Acceptance | State |
|---|---|---|---|---|
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

## Requests

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

## Handoff log

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
