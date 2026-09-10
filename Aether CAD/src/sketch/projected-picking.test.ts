import { expect, it } from "vitest";
import { pickSelectableSketchEntity } from "./projected-picking";
import type { SketchDrawing } from "@aether/core/sketch";
it("picks identified projected vertices and edges without treating them as authored", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      {
        id: "edge",
        type: "path",
        start: [0, 0],
        startVertexId: "start-vertex",
        segments: [{ id: "stable-edge", type: "line", end: [10, 0] }],
      },
    ],
  };
  expect(pickSelectableSketchEntity(d, [0, 0])?.ref).toMatchObject({
    kind: "point",
    vertexId: "start-vertex",
    contour: -1,
    projectedContourId: "edge",
  });
  expect(pickSelectableSketchEntity(d, [5, 0])?.ref).toMatchObject({
    kind: "line",
    segmentId: "stable-edge",
    contour: -1,
    projectedContourId: "edge",
  });
  d.contours.push({
    type: "path",
    start: [0, 0],
    segments: [{ type: "line", end: [10, 0] }],
  });
  expect(pickSelectableSketchEntity(d, [5, 0])?.ref.contour).toBe(0);
});
it("preserves a picked projected cubic contact parameter", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      {
        id: "curve",
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [0, 10],
              [10, 10],
            ],
            end: [10, 0],
          },
        ],
      },
    ],
  };
  expect(pickSelectableSketchEntity(d, [5, 7.5])?.ref).toMatchObject({
    kind: "curve",
    contour: -1,
    projectedContourId: "curve",
    parameter: expect.closeTo(0.5),
  });
});
