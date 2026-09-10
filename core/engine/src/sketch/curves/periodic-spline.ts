import type { SketchPoint } from "../drawing";
/** Periodic cubic second derivatives. A cyclic tridiagonal solve uses O(n)
 * storage and work, so large fit-point sets do not create dense matrices. */
export function periodicSplineSecond(
  points: readonly SketchPoint[],
  h: readonly number[],
): SketchPoint[] {
  const n = points.length,
    diagonal = h.map((v, i) => 2 * (v + h[(i + n - 1) % n]));
  const corner = h[n - 1],
    gamma = -diagonal[0];
  diagonal[0] -= gamma;
  diagonal[n - 1] -= (corner * corner) / gamma;
  const solve = (rhs: number[]): number[] => {
    const d = [...diagonal],
      x = [...rhs];
    for (let i = 1; i < n; i++) {
      const f = h[i - 1] / d[i - 1];
      d[i] -= f * h[i - 1];
      x[i] -= f * x[i - 1];
    }
    x[n - 1] /= d[n - 1];
    for (let i = n - 2; i >= 0; i--) x[i] = (x[i] - h[i] * x[i + 1]) / d[i];
    return x;
  };
  const u = Array(n).fill(0);
  u[0] = gamma;
  u[n - 1] = corner;
  const z = solve(u);
  const result: SketchPoint[] = points.map(() => [0, 0]);
  for (const axis of [0, 1] as const) {
    const rhs = points.map((p, i) => {
      const previous = (i + n - 1) % n,
        next = (i + 1) % n;
      return (
        6 *
        ((points[next][axis] - p[axis]) / h[i] -
          (p[axis] - points[previous][axis]) / h[previous])
      );
    });
    const x = solve(rhs),
      factor =
        (x[0] + (corner * x[n - 1]) / gamma) /
        (1 + z[0] + (corner * z[n - 1]) / gamma);
    x.forEach((value, i) => {
      result[i][axis] = value - factor * z[i];
    });
  }
  return result;
}
