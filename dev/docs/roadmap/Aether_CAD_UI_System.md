# Aether CAD shared UI-system buildout

**Status: planned contract.** This document expands the existing React +
TypeScript + `@aether/ui` decision into the component and screen plan needed
for a complete CAD product. It does not claim that the listed components or
screens are shipped.

## Outcome

Aether CAD's docked and expanded modes become a dense, traditional mechanical
CAD workspace without forking the Aether family design system. Every repeated
interaction is implemented once in `aether-ui/`; Aether CAD supplies typed
content, commands, and engine-backed state.

Floating and canvas modes remain first-class presentations of the same screen
model. Changing layout changes placement, not tools, data, or behavior.

The v1 traditional baseline shipped on 2026-08-14. It projects one
product-owned catalog into Home, Sketch, 3D Tools, Assembly, View, Manage, and
Output ribbons, adds Aether suite-stage and document context, and retains the
floating palette as an operator-selectable presentation. Browser, Properties,
and History/Problems panels now choose Dock, Float, or Hide independently and
can be reset from the global layout menu. Catalog entries without a connected
Core command stay visible but disabled with the exact missing producer; no
runtime control impersonates an implemented CAD operation.

## Reuse-first interaction practice

The following are strong defaults, not absolute prohibitions. A specialized
component is appropriate when its interaction semantics, performance profile,
or accessibility needs genuinely differ. The exception should be documented,
reuse the shared primitives and tokens where practical, and carry its own
gallery scenario and behavior tests so it does not become accidental drift.

1. Hierarchical lists normally use the shared `Tree`. A product may project
   different nodes, icons, badges, and commands, but should not create a second
   disclosure, selection, rename, drag, keyboard, or filtering implementation
   without a concrete reason the shared contract cannot express the behavior.
2. Popup command surfaces normally use the shared `Menu` model. Context menus,
   dropdown menus, overflow menus, and submenu contents render the same command
   descriptors through different anchors.
3. Short-lived anchored editors normally use the shared `Popover`; modal
   decisions normally use `Dialog`. Specialized spatial or long-running tools
   may use a purpose-built surface composed from shared primitives.
4. Labeled value editors normally use the shared field family. Text,
   numeric, unit, select, checkbox, color, slider, expression, error, and
   read-only states use the same spacing, focus, validation, and commit rules.
5. Property sidebars normally use the shared `PropertyGrid` and collapsible
   `PropertySection`. Selection changes the schema and values, not the inspector
   implementation.
6. Flat selectable collections normally use `ListBox`; tabular data normally uses
   `DataTable`. A fake one-level tree is not used merely to reuse styling.
7. Shared widgets are product-free: data in, events out. They never name a CAD
   feature, call Aether Core, allocate domain IDs, or own undo history.
8. App CSS composes layouts only. Widget colors, typography, density, focus,
   disabled states, menus, and row behavior live in `aether-ui` and consume
   design tokens.

## Responsibility split

| Layer | Owns | Must not own |
| --- | --- | --- |
| Aether Core | Documents, feature/constraint/assembly state, validation, commands, selection IDs, units, rebuild and operation results | React, DOM, menu placement, panel layout |
| Aether UI | Reusable widgets, interaction state machines, accessibility, keyboard behavior, focus, density, themes | CAD vocabulary, engine calls, file I/O |
| Aether CAD | Workbench composition, command registration, Core projections, file/window workflows, product-specific text | Duplicate widgets, geometry truth, alternate solver state |
| Viewport adapter | Persistent render session, GPU picking, world-space gizmos and previews | Menus, property forms, document authority |

## Shared command model

Menus, ribbons, toolbar buttons, tree row actions, the command palette, and
keyboard shortcuts consume one command registry. A command descriptor includes:

- stable command ID;
- label, optional description, icon, and shortcut;
- group and optional submenu ID;
- visible, enabled, checked, and destructive presentation state;
- an optional disable reason surfaced as help text;
- execution callback supplied by the application;
- optional selection/context predicate supplied by the application.

The same `cad.part.export` command may therefore appear in the File menu, a
tree context menu, the command palette, and an Export screen without duplicating
its availability logic. Destructive confirmation is a command policy, not a
custom dialog embedded in a tree row.

## Shared widget expansion

### Navigation and collections

- `Tree`: add inline rename, drag reorder/re-parent, drop-position feedback,
  loading/error children, virtualization, and reusable context-menu binding.
