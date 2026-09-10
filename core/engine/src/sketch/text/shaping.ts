import { shapingFontBytes } from "./woff";
import type { Font, PathCommand } from "opentype.js";
/** HarfBuzz performs substitutions/positioning; OpenType supplies exact glyph
 * curves. Keep shaping independent of UI and of preview placement. */
export async function shapedFontPath(
  bytes: ArrayBuffer,
  font: Font,
  text: string,
  em: number,
): Promise<PathCommand[]> {
  const hb = await import("harfbuzzjs");
  const blob = new hb.Blob(await shapingFontBytes(bytes)),
    face = new hb.Face(blob),
    shapedFont = new hb.Font(face);
  shapedFont.setScale(font.unitsPerEm, font.unitsPerEm);
  const commands: PathCommand[] = [];
  const scale = em / font.unitsPerEm;
  // The frame describes the first line. Later baselines advance below it in
  // font coordinates; empty lines retain their spacing. Never wrap to width.
  const metrics =
    font.ascender -
    font.descender +
    Math.max(0, Number(font.tables.hhea?.lineGap) || 0);
  const lineAdvance =
    Number.isFinite(metrics) && metrics > 0
      ? Math.max(font.unitsPerEm, metrics)
      : font.unitsPerEm;
  for (const [lineIndex, line] of text.split("\n").entries()) {
    if (!line) continue;
    const buffer = new hb.Buffer();
    buffer.addText(line);
    buffer.guessSegmentProperties();
    hb.shape(shapedFont, buffer);
    const infos = buffer.getGlyphInfos(),
      positions = buffer.getGlyphPositions();
    let x = 0,
      y = -lineIndex * lineAdvance;
    for (let i = 0; i < infos.length; i++) {
      const glyph = infos[i],
        position = positions[i];
      if (!glyph.codepoint)
        throw Error("The selected font cannot shape this text.");
      commands.push(
        ...font.glyphs
          .get(glyph.codepoint)
          .getPath(
            (x + position.xOffset) * scale,
            -(y + position.yOffset) * scale,
            em,
          ).commands,
      );
      x += position.xAdvance;
      y += position.yAdvance;
    }
  }
  return commands;
}
