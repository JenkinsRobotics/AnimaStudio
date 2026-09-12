import { expect, it } from "vitest";
import { inferMidpointSnaps, midpointSnapPoints } from "./midpoint-snaps";
import { dragSketchEntity } from "./drag-entity";
import { sketchEntityPoint } from "../solver/entities";
import { type SketchDrawing, validateSketchDrawing } from "../drawing";
it("keeps a point at the line midpoint after endpoint edits and serialization", () => {
  const before: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 5],
        segments: [{ type: "line", end: [15, 5] }],
      },
    ],
  };
  const after = structuredClone(before);
  after.contours.push({ type: "path", start: [10, 5], segments: [] });
  const next = inferMidpointSnaps(before, after, [[10, 5]]);
  validateSketchDrawing(next);
  expect(next.constraints![0]).toMatchObject({
    kind: "midpoint",
    a: { kind: "line", contour: 0, index: 0 },
    b: { kind: "point", contour: 1, index: 0 },
  });
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(next)),
    { kind: "point", contour: 0, index: 1 },
    [4, 2],
  );
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  const p = sketchEntityPoint(moved, { kind: "point", contour: 1, index: 0 })!;
  expect(p[0]).toBeCloseTo((path.start[0] + path.segments[0].end[0]) / 2);
  expect(p[1]).toBeCloseTo((path.start[1] + path.segments[0].end[1]) / 2);
  expect(after.constraints).toBeUndefined();
  expect(inferMidpointSnaps(before, next, [[10, 5]])).toEqual(next);
});
it("uses arc-length midpoints and excludes unplaced generated points", () => {
  const before: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [3, 4], end: [-5, 0] }],
      },
    ],
  };
  const midpoint = midpointSnapPoints(before)[0].point;
  expect(midpoint[0]).toBeCloseTo(0);
  expect(midpoint[1]).toBeCloseTo(5);
  const after = structuredClone(before);
  after.contours.push({ type: "path", start: [...midpoint], segments: [] });
  expect(inferMidpointSnaps(before, after, []).constraints).toEqual([]);
  const next = inferMidpointSnaps(before, after, [midpoint]);
  validateSketchDrawing(next);
  expect(next.constraints![0].a.kind).toBe("arc");
});
