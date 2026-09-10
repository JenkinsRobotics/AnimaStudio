import { lineLineMeasurement } from "./line-line-measurement";
import type { SketchDrawing } from "../drawing";
import type { DrawingConstraint } from "./types";
import { resolve } from "./entities";
import { pointLineMeasurement } from "./point-line-measurement";
export const referenceDimensionKinds = [
  "length",
  "distance",
  "horizontal-distance",
  "vertical-distance",
  "radius",
  "diameter",
  "angle",
] as const;
/** Reference dimensions measure current geometry, never provide equations. */
export function measuredDimensionValue(
  d: SketchDrawing,
  c: DrawingConstraint,
): number {
  if (
    c.value !== undefined ||
    c.valueFrom !== undefined ||
    c.valueSign !== undefined ||
    c.valueScale !== undefined ||
    c.valueOffset !== undefined
  )
    throw Error("Reference dimensions cannot contain driving values or links.");
  const a = resolve(d, c.a),
    b = c.b ? resolve(d, c.b) : undefined;
  if ((c.kind === "radius" || c.kind === "diameter") && a.circle)
    return a.circle.radius * (c.kind === "diameter" ? 2 : 1);
  if (c.kind === "length" && a.line)
    return Math.hypot(a.line[1][0] - a.line[0][0], a.line[1][1] - a.line[0][1]);
  if (a.point && b?.point) {
    const dx = b.point[0] - a.point[0],
      dy = b.point[1] - a.point[1];
    if (c.kind === "distance") return Math.hypot(dx, dy);
    if (c.kind === "horizontal-distance") return dx;
    if (c.kind === "vertical-distance") return dy;
  }
  if (c.kind === "distance") {
    if (a.line && b?.line) {
      const m = lineLineMeasurement(a.line, b.line);
      if (Math.abs(m.parallelError) > 1e-7)
        throw Error("Reference line distance requires parallel lines.");
      return m.distance;
    }
    if (a.point && b?.line)
      return pointLineMeasurement(a.point, b.line).distance;
    if (a.line && b?.point)
      return pointLineMeasurement(b.point, a.line).distance;
  }
  if (c.kind === "angle" && a.line && b?.line) {
    const u = [a.line[1][0] - a.line[0][0], a.line[1][1] - a.line[0][1]],
      v = [b.line[1][0] - b.line[0][0], b.line[1][1] - b.line[0][1]];
    if (Math.hypot(...u) < 1e-10 || Math.hypot(...v) < 1e-10)
      throw Error("Cannot measure a zero-length line angle.");
    return (
      (Math.atan2(u[0] * v[1] - u[1] * v[0], u[0] * v[0] + u[1] * v[1]) * 180) /
      Math.PI
    );
  }
  throw Error("Select compatible geometry for a reference dimension.");
}
