import { expect,it } from "vitest";
import { slotSketchEntities } from "./slot";
import { editDrawingDimension } from "./edit-dimension";
import { slotWidthHandle } from "./slot-handle";
import { constraintResiduals } from "../solver/residuals";
import { transformContour } from "../curves/similarity";
import type { SketchDrawing,SketchContour } from "../drawing";
const rectangle:SketchContour={type:"path",start:[0,0],segments:[{type:"line",end:[20,0]},{type:"line",end:[20,10]},{type:"line",end:[0,10]},{type:"line",end:[0,0]}]};
const capsule:SketchContour={type:"path",start:[0,-5],segments:[{type:"line",end:[10,-5]},{type:"arc",middle:[15,0],end:[10,5]},{type:"line",end:[0,5]},{type:"arc",middle:[-5,0],end:[0,-5]}]};
it("builds linked closed line and mixed-arc slots in either orientation",()=>{
 for(const shape of [rectangle,capsule])for(const reflect of [false,true]){
  const c=reflect?transformContour(shape,{a:-1,b:0,c:0,d:1,tx:0,ty:0}):structuredClone(shape);if(c.type!=="path")throw Error();
  const d:SketchDrawing={type:"drawing",contours:[c],constraints:[]};
  [c.start,...c.segments.slice(0,-1).map(s=>s.end)].forEach((p,index)=>d.constraints!.push({id:`fixed-${index}`,kind:"fix",a:{kind:"point",contour:0,index},point:p}));
  c.segments.forEach((s,index)=>{if(s.type==="arc")d.constraints!.push({id:`radius-${index}`,kind:"radius",a:{kind:"arc",contour:0,index},value:5});});
  const before=structuredClone(d),next=slotSketchEntities(d,[{kind:"contour",contour:0}],2);
  expect(next.contours).toHaveLength(3);expect(next.contours[0].construction).toBe(true);expect(next.contours[1]).toMatchObject({construction:false,hole:false});expect(next.contours[2]).toMatchObject({construction:false,hole:true});expect(d).toEqual(before);
  const slot=next.constraints!.find(c=>c.kind==="slot")!;
  const edited=editDrawingDimension(JSON.parse(JSON.stringify(next)),slot.id,3);
  for(const c of edited.constraints!)expect(constraintResiduals(edited,c).every(r=>Math.abs(r)<1e-6)).toBe(true);
  expect(slotWidthHandle(edited,slot.id)?.width).toBe(3);
 }
});
it("rejects a collapsed inner offset without changing source geometry",()=>{
 const d:SketchDrawing={type:"drawing",contours:[rectangle]},before=structuredClone(d);
 expect(()=>slotSketchEntities(d,[{kind:"contour",contour:0}],12)).toThrow(/collapses|reverses/);expect(d).toEqual(before);
});

it("offsets a two-arc closed centerline with both shared endpoints",()=>{
 const d:SketchDrawing={type:"drawing",contours:[{type:"path",start:[5,0],segments:[{type:"arc",middle:[0,5],end:[-5,0]},{type:"arc",middle:[0,-5],end:[5,0]}]}]};
 const next=slotSketchEntities(d,[{kind:"contour",contour:0}],2);
 expect(next.contours).toHaveLength(3);for(const c of next.constraints!)expect(constraintResiduals(next,c).every(r=>Math.abs(r)<1e-6)).toBe(true);
});
