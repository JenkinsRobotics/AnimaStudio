import { expect, it } from "vitest";
import { centerSnapPoints, inferCenterSnaps } from "./center-snaps";
import { dragSketchEntity } from "./drag-entity";
import { resolve } from "../solver/entities";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [15, 10],
      segments: [{ type: "arc", middle: [10, 15], end: [5, 10] }],
    },
  ],
});
it("retains a newly drawn endpoint at an arc center through edits", () => {
  const before = source(),
    after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: [10, 10],
    segments: [{ type: "line", end: [20, 20] }],
  });
  const next = inferCenterSnaps(before, after);
  validateSketchDrawing(next);
  expect(next.constraints).toHaveLength(1);
  expect(after.constraints).toBeUndefined();
  const reopened = JSON.parse(JSON.stringify(next));
  const moved = dragSketchEntity(
    reopened,
    { kind: "point", contour: 1, index: 0 },
    [2, 3],
  );
  const center = resolve(moved, { kind: "arc", contour: 0, index: 0 }).circle!
    .center;
  expect(center[0]).toBeCloseTo(12);
  expect(center[1]).toBeCloseTo(13);
  expect(inferCenterSnaps(next, next)).toEqual(next);
});
it("does not infer for existing or off-center vertices, or duplicate closed vertices", () => {
  const before = source();
  before.contours.push({ type: "path", start: [10, 10], segments: [] });
  const after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: [10, 10],
    segments: [
      { type: "line", end: [20, 20] },
      { type: "line", end: [10, 10] },
    ],
  });
  after.contours.push({ type: "path", start: [10.01, 10], segments: [] });
  const next = inferCenterSnaps(before, after);
  expect(next.constraints).toHaveLength(1);
  expect(next.constraints![0].a).toEqual({
    kind: "point",
    contour: 2,
    index: 0,
  });
});
it("attaches circle centers too and ignores degenerate arcs", () => {
  const before: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [10, 10], radius: 2 }],
  };
  const after = structuredClone(before);
  after.contours.push({ type: "circle", center: [10, 10], radius: 5 });
  expect(inferCenterSnaps(before, after).constraints![0].b).toEqual({
    kind: "circle",
    contour: 0,
  });
  expect(
    centerSnapPoints({
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [0, 0],
          segments: [{ type: "arc", middle: [1, 0], end: [2, 0] }],
        },
      ],
    }),
  ).toEqual([]);
});
