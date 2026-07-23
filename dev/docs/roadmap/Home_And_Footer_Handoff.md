# Handoff: port the demo's Home window + footer into the main app

Port the Anima Studio demo's **Home window** and **footer/status bar** into the
main app, faithfully. Source is the stable demo revision (see the shell handoff).
This upgrades the app's `StudioHomeView` (`AppShell/StudioHomeView.swift`) and its
status bar (`StudioStatusBar` in `AppShell/WorkspaceChrome.swift`) to match the
demo's design. Port the layout + behavior, not the demo's mock data — keep the
app's real project store, recents, and engine wiring. Keep `swift test` green.

Demo source of truth:
`Sources/AnimaStudioDemo/Workspaces/HomeAssets.swift` (`HomeWorkspace`,
`HomeSection`, `StartArchetype`, `recentRow`, `RecentSample`) and
`Sources/AnimaStudioDemo/App.swift` (`homeHeader`, `StatusBar`,
`SystemStatusView`).

---

## 1. Home window (single, merged — not a separate start window)

Home is a **workspace**, not a modal/start window. It keeps the 3-column
aesthetic (Shapr3D-inspired boxes). Layout: `HStack { left | divider | middle |
divider | right }`, top-aligned, full height.

**Home-specific header** (`homeHeader`): identity on the left (hexagon glyph +
"Anima Studio" + tagline), project-control icons on the right (new character,
import, open, save, theme, settings). NO workspace pipeline tabs, NO Live/Preview
— there's nothing open to run yet. (The regular header returns on any other
workspace.)

**Left column** — identity, project actions, nav, recents:
- Two buttons: **New Studio Project** (filled/accent) and **Open A Project**
  (outline). New creates a project on disk in the default location without
  prompting; Open uses the folder picker. Both then navigate into a workspace.
- A **section nav** list (selection-highlighted rows): Get Started · Recent
  Projects · Characters · Character Library (`HomeSection`).
- A **Recents** list at the bottom: each row = thumbnail tile + name + relative
  time + a **version chip** (V12/V3/…). Recents are disk-discovered (scan the
  projects root) unioned with the recents store, newest first; show
  representative **sample** rows when there are none yet. Refresh on `.onAppear`
  so returning to Home reflects new/opened projects. Clicking a recent opens it
  (reloads its parts — see the assets handoff).

**Middle column** — a `columnHeader(title, subtitle)` over the active section:
- **Get Started** → archetype cards (`StartArchetype`): Hardware Character ·
  Digital Character (mark preview) · Show Control. Each card has icon, title,
  detail, and routes to the right workspace on select.
- **Recent Projects** → a grid of the recents.
- **Characters** → the project's characters.
- **Character Library** → published, reusable characters.

**Right column** — "Open & Connected" (subtitle "One format, many embodiments")
plus a **LEARN** section (links/resources).

Behavior to preserve: create/open a project navigates into `.character` (or the
archetype's workspace); a "missing" recent (moved/deleted folder) is flagged, not
crashed.

## 2. Footer / status bar

A thin bottom bar, toggled by a setting (the app's equivalent of
`showStatusBar`). Demo `StatusBar`:
- **Left:** accent dot + "Anima Studio", then hairline separators, the current
  **workspace name**, and — when a part is selected — a `cube` label with
  `<name> · <tris> tris`.
- **Right:** the render **engine**, the **theme** name, and the **OCCT version**
  (`OCCT <GeomKernel.version>`), separated by hairlines.
- 24pt tall, 9pt muted text, panel background. Hairline separators are 1×12
  rectangles.
- Optional: a details popover (`SystemStatusView`) — port if the app wants the
  expandable diagnostics; otherwise the inline bar is enough.

In the main app, wire these to real values (actual selected entity + triangle
count from the engine, real engine/theme, the real kernel version). The status
bar reads live state; it doesn't own any.

---

## Acceptance
- Home is one merged view (no separate start window); its header has no pipeline
  tabs / Live / Preview.
- 3 columns: New/Open + section nav + recents (left), section content (middle),
  Open & Connected + Learn (right).
- Recents show thumbnail + relative time + version chip, disk-backed with a
  sample fallback, refreshed on appear; opening one loads its parts.
- Footer toggles via setting; shows workspace + selection on the left, engine /
  theme / OCCT on the right, with the real live values.
- `swift test` stays green.
