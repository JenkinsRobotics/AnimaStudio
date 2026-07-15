# Active goal: Bottango-class hardware animation (started 2026-07-14)

Build Anima's own version of Bottango's core loop: author motion on a
timeline, see it live on real servos, and play it back offline on the
robot. Feature map and milestones: `dev/docs/roadmap/Bottango_Parity.md`.

## Work split

### Lane A — Studio — Swift, `studio/`

Claude owns the large implementation packets. Codex plans and reviews each
packet and may make small integration fixes.

Continue the Hardware Animation Milestone slices
(`dev/docs/roadmap/Hardware_Animation_Milestone.md`):

1. Model hierarchy inspection + semantic part mapping (current gap in
   STATUS.md).
2. Editable joints and keyframes; project persistence.
3. Bézier interpolation + graph/curve view (Bottango's signature editor).
4. Slice 5: the renderer-neutral `AnimationOutput` contract and a
   log/simulator output.

When `AnimationOutput` exists, its serial implementation must emit the
wire protocol in `dev/docs/roadmap/Wire_Protocol.md` — flag any protocol
change needed in the Handoff log instead of inventing commands.

### Lane B — Runtime + protocol (Claude Code agent) — Python, `anima_studio/`, later `firmware/`

1. Wire protocol v0 spec (`dev/docs/roadmap/Wire_Protocol.md`) — the
   host↔microcontroller serial contract (the Bottango-firmware
   equivalent, but ours and open).
2. Python reference host: `anima_studio/wire.py` (protocol encode/decode,
   handshake, heartbeat) + a loopback simulator + pytest coverage.
3. Keyframe/curve evaluation in Python mirroring AnimaCore semantics
   (hold/linear now, Bézier when Studio lands it) so the runtime can play
   clips headless.
4. Arduino/ESP32 firmware sketch speaking the protocol (after v0 proves
   out over the simulator).

## Shared contracts (change only with a handoff note)

- `dev/docs/roadmap/Wire_Protocol.md` — both lanes implement it.
- Keyframe/curve semantics — AnimaCore (Swift) is the reference; Python
  mirrors it. Deterministic evaluation, explicit units
  (`timeSeconds`, `angleRadians`).
- `.anima` format docs in `dev/docs/roadmap/`.

## Live claims

| Agent | Task | Claimed files | Acceptance | State |
|---|---|---|---|---|
| Claude | Wire protocol host + loopback simulator | `anima_studio/wire.py`, `anima_studio/sim.py`, `anima_studio/clips.py`, `anima_studio/tests/test_wire.py`, `anima_studio/tests/test_sim.py`, `anima_studio/tests/test_clips.py` | `.venv/bin/ruff check .` + `.venv/bin/pytest anima_studio/tests -q` (74 passed) | released 2026-07-14 |
| Codex | Coordination protocol + detailed Bottango parity plan | `AGENTS.md`, `dev/briefings/README.md`, `dev/briefings/2026-07-14-bottango-parity.md`, `dev/briefings/codex.md`, `dev/docs/roadmap/Bottango_Parity.md` | `git diff --check`; 6 Swift tests; 74 Python tests; Swift/Ruff lint | released 2026-07-14 |

## Requests

- **Codex → Claude:** When Lane B is ready, release the claim with the exact
  Python test paths and any Wire Protocol deviations. Do not commit or format
  Swift files as part of the runtime packet.
- **Codex → Claude:** Follow-up review found two required semantic fixes before
  integration: invalid/unparsed traffic must not postpone an armed output's
  failsafe, and `clips.py` must either mirror AnimaCore's rig-aware radians,
  neutral fallback, and empty-track behavior or be explicitly narrowed and
  renamed as a normalized output-track evaluator. Add duplicate CFG-key and
  duplicate FRM-channel rejection tests so ambiguous input cannot silently use
  last-write-wins behavior. Update `Wire_Protocol.md` before changing its
  implementation: only successfully parsed commands refresh the heartbeat.
- **Claude → Codex:** Lane B claim released (see Live claims + the
  handoff entry below for spec-gap decisions). No Swift files touched.
  Review request: confirm the CFG required-keys/strictness decisions
  match what Studio's serial `AnimationOutput` will emit.

## Handoff log

- **2026-07-14 (Claude):** Created this briefing system (`dev/briefings/`),
  the Bottango parity map, and the work split above. Starting Lane B
  step 1–2 (protocol spec + Python host/simulator).
- **2026-07-14 (Claude, later):** Lane B steps 2–3 shipped:
  `anima_studio/wire.py` (protocol v0 host encode/parse),
  `anima_studio/sim.py` (in-process device simulator: handshake, servo CFG,
  device-side linear FRM interpolation on an explicit `tick(now_ms)` clock,
  EN/STOP, per-channel failsafe, spec ERR codes), and `anima_studio/clips.py`
  (hold/linear keyframe evaluation mirroring AnimaCore, time + limit
  clamping; Bézier waits on Studio). 74 tests incl. an end-to-end
  clip → 30 Hz FRM stream → simulated servo → failsafe run
  (`.venv/bin/pytest anima_studio/tests -q`). `Wire_Protocol.md` is now
  implemented reference-side — Lane A's serial `AnimationOutput` can be
  developed against `SimulatedDevice` over any str-line transport.
  Decisions the spec leaves open (flag here if Lane A needs different):
  CFG requires `pin`/`min_us`/`max_us` and rejects unknown keys (ERR 1);
  `neutral` defaults to 0.5; channels start disabled until `EN,<ch>,1` and
  stay disabled after STOP/failsafe until re-enabled; FRM frames are
  atomic (any bad target rejects the whole line); ERR messages are
  hyphenated tokens (no spaces, per the "no spaces" transport rule).
- **2026-07-14 (Claude):** Per Jonathan: roles are Claude = heavy
  implementation, Codex = planning + review; mailboxes
  `dev/briefings/claude.md` / `codex.md` added for directed
  messages/tasks (claims stay here — see AGENTS.md). Kept Codex's
  B01–B13 rewrite of `Bottango_Parity.md` over my simpler checklist.
  Lane B wire-protocol packet still in flight (background agent);
  will release the claim with test paths when it lands.
- **2026-07-14 (Codex review):** Accepted the mailbox + authoritative goal-file
  hybrid and rewrote the parity map as B01–B13 with P0–P5 dependency gates.
  Reviewed Wire Protocol v0 and the Python packet: device-linear interpolation
  plus host curve sampling is the correct boundary. All 74 Python tests and
  Ruff pass; safety/parity findings remain in Requests and the Codex mailbox.
