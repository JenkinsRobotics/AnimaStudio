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
- [x] 2026-07-15 (self, backend queue): serial transport for real
  hardware (pyserial bridge) and `.scene.anima` execution — both done
  (serial released earlier; scene execution v1 released 2026-07-15,
  583 suite total). The hardware smoke test still waits on Jonathan
  providing a board + servo (recipe in the serial handoff entry).

## OUT — Claude's replies, status notes (Claude writes here)

- 2026-07-16 (Relations bridge hook): Surfaced the already-implemented
  relation engine to the UI, **additively** — no existing field/verb
  changed. Added, all in `animacore/rig.py` beside the `Relation` model
  (the mate module does not know relation vocabulary):
  `relation_type_schema` / `all_relation_type_schemas` (static per-kind
  palette catalog, twin of `mate_type_schema` / `all_mate_type_schemas`)
  and `describe_relation` (per-instance descriptor, twin of
  `describe_mate`). `bridge.py` gains the **`relation_types`** verb (in
  `CAPABILITIES`) and a **`relations`** array in the `load_character`
  rig summary. Convention: the engine stores one signed `ratio`; the UI
  shows a positive magnitude + a "reverse direction" checkbox, so
  `describe_relation` reports `reverse = ratio < 0`,
  `magnitude = abs(ratio)`, and a kind-specific `ratio_field_value`
  (unitless for gear/linear; distance-per-revolution in mm =
  `abs(ratio) × 2π × 1000` for rack_pinion/screw). `evaluate_pose` /
  `project_channels` / loader untouched. 901 tests (+15), ruff clean, no
  `app/`/`firmware/` touched. **Codex:** the verbatim `relation_types`
  JSON, gear + rack_pinion `describe_relation` examples, and everything
  needed to build the relations palette + dialog (which mates/DOF are
  selectable per side, the one editable field + reverse checkbox, the
  navigator list from the `relations` array) are in the briefing handoff
  entry. Left uncommitted for main-session integration.

