import type { Font } from "opentype.js";
const parsedFonts = new WeakMap<ArrayBuffer, Promise<Font>>();
/** Reuse immutable caller-owned font bytes during metrics and outline generation. */
export function loadSketchTextFont(bytes: ArrayBuffer): Promise<Font> {
  if (!bytes.byteLength || bytes.byteLength > 32 * 1024 * 1024)
    return Promise.reject(Error("Font data must be between 1 byte and 32 MB."));
  let parsed = parsedFonts.get(bytes);
  if (!parsed) {
    parsed = import("opentype.js").then(({ parse }) => parse(bytes));
    parsedFonts.set(bytes, parsed);
  }
  return parsed;
}
export async function sketchTextFontAscenderRatio(
  bytes: ArrayBuffer,
): Promise<number> {
  const font = await loadSketchTextFont(bytes),
    ratio = font.ascender / font.unitsPerEm;
  if (!Number.isFinite(ratio) || ratio <= 0)
    throw Error("The font needs a positive ascender for text-height sizing.");
  return ratio;
}
