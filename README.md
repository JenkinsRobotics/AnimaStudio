<h1 align="center">Anima Studio</h1>

<p align="center">
  <em>Open-source unified character animation system for AI robots — digital avatars and physical animatronics from one rig, one format, one authoring tool.</em>
</p>

<p align="center">
  <a href="https://github.com/JenkinsRobotics/AnimaStudio/releases"><img src="https://img.shields.io/badge/version-0.1.0-2EA44F?style=for-the-badge" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-2EA44F?style=for-the-badge" alt="License"></a>
  <img src="https://img.shields.io/badge/python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python 3.11+">
</p>

---

## What it is

Anima Studio is the character performance layer of the
[Jaeger ecosystem](https://github.com/JenkinsRobotics/JaegerOS). It bridges
two worlds that have always been separate:

- **Digital avatar animation** — Live2D / VRM characters on screens, AI
  companions, VTubers
- **Physical animatronic control** — servo motors, stepper actuators, LED
  expressions, robotic bodies

These two worlds share ~90% of their infrastructure: the character rig, the
expression system (ARKit's 52 blend shapes), the scene scripting, the audio
sync, the AI integration. Only the output target differs. Anima Studio
implements that shared 90% once and routes to whichever outputs a project
uses — so a robot like JP01 can have its screen face and physical body
driven simultaneously from one character file and one scene script.

| Software | Digital avatar | Physical animatronic | Open source | AI integration |
|----------|:-:|:-:|:-:|:-:|
| Bottango | ✗ | ✓ | ✗ (driver only) | ✗ |
| Open-LLM-VTuber | ✓ | ✗ | ✓ | ✓ (limited) |
| VTube Studio | ✓ | ✗ | ✗ | ✗ |
| Disney DACS | ✓ | ✓ | ✗ | ✗ |
| **Anima Studio** | **✓** | **✓** | **✓** | **✓** |

## The three components

- **Anima Runtime** (`anima_studio/`, Python) — loads and executes `.anima`
  files, routes output to digital and physical targets. Runs standalone
  today; becomes a JaegerOS module filling the `animation` slot when the
  integration lands. **(planned — nothing implemented yet)**
- **Anima Studio app** (`studio/`, Swift/SwiftUI, macOS) — a buildable native
  foundation now includes renderer-independent joint/clip evaluation and a
  RealityKit sample preview. Character editing, model import, scene timelines,
  audio sync, screens/LEDs, Live2D, and live hardware remain **(planned)**.
- **The `.anima` format** — an open, human-readable YAML format for
  character rigs (`.character.anima`) and performance scenes
  (`.scene.anima`). The format is the lasting contribution — any compatible
  runtime can execute it. Full specs in
  [dev/docs/roadmap/](dev/docs/roadmap/).

## Install

```bash
git clone https://github.com/JenkinsRobotics/AnimaStudio.git
cd AnimaStudio
python3.11 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
```

## Documentation

Planning and design docs live under [dev/docs/](dev/docs/):

- [Overview](dev/docs/vision/Overview.md) — positioning and product summary
- [Whitepaper](dev/docs/vision/Whitepaper.md) — problem, prior art,
  architecture, use cases
- [References](dev/docs/vision/References.md) — prior art and standards
- [Architecture](dev/docs/roadmap/Architecture.md) — three-layer model,
  runtime design, output nodes
- [Studio app plan](dev/docs/roadmap/Studio_App.md) — Swift app architecture,
  RealityKit viewport, plugin system, and first build slice
- [Hardware animation milestone](dev/docs/roadmap/Hardware_Animation_Milestone.md)
  — workspace, model import, rigging, timeline, and first output loop
- [Character format](dev/docs/roadmap/Character_Format.md) —
  `.character.anima` spec with a full JP01 example
- [Scene format](dev/docs/roadmap/Scene_Format.md) — `.scene.anima` spec,
  action types, logic gates
- [STATUS](dev/docs/reality/STATUS.md) — what actually works right now

Repo conventions follow the Jaeger ecosystem rules — see
[CONVENTIONS.md](CONVENTIONS.md) and [TAXONOMY.md](TAXONOMY.md).

## Ecosystem links

- [JaegerOS](https://github.com/JenkinsRobotics/JaegerOS) — the robot
  framework (bus, nodes, modules/slots, supervisor, safety)
- [Jaeger-AI](https://github.com/JenkinsRobotics/Jaeger-AI) — the agentic
  Mind that triggers and authors `.anima` scenes
- [JP01](https://github.com/JenkinsRobotics/JP01) — the reference hardware
  Jaeger, the first body Anima Studio will drive

## License

[Apache-2.0](LICENSE) © Jenkins Robotics
