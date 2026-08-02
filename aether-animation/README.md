# Aether Animation

The Aether ecosystem's unified motion, avatars, and animatronics product:
import a character, define its movable structure, animate it on a timeline,
preview it, and route the same evaluated trajectories to physical hardware.
It also maps face/body performance capture to 2D and 3D avatar blendshapes and
supports real-time puppetry.

## Current reality

The product is being REBUILT as a web app (per Jonathan, 2026-08-01):

- `web/` — the Aether Animation React app: `@aether/ui` widgets + a
  persistent Three.js viewport, driving the canonical Python engine over
  the animacore HTTP bridge (`python -m animacore.httpbridge`). The
  engine stays the single semantic authority; the app is chrome.
- `archive/` — the previous Swift application (`swift-app/`) and its
  native engine seam (`AetherKit/`), frozen as the behavior reference.
  A native Swift shell remains a future option; it would re-consume the
  same tokens (`aether-ui/tokens/tokens.json`) and engine.

The Python semantics engine remains at `/animacore/` (canonical) until its
move into Core is scheduled.

Product-specific = timelines, show control, performance capture, avatar and
blendshape mapping, character-library UX, hardware panels, output buses, and
raw device adapters. Mathematical state/evaluation shared by multiple products
belongs in `/aether-core/`.
