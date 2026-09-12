import { expect, it } from "vitest";
import { sketchVariantContour } from "../primitives";
import { sketchConstraintState } from "../solver/diagnostics";
import { constraintResiduals } from "../solver/residuals";
import { dragSketchEntity } from "./drag-entity";
import { constrainSketchRectangle } from "./rectangle-relations";
import type { SketchDrawing } from "../drawing";

it("preserves axis-aligned rectangle relationships when dragging a corner", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      sketchVariantContour("center-rectangle", [
        [0, 0],
        [10, 5],
      ]),
    ],
  };
  const d = constrainSketchRectangle(source, 0, "rectangle");
  expect(source.constraints).toBeUndefined();
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 4,
  });
  const moved = dragSketchEntity(
    d,
    { contour: 0, kind: "point", index: 2 },
    [3, 2],
  );
  expect(moved.constraints).toEqual(d.constraints);
  for (const c of moved.constraints!)
    expect(
      Math.max(...constraintResiduals(moved, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments[1].end[0]).toBeCloseTo(13);
  expect(path.segments[1].end[1]).toBeCloseTo(7);
});

it("keeps an aligned rectangle free to rotate while preserving right angles", () => {
  const d = constrainSketchRectangle(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("aligned-rectangle", [
          [0, 0],
          [8, 6],
          [-3, 4],
        ]),
      ],
    },
    0,
    "aligned-rectangle",
  );
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 5,
  });
  const moved = dragSketchEntity(
    d,
    { contour: 0, kind: "point", index: 1 },
    [2, 1],
  );
  for (const c of moved.constraints!)
    expect(
      Math.max(...constraintResiduals(moved, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
});

it("retains a selectable center and resizes symmetrically when that center is fixed", () => {
  const d = constrainSketchRectangle(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("center-rectangle", [
          [0, 0],
          [10, 5],
        ]),
      ],
    },
    0,
    "center-rectangle",
  );
  expect(d.contours.slice(1).every((c) => c.construction)).toBe(true);
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 4,
  });
  d.constraints!.push({
    id: "fixed-center",
    kind: "fix",
    a: { contour: 2, kind: "point", index: 0 },
    point: [0, 0],
  });
  expect(sketchConstraintState(d).degreesOfFreedom).toBe(2);
  const moved = dragSketchEntity(
    d,
    { contour: 0, kind: "point", index: 2 },
    [3, 2],
  );
  const path = moved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.start[0]).toBeCloseTo(-13);
  expect(path.start[1]).toBeCloseTo(-7);
});

it("rejects nonrectangular paths atomically", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      sketchVariantContour("center-rectangle", [
        [0, 0],
        [10, 5],
      ]),
    ],
  };
  const path = d.contours[0];
  if (path.type !== "path") throw Error();
  path.segments[0].end[1] += 1;
  const before = structuredClone(d);
  expect(() => constrainSketchRectangle(d, 0, "rectangle")).toThrow();
  expect(d).toEqual(before);
});
