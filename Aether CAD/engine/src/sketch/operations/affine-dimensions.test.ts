import { expect, it } from "vitest";
import { linkSketchDimension } from "./link-dimension";
import {
  editDrawingDimension,
  removeDrawingConstraint,
} from "./edit-dimension";
import { setDimensionReference } from "./dimension-reference";
import { dimensionValue } from "../solver/dimension-links";
import { solveDrawingConstraints } from "../solver/solve";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [2, 3, 4].map((radius, i) => ({
    type: "circle",
    center: [i * 30, 0],
    radius,
  })),
  constraints: [2, 3, 4].map((value, i) => ({
    id: `r${i}`,
    kind: "radius",
    a: { contour: i, kind: "circle" },
    value,
  })),
});
it("resolves chained affine links and inversely edits their shared driver", () => {
  const initial = source(),
    before = structuredClone(initial);
  const a = linkSketchDimension(initial, "r1", "r0", 2, 1);
  const b = linkSketchDimension(a, "r2", "r1", 3, 2);
  expect(dimensionValue(b, b.constraints![2])).toBe(17);
  const edited = editDrawingDimension(JSON.parse(JSON.stringify(b)), "r2", 23);
  edited.contours.forEach((c, i) => {
    expect(c.type === "circle" ? c.radius : 0).toBeCloseTo([3, 7, 23][i], 7);
  });
  expect(edited.constraints![0].value).toBe(3);
  expect(edited.constraints![1].value).toBeUndefined();
  expect(edited.constraints![2]).toMatchObject({
    valueFrom: "r1",
    valueScale: 3,
    valueOffset: 2,
  });
  validateSketchDrawing(edited);
  expect(initial).toEqual(before);
});
it("preserves calculated values when a driver is removed or made reference", () => {
  const linked = linkSketchDimension(source(), "r1", "r0", 2, 1);
  for (const next of [
    removeDrawingConstraint(linked, "r0"),
    setDimensionReference(linked, "r0", true),
  ]) {
    const follower = next.constraints!.find((c) => c.id === "r1")!;
    expect(follower.value).toBe(5);
    expect(follower.valueFrom).toBeUndefined();
    expect(follower.valueScale).toBeUndefined();
    expect(follower.valueOffset).toBeUndefined();
    expect(() => solveDrawingConstraints(next)).not.toThrow();
  }
});
it.each([
  [0, 1],
  [Infinity, 0],
  [1, NaN],
])("rejects invalid affine coefficients %s, %s atomically", (scale, offset) => {
  const d = source(),
    before = structuredClone(d);
  expect(() => linkSketchDimension(d, "r1", "r0", scale, offset)).toThrow();
  expect(d).toEqual(before);
});
it("rejects cycles, missing and incompatible drivers", () => {
  const d = linkSketchDimension(source(), "r1", "r0", 2, 1);
  expect(() => linkSketchDimension(d, "r0", "r1")).toThrow("Cyclic");
  expect(() => linkSketchDimension(d, "r1", "missing")).toThrow("missing");
  d.constraints![0].kind = "angle";
  expect(() => linkSketchDimension(d, "r1", "r0")).toThrow("compatible units");
});
it("rejects affine metadata on literal and reference dimensions", () => {
  for (const reference of [false, true]) {
    const d = source();
    d.constraints![0].valueScale = 2;
    if (reference) {
      d.constraints![0].reference = true;
      delete d.constraints![0].value;
    }
    expect(() => solveDrawingConstraints(d)).toThrow();
  }
});
it("composes legacy angular signs with scales and offsets in the correct order", () => {
  const d = source();
  d.constraints!.forEach(c => { c.kind = "angle"; });
  const [, a, b] = d.constraints!;
  delete a.value; delete b.value;
  Object.assign(a, { valueFrom: "r0", valueSign: -1, valueScale: 2, valueOffset: 1 });
  Object.assign(b, { valueFrom: "r1", valueScale: 3, valueOffset: 2 });
  expect(dimensionValue(d, a)).toBe(-3);
  expect(dimensionValue(d, b)).toBe(-7);
});
it("rejects overflow in a chained relationship", () => {
  const d = source();
  delete d.constraints![1].value;
  delete d.constraints![2].value;
  Object.assign(d.constraints![1], { valueFrom: "r0", valueScale: 1e200 });
  Object.assign(d.constraints![2], { valueFrom: "r1", valueScale: 1e200 });
  expect(() => dimensionValue(d, d.constraints![2])).toThrow("numeric range");
});
