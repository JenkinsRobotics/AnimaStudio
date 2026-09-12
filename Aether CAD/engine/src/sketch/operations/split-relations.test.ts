import { constraintResiduals } from "../solver/residuals";
import { it, expect } from "vitest";
import { splitSketchSegment } from "./split";
import { solveDrawingConstraints } from "../drawing-constraints";
import { sketchArcGeometry } from "../arc-geometry";
import type { SketchDrawing } from "../drawing";
it("keeps split arcs concentric and equal after editing their retained radius dimension", () => {
  const drawing: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [3, 4], end: [0, 5] }],
      },
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
  const split = splitSketchSegment(drawing, [3, 4], 0.1);
  expect(split.constraints?.find((c) => c.id === "radius")).toEqual(
    drawing.constraints![0],
  );
  split.constraints![0].value = 8;
  const solved = solveDrawingConstraints(split);
  const c = solved.contours[0];
  if (
    c.type !== "path" ||
    c.segments[0].type !== "arc" ||
    c.segments[1].type !== "arc"
  )
    throw Error("arcs");
  const a = sketchArcGeometry(c.start, c.segments[0].middle, c.segments[0].end),
    b = sketchArcGeometry(
      c.segments[0].end,
      c.segments[1].middle,
      c.segments[1].end,
    );
  expect(a.radius).toBeCloseTo(8, 5);
  expect(b.radius).toBeCloseTo(8, 5);
  expect(a.center[0]).toBeCloseTo(b.center[0], 5);
  expect(a.center[1]).toBeCloseTo(b.center[1], 5);
  expect(drawing.constraints![0].value).toBe(5);
});
it("retains surviving endpoint references together with original arc midpoint semantics", () => {
  const drawing: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [3, 4], end: [0, 5] }],
      },
    ],
    constraints: [
      {
        id: "end",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 1 },
        point: [0, 5],
      },
    ],
  };
  expect(splitSketchSegment(drawing, [3, 4], 0.1).constraints![0].a.index).toBe(
    2,
  );
  drawing.contours.push({
    type: "path",
    start: [Math.SQRT1_2 * 5, Math.SQRT1_2 * 5],
    segments: [],
  });
  drawing.constraints!.push({
    id: "mid",
    kind: "midpoint",
    a: { contour: 0, kind: "arc", index: 0 },
    b: { contour: 1, kind: "point", index: 0 },
  });
  const split = splitSketchSegment(drawing, [3, 4], 0.1);
  expect(split.constraints![0].a.index).toBe(2);
  expect(split.constraints!.find((c) => c.id === "mid")!.a).toEqual({
    contour: 2,
    kind: "arc",
    index: 0,
  });
  for (const c of split.constraints!)
    expect(constraintResiduals(split, c).every((r) => Math.abs(r) < 1e-6)).toBe(
      true,
    );
});
it("preserves overall line length and direction through split and dimension edits", () => {
  const drawing: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
    ],
    constraints: [
      {
        id: "length",
        kind: "length",
        a: { contour: 0, kind: "line", index: 0 },
        value: 10,
      },
      {
        id: "horizontal",
        kind: "horizontal",
        a: { contour: 0, kind: "line", index: 0 },
      },
      {
        id: "origin",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [0, 0],
      },
    ],
  };
  const split = splitSketchSegment(drawing, [4, 0], 0.1);
  expect(split.constraints![0]).toMatchObject({
    id: "length",
    kind: "distance",
    value: 10,
    a: { kind: "point", index: 0 },
    b: { kind: "point", index: 2 },
  });
  split.constraints![0].value = 20;
  const solved = solveDrawingConstraints(split);
  const c = solved.contours[0];
  if (c.type !== "path") throw Error("path");
  expect(c.segments[1].end[0]).toBeCloseTo(20, 5);
  expect(c.segments[0].end[1]).toBeCloseTo(0, 5);
  expect(c.segments[1].end[1]).toBeCloseTo(0, 5);
  expect(drawing.constraints![0].kind).toBe("length");
});
