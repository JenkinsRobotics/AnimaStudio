import { deleteSketchContour } from "./delete";
import type { SketchDrawing, SketchPoint } from "../drawing";
import { drawingCurves, pickCurve } from "../curves/picking";
import { curveIntersections } from "../curves/pairs";
import { trimSketchCurve } from "./trim";
/** Exact stroke/curve crossings, independent of pointer event spacing. */
export function trimSketchSweep(
  source: SketchDrawing,
  from: SketchPoint,
  to: SketchPoint,
  pointTolerance = 1e-5,
): SketchDrawing {
  if (
    ![...from, ...to, pointTolerance].every(Number.isFinite) ||
    pointTolerance < 0
  )
    throw new Error(
      "Enter finite stroke coordinates and a nonnegative tolerance.",
    );
  if (Math.hypot(to[0] - from[0], to[1] - from[1]) < 1e-9) return source;
  const stroke = { start: from, segment: { type: "line" as const, end: to } };
  let next = source;
  const dx = to[0] - from[0],
    dy = to[1] - from[1],
    length = dx * dx + dy * dy;
  // Delete only standalone points within the stroke capsule, in descending index order.
  for (let index = source.contours.length - 1; index >= 0; index--) {
    const contour = source.contours[index];
    if (contour.type !== "path" || contour.segments.length) continue;
    const t = Math.max(
      0,
      Math.min(
        1,
        ((contour.start[0] - from[0]) * dx +
          (contour.start[1] - from[1]) * dy) /
          length,
      ),
    );
    if (
      Math.hypot(
        contour.start[0] - from[0] - t * dx,
        contour.start[1] - from[1] - t * dy,
      ) <= pointTolerance
    )
      next = deleteSketchContour(next, index);
  }
  const hits = drawingCurves(next)
    .flatMap(({ curve }) => curveIntersections(stroke, curve))
    .sort((a, b) => a.first - b.first);
  for (const hit of hits) {
    // Earlier crossings can already have removed this interval.
    try {
      pickCurve(next, hit.point, 1e-5);
    } catch {
      continue;
    }
    next = trimSketchCurve(next, hit.point, 1e-5);
  }
  return next;
}
