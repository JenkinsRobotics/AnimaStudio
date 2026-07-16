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

- **AnimaCore** (`animacore/`, Python) — the headless animation **engine**:
  loads `.character.anima` files into a typed parts/joints/DOF mechanism rig
  (Onshape-mate model), evaluates clips with limits and gear/rack/screw/linear
  relations, runs `.scene.anima` shows, and streams normalized channel targets
  over the open Anima Wire Protocol to real or simulated devices. The
  cross-platform core the app and firmware author for. JaegerOS integration
  remains **(planned)**.
- **Anima Studio app** (`app/`, Swift/SwiftUI, macOS) — the native
  authoring app: CAD-style workspaces, model import, proxy components,
  two-click connector-authored mates, face/edge selection, timeline with
  scrubbing and looping playback. Persistence, editable curves, and live
  hardware output remain **(planned)**.
- **Anima firmware** (`firmware/`, Arduino/ESP32) — the open device firmware
  speaking the wire protocol: servo config, interpolated frames, e-stop,
  heartbeat failsafe. Compiles for Uno and ESP32.
- **The `.anima` format** — an open, human-readable YAML format for
  mechanism rigs (`.character.anima`) and performance scenes
  (`.scene.anima`, planned). The format is the lasting contribution — any
  compatible runtime can execute it. Specs in
  [dev/docs/roadmap/](dev/docs/roadmap/).

## Install

```bash
git clone https://github.com/JenkinsRobotics/AnimaStudio.git
cd AnimaStudio
python3.11 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
```

## Launch the macOS app

On a Mac with Xcode installed, double-click **Anima Studio.app** at the
repository root after it has been assembled, or build it at any time with:

```bash
cd app
./Scripts/build-root-app.sh
open "../Anima Studio.app"
```

For SwiftUI development and live Canvas previews, open
`app/AnimaStudio.xcodeproj` and run the **AnimaStudio** scheme on **My Mac**.

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

Repo conventions: [CONVENTIONS.md](CONVENTIONS.md). Agent/contributor
contract: [AGENTS.md](AGENTS.md).

## Repository map

| Path | What it is |
|---|---|
| `animacore/` | **AnimaCore** — the Python animation engine: `.anima` loader, rig/DOF/relations evaluation, `.scene.anima` execution, wire protocol host, device simulator, extensions, tests |
| `app/` | Swift macOS app — `App/` (thin app target), `Sources/` (`AnimaModel`, `AnimaEvaluation`, `AnimaStudioUI`, and viewport packages), `Tests/` |
| `firmware/` | Arduino/ESP32 firmware speaking the wire protocol |
| `examples/` | Sample `.anima` files + extension bundles (the only place domain-specific naming lives) |
| `dev/briefings/` | Multi-agent coordination: mailboxes, claims, handoff log |
| `dev/docs/` | `reality/STATUS.md` (shipped truth) · `roadmap/` (planned) · `vision/` (why) |
| `docs/` | GitHub Pages site source |

> **AnimaCore is the engine; Anima Studio is one app that authors for it.**
> The `.anima` format and wire protocol in `dev/docs/roadmap/` are the
> contract both `animacore/` (Python) and the Swift app implement.

## Ecosystem links

- [JaegerOS](https://github.com/JenkinsRobotics/JaegerOS) — the robot
  framework (bus, nodes, modules/slots, supervisor, safety)
- [Jaeger-AI](https://github.com/JenkinsRobotics/Jaeger-AI) — the agentic
  Mind that triggers and authors `.anima` scenes
- [JP01](https://github.com/JenkinsRobotics/JP01) — the reference hardware
  Jaeger, the first body Anima Studio will drive

## License

[Apache-2.0](LICENSE) © Jenkins Robotics
