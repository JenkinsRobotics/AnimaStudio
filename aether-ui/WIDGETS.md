# Widget conformance

The rule this file enforces: **a core widget is finished ONCE, in
aether-ui, to its full spec — apps never re-implement or partially
implement one.** Every instance of a widget must look and behave
identically everywhere. If an app needs a behavior the widget lacks, the
behavior is added HERE (with a gallery scenario and a test), never
patched locally.

Definition of done for a core widget:
1. **Spec** — its behavior checklist below is complete.
2. **Gallery** — every checklist behavior is demonstrable in
   `npm run gallery`, including at least two instances side by side
   proving identical behavior from different data.
3. **Pins** — RTL tests cover each behavior (`npm test`).
4. **Consumers are dumb** — apps pass data + handlers only.

## Tree — spec v2 (flagship)

- [x] Hierarchical rows: disclosure, icon, label, badge, trailing actions
- [x] Selection: single click; ⌘/ctrl toggles; ⇧ selects a range over the
      visible (flattened, expanded) order
- [x] Disclosure click expands/collapses WITHOUT selecting
- [x] Expansion: uncontrolled by default; controlled via
      `expandedIDs` + `onToggle`
- [x] Keyboard: ↑/↓ move focus, → expands or enters children, ← collapses
      or moves to parent, Enter/Space selects, Home/End jump; roving
      tabindex
- [x] `filter` prop: hides non-matching rows, keeps ancestors of matches,
      auto-reveals matches inside collapsed branches
- [x] Trailing per-row actions (hover-revealed) that never change selection
- [x] `onActivate` (double-click) and `onContextMenu(id, x, y)` events
- [x] Disabled rows (skip focus/selection) and `dimmed` rows (styling only)
- [x] Empty state slot
- [ ] Inline rename (deferred — API will be `renamingID` + `onRename`)
- [ ] Drag re-order / re-parent (deferred — Swift NavigatorDropInteraction
      is the behavior reference)
- [ ] Virtualized rows for >1k nodes (deferred until a real assembly hits it)

## Status matrix (core widgets)

| Widget | Spec | Gallery | Pins | Notes |
|---|---|---|---|---|
| Tree | **v2** | full | full | flagship — see above |
| Button / IconButton | v1 | yes | basic | needs: focus ring spec |
| Ribbon (+Group/Tool) | v1 | yes | basic | needs: overflow scroll spec, keyboard |
| Tabs | v1 | yes | none | needs: keyboard (←/→), pins |
| Rail | v1 | yes | none | needs: pins |
| DockPanel / PanelHeading | v1 | yes | none | needs: collapse spec (rail chevron) |
| TextField | v1 | yes | none | needs: invalid state, unit suffix spec |
| Dialog | v1 | yes | yes | needs: focus trap, Escape pin |
| StatusBar / StatusDot | v1 | yes | none | trivial |
| ViewportCanvas | v1 | yes | none | mount/teardown pin wanted |
| Timeline / DopeSheet | — | — | — | not started; Swift `UIDevTimelineDesignB` + demo `Timeline.swift` are the references |

Work the matrix top to bottom; a row is done when all three columns are
full. Contributions (either agent) follow the same definition of done.
