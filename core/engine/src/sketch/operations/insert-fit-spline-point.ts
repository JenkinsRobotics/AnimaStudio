import type { SketchDrawing, SketchPoint } from "../drawing";
import { splitSketchSegment } from "./split";
import { assertConstraintsSatisfied } from "./preserve-constraints";

/** Preserve natural/periodic interpolation on insertion by subdividing its
 * parameter interval, rather than recomputing chord lengths after insertion. */
export function insertFitSplinePoint(
  drawing: SketchDrawing,
  contour: number,
  segment: number,
  parameter: number,
  point: SketchPoint,
  tolerance: number,
): SketchDrawing | undefined {
  const shape = drawing.constraints?.find(
    (c) => c.kind === "spline-shape" && c.a.contour === contour,
  );
  if (!shape) return undefined;
  assertConstraintsSatisfied(drawing);
  const path = drawing.contours[contour];
  if (path.type !== "path") throw Error("Select a fit spline.");
  let start = path.start;
  const intervals = shape.splineSpanIntervals
    ? [...shape.splineSpanIntervals]
    : path.segments.map((s) => {
        const length = Math.hypot(s.end[0] - start[0], s.end[1] - start[1]);
        start = s.end;
        return length;
      });
  const interval = intervals[segment];
  intervals.splice(
    segment,
    1,
    interval * parameter,
    interval * (1 - parameter),
  );
  const source = structuredClone(drawing);
  source.constraints = source.constraints!.filter((c) => c.id !== shape.id);
  const next = splitSketchSegment(source, point, tolerance);
  (next.constraints ??= []).push({
    ...structuredClone(shape),
    splineSpanIntervals: intervals,
  });
  assertConstraintsSatisfied(next);
  return next;
}
