# Anima — Technical Architecture

---

## The Three-Layer Model

```
┌──────────────────────────────────────────────────────────┐
│  AUTHORING LAYER                                         │
│                                                          │
│  Anima Studio (Swift / macOS)                            │
│  ├── Character editor                                    │
│  ├── Scene timeline (keyframes, curves, audio)           │
│  ├── Expression preset builder                           │
│  ├── Digital preview (Live2D / VRM)                      │
│  ├── Physical preview (3D robot model)                   │
│  └── Live runtime connection (for hardware preview)      │
└────────────────────────────┬─────────────────────────────┘
                             │ .anima files (character + scene)
┌────────────────────────────▼─────────────────────────────┐
│  RUNTIME LAYER                                           │
│                                                          │
│  Anima Runtime (JaegerOS module — AnimaNode)             │
│  ├── Character loader and rig evaluator                  │
│  ├── Scene executor (JaegerOS action)                    │
│  ├── Expression state machine                            │
│  ├── Lip sync processor (/sense/tts_chunk → visemes)     │
│  ├── Logic gate engine (wait_for / if / parallel)        │
│  └── Output router → JaegerOS bus topics                 │
└───────────┬──────────────────────────────┬───────────────┘
            │ /act/blend_shapes            │ /act/joint_targets
            │ /act/led_state               │ /act/led_state
┌───────────▼───────────┐    ┌─────────────▼───────────────┐
│  DIGITAL OUTPUT       │    │  PHYSICAL OUTPUT             │
│                       │    │                              │
│  DigitalOutputNode    │    │  PhysicalOutputNode          │
│  ├── Live2D renderer  │    │  ├── Blend shape → servo map  │
│  ├── VRM renderer     │    │  ├── Joint angle targets      │
│  └── Custom plugin    │    │  └── Publishes to hardware   │
│                       │    │      nodes via bus            │
└───────────────────────┘    └──────────────────────────────┘
```

---

## Where Anima Lives in the Jaeger Stack

```
Layer 2 — Application / Mind
    JaegerAI calls animation.play(), animation.set_expression()

Layer 3 — Module packages
    JaegerAnima package: declares animation slot, factory, topics

Layer 4 — Running nodes
    AnimaNode: scene executor, rig evaluator, output router
    DigitalOutputNode: Live2D / VRM rendering
    PhysicalOutputNode: servo / motor mapping

Layer 5 — JaegerOS framework
    Bus: transports /act/blend_shapes, /act/joint_targets, /act/led_state
    Supervisor: manages AnimaNode lifecycle

Layer 6 — Device adapters
    (PhysicalOutputNode publishes to MotionNode / LightNode,
     which handle the hardware protocol layer)
```

---

## Anima Runtime — Module Specification

### module.yaml

```yaml
module: anima_runtime
slot: animation
version: 1.0.0

subscribes:
  - /act/animation          # AnimationCommand — play scene or clip
  - /act/animation_stop     # AnimationStop — halt playback
  - /sense/tts_chunk        # TtsChunk — lip sync input

publishes:
  - /sense/animation_state  # AnimationState — current playback status
  - /act/blend_shapes       # BlendShapeFrame — per-frame face data
  - /act/joint_targets      # JointTargetFrame — per-frame body data
  - /act/led_state          # LedState — LED color and pattern

tools:
  - animation_play
  - animation_stop
  - animation_set_expression
  - animation_list_clips
  - animation_load_character

factory: jaeger_anima.runtime:make_anima_node
config: anima_runtime
```

### AnimaNode Internals

```
AnimaNode
├── CharacterLoader
│     loads and validates .character.anima files
│     maintains active character rig in memory
│
├── RigEvaluator
│     interpolates keyframes
│     blends expression presets
│     applies viseme overrides from lip sync
│     outputs blend shape + joint frames at target rate (30–60 Hz)
│
├── SceneExecutor
│     reads .scene.anima
│     walks sequence: actions, waits, parallels, conditionals
│     dispatches each action to appropriate capability
│     implemented as a JaegerOS action (goal/feedback/result/cancel)
│
├── ExpressionStateMachine
│     tracks current expression state (idle, happy, curious, etc.)
│     smoothly transitions between states
│     driven by JaegerAI tool calls or scene scripts
│
├── LipSyncProcessor
│     receives /sense/tts_chunk audio + timing data
│     maps phonemes to ARKit viseme blend shapes
│     drives jaw, lips, tongue blend shapes
│     blends with authored keyframes (authored takes priority)
│
└── OutputRouter
      publishes /act/blend_shapes at rig update rate
      publishes /act/joint_targets at hardware rate
      publishes /act/led_state on state change
```

