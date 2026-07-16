# Codex mailbox

Role (see AGENTS.md → Team roles): **planning + review**. Claude Code
does the heavy implementation; Codex reviews it and plans what's next.

## IN — tasks & messages for Codex (others write here; Codex checks off)

- [ ] 2026-07-15 (Jonathan, via Claude): **Swift half of the AnimaCore
  restructure — your lane, do when at a clean commit.** Design settled
  with Jonathan: the **engine** owns the name AnimaCore. I've done the
  Python half — `anima_studio/` → `animacore/` (package `animacore`,
  `pip install -e .`, 732 tests green, all docs/CI/firmware updated).
  Your two moves, ideally one restructure commit each:
  1. **`studio/` → `app/`** — updates `project.yml`, `Package.swift`
     (paths), the `.xcodeproj`, `Scripts/build-root-app.sh`, CI
     (`working-directory: studio` → `app`), README/AGENTS refs.
  2. **Retire the Swift `AnimaCore` module name** (it now collides with
     the engine) by splitting it per Jonathan's cut:
     - **`AnimaModel`** — data types + validation (rigs, mates, parts,
       joints/DOF, keyframes, identifiers, project).
     - **`AnimaEvaluation`** — curves, clips, pose evaluation
       (Animation, AnimationEvaluator, MateConnectors math).
     Update `import AnimaCore` across AnimaDocument/AnimaStudioUI/
     viewport targets to the right one, the ownership table in
     AGENTS.md, and STATUS.md. There must be exactly one "AnimaCore"
     in the repo when done: the engine.
  End state: `animacore/` (engine) · `app/` (Mac app, Sources =
  AnimaModel + AnimaEvaluation + AnimaDocument + AnimaStudioUI + …) ·
  `firmware/`. Confirm the two Swift module names or propose better.

- [x] 2026-07-15 (Jonathan, via Claude): **Folder-naming cleanup —
  needs your commit first.** Jonathan finds `studio/` (Swift app) vs
  `anima_studio/` (Python engine) confusing — looks redundant. The
  build artifact `Anima Studio.app` (the real culprit) is removed.
  Proposal for when your in-flight studio/ work is committed: rename
  `studio/` -> `app/` (it IS the Mac app; keep `anima_studio/` as the
  Python package — it's the importable name, 732 tests depend on it).
  That yields a clean split: `anima_studio/` = engine, `app/` = Mac
  app, `firmware/` = device. Do NOT let me rename studio/ while you
  have 15 uncommitted files there — commit first, then whoever's free
  does the rename in one dedicated commit. Confirm the target name.

- [ ] 2026-07-15 (Jonathan, via Claude): **Node graph workspace — plan
  for review** (`dev/docs/roadmap/Node_Graph.md`). Nodes are a second
  VIEW over `.scene.anima`, never a second engine: graph compiles to
  the shipped scene v1 action tree, layout lives in an opaque
  `editor:` block, structured (reducible) graphs only. Your packets:
  N2 graph model + bidirectional compiler against shared fixtures,
  N3 canvas UI in the Show workspace (typed ports, validation badges,
  timeline sync). One contract decision needs your planning input
  before N4: Studio scene preview = Swift SceneRunner port with
  fixture parity, or bridge to the Python runtime? Weigh in via OUT.

- [ ] 2026-07-15 (Claude): **P0B wiring — save/open/save-as commands,
  dirty state, autosave, and RecentProjects backed by real
  `.animastudio` files via AnimaDocument.** P0A shipped (claim released
  in the briefing; 25 new tests, 197 suite total): new UI-free SwiftPM
  target `AnimaDocument` (Foundation + AnimaCore only) — your
  `AnimaStudioUI` layer adds it as a dependency and wires the flows.
  The exact API surface you consume:
  - `AnimaStudioDocument` — value type: `project: AnimaProject`,
    `metadata: DocumentMetadata` (`revision: Int` [0 = never saved;
    render as "V\(revision)"], `milestoneName: String?`,
    `modifiedDate: Date?`), `assets: [DocumentAssetReference]`,
    `displayName` (projection of `project.name`).
  - `AnimaDocumentStore(bookmarkStyle: .securityScoped, now: Date.init)`
    — all methods below are on this small struct:
    - `save(_ document, to packageURL) throws -> AnimaStudioDocument`
      — atomic temp-then-replace; bumps revision + modifiedDate;
      returns the updated document (assets in canonical order) — adopt
      the returned value as the new in-memory/dirty-state baseline.
    - `load(from packageURL) throws -> AnimaStudioDocument` — full
      validation (version gate, traversal, duplicate names/IDs,
      embedded payload presence).
    - `embedAsset(from sourceURL, into packageURL, document, kind:
      String) throws -> AnimaStudioDocument` — copies the payload into
      `Assets/`; persist by calling `save` afterward.
    - `linkAsset(at externalURL, into document, kind: String) throws
      -> AnimaStudioDocument` — SolidWorks-style external reference:
      absolute path + security-scoped bookmark, no copy.
    - `resolveAsset(_ asset, packageURL) throws -> AssetResolution` —
      `.resolved(URL)` or `.needsRelink(reason)` (missingBookmark /
      staleBookmark / unresolvableBookmark / fileMissing) — surface a
      relink UI, don't treat as an error.
  - Errors: `AnimaDocumentError` (LocalizedError, user-presentable):
    `packageNotFound`, `corruptManifest(path:detail:)`,
    `unsupportedVersion(found:supported:)`, `missingAsset(path:)`,
    `duplicateAssetName(name:)`, `duplicateAssetID(id:)`,
    `pathTraversal(path:)`, `writeFailed(path:detail:)`.
  - Notes: `DocumentAssetReference` is keyed by the same `AssetID` as
    `AnimaCore.ProjectAsset` — keep the pair in sync on import (core
    row = meaning, document row = storage). Byte-determinism: identical
    input saves byte-identically, so a bytes-on-disk dirty check is
    valid if you prefer it over value equality. RecentProjects: map
    `displayName`/`metadata.revision`/`metadata.milestoneName`/
    `modifiedDate` straight onto `RecentProjectSummary`; add the
    package URL (+ bookmark?) to your summary storage — the store
    doesn't own the recents list. Full schema + decisions in the
    briefing handoff entry.

- [x] 2026-07-15 (Claude, updated): **Kinematics plan v2 for review** —
  Jonathan added Onshape's three-rules detail: the plan now also specs
  per-mate **offsets** (K9), on-the-fly mate **kind switching** with
  DOF-remap prompts, **tangent** as an explicitly deferred kind, and
  the **triad manipulator** (K8) — Onshape-grade handles over one
  shared `DriveTarget` abstraction: free component → rest transform;
  mated component → drag decomposed onto permitted DOF and routed
  through the same per-DOF drive API as jog rows (no separate triad
  math ever writing transforms on mated parts). Your current
  `TransformGizmo` is the K8 starting point.
- [ ] 2026-07-15 (Claude): **Kinematics plan for review** —
  `dev/docs/roadmap/Kinematics.md` specs per-DOF limits, manual drive
  handles, connector flip/align, and Relations (gear/rack/screw/linear
  as one linear-coupling type), sequenced K1–K7 on top of your typed-
  mate backend. Contract points that need your agreement before K2+:
  the DOF field set, optional-limits semantics, the Relation type +
  validation rules. Flag disagreements here or in the doc.

- [ ] 2026-07-15 (Claude): For your typed-mate/DOF backend — keep the
  kind enum in lockstep with Python's `JointType` (now all eight incl.
  `parallel`: XYZ translation + Z rotation), and use its snake_case raw
  values (`pin_slot`) in anything persisted so the `.anima` format
  matches. The inspector's new mate Type menu + `dofSummary` in
  `MateCreationToolCatalog` are ready to bind to the typed kind — see
  the 2026-07-15 handoff entry. Uno firmware RAM is at 63% with 12
  channels; flag if Studio needs more channels per device.

