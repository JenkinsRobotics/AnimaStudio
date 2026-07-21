# Handoff: project folders, asset import, tree lists, and assemblies

The demo (`dev/AnimaStudio Demo/`) settled these designs; port them into the main
app (`app/Sources/AnimaStudioUI/` + `AnimaDocument`/`AnimaModel`), backed by the
real engine and document format. Read the demo files named below to diff against
a working reference. Keep `swift test` (from `app/`) green.

## 1. Self-contained project folders (Pack-and-Go)

A project is a folder. Imported assets are COPIED into it by default so the
project is portable — never just referenced. Structure:

```
<Project>/
  project.json                (format_version 2 — unchanged)
  characters/  scenes/
  assets/
    models/  assemblies/  audio/  video/  images/  scripts/  renders/
```

- Create the typed `assets/` subfolders in the project skeleton, and **backfill**
  them when opening an older project.
- Demo reference: `StudioProject.swift` (`assetSubfolders`, `assetFolder`,
  `modelsURL`, `assembliesURL`, `ensureAssetFolders`, `createSkeleton`).

## 2. Import handling — Copy (default) or Reference, asked at import time

On import, prompt the operator: **Copy into Project** (default / Enter) vs
**Reference in Place**. Copy writes the file into the correct typed subfolder
(STEP → `assets/models/`) and the stored asset path points INSIDE the project;
Reference stores the original absolute path. Never Move. If no project is open,
force Reference and say so.

- The main app already has import UI (`ModelImportUnitsSheet`, `NativeImportPanel`)
  — add the copy/reference choice there and make it real (the demo's was inert
  until this pass).
- Demo reference: `RealViewport.swift` (`importFiles` NSAlert prompt,
  `resolvedSource` copy-into-assets, `AssetImportMode`).

## 3. Imports must persist + reload (this was a real bug in the demo)

Two fixes the app should verify it does NOT share:
- **Autosave after import** so the scene/document records the new assets.
- **Reopening a project reloads its assets** — the folder-open path must
  re-read the document and re-import, not just adopt the folder.
- Demo reference: `ProjectStore.swift` (`loadCurrentScene`, `autosave` after
  `load(persist:)`), called from both open-recent and open-folder flows.

## 4. One universal tree component (folders, drag/drop, group, delete, rename)

Every browser/list panel (Parts, Bodies, Mates, Documents, Assemblies, character
sections) uses ONE tree component with the same functions. Do NOT hand-roll a
tree per panel.
- Model: a `TreeNode` (id, name, icon, detail, isFolder, children, visible,
  payload) — **Codable** so subtrees serialise — and a `TreeModel` with:
  addFolder, groupSelection, delete, rename, toggleVisible/Expanded, and
  drag-move (reorder before a target / move into a folder, rejecting drops into
  own descendant).
- View: renders `TreeNode`s through one row (chevron · visibility eye · icon ·
  name · trailing count/detail), with `.draggable`/`.dropDestination` reorder +
  move-into-folder, a drop-line indicator, context menu (Rename / New Folder /
  Group / Delete), and a New Folder / Group / Delete action bar.
- Demo reference: `TreeModel.swift`, `TreeView.swift`, `TreeRow.swift`. Seed a
  `TreeModel` from real data and keep it in sync (see `DemoModel.syncPartsTree`).

## 5. Rig = assembly builder + an Asset Library panel

- Rig's left sidebar: **Assets** (the importable library) · **Structure** (the
  current assembly, a `TreeModel`) · **Mates**.
- The **Assets panel** shows the character's parts + saved sub-assemblies, each
  with an "import into assembly" (+) action, in a **List / Tiles** view toggle
  (tiles are rendered thumbnails when available). It should mirror the folders/
  groups the operator made in the character's part tree.
- An assembly can contain parts OR other assemblies (sub-assemblies → full
  assembly). Importing nests them in the Structure tree.
- Demo reference: `Workspaces/RigAnimate.swift` (`AssetLibraryPanel`,
  `AssetViewMode`, `structureTab`), `RigModel` (`assembly`, `importAsset`).

## 6. Assemblies are FILES

Building an assembly and "Save Assembly" writes a reusable document
`assets/assemblies/<name>.animasm` (JSON: name + node references). Saved
assemblies appear in the Asset Library and can be imported into other assemblies.
In the main app this should be a first-class `AnimaDocument` sub-type with
migrations, not raw JSON.
- Demo reference: `AssemblyFile` (in `TreeModel.swift`), `RigModel.saveAssembly`
  / `savedAssemblies` / `importAssembly`.

## 7. View sidebar must drive the viewport (make Environment real)

The Environment panel toggles (Grid, Origin, View cube, Ground shadow, Key light)
must actually change the RealityKit view — bind them to the real render state the
viewport reads, not a dead copy. (The main app has the two-sources-of-truth issue
flagged earlier: `@AppStorage` in `StudioWorkspaceView` vs `StudioViewSidebarState`
— unify onto one.)
- Demo reference: `RenderState` (`showGrid/showOrigin/groundShadow/keyLightScale`),
  `RealViewport` (reads them in `body` so the RealityView update re-runs),
  `Sidebars.swift` `environmentSettings` (bound to `RenderState`).

## Acceptance
- Import into a saved project, quit, reopen → the parts are still there, loaded
  from `assets/models/`.
- New project on disk has the typed asset subfolders.
- Every tree panel: create a folder, drag a row into it, group a selection,
  delete, rename — all work identically.
- Save an assembly → it appears in the Asset Library and imports into another
  assembly.
- Toggling Environment options visibly changes the 3D viewport.
- Copy/Reference is asked at import; Copy is the default and actually copies.
- All existing `swift test` contracts still pass; add tests for the tree ops and
  import copy/reference.
