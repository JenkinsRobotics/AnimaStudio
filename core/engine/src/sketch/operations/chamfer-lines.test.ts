import {it,expect} from 'vitest';
import {chamferSketchLines} from './chamfer-lines';
import {constraintResiduals} from '../drawing-constraints';
import type {SketchDrawing} from '../drawing';
it('joins separately drawn lines at a virtual intersection and retains the selected sides',()=>{
 const d:SketchDrawing={type:'drawing',contours:[{type:'path',start:[-10,0],segments:[{type:'line',end:[-2,0]}]},{type:'path',start:[0,2],segments:[{type:'line',end:[0,10]}]}]},before=structuredClone(d);
 const result=chamferSketchLines(d,{contour:0,segment:0,parameter:.5},{contour:1,segment:0,parameter:.5},{mode:'two-distances',distance:2,secondDistance:3}),path=result.contours[0];
 if(path.type!=='path')throw Error();expect(path.start).toEqual([-10,0]);expect(path.segments.map(s=>s.end)).toEqual([[-2,0],[0,3],[0,10]]);expect(d).toEqual(before);
 for(const c of result.constraints!)for(const r of constraintResiduals(result,c))expect(Math.abs(r)).toBeLessThan(1e-6);
});
it('anchors asymmetric setbacks and angle to the first selected connected line',()=>{
 const d:SketchDrawing={type:'drawing',contours:[{type:'path',start:[-10,0],segments:[{type:'line',end:[0,0]},{type:'line',end:[0,10]}]}]};
 const a={contour:0,segment:1},b={contour:0,segment:0};
 const result=chamferSketchLines(d,a,b,{mode:'two-distances',distance:2,secondDistance:3}),path=result.contours[0];if(path.type!=='path')throw Error();expect(path.segments[0].end).toEqual([-3,0]);expect(path.segments[1].end).toEqual([0,2]);
 const angled=chamferSketchLines(d,a,b,{mode:'distance-angle',distance:2,angleDegrees:30});
 expect(Math.abs(angled.constraints!.find(c=>c.kind==='angle')!.value!)).toBeCloseTo(30,6);
 for(const drawing of [result,angled])for(const c of drawing.constraints!)for(const r of constraintResiduals(drawing,c))expect(Math.abs(r)).toBeLessThan(1e-6);
});
it('remaps unrelated contour references when lines are merged',()=>{
 const d:SketchDrawing={type:'drawing',contours:[{type:'path',start:[-10,0],segments:[{type:'line',end:[0,0]}]},{type:'path',start:[0,0],segments:[{type:'line',end:[0,10]}]},{type:'circle',center:[30,0],radius:2}],constraints:[{id:'r',kind:'radius',a:{contour:2,kind:'circle'},value:2}]};
 const result=chamferSketchLines(d,{contour:0,segment:0},{contour:1,segment:0},{mode:'equal-distance',distance:1});expect(result.constraints!.find(c=>c.id==='r')!.a.contour).toBe(1);
});
