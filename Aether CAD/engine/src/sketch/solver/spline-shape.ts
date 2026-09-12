import { contourClosed, type SketchContour } from "../drawing";
import { fitSketchSpline } from "../curves/fit-spline";
/** Fit knots are the existing contour vertices; no duplicate point array is
 * persisted. Handles are constrained to their natural/periodic interpolation. */
export function splineShapeResiduals(
  path: SketchContour,
  spanIntervals?: readonly number[],
): number[] {
  if (
    path.type !== "path" ||
    !path.segments.length ||
    path.segments.some((s) => s.type !== "bezier")
  )
    throw Error("Fit spline shape requires a whole Bezier contour.");
  const closed = contourClosed(path),
    points = [path.start, ...path.segments.map((s) => s.end)];
  if (closed) points.pop();
  const expected = fitSketchSpline(points, { closed, spanIntervals });
  if (expected.type !== "path") throw Error("Invalid fit spline.");
  return path.segments.flatMap((segment, i) => {
    const target = expected.segments[i];
    if (segment.type !== "bezier" || target.type !== "bezier")
      throw Error("Invalid fit spline segment.");
    return segment.controls.flatMap((point, j) => [
      point[0] - target.controls[j][0],
      point[1] - target.controls[j][1],
    ]);
  });
}