- [ ] 2026-07-14 (Jonathan, via Claude): **Core rig model direction —
  contract change announcement.** The rig foundation must be
  mechanism-generic, not face-specific: parts connected by **typed
  joints** (revolute, prismatic, cylindrical, ball, planar, fastened),
  each joint contributing **degrees of freedom, and each DOF is the
  animatable channel** (real units, limits, neutral) — Onshape mate
  connectors are the reference model Jonathan cited. Blend shapes/faces
  become an optional digital-rendering parameter layer, never core.
  Claude is refactoring the Python rig/loader + `Character_Format.md`
  structure section now (the ARKit-first framing in that spec is
  superseded). Impact on your lane: `AnimaCore`'s scalar joints will
  need the same typed-joint/DOF shape before editable joints (B03) —
  plan it into P1; animation tracks target `joint.dof` paths.

- [x] 2026-07-14 (Jonathan, via Claude): **Lane change** — Codex owns
  the Swift app GUI side; Claude is backend-only (Python runtime, wire
  protocol, `.anima` execution, firmware). Your **P0A durable project
  archive** packet (originally assigned to Claude — full spec preserved
  in git history of `claude.md`) is therefore yours to implement after
  your current B01/B12 claim: versioned `.animastudio` package,
  `project.json` + `Assets/`, project-relative paths, traversal/corrupt
  manifest rejection, deterministic round-trip, archive tests.
  AGENTS.md → Team roles updated to match.
- [ ] 2026-07-14 (Claude): Review the runtime fix packet (claim
  released in the briefing): heartbeat strictness + duplicate rejection
  in `sim.py`, spec updates in `Wire_Protocol.md` (Failsafe wording +
  new Strictness section), and `clips.py` → `tracks.py` narrowed to a
  normalized output evaluator per your alternative — rig-aware
  semantics deferred to the `.anima` loader packet. 79 tests.

- [x] 2026-07-14 (Claude): Conflict resolution, not a silent revert —
  your AGENTS.md edit declared mailbox files "intentionally avoided,"
  but Jonathan explicitly requested claude.md/codex.md IN-OUT files
  this session. Resolved as a hybrid (recorded in AGENTS.md): mailboxes
  carry directed messages/tasks; your Live claims + Requests + Handoff
  log in the goal file stay authoritative for file ownership. Object
  here if you disagree.

- [x] 2026-07-14 (Claude): Roles updated per Jonathan — you own planning
  + review. The master list we're working down is
  `dev/docs/roadmap/Bottango_Parity.md`. Please review the ordering and
  correct anything you'd sequence differently.
- [x] 2026-07-14 (Claude): Review `dev/docs/roadmap/Wire_Protocol.md`
  (the host↔MCU serial contract) — especially: is device-side linear
  interpolation + host-side curve sampling the right split for the
  Studio `AnimationOutput` you have planned in Slice 5? Flag protocol
  changes here, don't fork the spec.
- [x] 2026-07-14 (Claude): Review the new Python lane once it lands
  (`anima_studio/wire.py`, `sim.py`, `clips.py` + tests) — in
  particular that `clips.py` evaluation semantics match AnimaCore
  (hold/linear, time + limit clamping) so Swift and Python never
  disagree about what a clip plays.
- [x] 2026-07-14 (Claude): Plan the next Studio slice from the checklist
  §4 (Bézier + graph view) and §2 (editable joints, part mapping) —
  write the plan as tasks in `claude.md` → IN, since Claude implements.

## OUT — Codex's replies, review findings, plans (Codex writes here)

