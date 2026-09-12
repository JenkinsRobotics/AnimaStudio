import { expect, it } from "vitest";
import { offsetSketchEntities } from "./offset-entities";
import { solveDrawingConstraints } from "../solver/solve";
import { editDrawingDimension } from "./edit-dimension";
import type { SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        { type: "line", end: [10, 0] },
        { type: "line", end: [10, 10] },
        { type: "arc", middle: [15, 15], end: [20, 10] },
      ],
    },
  ],
});
it("offsets selected edges and preserves their source indices and one shared distance", () => {
  const d = source(),
    before = structuredClone(d),
    next = offsetSketchEntities(
      d,
      [
        { kind: "line", contour: 0, index: 1 },
        { kind: "arc", contour: 0, index: 2 },
        { kind: "line", contour: 0, index: 1 },
      ],
      1,
    );
  expect(next.contours).toHaveLength(3);
  expect(next.contours[1]).toMatchObject({
    start: [9, 0],
    segments: [{ type: "line", end: [9, 10] }],
  });
  expect(next.constraints).toMatchObject([
    { a: { kind: "line", index: 1 }, b: { contour: 1, index: 0 }, value: 1 },
    {
      a: { kind: "arc", index: 2 },
      b: { contour: 2, index: 0 },
      valueFrom: "offset-1",
    },
  ]);
  expect(d).toEqual(before);
  expect(editDrawingDimension(next, "offset-2", 2).constraints![0].value).toBe(
    2,
  );
});
it("moves an individual offset with its selected source edge", () => {
  const d = offsetSketchEntities(
    source(),
    [{ kind: "line", contour: 0, index: 1 }],
    1,
  );
  d.constraints!.push(
    {
      id: "start",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 1 },
      point: [20, 0],
    },
    {
      id: "end",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 2 },
      point: [20, 10],
    },
  );
  const p = solveDrawingConstraints(d).contours[1];
  if (p.type !== "path") throw Error();
  expect(p.start[0]).toBeCloseTo(19, 5);
  expect(p.segments[0].end[0]).toBeCloseTo(19, 5);
});
it("rejects bad selections atomically", () => {
  const d = source(),
    before = structuredClone(d);
  expect(() => offsetSketchEntities(d, [], 1)).toThrow("Select");
  expect(() =>
    offsetSketchEntities(
      d,
      [
        { kind: "line", contour: 0, index: 0 },
        { kind: "line", contour: 0, index: 2 },
      ],
      1,
    ),
  ).toThrow("Select");
  expect(d).toEqual(before);
});
