import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { constraintResiduals } from "./residuals";
import { resolve } from "./entities";
import {
  quadrantSpan,
  quadrantFrame,
  nearestEllipseQuadrant,
} from "./ellipse-contact";
import { constrainSketchEllipse } from "../operations/ellipse-relations";
import { sketchVariantContour } from "../primitives";
const partial = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [5, 0],
      segments: [
        {
          type: "ellipse",
          end: [0, 3],
          radiusX: 5,
          radiusY: 3,
          rotationDegrees: 0,
          largeArc: false,
          sweep: true,
        },
      ],
    },
    { type: "circle", center: [-5, 0], radius: 1 },
  ],
});
it("does not satisfy an elliptical quadrant outside the retained span", () => {
  const d = partial(),
    a = { kind: "point" as const, contour: 1, index: 0 },
    b = { kind: "ellipse" as const, contour: 0, index: 0 };
  const residuals = constraintResiduals(d, {
    id: "quadrant",
    kind: "quadrant",
    a,
    b,
    quadrant: 2,
  });
  expect(Math.max(...residuals.map(Math.abs))).toBeGreaterThan(1);
  const entity = resolve(d, b);
  expect(
    nearestEllipseQuadrant(
      quadrantFrame(entity)!,
      [-5, 0],
      quadrantSpan(entity),
    ),
  ).toBe(1);
  d.contours[1] = { type: "circle", center: [0, 3], radius: 1 };
  expect(
    Math.max(
      ...constraintResiduals(d, {
        id: "quadrant",
        kind: "quadrant",
        a,
        b,
        quadrant: 1,
      }).map(Math.abs),
    ),
  ).toBeLessThan(1e-8);
});
it("keeps all quadrants available for a full constrained ellipse", () => {
  const d = constrainSketchEllipse(
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
  const entity = resolve(d, { kind: "ellipse", contour: 0, index: 0 });
  expect(quadrantSpan(entity)).toBeUndefined();
  d.contours.push({ type: "circle", center: [0, -3], radius: 1 });
  expect(
    Math.max(
      ...constraintResiduals(d, {
        id: "quadrant",
        kind: "quadrant",
        a: { kind: "point", contour: 1, index: 0 },
        b: { kind: "ellipse", contour: 0, index: 0 },
        quadrant: 3,
      }).map(Math.abs),
    ),
  ).toBeLessThan(1e-8);
});
it("checks the span on external ellipse geometry too", () => {
  const d = partial(),
    source = d.contours.shift()!;
  source.id = "source";
  d.projectionContext = [source];
  const residuals = constraintResiduals(d, {
    id: "projected",
    kind: "quadrant",
    a: { kind: "point", contour: 0, index: 0 },
    b: { kind: "ellipse", contour: -1, index: 0, projectedContourId: "source" },
    quadrant: 2,
  });
  expect(Math.max(...residuals.map(Math.abs))).toBeGreaterThan(1);
});
