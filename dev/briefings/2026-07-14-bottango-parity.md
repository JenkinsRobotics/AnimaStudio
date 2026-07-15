# Active goal: Bottango-class hardware animation (started 2026-07-14)

Build Anima's own version of Bottango's core loop: author motion on a
timeline, see it live on real servos, and play it back offline on the
robot. Feature map and milestones: `dev/docs/roadmap/Bottango_Parity.md`.

## Work split

### Lane A — Studio — Swift, `studio/` — **Codex**

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

### Lane B — Runtime + protocol (Claude Code agent) — Python, `anima_studio/`, later `firmware/`

1. Wire protocol v0 spec (`dev/docs/roadmap/Wire_Protocol.md`) — the
   host↔microcontroller serial contract (the Bottango-firmware
   equivalent, but ours and open).
2. Python reference host: `anima_studio/wire.py` (protocol encode/decode,
   handshake, heartbeat) + a loopback simulator + pytest coverage.
3. Keyframe/curve evaluation in Python mirroring AnimaCore semantics
   (hold/linear now, Bézier when Studio lands it) so the runtime can play
   clips headless.
4. Arduino/ESP32 firmware sketch speaking the protocol (after v0 proves
   out over the simulator).

## Shared contracts (change only with a handoff note)

- `dev/docs/roadmap/Wire_Protocol.md` — both lanes implement it.
- Keyframe/curve semantics — AnimaCore (Swift) is the reference; Python
  mirrors it. Deterministic evaluation, explicit units
  (`timeSeconds`, `angleRadians`).
- `.anima` format docs in `dev/docs/roadmap/`.

## Live claims

| Agent | Task | Claimed files | Acceptance | State |
|---|---|---|---|---|
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

## Handoff log

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
