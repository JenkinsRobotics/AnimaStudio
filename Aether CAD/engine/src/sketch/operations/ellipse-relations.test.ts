import { expect, it } from "vitest";
import { constrainSketchEllipse } from "./ellipse-relations";
import { sketchVariantContour } from "../primitives";
import { solveDrawingConstraints } from "../solver/solve";
import { constraintResiduals } from "../solver/residuals";
import { sketchConstraintState } from "../solver/diagnostics";
import { ellipseFrame } from "../curves/parameterization";
import type { SketchDrawing } from "../drawing";
it("retains five geometric freedoms for a full ellipse and avoids duplicate relations", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      sketchVariantContour("ellipse", [
        [0, 0],
        [4, 0],
        [0, 2],
      ]),
    ],
  };
  const d = constrainSketchEllipse(source, 0);
  expect(source.constraints).toBeUndefined();
  expect(constrainSketchEllipse(d, 0).constraints).toHaveLength(1);
  expect(sketchConstraintState(d)).toMatchObject({ degreesOfFreedom: 5 });
});
it("keeps both halves together when full ellipses solve for symmetry", () => {
  let d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, -10],
        segments: [{ type: "line", end: [0, 10] }],
      },
      sketchVariantContour("ellipse", [
        [-6, 0],
        [-2, 0],
        [-6, 2],
      ]),
      sketchVariantContour("ellipse", [
        [7, 1],
        [12, 1],
        [7, 3.5],
      ]),
    ],
  };
  d = constrainSketchEllipse(constrainSketchEllipse(d, 1), 2);
  d.constraints!.push({
    id: "sym",
    kind: "symmetric",
    a: { kind: "ellipse", contour: 1, index: 0 },
    b: { kind: "ellipse", contour: 2, index: 0 },
    axis: { kind: "line", contour: 0, index: 0 },
  });
  const solved = solveDrawingConstraints(d);
  for (const c of solved.constraints!)
    for (const r of constraintResiduals(solved, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  for (const path of solved.contours.slice(1)) {
    if (
      path.type !== "path" ||
      path.segments[0].type !== "ellipse" ||
      path.segments[1].type !== "ellipse"
    )
      throw Error();
    const [a, b] = path.segments;
    expect(a.radiusX).toBeCloseTo(b.radiusX, 5);
    expect(a.radiusY).toBeCloseTo(b.radiusY, 5);
    const first = ellipseFrame(path.start, a),
      second = ellipseFrame(a.end, b);
    expect(
      Math.hypot(
        first.center[0] - second.center[0],
        first.center[1] - second.center[1],
      ),
    ).toBeLessThan(0.001);
  }
});