---

## Bus Topics — Full Specification

### Inbound

`/act/animation` — AnimationCommand
```python
class AnimationCommand(Struct):
    correlation_id: str
    clip_name: str | None          # named clip from character library
    scene_file: str | None         # path to .scene.anima file
    scene_inline: str | None       # inline YAML scene content
    expression: str | None         # override expression state
    priority: int = 0              # higher priority interrupts lower
    blend_in_s: float = 0.1        # transition in seconds
```

`/act/animation_stop` — AnimationStop
```python
class AnimationStop(Struct):
    correlation_id: str
    immediate: bool = False        # True = cut, False = blend out
    blend_out_s: float = 0.3
```

`/sense/tts_chunk` — TtsChunk (from KokoroTTS)
```python
class TtsChunk(Struct):
    correlation_id: str
    audio_data: bytes              # PCM samples
    sample_rate: int
    timestamp_s: float             # position in utterance
    amplitude: float               # RMS amplitude (0.0–1.0)
    # future: phoneme data
```

### Outbound

`/sense/animation_state` — AnimationState
```python
class AnimationState(Struct):
    status: Literal["idle", "playing", "blending", "waiting"]
    clip_name: str | None
    scene_file: str | None
    progress: float                # 0.0–1.0
    current_expression: str
    elapsed_s: float
```

`/act/blend_shapes` — BlendShapeFrame
```python
class BlendShapeFrame(Struct):
    timestamp_s: float
    values: dict[str, float]       # ARKit names → 0.0–1.0
    # e.g. {"jawOpen": 0.4, "eyeBlinkLeft": 0.1, ...}
```

`/act/joint_targets` — JointTargetFrame
```python
class JointTargetFrame(Struct):
    timestamp_s: float
    joints: dict[str, float]       # joint name → angle in degrees
    # e.g. {"head_yaw": 15.0, "head_pitch": -5.0, ...}
```

`/act/led_state` — LedState
```python
class LedState(Struct):
    pattern: str                   # "solid", "pulse", "rainbow", etc.
    color_r: int                   # 0–255
    color_g: int
    color_b: int
    brightness: float              # 0.0–1.0
    speed: float = 1.0
```

---

## DigitalOutputNode

Subscribes to `/act/blend_shapes`. Routes to the configured digital renderer.

```
BlendShapeFrame
      │
      ▼
DigitalOutputNode
      │
      ├── Live2DRenderer
      │     maps ARKit blend shapes to Live2D parameter IDs
      │     calls Live2D SDK update at render rate
      │     renders to display surface
      │
      ├── VRMRenderer
      │     maps to VRM BlendShapeProxy
      │     updates Unity/THREE.js scene (or native VRM runtime)
      │
      └── PluginRenderer
            open interface for custom renderers
```

### Live2D Parameter Mapping

Standard ARKit blend shapes map to Live2D parameters:

| ARKit Blend Shape | Live2D Parameter | Notes |
|-------------------|------------------|-------|
| `jawOpen` | `ParamMouthOpenY` | |
| `mouthSmileLeft` | `ParamMouthForm` | averaged with right |
| `mouthSmileRight` | `ParamMouthForm` | |
| `eyeBlinkLeft` | `ParamEyeLOpen` | inverted |
| `eyeBlinkRight` | `ParamEyeROpen` | inverted |
| `eyeLookUpLeft` | `ParamEyeBallY` | combined |
| `eyeLookDownLeft` | `ParamEyeBallY` | combined |
| `eyeLookInLeft` | `ParamEyeBallX` | combined |
| `eyeLookOutLeft` | `ParamEyeBallX` | combined |
| `browInnerUp` | `ParamBrowLY` | |
| `cheekPuff` | `ParamCheek` | |

Full mapping in character file `digital.live2d_mapping` section.

---

## PhysicalOutputNode

Subscribes to both `/act/blend_shapes` and `/act/joint_targets`. Maps to hardware commands through the JaegerOS hardware layer.

```
BlendShapeFrame + JointTargetFrame
            │
            ▼
PhysicalOutputNode
            │ applies character physical_mapping
            ▼
servo angle targets per joint
            │
            ▼ publishes to hardware nodes
/act/motion (velocity/position targets)
/act/led_state
            │
            ▼ hardware nodes
MotionNode → MC01Link → ESP32 firmware
LightNode  → AVC01Link → Teensy firmware
```

