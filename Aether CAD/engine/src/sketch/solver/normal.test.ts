import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { solveDrawingConstraints } from "./solve";
import { constraintResiduals } from "./residuals";
function fixture(): SketchDrawing {
  return {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, -10],
        segments: [{ type: "line", end: [0, 10] }],
      },
      { type: "circle", center: [3, 2], radius: 5 },
    ],
    constraints: [
      {
        id: "a",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 0 },
        point: [0, -10],
      },
      {
        id: "b",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 1 },
        point: [0, 10],
      },
      {
        id: "n",
        kind: "normal",
        a: { kind: "line", contour: 0, index: 0 },
        b: { kind: "circle", contour: 1 },
      },
    ],
  };
}
it.each([false, true])(
  "solves line/circle normal with either selection order (%s)",
  (reverse) => {
    const source = fixture(),
      c = source.constraints![2];
    if (reverse) [c.a, c.b] = [c.b!, c.a];
    const before = structuredClone(source),
      solved = solveDrawingConstraints(source);
    expect(solved.contours[1]).toMatchObject({
      center: [expect.closeTo(0, 6), expect.closeTo(2, 6)],
      radius: 5,
    });
    expect(source).toEqual(before);
  },
);
it("solves incidence and perpendicular tangent at a finite cubic contact", () => {
  const source = fixture();
  source.contours[1] = {
    type: "path",
    start: [3, 2],
    segments: [
      {
        type: "bezier",
        controls: [
          [6, 4],
          [8, 8],
        ],
        end: [10, 10],
      },
    ],
  };
  source.constraints![2].b = {
    kind: "curve",
    contour: 1,
    index: 0,
    parameter: 0,
  };
  const solved = solveDrawingConstraints(source);
  for (const c of solved.constraints!)
    for (const r of constraintResiduals(solved, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  const p = solved.contours[1];
  if (p.type !== "path" || p.segments[0].type !== "bezier") throw Error();
  expect(p.start[0]).toBeCloseTo(0, 5);
  expect(p.start[1]).toBeCloseTo(p.segments[0].controls[0][1], 5);
});
it("rejects a fixed non-normal circle without mutating it", () => {
  const source = fixture();
  source.constraints!.push({
    id: "center",
    kind: "fix",
    a: { kind: "point", contour: 1, index: 0 },
    point: [3, 2],
  });
  const before = structuredClone(source);
  expect(() => solveDrawingConstraints(source)).toThrow();
  expect(source).toEqual(before);
});
it("rejects incompatible geometry and zero-length lines", () => {
  const source = fixture();
  const c = source.constraints![2];
  c.b = { kind: "point", contour: 1, index: 0 };
  expect(() => constraintResiduals(source, c)).toThrow("Normal requires");
  c.b = { kind: "circle", contour: 1 };
  source.contours[0] = {
    type: "path",
    start: [0, 0],
    segments: [{ type: "line", end: [0, 0] }],
  };
  expect(() => constraintResiduals(source, c)).toThrow("zero-length");
});
