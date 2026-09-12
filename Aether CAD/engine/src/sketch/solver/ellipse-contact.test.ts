import { expect, it } from "vitest";
import {
  ellipseQuadrant,
  nearestEllipseQuadrant,
  pointOnEllipse,
} from "./ellipse-contact";
import { solveDrawingConstraints } from "./solve";
import { constraintResiduals } from "./residuals";
import { constrainSketchEllipse } from "../operations/ellipse-relations";
import { sketchVariantContour } from "../primitives";
const e = {
  center: [2, 3] as [number, number],
  radiusX: 4,
  radiusY: 2,
  rotation: Math.PI / 3,
};
it("finds and retains all four rotated local-axis endpoints", () => {
  for (let i = 0; i < 4; i++) {
    const p = ellipseQuadrant(e, i);
    expect(nearestEllipseQuadrant(e, p)).toBe(i);
    expect(Math.abs(pointOnEllipse(e, p))).toBeLessThan(1e-10);
  }
  expect(() => ellipseQuadrant(e, 4)).toThrow();
  expect(() => ellipseQuadrant(e, NaN)).toThrow();
});
it("solves a point onto an ellipse and a quadrant in either entity order", () => {
  for (const kind of ["coincident", "quadrant"] as const)
    for (const reverse of [false, true]) {
      const d = constrainSketchEllipse(
        {
          type: "drawing",
          contours: [
            sketchVariantContour("ellipse", [
              [0, 0],
              [4, 0],
              [0, 2],
            ]),
            { type: "path", start: [3, 1], segments: [] },
          ],
        },
        0,
      );
      const a = { kind: "point" as const, contour: 1, index: 0 },
        b = { kind: "ellipse" as const, contour: 0, index: 0 };
      d.constraints!.push({
        id: "contact",
        kind,
        a: reverse ? b : a,
        b: reverse ? a : b,
        ...(kind === "quadrant" ? { quadrant: 0 as const } : {}),
      });
      const solved = solveDrawingConstraints(d);
      for (const c of solved.constraints!)
        for (const r of constraintResiduals(solved, c))
          expect(Math.abs(r)).toBeLessThan(1e-6);
    }
});
it("rejects quadrant constraints without a saved endpoint choice", () => {
  const d = constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [0, 0],
          [4, 0],
          [0, 2],
        ]),
        { type: "path", start: [3, 1], segments: [] },
      ],
    },
    0,
  );
  expect(() =>
    constraintResiduals(d, {
      id: "q",
      kind: "quadrant",
      a: { kind: "point", contour: 1, index: 0 },
      b: { kind: "ellipse", contour: 0, index: 0 },
    }),
  ).toThrow("quadrants");
});
