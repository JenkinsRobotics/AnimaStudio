# AnimaStudio — Unity front-end

A Unity front-end for AnimaStudio, following the **Bottango model** (Unity 3D
viewport + keyframe timeline + interpolation curves → hardware). The Python
engine `animacore/` stays the **single source of truth** — this app talks to it
over the same JSON-stdio bridge the Swift app uses. **No animation/mate/
kinematics logic is reimplemented here; it lives in the engine.**

## Why Unity
Everything that is slow to hand-build in a custom renderer — selection, picking,
gizmos, materials, **Unity Timeline + AnimationCurve**, video textures, VR,
cross-platform builds — is a Unity built-in. We wire the (already-built) engine
brain to Unity's body.

## Prerequisites
1. **Unity Hub** + **Unity 6 LTS** (free Personal license). If your patch differs
   from `ProjectSettings/ProjectVersion.txt`, Unity Hub will offer to open with
   your installed version — accept it.
2. **Python engine** — the repo's `.venv` with `animacore` installed. The bridge
   auto-finds `<repo>/.venv/bin/python` (macOS/Linux) or `.venv/Scripts/python.exe`
   (Windows), and falls back to `python3`/`python` on PATH.

## Run the Studio app
1. **Unity Hub → Open** → select `unity/AnimaStudioUnity`. Let it import
   (first import downloads packages incl. Newtonsoft.Json — a minute or two).
2. Menu bar: **AnimaStudio ▸ Build Studio Scene** (wires camera, light, ground,
   and the `StudioShell` app and saves `Assets/AnimaStudio/Scenes/Studio.unity`).
3. Press **Play**.

You get the AnimaStudio workspace shell, mirroring the Swift app's **dock
variant**: header tabs (**Assets · 3D Modeling · Animate · Show · Hardware**),
a grouped ribbon toolbar, and **44 px icon rails on both sides** with
collapsible tabbed panels — left rail switches the navigator tab per
workspace (e.g. PARTS / MATES / REL in 3D Modeling), right rail switches
Inspector / View (view presets Front·Right·Top·Iso, Zoom to fit, ground
toggle). Click a rail tab again (or the ◀/▶ chevron) to collapse the panel
and give the viewport the full width:

- **Assets** — character library (`examples/`, `characters/`) with one-click
  Load, the mesh library, and the import toolbar. **STEP import**: paste a
  `.step`/`.stp` path → every solid is tessellated to a per-part OBJ
  (`unity/Tools/step_to_obj.py`, OCCT via `cascadio`; install with
  `.venv/bin/pip install -e ".[cad]"`), placed at its CAD assembly position
  (rest transform, mm→m), and committed to the rig through the engine's
  `add_part` verb. **New Assembly** creates `characters/<name>/` and starts an
  empty character to import into. **Save** (header) serializes the rig through
  the engine and writes the `.character.anima`.
- **3D Modeling** — parts tree (grounded ⏚ / suppressed flagged) and the
  Onshape-style **mate dialog**: pick a type in the MATE ribbon, then click
  faces in the viewport — a **ghost XYZ triad previews the connector** and
  snaps to **bore/cylinder centers** (primary = the bore axis), **flat-face
  centers**, and **vertices** (Shift = raw surface point). First pick is the
  part that moves. **Solve** previews the engine's `preview_mate` result in
  the viewport; ✓ commits via `add_mate` with real connectors, offset, flip,
  secondary rotation, and simulation-connection controls per the engine's
  mate schema. Select a mate to inspect its DOF or Remove it.
- **Animate** — clip list, **live DOF pose sliders** (each drag re-poses
  through the engine's `dof_values` overrides — relations and limits
  included), and the bottom transport bar (play/pause, scrub).
- **Show / Hardware** — placeholders until the engine session verbs land.

Parts whose `model` is an `.obj` render the real mesh; everything else is a
placeholder box at the engine-resolved pose.
**Right-drag orbits, middle-drag pans, wheel zooms; left-click selects.**

If it errors, the Console shows exactly why (paste it back) — the C# compile
errors and the engine's `[animacore]` stderr are both surfaced.

## Standalone app
Menu bar: **AnimaStudio ▸ Build macOS App** → `unity/AnimaStudioUnity/Builds/
AnimaStudio.app` — a normal double-clickable app with the same shell UI.
It finds the repo (Python engine + examples) by walking up from its own
location, so keep the build inside the repo, or set `ANIMASTUDIO_REPO=/path/to/
AnimaStudio` if you move it elsewhere.

Headless build (CI or terminal):
```bash
"/Applications/Unity/Hub/Editor/<version>/Unity.app/Contents/MacOS/Unity" \
  -batchmode -quit -projectPath unity/AnimaStudioUnity \
  -executeMethod AnimaStudio.EditorTools.AnimaStudioSceneBuilder.BuildAll
```

## What works (and what's next)
- ✅ **Unity ⇄ AnimaCore bridge** (`AnimaCoreBridge.cs`) — same protocol as Swift.
- ✅ **Studio shell app** (`StudioShell.cs`): load character → parts tree,
  inspector, clip transport; clip playback and live DOF posing both evaluated
  by the engine (`resolve_pose` with `clip`/`time_s`/`dof_values`).
- ✅ **Standalone macOS build** with the same UI.
- ✅ Assembly Workbench scene (OBJ parts, drag-to-place) — the Workbench tab.
- ⏭️ **Real STEP/STL meshes** replace the placeholder boxes (STEP → per-part
  OBJ/glTF → Unity). The engine + kernel already produce the geometry.
- ⏭️ Move/rotate gizmos, keyframe **editing** (engine clip CRUD verbs land
  first), curve view, then `sim.py` → hardware output.

## Layout
```
unity/AnimaStudioUnity/
  Assets/AnimaStudio/
    Scripts/AnimaCoreBridge.cs   ← engine process + JSON stdio
    Scripts/StudioShell.cs       ← THE APP: shell UI, pose/clip loop, selection
    Scripts/AssemblyScene.cs     ← minimal first-proof scene (kept as reference)
    Scripts/AssemblyManager.cs   ← Workbench: OBJ library, drag-to-place
    Scripts/RuntimeObjImporter.cs← runtime .obj → Mesh
    Scripts/CameraOrbit.cs       ← orbit / pan / zoom
    Editor/AnimaStudioSceneBuilder.cs  ← scene builders + macOS app build
  Packages/manifest.json         ← Newtonsoft.Json, Timeline, UI, Video
  ProjectSettings/ProjectVersion.txt
```
`Library/`, `Temp/`, `Builds/` etc. are git-ignored — only `Assets/`,
`Packages/`, `ProjectSettings/` are tracked.
