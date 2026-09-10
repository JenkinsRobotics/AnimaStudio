import { offsetMixedPath } from "./offset-mixed";
import { collinearLineContact } from "./line-overlap";
import {
  contourClosed,
  type SketchContour,
  type SketchPoint,
} from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
const cross = (a: SketchPoint, b: SketchPoint) => a[0] * b[1] - a[1] * b[0];
const sub = (a: SketchPoint, b: SketchPoint): SketchPoint => [
  a[0] - b[0],
  a[1] - b[1],
];
/** Exact offset; positive is left of directed paths, outward for circles.
 * Mitered line chains, circles and individual circular arcs retain native curves.
 * Mixed line/arc chains use exact carrier intersections; spline chains reject rather than silently polygonizing.
 */
export function offsetSketchContour(
  source: SketchContour,
  distance: number,
): SketchContour {
  if (!Number.isFinite(distance) || Math.abs(distance) < 1e-8)
    throw Error("Enter a nonzero finite offset distance.");
  const out = structuredClone(source);
  delete out.id;
  if (out.type === "circle") {
    out.radius += distance;
    if (out.radius <= 1e-8) throw Error("Offset collapses the circle.");
    return out;
  }
  if (out.segments.length === 1 && out.segments[0].type === "arc") {
    const s = out.segments[0],
      g = sketchArcGeometry(out.start, s.middle, s.end);
    const radius = g.radius - Math.sign(g.sweep) * distance;
    if (radius <= 1e-8) throw Error("Offset collapses the arc.");
    const radial = (p: SketchPoint): SketchPoint => [
      g.center[0] + ((p[0] - g.center[0]) * radius) / g.radius,
      g.center[1] + ((p[1] - g.center[1]) * radius) / g.radius,
    ];
    out.start = radial(out.start);
    s.middle = radial(s.middle);
    s.end = radial(s.end);
    return out;
  }
  if (out.segments.length > 1 && out.segments.some((s) => s.type === "arc"))
    return offsetMixedPath(out, distance);
  if (!out.segments.length || out.segments.some((s) => s.type !== "line"))
    throw Error(
      "Offset currently requires a line chain, circle or individual circular arc.",
    );
  const closed = contourClosed(out),
    points = [out.start, ...out.segments.map((s) => s.end)];
  const edges = out.segments.map((_, i) => {
    const delta = sub(points[i + 1], points[i]),
      length = Math.hypot(...delta);
    if (length < 1e-8) throw Error("Cannot offset a zero-length edge.");
    const direction: SketchPoint = [delta[0] / length, delta[1] / length];
    const shift = (p: SketchPoint): SketchPoint => [
      p[0] - direction[1] * distance,
      p[1] + direction[0] * distance,
    ];
    return { direction, start: shift(points[i]), end: shift(points[i + 1]) };
  });
  const join = (
    before: (typeof edges)[number],
    after: (typeof edges)[number],
  ): SketchPoint => {
    const det = cross(before.direction, after.direction);
    if (Math.abs(det) < 1e-10) {
      if (
        before.direction[0] * after.direction[0] +
          before.direction[1] * after.direction[1] <
        0
      )
        throw Error("Cannot offset a reversing corner.");
      return before.end;
    }
    const t = cross(sub(after.start, before.end), after.direction) / det;
    return [
      before.end[0] + t * before.direction[0],
      before.end[1] + t * before.direction[1],
    ];
  };
  const result: SketchPoint[] = [
    closed ? join(edges.at(-1)!, edges[0]) : edges[0].start,
  ];
  for (let i = 1; i < edges.length; i++)
    result.push(join(edges[i - 1], edges[i]));
  result.push(closed ? [...result[0]] : edges.at(-1)!.end);
  for (let i = 0; i < edges.length; i++) {
    const delta = sub(result[i + 1], result[i]);
    if (
      delta[0] * edges[i].direction[0] + delta[1] * edges[i].direction[1] <=
      1e-8
    )
      throw Error("Offset collapses or reverses an edge.");
    for (let j = i + 2; j < edges.length; j++) {
      if (closed && i === 0 && j === edges.length - 1) continue;
      const v = sub(result[j + 1], result[j]),
        det = cross(delta, v);
      if (Math.abs(det) < 1e-10) {
        if (
          collinearLineContact(
            result[i],
            result[i + 1],
            result[j],
            result[j + 1],
          )
        )
          throw Error("Offset would self-intersect.");
        continue;
      }
      const between = sub(result[j], result[i]),
        t = cross(between, v) / det,
        u = cross(between, delta) / det;
      if (t >= 0 && t <= 1 && u >= 0 && u <= 1)
        throw Error("Offset would self-intersect.");
    }
  }
  out.start = result[0];
  out.segments = result.slice(1).map((end) => ({ type: "line", end }));
  return out;
}
