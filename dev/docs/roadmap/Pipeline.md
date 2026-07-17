# The Anima Studio pipeline — workspace flow & the 2D/3D question (planning)

> How a user moves through the app end to end, what each workspace is
> for, the tools each stage needs, and how 2D vs 3D characters relate
> (Jonathan, 2026-07-16 — planning only, nothing built from this yet).

## The spine: one directed flow

The workspaces are pipeline stages, and the **output of each is the
input of the next**:

```
ASSETS ──▶ RIG ──▶ ANIMATE ──▶ SHOW + NODES ──▶ HARDWARE
source in   make it   author       compose &        drive
& create    move      motion       add logic        reality
```

The UX job is to make this flow *forward*: each stage is gated on the
previous (you can't Animate an unrigged character; Hardware needs a rig
with output mappings), and the app should nudge to the next step
("character has parts → go Rig", "rig moves → go Animate"). Honest
disabling of not-yet-ready stages (the current "Planned" labels) is the
right instinct — keep it, but make the *ready* next step obvious.

## The stages

**ASSETS — bring media in, create the character.**
- Steps: new project → **create a character (2D or 3D)** → import
  model(s) / media → organize.
- Tools: model importer (STL/OBJ/USD + the units prompt), character
  creation (type picker), asset library, hierarchy inspection, media
  import (audio/video/image/LED).
- Done when: a character exists with its source parts/assets.

**RIG — turn parts into a mechanism.**
- Steps: define semantic parts → place **mate connectors** → apply
  **typed mates** (the 10 kinds) or a **DH kinematic chain** (arms) →
  set **DOF limits / neutrals** → couple with **relations**
  (gear/rack/screw/linear) → **ground** the base, **suppress** test
  parts, set **location**.
- Tools: part creation, connector inference + two-click mate placement,
  mate/relation catalogs, DOF limit editors, DH-chain editor, the
  transform gizmo, the component/mate tree.
- Done when: the rig moves (FK/IK), and DOF are mapped to output
  channels for later hardware.

**ANIMATE — author motion over time.**
- Steps: create clips → keyframe the **channels** (joint DOF /
  parameters) → shape **curves** (hold/linear/Bézier) → jog the arm via
  **FK/IK** → scrub/preview kinematically.
- Tools: timeline, dope sheet, graph/curve editor, transport, auto-key,
  the IK end-effector target handle.
- Done when: named animation clips exist.

**SHOW + NODES — compose performances and their logic (two views of
one scene).**
- SHOW = the temporal view: sequence clips across **multiple
  characters** + audio/screens/LEDs/events on cue tracks.
- NODES = the logic view: the same scene as a graph — flow, gates
  (`wait_for`), conditions, `select`, `call`, `loop`, background
  monitors. (The visual-builder/script-builder toggle over one
  `.scene.anima` document.)
- Tools: show timeline (cue tracks), node canvas (flow/action/logic
  nodes), the graph↔timeline sync.
- Done when: a `.scene.anima` performance exists.

**HARDWARE — drive reality.**
- Steps: connect a driver → **map DOF → actuator channels** →
  **calibrate** servo ranges → **arm** (Master Live) → **monitor** →
  safety/failsafe → stream evaluated frames over the wire protocol.
- Tools: driver connection, channel mapping, calibration, arm/disarm,
  live monitor, e-stop.
- Done when: the physical (or simulated) robot moves.

## The unifying idea: it's all channels over time

Every stage defines, animates, sequences, or outputs **channels**. A
channel is either a mechanism **DOF** (3D) or a scalar **parameter**
(a face weight, an LED level). The whole app is a channel factory:
RIG defines channels, ANIMATE drives them over time, SHOW/NODES
sequences and gates them, HARDWARE routes them to actuators. Hold that
and the 2D/3D question answers itself.

## 2D vs 3D: diverge, merge, diverge

**They are NOT separate apps.** They diverge only at the two ends and
share the whole middle — this is the whitepaper's "90% shared" made
concrete.

- **Diverge at ASSETS + RIG (how channels are *defined*):**
  - **3D** — import meshes → rigid **parts + typed mates + DOF** (a
    mechanism), or a DH chain. Channels = joint DOF. Tools: mates,
    connectors, gizmo, DH.
  - **2D** — import layered art (Live2D/VRM-style) → **parameters +
    deformers** (mouth-open, blink, head-turn — ARKit-blend-shape
    style). Channels = named 0..1 parameters. Tools: parameter/deformer
    binding, not mates. A different *rig type*.
- **Merge at ANIMATE + SHOW + NODES (how channels are *driven*):**
  identical. A clip keyframes channels; a scene sequences and gates
  clips. The timeline, curves, logic, and cue system don't care whether
  a channel came from a 3D joint or a 2D parameter. **One clip format,
  one scene format, one pipeline.**
- **Diverge again at OUTPUT (where channels *go*):** 3D DOF → servos +
  RealityKit; 2D parameters → Live2D/screen render. Both are just
  output adapters consuming the evaluated frame.

**Mixed 2D + 3D is the whole point, not an edge case.** The founding
example (JP01: a physical body with a screen face) is ONE character
carrying **both** a 3D mechanism rig (body DOF) *and* a 2D face layer
(expression parameters), animated in one clip, sequenced in one scene,
and output to **both** a screen (2D face) and servos (3D body)
simultaneously. So a "character" is: a 3D mechanism (optional) + a 2D
parameter/face layer (optional) — most have one, JP01 has both.

**What we already have that supports this:** the engine's generic
`Parameter` (a domain-agnostic 0..1 scalar — deliberately not
face-specific) is the seed of the 2D/expression channel. A 3D character
today is parts+mates+DOF **plus** optional parameters. Adding the 2D
branch later = a new rig-authoring surface (parameter/deformer binding)
+ a Live2D/screen output adapter, both plugging into the *existing*
animate/scene/output spine. Nothing about 2D requires forking the
pipeline.

## Sequencing

3D is being built first (per Jonathan). The 2D branch (2D asset import,
the parameter/deformer rig surface, and the screen/Live2D output
adapter) is a later addition that attaches to the same ANIMATE → SHOW →
OUTPUT middle. Build the channel spine right for 3D now, and 2D drops in
without re-architecting.
