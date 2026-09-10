import { expect, it } from "vitest";
import { editDrawingDimension } from "../operations/edit-dimension";
import { sketchEntityPoint } from "./entities";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { sketchConstraintState } from "./diagnostics";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { type: "path", construction: true, start: [5, 5], segments: [] },
    { type: "path", construction: true, start: [8, 9], segments: [] },
  ],
  constraints: [
    {
      id: "anchor",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [5, 5],
    },
    {
      id: "x",
      kind: "horizontal-distance",
      a: { kind: "point", contour: 0, index: 0 },
      b: { kind: "point", contour: 1, index: 0 },
      value: 3,
    },
    {
      id: "y",
      kind: "vertical-distance",
      a: { kind: "point", contour: 0, index: 0 },
      b: { kind: "point", contour: 1, index: 0 },
      value: 4,
    },
  ],
});
it("independently drives both coordinates, including zero and signed distances", () => {
  const source = drawing();
  validateSketchDrawing(source);
  expect(sketchConstraintState(source).degreesOfFreedom).toBe(0);
  const moved = editDrawingDimension(
    JSON.parse(JSON.stringify(source)),
    "x",
    -2,
  );
  const p = sketchEntityPoint(moved, { kind: "point", contour: 1, index: 0 })!;
  expect(p[0]).toBeCloseTo(3);
  expect(p[1]).toBeCloseTo(9);
  const aligned = editDrawingDimension(moved, "y", 0);
  expect(
    sketchEntityPoint(aligned, { kind: "point", contour: 1, index: 0 })![1],
  ).toBeCloseTo(5);
  expect(source.contours[1]).toMatchObject({ start: [8, 9] });
});
it("rejects incompatible geometry and nonfinite values without changing the document", () => {
  const d = drawing();
  expect(() => editDrawingDimension(d, "x", NaN)).toThrow();
  const wrong = structuredClone(d);
  wrong.constraints![1].a = { kind: "line", contour: 0, index: 0 };
  expect(() => validateSketchDrawing(wrong)).toThrow();
  expect(d).toEqual(drawing());
});