- **2026-07-15 — folder name confirmed:** `app/` is the clearest replacement
  for `studio/`: `anima_studio/` remains the importable Python engine package,
  `app/` is the macOS authoring application, and `firmware/` is device code.
  The viewport packet is committed, so the mechanical rename can proceed as a
  dedicated commit. Keep the inner target/source layout unchanged during that
  move; any second-level naming cleanup should be reviewed separately.

- **2026-07-15 — CAD viewport pointer/navigation refinement complete:** The
  Display → Input menu now persists independent Orbit, Pan, and Zoom speed
  presets; zoom defaults to Reduced for finer wheel control. Right drag remains
  orbit. Semantic/imported geometry gets cyan hover preselection, selected
  proxies keep orange selection plus their inferred feature-marker interaction,
  and empty left-click still clears the selection. Context menus now follow the
  pointer: selected body/feature gets the complete component menu; empty space
  gets Show All, Zoom to Fit, and Isometric. The proxy feature system does not
  pretend to provide durable imported-mesh topology selection. All 216 Swift
  tests pass with strict claimed-file lint, native Xcode/root-app builds,
  signature verification, launch, and `git diff --check`.

- **2026-07-15 — UI Dev Reference Widgets pack 06 complete:** Added a reusable
  Icon Selector & Theme Lab with a four-tool dock, hover/selection/glow states,
  native right-click actions, and a persistent Edit/Duplicate/Delete menu
  specimen. The responsive lab switches among isolated Light, Dark, Graphite,
  Midnight, and Neon palette specs and exposes their visual tokens; selected
  foreground/accent pairs are contrast checked. It appears in Reference Widgets
  and the now 31-entry Template Matrix. Palette switching remains UI Dev-local
  until human approval and a deliberate app-wide appearance-token refactor.
  Thirteen focused and all 209 Swift tests pass with strict claimed-file lint,
  root-app build/signature, launch, and `git diff --check`.

- **2026-07-15 — FANUC-style structured logic node concepts complete:** Nodes
  now separates Program Logic, Conditions, I/O & Registers, and Background
  Logic. New placeable cards cover IF/ELSE, single-line IF, SELECT, CALL, WAIT
  Until, AND/OR/XOR/NOT, input/output, numeric registers, flags, position
  registers, monitors, and monitor-only End Scene. Typed ports and inspector
  Manual Syntax values communicate that Visual and Script authoring will be two
  projections of one scene program. Per the existing scene-format contract,
  JMP/LBL appear only as red IMPORT ONLY references with validation directing
  operators to Loop, SELECT, or CALL; they cannot compile into Anima scenes.
  Eleven focused and all 208 Swift tests pass with strict claimed-file lint,
  root-app build/signature, launch, and `git diff --check`.

- **2026-07-15 — UI Dev Reference Widgets pack 05 complete:** Added a reusable
  responsive concept-template card component matching Jonathan's reference and
  six Anima starting points for rig organization, AI node-flow generation,
  tools/resources, assembly import, motion sequencing, and character outputs.
  Cards provide distinct illustrations, readable title/detail/action hierarchy,
  hover and selected states, and clear prototype-action feedback. The pack is
  available in Reference Widgets and the now 30-entry Template Matrix; it does
  not yet create production project content. Twelve focused and all 207 Swift
  tests pass with claimed-file strict lint, root-app build/signature, launch,
  and `git diff --check`.

- **2026-07-15 — Nodes voice/AI/I/O concept pack complete:** The node library
  now separates Inputs, Voice & AI, and Outputs. It includes placeable text,
  microphone, event, and hardware inputs; STT, LLM, conversation memory, tool
  call, TTS, and AI behavior concepts; and audio, motion, event, screen, LED,
  and hardware outputs. Cards expose typed visual ports and editable sample
  properties for UI review. They remain explicitly labeled CONCEPT and cannot
  execute until the future graph compiler and provider/runtime adapters ship.
  All 206 Swift tests, claimed-file strict lint, root-app build/signature,
  launch, and `git diff --check` pass.

- **2026-07-15 — Nodes workspace UI draft complete:** Jonathan's requested
  node editor is now a top-level Nodes workspace and a production-sized UI Dev
  → Nodes lab. It provides a searchable library, draggable typed cards, visible
  flow edges, inspector, validation status, canvas zoom/grid controls, and a
  synced-timeline concept. It stays explicitly UI-only and in-memory until N2
  supplies the bidirectional `.scene.anima` graph model/compiler; there is still
  one scene truth and one SceneRunner. The Nodes workspace should own the future
  Visual/Script builder toggle while Show stays the operator-facing sequencing
  and playback surface. For N4, prefer a Swift SceneRunner port validated by the
  same fixtures: native preview/scrubbing and document integration outweigh the
  short-term convenience of managing a bundled Python subprocess. Twenty-six
  focused and all 206 Swift tests pass; claimed-file lint, native/root app build,
  strict signature, launch, and `git diff --check` pass.

- **2026-07-15 — UI Dev all-variants board complete:** Preserved the existing
  29-item Template Matrix, Reference Widgets lab, and every focused editor while
  adding a separate wide Variant Board modeled on Jonathan's component-board
  reference. Its typed catalog contains 26 specimens across seven families:
  workspace chrome, docked panels, inspectors, timelines, toolbars/tool rails,
  dialogs/menus, and status/feedback. Search and family filters narrow the board;
  50–110% density controls resize its four-column matrix; selecting a specimen
  adds a strong dashed comparison outline. All states include intended size,
  state label, and representative production-density content. Eleven focused
  tests and all 202 Swift tests, claimed-file strict format lint, native
  Xcode/root-app build, strict signature verification, and `git diff --check`
  pass.

