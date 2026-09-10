import { expect, it } from "vitest";
import { contourNestingDepths } from "./nesting";
import { classifyImportedRegions } from "../import/classify-regions";
import { sketchVariantContour } from "../primitives";
import type { SketchContour } from "../drawing";
const circle = (radius: number, x = 0): SketchContour => ({
  type: "circle",
  center: [x, 0],
  radius,
});
it("classifies holes and nested islands independently of input order and direction", () => {
  const contours = [circle(2), circle(10), circle(5), circle(1, 30)];
  expect(contourNestingDepths(contours)).toEqual([2, 0, 1, 0]);
  const result = classifyImportedRegions({ type: "drawing", contours });
  expect(result.contours.map((c) => c.hole)).toEqual([
    false,
    false,
    true,
    false,
  ]);
  expect(contours[0].hole).toBeUndefined();
});
it("handles ellipse and line boundaries and leaves open/construction curves alone", () => {
  const outer = sketchVariantContour("ellipse", [
      [0, 0],
      [10, 0],
      [0, 5],
    ]),
    inner = sketchVariantContour("aligned-rectangle", [
      [-1, -1],
      [1, -1],
      [1, 1],
    ]);
  const d = classifyImportedRegions({
    type: "drawing",
    contours: [
      outer,
      inner,
      {
        type: "path",
        start: [20, 0],
        segments: [{ type: "line", end: [30, 0] }],
      },
      { ...circle(1), construction: true },
    ],
  });
  expect(d.contours.map((c) => c.hole)).toEqual([
    false,
    true,
    undefined,
    undefined,
  ]);
});
it("refuses touching, crossing and self-intersecting boundaries", () => {
  expect(contourNestingDepths([circle(5), circle(5, 10)])).toBeUndefined();
  expect(contourNestingDepths([circle(5), circle(5, 7)])).toBeUndefined();
  const bow: SketchContour = {
    type: "path",
    start: [0, 0],
    segments: [
      { type: "line", end: [4, 4] },
      { type: "line", end: [0, 4] },
      { type: "line", end: [4, 0] },
      { type: "line", end: [0, 0] },
    ],
  };
  expect(() =>
    classifyImportedRegions({ type: "drawing", contours: [bow] }),
  ).toThrow("manual region");
});
