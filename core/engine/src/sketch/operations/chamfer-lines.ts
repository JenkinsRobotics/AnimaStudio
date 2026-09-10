import type { SketchDrawing } from "../drawing";
import { applyLineCorner, type CornerLine } from "./line-corner-selection";
import { chamferSketchCorner, type ChamferSize } from "./chamfer";
/** Distance and angle are anchored to the first selected line, independent of path order. */
export function chamferSketchLines(
  source: SketchDrawing,
  a: CornerLine,
  b: CornerLine,
  size: ChamferSize,
): SketchDrawing {
  return applyLineCorner(
    source,
    a,
    b,
    (drawing, contour, vertex, firstIsIncoming) =>
      chamferSketchCorner(drawing, contour, vertex, size, !firstIsIncoming),
  );
}