- 2026-07-15 (Width + Tangent — geometry-constraint mates): Added the
  two Onshape mates beyond the 8, **additively** — the 8 kinematic
  mates' behavior and their `mate_types`/`describe_mate` shapes are
  unchanged; only a `category` field and the two new types were added
  (so Codex's in-flight `AnimaCoreClient` decode keeps working). The 8
  are KINEMATIC (engine owns their motion); `width`/`tangent` are
  GEOMETRY-CONSTRAINT (geometry lives app-side, RealityKit) — the engine
  recognizes, round-trips, and catalogs them but does not resolve their
  geometry. `mate_types` now returns **10** schemas, each with
  `category` (`kinematic`|`geometry_constraint`) + `drivable`; the
  geometry pair also carry a `note`. `width` reuses the connector/flip/
  simulation controls (NO offset, NO secondary reorientation) and, once
  the app supplies its two midplane connectors, resolves like a 0-DOF
  fastened at the centered position. `tangent` carries a `tangent`
  block (`selection_a`/`selection_b`/`propagation`, opaque app-side
  surface ids) instead of connectors, and is non-driving/deferred (no
  geometry kernel — `resolve_pose` leaves its child at the parent
  frame, `# ponytail:`). Loader gives typed pathed errors: width rejects
  `offset`/`secondary_axis_rotation_deg`/`dofs`; tangent rejects
  `connectors`/`offset`/`dofs` and requires the `tangent` block. New
  example `examples/geometry_mates_demo.character.anima` loads
  end-to-end. 886 tests (+43), ruff clean, no `app/`/`firmware/`
  touched. **Codex:** the verbatim width + tangent schema JSON, the
  `category`/`drivable` additions to the kinematic schemas, the
  `describe_mate` tangent-block shape, and five decisions are in the
  briefing handoff entry. Left uncommitted for main-session integration.

- 2026-07-15 (BR2 — mate motion resolver / `resolve_pose`): Shipped
  `animacore/kinematics.py` (canonical forward kinematics, stdlib +
  `math` only, no numpy) and the bridge `resolve_pose` verb. Each mate
  now actually MOVES the child part relative to the parent about/along
  the mate connector as the relative origin, per its DOF, chained
  through the rig — superseding the Swift `RigPoseResolver` +
  `MateConnectorMath` (Studio_Bridge migration step 2, engine side
  done). `Transform` = unit quaternion `(x,y,z,w)` (real part last, per
  RealityKit `simd_quatf`) + metre translation;
  `child_in_parent = C_A ∘ ALIGN ∘ Offset ∘ Motion ∘ inverse(C_B)` with
  ALIGN = opposed-Z default (180° about X) unless `flip_primary_axis`,
  plus a `secondary_axis_rotation_deg` twist; connectorless joints put
  motion at the part origin. `resolve_pose(rig, pose)` returns every
  part's world transform (roots at identity). Bridge verb result:
  `{parts:{name:{position:[x,y,z], orientation:[x,y,z,w]}}}`.
  `evaluate_pose`/`project_channels` unchanged. 843 suite total (+27),
  ruff clean, no `app/`/`firmware/` touched. **Codex:** the verbatim
  `resolve_pose` request/response JSON, the full `child_in_parent`
  convention, and four decisions — chief among them that motion uses the
  **canonical connector-frame axis** (so a connectorless revolute
  rotates about part-origin Z; the six-axis-arm example needs per-joint
  connectors authored to articulate realistically — a data task, not a
  code bug) — are in the briefing handoff entry. Left uncommitted for
  main-session integration.

- 2026-07-15 (mate authoring model — universal controls + `mates.py`):
  Shipped the dedicated mate-authoring module `animacore/mates.py`
  unifying Kinematics §4's flip/reorient/offset into one universal
  `MateControls` value shared by all eight mate kinds (only the DOF set
  differs per kind), plus a stable per-mate `id` distinct from the
  editable name. `rig.py` re-exports the moved vocabulary for
  back-compat; `Joint.offset` (`JointOffset`) is replaced by
  `Joint.controls.offset` (`MateOffset`), and `Joint` gains `id`. New
  `.character.anima` joint fields (all optional): `id`,
  `connectors:{a,b}` (part-local frames), `offset:{enabled,
  translation_m, rotate_about, angle_deg}`, `flip_primary_axis`,
  `secondary_axis_rotation_deg` (0/90/180/270), `simulation_connection`.
  Two UI hooks for Codex: bridge verb **`mate_types`** (static per-kind
  catalog — label, DOF slots, universal-controls list) and
  **`describe_mate`** (per-instance descriptor now carried in every
  `load_character` joint summary — id + full controls + DOF paths).
  `evaluate_pose`/`project_channels` unchanged (connectors/offset are
  round-trip-only, no spatial math). 811 tests (+51), ruff clean, no
  `app/`/`firmware/` touched. **Codex:** the verbatim `mate_types` +
  `describe_mate` JSON, the universal-controls list, and five spec
  decisions (native-unit offset in the descriptor, declared-part
  connector validation, non-parallel-axis rule, `controls`
  present/absent rule, `prismatic`→"Slider" label) are in the briefing
  handoff entry. Left uncommitted for main-session integration.

- 2026-07-15 (BR1 — Studio↔AnimaCore bridge engine helper): Shipped
  `animacore/bridge.py`, the long-running stdio helper (`python -m
  animacore.bridge`) that makes AnimaCore the single canonical engine
  and the Swift app a front end — protocol
  `dev/docs/roadmap/Studio_Bridge.md`, BR1 vertical slice: `hello`,
  `load_character`, `validate_character`, `evaluate`, `release`,
  `shutdown`. Protocol logic is a pure `handle_request(session,
  request)` over dicts (format/protocol errors → typed
  `{ok:false,error:{code,message,path}}` envelopes, never a loop
  crash); deterministic monotonic handles (`rig1`, `rig2`, …);
  `evaluate` DOF values proven equal to a direct `evaluate_pose` call.
  28 new tests (`animacore/tests/test_bridge.py`, incl. a `-m`
  subprocess smoke test), 760 suite total, ruff clean, claim released,
  no `studio/` files touched. **Codex:** the verbatim request/response
  JSON for every verb (what your Swift client parses) and five spec
  deviations/decisions — string-keyed `channels`, idempotent
  `release`, DTO field names, unknown-clip→`bad_request`, deferred
  `{path}` variant — are in the briefing handoff entry. Left
  uncommitted for main-session integration.

- 2026-07-15 (AnimaCore restructure, Python half): Per Jonathan, the
  engine owns the name AnimaCore. Renamed `anima_studio/` →
  `animacore/` (package/import `animacore`, distribution `animacore`),
  updated pyproject/CI/firmware comments/all contract+current-truth
  docs; `pip install -e .` and 732 tests green. Swift half (studio/ →
  app/, split AnimaCore → AnimaModel + AnimaEvaluation) speced in
  codex.md — Codex's lane. Dated briefing history left as-is.

- 2026-07-15 (`.scene.anima` execution v1): Shipped headless show
  playback — the B10 offline-playback foundation that outruns a
  tethered export (`anima_studio/scene.py`; 123 new tests, 583 suite
  total, ruff clean, claim released). v1 subset: identity + relative
  `character:` path + scalar `variables:` + a `sequence:` of `clip`
  (speed, background `wait: false`, looping clips require
  `duration_s`), `pose` (lerp from captured start values), `wait`,
  `wait_for` gates (timeout `skip|end`, edge-triggered), `set`/`if`
  (literals + variable copies only), `loop` (count or bool
  `while_var`, zero-time spins are typed errors), deterministic
  `parallel` (timestamp order, ties by track order), and `event`
  emission; `speak`/`expression`/`blend_shapes`/`lights`/
  `ai_response`/`goto` are loud pathed load errors. `SceneRunner`
  mirrors sim.py's explicit-time discipline (`advance(now_s)` +
  `post_event(name)`, no wall clock/threads), streams frames through
  any `OutputAdapter`, reuses the refuse-to-arm limit semantics, and
  reports `finished | ended_by_gate_timeout | stopped` plus an
  emitted-events log. Worked example
  `examples/pick_and_wave.scene.anima` (six-axis arm, visitor logic
  gate) is asserted end-to-end against the simulator on both
  branches. Scene_Format.md restructured shipped-vs-draft
  (Character_Format 2.0 style), Bottango_Parity B10 row and STATUS.md
  updated. Codex: the runner API the Studio Show workspace and the
  JaegerOS action layer consume is in the handoff entry. Left
  uncommitted for main-session integration.

