import { solveDrawingConstraints } from "../solver/solve";
import { expect, it } from "vitest";
import { constrainFitSpline } from "./spline-relations";
import { fitSketchSpline } from "../curves/fit-spline";
import { dragSketchEntity } from "./drag-entity";
import { splineShapeResiduals } from "../solver/spline-shape";
import { sketchConstraintState } from "../solver/diagnostics";
import { splitSketchSegment } from "./split";
import type { SketchDrawing, SketchPoint } from "../drawing";
const drawing = (points: SketchPoint[], closed = false): SketchDrawing =>
  constrainFitSpline(
    { type: "drawing", contours: [fitSketchSpline(points, { closed })] },
    0,
  );
it("retains only fit-point freedoms and avoids duplicate shape relations", () => {
  const d = drawing([
    [0, 0],
    [5, 4],
    [10, 0],
  ]);
  expect(constrainFitSpline(d, 0).constraints).toHaveLength(1);
  expect(sketchConstraintState(d)).toMatchObject({ degreesOfFreedom: 6 });
  const closed = drawing(
    [
      [0, 0],
      [10, 0],
      [10, 10],
      [0, 10],
    ],
    true,
  );
  expect(sketchConstraintState(closed)).toMatchObject({ degreesOfFreedom: 8 });
});
it("refits an interior point with fixed neighbors while maintaining shape intent", () => {
  const d = drawing([
      [0, 0],
      [5, 4],
      [10, 0],
    ]),
    original = structuredClone(d);
  d.constraints!.push(
    {
      id: "start",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [0, 0],
    },
    {
      id: "end",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 2 },
      point: [10, 0],
    },
  );
  const moved = dragSketchEntity(
    d,
    { kind: "point", contour: 0, index: 1 },
    [1, 2],
  );
  const c = moved.contours[0];
  if (c.type !== "path") throw Error();
  expect(c.segments[0].end[0]).toBeCloseTo(6, 5);
  expect(c.segments[0].end[1]).toBeCloseTo(6, 5);
  expect(Math.max(...splineShapeResiduals(c).map(Math.abs))).toBeLessThan(1e-6);
  expect(c.segments[0]).not.toEqual(
    original.contours[0].type === "path"
      ? original.contours[0].segments[0]
      : null,
  );
  expect(moved.constraints).toEqual(d.constraints);
  expect(d.contours).toEqual(original.contours);
});
it("refits the periodic seam when moving the first fit point", () => {
  const d = drawing(
    [
      [0, 0],
      [10, 0],
      [10, 10],
      [0, 10],
    ],
    true,
  );
  const moved = dragSketchEntity(
    d,
    { kind: "point", contour: 0, index: 0 },
    [-1, -2],
  );
  const c = moved.contours[0];
  if (c.type !== "path") throw Error();
  expect(c.start[0]).toBeCloseTo(-1, 5);
  expect(c.start[1]).toBeCloseTo(-2, 5);
  expect(c.segments.at(-1)!.end).toEqual(c.start);
  expect(Math.max(...splineShapeResiduals(c).map(Math.abs))).toBeLessThan(1e-6);
});

it("requires removing the shape relation before unsupported topology edits", () => {
  const d = drawing([
    [0, 0],
    [10, 0],
  ]);
  expect(() => splitSketchSegment(d, [5, 0], 0.1)).toThrow();
});
it("reports fully defined once every fit point is fixed", () => {
  const points: SketchPoint[] = [
      [0, 0],
      [5, 4],
      [10, 0],
    ],
    d = drawing(points);
  d.constraints!.push(
    ...points.map((point, index) => ({
      id: `fixed-${index}`,
      kind: "fix" as const,
      a: { kind: "point" as const, contour: 0, index },
      point,
    })),
  );
  expect(sketchConstraintState(d)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
});

it("validates already-satisfied large fit splines without exceeding iterative solver limits",()=>{
 const points:SketchPoint[]=Array.from({length:100},(_,i)=>[i,Math.sin(i/10)]);
 const d=drawing(points);expect(solveDrawingConstraints(d)).toEqual(d);
});
