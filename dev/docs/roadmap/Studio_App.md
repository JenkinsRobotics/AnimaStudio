# Anima Studio App — Development Plan

> **Status: planned direction.** A small app/core/viewport foundation now
> exists, but most of this document remains unimplemented. Current
> implementation truth lives in
> [`../reality/STATUS.md`](../reality/STATUS.md).

## Product Goal

Anima Studio is not a JP01 configuration utility. JP01 is the first reference
character and hardware target.

The larger goal is to make Anima an animation engine and an open interchange
standard for embodied AI characters: robots, animatronics, VTubers, kiosks,
desktop companions, installations, games, and screen-only assistants. Studio
authors `.character.anima` and `.scene.anima` files, but those files must remain
usable without Studio and must outlive any particular renderer or robot.

The long-term test is simple: a creator should be able to author a performance
once, then send the same semantic animation to a digital face, a 3D character,
a physical body, lights, or all of them at the same time.

### Product principles

1. **The format is the durable product.** Studio is the best editor for the
   format, not the only software allowed to read it.
2. **One rig, many embodiments.** Digital and physical targets consume the same
   evaluated character state.
3. **AI is a tool, not a requirement.** Every scene can run deterministically
   without a model or network connection.
4. **Authoring and playback are separate.** Studio creates and previews;
   Anima Runtime performs headlessly.
5. **Safety is below animation.** Studio can preview limits, but a physical
   device layer always enforces its own authoritative limits.
6. **Capabilities are extensible.** Renderers, importers, devices, trackers,
   and authoring tools meet narrow interfaces instead of entering the core.

## What Is the Engine?

There is no single third-party game engine inside the app. The planned engine
is a small native stack:

| Responsibility | Planned technology | Owns |
|---|---|---|
| macOS application shell | SwiftUI with AppKit where needed | Windows, panels, commands, documents, inspectors |
| Anima animation engine | Pure Swift (`AnimaCore`) | Timeline time, curves, clips, blending, state machines, constraints, evaluated frames |
| 3D viewport engine | RealityKit | Model rendering, camera, lights, materials, skeletal pose display, selection/hit testing |
| GPU layer | Metal, normally through RealityKit | Actual GPU drawing; custom overlays and render passes only when needed |
| 2D character renderer | Live2D Cubism SDK for Native + Metal adapter | Cubism model loading, parameters, deformation, and drawing |
| Runtime/hardware bridge | JaegerOS client adapter | Preview commands, telemetry, and live target output |

RealityKit renders the 3D model, but it does **not** define Anima's animation
semantics. `AnimaCore` evaluates the timeline into a renderer-neutral
`EvaluatedFrame`; viewport and output adapters consume that frame. This keeps
scrubbing, offline export, runtime playback, and physical output consistent.

```text
.character.anima + .scene.anima
               │
               ▼
        AnimaCore evaluator
   time · curves · blend · constraints
               │
               ▼
          EvaluatedFrame
   blend shapes · joint poses · lights
       ┌───────┼─────────┬───────────┐
       ▼       ▼         ▼           ▼
  RealityKit  Live2D  Hardware    Inspector
  3D preview  face    preview     diagnostics
```

### Models and joints

For the first 3D viewport, Studio imports a USD/USDZ asset and builds a mapping
from Anima joint IDs to the asset's skeleton joint names. RealityKit draws the
mesh and applies skeletal poses. `AnimaCore` supplies the desired local joint
transforms in radians/metres, and the RealityKit adapter converts those values
to the model skeleton.

Rigid robots that do not use a skinned mesh are represented as a hierarchy of
entities: one entity per link, parented at each joint pivot. Revolute and
prismatic joint components apply rotation or translation to their child link.
The same `EvaluatedFrame` therefore supports both organic skeletal characters
and mechanical URDF-style robots.

Studio deliberately presents two related hierarchies without conflating them:

