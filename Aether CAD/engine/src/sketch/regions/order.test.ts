import { expect, it } from "vitest";
import { sketchRegionOrder } from "./order";
import type { SketchContour } from "../drawing";
const circle = (radius: number, hole = false, x = 0): SketchContour => ({
  type: "circle",
  center: [x, 0],
  radius,
  hole,
});
it("orders all permutations of nested solids and holes without changing references", () => {
  const a = circle(2),
    b = circle(10),
    c = circle(5, true);
  for (const input of [
    [a, b, c],
    [a, c, b],
    [b, a, c],
    [b, c, a],
    [c, a, b],
    [c, b, a],
  ]) {
    const before = structuredClone(input);
    expect(sketchRegionOrder(input).map((i) => input[i])).toEqual([b, c, a]);
    expect(input).toEqual(before);
  }
});
it("preserves solid order and falls back for intersecting explicit holes", () => {
  expect(sketchRegionOrder([circle(2), circle(10)])).toEqual([0, 1]);
  expect(sketchRegionOrder([circle(5, true, 7), circle(5)])).toEqual([1, 0]);
});
