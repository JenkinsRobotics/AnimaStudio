import type { SketchDrawing, SketchPoint } from "../drawing";
import { pickCurve } from "../curves/picking";
import { splitSketchSegment } from "./split";
import { assertConstraintsSatisfied } from "./preserve-constraints";
import { insertFitSplinePoint } from "./insert-fit-spline-point";

/** Insert an editable cubic join without changing the curve's initial shape.
 * Existing finite contacts use Split's parameter remapping. The added G2
 * relation keeps the new join smooth during subsequent constrained edits. */
export function insertSketchSplinePoint(
  drawing: SketchDrawing,
  point: SketchPoint,
  tolerance: number,
): SketchDrawing {
  const target = pickCurve(drawing, point, tolerance);
  const source = drawing.contours[target.contour];
  if (
    source.type !== "path" ||
    source.segments[target.segment].type !== "bezier"
  )
    throw Error("Select the interior of a cubic spline span.");
  if (target.parameter <= 1e-6 || target.parameter >= 1 - 1e-6)
    throw Error("Choose a new spline point away from existing endpoints.");
  const fit = insertFitSplinePoint(
    drawing,
    target.contour,
    target.segment,
    target.parameter,
    point,
    tolerance,
  );
  if (fit) return fit;
  const next = splitSketchSegment(drawing, point, tolerance);
  const constraints = (next.constraints ??= []);
  const used = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  while (used.has(`spline-insert-${sequence}`)) sequence++;
  constraints.push({
    id: `spline-insert-${sequence}`,
    kind: "curvature",
    a: {
      kind: "curve",
      contour: target.contour,
      index: target.segment,
      parameter: 1,
    },
    b: {
      kind: "curve",
      contour: target.contour,
      index: target.segment + 1,
      parameter: 0,
    },
  });
  assertConstraintsSatisfied(next);
  return next;
}
