import { symmetricSplineResiduals } from "./symmetric-spline";
import type { SketchPoint } from "../drawing";
import type { resolve } from "./entities";
type Entity = ReturnType<typeof resolve>;
/** Symmetry acts on supporting curves, not trimmed line/arc endpoints. */
export function symmetricResiduals(
  a: Entity,
  b: Entity | undefined,
  axis: Entity | undefined,
  splineReversed = false,
): number[] {
  if (!axis?.line) throw Error("Select a line as the symmetry axis.");
  const [origin, end] = axis.line,
    dx = end[0] - origin[0],
    dy = end[1] - origin[1],
    length = Math.hypot(dx, dy);
  if (length < 1e-10) throw Error("Symmetry axis must have nonzero length.");
  const x = dx / length,
    y = dy / length;
  const reflect = (p: SketchPoint): SketchPoint => {
    const normal = (p[1] - origin[1]) * x - (p[0] - origin[0]) * y;
    return [p[0] + 2 * normal * y, p[1] - 2 * normal * x];
  };
  const pair = (p: SketchPoint, q: SketchPoint) => {
    const r = reflect(p);
    return [q[0] - r[0], q[1] - r[1]];
  };
  if(a.contour && b?.contour)return symmetricSplineResiduals(a.contour,b.contour,reflect,splineReversed);
  if (a.point && b?.point) return pair(a.point, b.point);
  if (a.circle && b?.circle)
    return [
      ...pair(a.circle.center, b.circle.center),
      a.circle.radius - b.circle.radius,
    ];
  if (a.ellipse && b?.ellipse) {
    const tensor = (rx: number, ry: number, angle: number) => {
      const c = Math.cos(angle),
        s = Math.sin(angle),
        u = rx * rx,
        v = ry * ry;
      return [u * c * c + v * s * s, (u - v) * s * c, u * s * s + v * c * c];
    };
    const p = a.ellipse,
      q = b.ellipse;
    const expected = tensor(
        p.radiusX,
        p.radiusY,
        2 * Math.atan2(y, x) - p.rotation,
      ),
      actual = tensor(q.radiusX, q.radiusY, q.rotation);
    const scale = Math.max(p.radiusX, p.radiusY, q.radiusX, q.radiusY);
    return [
      ...pair(p.center, q.center),
      ...actual.map((v, i) => (v - expected[i]) / scale),
    ];
  }
  if (a.line && b?.line) {
    const p = reflect(a.line[0]),
      q = reflect(a.line[1]),
      u = [q[0] - p[0], q[1] - p[1]],
      v = [b.line[1][0] - b.line[0][0], b.line[1][1] - b.line[0][1]],
      n = Math.hypot(...u),
      m = Math.hypot(...v);
    if (n < 1e-10 || m < 1e-10)
      throw Error("Symmetric lines must have nonzero length.");
    return [
      (u[0] * v[1] - u[1] * v[0]) / (n * m),
      ((b.line[0][1] - p[1]) * u[0] - (b.line[0][0] - p[0]) * u[1]) / n,
    ];
  }
  throw Error(
    "Select two points, two lines, or two circles/circular arcs, or two ellipses.",
  );
}
