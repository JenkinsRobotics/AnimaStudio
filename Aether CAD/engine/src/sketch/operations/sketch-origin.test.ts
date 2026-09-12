import { expect, it } from "vitest";
import { addSketchOrigin } from "./sketch-origin";
import { solveDrawingConstraints } from "../solver/solve";
import { sketchConstraintState } from "../solver/diagnostics";
import type { SketchDrawing } from "../drawing";

it("creates one reusable fixed origin without moving or fixing existing geometry", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "path", start: [0, 0], segments: [] }],
  };
  const { drawing, origin } = addSketchOrigin(source);
  expect(origin.contour).toBe(1);
  expect(source.contours).toHaveLength(1);
  expect(source.constraints).toBeUndefined();
  expect(sketchConstraintState(drawing, origin).degreesOfFreedom).toBe(0);
  expect(
    sketchConstraintState(drawing, { kind: "point", contour: 0, index: 0 })
      .degreesOfFreedom,
  ).toBe(2);
  expect(addSketchOrigin(JSON.parse(JSON.stringify(drawing))).drawing).toEqual(
    drawing,
  );
});

it("uses the fixed origin for a persistent driving distance", () => {
  const { drawing, origin } = addSketchOrigin({
    type: "drawing",
    contours: [{ type: "path", start: [3, 4], segments: [] }],
  });
  const point = { kind: "point" as const, contour: 0, index: 0 };
  const solved = solveDrawingConstraints({
    ...drawing,
    constraints: [
      ...drawing.constraints!,
      { id: "distance", kind: "distance", a: point, b: origin, value: 10 },
    ],
  });
  const p = (solved.contours[0] as { start: [number, number] }).start;
  expect(Math.hypot(...p)).toBeCloseTo(10, 5);
  expect(Math.hypot(...(solved.contours[1] as { start: [number, number] }).start)).toBeLessThan(1e-7);
  expect(addSketchOrigin(solved).drawing.contours).toHaveLength(2);
  expect(sketchConstraintState(solved, point).degreesOfFreedom).toBe(1);
});
