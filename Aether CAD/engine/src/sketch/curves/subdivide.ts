import type { SketchPoint, SketchSegment } from "../drawing";
import { ellipseFrame, segmentPoint } from "./parameterization";
const lerp = (a: SketchPoint, b: SketchPoint, t: number): SketchPoint => [
  a[0] + t * (b[0] - a[0]),
  a[1] + t * (b[1] - a[1]),
];
/** Exact degree-preserving subdivision. No polygon approximation is persisted. */
export function subdivideSegment(
  start: SketchPoint,
  segment: SketchSegment,
  t: number,
): [SketchSegment, SketchSegment] {
  if (!Number.isFinite(t) || t <= 1e-9 || t >= 1 - 1e-9)
    throw new Error(
      "Choose a split point inside the curve, away from its endpoints.",
    );
  if (segment.type === "bezier") {
    const a = lerp(start, segment.controls[0], t),
      b = lerp(segment.controls[0], segment.controls[1], t),
      c = lerp(segment.controls[1], segment.end, t);
    const d = lerp(a, b, t),
      e = lerp(b, c, t),
      mid = lerp(d, e, t);
    return [
      { type: "bezier", controls: [a, d], end: mid },
      { type: "bezier", controls: [e, c], end: [...segment.end] },
    ];
  }
  const mid = segmentPoint(start, segment, t);
  if (segment.type === "line")
    return [
      { type: "line", end: mid },
      { type: "line", end: [...segment.end] },
    ];
  if (segment.type === "arc")
    return [
      { type: "arc", middle: segmentPoint(start, segment, t / 2), end: mid },
      {
        type: "arc",
        middle: segmentPoint(start, segment, (1 + t) / 2),
        end: [...segment.end],
      },
    ];
  const frame = ellipseFrame(start, segment);
  const {
    id: discardedEdge,
    endVertexId: discardedVertex,
    ...geometry
  } = segment;
  const base = { ...geometry, radiusX: frame.radiusX, radiusY: frame.radiusY };
  return [
    { ...base, end: mid, largeArc: Math.abs(frame.sweep * t) > Math.PI },
    {
      ...base,
      end: [...segment.end],
      largeArc: Math.abs(frame.sweep * (1 - t)) > Math.PI,
    },
  ];
}
