# Anima Studio contributor contract

This repository is building an open animation, motion-authoring, and show-control
system for digital characters and physical audio-animatronic robots. The first
product milestone is hardware animation authoring: import an existing model,
define its movable structure, animate it on a timeline, preview it, and later
route the same evaluated motion to hardware.

This file is the shared briefing for every agent working the repo —
Claude Code reads it as `CLAUDE.md` (a symlink to this file), Codex
reads it as `AGENTS.md`. Edit this one file only.

## Read before changing code

1. [`CONVENTIONS.md`](CONVENTIONS.md)
2. [`dev/docs/reality/STATUS.md`](dev/docs/reality/STATUS.md)
3. The active briefing in [`dev/briefings/`](dev/briefings/README.md) —
   the current goal, the lane split between agents, and the handoff log
   you must append to after each work session.
3. [`dev/docs/roadmap/Hardware_Animation_Milestone.md`](dev/docs/roadmap/Hardware_Animation_Milestone.md)
4. [`dev/docs/roadmap/Studio_App.md`](dev/docs/roadmap/Studio_App.md)
5. The format document affected by the change:
   [`Character_Format.md`](dev/docs/roadmap/Character_Format.md) or
   [`Scene_Format.md`](dev/docs/roadmap/Scene_Format.md)

## Non-negotiable boundaries

- `AnimaCore` is renderer-, UI-, AI-, and hardware-independent.
- RealityKit displays evaluated state; it does not define timeline or rig
  semantics.
- Hardware adapters consume evaluated targets; vendor channel details do not
  enter the core animation model.
- Contract fields use explicit units. Swift properties use names such as
  `timeSeconds`, `angleRadians`, and `velocityRadiansPerSecond`.
- Physics/dynamics simulation is deferred. Preview is kinematic.
- Model creation belongs in Blender/CAD tools. Studio imports and animates.
- AI assistance is optional authoring functionality; saved animation never
  requires an AI model to play.

## Swift package ownership

| Target | Owns | Must not own |
|---|---|---|
| `AnimaCore` | rigs, joints, clips, keyframes, curves, evaluation, validation | SwiftUI, RealityKit, file dialogs, hardware SDKs |
| `AnimaViewport` | renderer-neutral preview contracts | concrete renderer behavior |
| `RealityKitViewport` | model loading/display, camera, selection, joint gizmos | persisted format semantics, hardware mapping |
| `AnimaStudioApp` | workspace state, commands, panels, document/file interaction | duplicate evaluator logic |

Add a new target only when it represents a proven dependency boundary. Do not
create speculative plugin packages.

## Working agreements for parallel contributors

- Keep changes within one ownership area when possible.
- Announce or document contract changes before editing both producer and
  consumer targets.
- Never create a second representation of a shared truth merely for one view;
  add a projection/helper around the core type.
- New evaluator behavior requires deterministic unit tests.
- New visible behavior requires `dev/docs/reality/STATUS.md` to change in the
  same work unit.
- Planned behavior stays in `dev/docs/roadmap/`; shipped behavior stays in
  `dev/docs/reality/STATUS.md`.
- Preserve unrelated working-tree changes. This repo may be edited by multiple
  contributors at once.

## Verification

Swift (Studio), from `studio/`:

```bash
swift format lint --recursive Sources Tests Package.swift
swift test
```

Python (Runtime), from the repo root:

```bash
.venv/bin/ruff check .
.venv/bin/pytest anima_studio/tests
```

For a user-facing workspace change, also launch `swift run AnimaStudio` and
walk the changed flow when the environment permits GUI execution.
