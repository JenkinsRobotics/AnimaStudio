# Anima

> **The open-source unified character animation system for AI robots.**  
> One character rig. One scene format. One authoring tool.  
> Digital and physical output simultaneously.

---

## What Is Anima?

Anima is the character performance layer of the Jaeger ecosystem. It bridges two worlds that have always been separate:

- **Digital avatar animation** — Live2D / VRM characters on screens, AI companions, VTubers
- **Physical animatronic control** — servo motors, stepper actuators, LED expressions, robotic bodies

The insight: these two worlds share 90% of their infrastructure. The character rig, the expression system, the scene scripting format, the audio sync, the AI integration — all identical. Only the output target differs.

Anima treats digital and physical as two delivery mechanisms for the same underlying character.

---

## The Gap Anima Fills

| Software | Digital avatar | Physical animatronic | Open source | AI integration |
|----------|:-:|:-:|:-:|:-:|
| Bottango | ✗ | ✓ | ✗ (driver only) | ✗ |
| Open-LLM-VTuber | ✓ | ✗ | ✓ | ✓ (limited) |
| VTube Studio | ✓ | ✗ | ✗ | ✗ |
| Disney DACS | ✓ | ✓ | ✗ | ✗ |
| **Anima** | **✓** | **✓** | **✓** | **✓** |

No open-source software today does all four. Anima is the first.

---

## The Unified Character Rig

A character in Anima is defined once as an abstract rig — a set of blend shapes, bone poses, and expression presets that describe the full range of what that character can express. The same rig data simultaneously drives:

```
Character Rig
    │
    ├── Digital renderer    → Live2D / VRM face → screen
    ├── Physical mapper     → servo targets      → robot hardware
    ├── LED controller      → color / pattern    → expression panels
    └── Voice sync          → lip sync visemes   → jaw / mouth
```

For JP01, the screen face and the physical body are driven by the same character data at the same time. One animation authored once.

---

## The Three Components

### Anima Runtime
A JaegerOS module. Loads `.anima` scene files and executes them as managed actions. Routes animation output to digital and physical nodes through the JaegerOS bus. Hardware-agnostic — it dispatches to whatever output nodes the project has configured.

### Anima Studio
A native Mac application (Swift / SwiftUI). The visual authoring environment for creating characters and scenes. Timeline editor, audio sync, digital preview, 3D physical preview, live hardware connection for real-time testing.

### The `.anima` Format
An open, human-readable (YAML-based) file format defining both character rigs and performance scenes. Version-controlled, shareable, and hardware-agnostic. The format is the lasting open-source contribution — any compatible runtime can execute it.

---

## How It Fits in the Jaeger Ecosystem

```
JP01 project
    │
    ├── JaegerAI          ← decides what to express and when
    │       │ animation.play("wave")
    │       ▼
    ├── Anima Runtime     ← executes .anima scenes as JaegerOS actions
    │       │ bus topics
    │       ├── DigitalOutputNode   → screen face
    │       └── PhysicalOutputNode  → servos / motors / LEDs
    │
    └── JaegerOS          ← connects, supervises, protects everything
```

JaegerAI gets character animation for free. `animation.play("greeting")` works whether JP01 is a screen character, a physical robot, or both.

---

## Use Cases

**JP01 robot** — Anima drives the screen face and physical body simultaneously. JaegerAI triggers expressions and scenes during conversation.

**Desktop AI companion** — Anima drives a Live2D or VRM avatar on screen. No physical hardware required. Reactive to conversation state and emotion.

**Animatronic installation** — Anima executes pre-authored show control scenes with logic gates, audio sync, and conditional branching. No AI required.

**Hybrid performance** — A robot character streams to both a physical body on stage and a digital feed simultaneously, driven by the same scene file.

---

## Open Source Commitment

Anima is MIT licensed. The `.anima` file format is an open standard. The Runtime and Studio are fully open source. No hardware lock-in. No subscription. No proprietary control boards required.

---

## Document Index

- [Whitepaper](Whitepaper.md) — formal product specification and rationale
- [Architecture](../roadmap/Architecture.md) — technical architecture: rig, runtime, output targets
- [Character_Format](../roadmap/Character_Format.md) — `.anima` character rig specification
- [Scene_Format](../roadmap/Scene_Format.md) — `.anima` scene scripting format and logic gates
- [References](References.md) — prior art, industry standards, technical foundations
