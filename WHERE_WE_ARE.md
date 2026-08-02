# Where we are — Aether Animation rebuild

_Snapshot for pausing development · 2026-08-01_

## TL;DR

The Swift animation app is being rebuilt as a **web app** (React + TS +
Vite) on a **shared widget library** (`aether-ui/`), talking to the
**Python engine** (`animacore/`) over an HTTP bridge. The rebuilt app is
**launchable now** with the full authoring chrome. Remaining work is
mostly **engine verbs** (clip editing, hardware), not UI.

## How to launch it (double-click, no terminal)

- **`Aether Animation.app`** (repo root) — the rebuilt animation app.
  Starts the engine + opens the workspace.
- **`Aether UI.app`** (repo root) — the widget gallery, for reviewing /
  improving UI elements in isolation.

Both are gitignored bundles. Rebuild after code changes:
```
zsh aether-animation/Launcher/build-launcher.sh
zsh aether-ui/Launcher/build-launcher.sh
```

Dev mode (live reload): run the engine
`.venv/bin/python -m animacore.httpbridge`, then `npm run dev` in
`aether-animation/web/` (app) or `npm run gallery` in `aether-ui/`.

## What's DONE (committed, on `master`, through 3a7fc00)

**Shared widgets — `aether-ui/`.** Every widget is spec'd once in
`aether-ui/WIDGETS.md` with tests, so it looks/behaves identically
everywhere (this fixes the recurring "the list tree is different every
time" problem). Finished: Tree (full: multi-select, keyboard, filter,
row actions), Tabs, Dialog (focus trap), Ribbon, TextField
(invalid/unit), Rail, Button, StatusBar, ViewportCanvas, **WorkspaceShell**
(the app window: docked / floating / canvas presets), **FloatingPanel**,
**DocumentBar**, **LayoutPresetButton** (the studio flip button),
**Timeline** (dope sheet). 32 tests green.

**Rebuilt app — `aether-animation/web/`.** Full chrome, all on the shared
widgets:
- Document bar: brand, character, engine status; centered workspace tabs
  (Assets / 3D Modeling / Animate); Save; the studio layout button
  (3 presets, persisted).
- Left sidebar: Character / Parts / Mates / Clips. Right sidebar:
  Inspector (part/mate details + Remove) / Pose (live DOF sliders).
- Every panel docks, floats (tear-off + drag), or hides per preset.
- **Mate authoring** (3D Modeling): all 8 kinematic mate tools from the
  engine → pick two connectors in the viewport → flip/reorient → Solve
  (preview) → Create (commit). Works end-to-end.
- **Timeline dope sheet** (Animate): per-DOF keyframe tracks from the
  clip, adaptive ruler, scrub, play/pause. Live posing through the engine.

## What's NOT done yet (pick up here)

1. **Engine clip-CRUD verbs** — the timeline is **read-only** until the
   engine can add/move/delete keyframes. This is the next task and it
   unblocks real animation editing. (Codex requested this; see
   `dev/briefings/claude.md` IN.)
2. **Assets workspace** — tab exists but STEP/mesh import isn't wired in
   the web app yet (import currently lives in the CAD lane).
3. **Hardware / Show workspaces** — not built; need the engine
   session/output verbs (Codex's queued packet).
4. **Fold the engine into one polyglot Aether Core** — see the
   Architecture decision below. This supersedes the old "just rename
   `animacore`" note. Big, cross-lane, atomic — plan + coordinate with
   Codex, don't big-bang it.
5. Smaller widget deferrals are listed at the bottom of
   `aether-ui/WIDGETS.md` (keyframe drag, panel drag-reorder, chrome-shape
   presets, curves view, etc.).

## Architecture decision — one polyglot Aether Core (Jonathan, 2026-08-01)

**There is ONE shared foundation: Aether Core.** Everything shared lives
in it — geometry, KI/IK solvers, mates, kinematics, all the semantic
math. It is **multi-language by design**: each subsystem is written in
the **best language for the job**, and **performance is a first-class
requirement**. This is not a rewrite-everything-into-one-language plan.

What "best language + performance" means concretely:

- **Geometry kernel** → C++ (OCCT), used as **WASM** in the browser.
  Already best-in-class — adopt, never rebuild. (Codex's `aether-core` TS
  side wraps this.)
- **Hot numeric kernel** — forward kinematics, IK/DH solvers, mate/pose
  resolution, clip evaluation — is the real-time, per-frame path. The
  performance-right home for this is a **compiled systems language
  (Rust, leading candidate)** that compiles to **both WASM and native
  from one source**. Payoff: the browser runs FK/IK/eval **in-process
  (no bridge round-trip per frame)**, and hardware/offline runs the
  **same** code natively at full speed. One implementation, two targets.
- **Orchestration / IO / hardware transport / serialization / project
  management** — not perf-critical; stay in the **ergonomic** language
  (Python today; pyserial + the mature engine live here).

Where that leaves the HTTP bridge: it is **not** a compromise to remove —
it's Aether Core's own internal transport between its native/Python side
and its TS/browser side. "Multiple languages" *requires* something like
it, because the language halves can't call each other in-process. As the
hot kernel moves to Rust→WASM, the bridge stops being on the interactive
hot path (preview runs locally) and is used for save/validate/hardware.

Target shape:

```
aether-core/
  ts/        geometry+render bindings: OCCT(WASM), WebGPU, Part/sketch, STEP   (Codex)
  rust/      the numeric kernel: FK, IK/DH, mate+pose resolution, eval → WASM + native   (planned)
  python/    orchestration, hardware (pyserial), .anima IO, bridge   (was animacore/)
  README.md  why this core is multi-language
```

Migration is **phased and parity-gated, never big-bang**:

1. Fold `animacore/` in as `aether-core/python/` (atomic rename, one
   sweep; coordinate with Codex who owns `aether-core/`). Answers Codex's
   standing rename request.
2. Carve the hot numeric kernel to Rust **behind the existing Python
   API**, with the current **~1180 Python tests as the conformance
   oracle** — the Rust kernel must match them before anything flips.
3. Ship the Rust kernel as WASM into the web apps so the preview/pose
   loop is local (kills the per-frame round-trip), and as a native lib
   for hardware/offline.

**Cross-language seam to get right:** the mate / connector / joint data
model. TS geometry produces connector frames; the numeric kernel
consumes them. Per Codex's rule this is **one stable-ID Core entity**
shared across all three languages — that shared shape is the real design
work, more than the file moves.

## Uncommitted in the tree (not mine — leave for their owners)

`Aether CAD/`, `aether-core/`, `dev/briefings/codex.md`, `STATUS.md`, and
a few docs carry Codex's / your in-flight work. My changes are all
committed; I only left the shared `.gitignore` and the briefing/handoff
edits staged with each commit.

## Map

- `aether-ui/` — shared widgets + gallery. `WIDGETS.md` = the status
  matrix (start here for UI work).
- `aether-animation/web/` — the rebuilt app. `src/App.tsx` is the shell;
  `MateDialog.tsx` / `TimelinePanel.tsx` / `PosePanel.tsx` are subsystems.
- `aether-animation/archive/` — the old Swift app (behavior reference,
  not built).
- `animacore/` — the Python engine (single source of animation meaning).
- `dev/briefings/2026-07-14-bottango-parity.md` — the full session-by-session
  handoff log.
