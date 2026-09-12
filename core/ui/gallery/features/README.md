# Feature editors

One file per feature — `sketch.ts`, `extrude.ts`, `revolve.ts`, `sweep.ts`,
`loft.ts`, `thicken.ts`, `enclose.ts`, `plane.ts`, `mate.ts` — each owning
that feature's window layout, controls, dependent sub-settings, and
validation. `shared.ts` holds the plumbing they all use (window
construction, parameter-row helpers, and the Core-validated wrapper);
`index.ts` re-exports them.

Every editor is built from two shared pieces and nothing else:

- `@aether/ui`'s `openFeatureWindow` — the window chrome (title, ✓/✕,
  tabs, entities box, parameter rows, nested sub-settings, anchored
  pickers, property footer, error state).
- `@aether/core` — the engine's own types and validators, so an editor
  reports the errors the app would report.

To add a feature: copy the closest existing file, keep its layout in
Onshape order (body type → boolean → selection → end type → parameters →
nested options), and export one `build<Name>Demo(host)`.

These are the reference implementations the Aether CAD editors are ported
from; `Aether CAD/src/plane-window.ts` is the first app-side editor built
on the same window API.
