import { expect, it } from "vitest";
import { offsetSketchContour } from "./offset";
import { sketchArcGeometry } from "../arc-geometry";
import { joinOffsetCarriers } from "./offset-carriers";
import type { SketchContour } from "../drawing";
const capsule: SketchContour = {
  type: "path",
  start: [0, -5],
  segments: [
    { type: "line", end: [10, -5] },
    { type: "arc", middle: [15, 0], end: [10, 5] },
    { type: "line", end: [0, 5] },
    { type: "arc", middle: [-5, 0], end: [0, -5] },
  ],
};
it.each([1, -1])(
  "retains exact tangent line/arc joins around a closed capsule (%s)",
  (distance) => {
    const before = structuredClone(capsule),
      out = offsetSketchContour(capsule, distance);
    if (out.type !== "path") throw Error();
    expect(out.start).toEqual([0, -5 + distance]);
    expect(out.segments.map((s) => s.type)).toEqual([
      "line",
      "arc",
      "line",
      "arc",
    ]);
    out.segments.forEach((s, i) => {
      if (s.type === "arc")
        expect(
          sketchArcGeometry(
            i ? out.segments[i - 1].end : out.start,
            s.middle,
            s.end,
          ).radius,
        ).toBeCloseTo(5 - distance, 6);
    });
    expect(out.segments.at(-1)!.end).toEqual(out.start);
    expect(capsule).toEqual(before);
  },
);
it("intersects a line and circular carrier at a non-tangent corner", () => {
  const out = offsetSketchContour(
    {
      type: "path",
      start: [10, 0],
      segments: [
        { type: "line", end: [5, 0] },
        { type: "arc", middle: [0, 5], end: [-5, 0] },
      ],
    },
    1,
  );
  if (out.type !== "path" || out.segments[1].type !== "arc") throw Error();
  expect(out.segments[0].end[0]).toBeCloseTo(Math.sqrt(15), 6);
  expect(out.segments[0].end[1]).toBe(-1);
  expect(
    sketchArcGeometry(
      out.segments[0].end,
      out.segments[1].middle,
      out.segments[1].end,
    ).radius,
  ).toBeCloseTo(4, 6);
});
it("chooses the nearer circle-circle corner and rejects disjoint carriers", () => {
  const a = {
      kind: "arc" as const,
      start: [0, -5] as [number, number],
      end: [4, 3] as [number, number],
      center: [0, 0] as [number, number],
      radius: 5,
      sweep: 2,
    },
    b = {
      ...a,
      center: [8, 0] as [number, number],
      start: [4, 2] as [number, number],
    };
  expect(joinOffsetCarriers(a, b, [4, 3])).toEqual([4, 3]);
  expect(() =>
    joinOffsetCarriers(a, { ...b, center: [20, 0] }, [4, 3]),
  ).toThrow("do not meet");
});
it("rejects collapsed curved profiles without mutating the source", () => {
  const before = structuredClone(capsule);
  expect(() => offsetSketchContour(capsule, 6)).toThrow("collapses");
  expect(capsule).toEqual(before);
});
