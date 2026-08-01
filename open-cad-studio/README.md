# Open CAD Studio

The CAD authoring product: create, place, edit, and constrain geometry in
Aether's 3D world — the modeling counterpart to Open Animation Studio.

## Ground rules (from day one, learned the hard way)

- **Kernel:** Open CASCADE, behind Core's shim boundary. We do not write a
  B-Rep kernel.
- **Renderers:** the shared Metal + WebGPU contracts from Aether. No
  product-private render state.
- **World model:** AetherScene entities with one stable ID space. No parallel
  representations, no URL-keyed joins — the fragmentation that stalled
  Anima Studio's viewport work does not get rebuilt here.
- **Viewport truth:** everything visible in the 3D viewport is real
  world-space geometry (CONVENTIONS.md); picking is a GPU task.
- **Subsystems:** dedicated files per subsystem (movement, selection,
  authoring tools) with behavior-pinning tests.

Useful prior art in this repo: `dev/OCCTMateLab/` (connector-first mate
authoring, exact topology inference) and `app/Sources/AnimaCAD*` (STEP
import, renderer-neutral document, GPU pick).
