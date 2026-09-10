import { expect,it } from "vitest";
import { projectSketchDrawing } from "./drawing";
import { sketchVariantContour } from "../primitives";
import type { SketchFrame, SketchDrawing } from "../drawing";
const source:SketchFrame={originMillimeters:[0,0,0],xDirection:[1,0,0],normal:[0,0,1]};
const target:SketchFrame={...source,normal:[0,1,0]};
it("projects a full circle to one bounded interval with its identity",()=>{
 const d:SketchDrawing={type:"drawing",contours:[{type:"circle",center:[3,7],radius:5,id:"rim",hole:true,construction:true}]};
 const before=structuredClone(d), result=projectSketchDrawing(d,source,target).contours[0];
 expect(result).toEqual({type:"path",start:[-2,0],segments:[{type:"line",end:[8,0]}],id:"rim",hole:false,construction:true});
 expect(d).toEqual(before);
});
it("retains an arc's interior extremum when its projected endpoints coincide",()=>{
 const result=projectSketchDrawing({type:"drawing",contours:[{type:"path",start:[0,5],segments:[{type:"arc",middle:[-5,0],end:[0,-5]}]}]},source,target).contours[0];
 if(result.type!=="path")throw Error();
 expect(result.segments).toHaveLength(2);
 expect(result.segments[0].end[0]).toBeCloseTo(-5,8);
 expect(result.segments[1].end[0]).toBeCloseTo(0,8);
});
it("collapses a rotated full ellipse to its exact extrema without doubled backtracking",()=>{
 const ellipse=sketchVariantContour("ellipse",[[5,3],[9,7],[3,5]]);
 const result=projectSketchDrawing({type:"drawing",contours:[ellipse]},source,target).contours[0];
 if(result.type!=="path")throw Error();
 expect(result.segments).toHaveLength(1);
 expect(result.start[0]).toBeCloseTo(5-Math.sqrt(20),7);
 expect(result.segments[0].end[0]).toBeCloseTo(5+Math.sqrt(20),7);
});
