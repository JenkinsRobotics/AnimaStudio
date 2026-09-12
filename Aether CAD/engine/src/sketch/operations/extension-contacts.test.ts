import { expect, it } from "vitest";
import { extendSketchCurve } from "./extend-curves";
import { segmentPoint } from "../curves/parameterization";
import { constraintResiduals } from "../solver/residuals";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
  type SketchSegment,
} from "../drawing";

it("preserves fixed and sliding contacts when extending either end of lines and both conic sweeps", () => {
  const fixtures: {
    start: SketchPoint;
    segment: SketchSegment;
    before: SketchPoint;
    after: SketchPoint;
  }[] = [
    {
      start: [0, 0],
      segment: { type: "line", end: [4, 0] },
      before: [-4, 0],
      after: [8, 0],
    },
  ];
  for (const sign of [-1, 1]) {
    fixtures.push({
      start: [1, 0],
      segment: {
        type: "arc",
        middle: [Math.SQRT1_2, sign * Math.SQRT1_2],
        end: [0, sign],
      },
      before: [0, -sign],
      after: [-1, 0],
    });
    fixtures.push({
      start: [2, 0],
      segment: {
        type: "ellipse",
        radiusX: 2,
        radiusY: 1,
        rotationDegrees: 0,
        largeArc: false,
        sweep: sign > 0,
        end: [0, sign],
      },
      before: [0, -sign],
      after: [-2, 0],
    });
  }
  for (const f of fixtures)
    for (const atStart of [false, true]) {
      const d: SketchDrawing = {
        type: "drawing",
        contours: [{ type: "path", start: f.start, segments: [f.segment] }],
        constraints: [],
      };
      for (const t of [0, 0.25, 0.75, 1]) {
        const contour = d.contours.length;
        d.contours.push({
          type: "path",
          start: segmentPoint(f.start, f.segment, t),
          segments: [],
        });
        d.constraints!.push({
          id: `contact-${t}`,
          kind: "coincident",
          a: { kind: "point", contour, index: 0 },
          b: {
            kind: "curve",
            contour: 0,
            index: 0,
            parameter: t,
            sliding: t !== 0.25,
          },
        });
      }
      const before = structuredClone(d);
      const next = extendSketchCurve(
        d,
        segmentPoint(f.start, f.segment, atStart ? 0.1 : 0.9),
        0.001,
        atStart ? f.before : f.after,
      );
      for (const t of [0, 0.25, 0.75, 1]) {
        const c = next.constraints!.find((c) => c.id === `contact-${t}`)!;
        expect(c.b!.parameter).toBeCloseTo(atStart ? (t + 1) / 2 : t / 2, 5);
        expect(c.b!.sliding).toBe(t !== 0.25);
        expect(
          constraintResiduals(next, c).every((r) => Math.abs(r) < 1e-6),
        ).toBe(true);
      }
      validateSketchDrawing(JSON.parse(JSON.stringify(next)));
      expect(d).toEqual(before);
    }
});
it("still rejects endpoint constraints that prevent extension without mutating input", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [4, 0] }],
      },
    ],
    constraints: [
      {
        id: "fixed-end",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 1 },
        point: [4, 0],
      },
    ],
  };
  const before = structuredClone(d);
  expect(() => extendSketchCurve(d, [3.9, 0], 0.01, [8, 0])).toThrow(
    /fixed-end/,
  );
  expect(d).toEqual(before);
});