- `ListBox`: flat single/multiple selection, groups, keyboard type-ahead,
  optional row actions, empty/loading/error states, and virtualization.
- `DataTable`: typed columns, resizable/reorderable columns, sorting, filtering,
  range selection, inline editing, pinned columns, row commands, and large-data
  virtualization.
- [x] `Breadcrumbs`: stable-path navigation for workspaces, assemblies, and nested
  feature/edit contexts.
- [x] `SearchField`: shared delayed filtering, clear, result count, scope, and
  keyboard focus behavior.

### Commands and overlays

- `Menu`: one renderer for menu bar, dropdown, context, and overflow menus;
  nested submenus, separators, icons, check/radio items, shortcuts, danger
  state, disable reasons, keyboard navigation, collision-aware placement, and
  focus return.
- `Popover`: anchored nonmodal content with arrow/side preferences, collision
  handling, outside-click/Escape dismissal, focus policy, and pinned mode.
- [x] `CommandPalette`: fuzzy command search, recent commands, categories,
  shortcuts, disable explanations, and argument follow-up.
- `Tooltip`: delayed accessible help, shortcut and disable-reason support.
- [x] `Toast` and `NotificationCenter`: success/warning/error/progress messages
  with optional actions and a persistent history surface.

### Fields and inspector

- `TextField`: retain shared validation and unit styling.
- `NumberField`: numeric and expression entry, explicit unit suffix, scrub,
  keyboard step, min/max, mixed multi-selection value, commit/cancel, and
  parse/validation diagnostics. Core performs semantic unit conversion.
- [x] `SelectField`, `Checkbox`, `RadioGroup`, `SegmentedControl`, `Slider`,
  `ColorField`, and `FileField`: one visual and interaction standard each.
- `FieldRow`: label, editor, optional reset/inheritance/animation affordance,
  help, error, and multi-selection state.
- `PropertyGrid`: schema-driven field rows with collapsible sections, filter,
  modified-only mode, per-property reset, multi-selection, and transaction
  boundaries supplied by the app.

### Layout and status

- `SplitPane`: accessible resizable regions with persisted size, min/max,
  collapse, double-click reset, and keyboard adjustment.
- `DockPanel`: finish collapse behavior, header command slots, loading/error
  states, and panel-local tabs.
- `BottomPanel`: Problems, History, Console, BOM, and task-progress tabs with
  resize/collapse and unread/error badges.
- [x] `DocumentTabs`: dirty, pinned, preview, close, reorder, overflow, and
  split-view behaviors.
- `ProgressOverlay`: determinate/indeterminate progress, phases, cancellation,
  backgrounding, and partial-failure summaries.
- `EmptyState` and `ErrorState`: reusable compact/full-panel variants with
  primary and secondary recovery actions.

## Docked and expanded CAD workspace

The professional layout uses the existing persistent viewport and the following
regions:

```text
Document bar: workspace tabs | active document | save/undo/redo | search | layout
Menu/ribbon:  Sketch | Solid | Surface | Assembly | Inspect | Insert | Output
Left:         Project / Model / Assets / Library trees
Center:       persistent 3D or Sketch viewport + ViewCube + contextual tool HUD
Right:        Properties / Constraints / Appearance / Mate / Display inspector
Bottom:       History / Rebuild / Problems / Console / BOM / Tasks
Status:       units | selection | solver/rebuild state | snap mode | kernel/backend
```

Expanded mode may widen inspectors, surface the full ribbon, and keep the
bottom panel visible. Docked mode may use narrower rails and collapsed panel
stacks. Both modes expose the same commands and restore their sizes per
workspace.

## Screen and workflow inventory

### Application and document screens

1. **Home:** recent workspaces, pinned projects, templates, recovery, and
   New/Open/Import entry points.
2. **New workspace:** Part, Assembly, or Drawing starting view; units; template;
   deterministic workspace name and location.
3. **Import center:** source list, detected format/units, copy/link policy,
   hierarchy preview, conflicts, progress, partial failures, and relink.
4. **Export center:** target objects, format, exact/mesh classification,
   tessellation settings, drawing sheets, dependency closure, and result log.
5. **Recovery:** autosave revisions, damaged-cache warning, missing sources,
   relink, and safe-open options.
6. **Preferences:** appearance, input/navigation, units/display precision,
   performance, import/export defaults, storage/cache, accessibility, and
   shortcuts.

### Part and Sketch workbenches

1. **Project/Model tree:** origin, planes, axes, sketches, features, bodies,
   imported references, materials, and errors.
