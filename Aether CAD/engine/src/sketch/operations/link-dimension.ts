import { dimensionValue } from "../solver/dimension-links";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { solveDrawingConstraints } from "../solver/solve";
/** Store an affine relationship by stable dimension IDs. No resolved cache or
 * UI formula string enters the canonical model. Cycles/unit errors reject atomically. */
export function linkSketchDimension(
  source: SketchDrawing,
  id: string,
  driverId: string,
  scale = 1,
  offset = 0,
): SketchDrawing {
  const next = structuredClone(source);
  const dimension = next.constraints?.find((c) => c.id === id);
  if (!dimension || dimension.reference)
    throw Error("Select a driving dimension.");
  delete dimension.valueExpression;
  delete dimension.value;
  delete dimension.valueSign;
  dimension.valueFrom = driverId;
  dimension.valueScale = scale;
  dimension.valueOffset = offset;
  const solved = solveDrawingConstraints(next);
  validateSketchDrawing(solved);
  return solved;
}

/** Make a linked dimension independent at its current solved value. Its own
 * followers remain linked to its stable ID, and no geometry is modified. */
export function unlinkSketchDimension(
  source: SketchDrawing,
  id: string,
): SketchDrawing {
  validateSketchDrawing(source);
  const next = structuredClone(source);
  const dimension = next.constraints?.find((c) => c.id === id);
  if (!dimension || dimension.reference)
    throw Error("Select a driving dimension.");
  const value = dimensionValue(source, dimension);
  dimension.value = value;
  delete dimension.valueFrom;
  delete dimension.valueSign;
  delete dimension.valueScale;
  delete dimension.valueOffset;
  validateSketchDrawing(next);
  return next;
}
