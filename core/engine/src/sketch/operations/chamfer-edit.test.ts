import {it,expect} from 'vitest';
import {chamferSketchCorner} from './chamfer';
import {findChamferDimensions,chamferDistanceHandle,editChamferDimensions} from './chamfer-edit';
it('recognizes a saved bevel from its virtual-sharp references and edits its setback',()=>{
 const d=chamferSketchCorner({type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]},{type:'line',end:[10,10]}]}]},0,1,{mode:'equal-distance',distance:1});
 const refs=findChamferDimensions(d,{contour:0,kind:'line',index:1})!;expect(refs.equal).toBe(true);expect(chamferDistanceHandle(d,refs.distance)!.radius).toBe(1);const next=editChamferDimensions(d,refs,2);expect(chamferDistanceHandle(next,refs.distance)!.radius).toBe(2);
});
