import { expect, it } from "vitest";
import { polynomialBSpline } from "./bspline";
import type { SketchPoint } from "../drawing";
// Independent Cox-de Boor basis evaluation, rather than the converter's
// triangular control-net evaluation or sampled interpolation.
function basis(i: number, p: number, u: number, k: number[]): number {
  if (!p) return u >= k[i] && u < k[i + 1] ? 1 : 0;
  const a = k[i + p] - k[i],
    b = k[i + p + 1] - k[i + 1];
  return (
    (a ? ((u - k[i]) / a) * basis(i, p - 1, u, k) : 0) +
    (b ? ((k[i + p + 1] - u) / b) * basis(i + 1, p - 1, u, k) : 0)
  );
}
it("preserves linear, quadratic and cubic nonuniform spline geometry across spans", () => {
  for (const degree of [1, 2, 3]) {
    const points: SketchPoint[] = [
      [0, 0],
      [2, 8],
      [5, -3],
      [9, 7],
      [13, 1],
      [16, 4],
    ];
    const knots = [
      ...Array(degree + 1).fill(0),
      ...Array.from(
        { length: points.length - degree - 1 },
        (_, i) => (i + 1) ** 2,
      ),
      ...Array(degree + 1).fill(30),
    ];
    const result = polynomialBSpline(degree, knots, points);
    if (result.type !== "path") throw Error();
    let s = 0,
      previous = result.start;
    for (let span = degree; span < points.length; span++) {
      const lo = knots[span],
        hi = knots[span + 1];
      if (hi === lo) continue;
      const segment = result.segments[s++];
      for (const t of [0.01, 0.19, 0.41, 0.73, 0.99]) {
        const u = lo + (hi - lo) * t;
        const expected = [0, 1].map((axis) =>
          points.reduce(
            (sum, p, i) => sum + p[axis] * basis(i, degree, u, knots),
            0,
          ),
        );
        const actual =
          segment.type === "line"
            ? [0, 1].map(
                (axis) => previous[axis] * (1 - t) + segment.end[axis] * t,
              )
            : segment.type === "bezier"
              ? [0, 1].map(
                  (axis) =>
                    (1 - t) ** 3 * previous[axis] +
                    3 * (1 - t) ** 2 * t * segment.controls[0][axis] +
                    3 * (1 - t) * t * t * segment.controls[1][axis] +
                    t ** 3 * segment.end[axis],
                )
              : [];
        expect(actual[0]).toBeCloseTo(expected[0], 9);
        expect(actual[1]).toBeCloseTo(expected[1], 9);
      }
      previous = segment.end;
    }
  }
});
it("supports unclamped spans and repeated interior knots, and rejects discontinuities", () => {
  const cp: SketchPoint[] = [
    [0, 0],
    [1, 2],
    [2, 4],
    [3, 1],
    [4, 0],
  ];
  const unclamped = polynomialBSpline(2, [0, 1, 2, 3, 4, 5, 6, 7], cp);
  if (unclamped.type !== "path") throw Error();
  expect(unclamped.start).toEqual([0.5, 1]);
  expect(unclamped.segments.at(-1)?.end).toEqual([3.5, 0.5]);
  expect(polynomialBSpline(2, [0, 0, 0, 1, 1, 2, 2, 2], cp).type).toBe("path");
  expect(() =>
    polynomialBSpline(2, [0, 0, 0, 1, 1, 1, 2, 2, 2], [...cp, [5, 0]]),
  ).toThrow("Disconnected");
  expect(() => polynomialBSpline(2, [0, 0, 0, 1, 2, 1, 2, 2], cp)).toThrow(
    "invalid",
  );
});
