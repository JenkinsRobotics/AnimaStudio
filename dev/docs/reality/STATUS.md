# STATUS

> Truthful, or it's worthless. Any commit that changes behavior updates
> this file in the same commit — see `CONVENTIONS.md` → "STATUS stays
> truthful."

## Current state — 2026-07-14

- **Repo:** `AnimaStudio` — open-source unified character animation
  system for AI robots (digital avatars + physical animatronics from
  one rig, one format, one authoring tool)
- **Version:** 0.1.0 (see `anima_studio/__init__.py`)
- **JaegerOS pin:** not yet set — for now the runtime is standalone and
  Jaegers read `.anima` files natively; the `jaeger-os` dependency and
  `animation`-slot module land later (see `dev/docs/roadmap/`)
- **What works:** the native macOS foundation under `studio/` builds and
  launches as a Swift package. `AnimaCore` defines project assets, joint rigs,
  clips, hold/linear keyframes, deterministic evaluation, neutral fallback,
  time clamping, joint-limit clamping, and Codable project round-tripping. The
  SwiftUI workspace has Build/Animate modes, an Assets/Structure/Joints/
  Animations navigator, RealityKit 3D viewport, contextual inspector, transport,
  timeline tracks/keyframes, click/drag scrubbing, and looping playback. Users
  can select a RealityKit-supported USD/Reality model; it loads asynchronously
  into the viewport, is normalized for preview framing, and appears in the
  project asset tree. Six tests pass with `cd studio && swift test`, including a
  real USD hierarchy load through RealityKit. The Python package skeleton also
  installs with `pip install -e ".[dev]"`. The Python runtime now implements
  the Anima Wire Protocol v0 reference host (`anima_studio/wire.py` — encode
  HELLO/CFG/FRM/EN/STOP/PING, parse ANIMA/OK/ERR/PONG, 3-decimal normalized
  values), an in-process simulated device (`anima_studio/sim.py` — handshake,
  servo CFG, device-side linear FRM interpolation on an explicit `tick(now_ms)`
  clock, E-stop, per-channel 2000 ms failsafe, spec ERR codes), and a keyframe
  clip evaluator mirroring AnimaCore semantics (`anima_studio/clips.py` —
  hold/linear, time and joint-limit clamping, deterministic; no Bézier yet).
  74 Python tests pass with `.venv/bin/pytest anima_studio/tests -q`
  (lint: `.venv/bin/ruff check .`), including an end-to-end clip → FRM stream →
  simulated servo → failsafe test.
- **What's stubbed:** every `*.example` file under `anima_studio/` —
  `module.yaml`, `config.py`, `node.py`, the module-contract test —
  these are the JaegerOS-module shape for later
- **Known gaps:** imported model hierarchies cannot yet be inspected/mapped to
  semantic parts; joints and keyframes are not yet editable; project changes
  are not persisted; imported security-scoped URLs last only for the current
  session. There is no `.anima` parser, undo/redo, Bézier curve editor, audio,
  screens/LEDs, Live2D, scene execution, output node, JaegerOS connection, or
  JP01 character file. Studio is a working workspace foundation, not yet a
  complete authoring workflow.

## How to update this file

1. Ship a behavior change.
2. In the same commit, add or edit a line above reflecting the new truth.
3. If something moves from "planned" to "shipped," delete it from
   `../roadmap/` (or mark it done there) — don't leave the same fact
   living in two docs, per `CONVENTIONS.md` law 1.
