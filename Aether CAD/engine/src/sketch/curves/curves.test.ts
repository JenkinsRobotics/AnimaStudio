import { expect, it } from "vitest";
import { sketchVariantContour } from "../primitives";
import { segmentPoint } from "./parameterization";
import { subdivideSegment } from "./subdivide";
import { lineSegmentIntersections } from "./intersections";
import { splitSketchSegment } from "../operations/split";
import type { SketchPoint, SketchSegment, SketchDrawing } from "../drawing";
const cases: [SketchPoint, SketchSegment][] = [
  [[0, 0], { type: "line", end: [10, 7] }],
  [[5, 0], { type: "arc", middle: [0, -5], end: [0, 5] }],
  [
    [0, 0],
    {
      type: "bezier",
      controls: [
        [0, 10],
        [10, 10],
      ],
      end: [10, 0],
    },
  ],
];
const ellipse = sketchVariantContour("ellipse", [
  [0, 0],
  [8, 6],
  [-3, 4],
]);
if (ellipse.type === "path") cases.push([ellipse.start, ellipse.segments[0]]);
it.each(cases)(
  "subdivides a curve without changing its geometry",
  (start, segment) => {
    const t = 0.37,
      [left, right] = subdivideSegment(start, segment, t);
    expect(left.type).toBe(segment.type);
    expect(right.type).toBe(segment.type);
    for (let i = 0; i <= 20; i++) {
      const u = i / 20,
        expected = segmentPoint(start, segment, u),
        actual =
          u <= t
            ? segmentPoint(start, left, u / t)
            : segmentPoint(left.end, right, (u - t) / (1 - t));
      expect(
        Math.hypot(actual[0] - expected[0], actual[1] - expected[1]),
      ).toBeLessThan(1e-6);
    }
    expect(() => subdivideSegment(start, segment, 0)).toThrow("endpoints");
  },
);
it("finds both cubic crossings and a tangent double root", () => {
  const curve: SketchSegment = {
    type: "bezier",
    controls: [
      [0, 10],
      [10, 10],
    ],
    end: [10, 0],
  };
  const crossings = lineSegmentIntersections([0, 5], [10, 5], [0, 0], curve);
  expect(crossings).toHaveLength(2);
  expect(crossings[0] + crossings[1]).toBeCloseTo(1, 8);
  const tangent = lineSegmentIntersections([0, 7.5], [10, 7.5], [0, 0], curve);
  expect(tangent).toHaveLength(1);
  expect(tangent[0]).toBeCloseTo(0.5, 8);
});
it("respects finite ellipse and arc extents when intersecting an infinite line", () => {
  const top: SketchSegment = {
    type: "ellipse",
    end: [-10, 0],
    radiusX: 10,
    radiusY: 3,
    rotationDegrees: 0,
    largeArc: false,
    sweep: true,
  };
  expect(
    lineSegmentIntersections([-20, 1], [20, 1], [10, 0], top),
  ).toHaveLength(2);
  expect(
    lineSegmentIntersections([-20, -1], [20, -1], [10, 0], top),
  ).toHaveLength(0);
  const arc: SketchSegment = { type: "arc", middle: [0, 5], end: [-5, 0] };
  expect(lineSegmentIntersections([-10, 3], [10, 3], [5, 0], arc)).toHaveLength(
    2,
  );
  expect(
    lineSegmentIntersections([-10, -3], [10, -3], [5, 0], arc),
  ).toHaveLength(0);
});
it("splits cubic geometry and remaps endpoint constraints without altering the source", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [0, 10],
              [10, 10],
            ],
            end: [10, 0],
          },
        ],
      },
    ],
    constraints: [
      {
        id: "fixed",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 1 },
        point: [10, 0],
      },
    ],
  };
  const result = splitSketchSegment(d, [5, 7.5], 0.01),
    contour = result.contours[0];
  if (contour.type !== "path") throw Error();
  expect(contour.segments).toHaveLength(2);
  expect(contour.segments.every((s) => s.type === "bezier")).toBe(true);
  expect(result.constraints![0].a.index).toBe(2);
  expect(d.constraints![0].a.index).toBe(1);
});
