# Anima — Product Whitepaper

> **Unified Character Animation for AI Robots**  
> Jenkins Robotics · Jaeger Ecosystem  
> Version 0.1 — Planning Draft

---

## Abstract

Anima is an open-source character animation system that unifies digital avatar animation and physical animatronic control under a single authoring environment, file format, and runtime. It is designed specifically for AI-driven robots — systems where a conversational intelligence must express itself through both screen-rendered faces and physical mechanical bodies simultaneously.

The central thesis is that digital and physical character animation share 90% of their infrastructure. Anima implements that shared core once, then routes output to whichever delivery mechanisms a given robot or application uses. The result is the first open-source system capable of driving a Live2D screen face, a servo-controlled physical body, and an AI conversation engine from the same authored character file and scene script.

---

## 1. The Problem

### 1.1 Fragmented Tooling

The field of expressive robotics sits at the intersection of three disciplines that have evolved entirely independently:

**Digital avatar animation** (VTubers, AI companions, virtual characters) has mature tooling — Live2D, VRM, VSeeFace, VTube Studio. These tools are designed for screen-only output and have no concept of physical hardware.

**Physical animatronic control** (theme park figures, prop animatronics, hobby robotics) has tooling like Bottango, which provides timeline editing and servo control but has no digital rendering capability and is not truly open source.

**AI conversation systems** (LLM-based agents, voice assistants) have no standard interface for triggering physical or digital animation. Expression is an afterthought, typically reduced to a few hardcoded emotional states.

A robot like JP01 — which has a screen face, a physical walking body, LED expressions, and a conversational AI — must currently integrate three separate systems with no common language between them.

### 1.2 No Unified Format

There is no open file format that describes a character's expressive range in a way that can target both digital renderers and physical hardware. Disney has internal proprietary formats. Bottango has a proprietary format. VRM is digital-only. There is no open equivalent of what the professional entertainment industry calls a "show file" — a complete description of a performance that any compatible runtime can execute.

### 1.3 AI Animation Is Primitive

Current AI-driven animation (where it exists at all) is limited to selecting from a small set of emotion states. There is no system that allows an AI to author, modify, or sequence multi-track character performances with timing, logic, and audio synchronization.

---

## 2. Prior Art

### 2.1 Bottango

The closest existing tool for physical animatronics. Free to download, closed-source application. The Arduino-compatible driver code is open source, but the authoring application is proprietary. Recently pivoting to selling its own control boards, increasing hardware lock-in. No digital output. No AI integration. No open file format.

**What Anima takes from Bottango:** the timeline-based authoring paradigm, the keyframe curve editor, the real-time hardware preview concept.

**What Anima improves:** open source, hardware-agnostic, unified with digital output, AI-integrated.

### 2.2 Open-LLM-VTuber

Open-source AI companion system using Live2D avatars with LLM, TTS, and STT integration. 8.8k GitHub stars. Active community. Supports real-time expression from emotion state. No physical output. No scene scripting. No show control.

**What Anima takes from Open-LLM-VTuber:** the Live2D rendering approach, the LLM-to-expression pipeline concept, the emotion state mapping.

**What Anima improves:** adds physical output, unified rig, scene scripting with logic gates, JaegerOS integration.

### 2.3 Disney Autonomatronics / DACS

Disney's internal show control and animatronic systems represent the gold standard for unified digital/physical character animation. Their approach:
- Unified character rig authored in standard DCC tools (Maya, MotionBuilder)
- Show control system triggers playback
- Same animation data drives embedded screen faces and physical servo bodies
- Behavior state machines allow reactive selection of pre-authored clips
- SMPTE timecode synchronizes all outputs

Not open source. Not available outside Disney. Hardware-specific. No AI integration.

**What Anima takes from Disney:** the unified rig concept, the show control scripting model, the separation of authoring from runtime.

### 2.4 Engineered Arts — Mesmer / Ameca

Engineered Arts builds the most sophisticated humanoid robot faces available commercially. Their "Mesmer" system uses silicone skin over servo-driven bone structures, with the digital character appearing in the eyes (screens). Their software is entirely proprietary.

**What Anima takes from Engineered Arts:** validation that the digital+physical unified concept works and is compelling.

### 2.5 VRM / VTube Studio / VSeeFace

The VTuber ecosystem has produced a robust open standard (VRM) for 3D avatar character rigs and a community of tools for driving them with face tracking and AI. ARKit blend shapes (52 standard parameters) have become the de facto face expression standard.

**What Anima takes from VTubers:** ARKit blend shape standard, VRM support, Live2D support, the concept of a character format separate from the rendering engine.

### 2.6 MIDI Show Control (MSC) and Show Control Protocols

The theatrical and theme park industry has decades of show control experience. MIDI Show Control is an extension of MIDI for triggering cues across audio, video, lighting, and motion systems. QLab is the leading show control authoring tool for theater. DMX-512 is the standard for lighting control.

**What Anima takes from show control:** the cue-based scene model, the "go / wait" logic, the concept of a show file as the authoritative performance description, multi-track synchronized output.

