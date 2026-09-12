import { expect, it } from "vitest";
import { slotSketchEntities } from "./slot";
import { editDrawingDimension } from "./edit-dimension";
import { constraintResiduals } from "../solver/residuals";
import { contourClosed, type SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        { type: "line", end: [10, 0] },
        { type: "line", end: [10, 10] },
      ],
    },
  ],
});
it("creates a rounded chain envelope and retains width after source vertices are fixed", () => {
  const d = source(),
    before = structuredClone(d),
    next = slotSketchEntities(d, [{ kind: "contour", contour: 0 }], 2);
  const profile = next.contours[1];
  expect(contourClosed(profile)).toBe(true);
  if (profile.type !== "path") throw Error();
  expect(profile.segments).toHaveLength(7);
  expect(profile.segments.filter((s) => s.type === "arc")).toHaveLength(3);
  expect(profile.start).toEqual([0, 1]);
  expect(profile.segments[0].end).toEqual([9, 1]);
  expect(next.contours[0].construction).toBe(true);
  expect(next.constraints![0].a).toEqual({ kind: "contour", contour: 0 });
  for (const [index, point] of [
    [0, 0],
    [10, 0],
    [10, 10],
  ].entries())
    next.constraints!.push({
      id: `fix-${index}`,
      kind: "fix",
      a: { kind: "point", contour: 0, index },
      point: point as [number, number],
    });
  const edited = editDrawingDimension(next, "slot-1", 3);
  for (const c of edited.constraints!)
    for (const r of constraintResiduals(edited, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  expect(d).toEqual(before);
});
it("rejects closed and reversing chains without altering the drawing", () => {
  const d = source();
  if (d.contours[0].type !== "path") throw Error();
  d.contours[0].segments[1].end = [0, 0];
  const before = structuredClone(d);
  expect(() =>
    slotSketchEntities(d, [{ kind: "contour", contour: 0 }], 2),
  ).toThrow();
  expect(d).toEqual(before);
});
it("joins a tangent line and circular arc with a shared width", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [
          { type: "line", end: [10, 0] },
          {
            type: "arc",
            middle: [10 + Math.sqrt(12.5), 5 - Math.sqrt(12.5)],
            end: [15, 5],
          },
        ],
      },
    ],
  };
  const next = slotSketchEntities(d, [{ kind: "contour", contour: 0 }], 2);
  const edited = editDrawingDimension(next, "slot-1", 3);
  for (const c of edited.constraints!)
    for (const r of constraintResiduals(edited, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it('keeps collinear intermediate vertices stable when width changes',()=>{
 const d=source();if(d.contours[0].type!=='path')throw Error();d.contours[0].segments[1].end=[20,0];
 const next=slotSketchEntities(d,[{kind:'contour',contour:0}],2);
 const edited=editDrawingDimension(next,'slot-1',4);
 for(const c of edited.constraints!)for(const r of constraintResiduals(edited,c))expect(Math.abs(r)).toBeLessThan(1e-6);
});
it('rejects overlapping chain envelopes',()=>{
 const d:SketchDrawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]},{type:'line',end:[10,1]},{type:'line',end:[0,1]}]}]};
 expect(()=>slotSketchEntities(d,[{kind:'contour',contour:0}],4)).toThrow();
});
