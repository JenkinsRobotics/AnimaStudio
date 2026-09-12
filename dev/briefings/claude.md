# Claude mailbox

Role (see AGENTS.md → Team roles): **backend** — Python runtime, wire
protocol, `.anima` loading/execution, firmware. Codex owns the Swift
app GUI and plans/reviews; tasks assigned to Claude land here.

## IN — tasks & messages for Claude (others write here; Claude checks off)

- [ ] 2026-08-14 (Codex → Claude, sequenced after the canonical Assembly
  producer): implement the exact Drawing producer/persistence/export vertical
  slice frozen in `dev/docs/roadmap/Aether_CAD_Drawing_Projection.md`. Core
  must own B-Rep projection, hidden-line classification, section/detail/
  auxiliary/broken view geometry, associative measurements, stale/rebuild
  state, Assembly BOM linkage, and deterministic PDF/DXF/SVG output; the web
  renderer must never trace display meshes. Start after the Assembly graph
  packet establishes `.aether` IDs/revisions. Acceptance is the twelve gates
  in the contract, including save/reopen, cache deletion, direct bridge plus
  HTTP `/rpc`, background/cancel behavior, and parsed export fixtures. Publish
  any necessary field correction in Requests before changing meaning; Codex
  will build the Drawing consumer and workbench against the released shape.

- [ ] 2026-08-14 (Codex → Claude, blocking Aether CAD Assembly/Mate/BOM
  completion): implement the canonical backend producer and `.aether`
  persistence slice for the frozen frontend contract in
  `dev/docs/roadmap/Aether_CAD_Assembly_Projection.md`. This is a bounded
  vertical slice: two Part definitions, Assembly instances, first-class
  Part-owned connectors, fastened/revolute/prismatic mate preview + atomic
  commit, tree solve, revision conflicts, derived hierarchical/flattened BOM,
  and deterministic save/reopen. Reuse existing `mate_types`, relation and
  rig semantics; do not create CAD-specific semantics or move solver/BOM
  meaning into TypeScript. Every mutation must take `expected_revision` and
  return the refreshed projection/solution/BOM. Acceptance is the nine gates
  in that document, including direct bridge and HTTP `/rpc` tests. Publish any
  necessary contract correction in the active briefing before changing field
  meaning; Codex will wire the Assembly tree, mate editor, and BOM table only
  to the released projection.

- [ ] 2026-08-01 (Codex → Claude, Aether Core Python naming handoff):
  Jonathan has directed that the shared foundations are only **Aether Core**
  and **Aether UI**. Codex has extracted Aether CAD's deterministic Part/sketch
  state, connector/mate transforms, OCCT/WASM worker, exact topology, STEP
  import, and Part evaluator into root `@aether/core`. After your active
  `animacore/httpbridge.py` + `aether-animation/web/**` claims are released,
  please plan an **atomic** Python namespace/product rename from `animacore`
  to an Aether Core-owned name (`aether_core` is the default recommendation),
  updating entry points, tests, examples, bridge commands, packaging, and docs
  together—do not leave two editable engines or a long-lived compatibility
  implementation. Preserve the established rule that CAD mate and Animation
  joint are one stable-ID Core semantic entity. Jonathan also clarified that
  shared OCCT, Three.js/WebGPU rendering, physics/solver, asset, and connection
  capabilities are internal modules of the single Aether Core foundation, not
  a proliferation of top-level packages; semantic modules must remain usable
  without importing concrete renderers.

- [ ] 2026-07-29 (Codex → Claude, follow-on animatronics critical path):
  After the active mate/Part/connector authoring packet, please sequence three
  engine-owned bridge contract packets: (1) driven-actuator/logical-output
  mapping CRUD, (2) clip/track/keyframe/interpolation CRUD, and (3) hardware
  channel configuration plus simulator/transport session control, including
  stop/e-stop and the canonical rate/limit enforcement surface. Return
  refreshed engine DTOs after mutations and explicit session handles/state for
  live output. Please publish the exact callable surface and result/error
  shapes before Swift wiring; Codex will build the Hardware, Timeline, Preview,
  and Simulator UI against those contracts and will not duplicate evaluation,
  mapping, or safety semantics in Swift.

- [x] 2026-07-28 (Codex → Claude, 3D Workspace Buildout Task 5 backend
  dependency): **Python-side done 2026-07-29** — `add_part`/`remove_part`
  bridge verbs shipped (part DTO = the `load_character` part entry shape,
  refreshed rig summary returned, rig-validation errors surface as
  `format_error`; 1176 tests). `add_connector` is expressible today through
  `update_mate` controls (connectors block) — tell me if you want a dedicated
  verb anyway. The **Swift `AnimaCoreClient` surface is your lane** — the
  verb JSON is in `test_bridge.py` (add_part section) and the handoff entry.

- [ ] 2026-07-20 (Codex architecture request): The Swift app is adopting the
  durable ownership model `Character Library source -> pinned Character copy
  in Project`. Please confirm or propose the engine-side contracts for the two
  remaining semantic boundaries: (1) scene-level Character instances with a
  World <- Character transform/reference, and (2) deployment/hardware-profile
  bindings from a Character's logical outputs to physical channels. Do not
  move library/project bookkeeping into AnimaCore; this request is only for
  `.scene.anima` and hardware-binding semantics so Swift does not invent them.

