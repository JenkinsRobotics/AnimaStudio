# Codex task — build out the 3D Modeling workspace (parts, frames, mates, sub-assemblies)

You are building the real CAD assembly workspace in AnimaStudio's **3D Modeling**
tab: move parts, mate parts, make sub-assemblies, and give the scene proper
coordinate frames (workspace origin + planes, and each part's own origin). This
is Onshape/SolidWorks-grade *assembly* editing (no sketching/solid modeling —
parts arrive as imported STEP).

## Read first
- `dev/docs/roadmap/CAD_Viewport_Functions.md` — the viewport function list + status.
- `dev/docs/roadmap/Assembly_Mating_Architecture.md` — the data model + solver + bridge.
- `CLAUDE.md` / `AGENTS.md` — lane split and boundaries.
- Current code: `app/Sources/AnimaStudioUI/Components/AssemblyTreeView.swift`,
  `app/Sources/AnimaCADViewport/CADPipelineViewport.swift`,
  `CADMetalViewport.swift`, `CADWebGPUViewport.swift`,
  `app/Sources/AnimaStudioUI/AppShell/StudioWorkspaceModel.swift`.

## What already works (don't rebuild)
- Assembly tree (`AssemblyTreeView`) sourced from `engineParts`/`engineMates`/
  `componentGroups`: parts, reference-geometry nodes, groups, mates; hide/select/
  isolate/ground/group in the tree.
- **Per-part hide, select, and click-to-pick** in **both** Metal and WebGPU, on a
  **shared node→part mapping** in `CADPipelineViewport` (`partIDs(for:)` /
  `sourceURL(forPartID:)`). partID = assemblyNode + 1. One STEP file = one part =
  a range of assembly nodes.
- Shared ViewCube driving both engines' cameras.

## Architecture rules (must follow)
1. **Shared-first.** All CAD logic lives in the shared layer (`CADPipelineViewport`
   + `StudioWorkspaceModel`); each engine is a *thin adapter* that only uploads
   geometry and draws. Compute state (transforms, part IDs, frames) **once** and
   hand the same values to Metal and WebGPU. New engine-specific code only for the
   actual GPU call.
2. **Mate/assembly *meaning* lives in AnimaCore (Python)**, surfaced via the
   bridge. Do NOT add mate/kinematics math to Swift. Swift picks the feature and
   renders; AnimaCore owns frames/DOF/solve. Coordinate backend verbs with the
   backend lane (Claude) via the mailbox — they are listed as dependencies below.
3. **Both engines** must support every feature. WebGPU JS is
   `dev/Codex Bench/web/threejs/src/app.js`; after editing run
   `node build.mjs` there and copy `../../Resources/ThreeJSWeb/app.js` →
   `app/App/Resources/CADWeb/ThreeJSWeb/app.js`.

## Coordinate frames (the mental model — implement to this)
- **Workspace origin** = the character/assembly origin at (0,0,0), with **Front /
  Top / Right** reference planes and an axis triad. This is the fixed global frame.
- **Part origin** = each part's own local frame. Its placement in the assembly is
  its **rest transform** — AnimaCore `Part.position_m` + `rotation_euler_rad`
  (already in the model; edited via `setPartPosition`/`setPartRotation`). That
  transform *is* "part origin expressed in workspace origin."
- **Moving** a part edits its rest transform. A **grounded** part is pinned at its
  rest transform and is the fixed base the solver positions others against.
- **Mates** constrain part **connectors** (oriented frames on parts) to each other;
  the solver derives part poses from mates + DOF.

## Tasks (in order — each ships something visible on both engines)

### 1. Reference geometry: real Origin + planes
- Render the workspace **Origin triad** and **Front/Top/Right planes** in the
  viewport, toggizable from the existing tree nodes (they're currently cosmetic).
- Wire their visibility through the shared layer to both engines (Metal: draw a
  grid/plane + triad; WebGPU: `THREE.GridHelper`/`PlaneHelper` + `AxesHelper`).
- Accept: origin triad + 3 planes visible and independently toggleable; both engines.

### 2. Part origin vs workspace origin: display + inspector
- On selection, draw the selected part's **local origin triad** at its placement.
- Inspector already exposes the part transform (position/rotation) relative to the
  workspace origin — surface it clearly as "Part origin (in assembly)".
- Accept: selecting a part shows its origin triad + editable numeric transform.

### 3. Move parts: gizmo + per-part transform (both engines)
- Translate/rotate **gizmo** on the selected part in the CAD viewport. Grounded
  parts don't move.
- Shared: gizmo hit-test + delta → write the part rest transform
  (`setPartPosition`/`setPartRotation`). Engines only *apply* a per-part transform:
  - Metal: fill `partTransformBuffer[partID]` (already bound at buffer index 2).
  - WebGPU: set the part mesh's `matrixAutoUpdate=false` + `matrix`.
- Add a shared `partTransforms: [partID: float4x4]` on `CADPipelineViewport`,
  computed from part rest transforms, handed to both engines (mirror how
  `hiddenPartIDs`/`selectedPartIDs` already flow).
- Accept: drag a non-grounded part → it moves in the viewport, persists to the
  project, and the inspector updates; both engines; 40+ parts stay at 60 fps.

### 4. Ground/fix: surface in the viewport
- The ground toggle exists (`togglePartGrounded` → AnimaCore `is_grounded`, shown
  in tree). Mark the grounded part distinctly in the viewport (Metal: state bit 2
  in the part-state buffer → a lock tint; WebGPU: an emissive/opacity cue) and
  block move gestures on it.
- Accept: ground a part → visibly pinned + immovable.

### 5. Mating parts: connectors → mate → solve  (needs backend verbs)
- Per Assembly_Mating_Architecture §Phase 1: pick a **connector** frame on two
  parts (reuse the existing `MateConnectorInference`/marker picking), choose a mate
  type (**fastened, revolute, slider** first), create the mate through AnimaCore,
  and let the solver reposition the child.
- **Backend dependency (Claude lane):** wire `add_mate`/`update_mate`/`remove_mate`
  in `AnimaCoreClient` (the Python verbs already exist but the Swift client never
  calls them), plus incremental `add_part`/`add_connector` verbs. Request these via
  the mailbox before wiring the Swift UI to them; until then, keep the local draft
  path behind a flag.
- Accept: place connectors on 2 parts → create a fastened + a revolute mate →
  engine positions the child; changing the revolute DOF moves it; round-trips to
  `.character.anima` and reloads identically.

### 6. Sub-assemblies (groups) as real assembly nodes
- Groups exist but are flat/navigator-only. Give a group its own **origin/transform**
  so it moves/grounds/hides as a unit, and allow nesting (a group inside a group).
- Accept: group parts → move/ground the group as one; nested groups; the tree shows
  the nesting.

## Verify (every change)
```
cd app && swift build && swift test          # 355 XCTest + 28 Swift Testing must pass
# WebGPU JS after edits:
cd "dev/Codex Bench/web/threejs" && node build.mjs \
  && cp ../../Resources/ThreeJSWeb/app.js ../../../app/App/Resources/CADWeb/ThreeJSWeb/app.js
# engine (if backend verbs touched):
.venv/bin/pytest animacore/tests
# root app (kill the running instance first, or the mv silently fails):
pkill -9 -f "Anima Studio.app/Contents/MacOS"; rm -rf "Anima Studio.app" "Anima Studio.app.staging"
cd app && ./Scripts/build-root-app.sh
```

## Notes / gotchas
- The WebGPU renderer is a WKWebView — it can't be visually verified headlessly.
  Keep its changes minimal and mirror the Metal behavior exactly; test in the GUI.
- Keep the per-engine adapter thin: if you're writing the same logic twice, it
  belongs in the shared layer.
- Preserve the shared `partID = assemblyNode + 1` convention across both engines.
- Update `dev/docs/reality/STATUS.md` for each shipped, visible behavior, and add a
  Handoff-log entry in the active briefing.