1. The **source-model hierarchy** is imported from Blender, CAD, or another
   authoring tool. It is selectable and searchable, but its nodes, ordering,
   pivots, and materials are source-owned and read-only in Studio. Source rows
   use a blue model icon plus a lock label; color is not the only cue.
2. The **semantic-rig hierarchy** contains Anima parts, typed mate connectors,
   joints, and animatable DOFs. It is project-owned. This is the hierarchy that
   Rig may rename, duplicate, drag to reparent, and edit with undo once durable
   semantic parts ship. Parts and joints use distinct icon-plus-label roles.

Mapping bridges the two layers. A semantic part may collect multiple source
nodes so a detailed imported subtree can behave as one rigid link; a source
node may drive at most one semantic part instance at a time. Imported nodes are
never directly reparented as a side effect of Rig editing. Viewport, navigator,
timeline, graph, and inspector selection all resolve through stable project and
source identities rather than retaining a transient RealityKit entity pointer.

Reimport synchronization requires a durable asset identity, a restorable source
bookmark, and source-node identities. It must reconcile moved, added, deleted,
and renamed nodes, preserve valid semantic mappings, and report ambiguous or
broken mappings before committing changes. A temporary sibling-index path is
adequate for current inspection but is not the final synchronization identity.
Materials remain authored in the source application and rendered from the
imported asset; a future non-destructive Studio override layer must not pretend
to be a shader editor or silently rewrite the source file.

### CAD viewport interaction contract

The default desktop navigation follows the common Onshape/SolidWorks family of
controls while retaining native macOS trackpad gestures:

- right-button drag orbits/tilts the camera around its target;
- middle-button drag pans, with Control + right-button drag as an Onshape-style
  alternative;
- scroll and pinch zoom toward the pointer, and camera preset buttons provide
  Home, Front, Right, and Top views;
- primary-button click selects geometry, and primary-button drag is reserved
  for a visible transform or DOF handle rather than camera navigation.

The current RealityKit viewport uses a narrow AppKit input adapter over its
RealityKit camera so the mapping is explicit and testable. The user-local mouse
profile offers Default, SolidWorks, Onshape, Fusion 360, and Custom. Default
uses the Onshape-style right-drag orbit, middle-drag pan, and wheel zoom.
SolidWorks uses middle-drag orbit plus Control- or Shift-middle-drag pan;
Fusion 360 uses Shift-middle-drag orbit plus middle-drag pan. Custom exposes
separate rotate and pan drag bindings and prevents the two actions from owning
the same chord. Trackpad two-finger movement pans and pinch zooms in every
profile. Navigation preferences never enter project data.

The viewport camera is represented by one presentation-state contract:
orientation, look-at target, perspective distance, orthographic scale, and
projection. The RealityKit adapter reports that state after every orbit, pan,
or zoom, so camera overlays never maintain a second approximation of the view.
The view cube projects its labels from that same orientation and supports the
standard CAD navigation vocabulary:

- clicking a face selects one of the six principal plane views;
- clicking an edge selects the corresponding two-axis view;
- clicking a corner selects the corresponding trimetric view;
- the surrounding arrows rotate the current view in 15-degree increments.

Visible face names behave like fixed decals anchored at each projected face
center. Each decal has one face-local orientation: it follows its face but is
never dynamically reoriented for readability, clipped, or scaled. Pointer hover
previews the exact face, edge, or corner that a click will select. The
embedded XYZ triad shares one visible origin and projects only the positive X,
Y, and Z directions through the same camera basis, so its directions remain
synchronized with the cube rather than acting as a static legend.

Camera and render controls are intentionally split from the RealityKit scene
implementation. `PreviewCameraState` owns renderer-facing camera data,
`ViewCubeGeometry` owns projection and hit testing, `ViewportViewCube` owns the
SwiftUI presentation, `ViewportRenderMenu` owns user choices,
`ViewportCameraHUD` composes those controls, and `ViewportLighting` owns the
RealityKit light rigs. This keeps the view cube independently testable and
prevents the workspace shell from becoming a single monolithic UI file.

