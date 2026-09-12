import type { SketchPoint } from "../drawing";
import type { Curve, CurveIntersection } from "./pairs";
import { closestSegmentParameter, segmentPoint } from "./parameterization";
/** Detect affine reparameterizations of a common cubic interval using its exact control polygon. */
export function cubicOverlap(
  first: Curve,
  second: Curve,
): CurveIntersection[] | undefined {
  if (first.segment.type !== "bezier" || second.segment.type !== "bezier")
    return;
  const candidates: CurveIntersection[] = [];
  for (const t of [0, 1]) {
    const point = segmentPoint(first.start, first.segment, t),
      closest = closestSegmentParameter(second.start, second.segment, point);
    if (closest.distance < 1e-8)
      candidates.push({ first: t, second: closest.parameter, point });
  }
  for (const u of [0, 1]) {
    const point = segmentPoint(second.start, second.segment, u),
      closest = closestSegmentParameter(first.start, first.segment, point);
    if (closest.distance < 1e-8)
      candidates.push({ first: closest.parameter, second: u, point });
  }
  candidates.sort((a, b) => a.first - b.first);
  const a = candidates[0],
    b = candidates.at(-1);
  if (
    !a ||
    !b ||
    b.first - a.first < 1e-8 ||
    Math.abs(b.second - a.second) < 1e-8
  )
    return;
  const derivative = (curve: Curve, t: number): SketchPoint => {
    if (curve.segment.type !== "bezier") throw new Error("Expected cubic.");
    const [p, q] = curve.segment.controls,
      start = curve.start,
      end = curve.segment.end;
    return [0, 1].map(
      (k) =>
        3 *
        ((1 - t) ** 2 * (p[k] - start[k]) +
          2 * (1 - t) * t * (q[k] - p[k]) +
          t * t * (end[k] - q[k])),
    ) as SketchPoint;
  };
  const polygon = (curve: Curve, lo: number, hi: number) => {
    const start = segmentPoint(curve.start, curve.segment, lo),
      end = segmentPoint(curve.start, curve.segment, hi),
      d0 = derivative(curve, lo),
      d1 = derivative(curve, hi),
      span = (hi - lo) / 3;
    return [
      start,
      [start[0] + d0[0] * span, start[1] + d0[1] * span],
      [end[0] - d1[0] * span, end[1] - d1[1] * span],
      end,
    ];
  };
  const p = polygon(first, a.first, b.first),
    q = polygon(second, a.second, b.second);
  if (
    p.every(
      (point, i) => Math.hypot(point[0] - q[i][0], point[1] - q[i][1]) < 1e-7,
    )
  )
    return [a, b];
}
