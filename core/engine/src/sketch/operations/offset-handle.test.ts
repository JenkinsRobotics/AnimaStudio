import { expect, it } from "vitest";
import { offsetSketch } from "./offset";
import {
  offsetDistanceHandle,
  offsetDistanceFromHandle,
} from "./offset-handle";
import type { SketchContour } from "../drawing";
it.each<SketchContour>([
  { type: "circle", center: [0, 0], radius: 5 },
  { type: "path", start: [0, 0], segments: [{ type: "line", end: [10, 0] }] },
  {
    type: "path",
    start: [5, 0],
    segments: [{ type: "arc", middle: [0, 5], end: [-5, 0] }],
  },
  {
    type: "path",
    start: [0, 0],
    segments: [
      { type: "line", end: [10, 0] },
      { type: "line", end: [10, 10] },
    ],
  },
])(
  "projects signed distance and ignores movement along the source tangent",
  (contour) => {
    const drawing = offsetSketch(
        { type: "drawing", contours: [contour] },
        [0],
        1,
      ),
      handle = offsetDistanceHandle(drawing, "offset-1")!;
    expect(handle).toBeTruthy();
    expect(offsetDistanceFromHandle(handle, handle.position)).toBeCloseTo(1, 6);
    const { origin: o, direction: n } = handle;
    expect(
      offsetDistanceFromHandle(handle, [
        o[0] - 2 * n[0] - 20 * n[1],
        o[1] - 2 * n[1] + 20 * n[0],
      ]),
    ).toBeCloseTo(-2, 6);
    expect(() => offsetDistanceFromHandle(handle, [NaN, 0])).toThrow("finite");
  },
);
it("resolves shared drivers for later handles in a batch", () => {
  const d = offsetSketch(
    {
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 5 },
        { type: "circle", center: [20, 0], radius: 5 },
      ],
    },
    [0, 1],
    2,
  );
  expect(offsetDistanceHandle(d, "offset-2")).toMatchObject({
    distance: 2,
    position: [27, 0],
  });
  expect(offsetDistanceHandle(d, "missing")).toBeUndefined();
});
