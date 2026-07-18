# Test Apps — what's floating around & how to launch each

> 2026-07-17. Two agents built benches for the six-pipeline CAD evaluation:
> Claude's live in `dev/labs/`, Codex's live in `cad-test/`. This page is the
> single map. Rebuild Claude's set with `dev/labs/build.sh`; Codex's with
> `cad-test/scripts/build.sh`. (The old "Test Lab" launcher is removed — it
> had no pipeline of its own.)

## The two main apps

| App | Author | Pipelines | Launch |
|---|---|---|---|
| **Claude Bench** | Claude | P1 RealityKit / P2 MetalKit / P3 OCCT-GL / P6 ModelIO as radio buttons in one workspace; P4 Qt via sidebar button; P5 documented-blocked | Double-click **`dev/labs/apps/Claude Bench.app`** |
| **Codex GeomBench** | Codex | Codex's build of the same six-pipeline spec | Double-click **`cad-test/GeomBench.app`** (or `cad-test/scripts/launch.sh`) |

Compare workflow: load the same STEP in both apps, and inside Claude Bench
flip the backend radio buttons — same file, different renderer each click.

## Supporting benches (command line)

| Bench | What | Run |
|---|---|---|
| qtbench (P4) | Qt6 + OCCT built-in GL viewer, native face hover/select | Claude Bench sidebar → "Launch P4", or `dev/labs/qtbench/build/qtbench.app/Contents/MacOS/qtbench "<file.step>"` |
| Codex Qt GL | Codex's Qt variant | `cad-test/build/qt/GeomBenchQtGL.app` |
| rustbench | Rust kernel (truck) → browser page. Known: panics on several real STEPs | `dev/labs/rustbench/run.sh "<file.step>"` |
| StlViewer | Baseline: today's app loader (ModelIO). STEP fails in red on purpose | `dev/labs/apps/StlViewer.app` (double-click) |
| **OpenGeometry** | Rust/WASM browser CAD kernel. Builds primitives live; **has no STEP importer** (export-only) so your files can't load — the bench shows this honestly | `dev/labs/opengeometry-bench/run.sh` (opens in browser) |
| **Unity** | STEP→OBJ+MTL via the Open CASCADE shim (real CAD colors), imported into a Unity scene. Shows: Unity renders, our kernel did the CAD work | `dev/labs/unity-bench/`: converter is `step_to_obj`; open `UnityBench/` in Unity, scene `Assets/Bench.unity` |
| OCCT kernel report | Headless precision numbers (1e-16 boolean exactness, STEP round-trip, quality dial) | `dev/labs/bin/occt_test` in Terminal |
| Anima Studio | The real app, for comparison | `Anima Studio.app` at the repo root |

Test file sets: `CAD DEMO/ARCADA001` (31 STL) · `ARCADA001-2` (46 STEP) ·
`ARCADA001-3` (46 OBJ).

Known trap (both agents): don't set `MTL_HUD_ENABLED` — Apple's Metal HUD
library crashes RealityKit windows on this OS. Full landmine list:
`dev/briefings/codex.md`. Detailed findings: `dev/labs/README.md`.

---

## Jonathan's test notes

| App / pipeline | File tested | Loaded? | Looks right? | Selection works? | FPS / feel | Notes |
|---|---|---|---|---|---|---|
| Claude Bench — P1 RealityKit | | | | | | |
| Claude Bench — P2 MetalKit | | | | | | |
| Claude Bench — P3 OCCT-GL | | | | | | |
| Claude Bench — P6 ModelIO | | | | | | |
| qtbench (P4) | | | | | | |
| rustbench | | | | | | |
| Codex GeomBench | | | | | | |
| Codex Qt GL | | | | | | |
| Anima Studio (main app) | | | | | | |

### Verdict so far (fill in / correct me)

- Winner:
- Runner-up:
- Disqualified:
- What the main app should adopt:
