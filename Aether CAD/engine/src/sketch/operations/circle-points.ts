import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
import { sketchVariantContour } from "../primitives";

/** Retain three-point circle placement as selectable points on the analytic circle. */
export function constrainThreePointCircle(
  source: SketchDrawing,
  contour: number,
  points: readonly SketchPoint[],
): SketchDrawing {
  if (points.length !== 3)
    throw new Error("A three-point circle needs three points.");
  const next = structuredClone(source),
    circle = next.contours[contour];
  if (!circle || circle.type !== "circle")
    throw new Error("Select an existing sketch circle.");
  const expected = sketchVariantContour(
    "three-point-circle",
    points.map((p) => [...p]),
  );
  if (
    expected.type !== "circle" ||
    Math.hypot(
      expected.center[0] - circle.center[0],
      expected.center[1] - circle.center[1],
    ) > 1e-6 ||
    Math.abs(expected.radius - circle.radius) > 1e-6
  )
    throw new Error("The placement points must lie on the selected circle.");
  const constraints = (next.constraints ??= []);
  const ids = new Set(constraints.map((c) => c.id));
  let sequence = 1;
  for (const point of points) {
    const index = next.contours.length;
    next.contours.push({
      type: "path",
      construction: true,
      start: [...point],
      segments: [],
    });
    while (ids.has(`circle-point-${sequence}`)) sequence++;
    const id = `circle-point-${sequence++}`;
    ids.add(id);
    constraints.push({
      id,
      kind: "coincident",
      a: { contour: index, kind: "point", index: 0 },
      b: { contour, kind: "circle" },
    });
  }
  validateSketchDrawing(next);
  return next;
}