2. **Sketch workbench:** entity and constraint ribbons; constraints list;
   dimensions; remaining DOF; conflict inspector; snap/filter controls.
3. **Feature editor:** consistent Apply/Cancel/Preview surface for Extrude,
   Revolve, Sweep, Loft, Hole, Boolean, Fillet, Chamfer, Shell, Draft, Rib,
   Pattern, Mirror, Split, and datum creation.
4. **Rebuild/history:** ordered operations, suppression, rollback marker,
   dependencies, timing, warnings, and failed downstream features.
5. **Inspect:** selection filters, Measure, mass properties, curvature,
   section view, bounding box, and geometry diagnostics.
6. **Appearance:** materials, face/body assignments, imported-color policy,
   transparency, display style, environment, and saved presets.

### Assembly workbench

1. **Assembly tree:** nested subassemblies, instances, connectors, mates,
   relations, patterns, configurations, grounding, visibility, and source state.
2. **Insert/library:** workspace Parts, linked Parts, standard components,
   variants, search, preview, and dependency status.
3. **Transform:** triad, numeric transform, align, move/copy, grounding, and
   instance pattern tools.
4. **Mate creation:** connector picks, type, alignment/flip, offsets, limits,
   live solve preview, conflict explanation, Apply/Cancel.
5. **Mate inspector:** connectors, remaining DOF, limits, relations,
   suppression, solver state, and driven-motion preview.
6. **Assembly analysis:** interference, clearance, section, exploded view,
   degrees-of-freedom report, and missing/failed component summary.
7. **BOM:** hierarchical/flattened views, quantity, part number, description,
   material, mass, source, custom properties, export, and drawing projection.

### Drawing workbench

1. Sheet and title-block setup.
2. Base, projected, section, detail, auxiliary, and broken views.
3. Dimensions, center marks, notes, symbols, tolerances, and datum annotations.
4. Parts list/BOM and balloons.
5. Scale, projection standard, layers, styles, print preview, PDF/DXF/SVG
   export, and stale-view rebuild indicators.

### Cross-cutting utility screens

- Assets and external references.
- Local component library and dependency browser.
- Materials and appearance library.
- Problems and rebuild diagnostics.
- Background tasks/import-export queue.
- Keyboard shortcuts and command search.
- Document information, custom properties, revisions, and statistics.

## Context-menu coverage

Every primary object type publishes a typed command context:

- workspace and document;
- sketch and sketch entity;
- feature and body;
- face, edge, and vertex selection;
- Part definition and Assembly instance;
- connector, mate, relation, and configuration;
- drawing sheet, view, annotation, and BOM row;
- asset, external reference, material, and background task.

Context menus show only commands valid for the current selection. Disabled
commands remain visible when the explanation helps the operator understand a
constraint; their disable reason is accessible from keyboard and pointer.

## Product-state requirements

Every screen must define all of these states before it is considered complete:

- empty/new;
- loading with progress and cancellation where applicable;
- populated;
- filtered with no matches;
- mixed multi-selection;
- read-only/linked;
- partially failed;
- validation error;
- missing dependency/relink required;
- background task in progress;
- offline/unavailable capability;
- destructive confirmation and recoverable undo result.

An enabled inert control is a defect. Unimplemented behavior is absent or
explicitly labeled unavailable with a reason.

## Build sequence

### UI-0 — isolation and inventory

- [x] Keep development references outside app test/build/package discovery.
- [x] Record every current app-local button, field, tree, menu, popup, and panel.
- [x] Map each to an existing shared widget, a required extension, or a new shared
  widget. No visual replacement starts without a behavior map.

Complete 2026-08-13. The reference source is quarantined from runtime/build
discovery, the behavior inventory is represented by the shipped widget matrix,
and intentional product specializations are documented at their owning screen.

### UI-1 — shared interaction primitives

- [x] Ship `Menu`, `Popover`, `Tooltip`, `NumberField`, `SelectField`,
  `Checkbox`, `ListBox`, and common empty/error/progress states.
- [x] Add gallery scenarios and behavior pins before CAD adopts them.

Complete 2026-08-13. The definitive behavior and current verification counts
live in `aether-ui/WIDGETS.md` and `dev/docs/reality/STATUS.md`.

### UI-2 — definitive data surfaces

- [x] Complete Tree rename, drag/re-parent, loading/error children, and
  virtualization.
- [x] Ship `DataTable`, `PropertyGrid`, `SplitPane`, and `BottomPanel`.
- [x] Prove identical Tree/Menu/Field behavior with two different datasets in the
  gallery.

