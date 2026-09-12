import { expect, it } from "vitest";
import { extendSketchCurve } from "./extend-curves";
import { ExtensionNeedsEndpoint } from "./trim-extend";
import { sketchArcGeometry } from "../arc-geometry";
import { ellipseFrame } from "../curves/parameterization";
import type { SketchDrawing } from "../drawing";
const quarter = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [5, 0],
      segments: [
        {
          type: "arc",
          middle: [Math.SQRT1_2 * 5, Math.SQRT1_2 * 5],
          end: [0, 5],
        },
      ],
    },
  ],
});
it("extends an arc to the nearest finite boundary while preserving radius", () => {
  const drawing = quarter();
  drawing.contours.push({
    type: "path",
    start: [-3, -10],
    segments: [{ type: "line", end: [-3, 10] }],
  });
  const before = JSON.stringify(drawing);
  const result = extendSketchCurve(drawing, [0, 5], 0.2);
  const c = result.contours[0];
  if (c.type !== "path" || c.segments[0].type !== "arc") throw Error("arc");
  expect(c.segments[0].end[0]).toBeCloseTo(-3);
  expect(c.segments[0].end[1]).toBeCloseTo(4);
  expect(
    sketchArcGeometry(c.start, c.segments[0].middle, c.segments[0].end).radius,
  ).toBeCloseTo(5);
  expect(JSON.stringify(drawing)).toBe(before);
});
it("extends either free end by a second point and rejects points inside the existing arc", () => {
  expect(() => extendSketchCurve(quarter(), [0, 5], 0.2)).toThrow(
    ExtensionNeedsEndpoint,
  );
  const result = extendSketchCurve(quarter(), [5, 0], 0.2, [0, -10]);
  const c = result.contours[0];
  if (c.type !== "path") throw Error("path");
  expect(c.start[0]).toBeCloseTo(0);
  expect(c.start[1]).toBeCloseTo(-5);
  expect(() => extendSketchCurve(quarter(), [0, 5], 0.2, [4, 4])).toThrow(
    "beyond",
  );
});
it("extends an ellipse on its original axes, including crossing a half revolution", () => {
  const drawing: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [10, 0],
        segments: [
          {
            type: "ellipse",
            end: [0, 3],
            radiusX: 10,
            radiusY: 3,
            rotationDegrees: 0,
            largeArc: false,
            sweep: true,
          },
        ],
      },
    ],
  };
  const result = extendSketchCurve(drawing, [0, 3], 0.2, [-10, -3]);
  const c = result.contours[0];
  if (c.type !== "path" || c.segments[0].type !== "ellipse")
    throw Error("ellipse");
  const frame = ellipseFrame(c.start, c.segments[0]);
  expect(frame.radiusX).toBeCloseTo(10);
  expect(frame.radiusY).toBeCloseTo(3);
  expect(frame.center[0]).toBeCloseTo(0);
  expect(frame.center[1]).toBeCloseTo(0);
  expect(c.segments[0].largeArc).toBe(true);
});
it("preserves clockwise orientation and radius constraints", () => {
  const drawing: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [3, -4], end: [0, -5] }],
      },
    ],
  };
  const result = extendSketchCurve(drawing, [0, -5], 0.2, [-5, 0]);
  const c = result.contours[0];
  if (c.type !== "path" || c.segments[0].type !== "arc") throw Error("arc");
  expect(
    sketchArcGeometry(c.start, c.segments[0].middle, c.segments[0].end).sweep,
  ).toBeCloseTo(-Math.PI);
  drawing.constraints = [
    {
      id: "radius",
      kind: "radius",
      a: { contour: 0, kind: "arc", index: 0 },
      value: 5,
    },
  ];
  const before = JSON.stringify(drawing);
  expect(extendSketchCurve(drawing, [0, -5], 0.2, [-5, 0]).constraints).toEqual(
    drawing.constraints,
  );
  expect(JSON.stringify(drawing)).toBe(before);
});
it("keeps horizontal and fixed-start line constraints, and rejects a fixed moved end", () => {
  const drawing: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
    ],
    constraints: [
      {
        id: "horizontal",
        kind: "horizontal",
        a: { contour: 0, kind: "line", index: 0 },
      },
      {
        id: "fixed-start",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [0, 0],
      },
    ],
  };
  const result = extendSketchCurve(drawing, [5, 0], 0.1, [10, 0]);
  expect(result.constraints).toEqual(drawing.constraints);
  drawing.constraints!.push({
    id: "fixed-end",
    kind: "fix",
    a: { contour: 0, kind: "point", index: 1 },
    point: [5, 0],
  });
  const before = JSON.stringify(drawing);
  expect(() => extendSketchCurve(drawing, [5, 0], 0.1, [10, 0])).toThrow(
    "fixed-end",
  );
  expect(JSON.stringify(drawing)).toBe(before);
});
