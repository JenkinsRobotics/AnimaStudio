# Bundled Noto Sans fonts

Unmodified Regular, Bold, Italic and BoldItalic TTF files from the archived
[official Noto fonts repository](https://github.com/notofonts/noto-fonts/tree/main/hinted/ttf/NotoSans).
`LICENSE` contains the original SIL Open Font License notice. `sources.json`
records download URLs, SHA-256 checksums and byte lengths for reproducible review.

CAD imports font URLs through Vite and loads only the selected style from the
installation. No font CDN is required. Retained sketch text embeds the selected
font bytes so native reopening does not depend on the original installation.
Keep the license with these unmodified fonts when packaging them.
