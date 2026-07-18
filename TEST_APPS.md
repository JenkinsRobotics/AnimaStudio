# Test Apps — what's floating around & how to launch each

> 2026-07-17. Two agents built benches for the six-pipeline CAD evaluation:
> Claude's live in `dev/labs/`, Codex's live in `cad-test/`. This page is the
> single map. Rebuild Claude's set with `dev/labs/build.sh`; Codex's with
> `cad-test/scripts/build.sh`.

## Launchers (start here)

| App | Author | How to launch |
|---|---|---|
| **Test Lab** | Claude | Double-click `Test Lab.app` at the repo root. Menu of every Claude bench + one-file "Launch ALL Pipelines" side-by-side compare |
| **Codex GeomBench** | Codex | Double-click `cad-test/GeomBench.app` (or `cad-test/scripts/launch.sh`) |

## The benches

| App | Author | Pipelines | Launch |
|---|---|---|---|
| **Claude Bench** | Claude | P1 RealityKit / P2 MetalKit / P3 OCCT-GL / P6 ModelIO as in-app radio buttons; P4 Qt via sidebar button; P5 documented-blocked | Double-click `dev/labs/apps/Claude Bench.app`, or Test Lab → Pipeline 1 row |
| **Codex GeomBench** | Codex | Its own build of the same six-pipeline spec | `cad-test/GeomBench.app` |
| **Codex Qt GL bench** | Codex | Qt + OCCT GL | `cad-test/build/qt/GeomBenchQtGL.app` |
| **qtbench** | Claude | P4 — Qt6 + OCCT built-in GL viewer (native face hover/select) | Test Lab → Pipeline 3 row (pick a STEP), or Claude Bench sidebar → "Launch P4" |
| **rustbench** | Claude | Rust kernel (truck) → Three.js browser page | Test Lab → Pipeline 2 row (pick a STEP; page opens in browser). Known: panics on several real STEPs |
| **StlViewer** | Claude | Baseline — today's app loader (ModelIO). STEP fails in red on purpose | Test Lab → BASELINE row (pick a file) |
| **OCCT kernel report** | Claude | Headless precision numbers | Test Lab → kernel report row (output shows in the pane) |
| **Anima Studio** | both lanes | The real app, for comparison | `Anima Studio.app` at the repo root |

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
