import { expect,it } from "vitest";
import { constrainSketchPolygon } from "./polygon-relations";
import { editSketchPolygonSides } from "./polygon-sides";
import { sketchVariantContour } from "../primitives";
import { constraintResiduals } from "../solver/residuals";
function polygon(){return constrainSketchPolygon({type:"drawing",contours:[sketchVariantContour("circumscribed-polygon",[[0,0],[10,0]],6)]},0,[0,0],true);}
it("keeps surviving supporting edges, symmetry axes and finite contacts",()=>{
 const d=polygon(),path=d.contours[0];if(path.type!=="path")throw Error();
 const a=path.segments[0].end,b=path.segments[1].end,t=.6;
 d.contours.push({type:"path",start:[a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])],segments:[]},{type:"path",start:[9,0],segments:[]},{type:"path",start:[11,0],segments:[]});
 d.constraints!.push({id:"vertical",kind:"vertical",a:{kind:"line",contour:0,index:0}},
 {id:"contact",kind:"coincident",a:{kind:"point",contour:3,index:0},b:{kind:"curve",contour:0,index:1,parameter:t,sliding:true}},
 {id:"sym",kind:"symmetric",a:{kind:"point",contour:4,index:0},b:{kind:"point",contour:5,index:0},axis:{kind:"line",contour:0,index:0}});
 const next=editSketchPolygonSides(d,0,12),c=next.constraints!.find(c=>c.id==="contact")!;
 expect(c.b!.index).toBe(2);expect(c.b!.parameter).toBeCloseTo(.5+.1*Math.tan(Math.PI/6)/Math.tan(Math.PI/12),7);expect(c.b!.sliding).toBe(true);
 for(const c of next.constraints!)expect(constraintResiduals(next,c).every(r=>Math.abs(r)<1e-6)).toBe(true);
 const roundtrip=JSON.parse(JSON.stringify(next));expect(editSketchPolygonSides(roundtrip,0,6).constraints!.find(c=>c.id==="contact")!.b!.parameter).toBeCloseTo(.6,7);
});
it("rejects contacts beyond a shortened side and conflicting edge dimensions atomically",()=>{
 const d=polygon(),path=d.contours[0];if(path.type!=="path")throw Error();
 const a=path.start,b=path.segments[0].end;
 d.contours.push({type:"path",start:[a[0]+.9*(b[0]-a[0]),a[1]+.9*(b[1]-a[1])],segments:[]});
 d.constraints!.push({id:"contact",kind:"coincident",a:{kind:"point",contour:3,index:0},b:{kind:"curve",contour:0,index:0,parameter:.9}});
 const before=structuredClone(d);expect(()=>editSketchPolygonSides(d,0,12)).toThrow(/attachment/);expect(d).toEqual(before);
 d.constraints=d.constraints!.filter(c=>c.id!=="contact");d.constraints.push({id:"fixed-length",kind:"length",a:{kind:"line",contour:0,index:0},value:Math.hypot(b[0]-a[0],b[1]-a[1])});
 expect(()=>editSketchPolygonSides(d,0,12)).toThrow(/fixed-length/);
});
