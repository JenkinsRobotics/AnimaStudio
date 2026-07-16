# STATUS

> Truthful, or it's worthless. Any commit that changes behavior updates
> this file in the same commit — see `CONVENTIONS.md` → "STATUS stays
> truthful."

## Current state — 2026-07-16

- **Repo:** `AnimaStudio` — open-source unified character animation
  system for AI robots (digital avatars + physical animatronics from
  one rig, one format, one authoring tool)
- **Version:** 0.1.0 (see `animacore/__init__.py`)
- **JaegerOS pin:** not yet set — for now the runtime is standalone and
  Jaegers read `.anima` files natively; the `jaeger-os` dependency and
  `animation`-slot module land later (see `dev/docs/roadmap/`)
- **What works:** the native macOS foundation under `app/` builds both as a
  Swift package and as a real `Anima Studio.app`. The checked-in Xcode project
  is reproducibly generated from `project.yml`, with a thin native lifecycle
  target over the reusable `AnimaStudioUI` package, shared Debug/Release
  `.xcconfig` settings, least-privilege sandbox entitlements, localized-resource
  support, an asset-catalog app icon, a launch-level UI-test target, and Xcode
  Canvas previews for the home, complete workspace, and animation timeline.
  `app/Scripts/build-root-app.sh` assembles an ad-hoc-signed development app
  at the repository root for direct Finder launch. The root bundle now embeds
  a signed Python 3.11 helper, AnimaCore source, and PyYAML dependency; the
  helper inherits the app sandbox and requires no repository path or active
  virtual environment after the app is assembled. Packaging rewrites both the
  Homebrew framework launcher and its nested `Python.app` launcher to resolve
  only the bundled framework, explicitly re-signs that nested app, and fails the
  build if either launcher still references Homebrew. `AnimaModel` defines project
  assets, stable semantic-part IDs, box/cylinder/sphere/locator rig proxies,
  metre positions, XYZ rest rotations in radians, backward-compatible Codable
  rest transforms, joint parent/child connections, optional part-local mate
  connector frames (origin plus primary/secondary axes), connector alignment,
  joint rigs, clips, hold/linear keyframes, and Codable project round-tripping.
  `AnimaEvaluation` still provides the pre-bridge transitional preview evaluator,
  but new animation meaning belongs in the canonical Python engine rather than
  this Swift module. A dedicated `AnimaCoreClient` now owns the typed newline-JSON
  protocol, long-running helper process, handshake, character load/validation,
  frame and world-pose evaluation, release, shutdown, engine errors, and
  channel-index decoding.
  The Assets ribbon can import a `.character.anima` document, load it through
  AnimaCore, evaluate its first clip at a deterministic preview time, and request
  the engine's per-part world transforms through `resolve_pose`. Studio creates
  one renderer-only proxy per engine part and applies the returned metre
  positions and real-last quaternions directly in RealityKit at the playhead;
  it no longer infers a second hierarchy, connector frame, or mate motion in
  Swift. Continuous playhead evaluation is live for imported engine clips.
  Save/open wrapping, canonical authoring mutation, scene playback, and hardware
  output remain subsequent bridge packets. The
  SwiftUI app launches into a Bottango-inspired dark home screen with a working
  New Studio Project action and honestly disabled project-open/templates until
  persistence ships. Its Recent Projects section now uses compact thumbnail
  cards with the project name, actual last-opened timestamp, revision badge,
  and optional milestone metadata. Records are recency-sorted, deduplicated,
  capped at twelve, and stored as versioned user-local metadata. Cards load a
  cached render path when one exists and otherwise show an honest project-type
  preview. Creating the current scratch project records its V1 entry; reopening
  remains visibly unavailable until P0 produces durable project documents. A
  new project now opens as a genuinely empty project in the first **Assets**
  workspace rather than silently inserting the sample mechanism or jumping
  ahead to Rig. The workspace-model initializer accepts an alternate startup
  workspace so a future operator preference can choose it without changing
  workspace semantics. Its Bottango-inspired **Add to
  Rig** palette creates real core-backed box, cylinder, sphere, and empty-point
  proxy components with their local origin at the workspace origin, then
  creates a Revolute Mate through an explicit two-step placement flow. Orange,
  hover-reactive connector markers expose proxy face centers, edge midpoints,
  corners, cylinder axes/circular centers, sphere cardinal points, and component
  origins. The first selection is the moving component; the second is fixed.
  The transitional local Revolute draft stores both connector frames but no
  longer performs a separate Swift mate solve; canonical document mutation and
  an AnimaCore reload/`resolve_pose` pass must perform alignment and motion.
  Component names, XYZ positions, XYZ rest rotations, and mate names, axis,
  parent/child
  connection, and angular limits are inspectable/editable in memory. The Rig
  ribbon presents the complete ten-type family: Fastened, Parallel, Slider,
  Revolute, Cylindrical, Pin Slot, Planar, Ball, Width, and Tangent. All ten are
  backed by the engine catalog for inspection; Revolute remains the sole
  transitional local draft-creation action until canonical character editing
  is wired. The mate inspector's Type row and UI Dev lab list the same family
  with per-kind DOF summaries. The Python rig model
  carries the same eight-type kinematic family (`JointType`, including
  `parallel`: XYZ translation + Z rotation) with per-type DOF templates,
  optional per-DOF limits, and gear/rack-and-pinion/screw/linear
  relations, plus two 0-DOF **geometry-constraint** mates — `width`
  (center a tab between two faces, no offset) and `tangent` (keep two
  surfaces in contact; non-driving, deferred with no geometry kernel).
  The engine recognizes, round-trips, and catalogs the geometry pair but
  their geometry is resolved app-side (`mate_category`); `width` resolves
  like a 0-DOF fastened once the app supplies its two midplane
  connectors, `tangent` leaves its child at the parent frame. The
  mate-authoring model lives in `animacore/mates.py`: every kinematic
  mate exposes one universal `MateControls` set — two flippable
  connector frames, an as-mated offset, a whole-mate primary-axis flip,
  a 90°-step secondary-axis reorientation, and a simulation-connection
  toggle — shared identically across all eight kinds, with only the DOF
  set differing per kind, plus a stable per-mate `id` distinct from the
  editable name; `width` reuses that control set minus offset/secondary,
  and `tangent` carries a two-selection `tangent` block instead of
  connectors. Two UI hooks surface it: the `mate_types` bridge verb (now
  ten schemas, each with `category`/`drivable` — static per-kind catalog
  of label, DOF slots, control ids) and `describe_mate` (per-instance
  descriptor carried in the `load_character` joint summary, with
  `category`). The Swift bridge mirrors category, drivable state, DOF axis,
  optional connector controls, and the Tangent-specific surface payload as
  typed DTOs and requests the engine-owned catalog when it connects. Imported
  engine mates are listed in the real Components navigator by their stable
  tracking id, so a zero-DOF Fastened mate remains selectable rather than
  disappearing from the rotational preview projection. Selecting one opens a
  reusable engine-driven mate inspector showing its type/name/id, parent and
  child, both connector frames and per-side flip state, offset values formatted
  in millimetres/degrees, whole-mate axis flip/reorientation, simulation
  connection, and its engine-supplied DOF rows with explicit axes. Fastened
  presents an explicit fully-bonded zero-DOF state; Width and Tangent present
  distinct non-drivable geometry-constraint states, and Tangent shows its two
  opaque surface selections plus propagation. This first panel is intentionally read-only;
  editing the canonical character text and revalidating it through the bridge
  is the next mate-authoring packet. Motors, 3D Models & Media, and Events are also
  present as clearly disabled reference groups rather than fake working
  features. Its project
  window now uses a CAD-style two-level header: a compact global document/live
  row followed by one full-width contextual command ribbon. A fixed far-left
  dropdown switches Assets, Rig, Animate, Show, Nodes, and Hardware with Command-1…6;
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
  **Nodes** is a dedicated scene-logic planning workspace with a dark dotted
  canvas, draggable and selectable typed sample nodes, live curved flow edges,
  a searchable node library, a selection-driven inspector, structural
  validation feedback, zoom/grid/frame controls, add/delete/reset actions, and
  a compact timeline concept that explicitly presents graph and timeline as two
  views of one future scene document. Flow, performance, timing, and event
  families are available in the UI draft. The concept library now separates
  Inputs, Voice & AI, and Outputs, with placeable STT/TTS/LLM, memory, tool,
  microphone, text, event, audio, motion, screen, LED, and hardware cards.
  The library also includes FANUC-inspired structured logic concepts: IF/ELSE,
  single-line IF guards, SELECT, CALL, WAIT Until, AND/OR/XOR/NOT, input reads,
  output writes, numeric registers, flags, position registers, background
  monitors, and monitor-only End Scene. Typed ports and inspector properties
  show the intended manual scene syntax so future Visual and Script editors can
  project the same program. JMP and LBL exist only as red IMPORT ONLY reference
  cards and validation errors; Anima scenes require the structured Loop, SELECT,
  and CALL equivalents rather than irreducible jump flow.
  Typed visual ports and editable sample properties support UI review, while
  every concept stays validation-blocked from execution until its runtime
  provider ships. This surface does not
  yet load, save, compile, execute, or author connections in `.scene.anima`;
  the in-memory draft is intentionally not a second runtime model.
  A shell-level **UI Dev** workspace follows the six project-authoring
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
  UI Dev opens on an **all-surfaces Template Matrix**: thirty-one current app
  specimens grouped into Windows & Workspaces, Timelines & Editors, Inspectors,
  Panels & Tools, Dialogs/Menus/Popovers, Buttons & Inputs, and Status & Empty
  States. Every specimen is visible together in a responsive board and names
  its intended production size. The board includes the real reusable Recent
  Projects cards, docked Agent, detached-tool template, and live scaled Mate
  Editor and triad labs alongside Navigator, viewport, timeline, appearance,
  hardware, context-menu, control, and feedback specimens. A stable catalog
  guarantees every current template ID belongs to one visible section. A
  separate **Variant Board** preserves that matrix while adding a wide,
  component-board comparison of twenty-six states across Workspace Chrome,
  Docked Panels, Inspectors, Timelines, Toolbars, Dialogs/Menus, and Status.
  Its search and family filter narrow the visible comparison without mutating
  the catalog; 50–110% density controls resize the four-column board, and any
  specimen can be focused with a visible dashed selection outline. The ribbon
  also exposes a dedicated **Reference Widgets** lab for visual patterns
  being tested before production adoption. Pack 01 implements three interactive
  SwiftUI references: a layered icon list with hierarchy disclosure, selection,
  hover, tags, and trailing state/type icons; a dismissible/restorable
  notification popup with a primary-controller choice; and a two-column layout/
  style inspector covering display mode, corner and border treatment, editable
  box-model spacing, background mode, and clipping. The same three reusable
  specimens appear in the global Template Matrix. Pack 02 adds two interactive
  tab patterns: a compact primary-command/settings panel with shortcut labels
  and a live Light/Dark segmented switch, plus a multi-document strip with
  macOS window context, tab selection and hover states, per-tab close controls,
  and new-tab creation. Both tab specimens are isolated in a dedicated source
  file and appear in the same matrix. Pack 03 adds a dedicated interactive
  Material Editor reference with a live HSB-driven preview sphere, editable
  name and surface type, native color selection, six selectable and independently
  enabled material channels, Float/Texture inputs, per-channel value and mix
  controls, locking, and explicit Node Editor/Assignment/Help feedback. It is a
  UI-only draft until renderer material, texture-asset, assignment, and document
  contracts are defined. Pack 04 adds **Timeline Design B**, an interactive
  multi-row animation lab with Dopesheet, Motion Curves, and Waypoint Lanes
  projected from one shared track/keyframe model. Operators can add rows, click
  empty row space to create sorted bounded keys, select and delete keys, add a
  key at the playhead, scrub the ruler, and switch presentations without losing
  state. Every variant draws the authored motion connection between waypoints;
  Motion Curves uses a smooth value-aware path while the other variants use
  direct readable segments. The Dopesheet is the default reference presentation
  and now follows the supplied compact editor more closely: its chrome is denser,
  the channel column is searchable, a Summary lane aggregates authored keys, the
  ruler uses 0–240 frame numbers at 30 fps, and the blue playhead reports its
  current frame in both the ruler and status footer. This remains a UI Dev
  comparison and does not
  replace the production Animate timeline yet. Pack 05 adds six reusable
  **Concept Template Cards** for rig organization, AI node-flow generation,
  tools/resources, assembly import, motion sequencing, and character outputs.
  The responsive cards provide purpose-built illustrations, title/detail/action
  hierarchy, hover and selected states, and explicit prototype-action feedback;
  they are available in both Reference Widgets and the Template Matrix. Pack 06
  adds an interactive **Icon Selector & Theme Lab** with a hover/select icon
  dock and Edit/Duplicate/Delete menu patterns. The same specimen switches
  among isolated Light, Dark, Graphite, Midnight, and Neon palette specs;
  selected-icon foreground colors are contrast checked. These palettes remain
  local to UI Dev until human review and a deliberate refactor of the app's
  dark-only appearance assumptions. None of these reference widgets is wired
  into an
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
  UI Dev also includes a dedicated **Nodes** tab rendering the production-sized
  node workspace in place so its library, canvas, cards, ports, edges,
  inspector, and timeline can be refined alongside the rest of the living UI
  standard.
  Its Mate Editor interaction lab uses one shared Onshape-style panel for the
  complete ten-mate family. A stable icon strip and full-width Type dropdown
  both switch that panel; the title, degrees-of-freedom readout, constrained
  translation/rotation Offset controls, and optional minimum/maximum Limits
  rows update from the selected kind. Slider exposes Z translation limits,
  Revolute exposes Z rotation limits, compound mates expose every permitted
  freedom with mm/degree units, Fastened explicitly has no motion limits, and
  Width/Tangent are labeled as 0-DOF geometry constraints.
  Connector picking, simulation-connection disclosure, accept/cancel,
  flip/reorient, preview, and solve affordances remain shared rather than
  duplicated per mate. Its Triad Manipulator lab provides a code-drawn,
  hoverable/drag-responsive center ball, XYZ translation arrows, rotation
  rings, plane pads, ghosted restricted motion, live units, and controls for
  handle scale and stroke weight. Both are explicitly design prototypes for
  refining operator readability and interaction; they do not claim the planned
  canonical authoring-mutation/DriveTarget path is shipped; only Revolute
  remains a local Rig draft action until that path lands.
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
  Orbit, pan, and zoom response now have independent persistent Slow through
  Very Fast presets in Display → Input. Orbit and pan default to Standard;
  zoom defaults to Reduced so a mouse-wheel notch makes a smaller, more
  controllable camera move.
  Discrete mouse-wheel events are consumed as zoom in every profile instead of
  scrolling vertically; precise trackpad scroll phases still pan, and pinch
  still zooms. Semantic proxy geometry is
  directly selectable in the viewport and resolves to the same stable part ID
  used by the Components tree and inspector. The selected component receives
  an orange silhouette highlight plus local XYZ translation arrows and rotation
  rings at its origin; dragging them edits the core-backed rest transform, and
  connector-authored mate rotation composes through parent/child chains. During
  pointer inspection, semantic proxy bodies and imported model surfaces use a
  cyan preselection glow before left-click commit. Selected proxy components
  continue to expose quiet face-center, edge-midpoint, corner, axis, and origin
  markers whose own hover effect previews the exact inferred feature target.
  During any inspectable selection, Studio now restores the right-side Inspector if
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
  show/hide, reversible isolate and transparency previews, mate-guide
  visibility, select-all/clear, Zoom to Fit and Zoom to Selection, lock/unlock,
  transform reset, and Appearance. Context routing now follows the pointer:
  right-clicking the selected component or one of its feature markers opens
  that full menu, while right-clicking empty space opens a compact Show All /
  Zoom to Fit / Isometric canvas menu. Right-drag remains camera orbit rather
  than a selection gesture.
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
  inspector. Two hundred sixteen tests pass with
  `cd app && swift test`, including real USD hierarchy loading/projection
  through RealityKit, duplicate/unnamed entity identity coverage, hierarchy
  filtering/ancestor retention, frame timecode and stepping, adjacent-key
  navigation, and loop/non-loop playback. The Swift side also ships the
  durable document layer as a UI-free `AnimaDocument` package target:
  `AnimaDocumentStore` saves/loads versioned `.animastudio` directory
  packages (`project.json` manifest with `format_version` "1", display
  name, per-save revision counter for the recents V-badge, optional
  milestone name, ISO-8601 modified date, the encoded AnimaModel project,
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
  the Anima Wire Protocol v0 reference host (`animacore/wire.py` — encode
  HELLO/CFG/FRM/EN/STOP/PING, parse ANIMA/OK/ERR/PONG, 3-decimal normalized
  values), an in-process simulated device (`animacore/sim.py` — handshake,
  servo CFG, device-side linear FRM interpolation on an explicit `tick(now_ms)`
  clock, E-stop, per-channel 2000 ms failsafe, spec ERR codes), and a
  normalized output-track evaluator (`animacore/tracks.py` — hold/linear,
  time and limit clamping, deterministic; explicitly not a rig evaluator —
  AnimaCore keeps rig semantics; no Bézier yet). Per review: only successfully
  parsed commands refresh the failsafe heartbeat, and duplicate CFG keys or
  duplicate FRM channels are rejected (no last-write-wins). The runtime also
  loads `.character.anima` 2.0 files (`animacore/loader.py` — version/type
  check, typed errors naming the offending path, unknown-field rejection;
  unsupported/superseded spec sections are rejected loudly, never
  silently dropped) into a mechanism-rig model (`animacore/rig.py` —
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
  (Extensions.md packet E1): `animacore/outputs.py` defines the
  `OutputAdapter` extension-point protocol (`open(channel_configs)` /
  `send_frame(targets, duration_ms)` / `stop()` e-stop / `close()`,
  with `ChannelConfig` mirroring the wire CFG fields) plus the
  built-in `SimulatorOutput` wrapping `SimulatedDevice` through that
  exact API, and `animacore/extensions.py` loads `<slug>.animaext`
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
  `animacore/features.py`) are pure-data YAML templates — a
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
  (`animacore/serial_transport.py`): `SerialWireOutput` implements
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
  (`animacore/scene.py`, the B10 offline-playback foundation):
  the execution-v1 subset of `Scene_Format.md` — `clip` (speed ratio,
  background `wait: false`, required `duration_s` for looping clips),
  one-off `pose` interpolation from captured start values, `wait`,
  `wait_for` event gates with optional timeout (`skip`/`end`), `set`/
  `if` over declared scalar variables (literals and variable copies
  only — no expressions yet), bounded and variable-gated `loop`,
  deterministic `parallel` (timestamp order, ties by track order), and
  outbound `event` emission — with the deferred spec actions (`speak`,
  `expression`, `blend_shapes`, `lights`, `ai_response`, `goto`)
  rejected loudly at load. Scene execution v2 adds the FANUC-inspired
  scripting constructs, additively within format 2.0: structured
  condition trees (`var`/`input` compare leaves with typed
  `eq/ne/lt/le/gt/ge`, `all`/`any`/`xor` (exactly two)/`not`
  combinators, unlimited nesting — data, never string expressions),
  `if: {when}` guards, `select` multi-way branches (first match, no
  fallthrough, duplicate literals rejected), `call` + top-level
  `subroutines:` (shared variable scope; recursion rejected at load
  with the cycle named), read-only externally driven `inputs:`
  (`runner.set_input` applies at the next tick boundary),
  level-triggered `wait_until` condition gates with `wait_for`-style
  timeouts, and background `monitors:` (BG-Logic interlocks scanned
  every tick before the main sequence, edge-triggered with re-arm,
  bodies restricted to `set`/`event`/the monitor-only `end_scene`,
  which e-stops the adapter and finishes with a result string such as
  `"estop"`). The `character:` path resolves relative to
  the scene file; `SceneRunner` has no wall clock (caller-driven
  `advance(now_s)` ticks plus `post_event(name)` gates and
  `set_input(name, value)` between ticks, mirroring the
  simulator's explicit-time discipline), merges active motion sources
  over held values, recomputes relation-driven DOF each frame with the
  same refuse-to-arm limit semantics, streams frames through any
  `OutputAdapter`, and reports `finished` /
  `ended_by_gate_timeout` / `stopped` / a monitor's result string,
  plus an emitted-events log.
  `examples/pick_and_wave.scene.anima` drives the six-axis arm through
  the whole v1 surface and `examples/patrol_and_greet.scene.anima`
  through the v2 surface (input-gated wait_until, select, a twice-
  called subroutine, an estop monitor).
  The runtime also exposes AnimaCore as the single canonical engine
  behind a stdio bridge (`animacore/bridge.py`, protocol
  `dev/docs/roadmap/Studio_Bridge.md`, BR1 slice): the Swift app spawns
  `python -m animacore.bridge` once per session and speaks
  newline-delimited JSON to it — `hello` handshake, `load_character`
  (returns a deterministic handle + a rig summary the app mirrors),
  `validate_character`, `evaluate` (DOF values, parameters, projected
  channels, and reported limit violations for one frame), `resolve_pose`
  (per-part world transforms — see below), `mate_types`,
  `relation_types` (the four relation kinds — Gear, Rack and pinion,
  Screw, Linear — as a static palette catalog), `serialize_character` /
  `serialize_scene` (the project-Save write side — see below), `release`,
  and `shutdown`. `load_character` also carries a `relations` array
  (`describe_relation` per instance: signed semantic `ratio` split into
  a display `magnitude` + `reverse` flag, plus a `ratio_field_value`
  that is the unitless ratio for gear/linear or distance-per-revolution
  in mm — `abs(ratio) × 2π × 1000` — for rack_pinion/screw). This is
  the seam that keeps the app a front end: it
  holds DTOs that mirror engine results and never redefines what a rig,
  pose, or frame means. Protocol logic is a pure
  `handle_request(session, request)` over dicts (format/protocol errors
  become typed `{ok:false,error:{code,message,path}}` envelopes, never a
  loop crash); an `evaluate` response's DOF values equal a direct
  `evaluate_pose` call, tested as a faithful passthrough. The engine also
  owns canonical **forward kinematics** (`animacore/kinematics.py`): a
  stdlib-only rigid `Transform` (unit quaternion `(x,y,z,w)`, real part
  last per RealityKit `simd_quatf`, plus a metre translation),
  `connector_frame`/`mate_motion`/`mate_offset_transform`/
  `child_in_parent`, and `resolve_pose(rig, pose)` walking the joint
  graph parents-before-children. Each mate moves the child relative to
  the parent about/along the **mate connector as the relative origin**
  per its DOF; at zero DOF/offset the child connector coincides with the
  parent connector with primary(Z) axes opposed, unless `flip_primary_axis` aligns
  them, plus a `secondary_axis_rotation_deg` twist. Roots (no parent
  joint) sit at identity. The bridge `resolve_pose` verb returns
  `{parts:{name:{position:[x,y,z], orientation:[x,y,z,w]}}}` — the
  RealityKit render hook. Studio now calls it for imports and every playhead
  update, maps the result to renderer-only part IDs, and applies those world
  transforms directly. The duplicate Swift `RigPoseResolver` and
  `MateConnectorMath` implementations and their semantic tests are removed.
  The engine also owns `.anima` **writing** (`animacore/serialize.py`) — the
  project-Save contract: `serialize_character` rebuilds a `Rig` from the full
  `load_character` rig DTO and emits canonical `.character.anima` text
  (radians→degrees, metres kept, defaults omitted, deterministic);
  `serialize_scene` emits `.scene.anima` from a scene document. Both validate
  (an invalid rig/scene is a `format_error`, so the app never writes a broken
  file). Round-trip is the acceptance test — `load → serialize → load` yields
  an equal rig/scene for every `examples/` file. To keep the round-trip
  lossless the `load_character` rig summary was additively enriched (clip
  `keyframes`, output ranges, per-DOF `axis_vector`/`name`/`description`,
  joint `description`; nothing renamed or removed).
  927 Python tests pass with `.venv/bin/pytest animacore/tests -q` (lint:
  `.venv/bin/ruff check .`), including end-to-end clip → FRM stream →
  simulated servo → failsafe, character file → rig evaluation →
  relation coupling → channel projection → simulated servo tests,
  rig evaluation → `OutputAdapter.send_frame` → simulated/UDP output
  tests, rig evaluation → serial bytes → simulated servo tests, and
  scene file → `SceneRunner` → simulated servo values at exact
  timestamps with logic-gate branching and monitor-driven e-stop.
- **What's stubbed:** every `*.example` file under `animacore/` —
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
  `.character.anima` and executes the `.scene.anima` v1+v2 subset; Studio
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
