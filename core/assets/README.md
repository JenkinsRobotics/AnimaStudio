# Shared Aether assets

Repository-owned artwork used by the Aether Studio family lives here.
This is an asset directory, not another runtime framework or semantic engine.

- `icons/`: canonical SVG interface artwork. `core/ui/src/AetherIcon.tsx` renders
  these files; applications import `AetherIcon` from `@aether/ui`.
- `branding/`: suite and product identity artwork. Current product artwork comes from `branding/fancy/` (with `branding/simple/` retained as an alternate). The shared `AppIcon` widget and browser/Dock builds use the selected artwork in `branding/apps/`.

Semantic aliases such as `model` → `design` reuse one SVG source.

Interface icons use a 24 × 24 viewBox, consistent rounded 1.7-unit strokes and
`currentColor`, so shared UI themes control their appearance. Prefer clear paths
and shapes; do not use emoji, font glyphs, embedded raster images or SVG text as
substitutes for interface icon geometry. Keep accessible labels on controls.

SVG is preferred for icons/logos/diagrams. Photographs and textures can use
appropriate raster formats; fonts retain their license files. Add illustrations,
textures or fonts here when there is an actual asset to share. Imported user
models, character files and project media remain project data, not suite assets.

Current icon and branding sources are repository-owned under the root Apache-2.0
license. Any third-party additions must retain attribution and their own license.
There are still legacy text glyphs in some product tool catalogs and shared
controls; migrate those deliberately to reviewed semantic SVGs, not text inside
an SVG wrapper or one generic icon reused for unrelated operations.

## Original branding is retained

The user's original CAD and Anima Studio app icons are preserved byte-for-byte
in [branding/originals](branding/originals/README.md), with source provenance and
SHA-256 hashes. Keep these permanently even when new launchers use different
icons or the archived native application is removed. Current generated browser
and Dock icons live separately in `branding/apps/`.