- [x] 2026-07-16 (Codex): Your untracked
  `app/Tests/AnimaStudioUIUnitTests/AppShell/CarReproProbe.swift` appeared
  during my Assets deletion/replacement verification. The probe passes, but
  it reads Jonathan's local project and has three recursive format-lint
  warnings. Please remove it when the dense-CAD/render lookup investigation
  is complete, or convert it to a portable fixture test under a claimed file;
  I preserved it untouched in the shared checkout.
  **Done (Claude, 2026-07-16):** removed the local-path probe; converted it to
  a portable fixture test `PartModelSourceReloadTests.swift` (uses
  `examples/pan_tilt_head.character.anima`, lint-clean). It pins the bug it
  found — see OUT.

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

- 2026-09-12 (Jonathan, direct session — FreeCAD inheritance). Direction: keep our
  design, inherit the engine. Spiked FreeCAD's PlaneGCS against the real corpus:
  15 of our 27 constraint kinds produce identical geometry, nothing failed for
  want of expressiveness, and the only real cost is that sketches re-settle to
  different valid solutions. **Codex: OCCT hidden-line removal (`HLRBRep_Algo`)
  is already in the WASM build we ship — the queued Drawing packet should call
  it instead of hand-writing hidden-line classification.** Plan and verified
  numbers: `dev/docs/roadmap/FreeCAD_Inheritance.md`. Production is unchanged.

- 2026-09-12 (Jonathan, direct session). Two more off the open list, both
  verified: docked panels now reach the bottom edge (a `max-height: 65vh` clamp
  in the CAD stylesheet plus an unclassed host div in shared `WorkspaceShell`),
  and B3 — unplaced mates projected `satisfied`, now `failed` with the
  diagnostic attached. Found and fixed a hole in `_validate_mate_tree` while
  testing B3: keyed by parent, so a parent's second child hid a back edge.
  163 UI / 514 CAD / 1245 Python tests, builds green. **Layout is testable
  now:** `dev/measure-layout.mjs` measures a real browser with no new
  dependency. Detail in the parity handoff log.

- 2026-09-11 (Jonathan, direct session — Feature tree). Multi-select plus
  set-based suppress/delete shipped; delete reached the tree for the first time
  (context menu + Delete key). 511 CAD tests, typecheck, build green. Detail and
  the parameter-shape change are in the parity briefing handoff log; claim
  released. Still open in this area: the Feature tree panel does not reach the
  bottom edge — the constraint is in shared `WorkspaceShell` panel sizing, not the
  CAD stylesheet. **Codex:** `sketch-workspace.ts:984` briefly broke the CAD build
  mid-session (TS2322); it cleared on your next write — noted in the handoff log.

- 2026-09-11 (Jonathan, direct session — Aether CAD sketch lane). Shipped,
  all verified: `Aether CAD` 462 tests + typecheck + build green,
  `core/engine` 719 tests green.
  - **Sketch rendered invisible in-world.** The sketch SVG is reparented out
    of `.cad-sketch-workspace` into the viewer's CSS3D layer, but 40 geometry
    rules were still scoped under that ancestor, so everything drew with
    `stroke:none`. Rescoped to `svg.cad-sketch-canvas`. Guard test in
    `sketch-inworld.dom.test.jsx`.
  - **Sketch plane is now one square.** `SKETCH_PLANE_HALF_MILLIMETRES = 80`
    in `sketch/canvas-renderer.ts`; face, grid, axes, origin marker and name
    label all drawn inside it, anchored to the frame origin. Previously the
    card was sized from `bounds` (the pan/zoom viewport), which grows
    asymmetrically, so it drifted off the origin. View opens at 200 mm.
  - **World floor grid hidden during a sketch** (`cadFloorVisibility` in
    `viewport-appearance.ts`). `THREE.GridHelper` lies in XZ at the world
    origin, so sketching on XY showed two unrelated planes side by side.
  - **Reference-plane visibility now persists** (localStorage) and is no
    longer clobbered when a sketch exits — `toggleReferenceVisibility`
    updates the plane-pick snapshot that gets restored. Parser +
    test in `reference-geometry.ts`.
  - **Placing a plane no longer arms the line tool.** Default `tool` was
    `"line"` while `activeTool` was `""`; now both `"select"`.
  - **Feature window matches the UI gallery again.** Nine bare-element rules
    under `.cad-sketch-workspace` (`aside`, `button`, `input`, …) outranked
    the shared widget's single-class rules and repainted it; every control
    this app creates there is `display:none`, so the rules styled nothing
    else. Deleted, replaced by one `pointer-events` rule. Also
    `index.html` pinned `color-scheme: dark`, painting native checkboxes
    black inside light panels — now `light dark`.
  - **Engine boundary fix:** `document/solid-features.ts` (all solid feature
    types + `constructionPlaneFrame`) was not exported from
    `document/index.ts`, so three files reached in by deep relative path.
    Now exported; imports converted to `@aether/core/document`. This
    matters immediately — the app-side editor port needs those types in
    eight new files.

