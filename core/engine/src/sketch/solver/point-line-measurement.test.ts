import { expect, it } from "vitest";
import { pointLineMeasurement } from "./point-line-measurement";
import { editDrawingDimension } from "../operations/edit-dimension";
import { setDimensionReference } from "../operations/dimension-reference";
import { dimensionValue } from "./dimension-links";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
it("measures perpendicular to an extended line in either direction", () => {
  expect(
    pointLineMeasurement(
      [20, 3],
      [
        [0, 0],
        [10, 0],
      ],
    ),
  ).toEqual({ distance: 3, foot: [20, 0] });
  expect(
    pointLineMeasurement(
      [20, 3],
      [
        [10, 0],
        [0, 0],
      ],
    ),
  ).toEqual({ distance: 3, foot: [20, 0] });
  expect(() =>
    pointLineMeasurement(
      [2, 3],
      [
        [0, 0],
        [0, 0],
      ],
    ),
  ).toThrow();
});
it("drives point distance while a line stays fixed and converts to reference", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
      { type: "path", construction: true, start: [20, 3], segments: [] },
    ],
    constraints: [
      {
        id: "a",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 0 },
        point: [0, 0],
      },
      {
        id: "b",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 1 },
        point: [10, 0],
      },
      {
        id: "distance",
        kind: "distance",
        a: { kind: "point", contour: 1, index: 0 },
        b: { kind: "line", contour: 0, index: 0 },
        value: 3,
      },
    ],
  };
  validateSketchDrawing(d);
  const moved = editDrawingDimension(
    JSON.parse(JSON.stringify(d)),
    "distance",
    7,
  );
  const line = moved.contours[0];
  if (line.type !== "path") throw Error();
  expect(line.start[0]).toBeCloseTo(0, 7);
  expect(line.start[1]).toBeCloseTo(0, 7);
  expect(line.segments[0].end[0]).toBeCloseTo(10, 7);
  expect(line.segments[0].end[1]).toBeCloseTo(0, 7);
  const point = moved.contours[1];
  if (point.type !== "path") throw Error();
  expect(Math.abs(point.start[1])).toBeCloseTo(7);
  const ref = setDimensionReference(moved, "distance", true);
  expect(dimensionValue(ref, ref.constraints!.at(-1)!)).toBeCloseTo(7);
  const reverse = structuredClone(d);
  [reverse.constraints![2].a, reverse.constraints![2].b] = [
    reverse.constraints![2].b!,
    reverse.constraints![2].a,
  ];
  validateSketchDrawing(reverse);
});
