# Icon packs

One directory per pack: `icon-packs/<id>/pack.json` plus the pack's SVGs.
The default pack lives in `core/assets/icons/` (68 stroke glyphs, 24px,
1.7px stroke, currentColor) and is guarded by `dev/check-icon-pack.mjs`.

A pack overrides icons **by name** through the registry seam:
`registerIconPack({ home: "<svg …>", … })` from `@aether/ui` — a hot swap
(every mounted icon re-renders immediately); missing names fall back to the
default artwork, so partial packs are fine. Pack-directory → registration
codegen is the listed follow-up in the theming roadmap.
