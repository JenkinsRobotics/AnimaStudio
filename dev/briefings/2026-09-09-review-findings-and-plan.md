# Suite review — findings log and fix plan (2026-09-09)

Four-agent review of the uncommitted Aether Suite work (Aether CAD,
`core/`, `studio/`, `animacore/` diff), requested by Jonathan. Every
finding below was verified against the code; items marked **[executed]**
were confirmed by running the module. Baseline at review time: all
suites green — 188 CAD / 81 core-engine / 149 core-ui / 1197 animacore /
39 host tests, all typechecks and builds pass.

**Status: LOGGED, NOT STARTED.** Jonathan's direction: Codex finishes
its in-flight work first; no fixes land until he gives the go-ahead.
Nothing here is claimed yet. Claim rows go into the active briefing
per the normal process when work starts.

---

## A. Blockers — contract-breaking (Claude lane, `animacore/`)

- [ ] **A1. Failed mutations commit anyway.** [executed]
  `animacore/aether_workspace.py:838-851` — `mutate()` swaps the draft
  into canonical state *before* `assembly_id` validation and before
  `mutation_result` projection. A failed `set_dof_value` (unknown
  assembly) returns `ok: false` yet advances revision 7→8; the client
  retry then hits a spurious `revision_conflict`. Violates the
  Assembly-projection contract's atomicity clause.
  Fix: validate fully before swap. Test: invalid-`assembly_id`
  mutation leaves revision and graph hash unchanged.

- [ ] **A2. Diagnostics never surface.** [executed]
  `animacore/aether_workspace.py:556-576` — `_current_issues` adds a
  limit-violation diagnostic only if its ID is NOT in
  `solution["diagnostic_ids"]`, which always contains it (identical
  inputs hash to identical IDs). Result: `projection.issues == []` and
  `preview_mate.diagnostics == []` even with a DOF at 2.0 rad against
  ±1.0 limits, while `diagnostic_ids` dangle. `solve_unconverged`
  diagnostics are never materialized at all.
  Fix: un-invert the filter; materialize solve diagnostics. Tests:
  assert `issues`/`diagnostics` *contents*, not just shape.

## B. High — projection fidelity (Claude lane, `animacore/`)

- [ ] **B1. Dangling BOM `parent_row_id`.** [executed]
  `aether_workspace.py:786-791` — suppressed parent's row is filtered
  out but child rows still reference `instance:<suppressed-id>`.
- [ ] **B2. Instance parent cycles accepted.** [executed]
  `aether_workspace.py:1043-1050` — `_move_instance` checks only
  exists/not-self; an A↔B cycle empties `root_instance_ids` and
  round-trips through save/load (`_build_instance` doesn't check
  either). Fix: acyclicity check on move AND on load.
- [ ] **B3. Unconverged mates project `satisfied`.**
  `aether_workspace.py:531-536` — `solve_state` is only
  suppressed|warning|satisfied; solver `status: "unconverged"` is
  invisible per-mate.
- [ ] **B4. No numeric ground-truth kinematics tests.**
  `instance_world_transforms` (quaternion/frame composition,
  `aether_workspace.py:205-277, 707-732`) is tested only for
  membership/determinism, never correct positions. Add fixed-pose
  numeric assertions. (Repo law: evaluator behavior needs
  deterministic unit tests.)
- [ ] **B5. BOM `material_name` always `None`** despite `material_id`
  existing.

## C. Boundary / robustness — needs cross-lane decisions first

- [ ] **C1. Two mutation channels over one graph type.**
  Bridge verbs enforce `expected_revision` + clone-swap;
  `animacore/aether_project.py:135-136` (`edit_project`, called from
  `core/host/cad_settings.py`) mutates live state, bumps revision with
  no expected-revision check, and raises raw `KeyError` on missing
  keys. No shared locking if both channels touch one file. Decision
  needed (Request row): one concurrency discipline, likely routing the
  host through the same validated mutate path.
- [ ] **C2. Engine imports host assets.** `animacore/cad_document.py:10-12`
  loads `core/assets/cad/units.json` at import time from outside the
  package — layering inversion; also drags display-units/trash
  presentation concerns into the engine. Fix: ship units data inside
  the package or inject it.
- [ ] **C3. `/rpc` drive-by surface.** `animacore/httpbridge.py:53-55`
  sends `Access-Control-Allow-Origin: *` on an unauthenticated bridge
  that can read/write files under `--root` (binds 127.0.0.1, but any
  web page in the browser can call it). Tighten: origin allowlist or
  a boot token shared with the launched app.
- [ ] **C4. Minor:** `bridge.py:1470` reaches into private
  `workspace._ordered`; per-session ordinal `workspace-0001` IDs
  collide across sessions (`aether_workspace.py:319`).
