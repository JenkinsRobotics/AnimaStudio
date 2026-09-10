import { expect, it } from "vitest";
import { constrainSketchEllipse } from "../operations/ellipse-relations";
import { splitSketchSegment } from "../operations/split";
import { sketchVariantContour } from "../primitives";
import { addSketchEllipseAxis } from "../operations/ellipse-axes";
import { solveDrawingConstraints } from "./solve";
import { sketchConstraintState } from "./diagnostics";
it("counts the five conic freedoms and three split vertex positions", () => {
  const d = splitSketchSegment(
    constrainSketchEllipse(
      {
        type: "drawing",
        contours: [
          sketchVariantContour("ellipse", [
            [0, 0],
            [5, 0],
            [0, 3],
          ]),
        ],
      },
      0,
    ),
    [3, 2.4],
    0.1,
  );
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 8,
  });
  const x = addSketchEllipseAxis(
    d,
    { kind: "ellipse", contour: 0, index: 0 },
    "x",
  );
  x.drawing.constraints!.push({
    id: "width",
    kind: "length",
    a: x.axis,
    value: 14,
  });
  const width = solveDrawingConstraints(x.drawing);
  expect(sketchConstraintState(width)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 7,
  });
  const y = addSketchEllipseAxis(
    width,
    { kind: "ellipse", contour: 0, index: 0 },
    "y",
  );
  y.drawing.constraints!.push({
    id: "height",
    kind: "length",
    a: y.axis,
    value: 8,
  });
  const both = solveDrawingConstraints(y.drawing);
  expect(sketchConstraintState(both)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 6,
  });
  expect(sketchConstraintState(both, x.axis)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 3,
  });
  const duplicate = structuredClone(d);
  duplicate.constraints!.push({
    ...duplicate.constraints![0],
    id: "duplicate",
  });
  expect(sketchConstraintState(duplicate)).toMatchObject({
    state: "over-constrained",
    degreesOfFreedom: 8,
    redundantEquations: 5,
  });
});
