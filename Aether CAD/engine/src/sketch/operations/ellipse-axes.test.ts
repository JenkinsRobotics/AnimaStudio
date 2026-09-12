import { expect, it } from "vitest";
import { addSketchEllipseAxis } from "./ellipse-axes";
import { constrainSketchEllipse } from "./ellipse-relations";
import { sketchVariantContour } from "../primitives";
import { solveDrawingConstraints } from "../solver/solve";
import { resolve } from "../solver/entities";
import { validateSketchDrawing } from "../drawing";
const ref = { kind: "ellipse" as const, contour: 0, index: 0 };
const fixture = () =>
  constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [0, 0],
          [5, 0],
          [0, 2],
        ]),
      ],
    },
    0,
  );
it("dimensions both ellipse axes using persistent construction lines", () => {
  const x = addSketchEllipseAxis(fixture(), ref, "x"),
    y = addSketchEllipseAxis(x.drawing, ref, "y");
  expect(addSketchEllipseAxis(y.drawing, ref, "x").drawing).toEqual(y.drawing);
  const d = JSON.parse(JSON.stringify(y.drawing));
  d.constraints.push(
    { id: "x-size", kind: "length", a: x.axis, value: 14 },
    { id: "y-size", kind: "length", a: y.axis, value: 6 },
  );
  const solved = solveDrawingConstraints(d),
    ellipse = resolve(solved, ref).ellipse!;
  expect(ellipse.radiusX).toBeCloseTo(7);
  expect(ellipse.radiusY).toBeCloseTo(3);
  validateSketchDrawing(solved);
  expect(x.drawing.contours).toHaveLength(2);
});
it("rejects invalid axis selections without altering source and keeps rotated axes on the ellipse", () => {
  const source = constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [4, 3],
          [7, 7],
          [2, 4.5],
        ]),
      ],
    },
    0,
  );
  const next = addSketchEllipseAxis(source, ref, "y");
  expect(next.drawing.contours[1]).toMatchObject({ construction: true });
  validateSketchDrawing(next.drawing);
  expect(() =>
    addSketchEllipseAxis(source, { kind: "line", contour: 0, index: 0 }, "x"),
  ).toThrow(/ellipse/);
  expect(source.contours).toHaveLength(1);
});
