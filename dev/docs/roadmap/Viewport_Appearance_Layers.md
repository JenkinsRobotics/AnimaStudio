# Viewport Appearance Layers

Approved design (Jonathan, 2026-07-31). Three appearance layers for the CAD
viewport, one shared model consumed by Metal and Three.js WebGPU in lockstep,
color-only parity on raw WebGPU (no shadow pass there — honest limitation).

## Layers

1. **Background** — theme preset (existing ten), style **Solid | Vertical
   gradient** (new bottom color), color pickers.
2. **Environment** — floor mode **None | Grid | Solid floor | Grid + floor**.
   Grid is the existing Unity-style infinite grid. Solid floor is a ground
   plane at Y=0 sized from model bounds, matte floor color, receiving the
   model's existing soft shadow. Persisted as two additive bools
   (`showsFloorGrid` existing, `showsSolidFloor` new) — the panel's mode
   picker maps onto them; no migration.
3. **Object** — master brightness plus per-light key/fill/rim/ambient,
   existing roughness/metallic, edges, STEP-color preservation.

## Slider semantics

Position `t ∈ [0,1]` maps to multiplier `4t²` of the light's theme-nominal
value: far left = fully off, mid = nominal, far right = 4x (blinding).
Master multiplies all lights; applied at theme construction in
`StudioWorkspaceView`, so renderers never see it. Raw intensities remain the
persisted values (existing keys unchanged); a light whose theme nominal is
zero falls back to the default theme's nominal so its slider still works.

## Instant feedback

Metal reads the theme per frame (uniforms). WebGPU receives the same values
through the existing revision-gated payload push. No debounce layers.

## Panel

The right-rail Appearance panel restructures into three collapsible
sections: Background / Environment / Object. Settings keeps binding the same
persisted keys; nothing is duplicated.

## Testing

Unit: slider curve (0 → off, mid → nominal, 1 → 4x, inverse round-trip),
floor-mode ↔ bools mapping, web payload encoding of the new fields.
Visual: live app on Metal and Three.js WebGPU.
