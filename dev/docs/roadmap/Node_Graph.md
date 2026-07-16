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
  graphs are **structured** (reducible to nested sequence / parallel /
  loop / if / select / call). Arbitrary spaghetti edges (goto-style
  jumps) are validation errors with explanations — matching the scene
  format's permanent JMP/LBL omission (`Scene_Format.md`: select +
  call + loops replace jumps; the canvas requires reducibility).

## Node taxonomy

**v1 (compiles to shipped scene actions):**

| Group | Nodes | Compiles to |
|---|---|---|
| Flow | Start, End, Sequence, Parallel (fork/join), Loop (count / while-var), Branch (if/else) | the action tree shape |
| Performance | Clip (name, speed, background, bounded loop), Pose (targets + duration) | `clip:` / `pose:` |
| Timing & gates | Wait (seconds), Wait For Event (name, timeout, on-timeout policy) | `wait:` / `wait_for:` |
| Data | Set Variable, variable/literal value chips on ports | `set:` / `if:` operands |
| Events | Emit Event | `event: {emit}` |

**v2 (compiles to the shipped scene v2 scripting constructs —
`Scene_Format.md` "Execution v2"; conditions are structured data
precisely so every node below is 1:1, no expression parsing):**

| Group | Nodes | Compiles to |
|---|---|---|
| Flow | Select (case rows in document order + optional default lane; first match wins, no fallthrough) | `select:` |
| Flow | Call (a collapsible subgraph reference: one node per call site, double-click opens the shared subroutine graph; the canvas surfaces the loader's recursion-cycle error) | `call:` + top-level `subroutines:` |
| Conditions | Compare (var/input picker + op + value chip), And, Or, Xor (exactly two condition inlets), Not — condition ports are their own data-port type (bool-valued, dashed) and only plug into condition inlets | condition-tree leaves and combinators |
| Timing & gates | Wait Until (condition inlet, timeout, on-timeout policy; level-triggered — badge distinguishes it from Wait For Event's edge trigger) | `wait_until:` |
| Data | Input source chips (read-only pill per declared input, visually distinct from variable chips — inputs are the DI/RI analog, externally driven; no Set node accepts them) | `inputs:` + `input:` condition leaves |
| Interlocks | Background Monitors lane: its own canvas region below the main graph (one row per monitor, declaration order = scan order), each row = condition inlet → a restricted node set (Set Variable, Emit Event, End Scene with its result string). Motion/timing/flow nodes cannot be dropped there — the palette greys them out with the loader's PLC message | `monitors:` (+ the monitor-only `end_scene:`) |

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

The app has a dedicated top-level **Nodes workspace** for scene logic,
with the Show workspace remaining the timeline-first execution and
show-control surface. The Nodes layout is canvas center, node library
left, node inspector right, and synced timeline docked below — selecting
a node will highlight its span on the timeline and vice versa. The same
production-sized surface also appears in UI Dev → Nodes for design-system
review; it is not a separate authoring implementation. Rig/Animate
workspaces are untouched; clips stay timeline-first. Preview runs through the same
evaluated-frame path as everything else; full scene preview in Studio
needs a Swift scene runner or a runtime bridge — **open contract
decision, flagged for Codex planning** (options: port SceneRunner
semantics to Swift with fixture parity, or Studio shells out to the
Python runtime it already ships next to).

### Visual builder / Script builder toggle (Jonathan, 2026-07-15)

The Nodes workspace will present a **two-way toggle** — "Visual builder"
(the node canvas) and "Script builder" (the raw `.scene.anima` YAML
text with syntax highlighting) — over the **same live scene
document**, like the visual/model builder toggles in modern web
tools. Node and script are just two syntaxes for one thing; an edit
in either view reflects in the other because there is only one
document. Explicitly:

1. The toggle is **per-Show-document view state**, not a mode that
   converts anything. Nothing is imported/exported when switching —
   both views render the one scene document.
2. The script view edits the file text directly, with **live parse
   validation**: pathed errors shown inline at the offending line,
   reusing the loader's error paths verbatim
   (`sequence[2].if.then[0].clip`, ...) — one error surface, never a
   second parser.
3. A script edit that produces an **unstructured or invalid graph**
   keeps the script view authoritative: the canvas shows why it
   cannot render (the same reducibility/validation explanations as
   canvas-side errors) and the text is **never destroyed or
   rewritten** to force it back into a graph.
4. Round-trip guarantees come from the **same N1/N2 fixtures** — the
   graph↔scene mapping fixtures are the single truth for both the
   compiler/loader pair and the toggle's equivalence claim.

## Packet sequencing

| # | Packet | Depends on | Lane |
|---|---|---|---|
| N1 | Scene-format `editor:` tolerance (opaque, preserved) + the graph↔scene mapping spec fixtures (YAML pairs: graph JSON ↔ scene tree) | scene v1 (shipped) | Claude (Python + spec) |
| N2 | Graph document model + graph→scene compiler + scene→graph loader in Swift, validated against the N1 fixtures | N1 | Codex (core, no UI) |
| N3 | Promote the UI draft to a document-backed canvas: pan/zoom, authorable typed ports/edges, inspector forms, compiler validation badges, and timeline sync in the top-level Nodes workspace | N2 | Codex |
| N4 | Scene preview in Studio (the Swift-runner-vs-bridge decision) + run controls in Show | N2 | contract decision first |
| N5 | Extension nodes (`scene_action` → node projection) + audio/AI node groups as their runtimes land | E4, B07, B13 | shared |

Cross-lane contract points: the `editor:` block shape, the mapping
fixtures (one truth for both compilers), and the N4 preview decision.
