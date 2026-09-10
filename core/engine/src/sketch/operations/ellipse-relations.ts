import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { ellipseShapeResiduals } from "../solver/ellipse-shape";
/** Capture full-ellipse intent without duplicating its geometric parameters. */
export function constrainSketchEllipse(
  source: SketchDrawing,
  contour: number,
): SketchDrawing {
  const next = structuredClone(source),
    path = next.contours[contour];
  if (!path) throw Error("Select an ellipse.");
  if (ellipseShapeResiduals(path).some((r) => Math.abs(r) > 1e-6))
    throw Error("Select a full ellipse with matching halves.");
  const constraints = (next.constraints ??= []);
  if (
    !constraints.some(
      (c) => c.kind === "ellipse-shape" && c.a.contour === contour,
    )
  ) {
    const used = new Set(constraints.map((c) => c.id));
    let n = 1;
    while (used.has(`ellipse-${n}`)) n++;
    constraints.push({
      id: `ellipse-${n}`,
      kind: "ellipse-shape",
      a: { kind: "contour", contour },
    });
  }
  validateSketchDrawing(next);
  return next;
}
