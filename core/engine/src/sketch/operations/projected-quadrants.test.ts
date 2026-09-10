import { expect, it } from "vitest";
import { projectedSnapPoints, inferProjectedSnaps } from "./projected-snaps";
import { solveDrawingConstraints } from "../solver/solve";
import { sketchVariantContour } from "../primitives";
import type { SketchDrawing } from "../drawing";
it("persists a projected circle quadrant and follows radius and center changes", () => {
  const before: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      { id: "circle", type: "circle", center: [10, 10], radius: 5 },
    ],
  };
  expect(
    projectedSnapPoints(before).filter((p) => p.kind === "quadrant"),
  ).toHaveLength(4);
  const after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: [10, 15],
    segments: [{ type: "line", end: [20, 20] }],
  });
  const linked = inferProjectedSnaps(before, after, [[10, 15]]);
  expect(linked.constraints![0]).toMatchObject({
    kind: "quadrant",
    quadrant: 1,
    b: { projectedContourId: "circle" },
  });
  const source = linked.projectionContext![0];
  if (source.type !== "circle") throw Error();
  source.radius = 8;
  source.center = [12, 13];
  const result = solveDrawingConstraints(linked).contours[0];
  if (result.type !== "path") throw Error();
  expect(result.start[0]).toBeCloseTo(12);
  expect(result.start[1]).toBeCloseTo(21);
});
it("offers ellipse quadrants on visible spans with stable edge identity", () => {
  const path = sketchVariantContour("ellipse", [
    [0, 0],
    [8, 0],
    [0, 4],
  ]);
  if (path.type !== "path") throw Error();
  path.id = "ellipse";
  path.segments.forEach((s, i) => (s.id = `edge-${i}`));
  const d: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [path],
  };
  const snaps = projectedSnapPoints(d).filter((p) => p.kind === "quadrant");
  expect(new Set(snaps.map((p) => p.quadrant)).size).toBe(4);
  expect(snaps.every((p) => p.ref.segmentId?.startsWith("edge-"))).toBe(true);
});
