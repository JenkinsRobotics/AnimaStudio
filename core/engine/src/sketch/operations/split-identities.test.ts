import { expect, it } from "vitest";
import { splitSketchSegment } from "./split";
import { sketchEntityPoint } from "../solver/entities";
import { solveDrawingConstraints } from "../solver/solve";
import type { SketchDrawing } from "../drawing";

it("preserves source endpoints through splitting for external coincidence", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        id: "source",
        start: [0, 0],
        startVertexId: "origin",
        segments: [
          { type: "line", id: "edge", end: [10, 0], endVertexId: "tip" },
        ],
      },
    ],
  };
  const split = splitSketchSegment(source, [4, 0], 0.1),
    path = split.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.startVertexId).toBe("origin");
  expect(path.segments[1].endVertexId).toBe("tip");
  expect(new Set(path.segments.map((s) => s.id)).size).toBe(2);
  expect(path.segments.some((s) => s.id === "edge")).toBe(false);
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [9, 1],
        segments: [{ type: "line", end: [9, 5] }],
      },
    ],
    projectionContext: split.contours,
    constraints: [
      {
        id: "attach",
        kind: "coincident",
        a: { contour: 0, kind: "point", index: 0 },
        b: {
          contour: -1,
          projectedContourId: "source",
          kind: "point",
          index: 1,
          vertexId: "tip",
        },
      },
    ],
  };
  const p = sketchEntityPoint(solveDrawingConstraints(d), {
    contour: 0,
    kind: "point",
    index: 0,
  })!;
  expect(p[0]).toBeCloseTo(10);
  expect(p[1]).toBeCloseTo(0);
  expect(source.contours[0]).not.toEqual(path);
});

it("remaps identified cubic contacts to the correct child edge", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            id: "curve",
            controls: [
              [3, 0],
              [7, 0],
            ],
            end: [10, 0],
            endVertexId: "end",
          },
        ],
      },
      {
        type: "path",
        start: [7.594, 0],
        segments: [{ type: "line", end: [7.594, 4] }],
      },
    ],
    constraints: [
      {
        id: "contact",
        kind: "coincident",
        a: { kind: "point", contour: 1, index: 0 },
        b: {
          kind: "curve",
          contour: 0,
          index: 0,
          segmentId: "curve",
          parameter: 0.75,
        },
      },
    ],
  };
  // Seed the exact cubic contact before the operation verifies retained equations.
  const point =
    0.25 ** 3 * 0 +
    3 * 0.25 ** 2 * 0.75 * 3 +
    3 * 0.25 * 0.75 ** 2 * 7 +
    0.75 ** 3 * 10;
  if (d.contours[1].type === "path") d.contours[1].start = [point, 0];
  const next = splitSketchSegment(d, [5, 0], 0.01),
    path = next.contours[0];
  if (path.type !== "path") throw Error();
  expect(next.constraints![0].b).toMatchObject({
    index: 1,
    segmentId: path.segments[1].id,
    parameter: expect.closeTo(0.5),
  });
});
