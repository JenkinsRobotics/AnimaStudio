import { expect, it } from "vitest";
import { lineLineMeasurement } from "./line-line-measurement";
import { editDrawingDimension } from "../operations/edit-dimension";
import { setDimensionReference } from "../operations/dimension-reference";
import { dimensionValue } from "./dimension-links";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { type: "path", start: [0, 0], segments: [{ type: "line", end: [10, 0] }] },
    {
      type: "path",
      start: [20, 3],
      segments: [{ type: "line", end: [30, 3] }],
    },
  ],
  constraints: [
    {
      id: "fixed-start",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [0, 0],
    },
    {
      id: "fixed-end",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 1 },
      point: [10, 0],
    },
    {
      id: "spacing",
      kind: "distance",
      a: { kind: "line", contour: 0, index: 0 },
      b: { kind: "line", contour: 1, index: 0 },
      value: 3,
    },
  ],
});
it("measures disjoint and reversed parallel lines, rejecting degenerate lines", () => {
  const m = lineLineMeasurement(
    [
      [0, 0],
      [10, 0],
    ],
    [
      [30, 3],
      [20, 3],
    ],
  );
  expect(m.distance).toBe(3);
  expect(m.point).toEqual([5, 0]);
  expect(m.foot).toEqual([5, 3]);
  expect(Math.abs(m.parallelError)).toBe(0);
  expect(() =>
    lineLineMeasurement(
      [
        [0, 0],
        [0, 0],
      ],
      [
        [0, 3],
        [10, 3],
      ],
    ),
  ).toThrow(/nonzero/);
});
it("edits spacing while maintaining parallelism and supports reference conversion", () => {
  const source = drawing();
  validateSketchDrawing(source);
  const result = editDrawingDimension(
    JSON.parse(JSON.stringify(source)),
    "spacing",
    8,
  );
  const [a, b] = result.contours;
  if (a.type !== "path" || b.type !== "path") throw Error();
  const m = lineLineMeasurement(
    [a.start, a.segments[0].end],
    [b.start, b.segments[0].end],
  );
  expect(m.distance).toBeCloseTo(8, 6);
  expect(m.parallelError).toBeCloseTo(0, 7);
  expect(a.start[0]).toBeCloseTo(0, 7);
  expect(a.start[1]).toBeCloseTo(0, 7);
  expect(a.segments[0].end[0]).toBeCloseTo(10, 7);
  expect(a.segments[0].end[1]).toBeCloseTo(0, 7);
  const ref = setDimensionReference(result, "spacing", true);
  expect(dimensionValue(ref, ref.constraints![2])).toBeCloseTo(8, 6);
  const reversed = drawing();
  [reversed.constraints![2].a, reversed.constraints![2].b] = [
    reversed.constraints![2].b!,
    reversed.constraints![2].a,
  ];
  validateSketchDrawing(reversed);
  expect(source).toEqual(drawing());
});
it("rejects nonparallel reference distances instead of reporting arbitrary endpoint spacing", () => {
  const d = drawing();
  const c = d.constraints![2];
  c.reference = true;
  delete c.value;
  const b = d.contours[1];
  if (b.type !== "path") throw Error();
  b.segments[0].end = [30, 7];
  expect(() => validateSketchDrawing(d)).toThrow(/parallel/);
});
