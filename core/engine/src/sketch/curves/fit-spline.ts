import { periodicSplineSecond } from "./periodic-spline";
import type { SketchContour, SketchPoint, SketchSegment } from "../drawing";
/** Chord-parameterized cubic interpolation (natural open ends or periodic closure).
 * Each clicked point is an
 * interpolation knot; native Bezier handles preserve the C2 curve exactly. */
export function fitSketchSpline(
  points: readonly SketchPoint[],
  options: { closed?: boolean; spanIntervals?: readonly number[] } = {},
): SketchContour {
  if (
    points.length < 2 ||
    points.length > 1001 ||
    points.some((p) => p.length !== 2 || p.some((v) => !Number.isFinite(v)))
  )
    throw Error("Spline needs 2–1001 finite fit points.");
  const closed = options.closed === true;
  if (closed && (points.length < 3 || points.length > 1000))
    throw Error("Closed spline needs 3–1000 fit points.");
  const n = points.length,
    h = points
      .slice(1)
      .map((p, i) => Math.hypot(p[0] - points[i][0], p[1] - points[i][1]));
  if (closed)
    h.push(
      Math.hypot(
        points[0][0] - points[n - 1][0],
        points[0][1] - points[n - 1][1],
      ),
    );
  if (h.some((v) => v < 1e-8))
    throw Error("Consecutive spline fit points must be distinct.");
  if (options.spanIntervals !== undefined) {
    if (
      options.spanIntervals.length !== h.length ||
      options.spanIntervals.some((v) => !Number.isFinite(v) || v <= 1e-10)
    )
      throw Error(
        "Spline span intervals must be positive and match its segments.",
      );
    h.splice(0, h.length, ...options.spanIntervals);
  }
  const second: SketchPoint[] = closed
    ? periodicSplineSecond(points, h)
    : points.map(() => [0, 0]);
  if (!closed)
    for (const axis of [0, 1] as const) {
      const diagonal: number[] = [],
        rhs: number[] = [];
      for (let i = 1; i < n - 1; i++) {
        const lower = h[i - 1],
          upper = h[i];
        const force =
          6 *
          ((points[i + 1][axis] - points[i][axis]) / upper -
            (points[i][axis] - points[i - 1][axis]) / lower);
        const factor = i === 1 ? 0 : lower / diagonal[i - 1];
        diagonal[i] = 2 * (lower + upper) - factor * h[i - 1];
        rhs[i] = force - (i === 1 ? 0 : factor * rhs[i - 1]);
      }
      for (let i = n - 2; i >= 1; i--)
        second[i][axis] =
          (rhs[i] - h[i] * second[(i + 1) % n][axis]) / diagonal[i];
    }
  const segments: SketchSegment[] = h.map((step, i) => {
    const a = points[i],
      b = points[(i + 1) % n],
      c1: SketchPoint = [0, 0],
      c2: SketchPoint = [0, 0];
    for (const axis of [0, 1] as const) {
      const delta = b[axis] - a[axis];
      c1[axis] =
        a[axis] +
        delta / 3 -
        (step * step * (2 * second[i][axis] + second[(i + 1) % n][axis])) / 18;
      c2[axis] =
        b[axis] -
        delta / 3 -
        (step * step * (second[i][axis] + 2 * second[(i + 1) % n][axis])) / 18;
    }
    return { type: "bezier", controls: [c1, c2], end: [...b] };
  });
  return { type: "path", start: [...points[0]], segments };
}