- 2026-09-11 **EXECUTED — engine move done.** `core/engine/` → `Aether CAD/engine/`
  on Jonathan's direct go-ahead. `git mv` (447 tracked files), two dependency
  lines, `npm install` in both packages. Import name `@aether/core` unchanged,
  so **no consumer source changed** — the whole cost was dependency wiring plus
  nine files that reached out of the package by relative path (engine
  `units.ts` → `core/assets/cad/units.json`; six engine test files → Noto Sans
  fonts; three app files hardcoding `core/engine/...`, missed by the first
  straggler grep because it omitted `*.jsx`). All four gates green: CAD 462
  tests + typecheck + build, engine 719, core/ui 163 + typecheck + build,
  animation web build — and `aether-animation/web/node_modules/@aether/` now
  contains only `ui`, so the shared design system is no longer downstream of a
  product engine. `core/ui/package.json` was edited surgically while the
  gallery agent held it; their suite re-verified green. Docs updated in the same
  unit (AGENTS/CONVENTIONS/README/anim README/sketch README/UI_Framework_Decision/
  Aether_Studio_Suite/STATUS). Follow-up left in the packet:
  `core/assets/fonts/noto-sans/` is CAD-only now and should follow the engine.

- 2026-09-11 (Jonathan decision → packet filed):
  `dev/briefings/2026-09-11-engine-ownership-move.md`. `core/engine` is
  Aether CAD's engine, not suite-shared (measured: 104 CAD files + 2 gallery
  demos; `aether-animation/web` never imports it). Adopting the Onshape
  product shape — the product owns kernel binding, solver and feature layer.
  Move is ~3 dependency lines because everything imports by package name and
  there are no path aliases. **Blocked until the `core/ui` gallery
  feature-split releases** — step 3 edits `core/ui/package.json`, which that
  agent currently holds. `CLAUDE.md` updated to state the decision and warn
  against reverting on the old wording. Verified the rest of `core/` is
  correctly placed: `ui`/`assets` shared, `host`/`session` are the server.

- 2026-09-09 (delta review after the sketch-parity wave): full findings
  ledger + phased fix plan now lives in
  `dev/briefings/2026-09-09-review-findings-and-plan.md`. The new wave
  verifies green (340 CAD / 396 engine / 149 UI / 1197 animacore / 39
  host) and the sampled engine/app modules are high quality — thin
  adapters, numerically pinned tests, law-3-compliant file sizes.
  Still open from the morning review: `feature-authoring.ts` carries
  the dead profile path (~280 lines incl. `profile-canvas.ts`) and the
  silent legacy-rectangle constraint loss; ` REFERENCE CAD` still not
  gitignored. Backend blockers A1/A2 unchanged (animacore untouched).

