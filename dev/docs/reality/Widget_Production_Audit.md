# Anima Studio production widget audit

Date: 2026-07-20

This is the shipped capability matrix for operator-facing panels in the macOS
app. It is deliberately stricter than the UI Dev gallery: UI Dev specimens may
show visual states, but a production control is either connected to real state
or visibly disabled with an explanation.

## Universal collection rules

The app has two intentionally different collection classes:

1. **Editable collections** use the shared `TreeView` / `TreeModel` or the
   shared Asset Builder selection model. They provide stable identity,
   filtering, expand/collapse, multi-selection where meaningful, keyboard and
   context commands, confirmation before destructive changes, state badges,
   and drag feedback. Reorder/group are present only when ordering or folders
   are part of the owning document.
2. **Reference collections** expose canonical taxonomy or imported source
   structure. They provide filtering, disclosure, selection, and reveal, but
   remain visibly locked. They never offer fake rename, grouping, reparenting,
   or deletion that the owning format cannot preserve.

An enabled no-op is a defect. Planned commands stay visible only when disabled
and carry Help text that names the missing owner or dependency.

## Shell and shared panels

| Surface | Source of truth | Production behavior |
|---|---|---|
| Document header | project session + global layout/settings state | New/Open/Save/Save As, home, playback, layout mode, Settings, and Help are live. Undo/Redo are visibly disabled until document history exists. |
| Workspace tabs | `StudioWorkspaceModel.activeWorkspace` | Switches Character, Rig, Animate, Show, Hardware, Nodes, and UI Dev without duplicating a workspace dropdown. |
| Tool sidebar | workspace tool catalog + shared tool settings | Compact category menus, Standard primary tools/overflow, Expanded captioned groups/categories, one armed model tool, and camera/tool exclusivity. Planned catalog actions are disabled. |
| Workspace sidebar rail/stack | per-workspace `StudioPanelStackState` | Multiple open panels, collapse, reorder, tear-off/re-dock, Floating/Docked/Canvas behavior, and Canvas edge reveal are live. |
| View sidebar | app-wide view-sidebar state + persisted viewport settings | View, Environment, Appearance, and Inspector edit presentation only; camera modes cancel model tools. |
| Status bar | workspace/project/runtime state | Current app/workspace/runtime status is read-only and live. |

## Character workspace

| Panel/widget | Class | Production behavior |
|---|---|---|
| Project Characters browser | reference taxonomy | Shared tree renderer; filter, disclose, choose active character, and live counts. Project/character/collection nesting is format-owned and therefore locked against arbitrary folders or reordering. |
| Character collection center | editable/query-backed table or grid | Table is default; grid toggle, filter, row selection, Command-toggle, Shift-range selection, Delete/Forward Delete, confirmed bulk part deletion, import, single-part replacement, and empty-state column headers are live. Other collections are honest projections of their engine/project/editor sources. |
| Load 3D Assembly | action panel | Picker and drop import STEP/STP, STL, OBJ, and USD-family sources; progress and inline errors are live. Import storage policy and units are explicit. |
| Selected-object preview | spatial reference | Live 3D preview of the active character/selected part; empty view remains a real viewport. |

## Rig workspace

| Panel/widget | Class | Production behavior |
|---|---|---|
| Instances tree | editable tree | Filter tokens, disclosure, multi-select, bidirectional viewport reveal, rename, individual/group lock, hide/suppress/ground state badges, move up/down, drag insertion line, drag-on-row auto-group, move-to-group, create empty/group-selected, dissolve group, and confirmed single/bulk Delete are live. Locked selections reject mutation atomically. |
| Mate Features tree | editable semantic list | Filter, selection/reveal, rename/reorder for legacy projected joints, lock/suppress for engine mates, drag reorder where the retained model supports it, and confirmed engine-mate Delete are live. Deleting a mate also removes dependent relations, outputs, and keyframe values before AnimaCore validation. |
| Relations tree | editable semantic list | Filter, reveal, suppress/unsuppress, and confirmed Delete are live. Grouping is intentionally absent because a relation is semantic graph data, not a folder item. |
| Source Model hierarchy | reference tree | Filter, disclosure, select, and map node to a semantic Part are live. Rows are locked because hierarchy, topology, and names belong to the source asset. |
| Component inspector | editable form | Transform, rig state, appearance/material, and applicable selection actions edit their owning engine DTO or editor metadata. Reimport remains disabled until durable source identity exists. |
| Mate inspector/placement | engine-backed form + viewport overlay | Typed mate catalog, connector selection, shared controls, DOF readouts, suppress/lock, and AnimaCore pose evaluation are live. Unsupported canonical mutations remain disabled rather than simulated. |
| Relation editor | engine-backed draft form | Catalog, compatibility filtering, signed-ratio preview, and Reverse are live. Create remains disabled until canonical relation insertion is exposed. |
| Visualization / material panel | editor metadata + renderer settings | Material presets, PBR finish, color, environment/background, lighting, surface/edge modes, section plane, named views, and quality settings are live and persistent. |

## Animate, Show, Nodes, and Hardware

| Panel/widget | Production behavior |
|---|---|
| Animate timeline | Playback, scrub, timecode, frame/key navigation, editor-mode switch, track display, and zoom are live. Add Key/Marker/Auto Key remain disabled until undoable canonical clip editing is available. |
| Show timeline/browser | Displays the scene-authoring structure and honest empty state. Add Cue and scene creation remain disabled pending `load_scene` and scene document editing. |
| Node canvas/library/inspector | Canvas navigation, selection, cards, ports, and draft graph editing are local prototypes. Scene transport is visibly disabled until a scene runtime is attached; it is not an enabled no-op. |
| Hardware dashboard/browser | Offline status, safety posture, mappings summary, and log empty state are truthful. Connect/configure/freeze/export controls are disabled until transport sessions are wired. |

## Home, settings, and development surfaces

| Panel/widget | Production behavior |
|---|---|
| Home / Recent Projects | New/Open, thumbnail cards, revision/date display, remove-from-recents without deleting disk data, and stale-path pruning are live. |
| Settings | General workspace root, Navigation profiles/bindings/speeds, Appearance, renderer/pipeline, and layout/tool-sidebar preferences persist. |
| UI Dev gallery | Living visual inventory for production chrome plus explicit concept specimens. Specimen buttons demonstrate appearance and are not production commands. Production components should be represented here when added. |

## Remaining honest gaps

- Project-character deletion/reordering and user-defined Character collection
  folders are not exposed because their complete on-disk transaction and
  reference migration are not implemented.
- Imported source-tree reparent/rename/delete is intentionally unavailable;
  edit the CAD source and reimport after durable source identity lands.
- Scene, clip-keyframe, node-runtime, and live-hardware authoring controls stay
  disabled until their canonical engine/document mutations exist.
- Undo/redo is still unavailable; destructive production actions therefore use
  confirmation and reject locked bulk selections instead of partially editing.

