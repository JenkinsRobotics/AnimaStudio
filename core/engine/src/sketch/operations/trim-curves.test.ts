import { expect, it } from "vitest";
import { trimSketchCurve } from "./trim";
import { sketchVariantContour } from "../primitives";
import { segmentPoint } from "../curves/parameterization";
import type { SketchDrawing, SketchPoint } from "../drawing";
const line = (a: SketchPoint, b: SketchPoint) => ({
  type: "path" as const,
  start: a,
  segments: [{ type: "line" as const, end: b }],
});
it("trims the selected interval of a Bezier without lowering its degree", () => {
  const source = sketchVariantContour("cubic-bezier", [
    [0, 0],
    [0, 10],
    [10, 10],
    [10, 0],
  ]);
  const d: SketchDrawing = {
    type: "drawing",
    contours: [source, line([2, -5], [2, 12]), line([8, -5], [8, 12])],
  };
  const next = trimSketchCurve(d, [5, 7.5], 0.01);
  expect(next.contours).toHaveLength(4);
  const a = next.contours[0],
    b = next.contours[1];
  if (a.type !== "path" || b.type !== "path") throw Error();
  expect(a.segments[0].type).toBe("bezier");
  expect(b.segments[0].type).toBe("bezier");
  expect(a.segments[0].end[0]).toBeCloseTo(2, 5);
  expect(b.start[0]).toBeCloseTo(8, 5);
  expect(d.contours).toHaveLength(3);
});
it("trims a circle to an exact open arc and deletes standalone points", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      { type: "circle", center: [0, 0], radius: 5 },
      line([0, -10], [0, 10]),
    ],
  };
  const next = trimSketchCurve(d, [5, 0], 0.01),
    c = next.contours[0];
  if (c.type !== "path") throw Error();
  expect(c.segments[0].type).toBe("arc");
  const middle = segmentPoint(c.start, c.segments[0], 0.5);
  expect(middle[0]).toBeCloseTo(-5, 5);
  expect(
    trimSketchCurve(
      {
        type: "drawing",
        contours: [{ type: "path", start: [1, 2], segments: [] }],
      },
      [1, 2],
      0.01,
    ).contours,
  ).toHaveLength(0);
});
it("trims an ellipse while retaining exact elliptical segments", () => {
  const c = sketchVariantContour("ellipse", [
    [0, 0],
    [10, 0],
    [0, 3],
  ]);
  const d: SketchDrawing = {
    type: "drawing",
    contours: [c, line([-3, -5], [-3, 5]), line([3, -5], [3, 5])],
  };
  const next = trimSketchCurve(d, [0, 3], 0.01),
    path = next.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments.every((s) => s.type === "ellipse")).toBe(true);
  expect(path.start[0]).toBeCloseTo(-3, 5);
});
it("retains circle radius and fixed center after trimming and a later dimension change", async () => {
  const { solveDrawingConstraints } = await import("../drawing-constraints");
  const { sketchArcGeometry } = await import("../arc-geometry");
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      { type: "circle", center: [0, 0], radius: 5 },
      line([0, -10], [0, 10]),
    ],
    constraints: [
      {
        id: "radius",
        kind: "radius",
        a: { contour: 0, kind: "circle" },
        value: 5,
      },
      {
        id: "center",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [0, 0],
      },
    ],
  };
  const next = trimSketchCurve(d, [5, 0], 0.01);
  expect(next.constraints![0].a).toEqual({ contour: 0, kind: "arc", index: 0 });
  expect(next.contours[2]).toMatchObject({
    type: "path",
    construction: true,
    start: [0, 0],
  });
  next.constraints![0].value = 8;
  const solved = solveDrawingConstraints(next),
    c = solved.contours[0];
  if (c.type !== "path" || c.segments[0].type !== "arc") throw Error("arc");
  const arc = sketchArcGeometry(
    c.start,
    c.segments[0].middle,
    c.segments[0].end,
  );
  expect(arc.radius).toBeCloseTo(8, 5);
  expect(arc.center[0]).toBeCloseTo(0, 5);
  expect(arc.center[1]).toBeCloseTo(0, 5);
  expect(d.contours[0].type).toBe("circle");
});
it("remaps surviving path vertices and unrelated contours after removing a middle interval", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-10, 0],
        segments: [
          { type: "line", end: [10, 0] },
          { type: "line", end: [10, 10] },
        ],
      },
      line([-3, -5], [-3, 5]),
      line([3, -5], [3, 5]),
    ],
    constraints: [
      {
        id: "start",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [-10, 0],
      },
      {
        id: "end",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 2 },
        point: [10, 10],
      },
      {
        id: "vertical",
        kind: "vertical",
        a: { contour: 0, kind: "line", index: 1 },
      },
      {
        id: "boundary",
        kind: "vertical",
        a: { contour: 2, kind: "line", index: 0 },
      },
      {
        id: "removed-length",
        kind: "length",
        a: { contour: 0, kind: "line", index: 0 },
        value: 20,
      },
    ],
  };
  const next = trimSketchCurve(d, [0, 0], 0.01);
  expect(next.constraints!.slice(0, 4).map((c) => c.id)).toEqual([
    "start",
    "end",
    "vertical",
    "boundary",
  ]);
  expect(next.constraints![1].a).toEqual({
    contour: 1,
    kind: "point",
    index: 2,
  });
  expect(next.constraints![2].a).toEqual({
    contour: 1,
    kind: "line",
    index: 1,
  });
  expect(next.constraints![3].a.contour).toBe(3);
  expect(d.constraints).toHaveLength(5);
});
it("retains arc radius across two trimmed remnants and keeps them on one circle", async () => {
  const { solveDrawingConstraints } = await import("../drawing-constraints");
  const { sketchArcGeometry } = await import("../arc-geometry");
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [0, 5], end: [-5, 0] }],
      },
      line([2, -1], [2, 6]),
      line([-2, -1], [-2, 6]),
    ],
    constraints: [
      {
        id: "radius",
        kind: "radius",
        a: { contour: 0, kind: "arc", index: 0 },
        value: 5,
      },
    ],
  };
  const next = trimSketchCurve(d, [0, 5], 0.01);
  expect(next.constraints![0].id).toBe("radius");
  next.constraints![0].value = 7;
  const solved = solveDrawingConstraints(next);
  const frames = solved.contours.slice(0, 2).map((c) => {
    if (c.type !== "path" || c.segments[0].type !== "arc") throw Error("arc");
    return sketchArcGeometry(c.start, c.segments[0].middle, c.segments[0].end);
  });
  expect(frames[0].radius).toBeCloseTo(7, 5);
  expect(frames[1].radius).toBeCloseTo(7, 5);
  expect(frames[0].center[0]).toBeCloseTo(frames[1].center[0], 5);
  expect(frames[0].center[1]).toBeCloseTo(frames[1].center[1], 5);
});
it("retains horizontal direction and collinearity across separated line remnants", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      line([-10, 0], [10, 0]),
      line([-3, -5], [-3, 5]),
      line([3, -5], [3, 5]),
    ],
    constraints: [
      {
        id: "horizontal",
        kind: "horizontal",
        a: { contour: 0, kind: "line", index: 0 },
      },
    ],
  };
  const next = trimSketchCurve(d, [0, 0], 0.01);
  expect(next.constraints!.map((c) => c.kind)).toEqual([
    "horizontal",
    "parallel",
    "coincident",
  ]);
});
it("uses finite overlap endpoints when trimming collinear segments", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [line([0, 0], [10, 0]), line([3, 0], [7, 0])],
  };
  const next = trimSketchCurve(d, [5, 0], 0.01);
  expect(next.contours).toHaveLength(3);
  const a = next.contours[0],
    b = next.contours[1];
  if (a.type !== "path" || b.type !== "path") throw Error("paths");
  expect(a.segments[0].end).toEqual([3, 0]);
  expect(b.start).toEqual([7, 0]);
  expect(d.contours).toHaveLength(2);
});
it("uses arc overlap endpoints without inventing midpoint boundaries", () => {
  const at = (a: number): SketchPoint => [5 * Math.cos(a), 5 * Math.sin(a)];
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: at(0),
        segments: [{ type: "arc", middle: at(Math.PI / 2), end: at(Math.PI) }],
      },
      {
        type: "path",
        start: at(Math.PI / 4),
        segments: [
          { type: "arc", middle: at(Math.PI / 2), end: at((3 * Math.PI) / 4) },
        ],
      },
    ],
  };
  const next = trimSketchCurve(d, at(Math.PI / 2), 0.01);
  expect(next.contours).toHaveLength(3);
  const a = next.contours[0],
    b = next.contours[1];
  if (a.type !== "path" || b.type !== "path") throw Error("paths");
  expect(a.segments[0].end[0]).toBeCloseTo(at(Math.PI / 4)[0], 5);
  expect(b.start[0]).toBeCloseTo(at((3 * Math.PI) / 4)[0], 5);
});
it("does not treat synthetic circle half seams as boundaries of duplicate circles", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      { type: "circle", center: [0, 0], radius: 5 },
      { type: "circle", center: [0, 0], radius: 5 },
    ],
  };
  const next = trimSketchCurve(d, [0, 5], 0.01);
  expect(next.contours).toEqual([
    { type: "circle", center: [0, 0], radius: 5 },
  ]);
});