### Blend Shape to Servo Mapping

Defined in the character file:

```yaml
physical_mapping:
  jaw_servo:
    source: jawOpen           # blend shape name
    joint: head_jaw           # joint target name
    range: [10, 45]           # servo degrees at value 0.0 and 1.0
    invert: false
    
  brow_servo:
    source: browInnerUp
    joint: head_brow
    range: [20, 60]
    invert: false
```

Safety limits always enforced from project config, regardless of blend shape values.

---

## Expression State Machine

The expression system operates continuously, independent of scene playback.

```
States: idle → transition → active

idle:      playing default idle animation (breathing, subtle movements)
transition: blending from current expression to target
active:    holding target expression with procedural variation
```

Procedural variation in idle and active states:
- Subtle breathing cycle (chest, shoulder blend shapes)
- Eye blink at natural intervals (~15–20 times/min)
- Micro-saccades (small eye movements)
- Weight shift (body joint variation)

These run continuously in the background and are blended under scene keyframes when a scene plays.

---

## Scene Execution as JaegerOS Action

Playing a `.anima` scene is implemented as a formal JaegerOS action:

```
Client sends:   AnimationGoal(scene_file="greeting.scene.anima")
Server accepts: confirms the file loaded and character is active
Feedback:       AnimationFeedback(step=3, total=8, current_action="speak")
Result:         AnimationResult(success=True, duration_s=4.2)
Cancel:         client sends cancel → blend out → return to idle
```

This means JaegerAI can:
- Fire and forget a scene
- Await completion before the next action
- Monitor progress through feedback
- Cancel mid-scene with clean blend-out

---

## Anima Studio — Technical Design

A native macOS application in Swift / SwiftUI.

### Connection to Runtime

Studio connects to a live Anima Runtime over the JaegerOS client protocol (NDJSON over WebSocket or ZMQ). When connected:
- Studio sends preview commands to the Runtime
- Runtime returns live animation state
- Hardware responds in real time
- Studio receives telemetry for debugging

Studio can also run in **offline mode** for pure authoring without hardware.

### Key Views

**Character Editor** — manage blend shapes, define expression presets, configure physical servo mappings, import Live2D / VRM model files.

**Scene Timeline** — multi-track timeline (face, body, voice, LED, audio). Drag keyframes, edit curves, import audio files, preview sync. Logic gate nodes on the timeline (wait, branch, parallel join).

**Digital Preview** — renders the Live2D or VRM character driven by the current timeline position. Shows exactly what the screen face will look like.

**Physical Preview** — RealityKit renders a USD/USDZ skeletal model or a
hierarchy of rigid robot links. Anima's renderer-neutral evaluator supplies the
joint poses; RealityKit displays them. Importers such as URDF are adapters, not
core format dependencies.

**Live Hardware** — when connected to a running JaegerOS system, scrubbing the timeline moves the real robot and updates the real screen face simultaneously.

**Expression Lab** — interactive blend shape sliders. Drag values, see digital and physical response live. Save current state as an expression preset.

### Studio engine and extension boundary

Studio is not planned around an embedded general-purpose game engine. SwiftUI
and AppKit provide the native macOS application shell, `AnimaCore` evaluates
documents and animation, RealityKit renders the 3D viewport, and Live2D Cubism
Native renders 2D characters through Metal. Renderers and output targets consume
the same evaluated blend-shape, joint-pose, and light frame.

The extension goal is capability-based: renderers, importers/exporters,
physical outputs, trackers, authoring tools, and validators meet narrow plugin
interfaces. Initial implementations remain first-party Swift packages while
those contracts are proven. A stable external plugin manifest/ABI is deferred
until at least two real implementations validate each boundary.

The full product goal, engine decision, plugin families, package boundaries,
and first vertical slice are specified in
[`Studio_App.md`](Studio_App.md).

---

## Related Docs

- [[05_Anima/Character_Format]] — full character file specification
- [[05_Anima/Scene_Format]] — full scene file specification and logic gate reference
- [[05_Anima/References]] — prior art and technical standards
- [`Studio_App.md`](Studio_App.md) — Swift app engine, plugins, and build plan
- [[01_JaegerOS/Communication_Semantics]] — JaegerOS action semantics
- [[01_JaegerOS/Wire_Contract]] — existing bus topics this extends
