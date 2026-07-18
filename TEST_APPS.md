# Test Apps — the CAD-pipeline benchmark

> 2026-07-18. Consolidated. There is now **one** benchmark app: **Unified
> Bench**, in `dev/labs/UnifiedBench/`. It harvested the best of the three
> demo apps (Codex / Claude / Gemini). The old separate benches are archived.

## Run it

```bash
cd dev/labs && ./build.sh          # first time / after changes
open dev/labs/apps/UnifiedBench.app
# or with a file preloaded:
open -n dev/labs/apps/UnifiedBench.app --args "CAD DEMO/ARCADA001-2/ARCADA001 - ARCADP001.step" 0.001
```

## The 8 pipelines (radio buttons in one workspace)

1. Open CASCADE → **RealityKit** — face/edge select, CAD colors, themes. **The one that ships (option A).**
2. Open CASCADE → **Metal** (custom MTKView)
3. Open CASCADE → **SceneKit** (harvested from Gemini)
4. Open CASCADE **built-in GL viewer**
5. Open CASCADE → **WebGL** (Three.js in a WKWebView)
6. **OpenGeometry** (Rust/WASM — no STEP import; shows its own primitives)
7. **Qt + Open CASCADE** (separate window — Qt owns its event loop)
8. **Unity** (shim → OBJ+colors → Unity editor; separate window)

Controls: drag orbit · **shift+drag roll** · middle-drag pan · scroll zoom ·
click face/edge · Theme dropdown (10) · Fit View.

## What was harvested (see `dev/labs/UnifiedBench/README.md`)

- **Codex** → camera roll/tilt + modular structure
- **Claude** → theme system (10) + face/edge selection
- **Gemini** → SceneKit engine

## The three original demo apps (for the record)

- **Claude**: `dev/labs/archive/OldClaudeBench` (superseded by Unified Bench)
- **Codex**: `cad-test/`
- **Gemini**: `gemeniARCADA001-2/GeomBench`

`dev/labs/archive/` also holds `StlViewer` (old ModelIO baseline), `rustbench`
(the Rust pipeline that panicked on real files), and `kernel_test` (OCCT
precision report) — all dead/reference-only.

---

## Jonathan's test notes

| Pipeline | File tested | Loaded? | Looks right? | Selection? | FPS / feel | Keep / cut |
|---|---|---|---|---|---|---|
| 1. RealityKit | | | | | | |
| 2. Metal | | | | | | |
| 3. SceneKit | | | | | | |
| 4. OCCT built-in GL | | | | | | |
| 5. WebGL | | | | | | |
| 6. OpenGeometry | | | | (no STEP) | | |
| 7. Qt | | | | | | |
| 8. Unity | | | | | | |

### Verdict
- Winner:
- Native alternates to keep:
- Cut:
