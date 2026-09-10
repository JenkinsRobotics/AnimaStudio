import type { SketchContour, SketchPoint, SketchSegment } from "../drawing";

/** Converts each polynomial B-spline knot span to a native cubic Bezier (or
 * line). Degree <= 3 makes interpolation exact, not a sampled approximation.
 * Knot parameters are dimensionless; controls are in sketch millimeters. */
export function polynomialBSpline(
  degree: number,
  knots: readonly number[],
  controls: readonly SketchPoint[],
): SketchContour {
  if (!Number.isInteger(degree) || degree < 1 || degree > 3)
    throw Error("Spline degrees above three need native higher-order support.");
  if (
    controls.length <= degree ||
    knots.length !== controls.length + degree + 1 ||
    controls.some(
      (p) => p.length !== 2 || p.some((v) => !Number.isFinite(v)),
    ) ||
    knots.some((v, i) => !Number.isFinite(v) || (i > 0 && v < knots[i - 1]))
  )
    throw Error("Spline control points or knot vector are invalid.");
  const first = knots[degree],
    last = knots[controls.length];
  if (!(last > first)) throw Error("Spline parameter domain is empty.");
  // Interior multiplicity above degree describes a disconnected curve.
  for (let i = degree + 1; i < controls.length; i++)
    if (knots[i] > first && knots[i] < last && knots[i] === knots[i - degree])
      throw Error("Disconnected spline spans need separate curves.");
  const evaluate = (span: number, u: number): SketchPoint => {
    const d = controls
      .slice(span - degree, span + 1)
      .map((p) => [...p] as SketchPoint);
    for (let r = 1; r <= degree; r++)
      for (let j = degree; j >= r; j--) {
        const i = span - degree + j,
          width = knots[i + degree - r + 1] - knots[i];
        const alpha = width === 0 ? 0 : (u - knots[i]) / width;
        d[j] = [
          d[j - 1][0] * (1 - alpha) + d[j][0] * alpha,
          d[j - 1][1] * (1 - alpha) + d[j][1] * alpha,
        ];
      }
    return d[degree];
  };
  const segments: SketchSegment[] = [];
  let start: SketchPoint | undefined;
  for (let span = degree; span < controls.length; span++) {
    const lo = knots[span],
      hi = knots[span + 1];
    if (hi === lo) continue;
    if (segments.length >= 1000)
      throw Error("Spline exceeds 1000 editable spans.");
    const a = evaluate(span, lo),
      b = evaluate(span, hi);
    start ??= a;
    if (degree === 1) segments.push({ type: "line", end: b });
    else {
      const f = evaluate(span, lo + (hi - lo) / 3),
        g = evaluate(span, lo + (2 * (hi - lo)) / 3);
      const c1: SketchPoint = [0, 0],
        c2: SketchPoint = [0, 0];
      for (const axis of [0, 1] as const) {
        const q1 = f[axis] - a[axis],
          q2 = g[axis] - a[axis],
          q3 = b[axis] - a[axis];
        c1[axis] = a[axis] + 3 * q1 - 1.5 * q2 + q3 / 3;
        c2[axis] = a[axis] - 1.5 * q1 + 3 * q2 - (5 * q3) / 6;
      }
      segments.push({ type: "bezier", controls: [c1, c2], end: b });
    }
  }
  if (!start) throw Error("Spline has no nonzero knot spans.");
  return { type: "path", start, segments };
}
