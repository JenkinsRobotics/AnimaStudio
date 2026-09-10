import { expect, it } from "vitest";
import { circularQuadrantSnaps } from "./circular-quadrants";
import { inferEllipseQuadrants } from "./ellipse-snaps";
import { solveDrawingConstraints } from "../solver/solve";
import { constraintResiduals } from "../solver/residuals";
import { nearestEllipseQuadrant } from "../solver/ellipse-contact";
import type { SketchDrawing } from "../drawing";
it("clips quadrant candidates to both clockwise and counterclockwise arcs", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [0, 5], end: [-5, 0] }],
      },
    ],
  };
  expect(circularQuadrantSnaps(d).map((s) => s.quadrant)).toEqual([0, 1, 2]);
  const path = d.contours[0];
  if (path.type !== "path" || path.segments[0].type !== "arc") throw Error();
  path.segments[0].middle = [0, -5];
  expect(circularQuadrantSnaps(d).map((s) => s.quadrant)).toEqual([0, 2, 3]);
});
it("retains a local circle quadrant without adding duplicate attachments", () => {
  const before: SketchDrawing = {
      type: "drawing",
      contours: [{ type: "circle", center: [0, 0], radius: 5 }],
    },
    after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: [0, 5],
    segments: [{ type: "line", end: [0, 10] }],
  });
  const linked = inferEllipseQuadrants(before, after);
  expect(linked.constraints![0]).toMatchObject({
    kind: "quadrant",
    quadrant: 1,
    b: { kind: "circle" },
  });
  expect(inferEllipseQuadrants(before, linked).constraints).toHaveLength(1);
  expect(() => solveDrawingConstraints(linked)).not.toThrow();
});
it("detects a quadrant outside an arc even when the point is on its supporting circle", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [0, 5], end: [-5, 0] }],
      },
      { type: "circle", center: [0, -5], radius: 1 },
    ],
  };
  const r = constraintResiduals(d, {
    id: "outside",
    kind: "quadrant",
    a: { kind: "point", contour: 1, index: 0 },
    b: { kind: "arc", contour: 0, index: 0 },
    quadrant: 3,
  });
  expect(Math.max(...r.map(Math.abs))).toBeGreaterThan(1);
  expect(() =>
    nearestEllipseQuadrant(
      { center: [0, 0], radiusX: 5, radiusY: 5, rotation: 0 },
      [5, 1],
      { startAngle: 0.1, sweep: 0.1 },
    ),
  ).toThrow(/no axis quadrant/);
});
