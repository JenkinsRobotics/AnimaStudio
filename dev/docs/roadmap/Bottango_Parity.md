# Bottango workflow parity map (planned)

> Bottango is the workflow reference for physical character authoring, not a
> code or product template. This map follows the sections in the current
> [Bottango documentation](https://docs.bottango.com/) so agents can implement
> and review one bounded capability at a time. Shipped truth remains in
> [`../reality/STATUS.md`](../reality/STATUS.md).

## Product bar

Bottango describes its core loop as expressing artistic intent on real
hardware through 3D structures, joints, keyframe/Bézier animation, and live
hardware drivers. Anima must reach that usability bar while preserving its own
architecture:

- one semantic rig for physical motion, digital characters, screens, and LEDs;
- an open `.anima` format and headless runtime;
- hardware adapters below renderer-neutral animation;
- JaegerOS integration and safety boundaries;
- no dependency on Studio for offline playback.

## Status legend

- **Shipped:** implemented and recorded in `STATUS.md`.
- **Foundation:** a real implementation exists but the user workflow is
  incomplete.
- **Planned:** accepted scope with no shipped implementation.
- **Deferred:** intentionally outside the current milestone.

## Documentation-section backlog

Each ID is an assignable/reviewable work packet. A packet is complete only when
its user flow, tests, and `STATUS.md` update land together.

| ID | Bottango documentation area | Anima deliverable | Home | Status / dependency |
|---|---|---|---|---|
| B01 | Workspace & UI | Project home; Build/Animate/Show/Hardware modes; contextual tools; camera/orbit; selection; inspector; save/load/save-as; dirty state; autosave/recovery; undo/redo | `AnimaStudioApp`, document layer | **Foundation:** Build/Animate shell, tree, viewport, inspector exist. Persistence, dirty state, autosave, undo/redo planned. Must finish before hardware authoring. |
| B02 | Structures | Semantic parts as animation controls; imported or primitive visual stand-ins; transforms; pivots; home pose; parent/child hierarchy; duplicate/delete/reparent | `AnimaCore` rig model + Studio Build mode + viewport | **Planned.** Imported assets exist, but model nodes cannot become persistent semantic parts. Depends on B01 persistence. |
| B03 | Joints | Revolute and prismatic joints first; parent/child connection; axis; pivot; neutral; min/max; offsets; duplicate assemblies; viewport gizmos | `AnimaCore`, `RealityKitViewport`, Build inspector | **Foundation:** scalar joint definition and clamping exist. Editing, hierarchy binding, joint types, pivots, and gizmos planned. Depends on B02. |
| B04 | Motors / actuator mapping | Separate semantic joints from output channels; normalized mapping; inversion; neutral/home; signal range; velocity limit; resolve conflicting home values | format mapping + runtime output config + Studio Hardware inspector | **Planned.** Must not put servo pins or pulse widths in core timeline data. Depends on B03 and the shared output contract. |
| B05 | Hardware drivers | Add/remove/connect drivers; explicit arm/disarm (Master Live equivalent); status; multiple/network devices; logs; heartbeat; failsafe; emergency stop | Studio Hardware mode + `AnimationOutput` + runtime/firmware | **Lane B foundation in progress:** Wire Protocol v0 and Python simulator. Studio connection UI planned. Depends on B04 and protocol proof. |
| B06 | Animating | Clip management; duration/loop; tracks; dope sheet; auto-key; select/move/copy/delete keyframes; playback; frame/time display; graph view; Bézier handles; interpolation modes; speed warnings | `AnimaCore` + timeline/graph views | **Foundation:** clips, tracks, hold/linear evaluation, transport, keyframe display, scrubbing. Editable keys, auto-key, Bézier/graph view, undo, and limit warnings planned. Depends on B01–B03. |
| B07 | Audio & video | Import/copy/bookmark media; waveform/video preview; typed media tracks; trim/offset; synchronized playback; choose host versus on-device audio | asset/document layer + AVFoundation + scene actions | **Planned.** Begin only after B01 and B06 persistence/timing are stable. |
| B08 | Supported motors & effectors | Hobby servo first; PCA9685 bank, stepper, DYNAMIXEL, custom channels, and custom/media events as adapters | runtime + firmware plugins/adapters | **Planned.** First physical acceptance target is one hobby servo; expand only after B05 proves the generic channel contract. |
| B09 | Recording & puppeteering | Input/control schemes; live manipulation; record to tracks; overwrite/layer modes; smoothing; microphone/audio capture | Studio input adapters + timeline authoring commands | **Planned later.** Depends on editable B06 tracks and safe B05 live output. |
| B10 | Exporting animations | Select characters/clips/assets/output profiles; validate dependencies; package `.anima` content; playback/trigger rules; deploy to headless runtime | document exporter + Anima Runtime | **Format foundation:** formats are planned/spec'd; executable export/runtime planned. Depends on B01, B06, B07, and runtime loader. |
| B11 | Advanced mechanisms | Named target poses; pose blending/mixers; kinematic constraints; look-at/reach; inverse kinematics; velocity/acceleration-aware motion planning | `AnimaCore` authoring/evaluation | **Planned later.** Physics/dynamics remains deferred; these features are kinematic. |
| B12 | Importing 3D models | USD-family import; hierarchy browser; preserve/collapse nodes; instantiate nodes as parts; assembly mapping; reimport synchronization; clear diagnostics | asset importer + RealityKit viewport + Build mode | **Foundation:** USD/Reality files load and normalize in viewport. Hierarchy inspection, mapping, persistence, reimport, and diagnostics planned. B12 hierarchy mapping is the next Studio slice. |
| B13 | External control | Runtime commands/events through JaegerOS; external play/stop/set-expression; LTC/timecode adapter where useful; explicit hardware-control permissions | JaegerOS client/runtime + optional adapters | **Planned later.** Anima uses the JaegerOS protocol/bus as its primary external-control surface rather than cloning Bottango's REST API. |

## Required behavior within each area

### B01 — Workspace and project durability

- The native project is a versioned `.animastudio` package containing a
  deterministic `project.json` manifest and package-owned `Assets/`; archive
  encoding and validation live outside `AnimaCore` in `AnimaDocument`.
- A native project document opens, saves, saves as, and reopens identically.
- Assets are project-relative or security-scoped/bookmarked; session-only URLs
  are not considered persistence.
- Structural and animation edits participate in undo/redo.
- Unsaved state, autosave, recovery, missing assets, and load failures are
  visible rather than silent.
- Mode changes alter the available tools without creating separate data models.

### B02–B04 — Structure, joints, and outputs

```text
Imported asset node       semantic part       semantic joint       actuator map
(appearance/hierarchy) -> (Anima identity) -> (motion/limits)   -> (device channel)
```

These are four different concepts. A model node may be collapsed or instanced;
a joint remains meaningful with no hardware; an actuator mapping can change
without rewriting animation.

### B06 — Timeline and graph editor

The dope sheet edits event time and track membership. The graph editor edits
time, value, and interpolation. Planned interpolation must cover:

- hold and linear;
- cubic Bézier with explicit in/out handles;
- linked smooth handles, auto-smooth handles, and broken handles;
- deterministic clamping and fixture parity between Swift and Python;
- visual velocity/acceleration limit warnings without silently changing the
  authored curve.

### B05/B08 — Safe live hardware loop

```text
AnimaCore EvaluatedFrame
          │
          ▼
AnimationOutput (renderer-neutral contract)
          │ normalized channel targets
          ▼
Wire Protocol host → device/firmware → actuator
```

Connecting is not arming. Arming is explicit, visible, reversible, and always
subordinate to device/runtime failsafes. Studio never becomes the only safety
layer.

## Delivery order and gates

1. **P0 — Durable workspace:** finish B01 project persistence, dirty state,
   errors, and undo foundation.
2. **P1 — Build a rig:** finish B12 hierarchy inspection, then B02 semantic
   parts and B03 editable joints.
3. **P2 — Animate the rig:** finish B06 editable keys, auto-key, Bézier
   evaluation, graph view, and speed warnings.
4. **P3 — Move one servo safely:** finish B04 mappings, B05 output/connection
   UX, and the first B08 hobby-servo adapter against Wire Protocol v0.
5. **P4 — Author complete performances:** B07 media, screens/LEDs, show tracks,
   and runtime scene execution/export (B10).
6. **P5 — Extend:** B09 recording/puppeteering, B11 advanced kinematics, more
   B08 adapters, and B13 external/timecode integrations.

No later phase should force an earlier semantic contract into a vendor-specific
shape. A capability may be prototyped early, but it does not pass its gate until
the preceding user workflow is deterministic, persistent, and tested.

## What Anima intentionally adds beyond Bottango

- Open application, runtime, firmware, and format—not only open firmware.
- Digital avatar, physical mechanism, screen, LED, audio, and lighting outputs
  from the same evaluated performance.
- Headless `.anima` playback and show-control logic.
- Optional AI authoring and triggering without AI-required playback.
- Replaceable output/import/input adapters with stable core semantics.
