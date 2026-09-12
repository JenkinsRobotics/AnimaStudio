import { expect, it } from "vitest";
import { fitSketchSpline } from "../curves/fit-spline";
import { segmentPoint } from "../curves/parameterization";
import { constrainFitSpline } from "./spline-relations";
import { insertSketchSplinePoint } from "./insert-spline-point";
import { dragSketchEntity } from "./drag-entity";
import { constraintResiduals } from "../solver/residuals";
import type { SketchDrawing } from "../drawing";

it("inserts into natural and periodic fit splines without changing any span", () => {
  for (const closed of [false, true]) {
    const drawing = constrainFitSpline(
      {
        type: "drawing",
        contours: [
          fitSketchSpline(
            [
              [0, 0],
              [10, 8],
              [20, 0],
              [30, 6],
            ],
            { closed },
          ),
        ],
      },
      0,
    );
    const source = drawing.contours[0];
    if (source.type !== "path") throw Error("path");
    const point = segmentPoint(source.segments[0].end, source.segments[1], 0.4);
    const next = insertSketchSplinePoint(drawing, point, 0.01),
      result = next.contours[0];
    if (result.type !== "path") throw Error("path");
    expect(result.segments).toHaveLength(source.segments.length + 1);
    let start = source.start;
    source.segments.forEach((s, i) => {
      for (let n = 0; n <= 10; n++) {
        const t = n / 10,
          right = i === 1 && t > 0.4;
        const index = i < 1 ? i : i === 1 ? 1 + (right ? 1 : 0) : i + 1;
        const local = i === 1 ? (right ? (t - 0.4) / 0.6 : t / 0.4) : t;
        const expected = segmentPoint(start, s, t);
        const actual = segmentPoint(
          index ? result.segments[index - 1].end : result.start,
          result.segments[index],
          local,
        );
        expect(actual[0]).toBeCloseTo(expected[0], 5);
        expect(actual[1]).toBeCloseTo(expected[1], 5);
      }
      start = s.end;
    });
    const reopened = JSON.parse(JSON.stringify(next)) as SketchDrawing;
    expect(reopened.constraints![0].splineSpanIntervals).toHaveLength(
      result.segments.length,
    );
    const moved = dragSketchEntity(
      reopened,
      { kind: "point", contour: 0, index: 2 },
      [0, 0.5],
    );
    for (const c of moved.constraints!)
      expect(
        constraintResiduals(moved, c).every((v) => Math.abs(v) < 1e-6),
      ).toBe(true);
    expect(drawing.constraints![0].splineSpanIntervals).toBeUndefined();
  }
});

it("rejects malformed persisted span intervals", () => {
  expect(() =>
    fitSketchSpline(
      [
        [0, 0],
        [10, 0],
      ],
      { spanIntervals: [-1] },
    ),
  ).toThrow("intervals");
  expect(() =>
    fitSketchSpline(
      [
        [0, 0],
        [10, 0],
      ],
      { spanIntervals: [1, 2] },
    ),
  ).toThrow("intervals");
});
