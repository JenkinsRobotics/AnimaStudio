import { it, expect } from "vitest";
import { solveDrawingConstraints } from "./solve";
import { constraintResiduals } from "./residuals";
import type { SketchDrawing } from "../drawing";
it("solves a persisted line/cubic endpoint tangent join without moving fixed line endpoints", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          { type: "line", end: [10, 0] },
          {
            type: "bezier",
            controls: [
              [12, 2],
              [15, 5],
            ],
            end: [20, 5],
          },
        ],
      },
    ],
    constraints: [
      {
        id: "start",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [0, 0],
      },
      {
        id: "join",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 1 },
        point: [10, 0],
      },
      {
        id: "tangent",
        kind: "tangent",
        a: { contour: 0, kind: "curve", index: 0, parameter: 1 },
        b: { contour: 0, kind: "curve", index: 1, parameter: 0 },
      },
    ],
  };
  const solved = solveDrawingConstraints(JSON.parse(JSON.stringify(d)));
  for (const c of solved.constraints!)
    for (const residual of constraintResiduals(solved, c))
      expect(Math.abs(residual)).toBeLessThan(1e-6);
  const path = solved.contours[0];
  if (path.type !== "path" || path.segments[1].type !== "bezier") throw Error();
  expect(path.segments[1].controls[0][1]).toBeCloseTo(0, 5);
  expect(d.contours[0]).not.toEqual(solved.contours[0]);
});
it("rejects out-of-domain and stationary tangent references", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [0, 0],
              [5, 5],
            ],
            end: [10, 5],
          },
        ],
      },
    ],
  };
  const c = {
    id: "t",
    kind: "tangent" as const,
    a: { contour: 0, kind: "curve" as const, index: 0, parameter: 0 },
    b: { contour: 0, kind: "curve" as const, index: 0, parameter: 1 },
  };
  expect(() => constraintResiduals(d, c)).toThrow("stationary");
  expect(() =>
    constraintResiduals(d, { ...c, a: { ...c.a, parameter: 2 } }),
  ).toThrow("between");
});
it("retains finite contact parameters when unrelated trimming splits the contour", async () => {
  const { trimSketchCurve } = await import("../operations/trim");
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-10, 0],
        segments: [
          { type: "line", end: [10, 0] },
          { type: "line", end: [10, 10] },
          {
            type: "bezier",
            controls: [
              [10, 12],
              [15, 15],
            ],
            end: [20, 15],
          },
        ],
      },
      {
        type: "path",
        start: [-3, -5],
        segments: [{ type: "line", end: [-3, 5] }],
      },
      {
        type: "path",
        start: [3, -5],
        segments: [{ type: "line", end: [3, 5] }],
      },
    ],
    constraints: [
      {
        id: "t",
        kind: "tangent",
        a: { contour: 0, kind: "curve", index: 1, parameter: 1 },
        b: { contour: 0, kind: "curve", index: 2, parameter: 0 },
      },
    ],
  };
  const next = trimSketchCurve(d, [0, 0], 0.01),
    constraint = next.constraints!.find((c) => c.id === "t")!;
  expect(constraint.a).toMatchObject({ contour: 1, parameter: 1 });
  expect(constraint.b).toMatchObject({ contour: 1, parameter: 0 });
  for (const residual of constraintResiduals(next, constraint))
    expect(Math.abs(residual)).toBeLessThan(1e-6);
});
