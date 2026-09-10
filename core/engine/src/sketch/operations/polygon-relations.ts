import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { constraintResiduals } from "../solver/residuals";
import type { DrawingConstraint, SketchEntityRef } from "../solver/types";

/** Equal chords on a common circle preserve regularity using ordinary constraints.
 * Circumscribed polygons also retain the user's inner sizing circle. Tangency
 * alone is insufficient: an equilateral tangential quadrilateral can be a rhombus.
 */
export function constrainSketchPolygon(
  source: SketchDrawing,
  contour: number,
  center: SketchPoint,
  circumscribed = false,
): SketchDrawing {
  const next = structuredClone(source),
    path = next.contours[contour];
  if (
    !path ||
    path.type !== "path" ||
    !contourClosed(path) ||
    path.segments.length < 3 ||
    path.segments.length > 100 ||
    path.segments.some((s) => s.type !== "line")
  )
    throw new Error(
      "Polygon relations require a closed path with 3–100 straight edges.",
    );
  if (!center.every(Number.isFinite))
    throw new Error("Polygon center must be finite.");
  const constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  const add = (constraint: Omit<DrawingConstraint, "id">) => {
    while (ids.has(`polygon-${sequence}`)) sequence++;
    const c = { ...constraint, id: `polygon-${sequence++}` };
    ids.add(c.id);
    constraints.push(c);
    if (
      constraintResiduals(next, c).some(
        (r) => !Number.isFinite(r) || Math.abs(r) > 1e-6,
      )
    )
      throw new Error(
        "The path is not a regular polygon around the selected center.",
      );
  };
  const radius = Math.hypot(
    path.start[0] - center[0],
    path.start[1] - center[1],
  );
  const outer = next.contours.length;
  next.contours.push({
    type: "circle",
    construction: true,
    center: [...center],
    radius,
  });
  const circle: SketchEntityRef = { contour: outer, kind: "circle" };
  const line = (index: number): SketchEntityRef => ({
    contour,
    kind: "line",
    index,
  });
  for (let index = 0; index < path.segments.length; index++) {
    add({
      kind: "coincident",
      a: { contour, kind: "point", index },
      b: circle,
    });
    if (index) add({ kind: "equal", a: line(0), b: line(index) });
  }
  if (circumscribed) {
    const inner = next.contours.length;
    next.contours.push({
      type: "circle",
      construction: true,
      center: [...center],
      radius: radius * Math.cos(Math.PI / path.segments.length),
    });
    const sizing: SketchEntityRef = { contour: inner, kind: "circle" };
    add({ kind: "concentric", a: circle, b: sizing });
    add({ kind: "tangent", a: line(0), b: sizing });
  }
  validateSketchDrawing(next);
  return next;
}