The direct Display menu beside the cube exposes Perspective/Orthographic
projection, 30–90° perspective field-of-view presets, Frame Selection, grid
visibility, viewport appearance, mouse profile, Shaded/Wireframe/Translucent
surface modes, independent mesh-edge visibility, and Balanced/Soft/Bright/High
Contrast two-light rigs. “Mesh Edges” means RealityKit triangle mesh lines; it
is not a promise of CAD feature-edge classification. Projection, surface, edge,
lighting, field of view, appearance, grid, mouse profile, and custom mouse
bindings are user-local presentation preferences and do not alter the project
document. Hidden-line removal, section views, roll controls, and saved named
views require dedicated geometry/camera contracts and remain future work rather
than inert menu items.

Semantic-part selection is one identity shared by the viewport, Parts tree,
and inspector. A selected proxy receives a high-contrast orange silhouette and
a local XYZ transform gizmo. Dragging a translation arrow edits the part's rest
position in metres; dragging a rotation ring edits its XYZ rest orientation in
radians. Evaluated joint motion composes on top of that rest orientation.
Imported source nodes remain selectable but read-only until they are explicitly
mapped to semantic parts.

Every semantic part owns a local origin. A newly created standalone part begins
with that origin coincident with the workspace origin `(0, 0, 0)`; the user then
places it with the transform gizmo or numeric inspector. Imported assemblies
preserve each source node's authored local origin and relative transform when
mapped, while the imported assembly root begins at the workspace origin. Studio
must not silently recenter individual imported links because mate connectors,
pivots, and animation all depend on those source-space origins.

Selection granularity is staged deliberately:

1. **Part** selection uses entity collision shapes and is the current authoring
   mode.
2. **Face** selection will use RealityKit triangle-hit metadata and preserve a
   stable reference to the selected mesh part/primitive through reimport.
3. **Edge** selection additionally requires mesh topology, adjacent-face
   analysis, and a screen-space proximity threshold. It must not be simulated
   by naming arbitrary triangles “edges.”

Face and edge references are advisory geometry references for connector
placement; durable rig meaning lives in explicit semantic connector transforms.

Joint editing overlays—axes, limits, pivots, selection outlines, motion trails,
and constraint warnings—belong to the viewport adapter. Joint definitions,
limits, units, and animation values belong to `AnimaCore` and the `.anima`
document model.

### Mate connectors and DOF handles

The Rig workspace visualizes each typed joint through a mate-connector frame,
inspired by Onshape's compact assembly relationship model rather than a stack
of unrelated constraints. The connector establishes an origin and local X/Y/Z
orientation; the mate type determines which degrees of freedom remain
interactive. RealityKit draws and hit-tests these guides, while AnimaCore owns
the connector transforms, mate type, DOFs, units, neutral values, and limits.

| Mate type | Viewport visualization |
|---|---|
| Fastened | Connector frame only; all six relative DOFs locked |
| Revolute | Rotation ring around the primary axis, neutral tick, current marker, and shaded angular limits |
| Prismatic | Linear arrow/rail on the primary axis with neutral, current, minimum, and maximum markers |
| Cylindrical | Coaxial rotation ring and translation rail, independently selectable |
| Ball | Three rotation rings sharing one origin, with orientation/limit envelope when defined |
| Planar | Translucent reference plane with two in-plane translation handles and any permitted normal-axis rotation |

Visual rules:

- X, Y, and Z use a consistent accessible color-plus-label vocabulary; color is
  never the only indication.
- Connector and handle size remains readable in screen space as the camera
  zooms. Occluded guides dim or use a deliberate x-ray treatment rather than
  disappearing unpredictably inside geometry.
- Hover identifies one available DOF; selection emphasizes its complete handle
  and matching inspector row. Dragging previews only that DOF unless a compound
  mate explicitly exposes more than one.
- Limit arcs, rails, or plane bounds show the legal authored range. Neutral,
  current, and dragged target states are distinct; approaching a limit warns,
  and invalid targets never silently extend the limit.
- Connector placement mode may expose inferred candidate origins/axes from
  imported geometry, but the resulting semantic connector is explicit and
  editable numerically. Reimport synchronization must not rely only on a
  transient RealityKit entity pointer.
- A virtual “exercise DOF” preview is always safe and never drives hardware.
  Physical mirroring still requires a separately connected and armed output.

The current sample rig implements the first visual foundation: a local XYZ
connector, revolute ring, optional reference plane, and limit arc with
independent visibility toggles. Editable handles and imported-part attachment
follow the shared typed-joint/DOF contract.

### Why not SceneKit, Unity, or Unreal?

- **SceneKit:** unsuitable for a new long-lived app because Apple has
  deprecated it in favor of RealityKit.
- **Unity/Unreal:** useful future output or bridge plugins, but embedding one as
  Studio's foundation would add a second application runtime, weaken native
  macOS document/UI behavior, and couple the `.anima` engine to a vendor.
- **Raw Metal:** available for specialized rendering, but too low-level for the
  initial model viewport. RealityKit already supplies the scene, material,
  camera, animation, and interaction layer above Metal.

## Application Architecture

The app is a local Swift package graph hosted by a thin native Xcode app target.
The checked-in project is generated from `studio/project.yml`; build settings
live in `.xcconfig` files rather than being scattered through the project file.
Dependency arrows point inward, and the document model never imports a renderer
or hardware SDK.

```text
AnimaStudioApp            @main lifecycle, resources, signing, entitlements
└── AnimaStudioUI         app shell, workspaces, panels, timeline presentation
    ├── AnimaCore         project model, evaluator, curves, constraints
    └── RealityKitViewport
        ├── AnimaViewport renderer-neutral viewport contracts
        └── AnimaCore
```

The current source tree groups `AnimaStudioUI` by `AppShell`, `Components`,
`Theme`, `PreviewSupport`, and task-focused `Workspaces`. Unit-test folders
mirror those groups. Xcode's Canvas opens a preview catalog for the home,
complete-workspace, and animation-timeline states; the native app target also
has a launch-level UI-test target. This keeps the operator-facing GUI editable
in normal Xcode/SwiftUI workflows while retaining command-line SwiftPM tests.

Future proven boundaries such as `AnimaDocument`, `Live2DViewport`,
`AnimaPluginAPI`, and `AnimaRuntimeClient` should become separate targets only
when their first implementation lands. `AnimaCore` remains usable from unit
tests and command-line tools without launching AppKit, SwiftUI, RealityKit,
Cubism, or JaegerOS.

### Core evaluated frame

The central output is renderer-neutral and uses explicit units:

```swift
struct EvaluatedFrame: Sendable {
    let timeS: Double
    let blendShapes: [BlendShapeID: Float]  // normalized 0...1
    let jointPoses: [JointID: JointPose]     // radians and metres
    let lightStates: [LightID: LightState]
    let activeEvents: [AnimationEvent]
}
```

The Studio preview clock and Runtime clock may have different implementations,
but they must pass the same evaluator conformance fixtures for a given format
version.

## Plugin Architecture

The architectural goal is that Studio depends on capability interfaces, not a
catalog of vendors. “Everything is a plugin” means replaceable boundaries; it
does not mean every first-party feature must begin as a separately distributed
binary.

### Plugin capability families

| Family | Examples | Contract shape |
|---|---|---|
| Renderer | RealityKit, Live2D, VRM, Unity bridge, Unreal bridge | Load asset; accept evaluated frames; render; hit-test |
| Import/export | USD, glTF, VRM, URDF, audio, motion capture | Probe; import/export; report diagnostics |
| Physical output | JaegerOS, Dynamixel, CAN, DMX, LED matrix | Describe channels; accept safe target frames; report telemetry |
| Input/tracking | ARKit, MediaPipe, OpenCV, OpenXR, Leap Motion | Publish timestamped observations in canonical coordinates |
| Authoring tool | lip sync, motion cleanup, retargeting, AI generation | Transform selected document data through undoable commands |
| Validation | format, rig, target compatibility, physical safety preview | Inspect snapshot; return structured diagnostics and fixes |

### Staged implementation

1. **Internal protocols first.** RealityKit and a mock renderer prove the
   viewport contract; JaegerOS and a simulator prove the output contract.
2. **First-party Swift packages second.** Keep implementations independently
   testable while the contracts are still changing.
3. **External plugins after two real implementations.** Freeze a versioned
   manifest and capability API only after the boundary has evidence.
4. **Process isolation for third parties.** Prefer XPC or a supervised helper
   process for untrusted/native plugins. Do not load arbitrary third-party code
   into the document process by default.
5. **Permissions are explicit.** A plugin declares file, network, hardware,
   camera, microphone, and live-motion needs before activation.

A future plugin manifest should include a stable identifier, semantic version,
minimum Studio/API versions, capability list, entry point, permissions, and
supported asset or channel types. That manifest is intentionally not frozen in
the first milestone.

## Primary Workspaces

Studio uses task-focused workspaces in the same sense as professional CAD,
animation, and image-editing applications. A workspace is a presentation of
one open project, not a separate document or data model. Switching workspaces
changes the contextual header, available commands, panel arrangement, and
default editor while preserving the project, undo history, and shared
selection whenever that selection remains meaningful.

### Planned built-in workspaces

| Workspace | Primary task | Contextual header and default layout |
|---|---|---|
| Assets | Import, inspect, relink, and organize source files | Import/relink tools; asset browser + large preview + metadata inspector |
| Rig | Build semantic parts, typed joints/DOFs, pivots, limits, and hierarchy mappings | Create/join/transform tools; Parts tree + 3D viewport + rig inspector |
| Animate | Author poses, clips, keys, curves, and recorded motion | Transport/auto-key/interpolation tools; viewport + timeline/graph + animation inspector |
| Show | Arrange character clips, audio, screens, lights, events, and scene logic | Show transport/trigger tools; multi-track scene timeline + cue/logic panels |
| Hardware | Map outputs, calibrate, test, monitor, and arm physical targets | Connection/calibration/safety tools; mapping table + telemetry + guarded live controls |

The window chrome has two layers:

1. A stable global header for project identity, save/open, undo/redo, workspace
   switching, connection state, and the guarded Master Live control.
2. A workspace-owned contextual header for the active task's tools. Rig shows
   part/joint tools; Animate shows transport and keying tools; Hardware shows
   connection, calibration, and safety actions.

Each built-in workspace declares a stable identifier, title/icon, contextual
commands, allowed panels, default layout, and capability requirements. Panel
sizes and visibility are restored per workspace. Those layout preferences are
user-local by default so opening a project does not overwrite another person's
preferred arrangement; explicit shareable layout presets may be added later.
Plugins may eventually contribute panels and commands to compatible
workspaces, but the initial descriptor contract is proven by built-in
workspaces first.

Workspace switching must not duplicate editor state. The document remains the
single source of truth; workspace views hold only transient presentation state
such as panel visibility, split positions, viewport camera, and the locally
focused editor. Import is allowed to begin as the existing workspace tab, then
become the Assets workspace without changing project semantics.

### Context and interaction rules

- Available commands are the intersection of the active workspace, current
  selection, loaded capabilities, and safety state. The contextual header does
  not show irrelevant controls. Tooltips describe the action, shortcut, units,
  and disabled reason.
- Rig owns structural editing. Animate may select and pose parts/DOFs but cannot
  silently create, delete, reparent, or redefine the rig.
- The Parts tree, 3D viewport, timeline tracks, graph curves, and inspector use
  one shared selection identity. A single selection opens its typed inspector;
  multiple selection exposes only valid common operations.
- The Parts tree groups semantic rig content separately from the read-only
  source model. Search keeps matching descendants and their ancestors visible.
  Locked source rows can be selected and framed but cannot accept reparent
  drops; only semantic parts expose hierarchy-editing affordances.
- The inspector uses progressive disclosure: human-readable common fields
  first, type-specific geometry/DOF/output controls second, and diagnostics or
  raw identifiers last.
- Numeric controls support exact keyboard entry and unit labels. Frequently
  adjusted values should later support label-drag scrubbing, fine/coarse
  modifiers, and reset-to-authored/default actions without sacrificing exact
  text editing.
- Animate's bottom editor switches between a dope sheet for timing/track
  membership and a graph editor for time, value, and interpolation. Both remain
  synchronized with viewport and tree selection. Media waveforms stay in the
  dope sheet rather than cluttering the motion graph.
- The first graph implementation may visualize the existing hold/linear curves
  read-only while the document and undo layers are built. Editing key time,
  value, interpolation, tangents, ranges, markers, media, or events must not be
  presented as working until each operation mutates the durable project model.
- Timeline truth is continuous seconds in AnimaCore. Frame notation is a
  configurable display/editing grid (for example 24, 25, 30, or 60 fps), never
  a hard-coded evaluation rate or hardware update rate.
- Hardware visualization is offline by default. Connecting does not arm;
  viewport manipulation and timeline scrubbing affect real hardware only after
  explicit arming. Live seeks use bounded transitions and remain subordinate to
  device limits, failsafes, and emergency stop.
- Hardware diagnostics provide searchable/filterable incoming, outgoing,
  informational, warning, and error messages, with freeze, clear, copy, and
  export actions. Raw traffic is a diagnostic view, not the primary workflow.
- Studio may provide simple proxy geometry for rig readability, but it is not a
  mesh or CAD modeler. Production models continue to come from Blender,
  SolidWorks, Onshape, and other dedicated tools.
- The primary viewport is kinematic. Physics/dynamics simulation remains
  deferred and must not leak into the first authoring contracts.

The long-term creative environment includes:

- Project and asset browser
- Character and rig editor
- Expression lab
- Animation clip editor
- Multi-track scene timeline and curve editor
- Logic graph, state machine, and behavior tools
- Audio and lip-sync editor
- Servo calibration and LED designer
- 3D, digital, simulated, and live-hardware previews
- Variables, event inspection, simulation console, and profiler
- Plugin manager and asset/package browser

The first release should not attempt all of them. Its vertical slice is:

1. Open and validate one `.character.anima` file.
2. Import one USD/USDZ robot or character model.
3. Map named Anima joints to model joints.
4. Edit a joint value and see the RealityKit viewport update.
5. Save an expression or pose with undo/redo.
6. Open a minimal `.scene.anima` timeline and scrub it through the same
   evaluator.
7. Send the evaluated frame to a simulator adapter; no real hardware is
   required for the first slice.

## Physics and Safety Preview

Constraints are engine inputs, not renderer behavior. Planned constraint types
include joint position/velocity/acceleration limits, planted contacts,
self-collision, balance/center-of-mass guidance, smoothing, and workspace
limits. Digital and physical previews consume the same constrained frame.

Studio diagnostics are advisory. The JaegerOS/body safety layer remains
authoritative and may clamp or reject any live target regardless of what Studio
previewed.

## Future AI Authoring

AI features operate through the same undoable authoring-command interface as a
human tool. Examples include generating idle motion, animating to audio or
video, changing emotional intent, retargeting motion, and producing a
physical-safe variation. Generated results become ordinary editable `.anima`
data; the file format and playback engine never require the generating model.

## Acceptance Goals for the Foundation

- A document produces identical evaluated fixture frames in Studio and Runtime
  within defined numeric tolerances.
- The same timeline drives a RealityKit preview and a mock physical target
  without renderer-specific branches in `AnimaCore`.
- Missing assets, unmapped joints, invalid limits, and unsupported plugin
  capabilities produce structured diagnostics rather than crashes.
- Scrubbing is deterministic, undoable edits never mutate saved files until a
  document save, and all live output is opt-in.
- No renderer, hardware vendor, tracker, or AI provider becomes part of the
  `.anima` core schema merely because its first adapter ships early.
