import { it, expect } from "vitest";
import { filletSketchLines } from "./fillet-lines";
import type { SketchDrawing } from "../drawing";
it("joins separately drawn lines with a fillet and remaps original endpoint constraints", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [-10, 0] }],
      },
      {
        type: "path",
        start: [0, 10],
        segments: [{ type: "line", end: [0, 0] }],
      },
    ],
    constraints: [
      {
        id: "corner",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [0, 0],
      },
    ],
  };
  const next = filletSketchLines(
      source,
      { contour: 0, segment: 0 },
      { contour: 1, segment: 0 },
      2,
    ),
    c = next.contours[0];
  if (c.type !== "path") throw Error();
  expect(c.start).toEqual([-10, 0]);
  expect(c.segments.map((s) => s.type)).toEqual(["line", "arc", "line"]);
  expect(c.segments[2].end).toEqual([0, 10]);
  expect(next.constraints![0].a).toEqual({
    contour: 1,
    kind: "point",
    index: 0,
  });
  expect(source.contours).toHaveLength(2);
});
it("rejects disjoint lines and accepts adjacent selections in one contour", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-10, 0],
        segments: [
          { type: "line", end: [0, 0] },
          { type: "line", end: [0, 10] },
        ],
      },
    ],
  };
  expect(
    filletSketchLines(
      source,
      { contour: 0, segment: 0 },
      { contour: 0, segment: 1 },
      2,
    ).contours,
  ).toHaveLength(2);
  expect(() =>
    filletSketchLines(
      source,
      { contour: 0, segment: 0 },
      { contour: 0, segment: 0 },
      2,
    ),
  ).toThrow();
});
it("extends disconnected lines to their virtual corner and honors picked sides of crossings", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-10, 0],
        segments: [{ type: "line", end: [-2, 0] }],
      },
      {
        type: "path",
        start: [0, 2],
        segments: [{ type: "line", end: [0, 10] }],
      },
    ],
  };
  const next = filletSketchLines(
    source,
    { contour: 0, segment: 0 },
    { contour: 1, segment: 0 },
    1,
  );
  expect(next.contours[0].type).toBe("path");
  const crossing: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-10, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
      {
        type: "path",
        start: [0, -10],
        segments: [{ type: "line", end: [0, 10] }],
      },
    ],
  };
  const result = filletSketchLines(
      crossing,
      { contour: 0, segment: 0, parameter: 0.25 },
      { contour: 1, segment: 0, parameter: 0.75 },
      2,
    ),
    p = result.contours[0];
  if (p.type !== "path") throw Error();
  expect(p.start).toEqual([-10, 0]);
  expect(p.segments.at(-1)!.end).toEqual([0, 10]);
});
it("rejects a virtual-intersection move that conflicts with a fixed endpoint", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-10, 0],
        segments: [{ type: "line", end: [-2, 0] }],
      },
      {
        type: "path",
        start: [0, 2],
        segments: [{ type: "line", end: [0, 10] }],
      },
    ],
    constraints: [
      {
        id: "fixed",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 1 },
        point: [-2, 0],
      },
    ],
  };
  expect(() =>
    filletSketchLines(
      source,
      { contour: 0, segment: 0 },
      { contour: 1, segment: 0 },
      1,
    ),
  ).toThrow("fixed");
});
