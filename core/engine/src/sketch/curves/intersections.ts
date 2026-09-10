import type { SketchPoint, SketchSegment } from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
import { ellipseFrame } from "./parameterization";
const cross = (a: SketchPoint, b: SketchPoint) => a[0] * b[1] - a[1] * b[0];
const subtract = (a: SketchPoint, b: SketchPoint): SketchPoint => [
  a[0] - b[0],
  a[1] - b[1],
];
const unique = (values: number[]) =>
  values
    .sort((a, b) => a - b)
    .filter((t, i, list) => !i || Math.abs(t - list[i - 1]) > 1e-8);
/** Isolate all roots on a bounded interval using derivative extrema (including tangencies). */
export function polynomialRoots(coefficients: number[], lo = 0, hi = 1): number[] {
  const scale = Math.max(...coefficients.map(Math.abs), 1),
    c = coefficients.map((v) => v / scale);
  while (c.length > 1 && Math.abs(c.at(-1)!) < 1e-13) c.pop();
  const value = (x: number) => c.reduceRight((sum, n) => sum * x + n, 0);
  if (c.length === 1) return [];
  if (c.length === 2) {
    const t = -c[0] / c[1];
    return t >= lo - 1e-10 && t <= hi + 1e-10
      ? [Math.max(lo, Math.min(hi, t))]
      : [];
  }
  const critical = polynomialRoots(
      c.slice(1).map((v, i) => v * (i + 1)),
      lo,
      hi,
    ),
    bounds = unique([lo, ...critical, hi]),
    roots: number[] = [];
  for (const t of bounds) if (Math.abs(value(t)) < 1e-10) roots.push(t);
  for (let i = 1; i < bounds.length; i++) {
    let a = bounds[i - 1],
      b = bounds[i],
      fa = value(a);
    if (fa * value(b) >= 0) continue;
    for (let n = 0; n < 60; n++) {
      const middle = (a + b) / 2,
        fm = value(middle);
      if (fa * fm <= 0) b = middle;
      else {
        a = middle;
        fa = fm;
      }
    }
    roots.push((a + b) / 2);
  }
  return unique(roots);
}
function quadratic(a: number, b: number, c: number): number[] {
  const discriminant = b * b - 4 * a * c;
  if (discriminant < -1e-10 || a < 1e-20) return [];
  const root = Math.sqrt(Math.max(0, discriminant));
  return unique([(-b - root) / (2 * a), (-b + root) / (2 * a)]);
}
/** Parameters on an infinite line where it intersects one finite exact sketch segment. */
export function lineSegmentIntersections(
  lineStart: SketchPoint,
  lineEnd: SketchPoint,
  start: SketchPoint,
  segment: SketchSegment,
): number[] {
  const direction = subtract(lineEnd, lineStart),
    lengthSquared = direction[0] ** 2 + direction[1] ** 2;
  if (lengthSquared < 1e-20)
    throw new Error("Intersection line has zero length.");
  const parameter = (p: SketchPoint) =>
    ((p[0] - lineStart[0]) * direction[0] +
      (p[1] - lineStart[1]) * direction[1]) /
    lengthSquared;
  if (segment.type === "line") {
    const other = subtract(segment.end, start),
      den = cross(direction, other);
    if (Math.abs(den) < 1e-12) return [];
    const delta = subtract(start, lineStart),
      u = cross(delta, direction) / den;
    return u >= -1e-9 && u <= 1 + 1e-9 ? [cross(delta, other) / den] : [];
  }
  if (segment.type === "bezier") {
    const points = [start, ...segment.controls, segment.end],
      f = points.map((p) => cross(subtract(p, lineStart), direction));
    const roots = polynomialRoots([
      f[0],
      3 * (f[1] - f[0]),
      3 * (f[2] - 2 * f[1] + f[0]),
      f[3] - 3 * f[2] + 3 * f[1] - f[0],
    ]);
    return roots.map((t) => {
      const u = 1 - t;
      return parameter([
        u * u * u * points[0][0] +
          3 * u * u * t * points[1][0] +
          3 * u * t * t * points[2][0] +
          t * t * t * points[3][0],
        u * u * u * points[0][1] +
          3 * u * u * t * points[1][1] +
          3 * u * t * t * points[2][1] +
          t * t * t * points[3][1],
      ]);
    });
  }
  const frame =
    segment.type === "ellipse"
      ? ellipseFrame(start, segment)
      : (() => {
          const arc = sketchArcGeometry(start, segment.middle, segment.end);
          return {
            ...arc,
            radiusX: arc.radius,
            radiusY: arc.radius,
            rotation: 0,
          };
        })();
  const cos = Math.cos(frame.rotation),
    sin = Math.sin(frame.rotation),
    q = subtract(lineStart, frame.center);
  const px = (cos * q[0] + sin * q[1]) / frame.radiusX,
    py = (-sin * q[0] + cos * q[1]) / frame.radiusY;
  const dx = (cos * direction[0] + sin * direction[1]) / frame.radiusX,
    dy = (-sin * direction[0] + cos * direction[1]) / frame.radiusY;
  const roots = quadratic(
      dx * dx + dy * dy,
      2 * (px * dx + py * dy),
      px * px + py * py - 1,
    ),
    tau = 2 * Math.PI;
  return roots.filter((t) => {
    const angle = Math.atan2(py + t * dy, px + t * dx),
      extent =
        frame.sweep >= 0
          ? (angle - frame.startAngle + tau) % tau
          : (frame.startAngle - angle + tau) % tau;
    return (
      extent <= Math.abs(frame.sweep) + 1e-8 || Math.abs(extent - tau) < 1e-8
    );
  });
}
