import { expect, it } from "vitest";
import { dimensionValue } from "./dimension-links";
import { sketchConstraintState } from "./diagnostics";
import { setSketchRadius } from "../operations/set-radius";
import { editDrawingDimension } from "../operations/edit-dimension";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [{ type: "circle", center: [5, 5], radius: 5 }],
  constraints: [
    {
      id: "measured",
      kind: "diameter",
      reference: true,
      a: { kind: "circle", contour: 0 },
    },
  ],
});
it("measures live geometry without reducing degrees of freedom or storing a value", () => {
  const d = drawing();
  validateSketchDrawing(d);
  expect(sketchConstraintState(d).degreesOfFreedom).toBe(3);
  expect(dimensionValue(d, d.constraints![0])).toBe(10);
  const next = setSketchRadius(
    JSON.parse(JSON.stringify(d)),
    { kind: "circle", contour: 0 },
    7,
  );
  expect(dimensionValue(next, next.constraints![0])).toBeCloseTo(14);
  expect(next.constraints![0].value).toBeUndefined();
  expect(next.constraints).toHaveLength(2);
  expect(sketchConstraintState(next).degreesOfFreedom).toBe(2);
  expect(() => editDrawingDimension(next, "measured", 12)).toThrow(
    "cannot drive",
  );
});
it("rejects reference drivers, stored driving values and nondimensional reference constraints", () => {
  const d = drawing();
  d.constraints!.push({
    id: "bad",
    kind: "radius",
    a: { kind: "circle", contour: 0 },
    valueFrom: "measured",
  });
  expect(() => validateSketchDrawing(d)).toThrow("cannot drive");
  const literal = drawing();
  literal.constraints![0].value = 10;
  expect(() => validateSketchDrawing(literal)).toThrow("driving values");
  const wrong = drawing();
  wrong.constraints![0].kind = "fix";
  expect(() => validateSketchDrawing(wrong)).toThrow();
});
it("measures signed axis distances and angles directly from geometry", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [2, 3],
        segments: [
          { type: "line", end: [-2, 3] },
          { type: "line", end: [-2, 8] },
        ],
      },
    ],
  };
  const x = {
    id: "x",
    kind: "horizontal-distance" as const,
    reference: true,
    a: { kind: "point" as const, contour: 0, index: 0 },
    b: { kind: "point" as const, contour: 0, index: 1 },
  };
  const angle = {
    id: "a",
    kind: "angle" as const,
    reference: true,
    a: { kind: "line" as const, contour: 0, index: 0 },
    b: { kind: "line" as const, contour: 0, index: 1 },
  };
  expect(dimensionValue(d, x)).toBe(-4);
  expect(dimensionValue(d, angle)).toBe(-90);
});
