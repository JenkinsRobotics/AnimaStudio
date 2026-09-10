import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { constraintResiduals } from "./residuals";
import { solveDrawingConstraints } from "./solve";
import { deleteSketchContour } from "../operations/delete";
import { splitSketchSegment } from "../operations/split";
const base = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, -10],
      segments: [{ type: "line", end: [0, 10] }],
      construction: true,
    },
    { type: "path", start: [-3, 4], segments: [] },
    { type: "path", start: [2, 2], segments: [] },
  ],
  constraints: [
    {
      id: "sym",
      kind: "symmetric",
      a: { kind: "point", contour: 1, index: 0 },
      b: { kind: "point", contour: 2, index: 0 },
      axis: { kind: "line", contour: 0, index: 0 },
    },
    {
      id: "axis0",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [0, -10],
    },
    {
      id: "axis1",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 1 },
      point: [0, 10],
    },
    {
      id: "point",
      kind: "fix",
      a: { kind: "point", contour: 1, index: 0 },
      point: [-3, 4],
    },
  ],
});
it("solves reflected points about a fixed live axis without mutating source", () => {
  const d = base(),
    before = structuredClone(d),
    solved = solveDrawingConstraints(d);
  const c = solved.contours[2];
  if (c.type !== "path") throw Error();
  expect(c.start[0]).toBeCloseTo(3, 5);
  expect(c.start[1]).toBeCloseTo(4, 5);
  expect(d).toEqual(before);
  solved.constraints![1].point = [-10, -10];
  solved.constraints![2].point = [10, 10];
  const rotated = solveDrawingConstraints(solved),
    p = rotated.contours[2];
  if (p.type !== "path") throw Error();
  expect(p.start[0]).toBeCloseTo(4, 5);
  expect(p.start[1]).toBeCloseTo(-3, 5);
});
it("constrains circular and line loci without forcing endpoint correspondence", () => {
  const d = base();
  d.contours[1] = { type: "circle", center: [-3, 4], radius: 2 };
  d.contours[2] = { type: "circle", center: [3, 4], radius: 2 };
  const c = d.constraints![0];
  c.a = { kind: "circle", contour: 1 };
  c.b = { kind: "circle", contour: 2 };
  expect(constraintResiduals(d, c)).toEqual([0, 0, 0]);
  d.contours[1] = {
    type: "path",
    start: [-3, 0],
    segments: [{ type: "line", end: [-3, 5] }],
  };
  d.contours[2] = {
    type: "path",
    start: [3, 8],
    segments: [{ type: "line", end: [3, 20] }],
  };
  c.a = { kind: "line", contour: 1, index: 0 };
  c.b = { kind: "line", contour: 2, index: 0 };
  expect(constraintResiduals(d, c).every((r) => Math.abs(r) < 1e-10)).toBe(
    true,
  );
});
it("removes symmetry when its axis is deleted and remaps shifted axis indices", () => {
  const d = base();
  expect(
    deleteSketchContour(d, 0).constraints?.some((c) => c.kind === "symmetric"),
  ).toBe(false);
  d.contours.unshift({ type: "path", start: [99, 99], segments: [] });
  for (const c of d.constraints!)
    for (const r of [c.a, c.b, c.axis]) if (r) r.contour++;
  expect(deleteSketchContour(d, 0).constraints![0].axis).toEqual({
    kind: "line",
    contour: 0,
    index: 0,
  });
});
it("rejects missing and degenerate axes", () => {
  const d = base(),
    c = d.constraints![0];
  delete c.axis;
  expect(() => constraintResiduals(d, c)).toThrow("axis");
  c.axis = { kind: "line", contour: 0, index: 0 };
  if (d.contours[0].type !== "path") throw Error();
  d.contours[0].segments[0].end = [0, -10];
  expect(() => constraintResiduals(d, c)).toThrow("nonzero");
});
it("keeps a symmetry axis attached to its supporting line after splitting", () => {
  const d = solveDrawingConstraints(base()),
    next = splitSketchSegment(d, [0, 0], 0.01);
  expect(next.constraints?.find((c) => c.id === "sym")?.axis).toEqual({
    kind: "line",
    contour: 0,
    index: 0,
  });
  for (const c of next.constraints!)
    for (const r of constraintResiduals(next, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("mirrors arc supporting circles while leaving their angular extents independent", () => {
  const d = base(),
    c = d.constraints![0];
  d.contours[1] = {
    type: "path",
    start: [-1, 4],
    segments: [{ type: "arc", middle: [-3, 6], end: [-5, 4] }],
  };
  d.contours[2] = {
    type: "path",
    start: [3, 6],
    segments: [{ type: "arc", middle: [5, 4], end: [3, 2] }],
  };
  c.a = { kind: "arc", contour: 1, index: 0 };
  c.b = { kind: "arc", contour: 2, index: 0 };
  expect(constraintResiduals(d, c).every((r) => Math.abs(r) < 1e-10)).toBe(
    true,
  );
});