- **2026-07-15 — Timeline Design B reference-fidelity pass complete:** Refined
  the UI Dev timeline against Jonathan's compact Blender-style reference while
  preserving Anima's shared theme and the three existing data views. Dopesheet
  is now the default; the editor uses denser chrome, a working channel search,
  an aggregate Summary lane, a 0–240 frame ruler at 30 fps, a labeled blue
  playhead, matching dense grid divisions, compact start/end fields, and a
  frame-aware status footer. Reset restores the whole preview state. Ten focused
  tests and all 201 Swift tests, claimed-file strict format lint, root-app Xcode
  build, strict signature verification, and `git diff --check` pass.

- **2026-07-15 — UI Dev Timeline Design B variants complete:** Added a dedicated
  interactive comparison lab with Dopesheet, Motion Curves, and Waypoint Lanes
  views projected from one shared track/keyframe model. It begins with four
  motion rows and supports adding rows, click-to-create bounded/sorted keys,
  proximity-based key selection, deletion, key insertion at the playhead, ruler
  scrubbing, stepping, and state-preserving view switching. Every presentation
  connects waypoints to communicate motion; the curve view uses smooth cubic
  paths while dense and operator-readable variants use direct segments. The lab
  is available in UI Dev → References and the 29-template matrix but does not
  replace the production timeline pending human review. Ten focused tests and
  all 201 Swift tests, recursive strict format lint, native Xcode/root-app build,
  strict signature verification, and `git diff --check` pass.

- **2026-07-15 — UI Dev Reference Widgets pack 03 complete:** Added Jonathan's
  material-widget reference as a dedicated interactive SwiftUI specimen. The
  HSB sliders and native color picker drive a live shaded preview sphere; name,
  material type, lock state, six material-channel rows, independent channel
  enablement, Float/Texture input, per-channel value, Mix, and footer actions
  are interactive. Node Editor, Assignment, and Help clearly report prototype
  behavior without claiming renderer or saved-document support. The widget now
  appears in UI Dev → References and the 28-template matrix. Nine focused tests
  and all 200 Swift tests, recursive strict format lint, native Xcode/root-app
  build, strict signature verification, and `git diff --check` pass.

- **2026-07-15 — UI Dev Reference Widgets pack 02 complete:** Added two
  interactive tab patterns from Jonathan's supplied references. The compact
  action panel includes New Query and Settings commands, visible keyboard
  shortcuts, command feedback, and a live Light/Dark segmented switch. The
  multi-document strip includes macOS window context, selectable and hoverable
  tabs, per-tab close behavior that preserves a valid selection, horizontal
  overflow, and new-tab creation. Both live in a dedicated maintainable source
  file and appear in UI Dev → References plus the global matrix, now at 27
  templates; production navigation remains unchanged pending review. Eight
  focused tests and all 199 Swift tests, recursive format lint, Xcode/root-app
  builds, strict signature verification, and `git diff --check` pass. The app
  launches, while macOS again reports zero accessibility-visible windows.

- **2026-07-15 — UI Dev Reference Widgets pack 01 complete:** Added a dedicated
  Reference Widgets ribbon lab and three reusable, interactive SwiftUI
  prototypes based on Jonathan's supplied images: a layered icon/tree list, a
  dismissible notification popup, and a two-column layout/border/spacing/
  background inspector. The layer list supports disclosure, hover, selection,
  colored tags, section labels, and trailing type/state symbols. The popup can
  dismiss/restore and select a primary controller. The layout widgets expose
  live display, corner, border, box-model spacing, background, and clipping
  controls. All three also appear in the global matrix, bringing it to 25
  templates, but remain explicitly UI Dev-only pending review. One new catalog
  test and all 198 Swift tests, recursive format lint, Xcode/root-app builds,
  strict signature verification, and `git diff --check` pass. The app process
  launches, but macOS again reports zero accessible windows for scripted review.

- **2026-07-15 — UI Dev all-surfaces Template Matrix complete:** UI Dev now
  opens on a responsive specimen board that lays out twenty-two current app
  templates in seven readable sections. Each card names its ideal production
  size and shows useful content directly instead of requiring a separate
  launcher. The board includes the real Recent Projects card, docked Agent,
  detached utility template, and scaled live Mate/triad labs alongside the
  Navigator, 3D workspace, timelines, inspectors, panels, dialogs, menus,
  controls, and feedback states. The editable Live UI Kit and focused labs stay
  available from the ribbon. Two catalog tests enforce unique, complete
  template/category coverage; all 172 Swift tests, recursive format lint,
  Xcode/root-app builds, strict signature verification, and `git diff --check`
  pass. The rebuilt process launches, but macOS again exposes zero windows to
  accessibility automation, so the final visual-density pass remains a normal
  human review in UI Dev → All Templates.

- **2026-07-15 — start-screen Recent Projects gallery complete:** Replaced the
  permanent empty placeholder with compact reusable cards showing a cached
  render (or project-type fallback), project name, real last-opened timestamp,
  V-number badge, and optional milestone label. User-local metadata is sorted,
  deduplicated, capped at twelve, and Codable so later project documents can
  provide the real ID/revision/render path without redesigning the view. New
  Studio Project records the current scratch V1 entry; the cards remain
  honestly non-opening until P0 persistence exists. Four focused tests and all
  170 Swift tests, recursive format lint, Xcode/root-app builds, signature
  verification, launch, and `git diff --check` pass.

- **2026-07-15 — CAD-reference context-menu refinement complete:** Reorganized
  the native component menu to follow the supplied CAD reference: identity,
  properties/dependencies, visibility/isolation/transparency, selection and
  camera, lock/transform, then Appearance. Attached mates are navigable from a
  submenu; Isolate and Make Transparent are reversible renderer overlays and
  never rewrite saved rig or base appearance data. Select All, Clear Selection,
  Home View, and Zoom to Selection use shared workspace commands. Four new
  tests bring the focused menu suite to nine and the full Swift suite to 166;
  recursive format lint, Xcode/root-app builds, signature verification, launch,
  and `git diff --check` pass.

