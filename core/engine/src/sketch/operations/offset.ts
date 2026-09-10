import { appendOffsetRelations } from "./offset-relations";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { offsetSketchContour } from "../curves/offset";
export { offsetSketchContour } from "../curves/offset";
export function offsetSketch(
  source: SketchDrawing,
  indices: number[],
  distance: number,
): SketchDrawing {
  if (!indices.length) throw Error("Select contours to offset.");
  const unique = [...new Set(indices)];
  if (unique.some((i) => !Number.isInteger(i) || !source.contours[i]))
    throw Error("Invalid offset contour.");
  const next = structuredClone(source);
  next.contours.push(
    ...unique.map((i) => offsetSketchContour(source.contours[i], distance)),
  );
  appendOffsetRelations(source, next, unique, distance);
  validateSketchDrawing(next);
  return next;
}
