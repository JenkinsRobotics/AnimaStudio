import { expect, it } from "vitest";
import { constrainSketchEllipse } from "../operations/ellipse-relations";
import { addSketchEllipseAxis } from "../operations/ellipse-axes";
import { splitSketchSegment } from "../operations/split";
import { sketchVariantContour } from "../primitives";
import { solveDrawingConstraints } from "./solve";
import { ellipseLocusCoordinates } from "./ellipse-locus-coordinates";
import { constraintResiduals } from "./residuals";
const fixture = () =>
  splitSketchSegment(
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
const ref = { kind: "ellipse" as const, contour: 0, index: 0 };
it("solves sequential diameter edits on linked arcs and preserves source data", () => {
  const x = addSketchEllipseAxis(fixture(), ref, "x");
  x.drawing.constraints!.push({
    id: "width",
    kind: "length",
    a: x.axis,
    value: 14,
  });
  const original = structuredClone(x.drawing);
  const width = solveDrawingConstraints(x.drawing);
  expect(x.drawing).toEqual(original);
  const y = addSketchEllipseAxis(width, ref, "y");
  y.drawing.constraints!.push({
    id: "height",
    kind: "length",
    a: y.axis,
    value: 8,
  });
  const solved = solveDrawingConstraints(y.drawing);
  const path = solved.contours[0];
  if (path.type !== "path") throw Error();
  for (const s of path.segments) {
    expect(s).toMatchObject({ type: "ellipse" });
    if (s.type !== "ellipse") throw Error();
    expect(s.radiusX).toBeCloseTo(7, 5);
    expect(s.radiusY).toBeCloseTo(4, 5);
  }
  for (const c of solved.constraints!)
    expect(
      Math.max(...constraintResiduals(solved, c).map(Math.abs)),
    ).toBeLessThan(1e-7);
  expect(path.segments.at(-1)!.end).toEqual(path.start);
  const conflict = structuredClone(solved);
  conflict.constraints!.push({
    id: "conflict",
    kind: "length",
    a: x.axis,
    value: 12,
  });
  const before = structuredClone(conflict);
  expect(() => solveDrawingConstraints(conflict)).toThrow();
  expect(conflict).toEqual(before);
});
it("does not parameterize fixed or unlinked paths", () => {
  const d = fixture();
  expect(ellipseLocusCoordinates(d, new Set([0])).coordinates).toHaveLength(0);
  d.constraints = [];
  expect(ellipseLocusCoordinates(d).coordinates).toHaveLength(0);
});
