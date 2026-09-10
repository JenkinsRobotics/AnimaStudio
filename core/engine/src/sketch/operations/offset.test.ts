import { expect, it } from "vitest";
import { offsetSketch, offsetSketchContour } from "./offset";
import type { SketchContour, SketchDrawing } from "../drawing";
const square: SketchContour = {
  type: "path",
  start: [0, 0],
  segments: [
    { type: "line", end: [10, 0] },
    { type: "line", end: [10, 10] },
    { type: "line", end: [0, 10] },
    { type: "line", end: [0, 0] },
  ],
};
it("offsets closed line chains with exact miters and preserves originals", () => {
  const source: SketchDrawing = { type: "drawing", contours: [square] },
    before = structuredClone(source);
  const next = offsetSketch(source, [0, 0], 2);
  expect(next.contours).toHaveLength(2);
  expect(next.contours[1]).toEqual({
    type: "path",
    start: [2, 2],
    segments: [
      { type: "line", end: [8, 2] },
      { type: "line", end: [8, 8] },
      { type: "line", end: [2, 8] },
      { type: "line", end: [2, 2] },
    ],
  });
  expect(source).toEqual(before);
  expect(offsetSketchContour(square, -2)).toMatchObject({ start: [-2, -2] });
});
it("offsets open line chains without closing or extending their end caps", () => {
  expect(
    offsetSketchContour(
      {
        type: "path",
        start: [0, 0],
        segments: [
          { type: "line", end: [10, 0] },
          { type: "line", end: [10, 10] },
        ],
      },
      2,
    ),
  ).toEqual({
    type: "path",
    start: [0, 2],
    segments: [
      { type: "line", end: [8, 2] },
      { type: "line", end: [8, 10] },
    ],
  });
});
it("retains exact circle and arc radii for signed offsets", () => {
  expect(
    offsetSketchContour({ type: "circle", center: [3, 4], radius: 5 }, 2),
  ).toEqual({ type: "circle", center: [3, 4], radius: 7 });
  expect(
    offsetSketchContour(
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [0, 5], end: [-5, 0] }],
      },
      2,
    ),
  ).toEqual({
    type: "path",
    start: [3, 0],
    segments: [{ type: "arc", middle: [0, 3], end: [-3, 0] }],
  });
});
it("rejects collapsing radii, reversing corners, collapsed edges and unsupported curves", () => {
  expect(() => offsetSketchContour(square, 6)).toThrow("collapses");
  expect(() =>
    offsetSketchContour({ type: "circle", center: [0, 0], radius: 2 }, -2),
  ).toThrow("collapses");
  expect(() =>
    offsetSketchContour(
      {
        type: "path",
        start: [0, 0],
        segments: [
          { type: "line", end: [2, 0] },
          { type: "line", end: [0, 0] },
        ],
      },
      1,
    ),
  ).toThrow("reversing");
  expect(() =>
    offsetSketchContour(
      {
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [1, 1],
              [2, 1],
            ],
            end: [3, 0],
          },
        ],
      },
      1,
    ),
  ).toThrow("currently requires");
  for (const n of [0, NaN, Infinity])
    expect(() => offsetSketchContour(square, n)).toThrow("finite");
});
it("rejects invalid selection without partially applying a batch", () => {
  const source: SketchDrawing = {
      type: "drawing",
      contours: [square, { type: "circle", center: [0, 0], radius: 1 }],
    },
    before = structuredClone(source);
  expect(() => offsetSketch(source, [0, 1], -2)).toThrow("collapses");
  expect(() => offsetSketch(source, [], 1)).toThrow("Select");
  expect(() => offsetSketch(source, [5], 1)).toThrow("Invalid");
  expect(source).toEqual(before);
});
it('rejects intersecting offset chains instead of saving crossed profiles',()=>{
 const crossing:SketchContour={type:'path',start:[0,0],segments:[{type:'line',end:[10,10]},{type:'line',end:[0,10]},{type:'line',end:[10,0]}]};
 expect(()=>offsetSketchContour(crossing,.1)).toThrow('self-intersect');
});
