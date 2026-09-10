import { expect, it } from "vitest";
import { linkSketchDimension, unlinkSketchDimension } from "./link-dimension";
import { editDrawingDimension } from "./edit-dimension";
import { solveDrawingConstraints } from "../solver/solve";
import { dimensionValue } from "../solver/dimension-links";
import type { SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [2, 5, 12].map((radius, i) => ({
    type: "circle",
    center: [30 * i, 0],
    radius,
  })),
  constraints: [2, 5, 12].map((value, i) => ({
    id: `r${i}`,
    kind: "radius",
    a: { contour: i, kind: "circle" },
    value,
  })),
});
it("unlinks an intermediate dimension without changing geometry or its downstream links", () => {
  const linked = linkSketchDimension(
    linkSketchDimension(source(), "r1", "r0", 2, 1),
    "r2",
    "r1",
    2,
    2,
  );
  const before = structuredClone(linked),
    unlinked = unlinkSketchDimension(linked, "r1");
  expect(unlinked.contours).toEqual(linked.contours);
  expect(linked).toEqual(before);
  expect(unlinked.constraints![1]).toMatchObject({ id: "r1", value: 5 });
  for (const key of ["valueFrom", "valueScale", "valueOffset", "valueSign"])
    expect(unlinked.constraints![1]).not.toHaveProperty(key);
  expect(unlinked.constraints![2].valueFrom).toBe("r1");
  const editedRoot = editDrawingDimension(unlinked, "r0", 3);
  expect(dimensionValue(editedRoot, editedRoot.constraints![1])).toBe(5);
  expect(dimensionValue(editedRoot, editedRoot.constraints![2])).toBe(12);
  const editedMiddle = editDrawingDimension(editedRoot, "r1", 7);
  expect(dimensionValue(editedMiddle, editedMiddle.constraints![2])).toBe(16);
  expect(() => solveDrawingConstraints(editedMiddle)).not.toThrow();
  expect(unlinkSketchDimension(unlinked, "r1")).toEqual(unlinked);
});
it("rejects missing and reference dimensions atomically", () => {
  const d = source();
  d.constraints![0].reference = true;
  delete d.constraints![0].value;
  const before = structuredClone(d);
  expect(() => unlinkSketchDimension(d, "missing")).toThrow();
  expect(() => unlinkSketchDimension(d, "r0")).toThrow();
  expect(d).toEqual(before);
});
