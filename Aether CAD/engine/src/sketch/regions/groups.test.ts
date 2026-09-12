import { expect, it } from "vitest";
import type { SketchContour } from "../drawing";
import { sketchRegionGroups } from "./groups";
const circle = (x: number, radius: number, hole = false): SketchContour => ({
  type: "circle",
  center: [x, 0],
  radius,
  hole,
});
it("associates each disconnected solid with its own hole regardless of input order", () => {
  const contours = [
    circle(30, 2, true),
    circle(0, 5),
    circle(0, 2, true),
    circle(30, 5),
  ];
  expect(sketchRegionGroups(contours)).toEqual([
    { solid: 1, holes: [2] },
    { solid: 3, holes: [0] },
  ]);
});
it("preserves nested islands and avoids redundant nested cuts", () => {
  expect(
    sketchRegionGroups([
      circle(0, 10),
      circle(0, 8, true),
      circle(0, 6),
      circle(0, 4, true),
    ]),
  ).toEqual([
    { solid: 0, holes: [1] },
    { solid: 2, holes: [3] },
  ]);
});
it("retains multiple holes in a single solid", () => {
  expect(
    sketchRegionGroups([
      circle(0, 10),
      circle(-4, 2, true),
      circle(4, 2, true),
    ]),
  ).toEqual([{ solid: 0, holes: [1, 2] }]);
});
it("falls back to ordered Booleans for crossing or touching holes", () => {
  expect(
    sketchRegionGroups([circle(0, 10), circle(9, 3, true)]),
  ).toBeUndefined();
  expect(
    sketchRegionGroups([circle(0, 10), circle(8, 2, true)]),
  ).toBeUndefined();
});
