import { expect, it } from "vitest";
import { type SketchDrawing, validateSketchDrawing } from "../drawing";
import { projectedSnapPoints } from "../operations/projected-snaps";
import { solveDrawingConstraints } from "./solve";
import { projectSketchDrawing } from "../projection/drawing";

it("keeps a projected midpoint constraint on its edge after inserting an earlier edge", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "line", end: [5, 4] }],
      },
    ],
    projectionContext: [
      {
        type: "path",
        id: "source",
        start: [0, 0],
        segments: [{ type: "line", id: "edge", end: [10, 0] }],
      },
    ],
  };
  const snap = projectedSnapPoints(d).find(
    (p) => p.label === "Projected midpoint",
  )!;
  expect(snap.ref.segmentId).toBe("edge");
  d.constraints = [
    {
      id: "midpoint",
      kind: "midpoint",
      a: snap.ref,
      b: { kind: "point", contour: 0, index: 0 },
    },
  ];
  const source = d.projectionContext![0];
  if (source.type !== "path") throw Error();
  source.start = [-5, 0];
  source.segments.unshift({ id: "new", type: "line", end: [0, 0] });
  const result = solveDrawingConstraints(d).contours[0];
  if (result.type !== "path") throw Error();
  expect(result.start[0]).toBeCloseTo(5);
  source.segments[1].id = "replacement";
  expect(() => solveDrawingConstraints(d)).toThrow(/Broken segment reference/);
});

it("preserves segment IDs through one-to-one projection and rejects ambiguous IDs", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        id: "path",
        start: [0, 0],
        segments: [{ type: "line", id: "edge", end: [10, 0] }],
      },
    ],
  };
  const frame = {
    originMillimeters: [0, 0, 0] as [number, number, number],
    xDirection: [1, 0, 0] as [number, number, number],
    normal: [0, 0, 1] as [number, number, number],
  };
  const projected = projectSketchDrawing(d, frame, frame).contours[0];
  if (projected.type !== "path") throw Error();
  expect(projected.segments[0].id).toBe("edge");
  const path = d.contours[0];
  if (path.type !== "path") throw Error();
  path.segments.push({ type: "line", id: "edge", end: [10, 10] });
  expect(() => validateSketchDrawing(d)).toThrow(/segment identities/);
});
