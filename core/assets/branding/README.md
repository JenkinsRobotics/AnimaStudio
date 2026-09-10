# Aether application artwork

`fancy/` and `simple/` contain scalable SVG renditions of Jonathan's supplied app-icon design sheets. These are vector reconstructions of the references, not the original raster source files. Each set contains distinct Studio, CAD (drafting grid/handles) and Animation (motion/timeline) artwork.

Fancy is the active set in `apps/`. `core/host/build-web-icons.py` copies the chosen set and renders PNG sizes; `--variant simple` selects the alternate set. Rebuild web products and browser launchers after changing sets. Shared `AppIcon` displays product branding; `AetherIcon` remains the monochrome toolbar vocabulary. Do not regenerate product branding from toolbar icons.

`originals/` preserves the original CAD/Anima artwork with its original hashes. `previous-browser-icons/` preserves the former generic browser icons. Never delete either archive when replacing the current artwork.
