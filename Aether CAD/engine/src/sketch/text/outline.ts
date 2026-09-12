import { shapedFontPath } from "./shaping";
import { loadSketchTextFont } from "./font";
import { normalizeSketchText } from "./content";
import { textPlacementTransform, type TextOrientation } from "./placement";
import type { PathCommand } from "opentype.js";
import {
  sameSketchPoint,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { classifyImportedRegions } from "../import/classify-regions";
import { transformContour } from "../curves/similarity";

/** Font path coordinates are y-down; sketch coordinates are y-up. Quadratic
 * font curves convert exactly to cubic Beziers, never sampled polylines. */
export function fontPathContours(
  commands: readonly PathCommand[],
): SketchDrawing {
  const drawing: SketchDrawing = { type: "drawing", contours: [] };
  let path:
    Extract<SketchDrawing["contours"][number], { type: "path" }> | undefined;
  let current: SketchPoint = [0, 0];
  const closeContour = () => {
    if (!path) return;
    if (!sameSketchPoint(current, path.start))
      path.segments.push({ type: "line", end: [...path.start] });
    else if (path.segments.length) path.segments.at(-1)!.end = [...path.start];
    if (path.segments.length) drawing.contours.push(path);
    path = undefined;
  };
  for (const command of commands) {
    if (command.type === "M") {
      closeContour();
      current = [command.x, -command.y];
      path = { type: "path", start: current, segments: [] };
    } else if (command.type === "Z") {
      if (!path) throw Error("Font outline closes a missing contour.");
      closeContour();
    } else {
      if (!path) throw Error("Font outline is missing its starting point.");
      const end: SketchPoint = [command.x, -command.y];
      if (command.type === "L") {
        if (!sameSketchPoint(current, end))
          path.segments.push({ type: "line", end });
      } else if (command.type === "C") {
        path.segments.push({
          type: "bezier",
          controls: [
            [command.x1, -command.y1],
            [command.x2, -command.y2],
          ],
          end,
        });
      } else if (command.type === "Q") {
        const q: SketchPoint = [command.x1, -command.y1];
        path.segments.push({
          type: "bezier",
          controls: [
            [
              current[0] + (2 * (q[0] - current[0])) / 3,
              current[1] + (2 * (q[1] - current[1])) / 3,
            ],
            [
              end[0] + (2 * (q[0] - end[0])) / 3,
              end[1] + (2 * (q[1] - end[1])) / 3,
            ],
          ],
          end,
        });
      }
      current = end;
    }
  }
  closeContour();
  validateSketchDrawing(drawing);
  return drawing;
}

/** Generate editable boundaries from caller-provided OpenType bytes. Fonts are
 * loaded lazily, keeping the parser out of the CAD startup bundle. Em size is
 * the font's design-em height, not a glyph bounding-box measurement. */
export async function sketchTextOutline(
  fontBytes: ArrayBuffer,
  text: string,
  options: TextOrientation & {
    emSizeMillimeters: number;
  },
): Promise<SketchDrawing> {
  text = normalizeSketchText(text);
  if (
    !Number.isFinite(options.emSizeMillimeters) ||
    options.emSizeMillimeters <= 0
  )
    throw Error("Text em size must be positive and finite.");
  const font = await loadSketchTextFont(fontBytes);
  for (const character of text)
    if (character !== "\n" && !font.hasChar(character))
      throw Error(
        `The selected font has no glyph for ${JSON.stringify(character)}.`,
      );
  const commands = await shapedFontPath(
    fontBytes,
    font,
    text,
    options.emSizeMillimeters,
  );
  const drawing = classifyImportedRegions(fontPathContours(commands));
  const transform = textPlacementTransform(options);
  drawing.contours = drawing.contours.map((c) =>
    transformContour(c, transform),
  );
  validateSketchDrawing(drawing);
  return drawing;
}
