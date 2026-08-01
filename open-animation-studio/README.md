# Open Animation Studio

The animatronics/animation product: import a character, define its movable
structure (mates on Core's world), animate it on a timeline, preview it, and
drive the same evaluated motion to physical hardware.

## Current reality

This product exists today as the app at `/app/` (Swift, macOS) plus the
engine at `/animacore/`. It migrates into this folder as the Core split
solidifies; until then, active development continues in place and this
folder holds product-specific planning and any new product-only modules.

Product-specific = timelines, show control, hardware panels, character
library UX. Anything two products need belongs in `/core/`.
