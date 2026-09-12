import { expect,it } from 'vitest';
import { solveDrawingConstraints, constraintResiduals, type DrawingConstraint } from './drawing-constraints';
import { validateSketchDrawing, type SketchDrawing } from './drawing';
const line=(a:[number,number],b:[number,number])=>({type:'path' as const,start:a,segments:[{type:'line' as const,end:b}]});
const ref=(contour:number,kind:'line'|'point'|'circle',index=0)=>({contour,kind,index});
const check=(d:SketchDrawing)=>{const result=solveDrawingConstraints(d);validateSketchDrawing(result);for(const c of result.constraints??[])expect(Math.max(...constraintResiduals(result,c).map(Math.abs))).toBeLessThan(1e-6);return result;};
it('solves a fixed, horizontal dimensioned line and perpendicular/equal dependent line without mutating source',()=>{
 const d:SketchDrawing={type:'drawing',contours:[line([1,2],[12,6]),line([20,5],[26,15])],constraints:[
 {id:'fix',kind:'fix',a:ref(0,'point'),point:[0,0]},
 {id:'h',kind:'horizontal',a:ref(0,'line')}, {id:'length',kind:'length',a:ref(0,'line'),value:10},
 {id:'p',kind:'perpendicular',a:ref(0,'line'),b:ref(1,'line')},{id:'eq',kind:'equal',a:ref(0,'line'),b:ref(1,'line')},
 {id:'join',kind:'coincident',a:ref(0,'point',1),b:ref(1,'point')}]};
 const before=JSON.stringify(d);check(d);expect(JSON.stringify(d)).toBe(before);
});
it('supports circle concentricity, equal radii, radius and line tangency',()=>{
 check({type:'drawing',contours:[{type:'circle',center:[0,0],radius:4},{type:'circle',center:[3,2],radius:7},line([-10,8],[10,9])],constraints:[
 {id:'center',kind:'fix',a:ref(0,'point'),point:[0,0]}, {id:'con',kind:'concentric',a:ref(0,'circle'),b:ref(1,'circle')},
 {id:'rad',kind:'radius',a:ref(0,'circle'),value:5},{id:'equal',kind:'equal',a:ref(0,'circle'),b:ref(1,'circle')},
 {id:'h',kind:'horizontal',a:ref(2,'line')},{id:'tan',kind:'tangent',a:ref(0,'circle'),b:ref(2,'line')}]});
});
it('rejects conflicting dimensions atomically',()=>{
 const d:SketchDrawing={type:'drawing',contours:[line([0,0],[10,0])],constraints:[{id:'a',kind:'length',a:ref(0,'line'),value:10},{id:'b',kind:'length',a:ref(0,'line'),value:20}]};
 const before=JSON.stringify(d);expect(()=>solveDrawingConstraints(d)).toThrow(/conflict|converge/);expect(JSON.stringify(d)).toBe(before);
});
it('supports midpoint, parallel, vertical, angle and point distance constraints',()=>{
 const constraints:DrawingConstraint[]=[{id:'a',kind:'vertical',a:ref(0,'line')},{id:'b',kind:'parallel',a:ref(0,'line'),b:ref(1,'line')},{id:'mid',kind:'midpoint',a:ref(0,'line'),b:ref(1,'point')},{id:'dist',kind:'distance',a:ref(1,'point'),b:ref(1,'point',1),value:5}];
 check({type:'drawing',contours:[line([0,0],[1,10]),line([0,4],[2,8])],constraints});
 check({type:'drawing',contours:[line([0,0],[10,0]),line([0,2],[8,8])],constraints:[{id:'angle',kind:'angle',a:ref(0,'line'),b:ref(1,'line'),value:45}]});
});
