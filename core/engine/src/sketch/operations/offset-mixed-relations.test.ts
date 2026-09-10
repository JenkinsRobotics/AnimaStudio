import { expect, it } from "vitest";
import { offsetSketch } from "./offset";
import { editDrawingDimension } from "./edit-dimension";
import { solveDrawingConstraints } from "../solver/solve";
import { constraintResiduals } from "../solver/residuals";
import { sketchArcGeometry } from "../arc-geometry";
import type { SketchDrawing, SketchPoint } from "../drawing";
function source(): SketchDrawing {
  const points: SketchPoint[] = [
    [0, -5],
    [10, -5],
    [10, 5],
    [0, 5],
  ];
  return {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: points[0],
        segments: [
          { type: "line", end: points[1] },
          { type: "arc", middle: [15, 0], end: points[2] },
          { type: "line", end: points[3] },
          { type: "arc", middle: [-5, 0], end: [0, -5] },
        ],
      },
    ],
    constraints: [
      ...points.map((point, index) => ({
        id: `p${index}`,
        kind: "fix" as const,
        a: { kind: "point" as const, contour: 0, index },
        point: [...point] as SketchPoint,
      })),
      {
        id: "r1",
        kind: "radius",
        a: { kind: "arc", contour: 0, index: 1 },
        value: 5,
      },
      {
        id: "r3",
        kind: "radius",
        a: { kind: "arc", contour: 0, index: 3 },
        value: 5,
      },
    ],
  };
}
it("retains a shared signed distance for a tangent capsule", () => {
  const initial = offsetSketch(source(), [0], 1),
    next = editDrawingDimension(initial, "offset-1", 2);
  expect(next.constraints?.find((c) => c.kind === "offset")).toMatchObject({
    a: { kind: "contour" },
    value: 2,
  });
  for (const c of next.constraints!)
    for (const r of constraintResiduals(next, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  const p = next.contours[1];
  if (p.type !== "path") throw Error();
  expect(p.start[1]).toBeCloseTo(-3, 5);
  p.segments.forEach((s, i) => {
    if (s.type === "arc")
      expect(
        sketchArcGeometry(i ? p.segments[i - 1].end : p.start, s.middle, s.end)
          .radius,
      ).toBeCloseTo(3, 5);
  });
});
it("updates a mixed offset when the fixed source grows", () => {
  const d = offsetSketch(source(), [0], 1);
  d.constraints!.find((c) => c.id === "p1")!.point = [20, -5];
  d.constraints!.find((c) => c.id === "p2")!.point = [20, 5];
  const next = solveDrawingConstraints(d),
    p = next.contours[1];
  if (p.type !== "path" || p.segments[1].type !== "arc") throw Error();
  const g = sketchArcGeometry(
    p.segments[0].end,
    p.segments[1].middle,
    p.segments[1].end,
  );
  const original = next.contours[0];
  if (original.type !== "path" || original.segments[1].type !== "arc")
    throw Error();
  const a = sketchArcGeometry(
    original.segments[0].end,
    original.segments[1].middle,
    original.segments[1].end,
  );
  expect(g.center[0]).toBeCloseTo(a.center[0], 5);
  expect(g.center[1]).toBeCloseTo(a.center[1], 5);
  expect(g.radius).toBeCloseTo(a.radius - 1, 5);
  for (const c of next.constraints!)
    for (const r of constraintResiduals(next, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("rejects a collapsing mixed offset without mutating its source", () => {
  const d = offsetSketch(source(), [0], 1),
    before = structuredClone(d);
  expect(() => editDrawingDimension(d, "offset-1", 6)).toThrow();
  expect(d).toEqual(before);
});
it('keeps a non-tangent line/arc join connected while editing its offset',()=>{
 const d:SketchDrawing={type:'drawing',contours:[{type:'path',start:[10,0],segments:[{type:'line',end:[5,0]},{type:'arc',middle:[0,5],end:[-5,0]}]}],constraints:[
  {id:'p0',kind:'fix',a:{kind:'point',contour:0,index:0},point:[10,0]},
  {id:'p1',kind:'fix',a:{kind:'point',contour:0,index:1},point:[5,0]},
  {id:'p2',kind:'fix',a:{kind:'point',contour:0,index:2},point:[-5,0]},
  {id:'r',kind:'radius',a:{kind:'arc',contour:0,index:1},value:5},
 ]};
 const next=editDrawingDimension(offsetSketch(d,[0],1),'offset-1',2);
 for(const c of next.constraints!)for(const r of constraintResiduals(next,c))expect(Math.abs(r)).toBeLessThan(1e-6);
 const p=next.contours[1];if(p.type!=='path'||p.segments[1].type!=='arc')throw Error();
 expect(p.start[1]).toBeCloseTo(-2,5);expect(sketchArcGeometry(p.segments[0].end,p.segments[1].middle,p.segments[1].end).radius).toBeCloseTo(3,5);
});
