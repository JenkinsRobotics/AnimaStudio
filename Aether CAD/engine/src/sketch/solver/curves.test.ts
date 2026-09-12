import { expect, it } from "vitest";
import { solveDrawingConstraints } from "./solve";
import { constraintResiduals } from "./residuals";
import { sketchEntities } from "./entities";
import type { SketchDrawing } from "../drawing";
const solve = (drawing: SketchDrawing) => {
  const result = solveDrawingConstraints(drawing);
  for (const c of result.constraints ?? [])
    expect(
      Math.max(...constraintResiduals(result, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
  return result;
};
it("solves arc radius and point-at-arc-midpoint", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [3, 4], end: [0, 5] }],
      },
      { type: "path", start: [2, 2], segments: [] },
    ],
    constraints: [
      {
        id: "r",
        kind: "radius",
        a: { contour: 0, kind: "arc", index: 0 },
        value: 8,
      },
      {
        id: "m",
        kind: "midpoint",
        a: { contour: 0, kind: "arc", index: 0 },
        b: { contour: 1, kind: "point", index: 0 },
      },
    ],
  };
  expect(sketchEntities(d).some((e) => e.ref.kind === "arc")).toBe(true);
  solve(d);
});
it("solves concentric arc and circle with equal radius", () => {
  solve({
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [{ type: "arc", middle: [3, 4], end: [0, 5] }],
      },
      { type: "circle", center: [1, 1], radius: 4 },
    ],
    constraints: [
      {
        id: "c",
        kind: "concentric",
        a: { contour: 0, kind: "arc", index: 0 },
        b: { contour: 1, kind: "circle" },
      },
      {
        id: "e",
        kind: "equal",
        a: { contour: 0, kind: "arc", index: 0 },
        b: { contour: 1, kind: "circle" },
      },
    ],
  });
});
it.each(["external", "internal"] as const)(
  "solves %s circle tangency",
  (tangentMode) => {
    solve({
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 5 },
        { type: "circle", center: [8, 0], radius: 2 },
      ],
      constraints: [
        {
          id: "a",
          kind: "radius",
          a: { contour: 0, kind: "circle" },
          value: 5,
        },
        {
          id: "b",
          kind: "radius",
          a: { contour: 1, kind: "circle" },
          value: 2,
        },
        {
          id: "t",
          kind: "tangent",
          a: { contour: 0, kind: "circle" },
          b: { contour: 1, kind: "circle" },
          tangentMode,
        },
      ],
    });
  },
);
it("solves a point on a line and another point on a circle with point-pair alignment", () => {
  solve({
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
      { type: "path", start: [4, 2], segments: [] },
      { type: "circle", center: [20, 0], radius: 5 },
      { type: "path", start: [23, 2], segments: [] },
    ],
    constraints: [
      {
        id: "l",
        kind: "coincident",
        a: { contour: 1, kind: "point", index: 0 },
        b: { contour: 0, kind: "line", index: 0 },
      },
      {
        id: "c",
        kind: "coincident",
        a: { contour: 3, kind: "point", index: 0 },
        b: { contour: 2, kind: "circle" },
      },
      {
        id: "h",
        kind: "horizontal",
        a: { contour: 1, kind: "point", index: 0 },
        b: { contour: 3, kind: "point", index: 0 },
      },
    ],
  });
});