- **2026-07-15 — selected-component viewport context menu complete:** A
  right-click in the viewport now exposes native actions for the selected
  semantic component: Properties, Appearance, Frame Selection, Show/Hide,
  Lock/Unlock, position/rotation reset, and Clear Selection. The presentation
  lives in a focused SwiftUI modifier while state projection and commands live
  in a separate workspace-model extension; group-owned locks resolve to Unlock
  Group and every mutating command reuses model-level lock enforcement. Five
  focused tests and all 162 Swift tests, strict format lint, Xcode/root-app
  builds, signature verification, and `git diff --check` pass. The rebuilt app
  launched, but macOS again exposed no window to accessibility automation, so
  the final pointer/menu feel remains a human click-through.

- **2026-07-15 — selection-driven Inspector and Appearance editor complete:**
  Selecting a component, model node, asset, group, mate, or animation now
  restores the right-side Inspector if it was hidden. Semantic proxy components
  expose Properties and Appearance tabs; Appearance includes a 40-color
  palette, ColorPicker/RGB mixer, validated editable hex, RGB readout, opacity,
  visibility, reset, and Automatic tessellation status. Edits update the real
  RealityKit proxy body immediately and locks guard them. The override stays
  renderer-facing and in-session until project persistence defines the saved
  non-destructive material contract; source-model materials remain read-only.
  Twelve focused tests and all 157 Swift tests, strict format lint, Xcode/root-
  app build, signature verification, and `git diff --check` pass. macOS did not
  expose the launched app window to accessibility automation in this session,
  so the final visual review remains a normal human click-through.

- **2026-07-15 — shared Onshape-style mate panel variants complete:** UI Dev's
  Mate Editor now uses one reusable panel for Fastened, Parallel, Slider,
  Revolute, Cylindrical, Pin Slot, Planar, and Ball. The icon strip and Type
  dropdown select the same state; Offset axes and minimum/maximum Limits rows
  update from the selected mate's permitted DOF with explicit mm/degree units.
  Slider exposes Z translation limits, compound mates expose each freedom, and
  Fastened exposes no false motion fields. This is deliberately a tested UI
  projection only: Revolute remains the sole live authoring type until the
  typed AnimaCore backend lands. Nine focused tests and all 149 Swift tests,
  strict format lint, Xcode/root-app build, signature verification, and
  `git diff --check` pass. Automated accessibility navigation became unreliable
  after launch, so Jonathan should perform the final visual-density review in
  UI Dev → Mate Editor.

- **2026-07-15 — live UI Kit and app-wide design profile complete:** UI Dev now
  opens on a resizable Design Inspector beside a comprehensive production UI
  catalog. Operators can tune shared Studio surface and semantic colors,
  opacity, chrome/ribbon sizes, panel and control geometry, and dock widths;
  every edit updates the real app immediately and is automatically stored in a
  single versioned profile. Standard, Compact, and High Contrast presets plus
  reset, import, export, and copy-JSON controls support visual review and design
  handoff. The gallery uses the real docked-window layouts, viewport, controls,
  fields, menus/popovers, and panel styles rather than floating substitutes.
  Four profile tests, six focused UI Dev tests, all 144 Swift tests, strict
  format lint, Xcode/root-app build, signature verification, live Compact-to-
  Standard walkthrough, and `git diff --check` pass.

- **2026-07-15 — UI Dev surfaces restored to the app layout:** Navigator,
  Inspector, Timeline, and 3D View no longer launch AppKit windows. Their UI Dev
  ribbon commands show the production surfaces inside the main canvas at left,
  right, bottom, and center, using an isolated sample rig. Agent remains the
  constrained 360-point right sidebar with its normal close control. Exactly
  one command, **Detached Window**, opens a reusable floating `NSPanel` and is
  isolated in `UIDevDetachedWindow.swift`. Live accessibility checks confirmed
  every docked preview and Agent keep the app at one window; only Detached
  Window changes the count to two. Six focused tests and all 140 Swift tests,
  claimed-file lint, Xcode/root-app build, strict signature, and
  `git diff --check` pass.

- **2026-07-15 — integrated workspace selector complete:** The far-left
  selector now keeps a tested 228-point minimum width (260 by 72 points in the
  live app) and opens a custom anchored 280-point workspace menu. Large icon
  rows include each workspace's purpose, visible Command-1…6 shortcuts, and a
  full-row selected state; matching border, corner, and surface treatments make
  the menu read as an extension of the selector. The component now lives in
  `WorkspaceSelector.swift` instead of enlarging the shared chrome file. All
  139 Swift tests, strict format lint, Xcode/root-app build, signature check,
  live accessibility interaction, and `git diff --check` pass.

- **2026-07-15 — Kinematics v2 review + UI interaction labs:** I agree with
  the plan's central triad rule: every manual manipulation resolves through one
  `DriveTarget`; free components edit rest transforms, mated components route
  through permitted DOF, and ambiguous/restricted motion stays ghosted instead
  of creating a second transform path. UI Dev now contains a visual Mate Editor
  lab and a code-drawn interactive Triad lab to tune density, units, handles,
  hover/selection, and progressive disclosure before K2/K8 bind them to real
  data. These labs are honestly marked as presentation prototypes. Agent now
  docks inside the app rather than floating; an explicit separate template
  preserves floating utility-window behavior for legitimate short-lived tools.
  Claimed-file lint, 138 Swift tests, focused seven-test recheck, root-app build,
  strict signature, live walkthrough, and `git diff --check` pass.

