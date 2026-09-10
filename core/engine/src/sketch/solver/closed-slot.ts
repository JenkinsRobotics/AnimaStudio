import type { SketchDrawing } from "../drawing";
import type { DrawingConstraint } from "./types";
import { dimensionValue } from "./dimension-links";
import { closedSlotOffset } from "../curves/closed-slot";
import { resolve } from "./entities";
import { offsetResiduals } from "./offset";
export function closedSlotResiduals(
  d: SketchDrawing,
  c: DrawingConstraint,
): number[] {
  const source = d.contours[c.a.contour];
  if (
    c.a.kind !== "contour" ||
    c.b?.kind !== "contour" ||
    source?.type !== "path" ||
    (c.slotBoundary !== "inner" && c.slotBoundary !== "outer")
  )
    throw Error("Closed slot boundary references are invalid.");
  return offsetResiduals(
    resolve(d, c.a),
    resolve(d, c.b),
    closedSlotOffset(source, c.slotBoundary, dimensionValue(d, c)),
  );
}
