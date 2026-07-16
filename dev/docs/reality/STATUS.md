# STATUS

> Truthful, or it's worthless. Any commit that changes behavior updates
> this file in the same commit — see `CONVENTIONS.md` → "STATUS stays
> truthful."

## Current state — 2026-07-15

- **Repo:** `AnimaStudio` — open-source unified character animation
  system for AI robots (digital avatars + physical animatronics from
  one rig, one format, one authoring tool)
- **Version:** 0.1.0 (see `anima_studio/__init__.py`)
- **JaegerOS pin:** not yet set — for now the runtime is standalone and
  Jaegers read `.anima` files natively; the `jaeger-os` dependency and
  `animation`-slot module land later (see `dev/docs/roadmap/`)
- **What works:** the native macOS foundation under `studio/` builds both as a
  Swift package and as a real `Anima Studio.app`. The checked-in Xcode project
  is reproducibly generated from `project.yml`, with a thin native lifecycle
  target over the reusable `AnimaStudioUI` package, shared Debug/Release
  `.xcconfig` settings, least-privilege sandbox entitlements, localized-resource
  support, an asset-catalog app icon, a launch-level UI-test target, and Xcode
  Canvas previews for the home, complete workspace, and animation timeline.
  `studio/Scripts/build-root-app.sh` assembles an ad-hoc-signed development app
  at the repository root for direct Finder launch. `AnimaCore` defines project
  assets, stable semantic-part IDs, box/cylinder/sphere/locator rig proxies,
  metre positions, XYZ rest rotations in radians, backward-compatible Codable
  rest transforms, joint parent/child connections, optional part-local mate
  connector frames (origin plus primary/secondary axes), connector alignment,
  joint rigs,
  clips, hold/linear keyframes, deterministic evaluation, neutral fallback,
  time clamping, joint-limit clamping, and Codable project round-tripping. The
  SwiftUI app launches into a Bottango-inspired dark home screen with a working
  New Studio Project action and honestly disabled project-open/templates until
  persistence ships. Its Recent Projects section now uses compact thumbnail
  cards with the project name, actual last-opened timestamp, revision badge,
  and optional milestone metadata. Records are recency-sorted, deduplicated,
  capped at twelve, and stored as versioned user-local metadata. Cards load a
  cached render path when one exists and otherwise show an honest project-type
  preview. Creating the current scratch project records its V1 entry; reopening
  remains visibly unavailable until P0 produces durable project documents. A
  new project now opens as a genuinely empty Rig rather
  than silently inserting the sample mechanism. Its Bottango-inspired **Add to
  Rig** palette creates real core-backed box, cylinder, sphere, and empty-point
  proxy components with their local origin at the workspace origin, then
  creates a Revolute Mate through an explicit two-step placement flow. Orange,
  hover-reactive connector markers expose proxy face centers, edge midpoints,
  corners, cylinder axes/circular centers, sphere cardinal points, and component
  origins. The first selection is the moving component; the second is fixed.
  Studio aligns the two origins with opposing primary axes, moves the first
  component into place, stores both local connector frames, and evaluates
  revolute motion about that connector rather than the component origin.
  Component names, XYZ positions, XYZ rest rotations, and mate names, axis,
  parent/child
  connection, and angular limits are inspectable/editable in memory. The Rig
  ribbon presents Fastened, Parallel, Slider, Revolute, Cylindrical, Pin Slot,
  Planar, and Ball mate families in a stable operator-facing catalog. Revolute
  is the only live creation action until the typed-mate/DOF backend lands; the
  other seven remain clearly disabled with motion summaries instead of writing
  incorrect scalar-joint data. The mate inspector's Type row is an
  Onshape-style menu listing the full eight-mate family with per-kind DOF
  summaries — only implemented kinds are selectable, and it binds to the
  joint's typed kind once the typed-mate backend lands. The Python rig model
  carries the same eight-type family (`JointType`, including `parallel`:
  XYZ translation + Z rotation) with per-type DOF templates, optional
  per-DOF limits, per-joint mate offsets, and gear/rack-and-pinion/
  screw/linear relations; 583 Python tests pass. Motors, 3D Models & Media, and Events are also
  present as clearly disabled reference groups rather than fake working
  features. Its project
  window now uses a CAD-style two-level header: a compact global document/live
  row followed by one full-width contextual command ribbon. A fixed far-left
  dropdown switches Assets, Rig, Animate, Show, and Hardware with Command-1…5;
  the former workspace-tab row has been removed. Each workspace replaces the
  ribbon with focused, grouped tools. The selector now keeps a readable
  228-point minimum width and uses an anchored, visually continuous workspace
  popover with large icon rows, purpose text, selected-row emphasis, and visible
  Command-1…6 shortcuts instead of the cramped detached system menu. Assets
  exposes Import, Manage, and Prepare; Animate exposes Transport, Keyframes,
  Curves, Tracks, and Reference;
  Show exposes Sequence, Clips, Events, and Sync; Hardware exposes Connection,
  Outputs, Mapping, Calibration, Safety, and Monitor. Implemented commands are
  live, while backend-dependent commands remain visibly disabled as planned.
  A shell-level **UI Dev** workspace follows the five project-authoring
  workspaces in the selector without becoming saved character data. Its ribbon
  opens Windows, Interaction Labs, Controls, and Foundations galleries for the living Studio UI
  standard: action hierarchy and states, labeled/unit-aware inputs, native
  menus, reusable panel chrome, blocking dialogs, contextual popovers, and
  semantic color/geometry tokens. Canonical reusable styles now cover primary,
  secondary, quiet, destructive, selected-icon, card, and popover treatments.
  UI Dev's Agent command toggles a right-side panel constrained inside the main
  app canvas, with voice/chat/docs/ideas presentation, prompt starters, a
  composer, and an explicit close affordance. It is labeled as a UI prototype;
  microphone and Send remain disabled until an agent service is connected.
  Navigator, Inspector, Timeline, and 3D View commands now render the real
  production surfaces inside the UI Dev canvas in their operator-facing dock
  regions: Navigator on the left, Inspector on the right, Timeline below the
  viewport, and the 3D view in the center. They use an isolated sample rig and
  never create auxiliary AppKit windows. The Agent likewise remains a real
  right-side app panel. One explicitly labeled **Detached Window** is the sole
  floating UI Dev surface; it demonstrates the always-above-workspace utility
  panel pattern for compact temporary tools and reuses one saved panel instance.
  UI Dev opens on an **all-surfaces Template Matrix**: twenty-five current app
  specimens grouped into Windows & Workspaces, Timelines & Editors, Inspectors,
  Panels & Tools, Dialogs/Menus/Popovers, Buttons & Inputs, and Status & Empty
  States. Every specimen is visible together in a responsive board and names
  its intended production size. The board includes the real reusable Recent
  Projects cards, docked Agent, detached-tool template, and live scaled Mate
  Editor and triad labs alongside Navigator, viewport, timeline, appearance,
  hardware, context-menu, control, and feedback specimens. A stable catalog
  guarantees every current template ID belongs to one visible section. The
  ribbon also exposes a dedicated **Reference Widgets** lab for visual patterns
  being tested before production adoption. Pack 01 implements three interactive
  SwiftUI references: a layered icon list with hierarchy disclosure, selection,
  hover, tags, and trailing state/type icons; a dismissible/restorable
  notification popup with a primary-controller choice; and a two-column layout/
  style inspector covering display mode, corner and border treatment, editable
  box-model spacing, background mode, and clipping. The same three reusable
  specimens appear in the global Template Matrix; none is wired into an
  operator workflow until it is reviewed and adopted there. The separate
  **Live UI Kit** remains available with a resizable Design Inspector
  beside a production-component catalog. The inspector edits the shared Studio surface
  and semantic colors, muted/border strength, chrome and ribbon heights, panel
  radius/padding, field and control geometry, and Navigator/Inspector/Agent
  widths. Changes are range-validated, applied immediately through the same
  `StudioPalette`/`StudioMetrics` source used by the rest of the app, and saved
  automatically as a versioned user design profile. Standard, Compact, and
  High Contrast presets, destructive reset confirmation, JSON import/export,
  and copy-as-JSON are live. The adjacent kit lays out the docked window map,
  all canonical button states, production fields, menus, popovers, panel
  chrome, and direct links to the real embedded surface previews.
  Its Mate Editor interaction lab uses one shared Onshape-style panel for the
  complete eight-mate family. A stable icon strip and full-width Type dropdown
  both switch that panel; the title, degrees-of-freedom readout, constrained
  translation/rotation Offset controls, and optional minimum/maximum Limits
  rows update from the selected kind. Slider exposes Z translation limits,
  Revolute exposes Z rotation limits, compound mates expose every permitted
  freedom with mm/degree units, and Fastened explicitly has no motion limits.
  Connector picking, simulation-connection disclosure, accept/cancel,
  flip/reorient, preview, and solve affordances remain shared rather than
  duplicated per mate. Its Triad Manipulator lab provides a code-drawn,
  hoverable/drag-responsive center ball, XYZ translation arrows, rotation
  rings, plane pads, ghosted restricted motion, live units, and controls for
  handle scale and stroke weight. Both are explicitly design prototypes for
  refining operator readability and interaction; they do not claim the planned
  typed-mate/DriveTarget backend is shipped; only Revolute remains a live Rig
  creation action until that AnimaCore contract lands.
  Rig preserves Structures and the complete Mate family and adds focused
  Connectors, Assemble, and Inspect groups before the planned Motors, 3D Models
  & Media, and Events groups. Its creation families stay docked in the ribbon
  rather than floating over the viewport; collapsing them restores a compact
  Rig tool row. Panel visibility
  remains independently restorable in-session for the navigator, inspector,
  and bottom editor. Assets
  centers import and hierarchy inspection; Rig centers components and mates;
  Animate owns the working timeline dock with transport, every clip motion
  track, clickable keyframes, click/drag scrubbing, adjacent-key and frame
  stepping, a real loop-preview toggle, horizontal zoom, and configurable
  24/25/30/60 fps timecode over continuous seconds. Its Dope Sheet includes
  honest empty Audio/Event capability lanes and switches to a read-only Graph
  presentation of hold/linear curves; selecting mates isolates their curves.
  Show has a distinct multi-track
  character/audio/screen/event timeline scaffold; Hardware has structured
  connection, safety, mapping, and filterable-log surfaces that visibly remain
  safely offline. The gear settings menu stores a user-local viewport
  appearance choice with Midnight, Graphite, CAD Light, and Blueprint presets;
  each changes the RealityKit background and major/minor grid colors without
  altering project data. The viewport now provides a readable grid and a live
  view cube driven by the same camera state as RealityKit. It mirrors manual
  orbit/pan/zoom changes; its faces, edges, and corners select principal,
  two-axis, and trimetric views, while its surrounding arrows rotate the view
  in 15-degree steps. A dedicated camera/render menu provides
  perspective/orthographic projection, 30–90° perspective field-of-view
  presets and selection framing. The lower camera toolbar now contains Home,
  Display, and Help; Front, Right, and Top shortcuts are omitted because the
  view cube owns principal, edge, and corner navigation. Display independently
  controls Shaded/Wireframe/Translucent surfaces, mesh-edge visibility, grid,
  viewport appearance, and Balanced/Soft/Bright/High Contrast RealityKit
  lighting rigs. Shaded proxies use physically based materials with
  Matte/Satin/Glossy/Metallic finishes; Subtle/Studio reflection modes use a
  generated softbox image-based-light environment, and directional shadow
  casting can be toggled directly. These settings persist as user-local presentation preferences
  and do not alter project data. Cube face names behave as fixed-size decals at
  their face centers, using one face-local orientation without readability flip
  correction, clipping, or scaling; its XYZ triad shares one origin and follows
  only the positive axis directions, and hovering previews the exact clickable
  face, edge, or corner. The viewport also provides trackpad pan/pinch and
  persistent Default, SolidWorks, Onshape, Fusion 360, and Custom mouse
  profiles. Default and Onshape map right drag to orbit and
  middle drag to pan; SolidWorks maps middle drag to orbit and Control- or
  Shift-middle drag to pan; Fusion 360 maps Shift-middle drag to orbit and
  middle drag to pan. Custom exposes conflict-free rotate and pan bindings.
  Discrete mouse-wheel events are consumed as zoom in every profile instead of
  scrolling vertically; precise trackpad scroll phases still pan, and pinch
  still zooms. Semantic proxy geometry is
  directly selectable in the viewport and resolves to the same stable part ID
  used by the Components tree and inspector. The selected component receives
  an orange silhouette highlight plus local XYZ translation arrows and rotation
  rings at its origin; dragging them edits the core-backed rest transform, and
  connector-authored mate rotation composes through parent/child chains. During
  any inspectable selection, Studio now restores the right-side Inspector if
  the operator had hidden it. A selected semantic proxy component exposes
  **Properties** and **Appearance** tabs. Appearance provides a 40-color
  industrial palette, an RGB/ColorPicker mixer, editable six-digit hex color,
  explicit RGB values, opacity, visibility, reset, and a truthful Automatic
  tessellation readout. Color, opacity, and visibility update the actual
  RealityKit proxy body immediately; locked components reject these edits.
  Overrides are deliberately in-session presentation state until the durable
  project document defines non-destructive material-override persistence, and
  imported source-model materials remain source-owned and read-only. A selected
  semantic component also has a native, CAD-ordered viewport context menu. It
  identifies the body and groups property editing, attached-mate navigation,
  show/hide, reversible isolate and transparency previews, select-all/clear,
  Home and Zoom to Selection, lock/unlock, transform reset, and Appearance.
  Isolation and transparency are renderer-only overlays that leave the saved
  rig and underlying appearance override unchanged. Menu commands use the same
  model-owned lock guards as the Inspector and transform gizmo. During
  mate placement, transform handles are suppressed so connector markers own the
  click target. Outside mate placement, the focused component shows the same
  inferred face-center/edge-midpoint/corner/axis/origin candidates as quiet
  cyan markers with view-cube-style hover: pointing at one highlights the
  exact clickable feature before commit-click. Clicking a marker selects that
  feature persistently (stronger cyan treatment) and keeps the owning
  component selected; the inspector shows a read-only Feature section with
  the owning component, feature kind, and part-local origin. Clicking empty
  viewport space now deselects the feature and all components; Escape clears
  the feature first, then component selection, and feature inspection is
  allowed on locked components while locks keep guarding every edit. The
  Components outline follows macOS file-browser
  selection conventions:
  Command/Shift select multiple, one item opens its configuration, and Escape
  or the inspector close control clears selection. Imported geometry can also
  be selected directly in the viewport, with Command/Shift extending the same
  Components-tree selection. Every navigator workspace now has a standardized
  filter. Imported assemblies appear in a separate blue, locked **Source Model ·
  Read Only** tree; filtering preserves the ancestors of matching nodes. The
  semantic Components and Mates remain separate editable-role rows in teal and
  purple. Component disclosure groups support contextual rename, move up/down,
  move-to-group, dissolve, and lock/unlock; Mates support contextual rename,
  reorder, and lock/unlock. Component-row edges now show insertion lines for
  before/after placement; the center shows a bordered **+ Group** target and
  creates an expanded folder containing the target plus the dragged active
  multi-selection. Existing folders accept the dragged selection, while the
  Components heading returns it to top level. Groups and Mates show peer
  insertion lines. The footer and selected-row context menu expose **Group
  Selected (N)** and report when locked selections will be skipped. Locked
  items reject inspector, transform, and organization edits, hide transform
  handles, and locked groups protect their members. Group and lock organization
  is currently in-session pending the durable `.animastudio` document layer.
  Source-node inspection explains ownership, source appearance, mapping, and
  reimport prerequisites. Shared theme metrics and
  reusable panel, text-field, picker, readout, and primary-button styles keep
  new Studio windows visually consistent. The sample Rig viewport also renders
  a mate-guide foundation: labeled local XYZ axes, a revolute DOF ring, an
  optional reference plane, and a highlighted limit arc with independent layer
  toggles on every created mate. Project and asset names are also editable in
  memory. Users can select a
  RealityKit-supported USD/Reality model; it loads asynchronously, is normalized
  for preview framing, and appears in the project asset tree. Its complete
  RealityKit entity hierarchy is projected into value-only nodes with unique
  sibling paths, shown as a selectable Structure outline, and described in the
  inspector. One hundred ninety-eight tests pass with
  `cd studio && swift test`, including real USD hierarchy loading/projection
  through RealityKit, duplicate/unnamed entity identity coverage, hierarchy
  filtering/ancestor retention, frame timecode and stepping, adjacent-key
  navigation, and loop/non-loop playback. The Swift side also ships the
  durable document layer as a UI-free `AnimaDocument` package target:
  `AnimaDocumentStore` saves/loads versioned `.animastudio` directory
  packages (`project.json` manifest with `format_version` "1", display
  name, per-save revision counter for the recents V-badge, optional
  milestone name, ISO-8601 modified date, the encoded AnimaCore project,
  and an asset table; `Assets/` holds embedded payloads). Saves are
  atomic (staged temp directory swapped into place — a crashed save never
  corrupts an existing package) and deterministic (sorted keys, stable
  asset ordering: identical input encodes byte-identically). Assets are
  SolidWorks-assembly style: `embedded` copies the payload into the
  package, `linked` records the external absolute path plus a
  security-scoped bookmark, and resolution returns an explicit
  needs-relink state for stale/missing links instead of throwing.
  Corrupt manifests, unsupported versions, duplicate asset names/IDs,
  missing payloads, and any manifest path escaping the package are
  rejected with typed, user-presentable errors (traversal is validated
  before the path touches the filesystem). Save/open/dirty-state UI
  wiring on top of this store has not landed yet — reopening from the
  home screen stays honestly disabled until it does. The Python
  package skeleton also
  installs with `pip install -e ".[dev]"`. The Python runtime now implements
  the Anima Wire Protocol v0 reference host (`anima_studio/wire.py` — encode
  HELLO/CFG/FRM/EN/STOP/PING, parse ANIMA/OK/ERR/PONG, 3-decimal normalized
  values), an in-process simulated device (`anima_studio/sim.py` — handshake,
  servo CFG, device-side linear FRM interpolation on an explicit `tick(now_ms)`
  clock, E-stop, per-channel 2000 ms failsafe, spec ERR codes), and a
  normalized output-track evaluator (`anima_studio/tracks.py` — hold/linear,
  time and limit clamping, deterministic; explicitly not a rig evaluator —
  AnimaCore keeps rig semantics; no Bézier yet). Per review: only successfully
  parsed commands refresh the failsafe heartbeat, and duplicate CFG keys or
  duplicate FRM channels are rejected (no last-write-wins). The runtime also
  loads `.character.anima` 2.0 files (`anima_studio/loader.py` — version/type
  check, typed errors naming the offending path, unknown-field rejection;
  unsupported/superseded spec sections are rejected loudly, never
  silently dropped) into a mechanism-rig model (`anima_studio/rig.py` —
  parts plus the eight typed Onshape-style mates whose type defines the
  DOF set; per-DOF limits are optional per Kinematics.md §2: an
  unlimited DOF is legal and never clamped, but mapping one to a
  bounded output channel is a load error naming the fix; per-joint
  as-mated `offset` blocks round-trip for Studio's spatial use; and
  gear / rack_pinion / screw / linear `relations` couple DOF pairs as
  `driven = ratio × driver + offset` with acyclic/single-driver/
  no-animated-driven validation. `evaluate_pose` resolves clip-driven
  DOF with neutral fallback and loop wrapping, applies relations in
  dependency order, and reports — never clamps — driven values outside
  their limits as `Pose.limit_violations`; `project_channels` (the
  target→normalized 0..1 channel seam feeding `wire.encode_frm`)
  raises `LimitViolationError` for a mapped violated DOF so hardware
  refuses to arm). `examples/six_axis_arm|rc_car|walle_style
  .character.anima` load end-to-end; rc_car exercises a steering
  rack-and-pinion relation and an unlimited free-spinning axle.
  The runtime also ships the community-extension foundation
  (Extensions.md packet E1): `anima_studio/outputs.py` defines the
  `OutputAdapter` extension-point protocol (`open(channel_configs)` /
  `send_frame(targets, duration_ms)` / `stop()` e-stop / `close()`,
  with `ChannelConfig` mirroring the wire CFG fields) plus the
  built-in `SimulatorOutput` wrapping `SimulatedDevice` through that
  exact API, and `anima_studio/extensions.py` loads `<slug>.animaext`
  bundles — closed-schema `extension.yaml` manifests with typed errors
  naming offending paths, capability declarations (hardware/network/
  filesystem), `discover_extensions(search_dirs)` over caller-passed
  directories with duplicate-id rejection, and
  `entry: "module.py:ClassName"` class loading namespaced per
  extension with no `sys.path` pollution; `output_adapter` (E1) and
  `parametric_feature` (E2) contributions load, other known kinds
  parse but refuse with "not yet supported". The packaged
  `examples/extensions/udp-wire-output.animaext/` example streams
  wire lines as UDP datagrams and is tested from its real bundle path.
  Parametric features (Extensions.md packet E2 backend,
  `anima_studio/features.py`) are pure-data YAML templates — a
  `parametric_feature` entry must be a `.yaml` file, never Python —
  declaring typed parameters (float with explicit unit hint / int /
  bool / choice, defaults and ranges) and a body of standard
  parts/joints/relations/rig-parameters in loader shapes, with safe
  `${expr}` arithmetic substitution (no `eval`; unknown names and
  division by zero are typed errors) and nestable `repeat:` blocks
  for indexed copies. `expand_feature` validates parameter values,
  prefixes every emitted name with the instance name (two instances
  coexist), and resolves the `$parent` attachment sentinel;
  `merge_fragment` inserts the fragment into a character mapping that
  is then re-parsed by the standard loader — expansion never bypasses
  loader validation. The packaged
  `examples/extensions/parametric-linkage.animaext/` example (an
  N-link serial revolute arm with an optional prismatic end slider,
  `capabilities: []`) is tested end-to-end from its real bundle path
  through discover → load template → expand → merge → loader →
  `evaluate_pose` → `project_channels`.
  The runtime also ships the real-hardware serial bridge
  (`anima_studio/serial_transport.py`): `SerialWireOutput` implements
  the same `OutputAdapter` contract over pyserial (`pyserial>=3.5` is
  now a package dependency) — `serial_for_url` port opening (device
  paths like `/dev/tty.usbmodem*` or URLs like `loop://` for tests),
  HELLO handshake with protocol-version check, CFG+EN per channel,
  OK-checked FRM streaming, and best-effort idempotent STOP that
  swallows dead-port errors into `last_error` during an e-stop.
  Typed errors name what happened (`HandshakeError`,
  `ReplyTimeoutError`, `ProtocolError`, `DeviceRejectedError` carrying
  the device's ERR code/message); reply reads use pyserial timeouts
  only (0.5 s default, 2 s handshake — no polling, no sleeps), and a
  host-side timeout is the operator signal while the device failsafe
  stays the safety net. Tested over a real pyserial `loop://` port
  against the reference `SimulatedDevice` with exact-line assertions
  (no reconnect/threading yet — that lands with Studio live control).
  The runtime also executes `.scene.anima` shows headless
  (`anima_studio/scene.py`, the B10 offline-playback foundation):
  the execution-v1 subset of `Scene_Format.md` — `clip` (speed ratio,
  background `wait: false`, required `duration_s` for looping clips),
  one-off `pose` interpolation from captured start values, `wait`,
  `wait_for` event gates with optional timeout (`skip`/`end`), `set`/
  `if` over declared scalar variables (literals and variable copies
  only — no expressions yet), bounded and variable-gated `loop`,
  deterministic `parallel` (timestamp order, ties by track order), and
  outbound `event` emission — with the deferred spec actions (`speak`,
  `expression`, `blend_shapes`, `lights`, `ai_response`, `goto`)
  rejected loudly at load. The `character:` path resolves relative to
  the scene file; `SceneRunner` has no wall clock (caller-driven
  `advance(now_s)` ticks plus `post_event(name)` gates, mirroring the
  simulator's explicit-time discipline), merges active motion sources
  over held values, recomputes relation-driven DOF each frame with the
  same refuse-to-arm limit semantics, streams frames through any
  `OutputAdapter`, and reports `finished` /
  `ended_by_gate_timeout` / `stopped` plus an emitted-events log.
  `examples/pick_and_wave.scene.anima` drives the six-axis arm through
  the whole v1 surface.
  583 Python tests pass with `.venv/bin/pytest anima_studio/tests -q` (lint:
  `.venv/bin/ruff check .`), including end-to-end clip → FRM stream →
  simulated servo → failsafe, character file → rig evaluation →
  relation coupling → channel projection → simulated servo tests,
  rig evaluation → `OutputAdapter.send_frame` → simulated/UDP output
  tests, rig evaluation → serial bytes → simulated servo tests, and
  scene file → `SceneRunner` → simulated servo values at exact
  timestamps with logic-gate branching.
- **What's stubbed:** every `*.example` file under `anima_studio/` —
  `module.yaml`, `config.py`, `node.py`, the module-contract test —
  these are the JaegerOS-module shape for later
- **Known gaps:** imported model hierarchies can be inspected and filtered but
  still use temporary sibling-index paths; durable source identity, security
  bookmarks, reimport reconciliation, collapse, and mapping to persistent
  semantic parts are not implemented. Source nodes are intentionally locked,
  and semantic-part drag reparenting waits for the persistent part/undo model.
  Proxy connector inference and two-click Revolute Mate placement are live,
  but connector orientation flip/reorientation controls, persistent custom
  connectors, and attachment to imported source nodes are not yet implemented.
  Automatic imported-hole centers require durable mesh/topology references;
  current hole-like snapping is available on cylinder proxy axes and circular
  face centers. The shipped part transform gizmo edits semantic-part rest
  transforms outside mate placement. Sub-object selection covers the inferred
  proxy feature candidates (face centers, edge midpoints, corners, axes,
  origins); imported-mesh face selection still
  needs triangle identity through reimport, and full edge-curve selection still needs
  topology/adjacency plus screen-space proximity. Transform gizmos are currently
  world-scaled rather than screen-size-stable. Mesh Edges and Wireframe display
  triangle mesh lines, not classified CAD feature edges; hidden-line removal,
  section views, camera roll, and saved named views are not implemented. Typed
  prismatic/cylindrical/ball/planar/fastened joints
  and keyframes are not yet editable; project changes are not
  persisted; imported security-scoped URLs
  last only for the current session. Project open/save, undo/redo, Home
  templates, and live hardware controls are intentionally visible but disabled.
  There is no `.anima` parsing in Studio (the Python runtime loads
  `.character.anima` and executes the `.scene.anima` v1 subset; Studio
  parses neither, and the deferred scene actions — speech, expressions,
  lights/LEDs, AI handoff, goto — execute nowhere), no
  editable Bézier curves/handles, audio, screens/LEDs, Live2D, Studio Show
  workspace playback, output
  node, JaegerOS connection, or full 52-blend-shape JP01 character file (a
  minimal example head ships in `examples/`). The root app bundle is a local
  development artifact rather than a notarized distribution; release signing,
  notarization, updater/distribution packaging, and App Store policy work have
  not started. Studio is a working workspace
  foundation, not yet a complete authoring workflow.

## How to update this file

1. Ship a behavior change.
2. In the same commit, add or edit a line above reflecting the new truth.
3. If something moves from "planned" to "shipped," delete it from
   `../roadmap/` (or mark it done there) — don't leave the same fact
   living in two docs, per `CONVENTIONS.md` law 1.
