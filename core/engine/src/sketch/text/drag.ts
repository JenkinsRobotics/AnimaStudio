import type { SketchDrawing, SketchPoint } from "../drawing";
import { similarityTransform, transformContour } from "../curves/similarity";
import { textOutlineDigest } from "./digest";

/** Seed a pointer solve by translating an intact retained group together.
 * Changing just the picked vertex would invalidate its digest and bypass the
 * grouped solver. Saved constraints can still resize/rotate or reject this seed. */
export function translateRetainedTextForDrag(
  drawing: SketchDrawing,
  contour: number,
  delta: SketchPoint,
): boolean {
  const selected = drawing.contours[contour]?.id;
  const item =
    selected &&
    drawing.textItems?.find((item) => item.contourIds.includes(selected));
  if (!item) return false;
  const indices = item.contourIds.map((id) =>
    drawing.contours.findIndex((c) => c.id === id),
  );
  if (
    indices.some((i) => i < 0) ||
    textOutlineDigest(indices.map((i) => drawing.contours[i])) !==
      item.outlineDigest
  )
    return false;
  const transform = similarityTransform([0, 0], delta, 0);
  for (const index of indices)
    drawing.contours[index] = transformContour(
      drawing.contours[index],
      transform,
    );
  item.originMillimeters = [
    item.originMillimeters[0] + delta[0],
    item.originMillimeters[1] + delta[1],
  ];
  item.outlineDigest = textOutlineDigest(
    indices.map((i) => drawing.contours[i]),
  );
  return true;
}
