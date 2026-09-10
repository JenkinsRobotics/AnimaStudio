import { expect,it } from "vitest";
import { slotSketchEntities } from "./slot";
import { editDrawingDimension } from "./edit-dimension";
import { slotWidthHandle } from "./slot-handle";
import { constraintResiduals } from "../solver/residuals";
import type { SketchDrawing } from "../drawing";
const source=():SketchDrawing=>({type:"drawing",contours:[{type:"circle",center:[2,3],radius:10}],constraints:[{id:"radius",kind:"radius",a:{kind:"circle",contour:0},value:10},{id:"center",kind:"fix",a:{kind:"point",contour:0,index:0},point:[2,3]}]});
it("creates exact annular boundaries with one editable width and native references",()=>{
 const d=source(),next=slotSketchEntities(d,[{kind:"circle",contour:0}],4);
 expect(next.contours).toMatchObject([{construction:true},{type:"circle",radius:12,hole:false},{type:"circle",radius:8,hole:true}]);expect(d.contours).toHaveLength(1);
 const slots=next.constraints!.filter(c=>c.kind==="slot");expect(slots).toHaveLength(2);expect(slots[1].valueFrom).toBe(slots[0].id);
 const edited=editDrawingDimension(JSON.parse(JSON.stringify(next)),slots[1].id,6);
 expect(edited.contours[1]).toMatchObject({radius:expect.closeTo(13,6)});expect(edited.contours[2]).toMatchObject({radius:expect.closeTo(7,6)});
 for(const c of edited.constraints!)expect(constraintResiduals(edited,c).every(r=>Math.abs(r)<1e-6)).toBe(true);
 const larger=editDrawingDimension(edited,"radius",12);expect(larger.contours[1]).toMatchObject({radius:expect.closeTo(15,6)});expect(larger.contours[2]).toMatchObject({radius:expect.closeTo(9,6)});
 expect(slotWidthHandle(edited,slots[0].id)).toMatchObject({width:6,normal:[1,0],origin:[expect.closeTo(12,6),expect.closeTo(3,6)],position:[expect.closeTo(15,6),expect.closeTo(3,6)]});
});
it("shares a driver across circular and open centerlines without duplicate IDs",()=>{
 const d=source();d.contours.push({type:"path",start:[30,0],segments:[{type:"line",end:[40,0]}]});
 for(const refs of [[{kind:"circle" as const,contour:0},{kind:"line" as const,contour:1,index:0}],[{kind:"line" as const,contour:1,index:0},{kind:"circle" as const,contour:0}]]){
  const next=slotSketchEntities(d,refs,2),slots=next.constraints!.filter(c=>c.kind==="slot");expect(new Set(next.constraints!.map(c=>c.id)).size).toBe(next.constraints!.length);expect(slots.filter(c=>c.value!==undefined)).toHaveLength(1);for(const c of slots.slice(1))expect(c.valueFrom).toBe(slots[0].id);
 }
});
it("rejects collapsed inner boundaries and malformed side references",()=>{
 const d=source(),before=structuredClone(d);expect(()=>slotSketchEntities(d,[{kind:"circle",contour:0}],20)).toThrow(/diameter/);expect(d).toEqual(before);
 const next=slotSketchEntities(d,[{kind:"circle",contour:0}],2),c=next.constraints!.find(c=>c.kind==="slot")!;delete c.slotBoundary;expect(()=>constraintResiduals(next,c)).toThrow(/boundary side/);
});