- 2026-07-15 (AnimaDocument P0A): Shipped the versioned `.animastudio`
  document layer as a new UI-free SwiftPM target (Foundation +
  AnimaCore only; Jonathan's SolidWorks-assembly reference: packages
  embed payloads in `Assets/` or link external files via absolute path
  + security-scoped bookmark with an explicit needs-relink resolution
  state). Deterministic manifest encoding (sorted keys, stable asset
  order, byte-identical for identical input), atomic temp-then-replace
  saves, per-save revision counter for the recents V-badge, typed
  user-presentable errors incl. pre-filesystem path-traversal
  rejection. 25 new tests (`studio/Tests/AnimaDocumentTests/`), 197
  Swift suite total, lint + SwiftPM + xcodegen/Xcode app builds green;
  `project.yml` unchanged. Claim released in the briefing; full schema,
  bookmark seam, and two AnimaCore Codable gaps in the handoff entry;
  P0B wiring task with the exact API surface dropped in Codex's IN.
  Left uncommitted for main-session integration.

- 2026-07-15 (Extensions E2 backend): Shipped `parametric_feature` —
  declarative, Onshape-custom-feature-style rig templates
  (`anima_studio/features.py`): pure-data YAML entries (no Python,
  `capabilities: []` suffices), typed parameters (float w/ explicit
  unit hint, int, bool, choice; defaults + ranges), body in exact
  loader shapes with safe `${expr}` arithmetic substitution and
  nestable `repeat:` blocks, instance-name prefixing so instances
  coexist, `$parent` attachment sentinel, and
  `expand_feature`/`merge_fragment` feeding the merged document back
  through the standard loader (never bypassed). Packaged example:
  `examples/extensions/parametric-linkage.animaext/` (N-link revolute
  arm, optional prismatic end slider via a bool repeat count), tested
  end-to-end discover → expand → merge → loader → `evaluate_pose` →
  `project_channels`. 90 new tests (460 suite total), ruff clean,
  claim released. Codex: the E3 form-UI contract
  (`load_parametric_feature` → `FeatureTemplate.parameters` as the
  insertion form, expand-then-merge flow, error `.path` display) is in
  the handoff entry + Extensions.md shipped-semantics note. Left
  uncommitted for main-session integration.

- 2026-07-15 (serial transport, pyserial bridge): Shipped the
  real-hardware half of the "serial transport + `.scene.anima`" queue
  item (claim released in the briefing; `.scene.anima` execution still
  open, so the IN box stays unchecked). `SerialWireOutput`
  (`anima_studio/serial_transport.py`) is the third `OutputAdapter`
  consumer: pyserial `serial_for_url` port, HELLO handshake with
  version check, CFG+EN per channel, OK-checked FRM streaming, typed
  errors (`HandshakeError`/`ReplyTimeoutError`/`ProtocolError`/
  `DeviceRejectedError` with the device's ERR code), idempotent
  best-effort `stop()` that records — never raises — dead-port errors
  during an e-stop, and `close()` ≠ stop per the adapter contract.
  `pyserial>=3.5` added to `pyproject.toml` (install re-verified).
  Tests drive real `loop://` bytes against the reference
  `SimulatedDevice` (20 new; 370 suite total at release, ruff clean).
  Wire_Protocol.md gained a short host reply-timeout guidance note.
  Jonathan: the copy-pasteable first physical smoke test (flash,
  port discovery, one-servo sweep snippet) is in the briefing handoff
  entry. Left uncommitted for main-session integration.

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
