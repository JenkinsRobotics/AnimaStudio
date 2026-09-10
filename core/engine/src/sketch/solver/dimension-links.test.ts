import { it, expect } from "vitest";
import { dimensionValue } from "./dimension-links";
import {
  editDrawingDimension,
  removeDrawingConstraint,
} from "../operations/edit-dimension";
import { deleteSketchContour } from "../operations/delete";
import { trimSketchCurve } from "../operations/trim";
import { solveDrawingConstraints } from "./solve";
import type { SketchDrawing } from "../drawing";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { type: "circle", center: [0, 0], radius: 2 },
    { type: "circle", center: [10, 0], radius: 2 },
  ],
  constraints: [
    {
      id: "driver",
      kind: "radius",
      a: { contour: 0, kind: "circle" },
      value: 2,
    },
    {
      id: "follower",
      kind: "radius",
      a: { contour: 1, kind: "circle" },
      valueFrom: "driver",
    },
  ],
});
it("edits a persisted follower through its driver without caching a duplicate value", () => {
  const source = drawing(),
    before = structuredClone(source),
    result = editDrawingDimension(
      JSON.parse(JSON.stringify(source)),
      "follower",
      3,
    );
  for (const c of result.contours)
    expect(c.type === "circle" ? c.radius : 0).toBeCloseTo(3, 6);
  expect(result.constraints![1].value).toBeUndefined();
  expect(dimensionValue(result, result.constraints![1])).toBe(3);
  expect(source).toEqual(before);
});
it("preserves follower values when a driver constraint or its geometry is removed", () => {
  for (const result of [
    removeDrawingConstraint(drawing(), "driver"),
    deleteSketchContour(drawing(), 0),
  ]) {
    const follower = result.constraints!.find((c) => c.id === "follower")!;
    expect(follower.valueFrom).toBeUndefined();
    expect(follower.value).toBe(2);
    expect(() => solveDrawingConstraints(result)).not.toThrow();
  }
});
it("rejects missing, cyclic, conflicting and incompatible dimensional drivers", () => {
  for (const variant of ["missing", "cycle", "conflict", "units"]) {
    const d = drawing();
    if (variant === "missing") d.constraints![1].valueFrom = "absent";
    if (variant === "cycle") {
      delete d.constraints![0].value;
      d.constraints![0].valueFrom = "follower";
    }
    if (variant === "conflict") d.constraints![1].value = 2;
    if (variant === "units") d.constraints![0].kind = "angle";
    expect(() => solveDrawingConstraints(d)).toThrow();
  }
});
it("materializes a surviving linked dimension when trim removes its driver geometry", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-5, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
      { type: "circle", center: [30, 0], radius: 10 },
    ],
    constraints: [
      {
        id: "length",
        kind: "length",
        a: { contour: 0, kind: "line", index: 0 },
        value: 10,
      },
      {
        id: "radius",
        kind: "radius",
        a: { contour: 1, kind: "circle" },
        valueFrom: "length",
      },
    ],
  };
  const result = trimSketchCurve(d, [0, 0], 0.1),
    radius = result.constraints!.find((c) => c.id === "radius")!;
  expect(radius.value).toBe(10);
  expect(radius.valueFrom).toBeUndefined();
  expect(() => solveDrawingConstraints(result)).not.toThrow();
});
