import { expect, it } from "vitest";
import { fitSketchSpline } from "./fit-spline";
import type { SketchPoint } from "../drawing";
it("interpolates every fit point and preserves C1/C2 continuity in chord parameters", () => {
  const points: SketchPoint[] = [
    [0, 0],
    [2, 5],
    [8, -2],
    [10, 3],
    [15, 0],
  ];
  const c = fitSketchSpline(points);
  if (c.type !== "path") throw Error();
  expect(c.start).toEqual(points[0]);
  expect(c.segments.map((s) => s.end)).toEqual(points.slice(1));
  for (let i = 0; i < c.segments.length - 1; i++) {
    const a = c.segments[i],
      b = c.segments[i + 1];
    if (a.type !== "bezier" || b.type !== "bezier") throw Error();
    const h = Math.hypot(
        points[i + 1][0] - points[i][0],
        points[i + 1][1] - points[i][1],
      ),
      j = Math.hypot(
        points[i + 2][0] - points[i + 1][0],
        points[i + 2][1] - points[i + 1][1],
      );
    for (const axis of [0, 1]) {
      expect((3 * (a.end[axis] - a.controls[1][axis])) / h).toBeCloseTo(
        (3 * (b.controls[0][axis] - a.end[axis])) / j,
        10,
      );
      expect(
        (6 * (a.end[axis] - 2 * a.controls[1][axis] + a.controls[0][axis])) /
          (h * h),
      ).toBeCloseTo(
        (6 * (a.end[axis] - 2 * b.controls[0][axis] + b.controls[1][axis])) /
          (j * j),
        10,
      );
    }
  }
});
it("handles two-point straight splines and rejects duplicate adjacent fit points", () => {
  const c = fitSketchSpline([
    [0, 0],
    [9, 0],
  ]);
  if (c.type !== "path" || c.segments[0].type !== "bezier") throw Error();
  expect(c.segments[0].controls).toEqual([
    [3, 0],
    [6, 0],
  ]);
  expect(() =>
    fitSketchSpline([
      [0, 0],
      [0, 0],
    ]),
  ).toThrow("distinct");
  expect(() => fitSketchSpline([[0, 0]])).toThrow("2–1001");
});

it("closes periodic splines with C2 continuity at every fit point, including the seam", () => {
  for (const points of [
    [
      [0, 0],
      [10, 0],
      [3, 8],
    ],
    [
      [0, 0],
      [8, -2],
      [13, 5],
      [4, 12],
      [-2, 3],
    ],
  ] as SketchPoint[][]) {
    const c = fitSketchSpline(points, { closed: true });
    if (c.type !== "path") throw Error();
    expect(c.segments).toHaveLength(points.length);
    expect(c.segments.at(-1)?.end).toEqual(c.start);
    const h = points.map((p, i) =>
      Math.hypot(
        points[(i + 1) % points.length][0] - p[0],
        points[(i + 1) % points.length][1] - p[1],
      ),
    );
    for (let i = 0; i < points.length; i++) {
      const j = (i + 1) % points.length,
        a = c.segments[i],
        b = c.segments[j];
      if (a.type !== "bezier" || b.type !== "bezier") throw Error();
      for (const axis of [0, 1]) {
        expect((3 * (a.end[axis] - a.controls[1][axis])) / h[i]).toBeCloseTo(
          (3 * (b.controls[0][axis] - a.end[axis])) / h[j],
          9,
        );
        expect(
          (6 * (a.end[axis] - 2 * a.controls[1][axis] + a.controls[0][axis])) /
            (h[i] * h[i]),
        ).toBeCloseTo(
          (6 * (a.end[axis] - 2 * b.controls[0][axis] + b.controls[1][axis])) /
            (h[j] * h[j]),
          9,
        );
      }
    }
  }
  expect(() =>
    fitSketchSpline(
      [
        [0, 0],
        [1, 0],
      ],
      { closed: true },
    ),
  ).toThrow("3–1000");
});
