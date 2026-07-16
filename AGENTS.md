# Anima Studio contributor contract

This repository is building an open animation, motion-authoring, and show-control
system for digital characters and physical audio-animatronic robots. The first
product milestone is hardware animation authoring: import an existing model,
define its movable structure, animate it on a timeline, preview it, and later
route the same evaluated motion to hardware.

This file is the shared briefing for every agent working the repo —
Claude Code reads it as `CLAUDE.md` (a symlink to this file), Codex
reads it as `AGENTS.md`. Edit this one file only.

Two channels, two jobs (per Jonathan, 2026-07-14 — resolving an earlier
conflict between agent edits):

- **Mailboxes** `dev/briefings/claude.md` / `dev/briefings/codex.md` —
  directed messages and task assignment (IN = others write, owner
  checks off; OUT = owner's replies/findings). Jonathan drops tasks
  here too.
- **The active goal file** in `dev/briefings/` — Live claims (file
  ownership), Requests (blocking cross-lane questions), Handoff log
  (session summaries). File ownership never lives in mailboxes.

## Team roles

The current goal is Bottango-level capability, working straight down
[`dev/docs/roadmap/Bottango_Parity.md`](dev/docs/roadmap/Bottango_Parity.md).

- **Claude Code — backend** (per Jonathan, 2026-07-14, superseding the
  earlier all-implementation split): the Python runtime
  (`anima_core/`), the wire protocol and its simulator, `.anima`
  loading/execution, and the microcontroller firmware
  (`firmware/`, when it exists).
- **Codex — Swift app GUI** (`studio/`), plus planning + review across
  both lanes: reviews commits/diffs, sequences the next checklist
  slices, assigns tasks.
- Planning is teamwork — either agent may propose; disagreements get a
  mailbox note, not a silent revert.

Agents communicate indirectly through mailboxes in `dev/briefings/`:
[`claude.md`](dev/briefings/claude.md) and
[`codex.md`](dev/briefings/codex.md). Each has **IN** (others write
tasks/messages there; the owner checks them off) and **OUT** (the owner
writes replies, findings, plans). **Every session: read your mailbox
IN before working, write your OUT before stopping.**

## Read before changing code

1. [`CONVENTIONS.md`](CONVENTIONS.md)
2. [`dev/docs/reality/STATUS.md`](dev/docs/reality/STATUS.md)
3. Your mailbox and the active briefing in
   [`dev/briefings/`](dev/briefings/README.md) — current goal, task
   assignments, claims, and the handoff log you append to after each
   session.
4. [`dev/docs/roadmap/Hardware_Animation_Milestone.md`](dev/docs/roadmap/Hardware_Animation_Milestone.md)
5. [`dev/docs/roadmap/Studio_App.md`](dev/docs/roadmap/Studio_App.md)
6. The format document affected by the change:
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
| `AnimaDocument` | versioned project-package encoding, migrations, project-relative asset storage and resolution | SwiftUI views, RealityKit, timeline evaluation, hardware SDKs |
| `AnimaViewport` | renderer-neutral preview contracts | concrete renderer behavior |
| `RealityKitViewport` | model loading/display, camera, selection, joint gizmos | persisted format semantics, hardware mapping |
| `AnimaStudioUI` | workspace state and reusable SwiftUI views, commands, panels, presentation logic | app signing/resources, duplicate evaluator logic |
| `AnimaStudioApp` | thin macOS lifecycle target, app resources, entitlements, app-only document/file integration | reusable workspace views, evaluator logic |

Add a new target only when it represents a proven dependency boundary. Do not
create speculative plugin packages.

## Working agreements for parallel contributors

- **Read `git status` before every claim and before every commit.** An untracked
  or modified file may be another agent's in-flight work.
- Claim a bounded task and its file globs in the active briefing before editing.
  Only one active claim may cover a file at a time.
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
- Stage explicit paths only. Never use `git add -A`, `git add .`, or commit an
  unclaimed file while another claim is active.
- Never stash, clean, reset, checkout, rebase, or run a repo-wide formatter in
  the shared checkout while another agent has an active claim.
- Run formatters only over files in the current claim.
- A generic role does not override the active lane split. By default Claude
  takes large implementation packets; Codex leads architecture, review,
  integration, and targeted implementation. The active briefing assigns the
  concrete files and acceptance test for each packet.

## Cross-agent communication

Mailboxes carry directed tasks and replies. The active briefing is the
authoritative coordination ledger for the shared checkout:

1. Add a row to **Live claims** before editing.
2. Put questions that block another lane in **Requests** with the contract or
   decision needed; do not silently invent a cross-lane API.
3. Append a concise **Handoff log** entry after verifying the work.
4. Mark the claim `released` only after listing changed files and test results.
5. The receiving/reviewing agent records its review result in the same log.

Commits are integration checkpoints, not the communication channel by
themselves. A commit without a handoff entry is incomplete multi-agent work.

## Verification

Swift package (Studio), from `studio/`:

```bash
swift format lint --recursive App AppUITests Sources Tests Package.swift
swift test
```

Native Xcode app, from `studio/`:

```bash
xcodegen generate
xcodebuild -project AnimaStudio.xcodeproj -scheme AnimaStudio \
  -derivedDataPath /tmp/AnimaStudioDerived CODE_SIGNING_ALLOWED=NO build
./Scripts/build-root-app.sh
```

Python (Runtime), from the repo root:

```bash
.venv/bin/ruff check .
.venv/bin/pytest anima_core/tests
```

For a user-facing workspace change, also launch the native app target (or the
root `Anima Studio.app`) and walk the changed flow when the environment permits
GUI execution.
