import { expect, it } from "vitest";
import { offsetSketch } from "./offset";
import {
  editDrawingDimension,
  removeDrawingConstraint,
} from "./edit-dimension";
import { solveDrawingConstraints } from "../solver/solve";
import type { SketchDrawing } from "../drawing";
function circles(): SketchDrawing {
  return {
    type: "drawing",
    contours: [
      { type: "circle", center: [0, 0], radius: 5 },
      { type: "circle", center: [20, 0], radius: 3 },
    ],
    constraints: [
      { id: "r0", kind: "radius", a: { kind: "circle", contour: 0 }, value: 5 },
      { id: "r1", kind: "radius", a: { kind: "circle", contour: 1 }, value: 3 },
    ],
  };
}
it("retains shared signed circle offset distances through source and follower edits", () => {
  const original = offsetSketch(circles(), [0, 1], 2);
  expect(original.constraints?.find((c) => c.id === "offset-2")).toMatchObject({
    valueFrom: "offset-1",
  });
  const resized = editDrawingDimension(original, "r0", 8);
  expect(resized.contours[2]).toMatchObject({ radius: expect.closeTo(10, 5) });
  const edited = editDrawingDimension(resized, "offset-2", -1);
  expect(edited.contours[2]).toMatchObject({ radius: expect.closeTo(7, 5) });
  expect(edited.contours[3]).toMatchObject({ radius: expect.closeTo(2, 5) });
  expect(original.contours[2]).toMatchObject({ radius: 7 });
});
it("preserves line endpoint correspondence when the source rotates and changes length", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
    ],
  };
  const offset = offsetSketch(source, [0], 2);
  offset.constraints!.push(
    {
      id: "start",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [3, 4],
    },
    {
      id: "end",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 1 },
      point: [3, 24],
    },
  );
  const solved = solveDrawingConstraints(offset),
    p = solved.contours[1];
  if (p.type !== "path") throw Error();
  expect(p.start[0]).toBeCloseTo(1, 5);
  expect(p.start[1]).toBeCloseTo(4, 5);
  expect(p.segments[0].end[0]).toBeCloseTo(1, 5);
  expect(p.segments[0].end[1]).toBeCloseTo(24, 5);
});
it("rejects radius collapse and retains a follower value when its driver is removed", () => {
  const source = offsetSketch(circles(), [0, 1], 2),
    before = structuredClone(source);
  expect(() => editDrawingDimension(source, "offset-1", -6)).toThrow();
  expect(source).toEqual(before);
  const removed = removeDrawingConstraint(source, "offset-1");
  expect(removed.constraints?.find((c) => c.id === "offset-2")).toMatchObject({
    value: 2,
  });
  expect(
    removed.constraints?.find((c) => c.id === "offset-2")?.valueFrom,
  ).toBeUndefined();
});
