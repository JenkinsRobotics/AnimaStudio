import type { SketchPoint, SketchSegment } from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
export interface EllipseFrame {
  center: SketchPoint;
  radiusX: number;
  radiusY: number;
  rotation: number;
  startAngle: number;
  sweep: number;
}
const tau = 2 * Math.PI;
const angleBetween = (u: SketchPoint, v: SketchPoint) =>
  Math.atan2(u[0] * v[1] - u[1] * v[0], u[0] * v[0] + u[1] * v[1]);
/** SVG endpoint-arc convention, also used by Replicad ellipseTo. Angles here are radians. */
export function ellipseFrame(
  start: SketchPoint,
  segment: Extract<SketchSegment, { type: "ellipse" }>,
): EllipseFrame {
  const rotation = (segment.rotationDegrees * Math.PI) / 180,
    cos = Math.cos(rotation),
    sin = Math.sin(rotation);
  let rx = Math.abs(segment.radiusX),
    ry = Math.abs(segment.radiusY);
  const dx = (start[0] - segment.end[0]) / 2,
    dy = (start[1] - segment.end[1]) / 2;
  const x = cos * dx + sin * dy,
    y = -sin * dx + cos * dy;
  if (rx <= 0 || ry <= 0 || Math.hypot(dx, dy) < 1e-12)
    throw new Error("Ellipse needs positive radii and distinct endpoints.");
  const correction = (x * x) / (rx * rx) + (y * y) / (ry * ry);
  if (correction > 1) {
    const scale = Math.sqrt(correction);
    rx *= scale;
    ry *= scale;
  }
  const denominator = rx * rx * y * y + ry * ry * x * x;
  const factor =
    (segment.largeArc === segment.sweep ? -1 : 1) *
    Math.sqrt(Math.max(0, (rx * rx * ry * ry - denominator) / denominator));
  const cx = (factor * rx * y) / ry,
    cy = (-factor * ry * x) / rx;
  const center: SketchPoint = [
    cos * cx - sin * cy + (start[0] + segment.end[0]) / 2,
    sin * cx + cos * cy + (start[1] + segment.end[1]) / 2,
  ];
  const u: SketchPoint = [(x - cx) / rx, (y - cy) / ry],
    v: SketchPoint = [(-x - cx) / rx, (-y - cy) / ry];
  let sweep = angleBetween(u, v);
  if (!segment.sweep && sweep > 0) sweep -= tau;
  if (segment.sweep && sweep < 0) sweep += tau;
  return {
    center,
    radiusX: rx,
    radiusY: ry,
    rotation,
    startAngle: Math.atan2(u[1], u[0]),
    sweep,
  };
}
export function ellipsePoint(
  frame: EllipseFrame,
  parameter: number,
): SketchPoint {
  const angle = frame.startAngle + parameter * frame.sweep,
    x = frame.radiusX * Math.cos(angle),
    y = frame.radiusY * Math.sin(angle),
    cos = Math.cos(frame.rotation),
    sin = Math.sin(frame.rotation);
  return [
    frame.center[0] + cos * x - sin * y,
    frame.center[1] + sin * x + cos * y,
  ];
}
export function segmentPoint(
  start: SketchPoint,
  segment: SketchSegment,
  t: number,
): SketchPoint {
  if (!Number.isFinite(t)) throw new Error("Curve parameter must be finite.");
  if (segment.type === "line")
    return [
      start[0] + t * (segment.end[0] - start[0]),
      start[1] + t * (segment.end[1] - start[1]),
    ];
  if (segment.type === "ellipse")
    return ellipsePoint(ellipseFrame(start, segment), t);
  if (segment.type === "arc") {
    const arc = sketchArcGeometry(start, segment.middle, segment.end),
      a = arc.startAngle + t * arc.sweep;
    return [
      arc.center[0] + arc.radius * Math.cos(a),
      arc.center[1] + arc.radius * Math.sin(a),
    ];
  }
  const u = 1 - t,
    a = u * u * u,
    b = 3 * u * u * t,
    c = 3 * u * t * t,
    d = t * t * t;
  return [
    a * start[0] +
      b * segment.controls[0][0] +
      c * segment.controls[1][0] +
      d * segment.end[0],
    a * start[1] +
      b * segment.controls[0][1] +
      c * segment.controls[1][1] +
      d * segment.end[1],
  ];
}
/** Nearest parameter for picking. Sample all basins, then refine; saved geometry is never sampled. */
export function closestSegmentParameter(
  start: SketchPoint,
  segment: SketchSegment,
  point: SketchPoint,
): { parameter: number; distance: number } {
  const squared = (t: number) => {
    const p = segmentPoint(start, segment, t);
    return (p[0] - point[0]) ** 2 + (p[1] - point[1]) ** 2;
  };
  if (segment.type === "line") {
    const x = segment.end[0] - start[0],
      y = segment.end[1] - start[1],
      den = x * x + y * y;
    const parameter = den
      ? Math.max(
          0,
          Math.min(
            1,
            ((point[0] - start[0]) * x + (point[1] - start[1]) * y) / den,
          ),
        )
      : 0;
    return { parameter, distance: Math.sqrt(squared(parameter)) };
  }
  const samples = 64,
    values = Array.from({ length: samples + 1 }, (_, i) =>
      squared(i / samples),
    );
  let best = values[0],
    parameter = 0;
  for (let i = 0; i <= samples; i++) {
    if (values[i] < best) {
      best = values[i];
      parameter = i / samples;
    }
    if (
      i === 0 ||
      i === samples ||
      values[i] > values[i - 1] ||
      values[i] > values[i + 1]
    )
      continue;
    let lo = (i - 1) / samples,
      hi = (i + 1) / samples;
    for (let step = 0; step < 45; step++) {
      const a = lo + (hi - lo) / 3,
        b = hi - (hi - lo) / 3;
      if (squared(a) < squared(b)) hi = b;
      else lo = a;
    }
    const t = (lo + hi) / 2,
      value = squared(t);
    if (value < best) {
      best = value;
      parameter = t;
    }
  }
  return { parameter, distance: Math.sqrt(best) };
}
