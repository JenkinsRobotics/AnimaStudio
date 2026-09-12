import { expect, it } from "vitest";
import { snapSemicircle } from "./semicircle-snap";
import { sketchArcGeometry } from "./arc-geometry";
it.each([
  [0, 5.02],
  [0, -4.98],
  [3.01, 4.01],
])("snaps a curvature point %s to an exact half-circle", (x, y) => {
  const p = snapSemicircle([-5, 0], [5, 0], [x, y], 0.1)!;
  expect(p).toBeDefined();
  expect(Math.abs(sketchArcGeometry([-5, 0], p, [5, 0]).sweep)).toBeCloseTo(
    Math.PI,
    10,
  );
});
it("handles translated and rotated endpoint chords", () => {
  const p = snapSemicircle([3, 2], [3, 12], [8.02, 7], 0.1)!;
  expect(p).toEqual([8, 7]);
});
it("does not snap outside tolerance or offer degenerate arcs", () => {
  expect(snapSemicircle([-5, 0], [5, 0], [0, 5.2], 0.1)).toBeUndefined();
  expect(snapSemicircle([-5, 0], [5, 0], [5, 0], 0.1)).toBeUndefined();
  expect(snapSemicircle([-5, 0], [5, 0], [0, 0], 10)).toBeUndefined();
  expect(snapSemicircle([0, 0], [0, 0], [0, 1], 1)).toBeUndefined();
  expect(snapSemicircle([-5, 0], [5, 0], [NaN, 5], 0.1)).toBeUndefined();
});
