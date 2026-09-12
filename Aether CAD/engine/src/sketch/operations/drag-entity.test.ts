import {it,expect} from 'vitest';
import {dragSketchEntity} from './drag-entity';
import type {SketchDrawing} from '../drawing';
it('drags a vertex or edge without persisting temporary constraints',()=>{
 const d:SketchDrawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]}]}]};
 const moved=dragSketchEntity(d,{contour:0,kind:'line',index:0},[2,3]),path=moved.contours[0];if(path.type!=='path')throw Error();expect(path.start).toEqual([2,3]);expect(path.segments[0].end).toEqual([12,3]);expect(moved.constraints).toBeUndefined();expect(d.contours[0]).not.toEqual(path);
});
it('rejects a drag conflicting with a fixed point without mutating the drawing',()=>{
 const d:SketchDrawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[]}],constraints:[{id:'fixed',kind:'fix',a:{contour:0,kind:'point',index:0},point:[0,0]}]},before=structuredClone(d);
 expect(()=>dragSketchEntity(d,{contour:0,kind:'point',index:0},[2,3])).toThrow();expect(d).toEqual(before);
});
