# Handoff: clean up + finish the workspace shell (align to the demo)

The demo app (`dev/AnimaStudio Demo/`) fine-tuned the three-sidebar shell to a
finished state. The main app's `StudioWorkspaceScaffold` already mirrors most of
it. This task closes the gap: delete a dead legacy path, port the interactions
the app still lacks, and fix a few quality issues. Work in
`app/Sources/AnimaStudioUI/`. Verify with `swift test` from `app/` — the AppShell
test contracts below MUST stay green.

Reference implementation to diff against (all finished + self-tested in the demo):
- `dev/AnimaStudio Demo/Sources/AnimaStudioDemo/Sidebars.swift` — `PanelStackState`
  (the shared engine: multi-toggle, drag reorder, tear-off), `StackRail`,
  `StackCard`, `PanelSidebar`.
- `dev/AnimaStudio Demo/Sources/AnimaStudioDemo/WorkspaceShell.swift` —
  `WorkspaceScaffold` (float/dock/canvas body, edge reveal, floating-panel
  clamp + drag), docked center-column layout.
- `dev/docs/roadmap/Sidebar_Standard.md` — the written spec.

---

## Part A — delete the dead legacy ribbon path (do this first)

These have zero references repo-wide (confirmed by grep). Remove them and any
now-unused helpers they pulled in:

- `WorkspaceToolBar` (`AppShell/WorkspaceChrome.swift:463`)
- `WorkspaceRibbonControls` (`AppShell/WorkspaceChrome.swift:286`)
- `compactRibbon` (`AppShell/WorkspaceChrome.swift:508`)
- `WorkspaceContextualTools` (`AppShell/WorkspaceChrome.swift:818`, ~150 lines)
- `WorkspaceRibbonCatalogView` (`Workspaces/WorkspaceRibbonView.swift:3`) — only
  reachable through the dead `WorkspaceToolBar`
- `StudioCanvasSide` (`AppShell/WorkspaceChrome.swift:1006`) — defined, never used

Retire the tests that only pin dead behavior: the `WorkspaceRibbonPresentation.resolve`/
`.height` cases in `WorkspaceChromeTests.swift:6-49`. Keep the rest of that file
(selector metrics, preset titles, document-bar density, project-name clamp,
`applyLayoutPreset`).

KEEP the live data layer: `WorkspaceRibbonCatalog` + `WorkspaceRibbonToolDescriptor`
(`Workspaces/WorkspaceRibbonCatalog.swift`) feed the live `StudioToolSidebar` via
`StudioWorkspaceToolCatalog.groups(for:)` — that path stays.

## Part B — port the interactions the app is missing

The app's sidebars today are a **rail + a single active panel** (collapse rule
only). The demo made them a full panel-stack engine. Bring these to
`StudioSidebarRail`/`StudioViewRail` + `StudioWorkspaceSidebar`/`StudioViewSidebar`
(`AppShell/WorkspaceShell.swift`). Mirror `PanelStackState` from the demo:

1. **Multi-panel stacking.** A rail tab toggles its own panel; several can be
   open at once and stack vertically (the left/browser stays "one at a time" by
   default — `exclusive` in the demo — the right/view stacks freely). Replace the
   single-selection state (`StudioViewSidebarState.selectedTab`,
   `workspaceSidebarSelections`) with an enabled-set + ordered stack per side.

2. **Drag to reorder + tear off.** The panel header is the drag handle (remove
   any detach/dock buttons):
   - Mostly-vertical drag → reorder within the stack, showing a **drop line whose
     width is the panel width** (not the window). See the demo's `reorderGesture`
     + `dropIndicator` + `CardMidKey` preference.
   - Sideways pull past ~half the panel width → the panel **tears off into a
     floating window** that follows the cursor (no drop line) and lands where
     released. Floating panels are clamped to the visible canvas (can't cover the
     rails/toolbar/status — see the demo's `floatClamp`/`floatBase`) and re-dock
     when dragged back near their home edge.

3. **Default unselected.** Panels start closed (empty enabled set) on launch, not
   with a default panel open.

4. **Rail centered, independent of the stack.** In floating mode the rail is
   vertically centered to the window and does NOT move as panels stack; the stack
   is centered independently and grows about the center. Panels fit their content
   height (no greedy fill). See the demo's `floatingLayout` (two independent
   `frame(maxHeight:.infinity, alignment:.center)` children).

5. **"Push panels to the outer edge" setting.** A `StudioLayoutState` bool
   (`panelsOnOuterEdge`) that swaps the arrangement so panels sit on the outer
   side and the rail moves inboard — while KEEPING the floating margin (do not
   latch flush to the window edge). Surface it in the app's settings UI.

