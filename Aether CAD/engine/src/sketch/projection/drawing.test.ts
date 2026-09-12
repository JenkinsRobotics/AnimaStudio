import { expect, it } from "vitest";
import { projectSketchDrawing } from "./drawing";
import { segmentPoint } from "../curves/parameterization";
import { sketchVariantContour } from "../primitives";
import type { SketchDrawing, SketchFrame, SketchPoint } from "../drawing";
const source: SketchFrame = {
  originMillimeters: [0, 0, 0],
  xDirection: [1, 0, 0],
  normal: [0, 0, 1],
};
const target: SketchFrame = {
  originMillimeters: [3, 4, 5],
  xDirection: [1, 0, 0],
  normal: [0, 0.6, 0.8],
};
const projected = (p: SketchPoint): SketchPoint => [p[0] - 3, 0.8 * p[1] - 0.2];
it("projects lines and Beziers exactly with translated oblique frames", () => {
  const drawing: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          { type: "line", end: [10, 4] },
          {
            type: "bezier",
            controls: [
              [12, 9],
              [20, -2],
            ],
            end: [24, 3],
          },
        ],
        construction: true,
      },
    ],
  };
  const before = structuredClone(drawing),
    d = projectSketchDrawing(drawing, source, target),
    c = d.contours[0];
  if (c.type !== "path") throw Error();
  const input = drawing.contours[0];
  if (input.type !== "path") throw Error();
  let a = input.start,
    b = c.start;
  for (let i = 0; i < c.segments.length; i++) {
    for (const t of [0, 0.17, 0.51, 1]) {
      const p = projected(segmentPoint(a, input.segments[i], t)),
        q = segmentPoint(b, c.segments[i], t);
      expect(q[0]).toBeCloseTo(p[0], 9);
      expect(q[1]).toBeCloseTo(p[1], 9);
    }
    a = input.segments[i].end;
    b = c.segments[i].end;
  }
  expect(c.construction).toBe(true);
  expect(drawing).toEqual(before);
});
it("projects circular and rotated elliptical arcs as exact native ellipses", () => {
  const ellipse = sketchVariantContour("ellipse", [
    [5, 3],
    [9, 7],
    [2, 6],
  ]);
  const arc = {
    type: "path" as const,
    start: [5, 0] as SketchPoint,
    segments: [
      {
        type: "arc" as const,
        middle: [0, 5] as SketchPoint,
        end: [-5, 0] as SketchPoint,
      },
    ],
  };
  for (const contour of [ellipse, arc]) {
    const result = projectSketchDrawing(
      { type: "drawing", contours: [contour] },
      source,
      target,
    ).contours[0];
    if (contour.type !== "path" || result.type !== "path") throw Error();
    let a = contour.start,
      b = result.start;
    for (let i = 0; i < contour.segments.length; i++) {
      expect(result.segments[i].type).toBe("ellipse");
      for (const t of [0.1, 0.4, 0.9]) {
        const p = projected(segmentPoint(a, contour.segments[i], t)),
          q = segmentPoint(b, result.segments[i], t);
        expect(q[0]).toBeCloseTo(p[0], 5);
        expect(q[1]).toBeCloseTo(p[1], 5);
      }
      a = contour.segments[i].end;
      b = result.segments[i].end;
    }
  }
});
it("resolves source constraints and projects full circles without copying invalid dimensions", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [0, 0], radius: 2, hole: true }],
    constraints: [
      { id: "r", kind: "radius", a: { kind: "circle", contour: 0 }, value: 3 },
    ],
  };
  const c = projectSketchDrawing(d, source, target).contours[0];
  if (c.type !== "path" || c.segments[0].type !== "ellipse") throw Error();
  expect(c.segments[0].radiusX).toBeCloseTo(3);
  expect(c.segments[0].radiusY).toBeCloseTo(2.4);
  expect(c.segments.at(-1)!.end).toEqual(c.start);
  expect(c.hole).toBe(true);
  expect(projectSketchDrawing(d, source, target).constraints).toBeUndefined();
  expect(d.contours[0]).toMatchObject({ radius: 2 });
  expect(
    projectSketchDrawing(
      {
        type: "drawing",
        contours: [{ type: "circle", center: [0, 0], radius: 2 }],
      },
      source,
      source,
    ).contours[0].type,
  ).toBe("circle");
});
it("flips arc orientation and projects edge-on arcs as lines", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [0, 5], end: [-5, 0] }],
      },
    ],
  };
  const c = projectSketchDrawing(d, source, { ...source, normal: [0, 0, -1] })
    .contours[0];
  if (c.type !== "path" || c.segments[0].type !== "ellipse") throw Error();
  expect(c.segments[0].sweep).toBe(false);
  const middle = segmentPoint(c.start, c.segments[0], 0.5);
  expect(middle[1]).toBeCloseTo(-5);
  expect(projectSketchDrawing(d, source, { ...source, normal: [0, 1, 0] }).contours[0]).toMatchObject({type:"path",start:[5,0],segments:[{type:"line",end:[-5,0]}]});
  expect(() =>
    projectSketchDrawing(d, source, { ...source, xDirection: [2, 0, 0] }),
  ).toThrow("orthonormal");
});