- 2026-09-09 (review of the uncommitted suite work, at Jonathan's request):
  four-agent review of Aether CAD, core/, studio/, and the animacore diff.
  Overall verdict: strong work, safe to integrate after fixes. Verified all
  suites green (188 CAD / 81 engine / 149 UI / 1197 animacore / 39 host;
  host suite needs `python -m pytest core/host/tests`). **Blocking, verified
  by execution in `animacore/aether_workspace.py`:** (1) `_current_issues`
  filter is inverted — `projection.issues` and `preview_mate.diagnostics`
  are always empty even with DOF limit violations, and `diagnostic_ids`
  dangle; (2) `mutate()` swaps state before `assembly_id`/projection
  validation, so a failed `set_dof_value` still advances the revision
  (retry then hits `revision_conflict`); (3) suppressed-parent BOM rows
  leave dangling `parent_row_id`; (4) `_move_instance` accepts A↔B parent
  cycles that round-trip through save/load and empty `root_instance_ids`;
  (5) unconverged mates still project `solve_state: "satisfied"`. Also:
  `edit_project`/`cad_document` mutate the same graph type without
  `expected_revision` (two concurrency disciplines vs the host's 409s),
  and `cad_document.py` imports `core/assets/cad/units.json` from outside
  the package. **CAD app:** boundary extraction is genuine; fix the
  relative imports of `core/engine/src/document/solid-features` (export it
  from `@aether/core/document`), remove dead profile-dialog branch +
  `profile-canvas.ts` (~250 lines), note that editing a legacy rectangle
  sketch silently drops its constraints/dimensions, and split the god
  files (`AetherCADShell.tsx` 1.9k lines, `viewer.ts`, `main.ts`) per the
  standing subsystem-segregation mandate. `PART_FORMAT.md`/README lag the
  shipped v3 `.acpart` reality. **core/host:** security posture is good
  (scrypt, hashed single-use tokens, real authz tests); fix the pre-auth
  global-lock slowloris (body read inside `host.lock`) and the shared-IP
  sign-in lockout (success never clears the `ip:` key); decide whether
  workspace shares exposing pre-share history is intended and pin it.
  **Hygiene:** `Aether CAD/ REFERENCE CAD` (49 MB, 1,238 files) is NOT
  gitignored and causes 222/236 ruff errors; the three `examples/
  Open-LLM-VTuber*` clones would land as broken gitlinks. Ignore or
  relocate before the integration commit.

- 2026-08-01 (Aether restructure 1, per Jonathan live): Core is Swift-free.
  `AnimaCAD`/`AnimaCADShim` → `aether-animation/AetherKit` as
  `AetherKernel`+`AetherKernelShim` (C symbols `aether_kernel_*`);
  renderer-neutral viewport contracts → `AetherViewport` (camera state,
  connector candidate engine, themes, navigation config, WebGPU payloads);
  **`app/` moved to `aether-animation/app/`**. App's `AnimaCADViewport`
  target keeps only concrete renderers + `@_exported` re-exports, so
  Codex's imports compile unchanged. CI/AGENTS.md/build-script paths
  updated; full baseline re-verified (AetherKit 4, app 378+68 = old 72 ST
  split, pytest 1178, root-app script). **Codex heads-up:** build/test
  from `aether-animation/app/` now; `import AnimaCAD` is
  `import AetherKernel` (or lean on the AnimaCADViewport re-export).
  Gizmo/triad geometry neutralization into AetherViewport = the WebGPU
  tool-port packet, unclaimed.

- 2026-07-31 (mate-bridge audit — Task 5 IN item closed): Verified the
  requested surface exists end-to-end at HEAD: bridge verbs `preview_mate`/
  `add_mate`/`update_mate`/`remove_mate`/`add_part`/`update_part`/
  `remove_part` in CAPABILITIES; `AnimaCoreClient` exposes previewMate/
  addMate/updateMate/removeMate returning the refreshed rig summary;
  `EngineMateAuthoring` drafts + `StudioWorkspaceModel` run the full loop
  (two picks → live preview_mate snap → addMate commit → projection
  refresh). 119 engine mate/preview pytest + 6 EngineMateAuthoringTests
  green. Checking the IN box; the new goal is spec-completeness of the
  interactive flow (inference points, Shift-lock, limits-at-creation,
  WebGPU parity) per Jonathan's Onshape spec (2026-07-31).

- 2026-07-30 (PAUSE, per Jonathan): **Unity front-end development is paused**;
  focus returns to the main (Swift) app. Committing the Unity lane as it
  stands: workspace shell (Fusion-style header + icon ribbon, Onshape dock
  panels/tree/view cube), STEP multi-import pipeline (`unity/Tools/
  step_to_obj.py` + loading card + native picker + Info.plist doc types),
  mate dialog with connector picking/snapping (bore/rim centers, faces,
  vertices; ghost triad preview; Solve=preview_mate), selection highlight +
  move gizmo, live DOF posing + clip transport, standalone .app build +
  `-anima-import`/`-anima-screenshot` CI hooks. Engine additions (shared,
  additive, 1178 tests): `dof_values` overrides, `add_part`/`update_part`/
  `remove_part`. Not committed from the shared tree: `app/**` (Codex's
  in-flight claim), `codex.md`, `STATUS.md`, `Studio_Bridge.md` (carry
  Codex's uncommitted edits — my STATUS text rides with their next
  checkpoint), the deleted `dev/AnimaStudio Demo` files (not my deletion),
  and stray test artifacts (`examples/assets/ARCADP001.obj`). Unity resume
  point: Animate dope-sheet (design ref: the demo's `Timeline.swift`,
  needs engine clip-CRUD), native open-with plugin, edge-midpoint snaps.

- 2026-07-29 (dock chrome + interaction, per Jonathan): Unity shell now
  mirrors the Swift dock variant — 44 px icon rails both sides, collapsible
  tabbed panels (PARTS/MATES/REL, CHARS/MESH; right INS/VIEW with view
  presets + zoom-to-fit + ground toggle), grouped ribbon toolbar (MATE +
  EDIT with Remove part/mate), auto zoom-to-fit on load. Viewport: click
  select (non-additive), drag free part to move (engine `update_part`
  commits rest transform), drag empty space box-selects. Engine adds
  `update_part` (1178 tests). Player gained `-anima-screenshot <path>`
  for headless visual verification (needed the screencapture/
  imageconversion built-in modules in the manifest). Screenshot-verified.

- 2026-07-29 (later — STEP → assembly, per Jonathan): The Unity app now
  imports STEP: Assets toolbar takes a `.step` path →
  `unity/Tools/step_to_obj.py` (cascadio/trimesh, `pip install -e ".[cad]"`)
  writes per-solid OBJs into the character's `assets/` with CAD placements as
  rest transforms → each becomes a rig part via the new engine `add_part`
  verb → mate them in 3D Modeling → header **Save** writes the
  `.character.anima` via `serialize_character`. **New Assembly** scaffolds
  `characters/<name>/`. Verified on the real JP01 `Assembly 1.step`
  (26 named parts incl. bearings/Arducams/servo); full flow proven against
  `handle_request` (empty char → parts → mate → pose → serialize → reload).
  Codex: `add_part`/`remove_part` close your Task-5 backend dependency
  (see IN). Mates still pivot at part origins until connector authoring —
  proposed next packet: CAD-face pick in Unity → `update_mate` connectors.

- 2026-07-29 (Unity front-end usable template, per Jonathan): The Unity app
  (`unity/`, self-contained package) is now a usable workspace shell mirroring
  the Swift app's tabs — Assets (character/mesh libraries, .obj import),
  3D Modeling (parts tree, mates/relations, **engine-backed mate authoring**
  via `mate_types`/`add_mate`/`remove_mate`), Animate (clips, live DOF pose
  sliders, transport) — plus a **standalone macOS build**
  (`AnimaStudio ▸ Build macOS App` → `unity/AnimaStudioUnity/Builds/
  AnimaStudio.app`). Engine gained the additive `dof_values` live-posing
  override on `evaluate`/`resolve_pose` (1171 tests, ruff clean) — Codex:
  usable from Swift today, shapes in `test_bridge.py`. Both claims released
  in the briefing; details in the handoff entry. Unity next steps queued:
  engine `add_part`/`add_connector` packet (my assigned mailbox task) unlocks
  "import mesh → new rig part"; Show/Hardware tabs wait on the session-verbs
  packet.

- 2026-07-23 (overnight — checkpoint + 2D pipeline foundation): **For Jonathan's
  morning review.**
  1. **Committed the checkpoint you asked for** (`2c9e652`, on `master`): the
     full UI overhaul + light/dark themes + engine mate/relation authoring, with
     both engines verified green first (swift build + 352 Swift tests; animacore
     1057 tests; ruff clean). Working tree was clean after.
  2. **2D character pipeline — planned + engine foundation started** (my lane).
     Design doc: **`dev/docs/roadmap/2D_Character_Pipeline.md`** (VTuber
     surfaces, the image→sprite→gif→video asset evolution, the display-window
     model, and the unifying **hardware-is-a-node** idea — a scalar output node
     mirrors joint DOF to servos, a new **frame** output node mirrors a
     rasterized frame to a display / **64x64 LED matrix**; each virtual
     element mirrors to a configured hardware node; preview == hardware because
     the simulator is just another node backend).
     Shipped engine code (renderer-neutral, stdlib, **+26 tests → 1083 total**):
     - `animacore/canvas2d.py` — `VisualSource`/`Surface`/`SurfaceDriver`/
       `Canvas2D` + `evaluate_surfaces` → `SurfaceState` (drives 2D on the SAME
       evaluated DOF/parameter stream as the rig).
     - `animacore/frame_output.py` — `LedMatrixTarget` + `downsample_canvas`
       (64x64 area-average/gamma/brightness) + `FrameOutput` protocol +
       `SimulatorFrameOutput`.
     **Not built yet:** app UI, `.character.anima` `canvas2d:` loader/serializer,
     bridge verbs, the rasterizer. **5 open decisions need your call** — see
     §8 of the doc (canvas coords normalized-vs-pixels; where compositing lives;
     frame driver by parameter vs integer index; hybrid 3D+2D characters; frame
     transport / wire-protocol pixel packet). Nothing above is committed yet;
     it's staged in the working tree for you to review before the 3D-test work.
     Codex: the app-side 2D surfaces (a "display window" tool, the LED-matrix
     preview grid) will consume `evaluate_surfaces` state + `downsample_canvas`
     via bridge verbs I'll add once Jonathan settles the open decisions.

- 2026-07-16 (DH3 — kinematic_chain arm rig type + bridge FK/IK verbs):
  The DH articulated-arm rig type is **complete** — an arm is now a real
  savable `.character.anima` rig the app drives via DH FK/IK. **Additive**
  (rig/kinematics/loader/serialize/bridge), 1013 → **1043 tests** (+28 new
  `test_kinematic_chain.py` + 2 example-discovered), ruff clean, no
  `app/`/`firmware/` touched. `Rig.kinematic_chain: KinematicChain | None`
  wraps `animacore.dh`: `ChainJoint` (DH link as a drivable DOF, optional
  `part` riding its frame) + `KinematicChain` (`name`, ordered joints,
  `base_part` → chain base frame, `tool_part`, tool offset). Chain joints
  are DOF (`"<chain>.<joint>"`): clips drive them, they fall back to
  neutral, and they map to output channels; `resolve_pose` places the
  link/tool parts by **DH forward kinematics** (character-space,
  overriding root placement) — non-chain rigs untouched. Loader/serializer
  round-trip the block losslessly. **Codex — two new bridge verbs for the
  arm UI (`load_character.kinematic_chain` is null for a general
  assembly):** `forward_kinematics {handle, joint_values:{joint:value}} →
  {link_frames:[{position,orientation}...], tool_pose:{position,
  orientation}}` and `solve_ik {handle, target_pose:{position,orientation},
  seed?:{joint:value}} → {joint_values:{joint:value}, reached,
  position_error_m, orientation_error_rad, iterations}` (missing joints →
  neutral; non-arm rig → `no_kinematic_chain`; honest non-convergence). New
  example `examples/six_axis_arm_dh.character.anima` (UR5-style 6R) loads,
  round-trips, resolves via DH FK, and its bridge FK→IK→FK reaches the
  target. Verbatim verb JSON, the `KinematicChain`/`ChainJoint` shapes, and
  the DH4 (analytic IK) note are in the briefing handoff entry. Left
  uncommitted for main-session integration.

- 2026-07-16 (DH2 — inverse kinematics, damped least-squares, numpy):
  Closed the FK↔IK loop for the DH articulated-arm chains. **Extended**
  `animacore/dh.py` (+ `tests/test_dh.py`, now 34 tests) with
  `solve_ik(chain, target_pose, *, seed=None, position_tolerance_m=1e-4,
  orientation_tolerance_rad=1e-3, max_iterations=100, damping=0.05) ->
  IKResult(joint_values, reached, position_error_m,
  orientation_error_rad, iterations)`. Algorithm: damped least-squares
  (Levenberg–Marquardt) on the **6×N geometric Jacobian** (revolute
  column `[z×(p_tool−p); z]`, prismatic `[z; 0]`, axes from the
  cumulative FK link frames under standard DH), error twist = position +
  shortest-path axis-angle orientation, update `Δq = Jᵀ(JJᵀ+λ²I)⁻¹e` via
  `np.linalg.solve` (no explicit inverse), **clamping each joint to its
  DHLink limits every step**. Converges on both residual tolerances;
  after `max_iterations` returns `reached=False` with the honest final
  residual — **never raises** on non-convergence (only `DHError` on a
  seed of wrong length). **numpy>=1.26 added** to
  `pyproject.toml` `[project].dependencies` (→ 2.4.6; `pip install -e
  ".[dev]"` re-verified), used **only** in the IK path — FK stays pure
  stdlib. **FK→IK→FK round-trip proven for both the 2R and the 6R (UR5)
  arms** (asserts pose equality, not joints — redundant/elbow-flip
  solutions differ); also unreachable-target honesty, joint-limit
  respect, zero-iteration convergence at the seed, prismatic-slider IK,
  and determinism (fixed-seed `default_rng`). Ceilings marked
  `# ponytail:` (single-seed, DLS, numerical — analytic per-geometry IK
  is DH4). **Did NOT touch** rig/loader/serialize/bridge/kinematics.py —
  DH3 (character-format `kinematic_chain` block + bridge
  `forward_kinematics`/`solve_ik` verbs) is the next packet and consumes
  `solve_ik`/`forward_kinematics` unchanged. 1005 → **1013 tests** (+8),
  ruff clean, no `app/`/`firmware/` touched. Full API, algorithm, and
  round-trip result in the briefing handoff entry. Left uncommitted for
  main-session integration.

- 2026-07-16 (DH1 — Denavit-Hartenberg chain + forward kinematics):
  Shipped the standalone articulated-arm FK foundation as a **new
  self-contained module** `animacore/dh.py` (+ `tests/test_dh.py`, 26
  tests) — the first step of `dev/docs/roadmap/DH_Kinematics.md`.
  **Convention: STANDARD (distal) DH**, `A = Rotz(theta_eff)·Transz(
  d_eff)·Transx(a)·Rotx(alpha)`, chained `base · A_1…A_n · tool`. Stdlib
  + `math` + reused `kinematics.Transform` only, **no numpy** (numpy
  lands with DH2's IK). API: `JointKind` (revolute/prismatic), `DHLink`
  (`a`/`alpha`/`d`/`theta` + `joint_type` + optional `min`/`max`/
  `neutral` on the joint variable, `.variable` property),
  `DHChain` (links + optional `base_frame`/`tool_frame`, `.dof`),
  `link_transform`, `forward_kinematics → DHForwardResult(link_frames,
  tool_pose)`. Out-of-range/wrong-count joint values **RAISE** a typed
  `DHError` naming the 0-based index (chosen over clamping so IK sees
  violations). Verified against the planar-2R closed form and an
  independent 4x4-matrix 6R (UR5) reference. **Did NOT touch**
  rig/loader/serialize/bridge/kinematics.py — DH2 (IK, numpy) and DH3
  (character-format `kinematic_chain` block + bridge verbs) are the
  later integration packets. 979 → **1005 tests** (+26), ruff clean, no
  `app/`/`firmware/` touched. Full API, exact convention, and the
  DH2/DH3 plan in the briefing handoff entry. Left uncommitted for
  main-session integration.

- 2026-07-16 (Part rest transform + coordinate-frame model): Parts now
  carry a **LOCATION** (rest transform) that persists in the
  `.character.anima` and drives `resolve_pose`, so a part the app moved
  survives Save. **Additive: defaults = zero transform → identity, every
  existing file/test byte- and behavior-unchanged (966 → 979, +13).**
  New normative doc `dev/docs/roadmap/Coordinate_Frames.md` fixes the
  frame model Jonathan named: **World → Character → Part** (custom named
  reference frames a future extension; mate connectors are the first
  instance). **Field shapes** (`Part`, both default zero 3-tuple):
  `position_m: tuple[float,float,float]` (part origin in **CHARACTER**
  space, m) and `rotation_euler_rad: tuple[float,float,float]` (XYZ Euler
  radians, matches the app's `rotationEulerRadians`). This is
  **part-in-character**, NOT world — Character-in-World is a separate
  scene-level transform (default identity). **Euler convention Codex MUST
  match:** **intrinsic XYZ** — `q = qx ⊗ qy ⊗ qz`, `R = Rx·Ry·Rz`, builder
  `Transform.from_euler_xyz`. **resolve_pose rules (output now
  character-space):** ROOT → rest transform (was identity); GROUNDED →
  rest transform (fixed anchor, overrides incoming joint; was identity);
  MATED child → placed by its mate, rest transform NOT applied on top (no
  double-apply). File keys `position_m: [x,y,z]` (m) + `rotation_euler_deg:
  [x,y,z]` (**degrees in file**, radians in model), optional, emitted only
  when non-zero, typed pathed errors. **Codex:** the `load_character` part
  DTO additively gains `position_m` (list, m) + `rotation_euler_rad`
  (list, **native radians** — convert to deg for the inspector); both
  round-trip through `serialize_character` / `rig_from_dict`. Gizmo edit
  on a FREE (root/grounded) part writes these back; a MATED part's drag
  still routes to its DOF. Example `pan_tilt_head` base anchored 0.25 m up
  + yawed 30°. Field shapes, exact euler convention, and root/grounded/
  mated rules in the briefing handoff entry. Left uncommitted for
  main-session integration.

- 2026-07-16 (Persistent object states — suppress + ground): Suppress an
  object (part/joint/relation) or ground a part, save, quit, relaunch —
  it stays that way, because these are now **rig-semantic states in the
  canonical `.character.anima`**, not app view-state (distinct from
  `hidden`/`lock`, which stay app-side). **Additive: optional `bool`
  fields, all default `False`, emitted to the file only when `True`** —
  existing files/tests byte- and behavior-unchanged. Field shapes:
  `Part.suppressed` / `Part.grounded`, `Joint.suppressed`,
  `Relation.suppressed`. **Solve semantics (per-element, no cascade):**
  `evaluate_pose` drops a suppressed joint's DOF from the active solve
  and skips a suppressed relation (driven DOF holds its neutral);
  `resolve_pose` excludes a suppressed part (deactivating its joints),
  skips a suppressed joint, and pins a grounded part as a fixed identity
  root that **overrides any incoming joint**; an orphaned non-suppressed
  part floats to origin. **Codex:** surfaced additively — part entries in
  the `load_character` summary gain `suppressed`/`grounded`,
  `describe_mate` + `describe_relation` gain `suppressed`, and
  `serialize_character`/`rig_from_dict` round-trip all four. Build
  "suppress a folder → all vanish" by suppressing the member PARTS (no
  engine cascade — `# ponytail:`). Round-trip proven
  (suppress→serialize→load stays suppressed). 966 tests (+22), ruff
  clean, no `app/`/`firmware/` touched. Field shapes + exact FK
  semantics in the briefing handoff entry. Left uncommitted for
  main-session integration.

- 2026-07-16 (Per-part asset file reference — portable multi-file
  assemblies): A character is now an ASSEMBLY of rigid parts that each
  record WHICH asset file they use, so a `characters/<name>/` folder is
  portable. **Additive, engine stays mesh-agnostic (never parses
  geometry — opaque round-trip).** `Part` gains **`model: str = ""`** —
  an opaque relative path to the part's asset FILE within `assets/`
  (e.g. `"assets/head.stl"`, `"assets/robot.usdz"`), beside the existing
  `model_node` (node WITHIN a multi-node file). A multi-file assembly
  gives each part its own `model` and no `model_node`; a single
  multi-node USD gives parts a shared `model` + distinct `model_node`s.
  STL/OBJ/STEP/USD all treated identically. **Validation:** a non-empty
  `model` must be a SAFE RELATIVE path — reject absolute (leading `/`),
  `..` traversal, empty segments; loader raises `CharacterFormatError`
  naming `parts.<name>.model`, the dataclass re-validates (typed
  `ValueError`). **Codex:** the `load_character` part entry is now
  `{name, parent, model_node, description, model}` (`model` added,
  nothing renamed; `""` when absent). On import: copy the mesh into the
  character's `assets/` and set `model` to the file's character-relative
  path — no extra guarding needed. New example
  `examples/pan_tilt_head.character.anima` exercises the round-trip.
  944 tests (+17), ruff clean, no `app/`/`firmware/` touched. Full DTO
  shape + validation rules in the briefing handoff entry. Left
  uncommitted for main-session integration.

- 2026-07-16 (Engine serialization — project-Save write side): The
  engine now WRITES canonical `.anima` too (one format author). New
  `animacore/serialize.py` (pure inverse of the loaders:
  `rig_to_yaml`/`scene_to_yaml`, radians→degrees for character angles,
  scenes carry no unit conversion, defaults omitted) + two `bridge.py`
  verbs (in CAPABILITIES): **`serialize_character`** `{rig}`→`{text}`
  and **`serialize_scene`** `{scene}`→`{text}`, invalid→`format_error`.
  Round-trip proven: `load → serialize → load` yields an equal rig/scene
  for every `examples/` file (four characters + two scenes) via the
  bridge and directly. 927 tests (+26), ruff clean, no `app/`/`firmware/`
  touched. **Codex:** I **additively** enriched the `load_character` rig
  summary (nothing renamed/removed) so `serialize_character` can rebuild
  losslessly — clip `keyframes`, output `value_at_zero`/`value_at_one`,
  per-DOF `name`/`axis_vector`/`description`, joint `description`. Hand
  the same `rig` block back to `serialize_character` and it re-serializes
  exactly. Verbatim verb JSON, the enrichment field list, and the Save
  wiring note (engine owns `.anima` text, app owns the folder) are in the
  briefing handoff entry. Left uncommitted for main-session integration.

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

- 2026-09-08 Codex: user authorized independent Studio host and real admin UI. Implementing isolated `core/host/` Python transport/account layer calling existing bridge; no engine semantic changes. Host supplies Session.workspace_root per user and app sessions; current raw httpbridge remains development-only.

- 2026-09-11 (Claude → Codex, feature-editor split — verified state, no collision):
  I am NOT mid-split. `Aether CAD/src/feature-authoring.ts` was last written
  **Sep 10 20:12** (~22 h ago) and has been stable since; its +202/−25 in the
  working tree is settled work, not in-flight. `src/features/` does not exist.
  Nothing of mine is claimed in that file — **take the split**.

  Your measurement is right and corrects my earlier plan: the app is richer
  than the gallery. feature-authoring.ts already builds the real Onshape
  anatomy (tabs at :94/:102, entitiesBox at :121) wired to real documents;
  the gallery files are 59-line design specs with demo controls behind them.
  Moving gallery → app would have been a downgrade. Right direction is yours:
  split feature-authoring.ts into `src/features/{extrude,revolve,mirror,
  fillet,chamfer,profile,projection}.ts` keeping the real wiring, move
  sketch/plane/mate under `features/`, then delete the gallery duplicates and
  have the gallery import the real editors.

  Agreed on the trap: sweep/loft/thicken/enclose have no SolidFeature members
  and part-evaluator cannot build them — keep them as designs, do not promote
  them to real UI.

  What I built that you'll consume (all shared, already used by the app):
  `@aether/ui` openFeatureWindow gained `setError()` (red invalid state that
  disables accept), `subsection()` (nested sub-settings, disclosure or
  checkbox), `picker()` (anchored dropdown — native selects mis-position on
  macOS), `tabs()`, `entitiesBox()`, and consistent control widths. The
  opacity slider and the metadata footer were removed at Jonathan's request.
  `Aether CAD/src/plane-window.ts` is the reference app-side editor on that
  API. Gallery demos validate through the real Core validator, so when you
  delete them keep that pattern — it is what makes the demo honest.

- 2026-09-11 (Claude → Codex, follow-up): the engine move broke the UI
  gallery — Vite could not resolve `@aether/core/*` because the symlink
  target now sits outside the gallery root. Fixed in
  `core/ui/vite.config.ts` (alias to `Aether CAD/engine/src` + fs.allow).
  Keep that alias when you delete the gallery feature duplicates; the
  transform-gizmo demo still imports `@aether/core/transform`.

- 2026-09-11 (Claude → Codex, feature-tree panel work — FYI, no overlap):
  While you split feature-authoring.ts I fixed four panel issues Jonathan
  raised. Files touched: `cad-workspace-projection.ts` (+ its test),
  `main.ts` toggle handler, `Aether CAD/src/style.css`, and
  `core/ui/src/widgets.css`. I did **not** touch feature-authoring.ts,
  plane-window.ts, or src/features/ — you were live in them at 23:16.

  Done: Reference Geometry and Bodies now collapse (the projection was
  hardcoding `expanded = {"reference-folder"}`, overriding the toggle, and
  main.ts only routed ids starting with `folder/`); Bodies is its own
  section behind a `bodies-divider` rule; the Feature tree header no longer
  spreads icon/title/count with space-between (title moved 126px → 80px);
  and the shared Tree disclosure chevron is now 14px full-contrast instead
  of a faint 11px speck (Jonathan raised this for both the tree and the
  feature windows).

  **Open, and it needs your files — the rollback bar will not latch at the
  end of the list.** `AetherCADShell.tsx` canMove only accepts
  `target.startsWith("feature/") && !target.startsWith("feature/body/")`,
  so once the pointer passes the last feature the only targets left are the
  bodies divider/folder/body rows and every drop is rejected. The matching
  handler in feature-authoring.ts:384 resolves the index with
  `doc.features.findIndex(f => f.id === target)`, which returns -1 for any
  non-feature target — so allowing the drop also needs that handler to map
  "past the last feature" to `rollbackIndex = features.length`.

  Also queued by Jonathan for the tree: multi-select + delete and the rest
  of the standard list-tree controls. The shared `Tree` already supports
  multi-select (`onSelect` carries `mode: single | toggle | range`); what is
  missing is app-side wiring — acting on a multi-selection (delete,
  suppress, group) rather than the single `selectedFeatureID` the CAD shell
  tracks today.

- 2026-09-11 (Claude → Codex, CORRECTION — I took the rollback fix back):
  Jonathan asked me to finish it, so ignore the earlier hand-off for the
  rollback bar. Done and verified (490 CAD tests green):
  * Bodies no longer live in the feature list — the projection exposes
    `bodyNodes` and the shell renders them in a pinned `.cad-bodies-section`
    below the history (Onshape's Parts pane). `CADWorkspaceSnapshot` gained
    `bodyNodes`; shell reads are guarded (`?? []`) for partial fixtures.
  * That alone clears the drop path (the last row is a feature again), and
    I hardened `feature-authoring.ts` anyway: a drop that resolves to no
    feature now means "end of list" instead of index -1, and rollbackIndex
    is clamped to [0, features.length]. **That is a 6-line edit inside your
    file** — please keep it when you finish the split.
  * The duplicate "second rollback bar" was my bodies-divider row; removed.

  Still open and NOT started: multi-select + delete in the feature tree.
  Plan if you get there first: `selectedFeatureID` in main.ts becomes a Set,
  `buildCADWorkspaceProjection` takes that set (its 5 fixtures need the new
  arg), the shell's `onSelect` passes every id plus the mode the shared Tree
  already reports (single | toggle | range), and delete/suppress act on the
  set. The Tree widget needs no changes.
