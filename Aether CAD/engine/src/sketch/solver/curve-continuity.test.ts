import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { curveContinuityResiduals } from "./curve-continuity";
import { constraintResiduals } from "./residuals";
import { solveDrawingConstraints } from "./solve";

function fixture(): SketchDrawing {
  return {
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
        id: "smooth",
        kind: "curvature",
        a: { contour: 0, kind: "curve", index: 0, parameter: 1 },
        b: { contour: 0, kind: "curve", index: 1, parameter: 0 },
      },
    ],
  };
}
it("solves zero curvature at a line/cubic join while preserving fixed endpoints", () => {
  const source = fixture(),
    before = structuredClone(source),
    solved = solveDrawingConstraints(source);
  for (const constraint of solved.constraints!)
    for (const r of constraintResiduals(solved, constraint))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  const path = solved.contours[0];
  if (path.type !== "path" || path.segments[1].type !== "bezier") throw Error();
  expect(path.segments[1].controls[0][1]).toBeCloseTo(0, 5);
  expect(path.segments[1].controls[1][1]).toBeCloseTo(0, 5);
  expect(source).toEqual(before);
});
it("matches nonzero curvature regardless of speed or reversed parameter direction", () => {
  const p = {
    point: [0, 0] as [number, number],
    first: [1, 0] as [number, number],
    second: [0, 2] as [number, number],
  };
  for (const speed of [-3, 0.25, 4]) {
    const q = {
      point: p.point,
      first: [speed, 0] as [number, number],
      second: [0, 2 * speed * speed] as [number, number],
    };
    expect(curveContinuityResiduals(p, q, true)).toEqual([0, 0, 0, 0]);
    q.second[1] *= 2;
    expect(Math.abs(curveContinuityResiduals(p, q, true)[3])).toBeGreaterThan(
      0.1,
    );
  }
});
it("rejects conflicting fixed geometry atomically", () => {
  const source = fixture();
  source.constraints!.push({
    id: "control",
    kind: "fix",
    a: { contour: 0, kind: "point", index: 1, control: 1 },
    point: [15, 5],
  });
  const before = structuredClone(source);
  expect(() => solveDrawingConstraints(source)).toThrow();
  expect(source).toEqual(before);
});
it("rejects stationary points and reports unsatisfied circle-locus contacts", () => {
  const p = {
    point: [0, 0] as [number, number],
    first: [0, 0] as [number, number],
    second: [1, 1] as [number, number],
  };
  expect(() => curveContinuityResiduals(p, p, true)).toThrow("stationary");
  const source = fixture();
  source.contours.push({ type: "circle", center: [0, 0], radius: 2 });
  const c = source.constraints![2];
  c.b = { kind: "circle", contour: 1 };
  expect(constraintResiduals(source, c).some(r => Math.abs(r) > 1e-6)).toBe(true);
});
it("solves a nonzero cubic/cubic curvature join with the reference curve fixed", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-1, 1],
        segments: [
          {
            type: "bezier",
            controls: [
              [-2 / 3, 1 / 3],
              [-1 / 3, 0],
            ],
            end: [0, 0],
          },
        ],
      },
      {
        type: "path",
        start: [0, 0],
        segments: [
          {
            type: "bezier",
            controls: [
              [1 / 3, 0],
              [2 / 3, 0.6],
            ],
            end: [1, 1],
          },
        ],
      },
    ],
    constraints: [
      {
        id: "p0",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [-1, 1],
      },
      {
        id: "p1",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 1 },
        point: [0, 0],
      },
      {
        id: "c0",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0, control: 0 },
        point: [-2 / 3, 1 / 3],
      },
      {
        id: "c1",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0, control: 1 },
        point: [-1 / 3, 0],
      },
      {
        id: "smooth",
        kind: "curvature",
        a: { contour: 0, kind: "curve", index: 0, parameter: 1 },
        b: { contour: 1, kind: "curve", index: 0, parameter: 0 },
      },
    ],
  };
  const solved = solveDrawingConstraints(source);
  for (const c of solved.constraints!)
    for (const r of constraintResiduals(solved, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  expect(solved.contours[1]).not.toEqual(source.contours[1]);
});
it("counts a line/cubic G2 join without a redundant second curvature equation",async()=>{
  const {sketchConstraintState}=await import("./diagnostics");
  const state=sketchConstraintState(solveDrawingConstraints(fixture()));
  expect(state.state).toBe("under-constrained");
  expect(state.degreesOfFreedom).toBe(4);
  expect(state.redundantEquations).toBe(0);
});
