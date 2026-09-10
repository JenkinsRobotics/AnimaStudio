import { mixedOffsetResiduals } from "./offset-mixed";
import { offsetSketchContour } from "../curves/offset";
import { contourClosed } from "../drawing";
import type { resolve } from "./entities";
type Entity = ReturnType<typeof resolve>;
/** Signed distance relation. Circle offsets preserve center; line offsets
 * preserve endpoint correspondence, direction and length, not just parallelism.
 */
export function offsetResiduals(
  a: Entity,
  b: Entity | undefined,
  distance: number,
): number[] {
  if (!Number.isFinite(distance))
    throw Error("Offset distance must be finite.");
  if (a.contour && b?.contour) {
    if (
      a.contour.type === "path" &&
      b.contour.type === "path" &&
      a.contour.segments.some((s) => s.type === "arc")
    )
      return mixedOffsetResiduals(a.contour, b.contour, distance);
    const expected = offsetSketchContour(a.contour, distance),
      target = b.contour;
    if (
      expected.type !== "path" ||
      target.type !== "path" ||
      expected.segments.length !== target.segments.length ||
      contourClosed(expected) !== contourClosed(target) ||
      target.segments.some((s) => s.type !== "line")
    )
      throw Error(
        "Offset chain topology changed; remove the offset relation before changing its edges.",
      );
    const p = [expected.start, ...expected.segments.map((s) => s.end)];
    const q = [target.start, ...target.segments.map((s) => s.end)];
    if (contourClosed(expected)) {
      p.pop();
      q.pop();
    }
    return p.flatMap((point, i) => [q[i][0] - point[0], q[i][1] - point[1]]);
  }
  if (a.circle && b?.circle && !a.arc && !b.arc)
    return [
      b.circle.center[0] - a.circle.center[0],
      b.circle.center[1] - a.circle.center[1],
      b.circle.radius - a.circle.radius - distance,
    ];
  if (a.arc && b?.arc) {
    const angle = b.arc.startAngle - a.arc.startAngle;
    // Five independent geometric equations; the through-point position is not
    // an extra geometric degree of freedom and must not be constrained here.
    return [
      b.arc.center[0] - a.arc.center[0],
      b.arc.center[1] - a.arc.center[1],
      b.arc.radius - a.arc.radius + Math.sign(a.arc.sweep) * distance,
      Math.atan2(Math.sin(angle), Math.cos(angle)),
      b.arc.sweep - a.arc.sweep,
    ];
  }
  if (a.line && b?.line) {
    const dx = a.line[1][0] - a.line[0][0],
      dy = a.line[1][1] - a.line[0][1],
      length = Math.hypot(dx, dy);
    if (length < 1e-10) throw Error("Cannot offset a zero-length line.");
    return a.line.flatMap((p, i) => [
      b.line![i][0] - p[0] + (dy / length) * distance,
      b.line![i][1] - p[1] - (dx / length) * distance,
    ]);
  }
  throw Error(
    "Offset relation requires two circles, two circular arcs or two lines.",
  );
}
