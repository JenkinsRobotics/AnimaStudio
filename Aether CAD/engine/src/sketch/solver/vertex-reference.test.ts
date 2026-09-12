import { expect, it } from "vitest";
import { type SketchDrawing, validateSketchDrawing } from "../drawing";
import { projectedSnapPoints } from "../operations/projected-snaps";
import { solveDrawingConstraints } from "./solve";
import { resolveVertexReference } from "./vertex-reference";
import { projectSketchDrawing } from "../projection/drawing";

it("keeps endpoint snaps attached after inserting earlier source geometry", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [10, 0],
        segments: [{ type: "line", end: [10, 4] }],
      },
    ],
    projectionContext: [
      {
        type: "path",
        id: "source",
        start: [0, 0],
        startVertexId: "start",
        segments: [{ type: "line", end: [10, 0], endVertexId: "tip" }],
      },
    ],
  };
  const snap = projectedSnapPoints(d).find((p) => p.ref.vertexId === "tip")!;
  expect(snap).toBeDefined();
  d.constraints = [
    {
      id: "endpoint",
      kind: "coincident",
      a: { kind: "point", contour: 0, index: 0 },
      b: snap.ref,
    },
  ];
  const source = d.projectionContext![0];
  if (source.type !== "path") throw Error();
  source.segments.unshift({
    type: "line",
    end: [5, 0],
    endVertexId: "inserted",
  });
  source.segments[1].end = [12, 3];
  const result = solveDrawingConstraints(d).contours[0];
  if (result.type !== "path") throw Error();
  expect(result.start[0]).toBeCloseTo(12);
  expect(result.start[1]).toBeCloseTo(3);
  source.segments[1].endVertexId = "replacement";
  expect(() => solveDrawingConstraints(d)).toThrow(/Broken vertex reference/);
});

it("preserves projected vertex IDs and resolves a closed seam to its start", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        startVertexId: "a",
        segments: [
          { type: "line", end: [10, 0], endVertexId: "b" },
          { type: "line", end: [0, 0], endVertexId: "a" },
        ],
      },
    ],
  };
  validateSketchDrawing(d);
  const frame = {
    originMillimeters: [0, 0, 0] as [number, number, number],
    xDirection: [1, 0, 0] as [number, number, number],
    normal: [0, 0, 1] as [number, number, number],
  };
  const path = projectSketchDrawing(d, frame, frame).contours[0];
  if (path.type !== "path") throw Error();
  expect(path.startVertexId).toBe("a");
  expect(path.segments[0].endVertexId).toBe("b");
  expect(
    resolveVertexReference(path, {
      kind: "point",
      contour: 0,
      index: 2,
      vertexId: "a",
    }).index,
  ).toBe(0);
  path.segments[0].endVertexId = "a";
  expect(() =>
    validateSketchDrawing({ type: "drawing", contours: [path] }),
  ).toThrow(/vertex identities/);
});