- [ ] **C5. Dual fastened-mate truth.** TS
  `core/engine/src/assembly/transforms.ts:104` (viewport proof) vs
  canonical Python `animacore/mates.py`. Documented as noncanonical,
  but it is a second live representation of mate meaning. Needs a
  retirement plan once the bridge covers the Part-session flow.

## D. `core/host` — security/availability (post-Codex; Python lane)

Posture verified GOOD: salted scrypt, `secrets` tokens hashed at rest,
30-min single-use recovery, HttpOnly/SameSite=Strict, Host+Origin
checks, admin/owner authz with real negative tests, traversal blocked,
127.0.0.1 default with HTTPS forced for non-loopback. Remaining:

- [ ] **D1. Pre-auth slowloris on the global lock.**
  `core/host/server.py:783,805,843` — entire request including body
  read runs inside one `host.lock`; 15 s socket timeout per recv means
  one dribbling client blocks every user. Fix: read body before
  acquiring the lock; bound total request time.
- [ ] **D2. Shared-IP sign-in lockout.** `core/host/state.py:177,202` —
  10 failures lock `ip:` key 15 min; success clears only the user key.
  On a local install everyone is 127.0.0.1 → whole-workspace lockout.
  Fix: clear/scope the IP key (or key on user only for loopback).
- [ ] **D3. Decide: shares expose pre-share history.**
  `core/host/library.py:143-145`, `history.py:88-94` — read actions
  aren't owner-gated, so sharing a file exposes ALL earlier revisions
  including private drafts. If intended, document + pin with a test;
  if not, gate history before the share point.
- [ ] **D4. Nits:** backup download loads whole zip in memory
  (`server.py:899-905`); no CSP header; headers dict can carry only one
  `Set-Cookie` (latent).

## E. Aether CAD app (Codex lane — task already filed in codex.md IN)

- [ ] **E1. God-file split** per CONVENTIONS.md law 3:
  `src/react/AetherCADShell.tsx` (1,939 lines), `src/viewer.ts`
  (1,296), `src/main.ts` (1,136). Mechanical moves, tests stay green.
  *(Filed 2026-09-09 in Codex mailbox IN with suggested seams.)*
- [ ] **E2. Dead code removal** (~250 lines): unreachable profile-dialog
  branch (`feature-authoring.ts:48-50` gates 134-160/212-218/295-313)
  + all of `profile-canvas.ts`; no-op `refresh` at
  `feature-authoring.ts:416`. *(Folded into the E1 task.)*
- [ ] **E3. Package boundary bypass:** `main.ts:2`,
  `sketch-workspace.ts:17,29` import
  `../../core/engine/src/document/solid-features` because
  `core/engine/src/document/index.ts` doesn't export it. One-line fix
  in the core index + repoint imports.
- [ ] **E4. Silent constraint loss on legacy sketch edit:**
  `feature-authoring.ts:443-447` + `sketch-workspace.ts:331-339`
  convert a fully-defined rectangle to an unconstrained polygon on
  Finish. Decide: synthesize equivalent constraints, or warn before
  discarding.
- [ ] **E5. Deterministic IDs:** `mate-state.ts` still uses
  `crypto.randomUUID()` — extraction gate 1 requires an injected
  deterministic ID source.
- [ ] **E6. Doc drift:** `PART_FORMAT.md` documents v2/.cadpart/
  rectangle-only; shipped is v3 `.acpart` with revolve/mirror/fillet/
  multi-body. README "first slice" likewise stale.
  `examples/Wheel-Walkthrough.md`: remove the "right-side rollback
  slider" sentence (no such control; rollback is the draggable tree
  bar). Otherwise the walkthrough is accurate — all 14 features match.
- [ ] **E7. Minor:** base64 helpers in triplicate
  (`cad-assembly-controller.ts:88-100`, `host-library.ts` ×2); raw
  `confirm`/`prompt`/`alert` in destructive flows vs shell dialogs;
  `shapr-shell.css` / "Shapr-style" test names bake a competitor name
  in; `part-evaluator.ts` hardcodes `".acpart"` instead of
  `PART_FILE_EXTENSION`; shim tests duplicate Core coverage.

## F. Repo hygiene — MUST precede the integration commit

- [ ] **F1. Gitignore `Aether CAD/ REFERENCE CAD`** (leading space in
  name; 49.2 MB / 1,238 addable files). Also fixes 222 of 236 ruff
  errors (ruff respects .gitignore).
- [ ] **F2. Handle `examples/Open-LLM-VTuber{,-Unity,-Web}`** — embedded
  git repos; a broad `git add` records broken gitlinks. Ignore them
  (or intentionally add as submodules).
