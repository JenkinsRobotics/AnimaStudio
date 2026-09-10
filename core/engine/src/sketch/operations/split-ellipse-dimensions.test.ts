import { expect, it } from "vitest";
import { addSketchEllipseAxis } from "./ellipse-axes";
import { constrainSketchEllipse } from "./ellipse-relations";
import { splitSketchSegment } from "./split";
import { sketchVariantContour } from "../primitives";
import { solveDrawingConstraints } from "../solver/solve";
import { resolve } from "../solver/entities";
import { constraintResiduals } from "../solver/residuals";

it("retains editable axis dimensions after splitting and reopening a full ellipse", () => {
  const ref = { kind: "ellipse" as const, contour: 0, index: 0 };
  const source = constrainSketchEllipse(
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
  );
  const x = addSketchEllipseAxis(source, ref, "x");
  const y = addSketchEllipseAxis(x.drawing, ref, "y");
  y.drawing.constraints!.push(
    { id: "width", kind: "length", a: x.axis, value: 10 },
    { id: "height", kind: "length", a: y.axis, value: 6 },
  );
  const before = structuredClone(y.drawing);
  const split = splitSketchSegment(y.drawing, [3, 2.4], 0.1);
  expect(y.drawing).toEqual(before);
  expect(addSketchEllipseAxis(split, ref, "x").drawing).toEqual(split);
  expect(addSketchEllipseAxis(split, ref, "y").drawing).toEqual(split);
  const reopened = JSON.parse(JSON.stringify(split));
  reopened.constraints.find((c: { id: string }) => c.id === "width").value = 14;
  reopened.constraints.find((c: { id: string }) => c.id === "height").value = 8;
  const solved = solveDrawingConstraints(reopened);
  for (let index = 0; index < 3; index++) {
    const ellipse = resolve(solved, { ...ref, index }).ellipse!;
    expect(ellipse.radiusX).toBeCloseTo(7, 4);
    expect(ellipse.radiusY).toBeCloseTo(4, 4);
  }
  for (const c of solved.constraints!)
    expect(
      Math.max(...constraintResiduals(solved, c).map(Math.abs)),
    ).toBeLessThan(1e-5);
});

it("creates diameter constraints across linked split arcs and supplies absent endpoints", () => {
  const ref = { kind: "ellipse" as const, contour: 0, index: 0 };
  const source = constrainSketchEllipse(
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
  );
  const split = splitSketchSegment(source, [3, 2.4], 0.1);
  const x = addSketchEllipseAxis(split, ref, "x");
  const y = addSketchEllipseAxis(x.drawing, ref, "y");
  for (const c of y.drawing.constraints!)
    expect(
      Math.max(...constraintResiduals(y.drawing, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
  const isolated = structuredClone(split);
  const path = isolated.contours[0];
  if (path.type !== "path") throw Error();
  path.segments = [path.segments[0]];
  isolated.constraints = [];
  const before = structuredClone(isolated);
  const extended = addSketchEllipseAxis(isolated, ref, "x");
  expect(extended.drawing.contours.length).toBe(isolated.contours.length + 2);
  for (const c of extended.drawing.constraints!)
    expect(
      Math.max(...constraintResiduals(extended.drawing, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
  expect(isolated).toEqual(before);
});
