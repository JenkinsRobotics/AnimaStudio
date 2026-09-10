import {
  contourClosed,
  type SketchContour,
  type SketchPoint,
} from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
type Path = Extract<SketchContour, { type: "path" }>;
const delta = (a: SketchPoint, b: SketchPoint): SketchPoint => [
  b[0] - a[0],
  b[1] - a[1],
];
const angle = (x: number) => Math.atan2(Math.sin(x), Math.cos(x));
/** Locus equations avoid repeatedly intersecting tangent carriers during finite
 * differences. Shared path vertices supply the joins; open ends retain their
 * source longitudinal/angle parameters. No sampled polygon representation.
 */
export function mixedOffsetResiduals(
  source: Path,
  target: Path,
  distance: number,
): number[] {
  if (
    source.segments.length !== target.segments.length ||
    contourClosed(source) !== contourClosed(target)
  )
    throw Error("Offset chain topology changed.");
  const result: number[] = [];
  let p = source.start,
    q = target.start;
  source.segments.forEach((s, i) => {
    const t = target.segments[i];
    if (t.type !== s.type) throw Error("Offset chain edge type changed.");
    const first = !contourClosed(source) && i === 0,
      last = !contourClosed(source) && i === source.segments.length - 1;
    if (s.type === "line" && t.type === "line") {
      const u = delta(p, s.end),
        v = delta(q, t.end),
        length = Math.hypot(...u),
        otherLength = Math.hypot(...v);
      if (length < 1e-10 || otherLength < 1e-10)
        throw Error("Offset line has zero length.");
      const x = u[0] / length,
        y = u[1] / length;
      result.push(
        Math.atan2(x * v[1] - y * v[0], x * v[0] + y * v[1]),
        (q[1] - p[1]) * x - (q[0] - p[0]) * y - distance,
      );
      if (first) result.push((q[0] - p[0]) * x + (q[1] - p[1]) * y);
      if (last)
        result.push((t.end[0] - s.end[0]) * x + (t.end[1] - s.end[1]) * y);
    } else if (s.type === "arc" && t.type === "arc") {
      const a = sketchArcGeometry(p, s.middle, s.end),
        b = sketchArcGeometry(q, t.middle, t.end),
        sign = Math.sign(a.sweep);
      if (a.radius - sign * distance <= 1e-8)
        throw Error("Offset collapses an arc.");
      result.push(
        b.center[0] - a.center[0],
        b.center[1] - a.center[1],
        Math.sign(b.sweep) * b.radius - sign * a.radius + distance,
      );
      if (first) result.push(angle(b.startAngle - a.startAngle));
      if (last)
        result.push(angle(b.startAngle + b.sweep - a.startAngle - a.sweep));
    } else
      throw Error(
        "Mixed offset relationships require lines and circular arcs.",
      );
    p = s.end;
    q = t.end;
  });
  return result;
}
