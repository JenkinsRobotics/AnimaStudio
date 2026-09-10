import { dimensionValue } from "../solver/dimension-links";
import { it, expect } from "vitest";
import { chamferSketchCorner } from "./chamfer";
import { contourClosed, type SketchDrawing } from "../drawing";
import {
  constraintResiduals,
  solveDrawingConstraints,
} from "../drawing-constraints";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        { type: "line", end: [10, 0] },
        { type: "line", end: [10, 10] },
        { type: "line", end: [0, 10] },
        { type: "line", end: [0, 0] },
      ],
    },
  ],
  constraints: [
    {
      id: "length",
      kind: "length",
      a: { contour: 0, kind: "line", index: 0 },
      value: 10,
    },
  ],
});
it("creates an asymmetric chamfer and preserves the original sharp length reference", () => {
  const d = source(),
    before = structuredClone(d),
    result = chamferSketchCorner(d, 0, 1, {
      mode: "two-distances",
      distance: 2,
      secondDistance: 3,
    }),
    path = result.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments[0].end).toEqual([8, 0]);
  expect(path.segments[1].end).toEqual([10, 3]);
  expect(contourClosed(path)).toBe(true);
  expect(result.constraints!.find((c) => c.id === "length")!.kind).toBe(
    "distance",
  );
  expect(d).toEqual(before);
  for (const c of result.constraints!)
    for (const r of constraintResiduals(result, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("persists and solves an angle-driven chamfer at a closed seam", () => {
  const result = chamferSketchCorner(source(), 0, 0, {
      mode: "distance-angle",
      distance: 2,
      angleDegrees: 30,
    }),
    reopened = JSON.parse(JSON.stringify(result));
  const angle = reopened.constraints.find(
    (c: { kind: string }) => c.kind === "angle",
  );
  expect(Math.abs(angle.value)).toBeCloseTo(30);
  angle.value = Math.sign(angle.value) * 35;
  const solved = solveDrawingConstraints(reopened);
  expect(contourClosed(solved.contours[0])).toBe(true);
  for (const c of solved.constraints!)
    for (const r of constraintResiduals(solved, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("supports equal setbacks and rejects invalid distances and angles atomically", () => {
  const d = source(),
    before = structuredClone(d),
    result = chamferSketchCorner(d, 0, 1, {
      mode: "equal-distance",
      distance: 2,
    });
  expect(
    result
      .constraints!.filter(
        (c) => c.id.startsWith("chamfer") && c.kind === "distance",
      )
      .map((c) => dimensionValue(result, c)),
  ).toEqual([2, 2]);
  expect(() =>
    chamferSketchCorner(d, 0, 1, {
      mode: "distance-angle",
      distance: 2,
      angleDegrees: 100,
    }),
  ).toThrow("angle");
  expect(() =>
    chamferSketchCorner(d, 0, 1, {
      mode: "two-distances",
      distance: 2,
      secondDistance: 20,
    }),
  ).toThrow("large");
  expect(d).toEqual(before);
});