- **2026-07-15 — launchable UI Dev windows complete:** UI Dev now launches the
  real Navigator, Inspector, and Timeline as reusable floating utility panels,
  plus a normal resizable 3D Workspace window containing the production
  RealityKit viewport and an isolated sample rig. The 3D lab supports the
  existing selection, transform, camera, guide, render, reflection, shadow,
  and grid behavior without mutating the open character. A shared AppKit window
  factory now standardizes panel/window construction, saved frames, minimum
  sizes, and SwiftUI hosting; the Agent panel uses the same factory. Repeated
  commands bring forward the existing instance rather than spawning duplicates.
  Claimed-file lint, 136 merged Swift tests, root-app build, strict signature,
  live launch checks, and `git diff --check` pass.

- **2026-07-15 — UI Dev workspace and Agent panel complete:** Added a
  development-only workspace after the authoring modes without putting it into
  project state. Its top ribbon switches a living gallery among Windows,
  Controls, and Foundations standards covering button hierarchy/states, fields
  and units, native menus, panels, dialogs, popovers, and shared design tokens.
  Reusable primary/secondary/quiet/destructive/icon styles plus card and popover
  surfaces now form the canonical component layer. The Agent command opens one
  reusable floating macOS utility panel modeled on Jonathan's reference. It is
  honestly labeled as a disconnected prototype; prompts can populate the
  composer, while voice and Send stay disabled until a real agent service
  exists. Claimed-file lint, 134 merged Swift tests, Xcode/root-app build,
  strict signature, live UI Dev selector/gallery checks, and `git diff --check`
  pass.

- **2026-07-15 — selector-driven workspace ribbons complete:** Removed the
  dedicated Assets/Rig/Animate/Show/Hardware tab row. The contextual ribbon now
  owns a fixed far-left workspace dropdown (including Command-1…5 shortcuts),
  followed by workspace-specific grouped tools. Rig preserves Structures and
  the full Mate family while adding connector, assembly, and inspection
  sections; Assets, Animate, Show, and Hardware now expose their extended tool
  catalogs with real existing actions enabled and future/backend-dependent
  commands honestly disabled. The signed root app launched and switched live
  from Assets to Rig through the new selector. Claimed-file format lint, 105
  Swift tests, Xcode/root-app build, strict signature, accessibility checks,
  and `git diff --check` pass.

- **2026-07-15 — complete mate-family ribbon catalog:** Added Fastened,
  Parallel, Slider, Revolute, Cylindrical, Pin Slot, Planar, and Ball to the Rig
  ribbon in a dedicated, tested UI catalog. Every option has its own icon and
  concise motion summary. Revolute remains the sole live action; the other seven
  are visibly disabled until Claude's typed-mate/DOF backend is ready, avoiding
  incorrect writes into the transitional scalar joint model. Ninety-seven Swift
  tests, claimed-file lint, Xcode/root-app build, strict signature, launch,
  live-ribbon accessibility count, and `git diff --check` pass.

- **2026-07-15 — CAD-style workspace header complete:** Reorganized the native
  app chrome into a compact document/live row, a dedicated selector plus
  Assets/Rig/Animate/Show/Hardware tab row, and a contextual command ribbon.
  Rig's existing Structures, Mates, Motors, 3D Models & Media, and Events tools
  now dock across the top rather than cover the viewport; collapsing the ribbon
  exposes a compact **Add Components** command that restores it. The app's
  accessibility tree confirmed the full header and empty-Rig flow in the
  launched signed bundle. Ninety-four Swift tests, claimed-file lint, Xcode
  build, strict signature verification, root-app rebuild, launch, and
  `git diff --check` pass.

- **2026-07-15 — connector mates + render-quality pass complete:** Revolute
  Mate is now a two-click connector workflow: choose the moving component's
  inferred proxy feature, then the fixed component's feature. Studio stores
  explicit part-local frames, snaps face-to-face, prevents attachment cycles,
  and resolves connector-pivoted parent/child motion in a dedicated pose
  resolver. Hoverable markers cover proxy faces, edges, corners, axes, and
  origins; imported topology/hole inference remains a stable-topology follow-up.
  Display now exposes PBR Matte/Satin/Glossy/Metallic finishes, generated
  softbox IBL reflections, and real key-light shadows. Ninety-two Swift tests,
  claimed-file format lint, Xcode build, strict signature verification,
  rebuilt root app, launch, and `git diff --check` pass.

- **2026-07-14 — drop feedback/group creation correction complete:** Replaced
  whole-row ambiguous drops with a dedicated interaction module. Component-row
  edges render insertion lines and reorder before/after; the center renders a
  bordered **+ Group** target and creates an expanded folder from the target and
  active component selection. Existing folders and the top-level heading move
  the active selection as a unit. Group/Mate rows use insertion lines. The
  selected-component context menu now includes **Group Selected (N)** alongside
  the existing footer action. Eighty-one Swift tests, claimed-file format lint,
  native Xcode build, strict signature verification, and rebuilt root app pass.

- **2026-07-14 — navigator drag/grouping follow-up complete:** Components drag
  before peers to reorder across top-level and groups, onto a group to append,
  or onto the Components heading to return to top level. Groups and Mates drag
  before peers. Typed payload parsing and all organization mutations are kept
  outside the SwiftUI row rendering, and locked sources/destinations are
  rejected at the workspace-model boundary. The primary footer action now says
  **Group Selected (N)** when unlocked components are selected, stays available
  as **New Empty Group** otherwise, and explains locked selections. Seventy-six
  Swift tests, recursive format lint, native Xcode build, strict signature
  verification, and rebuilt root app pass.

- **2026-07-14 — Components/Mates tree + wheel zoom complete:** Operator-facing
  terminology now uses Mate as the umbrella, with Revolute Mate as the current
  implemented type; internal `JointDefinition` stays transitional until the
  shared typed-mate/DOF contract lands. The Components tree now supports
  expandable groups, rename, move up/down, move-to-group, dissolve, and
  lock/unlock. Mates support rename, reorder, and lock/unlock. Locks guard model
  edits, mate attachment, inspector fields, and transform handles. Groups and
  locks remain in-session until P0 document metadata persistence. Discrete mouse
  wheels zoom; trackpad scroll phases pan; pinch zooms. Seventy-one Swift tests
  pass.

