import { it, expect } from "vitest";
import { cubicOverlap } from "./cubic-overlap";
import { curveIntersections, type Curve } from "./pairs";
import { subdivideSegment } from "./subdivide";
const source: Curve = {
  start: [0, 0],
  segment: {
    type: "bezier",
    controls: [
      [0, 10],
      [10, 10],
    ],
    end: [10, 0],
  },
};
it("recognizes a contained cubic subcurve and reversed duplicate without flattening", () => {
  const [left] = subdivideSegment(source.start, source.segment, 0.75);
  const [prefix, middle] = subdivideSegment(source.start, left, 1 / 3);
  const sub: Curve = { start: prefix.end, segment: middle };
  const hits = curveIntersections(source, sub);
  expect(hits).toHaveLength(2);
  expect(hits[0].first).toBeCloseTo(0.25, 6);
  expect(hits[1].first).toBeCloseTo(0.75, 6);
  if (source.segment.type !== "bezier") throw Error();
  const reversed: Curve = {
    start: source.segment.end,
    segment: {
      type: "bezier",
      controls: [source.segment.controls[1], source.segment.controls[0]],
      end: source.start,
    },
  };
  const reverseHits = cubicOverlap(source, reversed)!;
  expect(reverseHits[0].second).toBeCloseTo(1);
  expect(reverseHits[1].second).toBeCloseTo(0);
});
it("does not confuse common endpoints with coincident cubic geometry", () => {
  const different: Curve = {
    start: [0, 0],
    segment: {
      type: "bezier",
      controls: [
        [0, 8],
        [10, 8],
      ],
      end: [10, 0],
    },
  };
  expect(cubicOverlap(source, different)).toBeUndefined();
});
it("trims an overlapping cubic interval into exact remaining cubic segments", async () => {
  const { trimSketchCurve } = await import("../operations/trim");
  const [left] = subdivideSegment(source.start, source.segment, 0.75),
    [prefix, middle] = subdivideSegment(source.start, left, 1 / 3);
  const result = trimSketchCurve(
    {
      type: "drawing",
      contours: [
        { type: "path", start: source.start, segments: [source.segment] },
        { type: "path", start: prefix.end, segments: [middle] },
      ],
    },
    [5, 7.5],
    0.01,
  );
  expect(result.contours).toHaveLength(3);
  const a = result.contours[0],
    b = result.contours[1];
  if (a.type !== "path" || b.type !== "path") throw Error("paths");
  expect(a.segments[0].type).toBe("bezier");
  expect(b.segments[0].type).toBe("bezier");
  expect(a.segments[0].end[0]).toBeCloseTo(prefix.end[0], 6);
  expect(b.start[0]).toBeCloseTo(left.end[0], 6);
});
