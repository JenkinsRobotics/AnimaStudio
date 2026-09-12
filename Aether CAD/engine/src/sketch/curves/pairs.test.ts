import { expect, it } from "vitest";
import { curveIntersections, type Curve } from "./pairs";
import { circleSegments } from "./picking";
import { segmentPoint } from "./parameterization";
const line = (start: [number, number], end: [number, number]): Curve => ({
  start,
  segment: { type: "line", end },
});
it("intersects circles and ellipses analytically, including the omitted half-angle endpoint", () => {
  const a = circleSegments([0, 0], 5),
    b = circleSegments([6, 0], 5);
  const hits = a.flatMap((x) => b.flatMap((y) => curveIntersections(x, y)));
  expect(hits).toHaveLength(2);
  for (const h of hits) {
    expect(h.point[0]).toBeCloseTo(3, 6);
    expect(Math.abs(h.point[1])).toBeCloseTo(4, 6);
  }
  const ellipse: Curve = {
    start: [10, 0],
    segment: {
      type: "ellipse",
      end: [-10, 0],
      radiusX: 10,
      radiusY: 3,
      rotationDegrees: 0,
      largeArc: false,
      sweep: true,
    },
  };
  const tangent = circleSegments([-12, 0], 2).flatMap((c) =>
    curveIntersections(ellipse, c),
  );
  expect(tangent.some((h) => Math.abs(h.point[0] + 10) < 1e-6)).toBe(true);
});
it("filters nonintersecting conics and accepts adjacent halves without treating them as overlaps", () => {
  const a = circleSegments([0, 0], 5),
    b = circleSegments([0, 0], 2);
  expect(curveIntersections(a[0], b[0])).toHaveLength(0);
  expect(curveIntersections(a[0], a[1])).toHaveLength(2);
  expect(curveIntersections(a[0], a[0])).toHaveLength(2);
});
it("intersects cubic curves with conics and preserves parameters on both curves", () => {
  const cubic: Curve = {
      start: [-8, 0],
      segment: {
        type: "bezier",
        controls: [
          [-3, 8],
          [3, 8],
        ],
        end: [8, 0],
      },
    },
    circle = circleSegments([0, 0], 7);
  const hits = circle.flatMap((c) =>
    curveIntersections(cubic, c).map((h) => ({ ...h, curve: c })),
  );
  expect(hits.length).toBeGreaterThan(0);
  for (const h of hits) {
    const a = segmentPoint(cubic.start, cubic.segment, h.first),
      b = segmentPoint(h.curve.start, h.curve.segment, h.second);
    expect(Math.hypot(a[0] - b[0], a[1] - b[1])).toBeLessThan(1e-5);
  }
});
it("isolates cubic/cubic crossings using exact subdivisions", () => {
  const a: Curve = {
      start: [0, 0],
      segment: {
        type: "bezier",
        controls: [
          [0, 10],
          [10, 10],
        ],
        end: [10, 0],
      },
    },
    b: Curve = {
      start: [0, 5],
      segment: {
        type: "bezier",
        controls: [
          [3, 5],
          [7, 5],
        ],
        end: [10, 5],
      },
    };
  const hits = curveIntersections(a, b);
  expect(hits).toHaveLength(2);
  for (const h of hits) expect(h.point[1]).toBeCloseTo(5, 5);
  expect(curveIntersections(a, a)).toHaveLength(2);
  expect(
    curveIntersections(line([0, 0], [10, 0]), line([2, 0], [8, 0])).map(
      (h) => h.first,
    ),
  ).toEqual([0.2, 0.8]);
});
it("returns finite overlap endpoints for elliptical arcs and reversed lines", () => {
  const first: Curve = {
    start: [10, 0],
    segment: {
      type: "ellipse",
      end: [-10, 0],
      radiusX: 10,
      radiusY: 3,
      rotationDegrees: 0,
      largeArc: false,
      sweep: true,
    },
  };
  const second: Curve = {
    start: [0, 3],
    segment: {
      type: "ellipse",
      end: [-10, 0],
      radiusX: 10,
      radiusY: 3,
      rotationDegrees: 0,
      largeArc: false,
      sweep: true,
    },
  };
  const hits = curveIntersections(first, second);
  expect(hits).toHaveLength(2);
  expect(hits[0].first).toBeCloseTo(0.5);
  expect(hits[1].first).toBeCloseTo(1);
  expect(
    curveIntersections(line([0, 0], [10, 0]), line([8, 0], [2, 0])).map(
      (h) => h.second,
    ),
  ).toEqual([expect.closeTo(1), expect.closeTo(0)]);
});
