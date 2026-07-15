# STATUS

> Truthful, or it's worthless. Any commit that changes behavior updates
> this file in the same commit — see `CONVENTIONS.md` → "STATUS stays
> truthful."

## Current state — 2026-07-14

- **Repo:** `AnimaStudio` — open-source unified character animation
  system for AI robots (digital avatars + physical animatronics from
  one rig, one format, one authoring tool)
- **Version:** 0.1.0 (see `anima_studio/__init__.py`)
- **JaegerOS pin:** not yet set — for now the runtime is standalone and
  Jaegers read `.anima` files natively; the `jaeger-os` dependency and
  `animation`-slot module land later (see `dev/docs/roadmap/`)
- **What works:** the native macOS foundation under `studio/` builds and
  launches as a Swift package. `AnimaCore` defines project assets, joint rigs,
  clips, hold/linear keyframes, deterministic evaluation, neutral fallback,
  time clamping, joint-limit clamping, and Codable project round-tripping. The
  SwiftUI app launches into a Bottango-inspired dark home screen with a working
  New Studio Project action and honestly disabled project-open/templates until
  persistence ships. Its project window now has task-focused Assets, Rig,
  Animate, Show, and Hardware workspaces with Command-1…5 switching, a stable
  global project/live bar, workspace-owned contextual tools, and independently
  restorable in-session navigator/inspector/bottom-panel visibility. Assets
  centers import and hierarchy inspection; Rig centers parts and joints;
  Animate owns the working timeline dock with transport, tracks/keyframes,
  click/drag scrubbing, and looping playback; Show has a distinct multi-track
  character/audio/screen/event timeline scaffold; Hardware has structured
  connection, safety, mapping, and filterable-log surfaces that visibly remain
  safely offline. The viewport now provides
  a readable grid, Home/front/right/top camera presets, perspective/orthographic
  projection switching, orbit controls, and framing of a selected imported
  model node. The Parts outline follows macOS file-browser selection conventions:
  Command/Shift select multiple, one item opens its configuration, and Escape
  or the inspector close control clears selection. Imported geometry can also
  be selected directly in the viewport, with Command/Shift extending the same
  Parts-tree selection. Shared theme metrics and
  reusable panel, text-field, picker, readout, and primary-button styles keep
  new Studio windows visually consistent. The sample Rig viewport also renders
  a mate-guide foundation: labeled local XYZ axes, a revolute DOF ring, an
  optional reference plane, and a highlighted limit arc with independent layer
  toggles. Project, asset, and joint names plus
  a joint's rotation axis are editable in memory. Users can select a
  RealityKit-supported USD/Reality model; it loads asynchronously, is normalized
  for preview framing, and appears in the project asset tree. Its complete
  RealityKit entity hierarchy is projected into value-only nodes with unique
  sibling paths, shown as a selectable Structure outline, and described in the
  inspector. Fifteen tests pass with `cd studio && swift test`, including real USD
  hierarchy loading/projection through RealityKit and duplicate/unnamed entity
  identity coverage. The Python package skeleton also
  installs with `pip install -e ".[dev]"`. The Python runtime now implements
  the Anima Wire Protocol v0 reference host (`anima_studio/wire.py` — encode
  HELLO/CFG/FRM/EN/STOP/PING, parse ANIMA/OK/ERR/PONG, 3-decimal normalized
  values), an in-process simulated device (`anima_studio/sim.py` — handshake,
  servo CFG, device-side linear FRM interpolation on an explicit `tick(now_ms)`
  clock, E-stop, per-channel 2000 ms failsafe, spec ERR codes), and a
  normalized output-track evaluator (`anima_studio/tracks.py` — hold/linear,
  time and limit clamping, deterministic; explicitly not a rig evaluator —
  AnimaCore keeps rig semantics; no Bézier yet). Per review: only successfully
  parsed commands refresh the failsafe heartbeat, and duplicate CFG keys or
  duplicate FRM channels are rejected (no last-write-wins). The runtime also
  loads `.character.anima` files (`anima_studio/loader.py` — version/type
  check, typed errors naming the offending path, unknown-field rejection;
  unsupported spec sections — expressions, lip_sync, digital, voice,
  blend_shape/led mappings, smoothing, easing — are rejected loudly, never
  silently dropped) into a rig-aware model (`anima_studio/rig.py` — joints
  with radian ranges and neutrals, blend shapes, hold/linear clips with
  neutral fallback for every unanimated parameter, loop wrapping, and the
  joint→normalized 0..1 servo-channel projection feeding `wire.encode_frm`);
  `examples/jp01_minimal.character.anima` is a loadable minimal head rig.
  144 Python tests pass with `.venv/bin/pytest anima_studio/tests -q` (lint:
  `.venv/bin/ruff check .`), including end-to-end clip → FRM stream →
  simulated servo → failsafe, and character file → rig evaluation →
  channel projection → simulated servo tests.
- **What's stubbed:** every `*.example` file under `anima_studio/` —
  `module.yaml`, `config.py`, `node.py`, the module-contract test —
  these are the JaegerOS-module shape for later
- **Known gaps:** imported model hierarchies can be inspected but cannot yet be
  mapped to persistent semantic parts; the mate guides currently visualize the
  sample revolute joint but are not editable handles or attached to imported
  parts; joint limits and keyframes are not yet
  editable; project changes are not
  persisted; imported security-scoped URLs
  last only for the current session. Project open/save, undo/redo, Home
  templates, and live hardware controls are intentionally visible but disabled.
  There is no `.anima` parsing in Studio (the Python runtime loads
  `.character.anima` only; `.scene.anima` is unimplemented everywhere), no
  Bézier curve editor, audio, screens/LEDs, Live2D, scene execution, output
  node, JaegerOS connection, or full 52-blend-shape JP01 character file (a
  minimal example head ships in `examples/`). Studio is a working workspace
  foundation, not yet a complete authoring workflow.

## How to update this file

1. Ship a behavior change.
2. In the same commit, add or edit a line above reflecting the new truth.
3. If something moves from "planned" to "shipped," delete it from
   `../roadmap/` (or mark it done there) — don't leave the same fact
   living in two docs, per `CONVENTIONS.md` law 1.
