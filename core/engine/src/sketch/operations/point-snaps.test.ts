import { expect, it } from "vitest";
import { inferPointSnaps } from "./point-snaps";
import { dragSketchEntity } from "./drag-entity";
import { sketchEntityPoint } from "../solver/entities";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { type: "path", start: [5, 5], segments: [{ type: "line", end: [10, 5] }] },
  ],
});
it("retains endpoint coincidence through serialization and source movement", () => {
  const before = source(),
    after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: [10, 5],
    segments: [{ type: "line", end: [15, 10] }],
  });
  const next = inferPointSnaps(before, after);
  validateSketchDrawing(next);
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(next)),
    { kind: "point", contour: 0, index: 1 },
    [2, 3],
  );
  const p = sketchEntityPoint(moved, { kind: "point", contour: 1, index: 0 })!;
  expect(p[0]).toBeCloseTo(12);
  expect(p[1]).toBeCloseTo(8);
  expect(after.constraints).toBeUndefined();
  expect(inferPointSnaps(next, next)).toEqual(next);
});
it("anchors new origin points without constraining off-target or existing points", () => {
  const before = source(),
    after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: [0, 0],
    segments: [{ type: "line", end: [5.01, 5] }],
  });
  const next = inferPointSnaps(before, after);
  expect(next.constraints).toEqual([
    {
      id: "point-inferred-1",
      kind: "fix",
      a: { kind: "point", contour: 1, index: 0 },
      point: [0, 0],
    },
  ]);
  expect(() =>
    dragSketchEntity(next, { kind: "point", contour: 1, index: 0 }, [1, 0]),
  ).toThrow();
});
it("does not duplicate closed endpoints or existing inferred relationships", () => {
  const before = source(),
    after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: [10, 5],
    segments: [
      { type: "line", end: [20, 20] },
      { type: "line", end: [10, 5] },
    ],
  });
  const next = inferPointSnaps(before, after);
  expect(next.constraints).toHaveLength(1);
  expect(inferPointSnaps(before, next)).toEqual(next);
});
it("limits gesture inference to explicitly placed points, excluding generated centers", () => {
  const before: SketchDrawing = { type: "drawing", contours: [] };
  const after: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [0, 0], radius: 5 }],
  };
  expect(
    inferPointSnaps(before, after, [
      [5, 0],
      [-5, 0],
      [0, 5],
    ]).constraints,
  ).toEqual([]);
  expect(
    inferPointSnaps(before, after, [
      [0, 0],
      [5, 0],
    ]).constraints,
  ).toHaveLength(1);
});
