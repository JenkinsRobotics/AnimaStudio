# Handoff: import per-workspace tools, the Design workspace, and the UI Kit

ADDITIVE port. Bring the demo's per-workspace tool catalogs, the Design
workspace, and the UI Kit widgets into the main app **alongside** what it already
has. Do NOT replace the app's existing tools/components — add, and we consolidate
later. Where a name would collide, namespace/prefix the incoming one (the app's
convention or a `Demo`/`Kit` suffix) rather than overwrite. Keep `swift test`
green.

Depends on the shell port (tool sidebar + `ToolGroup`/`ToolCategory`/`RibbonTool`
+ `WorkspaceScaffold`) landing first. Demo source: the files named per section.

---

## 1. Per-workspace tool catalogs (add to each workspace's existing tools)

Port each workspace's tool catalog as-is and feed it to the ported tool sidebar.
Keep any tools the app already defines; append these so nothing is lost.

- **Character** (`Workspaces/HomeAssets.swift` → `CharacterTools`): groups
  **Import** (Character · 3D Model · Audio · Video · Image), **Manage** (Replace ·
  Reveal · Folder · Duplicate), **Prepare** (Units · Up Axis · Origin · Hierarchy ·
  Validate). Note the `primary` flags (Audio/Video/Image, Folder/Duplicate, Up
  Axis/Origin/Hierarchy are non-primary) and category icons. These are immediate
  actions via the tool `actionHandler`, not canvas-arm tools.
- **Rig** (`Workspaces/RigAnimate.swift` → `RigTools`): Structure · Mates ·
  Relations · Inspect.
- **Animate** (`Workspaces/RigAnimate.swift` → `AnimateTools`): Keys · Playback ·
  Edit.
- **Show** (`Workspaces/ShowHardware.swift` → `ShowTools`): Nodes · Output · Edit.
- **Hardware** (`Workspaces/ShowHardware.swift` → `HardwareTools`): Wire · Tune.
- **Design** (`Workspaces/DesignWorkspace.swift` → `DesignTools`): the Fusion
  category set — Design · Sketch · Surface · Mesh · Sheet Metal · Assemble — each
  with groups (Create/Modify/Utility …). This is what exercises the Expanded
  density's category tabs.

The catalogs are plain data (`[ToolGroup]` / `[ToolCategory]` / overflow +
armGroup); porting is mechanical. Wire each workspace's real actions to the tools
where the app has them; leave unimplemented ones as no-op/status placeholders
(clearly marked) so the ribbon is complete.

## 2. The Design workspace (placeholder, but wanted)

Port the Design workspace even though it's a sandbox — we want the surface for
future in-app shape creation / CAD-tool tuning. Demo: `Workspaces/DesignWorkspace.swift`
(`DesignWorkspace`, `DesignModel`, `WorkspaceBrowserContent`, `DesignGrid`,
`PartPropertiesPanel`, `DesignTools`).

- Add `.design` to the workspace pipeline (the demo currently hides it, but the
  app should carry it — behind a flag/feature toggle if you prefer).
- It's a `WorkspaceScaffold` with a flat grid canvas; arming a tool and clicking
  drops a placeholder card (no real geometry). Left browser = Documents ·
  Features · Bodies · Mates (placeholder rows via `WorkspaceBrowserContent`);
  right Inspector = `PartPropertiesPanel` (General / Transform / Information,
  editable). Keep it clearly labelled a sandbox.

## 3. UI Kit — add all the demo widgets alongside the app's components

Port the demo's component gallery + widgets **in addition to** the app's existing
components. Demo: `Workspaces/UIKit.swift` (the gallery) and the widget files
`Widgets.swift`, `NodeWidgets.swift`, `PanelWidgets.swift`, `Timeline.swift`,
`Graph.swift`, `PerformanceHUD.swift`, `EnvironmentPanel.swift`,
`Visualization.swift`, `MateInspector.swift`, `ViewCube.swift`, `MoveGizmo.swift`.

Widgets to bring over (add, don't replace equivalents):
- Layout/rows: `PanelCard`, `ListRow`, `PanelAction`, `Row`, `Field`, `Panel`,
  `TreeRow` (the universal tree row).
- Chips/buttons: `Pill`, `StageChip`, `ChipPicker`, `SegmentedIcons`,
  `ToggleRow`, `CommandButton`, `ToolCluster`, `Callout`.
- Cards/overlays: `MetricCard`, `NotificationCard`, `DialogCard`, `Toast`,
  `ProgressCard`.
- Domain widgets: `MateInspector`, `CurveCard`, `EnvironmentPanel`,
  `VisualizationPanel` + `MaterialSphere` + `VisualizationIcon`,
  `PerformanceHUD`, `SystemStatusView`, `DopeSheetTimeline`, `GraphNode`,
  `ServoTrack`, `LogicNode`, `NodeLibraryRow`, `FeatureTimeline`,
  `DocumentTabBar`, `InspectorTabs`, `SearchField`, `StepperField`, `AxisGizmo`,
  `ViewCube`, `MoveGizmo`.
- The **UI Kit workspace** itself: a scrollable, grouped gallery of every widget
  (sectioned, timeline rendered full-width). Add it as a workspace/tab so the
  app has a living design-system surface next to whatever component catalog it
  already has.

Consolidation (deduping against the app's existing versions) is a LATER pass —
for now both sets coexist.

---

## Acceptance
- Each workspace's tool sidebar shows its ported catalog (Character Import/
  Manage/Prepare, Rig, Animate, Show, Hardware, Design categories) across all
  three densities.
- The Design sandbox workspace exists and is usable (arm a tool → drop a
  placeholder card; inspector edits it).
- A UI Kit gallery workspace lists all the ported widgets; existing app
  components are untouched.
- No existing tool/component was removed or overwritten; collisions are
  namespaced. `swift test` stays green.
