import { expect, it } from "vitest";
import { sketchVariantContour } from "../primitives";
import { addSketchEllipseAxis } from "./ellipse-axes";
import { editDrawingDimension } from "./edit-dimension";
import { resolve } from "../solver/entities";
import { constraintResiduals } from "../solver/residuals";
import type { SketchDrawing } from "../drawing";
it("dimensions both radii of a partial arc without duplicating support geometry", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      sketchVariantContour(
        "elliptical-arc",
        [
          [0, 0],
          [5, 0],
          [0, 3],
          [5, 0],
        ],
        6,
        { clockwise: true },
      ),
    ],
  };
  const before = structuredClone(source),
    ref = { contour: 0, kind: "ellipse" as const, index: 0 };
  const x = addSketchEllipseAxis(source, ref, "x"),
    y = addSketchEllipseAxis(x.drawing, ref, "y");
  expect(source).toEqual(before);
  expect(y.drawing.contours).toHaveLength(4);
  expect(y.drawing.contours[1].construction).toBe(true);
  expect(addSketchEllipseAxis(y.drawing, ref, "x").drawing).toEqual(y.drawing);
  expect(addSketchEllipseAxis(y.drawing, ref, "y").drawing).toEqual(y.drawing);
  y.drawing.constraints!.push(
    { id: "width", kind: "length", a: x.axis, value: 10 },
    { id: "height", kind: "length", a: y.axis, value: 6 },
  );
  const reopened = JSON.parse(JSON.stringify(y.drawing));
  const resized = editDrawingDimension(
    editDrawingDimension(reopened, "width", 14),
    "height",
    8,
  );
  const e = resolve(resized, ref).ellipse!;
  expect(e.radiusX).toBeCloseTo(7, 4);
  expect(e.radiusY).toBeCloseTo(4, 4);
  for (const c of resized.constraints!)
    expect(
      constraintResiduals(resized, c).every((r) => Math.abs(r) < 1e-6),
    ).toBe(true);
  expect(reopened).toEqual(y.drawing);
});
