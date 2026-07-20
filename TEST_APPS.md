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

## The 4 in-app pipelines (radio buttons in one workspace)

All embed directly in the Swift app — no external process, no separate install.

1. Open CASCADE → **RealityKit** — face/edge select, CAD colors, themes. **The one that ships (option A).**
2. Open CASCADE → **Metal** (custom MTKView)
3. Open CASCADE → **SceneKit** (harvested from Gemini)
4. Open CASCADE → **WebGL** (Three.js in a WKWebView)

**Cut when finalized:** Unity + Qt (external window — needed a separate app),
OpenGeometry + ModelIO (can't import STEP), OCCT built-in GL viewer (deprecated
OpenGL — wouldn't render on macOS 26).

Controls: drag orbit · **shift+drag roll** · middle-drag pan · scroll zoom ·
click face/edge · Theme dropdown (10) · Fit View.

## What was harvested (see `dev/labs/UnifiedBench/README.md`)

- **Codex** → camera roll/tilt + modular structure
- **Claude** → theme system (10) + face/edge selection
- **Gemini** → SceneKit engine

## The original demo apps (for the record)

Unified Bench harvested the best of three, then finalized down to five in-app
pipelines:

- **Claude** → became **Unified Bench** itself (the old standalone + archive were deleted)
- **Codex** → `dev/Codex Bench/`
- **Gemini** → `gemeniARCADA001-2/`

---

## Jonathan's test notes

| Pipeline | File tested | Loaded? | Looks right? | Selection? | FPS / feel | Keep / cut |
|---|---|---|---|---|---|---|
| 1. RealityKit | | | | | | |
| 2. Metal | | | | | | |
| 3. SceneKit | | | | | | |
| 4. WebGL | | | | | | |

### Verdict
- Winner:
- Native alternates to keep:
- Cut:
