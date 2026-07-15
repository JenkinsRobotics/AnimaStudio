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

Joint editing overlays—axes, limits, pivots, selection outlines, motion trails,
and constraint warnings—belong to the viewport adapter. Joint definitions,
limits, units, and animation values belong to `AnimaCore` and the `.anima`
document model.

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

The planned app is a Swift package graph hosted by a thin Xcode app target.
Dependency arrows point inward; the document model never imports a renderer or
hardware SDK.

```text
AnimaStudioApp
├── AnimaDocuments       document lifecycle, undo, validation, autosave
├── AnimaAuthoring       timeline, graph, expression and calibration tools
├── AnimaCore            format model, evaluator, curves, blending, constraints
├── AnimaViewport        renderer-neutral viewport contracts
├── RealityKitViewport   USD/USDZ and mechanical-rig 3D preview
├── Live2DViewport       Cubism/Metal digital-face preview
├── AnimaPluginAPI       capability descriptors and narrow extension contracts
└── AnimaRuntimeClient   offline/local/live JaegerOS preview sessions
```

`AnimaCore` should be usable from unit tests and command-line tools without
launching AppKit, SwiftUI, RealityKit, Cubism, or JaegerOS.

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
