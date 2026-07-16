# Hardware Animation Authoring — First Product Milestone

> **Status: planned, with a small working foundation.** Shipped truth is listed
> in [`../reality/STATUS.md`](../reality/STATUS.md).

## Goal

The first product goal is a usable native workspace for animating physical
audio-animatronic mechanisms. A creator brings in a model built in Blender,
SolidWorks, Onshape, or another DCC/CAD tool; identifies the movable pieces;
defines joints and limits; authors motion on a timeline; previews the result;
and saves a hardware-neutral Anima project.

Bottango is the primary workflow reference for this milestone: visual
structures, pivots, joints, motor mappings, keyframe/curve animation, media
tracks, and real-time preview. Anima is not a clone. Its core distinction is
that one semantic rig and evaluated frame can drive physical mechanisms,
screens, LEDs, and digital characters through replaceable outputs.

## Product boundary

Studio does:

- Import and organize existing 3D assets.
- Preserve and expose useful model hierarchy.
- Define semantic parts, parent/child relationships, pivots, and joints.
- Define neutral poses and position/velocity/acceleration limits.
- Author clips with tracks, keyframes, interpolation, and looping.
- Scrub and play motion in a kinematic 3D preview.
- Author synchronized audio, screen, LED, and event tracks in later slices.
- Map semantic joints to abstract actuator channels.
- Send evaluated target frames through an output adapter when explicitly armed.

Studio does not:

- Create or sculpt production meshes.
- Replace CAD assembly design.
- Simulate gravity, balance, loads, flexible bodies, or walking dynamics.
- Talk directly to motors from `AnimaCore` or the RealityKit viewport.

## Workspace layout

The initial workspace uses a stable, familiar arrangement:

```text
┌──────────────┬──────────────────────────────┬────────────────┐
│ Project tree │                              │ Inspector      │
│              │        3D viewport           │                │
│ Assets       │                              │ Part / joint   │
│ Structure    │                              │ properties     │
│ Joints       │                              │                │
│ Animations   │                              │                │
├──────────────┴──────────────────────────────┴────────────────┤
│ Transport  │ time ruler                                      │
│ Tracks     │ keyframes and curves                            │
└───────────────────────────────────────────────────────────────┘
```

The app has explicit modes because structural edits and animation edits have
different consequences:

- **Build:** import assets; organize parts; define pivots, joints, limits, and
  output mappings.
- **Animate:** select a clip; scrub/play; edit joint values and keyframes.
- **Show:** sequence clips, audio, expressions, screens, LEDs, and events.
  This mode follows after hardware animation is usable.

## Canonical data flow

```text
Project document
  ├── asset references
  ├── semantic part hierarchy
  ├── character rig / joints
  └── animation clips / tracks
                 │
                 ▼
          AnimaCore evaluator
                 │ EvaluatedFrame
        ┌────────┴─────────┐
        ▼                  ▼
RealityKit viewport   Output adapter
kinematic preview     hardware targets
```

The viewport never reads timeline widgets to determine a pose. Both viewport
and output consume the same `EvaluatedFrame`.

## Model import contract

The native import path accepts RealityKit-supported USD assets (`.usd`,
`.usda`, `.usdc`, `.usdz`, and `.reality`) plus STL and OBJ through ModelIO.
USD/USDZ is the preferred interchange from Blender or a CAD conversion
pipeline because it carries hierarchy and units. STL and OBJ are unitless;
Studio prompts for mm/cm/m, converts vertex positions to metres, and persists
that interpretation in app-only character editor metadata. STEP has no native
macOS mesh loader, so Studio presents an explicit export-to-STL-or-USD message
instead of pretending the file can render.

Import must:

1. Copy or bookmark the source according to the eventual project document
   policy; never silently depend on a temporary file URL.
2. Load asynchronously so the UI remains responsive.
3. Preserve the entity hierarchy and names.
4. Show structured diagnostics when an asset cannot be loaded.
5. Keep asset identity separate from an instance placed in the character.

Direct STEP, FBX, glTF/GLB, VRM, and URDF support requires future importer
adapters and is not part of the native slice.

## Core document concepts

- **Project:** metadata and references to characters, scenes, and assets.
- **Asset:** immutable imported source plus import settings.
- **Part:** a semantic instance of visual content in a parent/child hierarchy.
- **Joint:** motion relationship connecting a child part to its parent, with
  axis, pivot, neutral value, and explicit limits.
- **Actuator mapping:** maps a joint's semantic normalized/radian target to an
  output channel. It is not the joint itself.
- **Animation clip:** duration, loop mode, and one or more typed tracks.
- **Track:** values for one property/channel over time.
- **Keyframe:** time, value, interpolation, and later curve tangents.
- **Evaluated frame:** complete renderer-neutral state at one timestamp.

## Incremental delivery

### Slice 0 — foundation (shipped)

- Swift package and native app shell.
- Renderer-independent joint/clip/keyframe model.
- Hold and linear evaluation with joint-limit clamping.
- RealityKit sample mechanism and timeline scrubber.

### Slice 1 — workspace skeleton (foundation shipped)

- Build/Animate mode switch.
- Project navigator with Assets, Structure, Joints, and Animations.
- Central RealityKit viewport.
- Contextual inspector.
- Timeline with transport and track rows.

### Slice 2 — model import (portable rigid-part path shipped)

- Asynchronous USD-family, STL, and OBJ file import.
- Explicit STL/OBJ unit conversion to metres; honest STEP conversion guidance.
- Imported asset list and load diagnostics.
- Model hierarchy inspection and selection.
- Engine-authored per-part `model`/`model_node` references, portable asset copy,
  and restored per-part rendering after project reopen.
- Camera frame/reset controls.

### Slice 3 — mechanical rigging

- Create part instances from imported hierarchy nodes. (Basic persistent
  mapping shipped; reimport identity and topology reconciliation remain.)
- Configure pivot, axis, joint type, neutral pose, and limits.
- Manipulation gizmos and numeric inspector editing.
- Undo/redo for every structural edit.

### Slice 4 — animation editing

- Create, rename, duplicate, loop, and resize clips.
- Add/update/delete/select keyframes.
- Auto-key joint manipulation in Animate mode.
- Hold, linear, and Bézier interpolation with a graph editor.
- Play/pause/stop/loop transport with a stable frame clock.

### Slice 5 — first hardware loop

- Renderer-neutral `AnimationOutput` contract.
- Disabled-by-default simulator/log output proving frame routing.
- JaegerOS preview adapter with explicit connect and arm states.
- Telemetry, disconnect behavior, rate limiting, and emergency stop surfaced
  in Studio while lower-layer safety remains authoritative.

## Foundation acceptance criteria

The first milestone is complete when a user can:

1. Launch Anima Studio and create/open a project.
2. Import a model and inspect its hierarchy.
3. Define at least one revolute or prismatic joint between two parts.
4. Set its pivot, axis, neutral value, and limits.
5. Create an animation and keyframe that joint at multiple times.
6. Scrub and play the animation in the 3D viewport.
7. Save, close, reopen, and obtain the same project state.
8. Route the evaluated motion to a non-hardware test output.
9. Receive clear diagnostics for missing assets or invalid mappings.

Real hardware output follows only after this authoring path is deterministic,
persistent, undoable, and covered by evaluator fixtures.
