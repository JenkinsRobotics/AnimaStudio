import { expect, it } from "vitest";
import { trimSketchCurve } from "./trim";
import { sketchEntityPoint } from "../solver/entities";
import type { SketchDrawing } from "../drawing";
it("retains the original end but never assigns the removed start ID to the new cut", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        id: "source",
        type: "path",
        start: [0, 0],
        startVertexId: "start",
        segments: [
          { id: "edge", type: "line", end: [10, 0], endVertexId: "end" },
        ],
      },
      {
        type: "path",
        start: [4, -5],
        segments: [{ type: "line", end: [4, 5] }],
      },
    ],
    constraints: [
      {
        id: "fixed-end",
        kind: "fix",
        point: [10, 0],
        a: { contour: 0, kind: "point", index: 0, vertexId: "end" },
      },
    ],
  };
  // The stored index is stale: the stable identity is authoritative.
  const next = trimSketchCurve(d, [2, 0], 0.1),
    path = next.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.start).toEqual([4, 0]);
  expect(path.startVertexId).not.toBe("start");
  expect(path.segments[0].endVertexId).toBe("end");
  expect(path.id).toBe("source");
  expect(next.constraints![0].a).toMatchObject({ vertexId: "end", index: 1 });
  const context: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [path],
  };
  expect(
    sketchEntityPoint(context, {
      contour: -1,
      projectedContourId: "source",
      kind: "point",
      index: 1,
      vertexId: "end",
    }),
  ).toEqual([10, 0]);
  expect(() =>
    sketchEntityPoint(context, {
      contour: -1,
      projectedContourId: "source",
      kind: "point",
      index: 0,
      vertexId: "start",
    }),
  ).toThrow(/Broken vertex/);
  expect(d.contours[0]).not.toEqual(path);
});
it("keeps surviving closed-path vertex identities when trim rotates the start", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        id: "square",
        type: "path",
        start: [0, 0],
        startVertexId: "a",
        segments: [
          { id: "ab", type: "line", end: [10, 0], endVertexId: "b" },
          { id: "bc", type: "line", end: [10, 10], endVertexId: "c" },
          { id: "cd", type: "line", end: [0, 10], endVertexId: "d" },
          { id: "da", type: "line", end: [0, 0], endVertexId: "a" },
        ],
      },
    ],
  };
  const next = trimSketchCurve(d, [5, 0], 0.1),
    path = next.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.startVertexId).toBe("b");
  expect(path.segments.map((s) => s.id)).toEqual(["bc", "cd", "da"]);
  expect(
    sketchEntityPoint(next, {
      contour: 0,
      kind: "point",
      vertexId: "a",
      index: 0,
    }),
  ).toEqual([0, 0]);
});
