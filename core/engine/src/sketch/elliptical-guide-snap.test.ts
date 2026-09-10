import { expect, it } from "vitest";
import { snapEllipticalArcGuide } from "./elliptical-guide-snap";
import { sketchVariantContour } from "./primitives";
import { constrainEllipseEndpointQuadrants } from "./operations/ellipse-endpoint-quadrants";
import { setSketchEllipseDiameter } from "./operations/set-ellipse-diameter";
import { constraintResiduals } from "./solver/residuals";
import type { SketchDrawing } from "./drawing";
it("snaps fixed and rotated guide quadrants within tolerance only", () => {
  expect(
    snapEllipticalArcGuide(
      [
        [0, 0],
        [5, 0],
        [0, 3],
      ],
      [5.02, 0.01],
      0.1,
    )?.quadrant,
  ).toBe(0);
  expect(
    snapEllipticalArcGuide(
      [
        [0, 0],
        [5, 0],
        [0, 3],
      ],
      [5.2, 0.1],
      0.1,
    ),
  ).toBeUndefined();
  const rotated = snapEllipticalArcGuide(
    [
      [10, 20],
      [10, 25],
      [7, 20],
    ],
    [10.01, 25.02],
    0.1,
  );
  expect(rotated?.point[0]).toBeCloseTo(10);
  expect(rotated?.point[1]).toBeCloseTo(25);
  expect(
    snapEllipticalArcGuide(
      [
        [0, 0],
        [5, 0],
      ],
      [5.02, 0.01],
      0.1,
      { rememberedRadiusMillimeters: 3 },
    )?.quadrant,
  ).toBe(0);
});
it("keeps inferred endpoint quadrants when diameter changes and does not duplicate them", () => {
  const d: SketchDrawing = {
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
  constrainEllipseEndpointQuadrants(d, 0);
  constrainEllipseEndpointQuadrants(d, 0);
  expect(d.constraints).toHaveLength(2);
  const edited = setSketchEllipseDiameter(
    d,
    { contour: 0, kind: "ellipse", index: 0 },
    "x",
    14,
  );
  for (const c of edited.constraints!)
    expect(
      constraintResiduals(edited, c).every((r) => Math.abs(r) < 1e-6),
    ).toBe(true);
});
