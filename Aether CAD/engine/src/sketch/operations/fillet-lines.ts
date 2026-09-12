import type { SketchDrawing } from "../drawing";
import { applyLineCorner, type CornerLine } from "./line-corner-selection";
import { filletSketchCorner } from "./fillet";
export type FilletLine = CornerLine;
/** Fillets share line joining/reference mapping with chamfers. */
export function filletSketchLines(
  source: SketchDrawing,
  a: FilletLine,
  b: FilletLine,
  radius: number,
): SketchDrawing {
  return applyLineCorner(source, a, b, (drawing, contour, vertex) =>
    filletSketchCorner(drawing, contour, vertex, radius),
  );
}