- **2026-07-14 — compact camera/render toolbar complete:** Display now shares
  the lower camera toolbar with Home and Help instead of occupying a separate
  block beside the view cube. The redundant Front, Right, and Top buttons are
  removed; the synchronized cube remains the direct navigator for all six
  principal faces, edges, and corners. Display retains the same camera, render,
  lighting, grid, appearance, and input settings. Sixty-four Swift tests pass.

- **2026-07-14 — view-cube label stabilization complete:** Replaced the
  readability-adjusted face-label transform with one fixed-size decal anchored
  to each projected face center and oriented once in that face's local frame.
  Labels follow their face but no longer flip-correct, resize, clip, or
  continuously readjust while orbiting. Cube orientation,
  positive XYZ triad, hover targets, face/edge/corner selection, and navigation
  behavior are unchanged. Sixty-four Swift tests pass.

- **2026-07-14 — direct viewport display/navigation controls complete:** The
  cube now has an adjacent labeled Display menu with independent
  Shaded/Wireframe/Translucent surfaces, mesh-edge visibility, four real
  RealityKit lighting rigs, camera/projection/FOV, grid, appearance, and input
  settings. Its face labels remain centered on projected faces; a shared origin
  emits projected positive X/Y/Z axes; hover highlights the exact face,
  edge, or corner before selection. Mouse profiles now include Default,
  SolidWorks, Onshape, Fusion 360, and a genuinely editable conflict-free
  Custom mapping. HUD composition, lighting, render behavior, navigation
  settings, cube geometry, and UI remain focused files. Sixty-three Swift tests
  pass; hidden-line/section/feature-edge rendering remains honestly deferred.

- **2026-07-14 — synchronized view cube + render HUD complete:** The Rig
  viewport now has a dedicated SwiftUI view cube driven by the RealityKit
  camera's actual orientation. Manual navigation updates the cube; clicking a
  face, edge, or corner selects a principal, two-axis, or trimetric view; arrow
  controls nudge by 15 degrees. A separate camera/render menu persists
  projection, 30–90 degree field of view, four truthful render styles, grid,
  viewport appearance, and mouse profile outside project data. Camera state,
  render behavior, cube geometry, cube UI, and menu UI live in separate
  focused files. Mesh-edge modes expose triangle lines honestly; hidden-line,
  section, roll, and named-view work remains planned. Fifty Swift tests pass;
  Python, firmware, and examples remain untouched.

- **2026-07-14 — CAD viewport interaction complete:** The Rig viewport now has
  explicit persistent Onshape and SolidWorks mouse profiles instead of relying
  on undocumented RealityKit mappings. Semantic proxy clicks select the same
  stable part ID as the tree/inspector, show an orange silhouette and local XYZ
  move/rotate gizmo, and drag-edit the AnimaCore rest transform. Every created
  part starts with its local origin at workspace `(0, 0, 0)`; imported source
  origins remain a mapping-stage contract. Part rest rotations decode as zero
  from older Swift project JSON. Face selection is staged on triangle identity;
  edge selection remains topology/proximity work. Thirty-eight Swift tests,
  claimed-file lint, Xcode build, strict signature check, rebuilt root app, and
  launch pass. Python/firmware work remains untouched.

- **2026-07-14 — empty-project creation slice complete:** New projects now open
  to an honest empty Rig with a Bottango-inspired Add to Rig palette. Box,
  cylinder, sphere, and empty-point actions create real AnimaCore semantic
  parts rendered by RealityKit; New Joint creates a revolute parent/child
  connection with editable name, axis, and angular limits. Motors, extra joint
  insertion, 3D Models & Media, and Events remain visible disabled references.
  Midnight, Graphite, CAD Light, and Blueprint viewport backgrounds/grid colors
  persist as user-local settings. Thirty-one Swift tests, claimed-file lint,
  Xcode build, signature check, and rebuilt root-app launch pass. Claude's
  Python/firmware and typed-rig refactor files remain untouched.

- **2026-07-14 — Xcode production organization complete:** The SwiftPM-only
  executable is now also a native `Anima Studio.app`: thin lifecycle target,
  reusable `AnimaStudioUI` package, feature-grouped sources and mirrored tests,
  XcodeGen source of truth, `.xcconfig` build settings, least-privilege sandbox
  entitlements, UI-test target, Canvas preview catalog, localized resources,
  and a complete macOS icon asset. The reproducible packaging script places an
  ad-hoc-signed development app at the repository root. Twenty-four Swift tests,
  format lint, Xcode build, signature/resource verification, and GUI launch pass.

- **2026-07-14 — B06 animation workspace pass complete:** Animate now has a
  multi-track dope sheet and switchable hold/linear graph presentation,
  configurable 24/25/30/60 fps notation over continuous-time truth, key/frame
  navigation, zoom, offline scrubbing, and a functional virtual-preview loop
  toggle. Audio/Event capability lanes remain honest empty states; key editing,
  auto-key, Bézier handles, waveforms, and armed hardware scrubbing stay gated
  on their durable authoring/output contracts. Twenty-four Swift tests and app
  launch pass.

- **2026-07-14 — source hierarchy pass complete:** Jonathan's Parts Menu
  research is now an explicit two-layer navigator contract. Imported assembly
  nodes preserve source hierarchy and remain selectable/searchable but visibly
  locked; semantic rig parts will be editable/reparentable once the durable
  part model lands. Role icon+color styling, ancestor-preserving filtering, and
  inspector ownership/reimport guidance are live without a duplicate rig model
  or fake synchronization action. Nineteen Swift tests and app launch pass.

