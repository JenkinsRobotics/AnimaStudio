import { expect, it } from "vitest";
import { ellipseSnapPoints, inferEllipseQuadrants } from "./ellipse-snaps";
import { constrainSketchEllipse } from "./ellipse-relations";
import { sketchVariantContour } from "../primitives";
import { constraintResiduals } from "../solver/residuals";
const source = () =>
  constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [0, 0],
          [4, 0],
          [0, 2],
        ]),
      ],
    },
    0,
  );
it("offers four exact endpoints once for a full ellipse and clips trimmed arcs", () => {
  expect(ellipseSnapPoints(source()).map((s) => s.point)).toHaveLength(4);
  const snaps = ellipseSnapPoints({
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [4, 0],
        segments: [
          {
            type: "ellipse",
            end: [0, 2],
            radiusX: 4,
            radiusY: 2,
            rotationDegrees: 0,
            largeArc: false,
            sweep: true,
          },
        ],
      },
    ],
  });
  expect(snaps.map((s) => s.quadrant)).toEqual([0, 1]);
});
it("adds a saved relation only for new points at quadrant snaps", () => {
  const before = source(),
    after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: [0, 2],
    segments: [{ type: "line", end: [8, 8] }],
  });
  const next = inferEllipseQuadrants(before, after),
    c = next.constraints!.at(-1)!;
  expect(c).toMatchObject({
    kind: "quadrant",
    quadrant: 1,
    a: { contour: 1, index: 0 },
    b: { contour: 0, kind: "ellipse" },
  });
  expect(constraintResiduals(next, c).every((r) => Math.abs(r) < 1e-7)).toBe(
    true,
  );
  expect(after.constraints).toHaveLength(1);
  expect(inferEllipseQuadrants(next, next).constraints).toHaveLength(2);
});
