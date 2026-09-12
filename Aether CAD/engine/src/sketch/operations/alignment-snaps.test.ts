import { expect, it } from "vitest";
import { inferLineAlignment } from "./alignment-snaps";
import { dragSketchEntity } from "./drag-entity";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const empty = (): SketchDrawing => ({ type: "drawing", contours: [] });
it("retains horizontal and vertical directions while dragging an unconstrained corner", () => {
  const after: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 5],
        segments: [
          { type: "line", end: [10, 5] },
          { type: "line", end: [10, 10] },
        ],
      },
    ],
  };
  const next = inferLineAlignment(empty(), after);
  validateSketchDrawing(next);
  expect(next.constraints!.map((c) => c.kind)).toEqual([
    "horizontal",
    "vertical",
  ]);
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(next)),
    { contour: 0, kind: "point", index: 1 },
    [2, 3],
  );
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.start[1]).toBeCloseTo(path.segments[0].end[1]);
  expect(path.segments[1].end[0]).toBeCloseTo(path.segments[0].end[0]);
  expect(path.segments[0].end[0]).toBeCloseTo(12);
  expect(path.segments[0].end[1]).toBeCloseTo(8);
  expect(after.constraints).toBeUndefined();
});
it("only infers newly appended axis-aligned lines and avoids duplicate relations", () => {
  const before: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
    ],
  };
  const after = structuredClone(before);
  const path = after.contours[0];
  if (path.type !== "path") throw Error();
  path.segments.push(
    { type: "line", end: [5, 5] },
    { type: "line", end: [8, 7] },
  );
  const next = inferLineAlignment(before, after);
  expect(next.constraints).toHaveLength(1);
  expect(next.constraints![0]).toMatchObject({
    kind: "vertical",
    a: { index: 1 },
  });
  expect(inferLineAlignment(before, next)).toEqual(next);
  expect(inferLineAlignment(next, next)).toEqual(next);
});
