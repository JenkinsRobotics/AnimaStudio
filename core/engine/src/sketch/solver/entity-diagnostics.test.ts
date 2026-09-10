import { expect, it } from "vitest";
import { sketchConstraintState } from "./diagnostics";
import type { SketchDrawing } from "../drawing";
it("separates a fixed point from its free line endpoint and unrelated geometry", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
      { type: "circle", center: [30, 20], radius: 5 },
    ],
    constraints: [
      {
        id: "fixed",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 0 },
        point: [0, 0],
      },
    ],
  };
  const before = structuredClone(d);
  expect(
    sketchConstraintState(d, { kind: "point", contour: 0, index: 0 })
      .degreesOfFreedom,
  ).toBe(0);
  expect(
    sketchConstraintState(d, { kind: "point", contour: 0, index: 1 })
      .degreesOfFreedom,
  ).toBe(2);
  expect(
    sketchConstraintState(d, { kind: "line", contour: 0, index: 0 })
      .degreesOfFreedom,
  ).toBe(2);
  d.constraints!.push({
    id: "horizontal",
    kind: "horizontal",
    a: { kind: "line", contour: 0, index: 0 },
  });
  expect(
    sketchConstraintState(d, { kind: "line", contour: 0, index: 0 })
      .degreesOfFreedom,
  ).toBe(1);
  d.constraints!.push({
    id: "length",
    kind: "length",
    a: { kind: "line", contour: 0, index: 0 },
    value: 10,
  });
  expect(
    sketchConstraintState(d, { kind: "line", contour: 0, index: 0 }),
  ).toMatchObject({ state: "fully-constrained", degreesOfFreedom: 0 });
  expect(sketchConstraintState(d).degreesOfFreedom).toBe(3);
  expect(d.contours).toEqual(before.contours);
});
it("counts circular and arc mobility using geometry rather than the number of selected coordinates", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      { type: "circle", center: [0, 0], radius: 3 },
      {
        type: "path",
        start: [1, 0],
        segments: [
          { type: "arc", middle: [Math.SQRT1_2, Math.SQRT1_2], end: [0, 1] },
        ],
      },
    ],
  };
  expect(
    sketchConstraintState(d, { kind: "circle", contour: 0 }).degreesOfFreedom,
  ).toBe(3);
  expect(
    sketchConstraintState(d, { kind: "point", contour: 0, index: 0 })
      .degreesOfFreedom,
  ).toBe(2);
  expect(
    sketchConstraintState(d, { kind: "arc", contour: 1, index: 0 })
      .degreesOfFreedom,
  ).toBe(5);
  d.constraints = [
    {
      id: "radius",
      kind: "radius",
      a: { kind: "circle", contour: 0 },
      value: 3,
    },
  ];
  expect(
    sketchConstraintState(d, { kind: "circle", contour: 0 }).degreesOfFreedom,
  ).toBe(2);
  expect(
    sketchConstraintState(d, { kind: "line", contour: 99, index: 0 }).state,
  ).toBe("invalid");
});
it("batches entity and sketch results without sharing mobility between selections",async()=>{
 const {sketchConstraintStates}=await import('./diagnostics');
 const d:SketchDrawing={type:'drawing',contours:[{type:'circle',center:[0,0],radius:5},{type:'circle',center:[20,0],radius:3}],constraints:[{id:'fix',kind:'fix',a:{kind:'point',contour:0,index:0},point:[0,0]}]};
 const refs=[undefined,{kind:'circle' as const,contour:0},{kind:'point' as const,contour:0,index:0},{kind:'circle' as const,contour:1}];
 const before=structuredClone(d),batch=sketchConstraintStates(d,refs);
 expect(batch.map(s=>s.degreesOfFreedom)).toEqual([4,1,0,3]);
 expect(batch).toEqual(refs.map(ref=>sketchConstraintState(d,ref)));expect(d).toEqual(before);
});
