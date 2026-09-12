import { expect, it } from "vitest";
import type { SketchDrawing, SketchContour } from "../drawing";
import { ellipsePoint } from "../curves/parameterization";
import { constraintResiduals } from "./residuals";
import { solveDrawingConstraints } from "./solve";
import { sketchEntities } from "./entities";
const ellipse = (
  cx: number,
  cy: number,
  rx: number,
  ry: number,
  angle: number,
  start: number,
  sweep: number,
): SketchContour => {
  const f = {
    center: [cx, cy] as [number, number],
    radiusX: rx,
    radiusY: ry,
    rotation: angle,
    startAngle: start,
    sweep,
  };
  return {
    type: "path",
    start: ellipsePoint(f, 0),
    segments: [
      {
        type: "ellipse",
        end: ellipsePoint(f, 1),
        radiusX: rx,
        radiusY: ry,
        rotationDegrees: (angle * 180) / Math.PI,
        largeArc: Math.abs(sweep) > Math.PI,
        sweep: sweep > 0,
      },
    ],
  };
};
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, -10],
      segments: [{ type: "line", end: [0, 10] }],
    },
    ellipse(-6, 2, 4, 2, 0.3, 0.2, 1.5),
    ellipse(6, 2, 4, 2, Math.PI - 0.3, 1, 1.2),
  ],
  constraints: [
    {
      id: "sym",
      kind: "symmetric",
      a: { kind: "ellipse", contour: 1, index: 0 },
      b: { kind: "ellipse", contour: 2, index: 0 },
      axis: { kind: "line", contour: 0, index: 0 },
    },
  ],
});
it("reflects ellipse centers and quadratic shape independently of trimmed endpoints", () => {
  const d = drawing();
  expect(
    constraintResiduals(d, d.constraints![0]).every((r) => Math.abs(r) < 1e-10),
  ).toBe(true);
  expect(
    sketchEntities(d).filter((e) => e.ref.kind === "ellipse"),
  ).toHaveLength(2);
});
it("solves unequal radii and orientation with positive ellipse coordinates", () => {
  const d = drawing();
  d.contours[2] = ellipse(6.2, 2.1, 4.5, 2.3, Math.PI - 0.2, 1, 1.2);
  const before = structuredClone(d),
    solved = solveDrawingConstraints(d);
  for (const r of constraintResiduals(solved, solved.constraints![0]))
    expect(Math.abs(r)).toBeLessThan(1e-6);
  for (const c of solved.contours)
    if (c.type === "path")
      for (const s of c.segments)
        if (s.type === "ellipse") {
          expect(s.radiusX).toBeGreaterThan(0);
          expect(s.radiusY).toBeGreaterThan(0);
        }
  expect(d).toEqual(before);
});
it("accepts swapped principal radii and half-turn equivalent orientations", () => {
  const d = drawing();
  d.contours[2] = ellipse(6, 2, 2, 4, Math.PI - 0.3 + Math.PI / 2, 1, 1.2);
  expect(
    constraintResiduals(d, d.constraints![0]).every((r) => Math.abs(r) < 1e-10),
  ).toBe(true);
});
