# Anima — References and Prior Art

Technical standards, prior art, and foundational research that inform the Anima design.

---

## Industry Standards

### ARKit Face Blend Shapes (Apple)
The de facto industry standard for face expression parameters. 52 blend shapes covering jaw, mouth, eyes, brows, nose, cheeks, and tongue. Used by Apple FaceID, VTubers, game engines, and virtual production.

- [Apple ARKit Documentation — ARFaceAnchor.BlendShapeLocation](https://developer.apple.com/documentation/arkit/arfaceanchor/blendshapelocation)
- Used by: VTube Studio, VSeeFace, Unreal MetaHuman, Unity FaceCapture, Open-LLM-VTuber

**Anima adopts ARKit blend shapes as its standard face parameter set.** This ensures compatibility with the largest existing ecosystem of face assets, tracking tools, and renderers. Custom extensions (`headNod`, `headShake`, `bodyLean`, etc.) follow the same naming convention.

### VRM — Virtual Reality Model
Open standard for 3D humanoid avatar models, optimized for real-time use. Supported by VRoid Studio, Unity, THREE.js, and most VTuber tools. Includes blend shape proxy system built on ARKit-compatible parameters.

- [VRM Specification](https://vrm.dev/en/)
- [VRM on GitHub](https://github.com/vrm-c/vrm-specification)
- File format: glTF 2.0 extension

**Anima's VRM support** means any VRM avatar (from VRoid Hub or custom) can be used as a digital character with no re-authoring.

### glTF 2.0 — GL Transmission Format
Khronos Group open standard for 3D scenes and models. The "JPEG of 3D." Includes animation support via keyframes and morph targets. VRM is a glTF extension.

- [glTF Specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
- [Khronos Group glTF](https://www.khronos.org/gltf/)

**Anima's physical 3D robot preview** in Anima Studio can import glTF/URDF robot models.

### URDF — Unified Robot Description Format
XML format for describing robot kinematics, visual geometry, and collision geometry. The standard in ROS/ROS 2 for robot models. Used for simulation (Gazebo, Isaac Sim) and visualization.

- [URDF Documentation (ROS)](https://wiki.ros.org/urdf)

**Anima Studio's physical preview** accepts URDF models so JP01's actual kinematic model can be used for accurate joint visualization.

### MIDI Show Control (MSC)
MIDI extension for theatrical show control. Defines a cue-based triggering system where a show control master sends typed cue commands to subsystems (audio, video, lighting, motion). The standard in Broadway and theme park show control since 1991.

- [MIDI Show Control Specification (MMA)](https://www.midi.org/specifications-old/item/midi-show-control)

**Anima's scene scripting** follows the same conceptual model: named cues, sequential and parallel execution, external trigger support. MSC is the prior art for what Anima's logic gate system formalizes.

### SMPTE Timecode
Society of Motion Picture and Television Engineers timecode standard. Frame-accurate time reference used to synchronize audio, video, lighting, and motion control in professional production.

- [SMPTE 12M Standard](https://www.smpte.org/standards/document-index/standards-and-engineering-documents)

**Future Anima feature:** SMPTE timecode input for synchronizing scenes to external audio/video playback systems (live shows, museum installations, film production).

### DMX-512
The lighting control standard. 512 channels at 44Hz, each 0–255. Universal in theater, concert, and architectural lighting. Animatronics often use DMX for LED and effect control.

- [ESTA/PLASA DMX512-A Standard](https://tsp.esta.org/tsp/documents/docs/ANSI-ESTA_E1-11_2008R2018.pdf)

**Anima's LED output** can optionally target DMX-compatible lighting hardware as an additional output target.

---

## Software Prior Art

### Bottango
Free animatronic animation software. Timeline editor with keyframe curves, audio sync, and real-time hardware output. Arduino-compatible open-source driver. Proprietary application. Now selling their own control boards.

- [bottango.com](https://www.bottango.com)
- [Bottango Docs](https://docs.bottango.com)
- Version at reference time: 0.8.0c2

**What Anima takes:** timeline authoring paradigm, keyframe curve editor, audio sync, real-time hardware preview.  
**What Anima improves:** open source application, hardware-agnostic, unified digital output, AI integration, open file format.

### Open-LLM-VTuber
Open-source AI VTuber system with Live2D avatars, LLM integration, TTS, STT, and face tracking. 8.8k GitHub stars. Python backend, web frontend with Pixi.js for Live2D rendering.

- [github.com/Open-LLM-VTuber/Open-LLM-VTuber](https://github.com/Open-LLM-VTuber/Open-LLM-VTuber)

**What Anima takes:** Live2D rendering approach, LLM-to-expression pipeline, emotion state mapping, real-time lip sync from TTS.  
**What Anima improves:** adds physical output, JaegerOS integration, scene scripting, unified character rig, open format.

### VTube Studio
The leading commercial VTuber software. Face tracking to avatar animation using iPhone TrueDepth camera or webcam. ARKit blend shape output. Closed source.

- [denchisoft.com](https://denchisoft.com)

**What Anima takes:** the ARKit blend shape standard as the face parameter format.

### VSeeFace
Open-source VTuber face tracking software. ARKit blend shape output. Free.

- [vseeface.icu](https://www.vseeface.icu)
- [github.com/emilianavt/VSeeFace](https://github.com/emilianavt/VSeeFace)

### QLab (Figure 53)
Professional show control software for theater, live events, and installations. Cue-based scripting with go/wait/conditional logic, audio, video, lighting, and MIDI output. The industry standard for live show control.

- [figure53.com/qlab](https://figure53.com/qlab/)

**What Anima takes:** the cue list model, wait/go logic, multi-track synchronized output, the concept of a show file as the authoritative performance description.

### Autodesk MotionBuilder
Professional 3D character animation software used in film, games, and virtual production. Real-time character animation with motion capture, FK/IK, and constraint systems.

- [autodesk.com/motionbuilder](https://www.autodesk.com/products/motionbuilder/overview)

**Reference for:** the concept of a character rig as the abstract representation that drives multiple outputs.

---

## Robotics and Animatronics Prior Art

### Disney Autonomatronics
Disney's proprietary system for AI-reactive animatronic characters. Characters use sensors (proximity, cameras, microphones) to detect visitors and select pre-authored behavioral responses. The system combines show control playback with a behavior selection layer.

- Disney Research publications on character animation
- Patent: US10981069B2 "Robotic character head with realistic range of motion"
- Notable systems: Lucky the Dinosaur (2003), interactive park characters

**Key insight Anima adopts:** pre-authored clips + AI behavior selection is more reliable than fully generative animation. The AI decides what to express; the animation system executes it with quality.

### Engineered Arts — Mesmer / Ameca
UK robotics company building humanoid robots with the most realistic facial expressions available commercially. Their "Mesmer" platform uses silicone skin over servo-driven bone structures. Digital character elements appear in the eyes (screens).

- [engineeredarts.co.uk](https://www.engineeredarts.co.uk)
- Notable robot: Ameca

**Key insight:** the digital+physical unified character concept at commercial scale. Screen eyes in a physical face is the same pattern JP01 uses.

### Hanson Robotics — Sophia
Early example of AI + physical robot with expressive face. Neoprene skin over servo actuators. GPT-based conversation. Significant media coverage.

- [hansonrobotics.com](https://www.hansonrobotics.com)

**Key insight:** the importance of unified expression — Sophia's face and voice are coordinated through a single system.

### Embodied — Moxie
Children's social robot with a screen face. AI-driven conversation with emotional expression on the screen. Physical head movement. Shows screen-face + physical body as a viable consumer product.

- [embodied.com](https://embodied.com)

### Boston Dynamics — Spot Expression System
Spot the robot dog uses LED "eyes" and body language (tail, posture, gait) to convey emotional state. No verbal communication. Demonstrates that physical expression alone (no screen face) can convey character.

---

## Technical Foundations

### Live2D Cubism SDK
The standard SDK for rendering rigged 2D character models at runtime. Used by the majority of VTubers. C++ SDK with Objective-C and Swift wrappers.

- [live2d.com/en/sdk/about](https://www.live2d.com/en/sdk/about/)
- [GitHub — CubismNativeSamples](https://github.com/Live2D/CubismNativeSamples)

**Anima Studio's digital preview** uses the Live2D SDK. License note: Live2D SDK is free for projects under specified revenue thresholds; commercial use above those thresholds requires a license.

### msgspec (Python)
Fast, type-safe serialization library used throughout JaegerOS. Anima Runtime uses it for all bus message types.

- [github.com/jcrist/msgspec](https://github.com/jcrist/msgspec)

### ZeroMQ (ZMQ)
Transport layer underlying JaegerOS bus. Anima Runtime uses it indirectly through the JaegerOS Bus abstraction.

- [zeromq.org](https://zeromq.org)

### SceneKit (Apple)
Apple's 3D rendering framework for macOS and iOS. Used for Anima Studio's physical robot preview.

- [developer.apple.com/scenekit](https://developer.apple.com/documentation/scenekit)

### SwiftUI
Apple's declarative UI framework. Used for all Anima Studio UI.

- [developer.apple.com/xcode/swiftui](https://developer.apple.com/xcode/swiftui/)

---

## Academic and Research References

- Breazeal, C. (2002). *Designing Sociable Robots*. MIT Press. — Foundational work on robot social expression.
- Hegel, F. et al. (2011). "Understanding Social Robots." *Proc. 2nd Intl. Conf. on Advances in Computer-Human Interactions.*
- Fong, T., Nourbakhsh, I., Dautenhahn, K. (2003). "A survey of socially interactive robots." *Robotics and Autonomous Systems* 42(3–4).
- Ekman, P. (1978). *Facial Action Coding System (FACS)*. — The basis for blend shape facial expression systems.
- Disney Research: "Articulated and Physically Simulated Characters" — internal white papers on character animation systems.

---

## Open Standards to Monitor

- **OpenUSD** (Pixar / Alliance for OpenUSD) — Universal Scene Description. May become relevant for character and scene interchange.
- **glXF** (Khronos) — proposed extension for real-time XR experiences, includes animation.
- **W3C SMIL** (Synchronized Multimedia Integration Language) — web standard for timed multimedia, conceptually similar to Anima's scene format.
- **OSC** (Open Sound Control) — network protocol for show control, alternative to MIDI Show Control for IP-based systems.
