import { expect, it } from "vitest";
import { sketchVariantContour } from "../primitives";
import { constrainThreePointCircle } from "./circle-points";
import { dragSketchEntity } from "./drag-entity";
import { sketchConstraintState } from "../solver/diagnostics";
import { constraintResiduals } from "../solver/residuals";
import type { SketchPoint } from "../drawing";

const points: SketchPoint[] = [
  [5, 0],
  [0, 5],
  [-5, 0],
];
function drawing() {
  return constrainThreePointCircle(
    {
      type: "drawing",
      contours: [sketchVariantContour("three-point-circle", points)],
    },
    0,
    points,
  );
}
it("persists selectable placement points and their circle relationships", () => {
  const d = drawing();
  expect(d.contours.slice(1).map((c) => c.type === "path" && c.start)).toEqual(
    points,
  );
  expect(d.contours.slice(1).every((c) => c.construction)).toBe(true);
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 6,
  });
  const moved = dragSketchEntity(
    d,
    { contour: 2, kind: "point", index: 0 },
    [1, 2],
  );
  for (const c of moved.constraints!)
    expect(
      Math.max(...constraintResiduals(moved, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
});
it("keeps two fixed placement points on the circle while the third is dragged", () => {
  const d = drawing();
  for (const i of [0, 2])
    d.constraints!.push({
      id: `fixed-${i}`,
      kind: "fix",
      a: { contour: i + 1, kind: "point", index: 0 },
      point: points[i],
    });
  const moved = dragSketchEntity(
    d,
    { contour: 2, kind: "point", index: 0 },
    [0, 2],
  );
  const expected = sketchVariantContour("three-point-circle", [
    [5, 0],
    [0, 7],
    [-5, 0],
  ]);
  const circle = moved.contours[0];
  if (circle.type !== "circle" || expected.type !== "circle") throw Error();
  expect(circle.center[0]).toBeCloseTo(expected.center[0]);
  expect(circle.center[1]).toBeCloseTo(expected.center[1]);
  expect(circle.radius).toBeCloseTo(expected.radius);
});
it("fully defines a circle when all three placement points are fixed", () => {
  const d = drawing();
  points.forEach((point, i) =>
    d.constraints!.push({
      id: `fixed-${i}`,
      kind: "fix",
      a: { contour: i + 1, kind: "point", index: 0 },
      point,
    }),
  );
  expect(sketchConstraintState(d)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
  expect(() =>
    dragSketchEntity(d, { contour: 2, kind: "point", index: 0 }, [0, 2]),
  ).toThrow();
});
it("rejects collinear or mismatched placement without changing existing geometry", () => {
  const source = {
    type: "drawing" as const,
    contours: [sketchVariantContour("three-point-circle", points)],
  };
  const before = structuredClone(source);
  expect(() =>
    constrainThreePointCircle(source, 0, [
      [0, 0],
      [1, 0],
      [2, 0],
    ]),
  ).toThrow();
  expect(() =>
    constrainThreePointCircle(source, 0, [
      [6, 0],
      [0, 5],
      [-5, 0],
    ]),
  ).toThrow();
  expect(source).toEqual(before);
});