---

## 3. The Unified Character Rig Insight

The fundamental insight that Anima is built on:

> A character's expressive range — its face, body poses, emotional states — is independent of the medium through which it is expressed.

A character can be expressed through:
- Pixels on a screen (digital rendering)
- Servos and motors (physical hardware)
- Both simultaneously

The description of *what the character is doing* should be the same in all cases. Only the translation to physical output or digital output differs.

This is the same principle Disney uses. An animator authors a character's movements once. The show control system delivers those movements to whatever outputs exist — embedded screen, physical joints, audio, lighting.

### 3.1 The Shared 90%

```
Character rig definition       ← 100% shared
Expression preset library      ← 100% shared
Scene scripting format         ← 100% shared
Timeline authoring tools       ← 100% shared
Audio sync and lip sync        ← 100% shared
Logic gates and conditionals   ← 100% shared
AI integration layer           ← 100% shared
File format and versioning     ← 100% shared
```

### 3.2 The Different 10%

```
Digital output:
  Blend shape values → Live2D / VRM renderer → screen

Physical output:
  Blend shape values → servo range mapping → hardware commands
```

Two output modules. Everything else is identical.

---

## 4. Anima Architecture

### 4.1 The Three Layers

```
┌─────────────────────────────────────┐
│  AUTHORING LAYER                    │
│  Anima Studio (Swift / macOS)       │
│  Character editor · Scene timeline  │
│  Audio sync · Preview · Export      │
└──────────────────┬──────────────────┘
                   │ .anima files
┌──────────────────▼──────────────────┐
│  RUNTIME LAYER                      │
│  Anima Runtime (JaegerOS module)    │
│  Scene execution · Rig evaluation   │
│  AI integration · Logic gates       │
└──────────────────┬──────────────────┘
                   │ JaegerOS bus topics
       ┌───────────┴───────────┐
┌──────▼──────┐         ┌──────▼──────┐
│  DIGITAL    │         │  PHYSICAL   │
│  OUTPUT     │         │  OUTPUT     │
│             │         │             │
│DigitalOutput│         │PhysicalOutp │
│Node         │         │utNode       │
│             │         │             │
│Live2D·VRM   │         │Servo mapping│
│Screen face  │         │Motor cmds   │
└─────────────┘         └─────────────┘
```

### 4.2 Anima Runtime — JaegerOS Module

The Runtime is a JaegerOS module that fills the `animation` slot:

```yaml
module: anima_runtime
slot: animation
factory: jaeger_anima.runtime:make_anima_node

subscribes:
  - /act/animation        # play named clip or scene file
  - /act/animation_stop   # stop current playback
  - /sense/tts_chunk      # lip sync input from TTS

publishes:
  - /sense/animation_state    # current playback state
  - /act/blend_shapes         # per-frame blend shape values
  - /act/joint_targets        # per-frame physical joint targets
  - /act/led_state            # LED color/pattern output

tools:
  - animation_play
  - animation_stop
  - animation_set_expression
  - animation_list_clips
```

Scene execution is a JaegerOS action:

```
Goal:     play this .anima scene file
Feedback: current step, progress, active tracks
Result:   completed / interrupted / error
Cancel:   stop immediately, return to idle
```

### 4.3 Output Targets

**DigitalOutputNode** subscribes to `/act/blend_shapes` and drives:
- Live2D model via the Live2D SDK
- VRM model via the VRM runtime
- Custom 2D/3D renderer via an open plugin interface

**PhysicalOutputNode** subscribes to `/act/blend_shapes` and `/act/joint_targets` and:
- Maps blend shape values to servo angle ranges (defined in character config)
- Publishes joint targets to hardware nodes (MotionNode, LightNode)
- Applies safety limits from project configuration

Both nodes can run simultaneously. JP01 runs both.

### 4.4 Character Data Flow

```
.anima character file
        │ loaded by Runtime
        ▼
Character rig in memory
  - blend shape names and ranges
  - bone hierarchy
  - expression presets
  - physical servo mapping
  - voice and persona bindings
        │
        │ each frame / keyframe
        ▼
Rig evaluator
  - interpolates keyframes
  - applies expression presets
  - processes audio-driven visemes
        │
        ├──► /act/blend_shapes  ──► DigitalOutputNode ──► screen
        └──► /act/joint_targets ──► PhysicalOutputNode ──► servos
```

---

## 5. The `.anima` Format

Two file types share the `.anima` extension:

**Character file** (`.character.anima`) — defines the character's identity, expressive range, and hardware mapping. Authored once per character.

**Scene file** (`.scene.anima`) — defines a performance: tracks, keyframes, audio sync, logic gates, AI integration points. Authored per-performance or generated by AI.

See [[05_Anima/Character_Format]] and [[05_Anima/Scene_Format]] for full specifications.

---

## 6. AI Integration

### 6.1 JaegerAI as Performance Director

JaegerAI interacts with Anima through the JaegerOS capability layer:

