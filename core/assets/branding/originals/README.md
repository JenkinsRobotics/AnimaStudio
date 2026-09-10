# Original application icons — preserve permanently

Jonathan explicitly requested preservation of the original app icons, even when
new artwork is used by current launchers (2026-09-08).

- `aether-cad/AppIconSource.svg`: original blue/purple drafting-A CAD icon,
  matching the screenshot supplied by Jonathan.
- `anima-studio/AppIconSource.svg`: original Anima Studio A/motion icon.
- `anima-studio/AppIcon.appiconset/`: original macOS PNG sizes and catalog.
- `anima-studio/AppIcon.icns`: original compiled macOS icon.

`manifest.json` records original locations and SHA-256 hashes. Copies are
byte-for-byte; the existing source files and archived native app remain intact.
If a previous CAD compiled icon was available in the build cache, it is included
and recorded in the manifest too.

This directory is an archive, not generated output. Never point icon generation,
cleanup, or application-build replacement steps here. New variants belong in
`../apps/` or another distinctly named asset directory. Retain these originals
when the archived Swift application is eventually retired.
