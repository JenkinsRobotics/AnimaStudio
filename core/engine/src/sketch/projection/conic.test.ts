import { expect, it } from "vitest";
import { projectedEllipse } from "./conic";
import type { SketchPoint } from "../drawing";
it("resolves a nearly singular but geometrically usable conic", () => {
  const map = {
    determinant: 1e-12,
    vector: ([x, y]: SketchPoint): SketchPoint => [x, y * 1e-12],
    point: ([x, y]: SketchPoint): SketchPoint => [x, y * 1e-12],
  };
  const axes = projectedEllipse(map, 1e6, 1e6, Math.PI / 4);
  expect(axes.radiusX).toBeCloseTo(1e6);
  expect(axes.radiusY).toBeCloseTo(1e-6, 12);
});
it("normalizes the shape matrix before squaring large radii", () => {
  const map = {
    determinant: 1,
    vector: (p: SketchPoint) => p,
    point: (p: SketchPoint) => p,
  };
  const axes = projectedEllipse(map, 1e160, 5e159, 0);
  expect(Number.isFinite(axes.radiusX)).toBe(true);
  expect(axes.radiusX / 1e160).toBeCloseTo(1);
  expect(axes.radiusY / 5e159).toBeCloseTo(1);
});
