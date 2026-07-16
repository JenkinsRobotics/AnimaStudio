# Node graph authoring (planned)

> A node-based workspace for planning advanced audio-visual animation
> (Jonathan, 2026-07-15; reference: node-canvas tools where scene
> blocks, audio stems, and logic connect on a canvas above a synced
> timeline). Logic nodes, AI nodes, audio nodes — the visual authoring
> surface for shows.

## The one rule: a view, not a second engine

The node graph **authors `.scene.anima`** — it never becomes a second
execution model. A scene's structure (sequence, parallel, loop, if,
wait_for gates, events) already *is* a directed graph; the canvas is
its visual editor, the timeline remains its temporal view, and
`SceneRunner` remains the only executor. Concretely:

- The graph **compiles to** the shipped scene v1 action tree, and a
  scene loads back into a graph. Round-trip is the acceptance test.
- Canvas layout (node positions, sizes, collapsed state, colors) is
  editor-only metadata in an `editor:` block of the scene file. The
  runtime **ignores and preserves** it — never interprets it. (Small
  format change: the Python loader currently rejects unknown top-level
  keys; it will tolerate exactly `editor:` as an opaque round-tripped
  mapping. That is packet N1.)
- Whatever the canvas can express must reject-or-compile cleanly:
  v1 graphs are **structured** (reducible to nested sequence /
  parallel / loop / if). Arbitrary spaghetti edges (goto-style jumps)
  are validation errors with explanations — matching scene v1 having
  no `goto`.

## Node taxonomy

**v1 (compiles to shipped scene actions):**

| Group | Nodes | Compiles to |
|---|---|---|
| Flow | Start, End, Sequence, Parallel (fork/join), Loop (count / while-var), Branch (if/else) | the action tree shape |
| Performance | Clip (name, speed, background, bounded loop), Pose (targets + duration) | `clip:` / `pose:` |
| Timing & gates | Wait (seconds), Wait For Event (name, timeout, on-timeout policy) | `wait:` / `wait_for:` |
| Data | Set Variable, variable/literal value chips on ports | `set:` / `if:` operands |
| Events | Emit Event | `event: {emit}` |

**Later (each gated on its runtime feature, deferred loudly):**

| Group | Nodes | Gated on |
|---|---|---|
| Audio | Audio Clip (file, volume, pan — the screenshot's stems), Sync Marker | scene audio actions (B07) |
| Screens/LEDs | Expression, Light Cue | digital/LED output nodes |
| AI | Prompt/Response, Behavior Select | JaegerAI integration (B13) |
| Community | any `scene_action` extension surfaces as a node automatically — its manifest params become the node's ports/inspector form (same projection E3 uses for parametric features) | E4 |

## Ports & typing

Two port families, visually distinct: **flow ports** (execution order —
white, one-to-one out except Parallel's fork) and **data ports**
(typed: number / bool / string / event name). Edge type mismatches are
live validation errors on the canvas, not compile surprises. Every
node shows a validation badge (the honest-UI convention: a node whose
runtime feature is deferred renders disabled with its motion summary,
exactly like the mate catalog did pre-backend).

## Where it lives in the app

The **Show workspace** gains an Edit/Graph presentation alongside its
timeline (reference layout: canvas center, node inspector right,
synced timeline docked below — selecting a node highlights its span on
the timeline and vice versa). Rig/Animate workspaces are untouched;
clips stay timeline-first. Preview runs through the same
evaluated-frame path as everything else; full scene preview in Studio
needs a Swift scene runner or a runtime bridge — **open contract
decision, flagged for Codex planning** (options: port SceneRunner
semantics to Swift with fixture parity, or Studio shells out to the
Python runtime it already ships next to).

## Packet sequencing

| # | Packet | Depends on | Lane |
|---|---|---|---|
| N1 | Scene-format `editor:` tolerance (opaque, preserved) + the graph↔scene mapping spec fixtures (YAML pairs: graph JSON ↔ scene tree) | scene v1 (shipped) | Claude (Python + spec) |
| N2 | Graph document model + graph→scene compiler + scene→graph loader in Swift, validated against the N1 fixtures | N1 | Codex (core, no UI) |
| N3 | Canvas UI: pan/zoom canvas, node palette, typed ports/edges, inspector forms, validation badges, timeline sync | N2 | Codex |
| N4 | Scene preview in Studio (the Swift-runner-vs-bridge decision) + run controls in Show | N2 | contract decision first |
| N5 | Extension nodes (`scene_action` → node projection) + audio/AI node groups as their runtimes land | E4, B07, B13 | shared |

Cross-lane contract points: the `editor:` block shape, the mapping
fixtures (one truth for both compilers), and the N4 preview decision.
