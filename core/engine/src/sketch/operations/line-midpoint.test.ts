import { expect, it } from "vitest";
import { addSketchLineMidpoint } from "./line-midpoint";
import { dragSketchEntity } from "./drag-entity";
import { sketchVariantContour } from "../primitives";
import { sketchConstraintState } from "../solver/diagnostics";
import { editDrawingDimension } from "./edit-dimension";

function drawing() {
  return addSketchLineMidpoint(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("midpoint-line", [
          [0, 0],
          [10, 0],
        ]),
      ],
    },
    { contour: 0, kind: "line", index: 0 },
  );
}
it("retains the original midpoint as construction geometry without adding freedom", () => {
  const d = drawing();
  expect(d.contours[1]).toMatchObject({
    type: "path",
    construction: true,
    start: [0, 0],
    segments: [],
  });
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 4,
  });
  const moved = dragSketchEntity(
    d,
    { contour: 1, kind: "point", index: 0 },
    [2, 3],
  );
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.start[0]).toBeCloseTo(-8);
  expect(path.start[1]).toBeCloseTo(3);
  expect(path.segments[0].end[0]).toBeCloseTo(12);
  expect(path.segments[0].end[1]).toBeCloseTo(3);
});
it("moves the opposite endpoint symmetrically about a fixed midpoint", () => {
  const d = drawing();
  d.constraints!.push({
    id: "center",
    kind: "fix",
    a: { contour: 1, kind: "point", index: 0 },
    point: [0, 0],
  });
  const moved = dragSketchEntity(
    d,
    { contour: 0, kind: "point", index: 1 },
    [2, 3],
  );
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.start[0]).toBeCloseTo(-12);
  expect(path.start[1]).toBeCloseTo(-3);
  expect(path.segments[0].end[0]).toBeCloseTo(12);
  expect(path.segments[0].end[1]).toBeCloseTo(3);
  expect(sketchConstraintState(moved).degreesOfFreedom).toBe(2);
});
it("supports full definition and length edits around the center", () => {
  const d = drawing();
  d.constraints!.push(
    {
      id: "center",
      kind: "fix",
      a: { contour: 1, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "direction",
      kind: "horizontal",
      a: { contour: 0, kind: "line", index: 0 },
    },
    {
      id: "size",
      kind: "length",
      a: { contour: 0, kind: "line", index: 0 },
      value: 20,
    },
  );
  const moved = editDrawingDimension(d, "size", 30);
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.start[0]).toBeCloseTo(-15);
  expect(path.segments[0].end[0]).toBeCloseTo(15);
  expect(sketchConstraintState(moved)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
});
it("uses collision-free constraint IDs and rejects invalid edges atomically", () => {
  const d = drawing(),
    before = structuredClone(d);
  const repeated = addSketchLineMidpoint(d, {
    contour: 0,
    kind: "line",
    index: 0,
  });
  expect(new Set(repeated.constraints!.map((c) => c.id)).size).toBe(2);
  expect(() =>
    addSketchLineMidpoint(d, { contour: 0, kind: "line", index: 4 }),
  ).toThrow();
  expect(d).toEqual(before);
});
