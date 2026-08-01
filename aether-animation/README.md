# Aether Animation

The Aether ecosystem's unified motion, avatars, and animatronics product:
import a character, define its movable structure, animate it on a timeline,
preview it, and route the same evaluated trajectories to physical hardware.
It also maps face/body performance capture to 2D and 3D avatar blendshapes and
supports real-time puppetry.

## Current reality

The Swift macOS app now lives here (moved 2026-08-01, per Jonathan):

- `app/` — the product application (formerly the repo-root `app/`;
  build/test from `aether-animation/app/`).
- `AetherKit/` — the product's **native Swift engine seam**: the
  `AetherKernel` OCCT bridge (C++ shim + Swift wrapper) and the
  `AetherViewport` renderer-neutral contracts (camera state, connector
  candidate engine, themes, navigation bindings, WebGPU entity payloads).
  Swift is product code — it binds Aether Core, it is not Aether Core.
  The platform-universal engine (OCCT/WASM kernel, web renderer core,
  Python semantics) consolidates in `/aether-core/` per its README.

The Python semantics engine remains at `/animacore/` (canonical) until its
move into Core is scheduled.

Product-specific = timelines, show control, performance capture, avatar and
blendshape mapping, character-library UX, hardware panels, output buses, and
raw device adapters. Mathematical state/evaluation shared by multiple products
belongs in `/aether-core/`.
