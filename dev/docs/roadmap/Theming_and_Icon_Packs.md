# Theming and icon packs

Direction (Jonathan, 2026-09-10): the suite must be structurally themable —
no hardcoded presentation in app code. Light mode exposed the cost of
inlined palettes; this contract prevents regrowth.

## The contract (shipped)

- **Color flows through variables only.** Core structure uses `--aether-*`
  tokens (`core/ui/tokens/tokens.css`, mirrored from `tokens.json`). Page- or
  product-specific decoration uses scoped variables (`--studio-*`,
  `--setup-*`, `--library-*`) declared in one theme block per stylesheet with
  dark defaults and `.aether-light-theme` overrides.
- **A theme is a variable-override scope.** Dark is `:root`; light is
  `.aether-light-theme` (applied by the shared appearance bootstrap in
  `@aether/ui` StudioChrome — System/Light/Dark, OS-following, cross-tab).
  A future theme pack is another override block/class produced from a token
  set; no rule changes required.
- **Enforcement:** `node dev/check-theme-literals.mjs` fails on raw color
  literals outside variable declarations (var() fallbacks allowed). Wired
  into the studio build. Expansion path: add `Aether CAD/src` and
  `aether-animation/web/src` to its roots after their sweeps.
- **Icon packs:** all interface icons resolve through the `AetherIcon` /
  `ToolIcon` name registries backed by `core/assets/icons/`. The registry map
  is the single swap seam — an icon pack is an alternate module registering
  the same names. Products must not inline icon geometry (existing rule).

## Shipped 2026-09-10: default theme + default icon pack

- **Default theme** `core/assets/themes/aether-default.json` — a theme is a
  JSON manifest shipping BOTH modes (dark + light) plus geometry and type.
  `node dev/build-theme-css.mjs [themeId]` generates `core/ui/tokens/tokens.css`
  from it (parity-verified against the previous hand-written values). A new
  theme is a new manifest + regenerate; widget rules never change. tokens.json
  is superseded by the manifest and kept only for reference.
- **Default icon pack** `core/assets/icons/pack.json` — the pack is the
  artwork directory plus the AetherIcon registry that names it.
  `node dev/check-icon-pack.mjs` guards registry↔artwork drift (68 icons at
  ship). An alternate pack = alternate artwork registered under the same names.
- **Geometry contract tokens** — `--aether-size-row` (36px),
  `--aether-size-icon-slot` (36px), `--aether-size-grid` (4px): the row =
  [icon slot][label] block system (constant in collapsed/expanded states,
  headers become dividers) now driven by tokens. This is the foundation for
  sidebars, toolbars, and tables; the CAD library sidebar is the reference
  implementation.

## Community drop-in flow (shipped 2026-09-10, evening)

Bringing a new theme, VS Code-style:
1. Drop `my-theme.json` into `core/assets/themes/` (same manifest shape as
   the default: id, name, `modes.dark`, `modes.light`).
2. `node dev/build-theme-css.mjs` — installed themes emit side by side as
   `.aether-theme-<id>` scoped classes; the default stays on `:root`.
3. Select at runtime with `setAetherTheme("<id>")` from `@aether/ui`
   (persisted per device, synced across tabs, composes with System/Light/Dark
   because every theme ships both modes). Selection UI in Settings is the
   remaining piece.

Bringing a new icon pack:
1. Ship artwork under the pack's directory with a `pack.json`.
2. Register at runtime: `registerIconPack({ name: svgMarkup, … })` from
   `@aether/ui` — partial packs fall back per icon to the default artwork.
   Build-time compilation of a pack directory into that object is the listed
   codegen follow-up; `dev/check-icon-pack.mjs` guards the default pack.

Proven end-to-end: a test manifest generated its scoped classes and was
removed cleanly; runtime selection and icon override are unit-tested.

## Asset layout + hot swap (shipped 2026-09-10, late)

```
core/assets/
  themes/            # one manifest per theme (aether-default.json is built in)
  icons/             # the default icon pack (pack.json + 68 SVGs)
  icon-packs/        # one directory per additional pack (pack.json + SVGs)
  branding/          # identity artwork (originals preserved — standing rule)
```

Hot swap is live, VS Code-style: `installAetherTheme(manifest)` injects a
theme's scoped CSS at runtime (no build) and `setAetherTheme(id)` activates
it instantly; `registerIconPack({...})` re-renders every mounted icon
immediately via the pack store. Both paths are unit-tested; READMEs in the
asset directories carry the contributor recipes.

## Scope split: suite themes vs app render settings

Universal themes (this document) style the interface chrome of every app.
The 3D **viewport render themes** (Midnight / Graphite / CAD Light /
Blueprint, ported from the native PreviewAppearance) are **Aether CAD app
settings** — CAD owns the WebGPU/OCCT viewport — stored per device in
`aether-cad-appearance`, controlled from CAD's Appearance panel, and
deliberately outside the suite theme manifests.

## Open items

- Tokenize `Aether CAD/src` and `aether-animation/web/src` stylesheets, then
  add them to the checker roots.
- Light palette polish pass (decorative overlays, chip tints) with Jonathan.
- Adaptive renderer palette so the 3D viewport can follow themes.
- A second theme manifest to prove the pipeline end-to-end; VS Code-style
  selection UI once more than one theme/pack exists.
- Icon-pack codegen for the AetherIcon registry (today the registry is the
  hand-maintained seam; the checker keeps it honest).
- Adopt the geometry tokens in the CAD workspace toolbar/panels and the
  library tables.
