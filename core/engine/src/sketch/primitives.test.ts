import { expect,it } from 'vitest';
import {sketchVariantContour} from './primitives';
import {validateSketchDrawing} from './drawing';
it('creates a midpoint line symmetrically and rotated rectangles with perpendicular edges',()=>{
 const line=sketchVariantContour('midpoint-line',[[3,4],[8,6]]);
 expect(line).toEqual({type:'path',start:[-2,2],segments:[{type:'line',end:[8,6]}]});
 const c=sketchVariantContour('aligned-rectangle',[[1,2],[4,6],[0,5]]);
 if(c.type!=='path')throw Error('path');
 const b=c.segments[0].end,d=c.segments[1].end;
 expect((b[0]-c.start[0])*(d[0]-b[0])+(b[1]-c.start[1])*(d[1]-b[1])).toBeCloseTo(0,10);
 validateSketchDrawing({type:'drawing',contours:[c]});
});
it('fits a circle through all three points and rejects collinear input',()=>{
 const c=sketchVariantContour('three-point-circle',[[15,7],[10,12],[5,7]]);
 expect(c).toEqual({type:'circle',center:[10,7],radius:5});
 expect(()=>sketchVariantContour('three-point-circle',[[0,0],[1,1],[2,2]])).toThrow('collinear');
});
it('constructs a counterclockwise arc of constant radius using an end direction',()=>{
 const c=sketchVariantContour('center-arc',[[0,0],[5,0],[0,20]]);
 if(c.type!=='path'||c.segments[0].type!=='arc')throw Error('arc');
 expect(c.segments[0].end[1]).toBeCloseTo(5);expect(c.segments[0].middle[0]).toBeCloseTo(Math.sqrt(12.5));
 validateSketchDrawing({type:'drawing',contours:[c]});
});
it('uses a vertex for inscribed polygons and a side midpoint for circumscribed polygons',()=>{
 for(const tool of ['inscribed-polygon','circumscribed-polygon'] as const){
  const c=sketchVariantContour(tool,[[0,0],[10,0]],5);
  if(c.type!=='path')throw Error('path');
  expect(c.segments).toHaveLength(5);
  if(tool==='inscribed-polygon')expect(Math.hypot(...c.start)).toBeCloseTo(10);
  else{const b=c.segments[0].end;expect((b[0]+c.start[0])/2).toBeCloseTo(10);expect((b[1]+c.start[1])/2).toBeCloseTo(0);}
  validateSketchDrawing({type:'drawing',contours:[c]});
 }
 expect(()=>sketchVariantContour('inscribed-polygon',[[0,0],[5,0]],2)).toThrow('3 to 100');
});
it('keeps ellipses and cubic Beziers as exact curve segments',()=>{
 const ellipse=sketchVariantContour('ellipse',[[0,0],[10,0],[0,3]]);
 if(ellipse.type!=='path')throw Error('path');
 expect(ellipse.segments).toHaveLength(2);expect(ellipse.segments[0].type).toBe('ellipse');
 validateSketchDrawing({type:'drawing',contours:[ellipse]});
 const bezier=sketchVariantContour('cubic-bezier',[[0,0],[0,10],[10,10],[10,0]]);
 validateSketchDrawing({type:'drawing',contours:[bezier]});
 expect(()=>sketchVariantContour('ellipse',[[0,0],[10,0],[3,0]])).toThrow('minor radius');
});
