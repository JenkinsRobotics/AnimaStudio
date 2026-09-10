import { expect, it } from "vitest";
import { setDimensionReference } from "./dimension-reference";
import { editDrawingDimension } from "./edit-dimension";
import { dimensionValue } from "../solver/dimension-links";
import { type SketchDrawing } from "../drawing";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [1, 2, 3].map((i) => ({
    type: "circle",
    center: [i * 10, 0],
    radius: 5,
  })),
  constraints: [
    { id: "a", kind: "radius", a: { kind: "circle", contour: 0 }, value: 5 },
    {
      id: "b",
      kind: "radius",
      a: { kind: "circle", contour: 1 },
      valueFrom: "a",
    },
    {
      id: "c",
      kind: "radius",
      a: { kind: "circle", contour: 2 },
      valueFrom: "b",
    },
  ],
});
it("preserves dependent values while converting a driver to a measurement", () => {
  const source = drawing(),
    next = setDimensionReference(source, "a", true);
  expect(next.contours).toEqual(source.contours);
  expect(next.constraints![0]).toMatchObject({ id: "a", reference: true });
  expect(next.constraints![0].value).toBeUndefined();
  expect(next.constraints![1]).toMatchObject({ id: "b", value: 5 });
  expect(next.constraints![1].valueFrom).toBeUndefined();
  expect(next.constraints![2].valueFrom).toBe("b");
  const edited = editDrawingDimension(next, "b", 8);
  expect(dimensionValue(edited, edited.constraints![0])).toBeCloseTo(5);
  expect(source).toEqual(drawing());
});
it("restores a driving value from measured geometry with the same identity", () => {
  const next = setDimensionReference(drawing(), "b", true);
  next.contours[1] = { type: "circle", center: [20, 0], radius: 7 };
  const driving = setDimensionReference(
    JSON.parse(JSON.stringify(next)),
    "b",
    false,
  );
  expect(driving.constraints![1]).toMatchObject({ id: "b", value: 7 });
  expect(driving.constraints![1].reference).toBeUndefined();
  expect(driving.constraints![1].valueFrom).toBeUndefined();
  expect(setDimensionReference(driving, "b", false)).toEqual(driving);
  expect(() => setDimensionReference(driving, "missing", true)).toThrow();
});
