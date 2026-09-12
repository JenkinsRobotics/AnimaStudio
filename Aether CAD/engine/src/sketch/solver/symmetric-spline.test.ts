import { expect, it } from "vitest";
import { constraintResiduals } from "./residuals";
import { solveDrawingConstraints } from "./solve";
import { dragSketchEntity } from "../operations/drag-entity";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const fixture = (reversed = false): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, -10],
      segments: [{ type: "line", end: [0, 10] }],
    },
    {
      type: "path",
      start: [-2, 0],
      segments: [
        {
          type: "bezier",
          controls: [
            [-4, 1],
            [-3, 4],
          ],
          end: [-5, 5],
        },
      ],
    },
    reversed
      ? {
          type: "path",
          start: [5, 5],
          segments: [
            {
              type: "bezier",
              controls: [
                [3, 4],
                [4, 1],
              ],
              end: [2, 0],
            },
          ],
        }
      : {
          type: "path",
          start: [2, 0],
          segments: [
            {
              type: "bezier",
              controls: [
                [4, 1],
                [3, 4],
              ],
              end: [5, 5],
            },
          ],
        },
  ],
  constraints: [
    {
      id: "axis0",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [0, -10],
    },
    {
      id: "axis1",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 1 },
      point: [0, 10],
    },
    {
      id: "sym",
      kind: "symmetric",
      a: { kind: "contour", contour: 1 },
      b: { kind: "contour", contour: 2 },
      axis: { kind: "line", contour: 0, index: 0 },
      splineReversed: reversed,
    },
  ],
});
it("retains exact spline control reflection in either drawing direction after native save and drag", () => {
  for (const reversed of [false, true]) {
    const d = fixture(reversed);
    validateSketchDrawing(d);
    const next = dragSketchEntity(
      JSON.parse(JSON.stringify(d)),
      { kind: "point", contour: 1, index: 0, control: 0 },
      [-1, 2],
    );
    const target = next.contours[2];
    if (target.type !== "path" || target.segments[0].type !== "bezier")
      throw Error();
    expect(target.segments[0].controls[reversed ? 1 : 0][0]).toBeCloseTo(5);
    expect(target.segments[0].controls[reversed ? 1 : 0][1]).toBeCloseTo(3);
    for (const c of next.constraints!)
      expect(
        constraintResiduals(next, c).every((r) => Math.abs(r) < 1e-6),
      ).toBe(true);
  }
});
it("rejects topology mismatch and conflicting fixed controls atomically", () => {
  const d = fixture();
  d.constraints!.push(
    {
      id: "p",
      kind: "fix",
      a: { kind: "point", contour: 1, index: 0, control: 0 },
      point: [-4, 1],
    },
    {
      id: "q",
      kind: "fix",
      a: { kind: "point", contour: 2, index: 0, control: 0 },
      point: [6, 1],
    },
  );
  const before = structuredClone(d);
  expect(() => solveDrawingConstraints(d)).toThrow();
  expect(d).toEqual(before);
  const bad = fixture();
  bad.contours[2] = {
    type: "path",
    start: [1, 0],
    segments: [{ type: "line", end: [2, 0] }],
  };
  expect(() => validateSketchDrawing(bad)).toThrow(/matching/);
});
