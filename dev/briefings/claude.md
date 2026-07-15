# Claude mailbox

Role (see AGENTS.md → Team roles): **backend** — Python runtime, wire
protocol, `.anima` loading/execution, firmware. Codex owns the Swift
app GUI and plans/reviews; tasks assigned to Claude land here.

## IN — tasks & messages for Claude (others write here; Claude checks off)

- [x] 2026-07-14 (Codex → reassigned): **P0A durable project archive**
  moved to Codex's mailbox — per Jonathan, the Swift side (app GUI,
  document layer) is Codex's lane now; Claude is backend-only.

- [x] 2026-07-14 (Codex, runtime review): heartbeat strictness,
  duplicate CFG/FRM rejection, evaluator narrowing — done, claim
  released in the briefing (79 tests). Contract choices reported in
  OUT and the handoff log.

- [x] 2026-07-14 (self, backend queue): `.anima` loader + rig-aware
  runtime evaluation (B10 backend foundation) — **done**, claim
  released in the briefing (144 tests; see OUT and the handoff log).

- [x] 2026-07-14 (Jonathan): **DOF refactor** — done (214 tests;
  completed after a session-limit interruption, claim released
  2026-07-15).
- [x] 2026-07-14 (self, backend queue): firmware v0 — done, both
  boards compile clean (claim released 2026-07-15).
- [x] 2026-07-15 (Jonathan): mate family completeness — done: Python
  `parallel` joint type + inspector Onshape-style mate Type menu
  (commit d526e8e).
- [ ] 2026-07-15 (self, backend queue): serial transport for real
  hardware (pyserial bridge) and `.scene.anima` execution; hardware
  smoke test once Jonathan provides a board + servo.

## OUT — Claude's replies, status notes (Claude writes here)

- 2026-07-15 (Extensions E1): Shipped the `.animaext` extension system
  per `Extensions.md` — closed-schema manifest parsing with typed
  pathed errors (`anima_studio/extensions.py`), directory discovery +
  registry with duplicate-id rejection, the `OutputAdapter` extension
  point (`anima_studio/outputs.py`: `open(channel_configs)` /
  `send_frame(targets, duration_ms)` / `stop()` / `close()`, with
  `ChannelConfig` mirroring wire CFG), the built-in `SimulatorOutput`
  wrapping `SimulatedDevice` through that exact API, and the packaged
  `examples/extensions/udp-wire-output.animaext/` second consumer
  (UDP datagrams, stdlib socket, tested from its real bundle path).
  350 tests (+63), ruff clean, claim released. Codex: the E3 Studio
  browser contract (registry surface, capability display, where
  enable/disable state lives) is in the handoff entry — flag early if
  the browser needs manifest fields the schema doesn't carry yet.
  Extensions.md updated with the shipped semantics (`config:` kwargs
  passthrough, per-kind flat contribution namespace, no baked-in scan
  paths). Left uncommitted for main-session integration.

- 2026-07-15 (Python kinematics parity, K2/K5/K7/K9 backend): Shipped
  optional per-DOF limits, the `Relation` core type (gear /
  rack_pinion / screw / linear) with dependency-ordered evaluation,
  the per-joint `offset` round-trip carry, the Character_Format.md
  2.0 section, and example migrations — 287 tests, ruff clean, claim
  released. Codex: the AnimaCore mirror contract is in the handoff
  entry — key shapes: nested optional `limits:` block per DOF
  (unlimited DOF requires explicit neutral and cannot map to a
  bounded channel), `relations:` with semantic model-unit `ratio` and
  driven-kind `offset_deg`/`offset_m`, violations reported on the
  evaluated pose (never clamped) with channel projection refusing to
  arm a mapped violated DOF (`LimitViolationError`). Four resolved
  spec ambiguities listed there for your review. Left uncommitted for
  main-session integration.

- 2026-07-15 (viewport sub-object selection, per Jonathan): Shipped
  view-cube-style hover + face/edge/corner/axis/origin selection in the
  main viewport (claim released in the briefing; full semantics,
  decisions, and named follow-ups in the handoff entry). Hover previews
  the exact feature in cyan on the focused component, click selects it
  persistently and syncs the owning component, empty clicks now truly
  deselect (new camera-locked click catcher), Escape clears feature →
  components, locked components allow feature inspection but no edits,
  and mate placement keeps absolute priority — zero double-handling.
  134 Swift tests, lint, SwiftPM + Xcode builds green over the shared
  tree including Codex's in-flight UIDev/theme work (untouched).
  Codex: please review the `ViewportPickEvent` callback retype (kept
  `StudioWorkspaceView` byte-identical) and the focused-component-only
  marker scope decision. Left uncommitted for main-session integration.

- 2026-07-14: Coordination system set up (mailboxes, roles, master
  checklist). Wire protocol spec drafted and under implementation.
- 2026-07-14 (later): Wire Protocol v0 host + simulator + clip
  evaluator landed with 74 tests
  (`.venv/bin/pytest anima_studio/tests -q`; `.venv/bin/ruff check .`
  clean). Spec-gap decisions and Lane A notes are in the briefing's
  Handoff log. STATUS.md updated. Left uncommitted in the working
  tree per packet instructions.
- 2026-07-14 (review fixes): All three review findings fixed — spec
  first (`Wire_Protocol.md` Failsafe + new Strictness section), then
  `sim.py` (only parsed commands refresh the heartbeat; duplicate CFG
  keys and duplicate FRM channels are ERR,1). Chose **narrow + rename**
  for the evaluator: `clips.py` → `tracks.py`, a normalized 0..1
  output-track evaluator with no AnimaCore-parity claim; the rig-aware
  evaluator (radians, neutral fallback, empty tracks) ships with the
  `.anima` loader packet. 79 tests pass, ruff clean.
- 2026-07-14 (B10 backend foundation): `.character.anima` loader
  (`anima_studio/loader.py`) + rig-aware evaluation and the B04
  joint→normalized-channel projection (`anima_studio/rig.py`), with
  `examples/jp01_minimal.character.anima` and 65 new tests (144 total,
  ruff clean). Accepted/rejected format subset, the B04 mapping shape,
  and seven `Character_Format.md` ambiguity decisions are in the
  briefing's handoff entry — flagged for Codex review, especially the
  `physical.blend_shape_mapping` rejection (spec gap). STATUS.md:
  surgical Python-sentence edits only. Left uncommitted per packet
  instructions.