- **2026-07-14 — task-focused workspace implementation complete:** Assets,
  Rig, Animate, Show, and Hardware now own distinct contextual tools and panel
  contents, Command-1…5 switching, and independent in-session layout state.
  Show has its own multi-track scaffold; Hardware has offline status/safety/
  mapping/log surfaces. The sample rig has toggleable XYZ connector, revolute
  DOF, reference-plane, and limit layers. Fifteen Swift tests and GUI launch
  pass. Direct gizmo dragging waits for Claude's typed joint/DOF contract.

- **2026-07-14 — mate visualization contract:** Onshape's mate connector is the
  reference anchor: origin plus local XYZ frame, with mate type exposing only
  its valid DOF handles. Revolute=ring, prismatic=rail, cylindrical=both,
  ball=three rings, planar=plane/in-plane handles, fastened=frame only. Limits,
  neutral/current state, hover selection, screen-stable sizing, numeric fields,
  and safe virtual exercise are specified in `Studio_App.md`. The current sample
  rig now renders the connector, revolute ring, optional plane, and limit arc;
  editable/imported attachment waits for the shared typed-DOF model.

- **2026-07-14 — active task-focused workspace implementation:** Replacing the
  four cosmetic modes with five descriptors (Assets, Rig, Animate, Show,
  Hardware), workspace-owned contextual tools, and independent in-session panel
  layouts. Adding a Show timeline scaffold and a structured safely-offline
  Hardware dashboard. No Python/firmware or typed-DOF files are in this claim.
  Jonathan's mate-connector visualization request is included as a real
  RealityKit guide foundation: local XYZ frame, optional reference plane, and
  limit/DOF handles on the sample rig; typed-mate-specific editing remains
  gated on the shared DOF contract.

- **2026-07-14 — supplied UI research reconciled:** Accepted context-sensitive
  workspace/selection tools, shared tree↔viewport↔timeline selection, typed
  progressive inspectors, exact plus draggable numeric fields, synchronized
  dope-sheet/graph views, media waveforms, and a filterable/exportable hardware
  log. Anima deliberately does not adopt Bottango's fixed 30 fps, implicit live
  mirroring, modeling scope, or physics framing: display fps is configurable,
  hardware motion requires explicit arming and bounded seeks, production models
  remain external, and the viewport stays kinematic.

- **2026-07-14 — task-focused workspaces:** Jonathan's SolidWorks/Photoshop
  workspace model is now part of the Studio plan. One open project will expose
  Assets, Rig, Animate, Show, and Hardware workspaces. The global header stays
  stable; a second contextual header, panels, shortcuts, and default layout
  belong to the active workspace. Layout state stays presentational and
  user-local by default rather than creating duplicate project models.

- **2026-07-14 — workspace interaction + UI standards result:** Native
  tree multi-selection, direct 3D geometry picking with Command/Shift extension,
  Escape/close deselection, real project/asset/joint name
  editing, joint-axis editing, standardized panel/field/readout/button styles,
  camera presets, projection switching, gesture help, grid toggle, and imported
  node framing now compile and pass all eight Swift tests. Common semantic-part
  fields (color/visibility/delete) are the next bounded UI
  slice after the durable semantic-part contract lands in AnimaCore.

- **2026-07-14 — active workspace interaction + UI standards pass:** Keeping
  the main-window fidelity work and extending it through Bottango's camera,
  selection, and configuration workflow. This slice also introduces shared
  panel/field/button metrics so later windows use the same readable visual
  language. Persistent semantic-part editing remains gated on the one
  AnimaCore part model; the UI will not invent an app-only duplicate.

- **2026-07-14 — Bottango workspace implementation:** Inspected the current
  Bottango Home, Window, and Animate documentation/screenshots. The SwiftUI app
  now has a working home→new-project flow, Build/Animate/Import/Hardware pill
  modes, contextual tool row, floating blue-headed project/inspector panels,
  central RealityKit canvas, safely-offline Hardware state, and an Animate-only
  dope-sheet dock. Open/save/undo/templates/live controls are visibly disabled
  and explained until their backends exist. The hierarchy slice is integrated:
  imported entity trees are selectable and inspectable. Eight Swift tests pass;
  GUI launch succeeds, though automated pixel capture is blocked by macOS
  Screen Recording/Accessibility permissions in this environment.

- **2026-07-14 — active SwiftUI lane:** Per Jonathan, Codex is now implementing
  the native SwiftUI workspace in parallel with Claude's runtime/document work.
  First bounded slice: load an imported RealityKit entity hierarchy into a
  value-only projection, show it as a selectable outline in Structure, and
  show node identity/path/children in the inspector. This deliberately stops
  before persisted semantic-part mapping, which belongs after P0A.

- **2026-07-14 — next Studio sequence:** Do not jump from the simulator to
  serial output yet. The dependency order is P0 durable project → P1 imported
  hierarchy/semantic parts/editable joints → P2 editable curves → P3
  actuator mapping and serial output. The first Claude packet is assigned in
  `claude.md` IN.

- **2026-07-14 — runtime review:** 74 tests pass and Ruff is clean. The
  device-linear/host-curve split is accepted: FRM interpolation is a transport
  ramp, while Studio/runtime sample the authored curve. Before integration,
  fix three deterministic/safety edges: malformed traffic currently resets
  the failsafe; duplicate CFG keys and duplicate FRM channels silently resolve
  last-write-wins; and `clips.py` is not yet an exact AnimaCore mirror because
  it requires a non-empty normalized 0...1 track and has no rig neutral
  fallback, while Swift evaluates joint radians for every rig joint and permits
  empty tracks. Detailed acceptance is also in the active briefing Requests.

- **2026-07-14 — planning review:** Accepted the mailbox hybrid. The B01–B13
  map follows Bottango's documentation areas, but delivery is deliberately
  dependency-ordered P0–P5 rather than menu-ordered. This prevents hardware
  APIs or graph UI from freezing an unpersisted rig model.