6. **Docked center-column layout.** In docked mode the two side sidebars must
   span the FULL window height, and the tool bar belongs at the **top of the
   center column** (viewport/bottom-editor below it) — not a full-width strip
   across the top. The demo's `dockedBody` is a single `HStack {
   leftSidebar | VStack { toolBar; center } | rightSidebar }`. Check the app's
   current `dockedBody` (`WorkspaceShell.swift:704`) and restructure to match.

7. **Docked panel width is fixed.** A docked side panel must be a fixed-width
   column, not greedily filling the canvas (the demo pins it; a `ScrollView`
   expands horizontally by default — constrain it).

Keep the demo's density behavior you already have (docked forces `.expanded`),
the Fusion-style category ribbon at expanded density, and the arm→prompt→commit
tool lifecycle with camera-nav exclusivity.

## Part C — quality fixes (grounded in the review)

- **De-duplicate the `WorkspaceRibbonAction` dispatch.** It's copied 3× —
  `StudioWorkspaceView.performWorkspaceRibbonAction` (`StudioWorkspaceView.swift:386`),
  `WorkspaceRibbonCatalogView.perform` (dead, removed in Part A), and
  `WorkspaceFloatingGroupPopover.perform` (`WorkspaceChrome.swift:778`). Collapse
  to one dispatcher; likewise the duplicated `isEnabled/isSelected/displayTitle/
  displayImage` helpers.
- **Replace stringly-typed rig tool commands.** `"rig.part.\(kind)"` /
  `"rig.relation.\(kind)"` are built at `WorkspaceShell.swift:290/309` and
  re-parsed with `hasPrefix`/`dropFirst` in `commitArmedTool`
  (`StudioWorkspaceView.swift:403-432`). Carry a typed payload on
  `StudioToolBehavior.arm` instead.
- **Collapse the two sources of truth for viewport display.** ~40 `@AppStorage`
  render prefs in `StudioWorkspaceView` (`:39-85`) overlap `StudioViewSidebarState.shared`
  and are merged in `shellRenderStyle`/`shellEdgeDisplay`/etc. (`:944-966`). Pick
  one owner (prefer `StudioViewSidebarState`) so the view sidebar's toggles
  actually drive the viewport.
- **Unify the two near-identical rails.** `StudioSidebarRail` (`:376`) and
  `StudioViewRail` (`:416`) are structurally identical — extract one rail
  parameterized by side, as the demo's single `StackRail` does. Fold the parallel
  `alignment(for:)/transitionEdge(for:)/edgePadding(for:)` switches (`:863-885`).
- **Rename for clarity (optional but recommended):** `StudioLayoutPreset.studio`
  renders as "Floating" everywhere — the case name never matches the operator
  term. Consider renaming the case to `.floating`. (Update `WorkspaceChromeTests.swift:66`.)
- **`isUIDevWorkspace`** (`StudioWorkspaceView.swift:29`) is threaded through many
  subviews as a `@Binding` and behaves like a 7th workspace — model it as a case
  on `StudioWorkspaceModel` rather than view-local `@State`.

## Constraints / contracts to preserve (from `WorkspaceShellTests` / `WorkspacePresentationTests`)

Do not break these — extend them if behavior grows:
- Layout mode is **app-global** and cycles studio→docked→canvas across separate
  model instances (`WorkspaceShellTests.swift:28`).
- Rails obey switch-open / active-collapse via `StudioSidebarInteraction.select`
  (`:45`). (Now: also support multi-open + reorder + tear-off — add tests.)
- Left sidebar selection + open state **survive** workspace and layout changes
  (`:59`). The new enabled-set state must persist the same way.
- Docked forces `.expanded` density without losing the floating preference (`:73`).
- Arm/camera-nav mutual exclusivity + repeat-mode (`:87`, `:107`).
- Per-workspace navigator/inspector state restores across switches; leaving
  Animate stops playback; bottom editor only in Animate/Show; an inspectable
  selection force-reveals the inspector (`WorkspacePresentationTests`).

Add deterministic tests for every new behavior (stacking, reorder index math,
tear-off/dock transitions, `panelsOnOuterEdge`) — the demo unit-tests all of
these headlessly; port those assertions.

## Suggested order
A (delete dead code, green tests) → B6/B7 (docked layout, low risk, high visual
payoff) → B1 (stacking state) → B2 (drag reorder/tear-off) → B3/B4/B5 (defaults,
centering, outer-edge) → C (quality). Commit per phase; keep `swift test` green
throughout.
