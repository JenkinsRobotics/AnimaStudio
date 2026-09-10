import { expect, it } from "vitest";
import { circleContinuityResiduals } from "./circle-continuity";
import { constraintResiduals } from "./residuals";
import { solveDrawingConstraints } from "./solve";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
it("matches signed osculating curvature independently of traversal direction and speed", () => {
  const circle = { center: [0, 0.5] as [number, number], radius: 0.5 };
  for (const speed of [-3, 0.25, 4]) {
    const curve = {
      point: [0, 0] as [number, number],
      first: [speed, 0] as [number, number],
      second: [0, 2 * speed * speed] as [number, number],
    };
    expect(circleContinuityResiduals(circle, curve, true).map(Math.abs)).toEqual([0, 0, 0]);
    expect(
      Math.abs(
        circleContinuityResiduals(
          { center: [0, -0.5], radius: 0.5 },
          curve,
          true,
        )[2],
      ),
    ).toBeCloseTo(2);
    expect(
      circleContinuityResiduals({ center: [0, -0.5], radius: 0.5 }, curve).map(Math.abs),
    ).toEqual([0, 0]);
  }
});
const fixture = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        {
          type: "bezier",
          controls: [
            [1 / 3, 0],
            [2 / 3, 1 / 3],
          ],
          end: [1, 1],
        },
      ],
    },
    { type: "circle", center: [0.1, 0.6], radius: 0.6 },
  ],
  constraints: [
    {
      id: "p0",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "p1",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0, control: 0 },
      point: [1 / 3, 0],
    },
    {
      id: "p2",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0, control: 1 },
      point: [2 / 3, 1 / 3],
    },
    {
      id: "p3",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 1 },
      point: [1, 1],
    },
    {
      id: "g2",
      kind: "curvature",
      a: { contour: 1, kind: "circle" },
      b: { contour: 0, kind: "curve", index: 0, parameter: 0 },
    },
  ],
});
it("solves a circle to the fixed cubic osculating circle and preserves native relations", () => {
  const d = fixture(),
    before = structuredClone(d),
    next = solveDrawingConstraints(d);
  expect(d).toEqual(before);
  const circle = next.contours[1];
  if (circle.type !== "circle") throw Error();
  expect(circle.center[0]).toBeCloseTo(0);
  expect(circle.center[1]).toBeCloseTo(0.5);
  expect(circle.radius).toBeCloseTo(0.5);
  validateSketchDrawing(JSON.parse(JSON.stringify(next)));
  const c = next.constraints!.at(-1)!;
  expect(
    constraintResiduals(next, { ...c, a: c.b!, b: c.a }).every(
      (r) => Math.abs(r) < 1e-6,
    ),
  ).toBe(true);
});
it("rejects a fixed contradictory radius and undefined contacts atomically", () => {
  const d = fixture();
  d.constraints!.push({
    id: "r",
    kind: "radius",
    a: { kind: "circle", contour: 1 },
    value: 1,
  });
  const before = structuredClone(d);
  expect(() => solveDrawingConstraints(d)).toThrow();
  expect(d).toEqual(before);
  expect(() =>
    circleContinuityResiduals(
      { center: [0, 0], radius: 1 },
      { point: [0, 0], first: [1, 0], second: [0, 0] },
      true,
    ),
  ).toThrow(/contact/);
});
