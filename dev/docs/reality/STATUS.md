# STATUS

> Truthful, or it's worthless. Any commit that changes behavior updates
> this file in the same commit — see `CONVENTIONS.md` → "STATUS stays
> truthful."

## Current state — 2026-07-14

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
  rest transforms, joint parent/child connections, joint rigs,
  clips, hold/linear keyframes, deterministic evaluation, neutral fallback,
  time clamping, joint-limit clamping, and Codable project round-tripping. The
  SwiftUI app launches into a Bottango-inspired dark home screen with a working
  New Studio Project action and honestly disabled project-open/templates until
  persistence ships. A new project now opens as a genuinely empty Rig rather
  than silently inserting the sample mechanism. Its Bottango-inspired **Add to
  Rig** palette creates real core-backed box, cylinder, sphere, and empty-point
  proxy components with their local origin at the workspace origin, then
  creates a first Revolute Mate for the selected unconnected component.
  Component names, XYZ positions, XYZ rest rotations, and mate names, axis,
  parent/child
  connection, and angular limits are inspectable/editable in memory. Motors,
  extra joint insertion, 3D Models & Media, and Events are present as clearly
  disabled reference groups rather than fake working features. Its project
  window now has task-focused Assets, Rig,
  Animate, Show, and Hardware workspaces with Command-1…5 switching, a stable
  global project/live bar, workspace-owned contextual tools, and independently
  restorable in-session navigator/inspector/bottom-panel visibility. Assets
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
  lighting rigs. These settings persist as user-local presentation preferences
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
  rings at its origin; dragging them edits the core-backed rest transform, and animated
  mate rotation composes on top. The Components outline follows macOS file-browser
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
  inspector. Seventy-one tests pass with `cd studio && swift test`, including real
  USD hierarchy loading/projection through RealityKit, duplicate/unnamed entity
  identity coverage, hierarchy filtering/ancestor retention, frame timecode and
  stepping, adjacent-key navigation, and loop/non-loop playback. The Python
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
  loads `.character.anima` files (`anima_studio/loader.py` — version/type
  check, typed errors naming the offending path, unknown-field rejection;
  unsupported spec sections — expressions, lip_sync, digital, voice,
  blend_shape/led mappings, smoothing, easing — are rejected loudly, never
  silently dropped) into a rig-aware model (`anima_studio/rig.py` — joints
  with radian ranges and neutrals, blend shapes, hold/linear clips with
  neutral fallback for every unanimated parameter, loop wrapping, and the
  joint→normalized 0..1 servo-channel projection feeding `wire.encode_frm`);
  `examples/jp01_minimal.character.anima` is a loadable minimal head rig.
  144 Python tests pass with `.venv/bin/pytest anima_studio/tests -q` (lint:
  `.venv/bin/ruff check .`), including end-to-end clip → FRM stream →
  simulated servo → failsafe, and character file → rig evaluation →
  channel projection → simulated servo tests.
- **What's stubbed:** every `*.example` file under `anima_studio/` —
  `module.yaml`, `config.py`, `node.py`, the module-contract test —
  these are the JaegerOS-module shape for later
- **Known gaps:** imported model hierarchies can be inspected and filtered but
  still use temporary sibling-index paths; durable source identity, security
  bookmarks, reimport reconciliation, collapse, and mapping to persistent
  semantic parts are not implemented. Source nodes are intentionally locked,
  and semantic-part drag reparenting waits for the persistent part/undo model.
  The mate guides currently visualize the created revolute joints but their
  DOF/connector handles are not yet editable or attached to imported source
  nodes; the shipped part transform gizmo edits only semantic-part rest
  transforms. Part selection is entity-level; durable face selection still
  needs triangle identity through reimport, and true edge selection still needs
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
  `.character.anima` only; `.scene.anima` is unimplemented everywhere), no
  editable Bézier curves/handles, audio, screens/LEDs, Live2D, scene execution, output
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