```python
# Play a pre-authored scene
animation.play("greeting_wave")

# Set an expression state
animation.set_expression("curious")

# Speak with synchronized animation
animation.speak("Hello! I am JP01.", expression="happy")

# Author and play a new scene dynamically
animation.play_inline(scene_yaml)
```

### 6.2 Reactive Animation

JaegerAI drives Anima's expression state based on conversation context. Anima blends continuously between expression presets based on the current state:

```
JaegerAI emotion state: "curious"
        │
        ▼
Anima expression system
        │ blend toward "curious" preset
        ▼
/act/blend_shapes
        │
        ├── eyebrowRaiseLeft:  0.6
        ├── eyebrowRaiseRight: 0.6
        ├── headTilt:          0.3
        └── eyeSquintLeft:     0.2
```

### 6.3 AI Scene Authoring

Because `.anima` scene files are human-readable YAML, JaegerAI can generate them:

```
User: "Create a scene where JP01 introduces itself and shakes its hand."

JaegerAI generates .anima scene file →
Anima Runtime executes it →
JP01 performs the scene
```

This closes the loop: the AI doesn't just trigger pre-authored animations — it can create new ones.

### 6.4 Lip Sync Pipeline

```
TTSNode generates speech
        │ /sense/tts_chunk (audio data + timing)
        ▼
Anima Runtime
        │ phoneme → viseme conversion
        ▼
/act/blend_shapes
  jawOpen:       0.0 → 0.8 → 0.0
  mouthFunnel:   0.0 → 0.3 → 0.0
        │
        ├── Live2D mouth ← DigitalOutputNode
        └── Physical jaw servo ← PhysicalOutputNode
```

---

## 7. Use Cases

### 7.1 JP01 — Unified Physical and Digital
JP01's screen face and physical body driven simultaneously by the same character file. JaegerAI triggers expressions and scenes during conversation. Show control scenes play during demonstrations. PID motor control handles walking; Anima handles expression.

### 7.2 Desktop AI Companion
No physical hardware. Anima drives a Live2D or VRM avatar on a Mac desktop. JaegerAI provides the intelligence. KokoroTTS provides the voice. The full Jaeger stack runs locally, completely offline.

### 7.3 Animatronic Installation
No AI required. An artist authors scenes in Anima Studio, exports `.anima` files, and the Runtime executes them on a physical animatronic figure triggered by show control events. Replaces Bottango with an open-source, hardware-agnostic alternative.

### 7.4 Streaming AI Character
An AI character streams live to an audience. The digital avatar is the face. Pre-authored scenes handle structured segments. JaegerAI handles live conversation. Audio drives lip sync. All from one system.

### 7.5 Multi-Robot Choreography
Multiple JaegerOS robots execute synchronized `.anima` scenes triggered by the same show control cue. Each robot has its own character file; the scene defines what each character does and when.

---

## 8. Design Principles

**Open format above all.** The `.anima` format is the lasting contribution. Applications come and go; an open, well-specified format creates an ecosystem.

**Hardware agnosticism.** Anima never talks directly to hardware. JaegerOS hardware modules handle that. Anima publishes blend shapes and joint targets; the project determines what hardware receives them.

**AI-first but not AI-only.** Anima works without AI. Show control scenes run independently. But AI integration is a first-class design target, not an afterthought.

**Authoring and runtime are separate.** Anima Studio creates files. Anima Runtime executes them. They communicate through the `.anima` format. The Runtime can run headless. The Studio can connect to a live runtime for preview.

**The rig is the character.** A character exists independently of any rendering backend. The same character file describes a Live2D version and a physical version.

---

## 9. Open Source Commitment

Anima is MIT licensed. The specification, the Runtime, and Anima Studio source are fully open.

The `.anima` format will be published as an open specification with a versioning policy, so third-party runtimes and tools can implement it.

No hardware is required or preferred. Anima works with any hardware that JaegerOS supports.

---

## 10. Roadmap

### Phase 1 — Format and Runtime (Foundation)
- Define `.anima` character format v1.0
- Define `.anima` scene format v1.0
- Implement Anima Runtime as JaegerOS module
- Implement DigitalOutputNode (Live2D)
- Implement PhysicalOutputNode (JP01 hardware)
- JaegerAI tool integration
- Lip sync pipeline from TTS

### Phase 2 — Anima Studio MVP
- Character editor (blend shape list, expression presets)
- Scene timeline editor (keyframes, audio sync)
- Digital preview (Live2D)
- Live hardware connection for preview
- Export `.anima` files

### Phase 3 — Advanced Features
- 3D physical robot preview (SceneKit)
- VRM support
- Scene logic gates (wait_for, if/then, parallel)
- AI scene authoring interface
- Multi-robot choreography

### Phase 4 — Ecosystem
- Open `.anima` format specification published
- Community character library
- Third-party hardware mapping support
- Plugin system for custom output targets

---

## References

See [[05_Anima/References]] for full citations and technical standards.

---

*Anima is a Jenkins Robotics / Jaeger Ecosystem project.*  
*Contact: jonathan.d.jenkins31@gmail.com*
