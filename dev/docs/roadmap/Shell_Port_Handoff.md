# Handoff: port the demo's shell into the main app (faithful)

Decision: the demo (`dev/AnimaStudio Demo/`) has the finished header, workspace
shell, tool bar, and sidebars. Port them **faithfully** into the main app
(`app/Sources/AnimaStudioUI/`). This REPLACES the app's parallel `Studio*` shell
(`StudioWorkspaceScaffold`, `StudioToolSidebar`, `StudioLayoutState`,
`StudioSidebarRail`, `StudioViewSidebar`, the document bar) with ports that match
the demo's behavior exactly.

Rules for the whole job:
- **Port the chrome + interactions, not the demo's mock data.** The app keeps its
  real engine wiring, `AnimaDocument` format, inspector content, and tests.
- **Faithful means faithful:** same layout math, breakpoints, gestures, densities,
  animations, and edge cases. When in doubt, match the demo pixel-for-behavior.
- Keep the app's `Studio*` naming convention (rename the demo types on the way in)
  but do not change their behavior.
- `swift test` stays green; update/extend the AppShell tests to the new behavior.
- Do it in the four sections below, each building + testing before the next.

Read these demo files first — they are the source of truth:
`Sources/AnimaStudioDemo/App.swift`, `WorkspaceShell.swift`, `Sidebars.swift`,
`ToolRibbon.swift` (ToolState/RibbonTool/RibbonGroup), `TreeModel.swift`,
`TreeView.swift`, `TreeRow.swift`, `Theme.swift` (UI tokens + RenderState),
`Layout.swift` (LayoutState/LayoutPreset).

---

## 1. Header (top bar)

Demo: `App.swift` → `TopBar`, `homeHeader`, `WindowControlArea`, the App scene.

Faithfully reproduce:
- **Window-centered workspace tabs.** The side clusters (brand + file icons on
  the left; Live/Preview on the right) hug their edges; the pipeline tabs are an
  **overlay** on the bar so they center on the WINDOW, not the leftover space:
  `HStack { leftCluster; Spacer(); rightCluster }.overlay { pipelineTabs }`.
- **Responsive breakpoints** (GeometryReader on the bar width): file icons
  collapse to an overflow ⋯ menu at width < 1320; tabs go icon-only < 1060;
  Live/Preview compress < 880. Project name is `.fixedSize` so a short name
  doesn't reserve dead space.
- **Home button** where the project icon sits (returns to Home); brand is the
  house glyph, filled/accent on Home.
- **Home gets its own header** (`homeHeader`): identity left, project controls
  right, NO workspace tabs / Live / Preview.
- **Hidden title bar with real window behaviour.** Scene uses
  `.windowStyle(.hiddenTitleBar)` + `.windowResizability(.contentMinSize)`. A
  transparent `WindowControlArea` (NSViewRepresentable) sits BEHIND the header
  controls so empty header areas **drag the window** (`window.performDrag`) and
  **double-click zooms/minimises** per the user's macOS preference
  (`AppleActionOnDoubleClick`). Buttons still get their own clicks.
- Bottom `StatusBar` toggled by a setting.

## 2. Workspace shell (float / dock / canvas)

Demo: `WorkspaceShell.swift` → `WorkspaceScaffold`; `App.swift` → `Shell`;
`Layout.swift` → `LayoutState`/`LayoutPreset`.

Every workspace is ONE `WorkspaceScaffold`: tool bar (top) + workspace sidebar
(left) + view sidebar (right) over a caller-supplied center. Three Studio modes
cycled by one button, driven by a global layout state:
- **Floating** — center full-bleed; sidebars float over it as translucent pills;
  side sidebars vertically centered on their edge, **rail centered independently
  of the stack** (rail never moves as panels stack).
- **Docked** — a single `HStack { leftSidebar | VStack{ toolBar; center } | rightSidebar }`
  so **side sidebars span full height** and the **tool bar sits at the top of the
  center column** (viewport/timeline below it). Docked side panels are a **fixed
  width**, not greedy.
