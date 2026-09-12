import type { SketchPoint, SketchSegment } from "../drawing";
import { sketchArcGeometry } from "../arc-geometry";
export type OffsetCarrier = { start: SketchPoint; end: SketchPoint } & (
  | { kind: "line"; direction: SketchPoint }
  | { kind: "arc"; center: SketchPoint; radius: number; sweep: number }
);
const sub = (a: SketchPoint, b: SketchPoint): SketchPoint => [
  a[0] - b[0],
  a[1] - b[1],
];
const cross = (a: SketchPoint, b: SketchPoint) => a[0] * b[1] - a[1] * b[0];
export function offsetCarrier(
  start: SketchPoint,
  segment: SketchSegment,
  distance: number,
): OffsetCarrier {
  if (segment.type === "line") {
    const v = sub(segment.end, start),
      length = Math.hypot(...v);
    if (length < 1e-8) throw Error("Cannot offset a zero-length edge.");
    const direction: SketchPoint = [v[0] / length, v[1] / length];
    const shift = (p: SketchPoint): SketchPoint => [
      p[0] - direction[1] * distance,
      p[1] + direction[0] * distance,
    ];
    return {
      kind: "line",
      direction,
      start: shift(start),
      end: shift(segment.end),
    };
  }
  if (segment.type !== "arc")
    throw Error("Mixed offsets currently require lines and circular arcs.");
  const g = sketchArcGeometry(start, segment.middle, segment.end),
    radius = g.radius - Math.sign(g.sweep) * distance;
  if (radius <= 1e-8) throw Error("Offset collapses an arc.");
  const shift = (p: SketchPoint): SketchPoint => [
    g.center[0] + ((p[0] - g.center[0]) * radius) / g.radius,
    g.center[1] + ((p[1] - g.center[1]) * radius) / g.radius,
  ];
  return {
    kind: "arc",
    center: g.center,
    radius,
    sweep: g.sweep,
    start: shift(start),
    end: shift(segment.end),
  };
}
/** Intersect unbounded line/circle carriers, then choose the join nearest the original corner. */
export function joinOffsetCarriers(
  a: OffsetCarrier,
  b: OffsetCarrier,
  corner: SketchPoint,
): SketchPoint {
  if (Math.hypot(...sub(a.end, b.start)) < 1e-8) return a.end;
  let candidates: SketchPoint[] = [];
  if (a.kind === "line" && b.kind === "line") {
    const det = cross(a.direction, b.direction);
    if (Math.abs(det) < 1e-10)
      throw Error("Offset corner is parallel or reversing.");
    const t = cross(sub(b.start, a.end), b.direction) / det;
    candidates = [
      [a.end[0] + t * a.direction[0], a.end[1] + t * a.direction[1]],
    ];
  } else if (a.kind === "arc" && b.kind === "arc") {
    const v = sub(b.center, a.center),
      length = Math.hypot(...v);
    if (length < 1e-10) throw Error("Offset arcs have no unique corner.");
    const along =
        (a.radius * a.radius - b.radius * b.radius + length * length) /
        (2 * length),
      height2 = a.radius * a.radius - along * along;
    if (height2 >= -1e-9) {
      const h = Math.sqrt(Math.max(0, height2)),
        x = a.center[0] + (along * v[0]) / length,
        y = a.center[1] + (along * v[1]) / length;
      candidates = [
        [x - (h * v[1]) / length, y + (h * v[0]) / length],
        [x + (h * v[1]) / length, y - (h * v[0]) / length],
      ];
    }
  } else {
    const line = a.kind === "line" ? a : b,
      arc = a.kind === "arc" ? a : b;
    if (line.kind !== "line" || arc.kind !== "arc") throw Error();
    const v = sub(line.start, arc.center),
      projection = v[0] * line.direction[0] + v[1] * line.direction[1],
      discriminant =
        projection * projection -
        (v[0] * v[0] + v[1] * v[1] - arc.radius * arc.radius);
    if (discriminant >= -1e-9)
      for (const t of [
        -projection - Math.sqrt(Math.max(0, discriminant)),
        -projection + Math.sqrt(Math.max(0, discriminant)),
      ])
        candidates.push([
          line.start[0] + t * line.direction[0],
          line.start[1] + t * line.direction[1],
        ]);
  }
  if (!candidates.length)
    throw Error(
      "Offset curves do not meet; this corner requires a topology change.",
    );
  return candidates.sort(
    (p, q) => Math.hypot(...sub(p, corner)) - Math.hypot(...sub(q, corner)),
  )[0];
}
export function offsetCarrierSegment(
  c: OffsetCarrier,
  start: SketchPoint,
  end: SketchPoint,
): SketchSegment {
  if (c.kind === "line") {
    const v = sub(end, start);
    if (v[0] * c.direction[0] + v[1] * c.direction[1] <= 1e-8)
      throw Error("Offset reverses or collapses an edge.");
    return { type: "line", end };
  }
  const a = Math.atan2(start[1] - c.center[1], start[0] - c.center[0]),
    b = Math.atan2(end[1] - c.center[1], end[0] - c.center[0]);
  const tau = 2 * Math.PI,
    sign = Math.sign(c.sweep),
    sweep = sign * ((sign * (b - a) + tau) % tau);
  if (Math.abs(sweep) < 1e-8 || Math.abs(sweep - c.sweep) > Math.PI)
    throw Error("Offset arc requires a topology change.");
  return {
    type: "arc",
    end,
    middle: [
      c.center[0] + c.radius * Math.cos(a + sweep / 2),
      c.center[1] + c.radius * Math.sin(a + sweep / 2),
    ],
  };
}
