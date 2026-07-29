# CAD Viewport Functions — execution spec

Status: in progress. The 3D Modeling viewport must give Onshape-style
**part-level control** on **huge assemblies**, on **both** render engines
(Metal + WebGPU), with the logic **shared** and only the GPU draw per-engine.
This is the concrete function list and how each lands.

## Architecture (shared-first)

Shared, engine-agnostic — lives in `CADPipelineViewport` and the workspace:
- Geometry load + merge → one `CADGeometryDocument`.
- **Node→part mapping**: each STEP file → its assembly-node range → CAD partIDs
  (`partIDs(for:)`). A part = one imported STEP file = a set of assembly nodes.
- **Per-part state resolution**: hidden/selected/grounded parts → CAD partID sets.
- Camera + ViewCube direction.
- Pick result (partID) → workspace selection; ground toggle → engine + AnimaCore.

Engine-specific — thin, only the GPU draw and readback:
- **Metal** (`CADMetalViewport`): per-vertex `partID`, a per-part **state buffer**
  (hidden/selected/grounded bits) read by the shader; `partTransformBuffer` for
  moves; an ID-buffer pass for picking.
- **WebGPU** (`three/webgpu` app.js): one mesh **per part** (grouped by
  assemblyNode), `mesh.visible` for hide, `emissive` for select, `mesh.matrix`
  for move, raycast for picking.

Both engines receive the **same** `hidden/selected/grounded partIDs`, camera,
and transforms from the shared layer. Adding an engine = implement that thin set.

## Functions

### 1. Per-part visibility (hide / show) — DONE (Metal), WebGPU in progress
- Tree eye toggle → `hiddenSourceURLs` → `partIDs(for:)` → engine.
- Metal: state bit 0 → vertex clipped. WebGPU: `mesh.visible = false`.
- Done: `showAllComponents`, per-part `toggleComponentVisibility`.

### 2. Per-part selection tint — DONE (Metal), WebGPU in progress
- Tree click or viewport pick → `selectedSourceURLs` → engine.
- Metal: state bit 1 → fragment tint. WebGPU: `emissive = selectionColor`.

### 3. Viewport click-to-select (pick) — both engines
- Click a part in the viewport → select it in the tree (bidirectional with #2).
- Metal: render `partID` to an off-screen ID texture; read the pixel under the
  cursor → partID → workspace `selectPart`. ⌘-click extends; empty click clears.
- WebGPU: `THREE.Raycaster` against the per-part meshes → `mesh.userData.partID`
  → post `pick` message to Swift → workspace `selectPart`.
- Shared: partID → source URL → PartID (reverse of `partIDs(for:)`).

### 4. Ground / fix a part (the fixed base) — both engines
- Mark a part as **ground** (fixed reference). Backend exists
  (`togglePartGrounded` → AnimaCore `is_grounded`); the grounded part is the
  root the solver positions everything else against, and the one part a move
  gesture will not move.
- Tree + context menu already expose Ground/Unground; surface it in the viewport
  too (pin badge, and a distinct tint/lock in the engine state — state bit 2).
- Only one active ground per assembly is typical; allow it, don't force it.

### 5. Move parts in the environment (transform) — both engines
- Select a part → translate/rotate **gizmo** in the viewport → updates the part's
  rest transform (or its driving mate's DOF). Grounded parts don't move.
- Shared: gizmo math + writing the transform to the part (rest transform via
  `setPartPosition`/`setPartRotation`, already present for the RealityKit path).
- Metal: fill `partTransformBuffer[partID]` (already plumbed) with the part's
  transform. WebGPU: set the part mesh's `matrixAutoUpdate=false` + `matrix`.
- Snap/precision + numeric entry reuse the existing inspector fields.

### 6. Selection niceties (after 1–5)
- Multi-select (⌘/⇧), marquee/box select, hover highlight, "isolate" (already in
  the tree), frame-selected (ViewCube/Home already fits all).

## Success criteria
- On **both** engines, at 40+ parts: hide a part → it vanishes; click a part in
  the viewport → it highlights + selects in the tree; ground a part → it's pinned
  and excluded from moves; drag a non-grounded part → it moves and persists.
- Shared logic has no engine `if`s beyond the thin draw/readback adapter.

## Order of execution
1 → 2 (WebGPU) · 3 (pick, both) · 4 (ground surfacing) · 5 (move, both) · 6.
