# Community extensions (planned)

> The open ecosystem layer (Jonathan, 2026-07-15): users expand Anima
> Studio the way Onshape users build
> [custom features](https://www.onshape.com/en/features/custom-features)
> and the way JaegerOS consumes modules — self-contained packages,
> everything packed in one bundle, with declared access to the layers
> they extend. This app is open source; the extension surface is how
> the community makes it theirs.

## The package: one bundle, everything in it

An extension is **one directory** (zip-distributable) named
`<slug>.animaext/`, with a single manifest describing everything it
contributes — the JaegerOS `module.yaml` spirit:

```yaml
# extension.yaml — the one copy of this extension's truth
anima_extension: "1.0"          # manifest schema version
id: "udp-wire-output"           # unique slug
name: "UDP Wire Output"
version: "0.1.0"
author: "…"
license: "Apache-2.0"
description: "Streams Anima Wire Protocol frames over UDP."
compatibility:
  anima_format: "2.0"           # .anima format major it understands
requires: []                    # other extension ids (rarely; keep flat)
capabilities: [network]         # declared access: hardware | network | filesystem
provides:
  - kind: output_adapter        # the extension point (see table)
    id: "udp_wire"
    entry: "adapter.py:UdpWireOutput"
assets: []                      # bundled files (models, curves, docs)
```

Rules: the manifest is closed-schema (unknown fields rejected, typed
errors naming paths — same loader discipline as `.anima` files). All
code/assets live inside the bundle; an extension never reaches into
another extension or the app's internals beyond its extension point's
API. `capabilities` is surfaced to the user at install time.

## Extension points — access to all the layers

| Kind | Layer | What it contributes | Trust model |
|---|---|---|---|
| `output_adapter` | Python runtime | A device/protocol backend consuming evaluated channel frames (DMX, OSC, UDP, vendor servo buses…) | Python code — installing = trusting, capabilities declared |
| `parametric_feature` | Format/Studio | A declarative template producing standard parts/joints/relations from parameters (a "custom feature" in the Onshape sense: a gripper, a Stewart platform, an N-link arm) | Pure data (YAML) — safe by construction |
| `scene_action` | Python runtime | A custom `.scene.anima` action/trigger (after scene execution ships) | Python code |
| `motor_backend` | Firmware | A C++ servo/motor signal backend compiled into the firmware build | Source, compiled by the user |
| `studio_panel` | Swift app | **Explicitly not planned for v1** — native plugin loading needs sandboxing/signing answers we don't have; declarative features cover the near-term need |

The composition rule (same as Onshape's): extensions **compose the
core primitives**, they don't add new kernel types. A parametric
feature emits standard mates and relations; an output adapter consumes
the standard evaluated-channel frame. Core contracts stay small.

## Discovery & install

- Install = drop the bundle in a scanned directory: user-level
  (`~/Library/Application Support/AnimaStudio/Extensions/`) or
  project-local (`<project>/extensions/`, shipping with the project).
- The runtime scans for `*.animaext/extension.yaml`, validates, and
  registers contributions; conflicts (duplicate `id`) are load errors.
  No pip requirement — everything packed in.
- Distribution starts as git repos + zips; a community index
  (registry repo + site gallery) is a later packet, not a launch
  requirement.

## Packet sequencing

| # | Packet | Depends on | Lane |
|---|---|---|---|
| E1 | Manifest schema + discovery/registry + `output_adapter` point + built-in simulator adapter behind the same API + one real packaged example extension | — | Claude (Python) |
| E2 | `parametric_feature`: declarative template schema (params → parts/joints/relations), loader + expansion into the standard rig | format 2.0 | Claude format/runtime; Codex Studio rendering |
| E3 | Studio: Extensions browser (installed list, capabilities display, enable/disable), parametric features appearing in the Rig ribbon like built-ins | E1/E2 | Codex |
| E4 | `scene_action` point | `.scene.anima` execution | Claude |
| E5 | Firmware `motor_backend` build hooks | firmware v0 | Claude |
| E6 | Community registry + site gallery | E1–E3 proven | shared |

First real consumer rule (CONVENTIONS law 1): E1 ships with the
simulator rewired through the same adapter API plus one genuine
example extension — the extension point is proven by two consumers on
day one, or it doesn't merge.