Complete 2026-08-13. UI-2 now supplies definitive hierarchical, flat,
tabular, inspector, split-layout, and bottom-tool surfaces; application
migration continues in UI-3.

### UI-3 — CAD shell migration

- [x] Replace Aether CAD's app-local item tree, toolbar, form fields, history list,
  floating cards, and ad-hoc DOM command wiring with shared widgets and one
  command registry.
- [x] Move React from a chrome wrapper to the owner of application presentation
  state while preserving one persistent viewport instance.
- [x] Preserve every working Part, Sketch, STEP, connector, mate, visibility,
  ViewCube, and save/open flow during the strangler migration.

Complete 2026-08-13. The shell now uses shared fields, Tree, ListBox, Menu,
Rail, DockPanel, and ProgressOverlay; typed command/workspace/presentation
stores connect React to the persistent viewport controller. Superseded HTML
renderers, generated list rows, fallback shell, toolbar, and dead CSS are gone.

### UI-4 — complete workbench screens

- [x] Land Home/New/Import/Export/Recovery first.
- [x] Land Part/Sketch/Inspect/Rebuild screens alongside the corresponding Core
  feature slices.
- [x] Land Assembly/Mate/BOM screens alongside the persistent assembly graph,
  consuming the frozen renderer-free bridge contract in
  [`Aether_CAD_Assembly_Projection.md`](Aether_CAD_Assembly_Projection.md).
- [ ] Land Drawing screens only when the exact Core projection frozen in
  [`Aether_CAD_Drawing_Projection.md`](Aether_CAD_Drawing_Projection.md)
  exists; never trace the display mesh.

Frontend-independent work is complete as of 2026-08-14. The remaining Drawing
row already has a strict bridge client, presentation adapter, truthful
dependency state, shared-widget workbench, and renderer seam; it resumes when
its canonical producer exists through direct bridge and HTTP RPC. The
Assembly/Mate/BOM producer and product controller shipped on 2026-08-14, with
Core-owned new/open/save, solve, BOM, and exact projections. Completing a
consumer by duplicating solver/BOM/HLR/measurement meaning in the UI remains
prohibited.

### UI-5 — convergence and hardening

- [x] Remove replaced app-local UI implementations.
- [x] Run keyboard-only, screen-reader, focus-return, scaling, high-contrast, and
  reduced-motion passes.
- [x] Verify docked, expanded/floating, and canvas layouts at supported window
  breakpoints with no missing commands.
- [x] Make the traditional CAD ribbon the default, retain floating tools as an
  alternate, and expose independent Dock/Float/Hide controls for primary panels.
- [x] Validate large trees/tables and long-running import/export tasks.

Post-baseline CAD parity continues as bounded vertical slices rather than a
second shell. The View slice is complete: one registry now drives standard
views, five display styles, four lighting presets, contact shadows, and the
Visualization browser; the persistent viewport ViewCube supports face/home,
15-degree nudge, and 90-degree roll. The following selection slice is also
complete: Auto/Component/Body/Face/Edge/Vertex filters, preselection, modifier
extension, F6 cycling, and directional Window/Crossing selection reuse one
selection projection across viewport, Items, ribbon, palette, and floating
tools. Exact measurement/section producers and transform commands remain later
vertical slices; they must consume this selection contract rather than fork it.

## Definition of done for a widget

A shared widget ships only when:

1. its behavior contract is written in `aether-ui/WIDGETS.md`;
2. the gallery demonstrates every state and at least two different consumers;
3. deterministic interaction/accessibility tests pin the contract;
4. it consumes tokens rather than product CSS constants;
5. CAD and Animation can supply data without product-specific branches;
6. keyboard, focus, pointer, disabled, error, empty, and high-contrast states
   are verified;
7. no redundant app-local equivalent remains after migration; intentional
   specializations record why the shared widget was insufficient.

## Definition of done for a screen

A CAD screen ships only when its commands operate on canonical Core state,
undo/redo boundaries are explicit, errors are actionable, loading can be
observed, selection remains synchronized with the viewport and other panels,
and save/reopen preserves the resulting semantic state. Visual completion alone
does not count.

## Clean integration policy

The external reference material is a behavior and coverage aid only. Final
runtime code, widget names, command IDs, UI text, assets, styles, tests, and
packaging use Aether-owned concepts. No external application code, branding,
viewer dependency, or product-specific architecture is introduced.