- [ ] **F3. Pytest path for host tests:** plain
  `pytest core/host/tests` fails collection (no repo root on
  `sys.path`); works via `python -m pytest`. Add
  `pythonpath = ["."]` to pyproject `[tool.pytest.ini_options]` (and
  add the path to `testpaths`).
- [ ] **F4. Ruff:** 3× E702 in `core/assets/icons/tools/generate.py`;
  11 pre-existing style errors in `examples/assets/2d/math/*.py` (old
  debt, optional).
- [ ] **F5. Integration commit discipline:** stage explicit paths only
  (per the pause-checkpoint warning); commit Core/CAD extraction
  deliberately, never `git add -A`.

## G. Docs / process

- [ ] **G1. `core/README.md` is stale:** says `host/` is "planned" while
  fully built next to it; table omits `host/`, `session/`, and the
  Swift files in `core/ui/`. Update, and have Jonathan bless (or
  amend) the two-foundations law to cover `core/host` + `core/session`.
- [ ] **G2. Shipped-vs-planned check** of the new roadmap docs after the
  integration commit (STATUS.md gained 1,223 lines; spot-check claims).

---

## Sequencing plan

**Phase 0 — now (done):** findings logged (this file), Codex refactor
task filed, CONVENTIONS.md law 3 added. No code changes.

**Phase 1 — first change window (fast, low-risk):** F1→F4 hygiene,
then the F5 integration commit so five weeks of work stops living
untracked. ~30 min of work; F1/F2 must land BEFORE any broad add.

**Phase 2 — Claude backend packet (claim `animacore/aether_workspace.py`
+ tests):** A1, A2, then B1–B5 with the missing negative/numeric tests.
Each fix ships with the test that would have caught it.

**Phase 3 — cross-lane decisions (Requests in the active briefing,
answers needed from Jonathan/Codex):** C1 single mutation discipline,
C3 /rpc hardening approach, D3 share-history intent, C5 mate-truth
retirement, G1 foundations-law amendment.

**Phase 4 — parallel lanes:** Codex runs E1–E7 (E1/E2 already
assigned); Claude runs D1/D2 + C2/C4 once Codex's host claims are
released.

Ordering rationale: Phase 1 protects the work (it's all uncommitted);
Phase 2 fixes verified contract breaks that invalidate client retry
logic; decisions in Phase 3 unblock the rest without anyone inventing
a cross-lane API silently.

---

# Delta update — 2026-09-09, later session (Codex kept coding)

Re-review after Codex's sketch-parity wave (~322 files touched since the
morning review; core/engine 81→396 tests, CAD 188→340, `src/sketch/`
12→62 modules).

**Verification: all green, claims check out.** 340 CAD / 396 engine /
149 UI / 1197 animacore / 39 host; all typechecks + builds pass.

**Quality verdict on the new wave: excellent — no velocity damage.**
Sampled engine modules contain real math (Levenberg–Marquardt solver
with adaptive damping, exact trim interval topology, correct DXF OCS
handling that rejects non-planar input), numerically pinned tests
(8-decimal coordinate assertions, residuals < 1e-6), zero TODO/FIXME,
zero `any` in engine code, zero React/Three leakage, largest sketch
file 342 lines. App-side sketch modules are thin adapters calling core
operations — no re-implemented meaning. New work fully follows
CONVENTIONS law 3. Minor: compressed single-line formatting in a few
files clashes with prettier style; `dxf-import-panel.ts:194` couples
via a global window custom event (disposed correctly).

**Findings ledger changes:**
- E2 (dead profile code) — STILL PRESENT, refined: the rewrite added a
  projection-editor path but kept the corpse. `feature-authoring.ts:53-61`
  returns unconditionally; dialog fields ~144-171, `mountProfileCanvas`
  call 222-228, submit ~305-322 unreachable; `profile-canvas.ts`
  (230 lines) dead but bundled. ~280 dead lines total.
- E4 (silent legacy-rectangle constraint loss) — STILL PRESENT, now at
  `feature-authoring.ts:452-457` + `sketch-workspace.ts:102-109,384-397`.
- `feature-authoring.ts` (649 lines) is now the single weakest module
  in the app tree — carries E2, E4, and the only `as any` casts in app
  src (lines 68, 298). Recommend Codex's cleanup packet targets this
  file first, before the god-file split.
- A1/A2, B1-B5, C*, D* — unchanged; `animacore/` and `core/host/`
  untouched by this wave.
- F1 — still open: ` REFERENCE CAD` remains unignored (222/236 ruff
  errors).

Plan phases unchanged.
