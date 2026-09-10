# Aether Studio UI convergence

Jonathan's direction, 2026-09-08: use the old native Anima Studio as the visual
and workflow reference, port it into Aether Animation web, then have Aether CAD
consume the same shared UI. Like a creative application suite, tools and layout
vary by product; the controls, typography, themes and interaction rules do not.

## Authority

- Native reference: `aether-animation/archive/swift-app/Sources/AnimaStudioUI/`.
  `Theme/StudioDesignProfile.swift` supplies the accepted structural palette.
- Shared implementation: `core/ui/`, imported as `@aether/ui`.
- Products: compose shared UI with product data and actions. Do not restyle shared
  ViewCube, Tree, DataTable, fields, dialogs, tabs or ribbons with private skins.
- One semantic authority: Python and Core keep their current responsibilities.
  Port presentation and bridge consumers; do not translate Swift evaluation into
  another browser-side engine.

## Implemented in this convergence pass

- Native structural palette, system typography and 54px document bar live in the
  shared JSON/CSS tokens and reach both apps.
- CAD now uses the same `WorkspaceShell` as Animation for side rails, docked,
  floating and canvas chrome; existing product tools and commands remain.
- CAD's private shared-ribbon, ViewCube and numeric-field skin overrides removed.
  The ViewCube in both products is `ViewportNavigationCube`; each renderer only
  adapts camera state and actions. Animation now implements face/Home/nudge/roll.
- Panel content can retain its DOM, input drafts and external editor bindings
  across shell placement changes. The viewport remains mounted across presets.
- Versioned device-local per-preset panel preferences are available in the shared
  shell and adopted by Animation. CAD retains its existing presentation store.
- Floating headers support keyboard movement; resize clamps floating coordinates.
  Compact windows reveal side panels from their rails instead of permanently
  compressing the viewport between two wide sidebars.
- The current launcher is `Aether Animation.app`. The old native bundle is kept
  under `aether-animation/archive/Anima Studio.app` while parity work continues.

## Native-to-web parity gates (not complete)

This is a shared-chrome port, not a claim of complete native application parity.
The current web Animation app still opens the sample character and has a limited
Assets workflow. The remaining conversion must be measured against native flows:

1. Assets/library, project selection, import and native package reopen/save.
2. Rig/connector authoring parity, exact CAD asset rendering, face/edge picking.
3. Clip/keyframe creation and editing, curve editor and persistence. Current web
   timeline supports playback/scrub, but its keyframes remain read-only.
4. Show and Hardware sessions, live output ownership and safe disconnect behavior.
   Their top-level web tabs are explicitly disabled pending bridge-backed flows.
5. 2D/VR workspace and performance-capture parity where implemented natively.
6. Native window integration, settings and accessibility comparisons at desktop
   and tablet sizes; cross-device persistence remains a suite-host milestone.

Each gate needs native reference steps, available bridge operations, implemented
web behavior, tests and browser verification. Missing protocol operations require
an engine-lane contract handoff before a frontend can claim the workflow works.

## Onshape mockup: extraction and retirement

Keep `onshape mockup/` for now. It contains fixture modeling, not production CAD
semantics. The following lessons are applied in shared UI: retain renderer/editor
state during layout changes, validate versioned preferences, remember presets,
keyboard-move panels, and keep floating coordinates reachable after resize.

Still compare and integrate or explicitly reject:

- edge-drag docking to all four edges and its drop-target feedback;
- independently dockable ribbon, feature history, ViewCube and element tabs;
- per-preset reset/restore controls and layout persistence across both products;
- feature context menus, rollback and parameter editing against real Core state;
- touch/pointer ergonomics and accessibility in real modeling workflows.

Delete the mockup only after these decisions and production replacements have
been verified and the reference interactions are no longer needed. Do not copy
its procedural modeling or JSON fixture format into production.

## Browser-installed delivery direction (2026-09-08)

Jonathan prefers Safari Add to Dock, as used for Onshape. Target one independently running Aether Studio host with package URLs for CAD and Animation, accessible through browsers and optional browser-installed app windows. Core UI remains responsible for visual consistency; browser installation alone does not unify component implementations. Keep current Swift launchers transitional until host lifecycle, local startup and cross-device serving are implemented and verified. Do not require a client app window to remain open to keep the host running.
