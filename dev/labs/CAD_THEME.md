# CAD Theme — the approved shading look

Jonathan approved this look (the blue enclosure render, 2026-07-17). Captured
so it ports to Anima Studio's viewport unchanged. Single source:
`dev/labs/OcctSwift/Sources/GeomBench/CADTheme.swift`.

## The recipe

**Surface** — matte plastic/metal PBR, no shine to hide edges:
- `PhysicallyBasedMaterial`, roughness **0.5**, metallic **0.0**
- base color = the STEP file's XCAF face color (fallback neutral `0.72,0.74,0.78`)

**Lighting** — studio three-point (this is what makes parts read as solid, not
flat; curved faces shade smoothly, edges stay crisp):

| Light | Color | Intensity | Direction (from) |
|---|---|---|---|
| Key | white | 3000 | (0.5, 0.9, 0.6) |
| Fill | cool blue `0.75,0.82,1.0` | 1200 | (-0.7, 0.3, 0.4) |
| Rim | white | 900 | (0.1, 0.5, -0.8) |

All three are `DirectionalLightComponent`s aimed at the origin.

**Background** — dark charcoal `0.16, 0.17, 0.19`.

**Selection** — face → systemOrange (+ emissive 0.4); edge → systemTeal
(+ emissive 0.6).

## Porting to Anima Studio

The main app's viewport already has a lighting/appearance system; this theme is
the target values to match (or add as a "CAD" preset). The key differences from
a naive setup that make it look right:
1. **Three-point lighting**, not a single light — the fill+rim are what stop the
   part looking flat/muddy (the earlier bench bug was *zero* lights).
2. **Roughness 0.5** — glossy hides geometry; fully matte looks like clay. 0.5
   is the CAD sweet spot.
3. **Real XCAF colors** from the shim, not a uniform tint.
