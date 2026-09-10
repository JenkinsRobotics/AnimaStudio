import { it, expect } from "vitest";
import { sketchConstraintState } from "./diagnostics";
import type { SketchDrawing } from "../drawing";
it("distinguishes free, fully constrained, redundant and conflicting circles", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [0, 0], radius: 2 }],
  };
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 3,
  });
  d.constraints = [
    {
      id: "center",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "radius",
      kind: "radius",
      a: { contour: 0, kind: "circle" },
      value: 2,
    },
  ];
  expect(sketchConstraintState(d)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
  d.constraints.push({
    id: "duplicate",
    kind: "radius",
    a: { contour: 0, kind: "circle" },
    value: 2,
  });
  expect(sketchConstraintState(d)).toMatchObject({
    state: "over-constrained",
    redundantEquations: 1,
  });
  d.constraints[2].value = 3;
  expect(sketchConstraintState(d).state).toBe("over-constrained");
});
it("counts arcs geometrically rather than treating their arbitrary through-point as an extra freedom", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [1, 0],
        segments: [
          { type: "arc", middle: [Math.SQRT1_2, Math.SQRT1_2], end: [0, 1] },
        ],
      },
    ],
  };
  const before = structuredClone(d);
  expect(sketchConstraintState(d).degreesOfFreedom).toBe(5);
  d.constraints = [
    {
      id: "a",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0 },
      point: [1, 0],
    },
    {
      id: "b",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 1 },
      point: [0, 1],
    },
    {
      id: "r",
      kind: "radius",
      a: { contour: 0, kind: "arc", index: 0 },
      value: 1,
    },
  ];
  expect(sketchConstraintState(d)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
  expect(d.contours).toEqual(before.contours);
});
it("does not mistake a solvable unsatisfied dimension for a conflict", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [0, 0], radius: 2 }],
    constraints: [
      { id: "r", kind: "radius", a: { contour: 0, kind: "circle" }, value: 3 },
    ],
  };
  expect(sketchConstraintState(d)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 2,
  });
});