- **Canvas** — floating look but sidebars hidden behind ~16pt edge hot-zones with
  a plain capsule grab-handle; hovering reveals, leaving hides (track hover on
  both zone and revealed surface so it doesn't flicker).
- One `SidebarChrome(docked:)` modifier carries the floating-pill and flat-docked
  looks so every surface renders in all three modes from one path.
- A `panelsOnOuterEdge` setting swaps panels to the outer edge (rail inboard)
  while keeping the floating margin (do not latch flush).

## 3. Tool bar (three real densities)

Demo: `WorkspaceShell.swift` → `ToolSidebar`, `ToolGroup`, `ToolCategory`,
`ToolDensity`; `ToolRibbon.swift` → `ToolState`, `RibbonTool` (`.primary`).

The densities must be genuinely different (this was tuned late — match it):
- **Compact** — ONE category icon per group; clicking opens a popover listing
  that group's tools.
- **Standard** — a group's **primary** tools inline (icon+label); non-primary
  tools fold into a per-group overflow ▾ popover.
- **Expanded** — all tools, grouped with captions underneath, and when the
  workspace supplies categories, a thin category-tab strip (DESIGN·SKETCH·…) over
  the tool row with NO divider between them (Fusion ribbon). Docked forces
  Expanded regardless of the floating preference.
- Model: `ToolGroup(name, icon?, [RibbonTool])` with `categoryIcon`,
  `primaryTools`/`overflowTools`; `RibbonTool(icon, label, primary: Bool = true)`;
  optional `[ToolCategory]`.
- **Tool lifecycle:** arm → prompt bar ("<Tool> — click in the viewport. Esc to
  cancel") → commit → repeat/Esc. Arming a tool and a camera-nav mode are
  mutually exclusive. **Immediate-action tools** (Import, New Character, …) run at
  tap time via a `ToolState.actionHandler` the active workspace sets in
  `.onAppear` and returns true so they never arm — do NOT use `.onChange` on the
  armed tool (it won't fire when the tool is armed inside the scaffold).

## 4. Sidebars + the universal tree

Demo: `Sidebars.swift` (`PanelStackState`, `PanelSidebar`, `StackRail`,
`StackCard`, `ViewSidebar`, `ViewTabContent`, `ViewSidebarState`, `SidebarTab`);
`TreeModel.swift`, `TreeView.swift`, `TreeRow.swift`.

One engine drives BOTH side sidebars:
- **`PanelStackState`** — `order`, `enabled: Set`, `floatingOffset`, `exclusive`
  (left defaults exclusive/browser-style; right stacks freely). Multi-toggle
  stacking; **panels default unselected** (empty) on launch.
- **Rail rule:** click a tab to toggle its panel; several open at once stack in
  the panel column. Both rails identical (`StackRail`).
- **Tear-off by drag:** the panel HEADER is the drag handle (no detach/dock
  icons). Mostly-vertical drag reorders within the stack with a **stack-width
  drop line**; a sideways pull tears the panel off into a **floating window**
  that follows the cursor (no line) and lands where dropped, **clamped to the
  visible canvas** (can't cover rails/toolbar/status), re-docking when dragged
  back to its home edge. Long panels **scroll** internally.
- **View sidebar** tabs: View · Environment · Appearance · Inspector. Only the
  Inspector content is per-workspace (injected); Environment/Appearance/View must
  actually drive the viewport (see the Assets/Assembly handoff §7).

**The universal tree** — every browser/list panel uses ONE component, not a tree
per panel:
- `TreeNode` (id, name, icon, detail, isFolder, children, visible, payload) —
  **Codable**; `TreeModel` with addFolder, groupSelection, delete, rename,
  toggleVisible/Expanded, and drag-move (reorder-before / move-into-folder,
  rejecting drops into own descendant).
- `TreeView` renders through `TreeRow` (chevron · visibility eye · icon · name ·
  trailing count/detail), with `.draggable`/`.dropDestination`, a drop-line
  indicator, context menu (Rename / New Folder / Group / Delete), and a
  New-Folder/Group/Delete action bar. Seed a `TreeModel` from real data and keep
  it in sync.

---

## Sequencing & acceptance
Do 2 (shell) → 3 (tool bar) → 4 (sidebars + tree) → 1 (header) — the shell must
exist before the bars slot into it; the header is the least entangled.

Acceptance:
- Studio button cycles floating→docked→canvas, app-global, persists across
  workspaces; docked has full-height sidebars + tool bar in the center column.
- Header tabs stay window-centered; icons collapse at the breakpoints; the header
  drags/zooms the window; Home has its own header.
- Compact/Standard/Expanded are visibly different; docked forces Expanded;
  category tabs appear for large catalogs.
- Panels stack, reorder by drag with a drop line, tear off (clamped) and re-dock;
  default unselected.
- Every tree panel: new folder, drag into folder, group selection, delete,
  rename — identical everywhere.
- All existing AppShell tests pass; add tests for densities, panel stacking /
  reorder / tear-off, and tree ops.
