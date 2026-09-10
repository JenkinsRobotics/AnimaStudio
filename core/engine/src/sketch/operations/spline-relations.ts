import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { splineShapeResiduals } from "../solver/spline-shape";
/** Retain interpolation intent using the native contour's existing vertices. */
export function constrainFitSpline(
  source: SketchDrawing,
  contour: number,
): SketchDrawing {
  const next = structuredClone(source),
    path = next.contours[contour];
  if (!path || splineShapeResiduals(path).some((v) => Math.abs(v) > 1e-6))
    throw Error("Select an interpolated fit spline.");
  const constraints = (next.constraints ??= []);
  if (
    !constraints.some(
      (c) => c.kind === "spline-shape" && c.a.contour === contour,
    )
  ) {
    let id = "spline-shape";
    while (constraints.some((c) => c.id === id)) id += "-";
    constraints.push({
      id,
      kind: "spline-shape",
      a: { kind: "contour", contour },
    });
  }
  validateSketchDrawing(next);
  return next;
}
