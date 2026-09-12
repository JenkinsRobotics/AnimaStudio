import { applyDocumentUnits } from "./document-preferences";
import { createRequire } from 'node:module';
import { beforeAll,beforeEach,afterEach,afterAll,expect,it,vi } from 'vitest';
import { createEmptyPartDocument, serializePartDocument, parsePartDocument } from '@aether/core/document';
import { contourClosed } from '@aether/core/sketch';
import { cadCommands } from './cad-command-registry';
const require=createRequire(new URL('../../core/ui/package.json',import.meta.url));
const {JSDOM}=require('jsdom');
let dom,open,doc,apply;
beforeAll(async()=>{
 dom=new JSDOM('<!doctype html><html><body></body></html>',{url:'http://localhost/cad/index.html'});
 for(const key of ['window','document','HTMLElement','CustomEvent','Event','location'])vi.stubGlobal(key,dom.window[key]);
 open=(await import('./sketch-workspace')).openSketchWorkspace;
});
beforeEach(()=>{document.body.innerHTML='<div class="cad-studio-viewport"></div>';doc=createEmptyPartDocument('Wheel');apply=vi.fn(async next=>{doc=next;});});
afterEach(()=>{document.querySelector('.cad-sketch-workspace')?.querySelectorAll('button').forEach(b=>{if(b.textContent==='Cancel')b.click();});});
afterAll(()=>{dom.window.close();vi.unstubAllGlobals();});
const click=label=>{const b=[...document.querySelectorAll('button')].find(b=>b.textContent===label&&!b.closest('[hidden]'));expect(b).toBeTruthy();b.click();};
const tool=name=>window.dispatchEvent(new CustomEvent('aether-sketch-tool',{detail:name}));
const point=(x,y)=>{document.querySelector('[aria-label="X (mm)"]').value=x;document.querySelector('[aria-label="Y (mm)"]').value=y;click('Place point');};
it('starts from a plane inside the viewport and saves line/arc/circle contours without a dialog',async()=>{
 open(()=>doc,apply);expect(document.querySelector('dialog')).toBeNull();expect(document.querySelector('.cad-studio-viewport .cad-sketch-workspace')).toBeTruthy();
 expect(document.querySelector('.choosing-plane')).toBeTruthy();
 window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XZ'}));
 expect(document.querySelector('.choosing-plane')).toBeNull();
 tool('arc');point(-10,0);point(10,0);point(0,10);tool('line');point(-10,0);
 tool('circle');point(0,4);point(1,4);
 tool('line');point(20,0);point(30,0);
 expect(document.querySelector('[role="status"]').textContent).toContain('2 closed / 1 open');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));const feature=saved.features[0];
 expect(feature.plane).toBe('XZ');expect(feature.profile.contours).toHaveLength(5);expect(feature.profile.contours.filter(c=>!c.construction)).toHaveLength(3);
 expect(feature.profile.contours.filter(contourClosed)).toHaveLength(2);
 expect(feature.profile.contours[0].segments[0].type).toBe('arc');
 expect(document.querySelector('.cad-sketch-workspace')).toBeNull();
 open(()=>doc,apply,feature);expect(document.querySelector('[role="status"]').textContent).toContain('2 closed / 1 open');
});
it('retains a selected face frame, supports undo, and cancel never applies changes',()=>{
 open(()=>doc,apply);
 const frame={originMillimeters:[10,20,30],normal:[0,1,0],xDirection:[1,0,0]};
 window.dispatchEvent(new CustomEvent('aether-sketch-face',{detail:{frame}}));
 tool('rectangle');point(0,0);point(10,10);expect(document.querySelector('[role="status"]').textContent).toContain('1 closed');
 click('Undo');expect(document.querySelector('[role="status"]').textContent).toContain('0 closed');click('Redo');expect(document.querySelector('[role="status"]').textContent).toContain('1 closed');
 click('Cancel');expect(apply).not.toHaveBeenCalled();expect(doc.features).toHaveLength(0);
});
it('feature authoring leaves no duplicate floating Part features box',async()=>{
 const {mountFeatureAuthoring}=await import('./feature-authoring');mountFeatureAuthoring(()=>doc,apply);
 expect(document.querySelector('.feature-authoring')).toBeNull();
 cadCommands.execute('feature-profile');expect(document.querySelector('.cad-sketch-workspace')).toBeTruthy();expect(document.querySelector('dialog')).toBeNull();
});

function move(x,y){
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 // JSDOM has no SVG layout matrix; use a known identity screen→sketch mapping.
 svg.createSVGPoint=()=>({x:0,y:0,matrixTransform(){return {x:this.x,y:this.y};}});
 svg.getScreenCTM=()=>({a:1,b:0,inverse:()=>({})});
 svg.dispatchEvent(new dom.window.MouseEvent('pointermove',{clientX:x,clientY:-y,bubbles:true}));
}
it('previews circle radius on pointer movement and commits only the clicked geometry',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);
 move(3,4);expect(document.querySelector('.sketch-preview-layer circle.sketch-preview').getAttribute('r')).toBe('5');
 expect(document.querySelector('.sketch-preview-dimension').textContent).toContain('Ø 10.00 mm');
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);expect(doc.features).toHaveLength(0);
 move(6,8);expect(document.querySelector('.sketch-preview').getAttribute('r')).toBe('10');
 document.querySelector('svg').dispatchEvent(new dom.window.MouseEvent('click',{clientX:6,clientY:-8,bubbles:true}));
 expect(document.querySelector('.sketch-contour').getAttribute('r')).toBe('10');
 expect(document.querySelector('.sketch-preview-layer')).toBeNull();
 // Hover for the next circle must not create another saved contour.
 move(20,20);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(doc.features[0].profile.contours).toEqual([{type:'circle',center:[0,0],radius:10}]);
});
it('previews lines, chained segments, rectangles and three-point arcs and clears abandoned previews',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);move(10,0);
 expect(document.querySelector('.sketch-preview').getAttribute('x2')).toBe('10');
 point(10,0);move(10,10);expect(document.querySelector('.sketch-preview').getAttribute('x1')).toBe('10');
 expect(document.querySelector('.sketch-preview-dimension').textContent).toContain('90.0°');
 tool('rectangle');expect(document.querySelector('.sketch-preview-layer')).toBeNull();point(0,0);move(20,15);
 expect(document.querySelector('rect.sketch-preview').getAttribute('width')).toBe('20');
 expect(document.querySelector('.sketch-preview-dimension').textContent).toContain('20.00 × 15.00');
 tool('arc');point(-10,0);move(10,0);expect(document.querySelector('line.sketch-preview')).toBeTruthy();point(10,0);move(0,10);
 expect(document.querySelector('path.sketch-preview').getAttribute('d')).toContain('A10 10');
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');svg.dispatchEvent(new dom.window.Event('pointerleave'));
 expect(document.querySelector('.sketch-preview-layer')).toBeNull();move(10,0);
 svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape'}));expect(document.querySelector('.sketch-preview-layer')).toBeNull();
 expect(doc.features).toHaveLength(0);
});
it('applies and saves concentric and radius constraints and requests default planes only during selection',async()=>{
 const selecting=[];const listener=e=>selecting.push(e.detail);window.addEventListener('aether-sketch-plane-selection',listener);
 open(()=>doc,apply);expect(selecting).toEqual([true]);click('Top (XY)');expect(selecting).toEqual([true,false]);
 tool('circle');point(0,0);point(5,0);point(4,4);point(12,4);
 const set=(label,value)=>{const el=document.querySelector(`[aria-label="${label}"]`);el.value=value;el.dispatchEvent(new dom.window.Event('change'));};
 set('Constraint','concentric');set('Entity A',JSON.stringify({contour:0,kind:'circle'}));set('Entity B',JSON.stringify({contour:1,kind:'circle'}));click('Apply constraint');
 set('Constraint','radius');document.querySelector('[aria-label="Constraint value"]').value='10';click('Apply constraint');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const sketch=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(sketch.constraints).toHaveLength(2);expect(sketch.contours[0].radius).toBeCloseTo(10,5);
 expect(sketch.contours[0].center[0]).toBeCloseTo(sketch.contours[1].center[0],5);
 expect(sketch.contours[0].center[1]).toBeCloseTo(sketch.contours[1].center[1],5);
 window.removeEventListener('aether-sketch-plane-selection',listener);
 open(()=>doc,apply,doc.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('concentric');
});

it('previews and saves all added drawing variants, rejects degenerate input, and reopens them',async()=>{
 open(()=>doc,apply);click('Top (XY)');
 tool('midpoint-line');point(0,0);move(10,5);
 expect(document.querySelector('.sketch-preview-layer path').getAttribute('d')).toContain('M-10,5L10,-5');
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);
 point(10,5);
 tool('center-rectangle');point(30,0);point(35,4);
 tool('aligned-rectangle');point(50,0);point(54,3);point(48,4);
 tool('three-point-circle');point(70,0);point(75,5);point(80,0);
 tool('center-arc');point(90,0);point(95,0);point(90,5);
 tool('inscribed-polygon');document.querySelector('[aria-label="Polygon sides"]').value='5';point(110,0);point(115,0);
 tool('circumscribed-polygon');point(130,0);point(135,0);
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(17);
 tool('three-point-circle');point(0,20);point(1,20);point(2,20);
 expect(document.querySelector('[role="status"]').textContent).toContain('collinear');
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(17);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0];
 expect(saved.profile.contours).toHaveLength(17);expect(saved.profile.contours[12].segments).toHaveLength(5);
 expect(saved.profile.constraints).toHaveLength(35);expect(saved.profile.contours.filter(c=>c.construction)).toHaveLength(10);
 open(()=>doc,apply,saved);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(17);
});
it('shows ellipse and cubic curve previews and persists edited Bezier control points',async()=>{
 open(()=>doc,apply);click('Top (XY)');
 tool('ellipse');point(0,0);point(10,0);move(0,3);
 expect(document.querySelector('.sketch-preview-layer path').getAttribute('d')).toContain('A10 3');point(0,3);
 tool('cubic-bezier');point(20,0);point(20,10);point(30,10);move(30,0);
 expect(document.querySelector('.sketch-preview-layer path').getAttribute('d')).toContain('C20,-10 30,-10 30,0');point(30,0);
 const a=document.querySelector('[aria-label="Entity A"]');
 a.value=JSON.stringify({contour:1,kind:'point',index:0,control:0});
 expect(a.value).not.toBe('');
 document.querySelector('[aria-label="X (mm)"]').value=22;document.querySelector('[aria-label="Y (mm)"]').value=12;
 click('Set selected point / circle center');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0];
 expect(saved.profile.contours[1].segments[0].controls[0]).toEqual([22,12]);
 open(()=>doc,apply,saved);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
});
it('Plane command opens real offset controls and saves a construction feature',async()=>{
 dom.window.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','');};
 dom.window.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open');};
 const {mountFeatureAuthoring}=await import('./feature-authoring');mountFeatureAuthoring(()=>doc,apply);
 cadCommands.execute('feature-plane');
 // Planes create instantly (auto-named) and edit in a floating window — no modal.
 await vi.waitFor(()=>expect(doc.features).toHaveLength(1));
 expect(doc.features[0]).toMatchObject({type:'plane',name:'Plane 1',plane:'XY',offsetMillimeters:10});
 expect(document.querySelector('dialog')).toBeNull();
 const win=document.querySelector('.cad-plane-window');expect(win).toBeTruthy();
 // The Entities list starts EMPTY — a new plane pre-selects nothing — so the
 // reference is picked before the offset can be applied.
 expect(win.querySelector('.aui-feature-entity')).toBeNull();
 window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
 expect(win.querySelector('.aui-feature-entity').textContent).toContain('Top plane');
 win.querySelector('[aria-label="Offset distance"]').value='25';
 win.querySelector('[aria-label="Apply plane"]').click();
 await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));
 const saved=parsePartDocument(serializePartDocument(doc));
 expect(saved.features[0]).toMatchObject({type:'plane',plane:'XY',offsetMillimeters:25,definition:{method:'offset',distanceMillimeters:25}});
 expect(document.querySelector('.cad-plane-window')).toBeNull();
});
it('starts a sketch on a saved offset construction plane and preserves its frame on reopen',async()=>{
 doc.features.push({id:'plane',type:'plane',name:'Plane 1',plane:'XZ',offsetMillimeters:25,suppressed:false});
 open(()=>doc,apply);click('Plane 1');tool('circle');point(0,0);point(5,0);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));
 expect(saved.features[1].frame).toEqual({originMillimeters:[0,-25,0],normal:[0,-1,0],xDirection:[1,0,0]});
 open(()=>doc,apply,saved.features[1]);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
});
it('previews and commits mirror/pattern/transform operations with undo and persistence',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(5,0);point(6,0);
 tool('mirror');expect(document.querySelector('.sketch-modification-preview circle').getAttribute('cx')).toBe('-5');
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Apply modification');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');
 tool('linear-pattern');click('Apply modification');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(6);
 tool('circular-pattern');click('Cancel modification');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(6);
 tool('transform');expect([...document.querySelectorAll('button')].find(b=>b.textContent==='Apply modification').disabled).toBe(true);expect(document.querySelector('.sketch-modifications').textContent).toContain('conflicts with an existing constraint');click('Cancel modification');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours).toHaveLength(6);
 expect(saved.features[0].profile.contours[0].center).toEqual([5,0]);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(6);
});
it('creates sketch points and toggles persisted construction geometry',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('point');move(3,4);expect(document.querySelector('.sketch-preview-layer')).toBeTruthy();point(3,4);
 tool('circle');point(0,0);point(10,0);
 const buttons=[...document.querySelectorAll('button')].filter(b=>b.textContent==='Make construction');buttons[1].click();
 expect(document.querySelector('.sketch-contour.construction')).toBeTruthy();
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(doc.features[0].profile.contours[0]).toMatchObject({start:[3,4],segments:[]});expect(doc.features[0].profile.contours[1].construction).toBe(true);
});
it('trims a clicked straight segment with a reversible preview and undo',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(10,0);click('New contour');point(-3,-5);point(-3,5);click('New contour');point(3,-5);point(3,5);
 tool('trim');move(0,0);expect(document.querySelector('.sketch-preview-layer')).toBeTruthy();point(0,0);
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(4);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);
});
it('selects a circular arc for a persisted radius constraint through the extracted panel',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');point(5,0);point(0,5);point(3,4);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'radius'}));
 const selector=document.querySelector('[aria-label="Entity A"]');selector.value=JSON.stringify({contour:0,kind:'arc',index:0});expect(selector.value).not.toBe('');
 document.querySelector('[aria-label="Constraint value"]').value='8';click('Apply constraint');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0]).toMatchObject({kind:'radius',value:8,a:{kind:'arc'}});
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('radius 8');
});
it('splits a Bezier from the ribbon tool with preview, undo and native persistence',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('cubic-bezier');point(0,0);point(0,10);point(10,10);point(10,0);
 tool('split');move(5,7.5);expect(document.querySelector('.sketch-preview-layer')).toBeTruthy();point(5,7.5);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0].segments).toHaveLength(2);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(2);
});
it('splits circles with two clicks and persists the two exact arc segments',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(5,0);
 tool('split');point(5,0);expect(document.querySelector('[role="status"]').textContent).toContain('second position');
 move(0,5);expect(document.querySelector('.sketch-preview-layer')).toBeTruthy();point(0,5);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0].segments.map(s=>s.type)).toEqual(['arc','arc']);
});
it('extends to a second clicked endpoint when no intersecting boundary exists',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(5,0);
 tool('extend');point(4.9,0);expect(document.querySelector('[role="status"]').textContent).toContain('new endpoint');
 move(10,2);expect(document.querySelector('.sketch-preview-layer')).toBeTruthy();point(10,2);
 expect(document.querySelector('.sketch-contour').getAttribute('d')).toContain('L10,0');
 click('Undo');expect(document.querySelector('.sketch-contour').getAttribute('d')).toContain('L5,0');
});
it('trims a cubic interval with preview, undo, and exact native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('cubic-bezier');point(0,0);point(0,10);point(10,10);point(10,0);
 tool('line');click('New contour');point(2,-1);point(2,10);click('New contour');point(8,-1);point(8,10);
 tool('trim');move(5,7.5);expect(document.querySelector('.sketch-preview-layer')).toBeTruthy();expect(doc.features).toHaveLength(0);point(5,7.5);
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(4);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));const contours=saved.features[0].profile.contours;
 expect(contours.slice(0,2).map(c=>c.segments[0].type)).toEqual(['bezier','bezier']);
 expect(contours[0].segments[0].end[0]).toBeCloseTo(2);expect(contours[1].start[0]).toBeCloseTo(8);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(4);
});
it('extends an arc in place with a second-click preview and native persistence',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');point(5,0);point(0,5);point(3,4);
 tool('extend');point(0,5);expect(document.querySelector('[role="status"]').textContent).toContain('new endpoint');
 move(-5,0);expect(document.querySelector('.sketch-preview-layer')).toBeTruthy();point(-5,0);
 click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));const segment=saved.features[0].profile.contours[0].segments[0];
 expect(segment.type).toBe('arc');expect(segment.end[0]).toBeCloseTo(-5);expect(segment.end[1]).toBeCloseTo(0);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-contour').getAttribute('d')).toContain('A');
});
it('extends a radius-constrained arc and preserves the relation through save and reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');point(5,0);point(0,5);point(3,4);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'radius'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'arc',index:0});
 document.querySelector('[aria-label="Constraint value"]').value='5';click('Apply constraint');
 tool('extend');point(0,5);point(-5,0);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0]).toMatchObject({kind:'radius',value:5});
 expect(saved.features[0].profile.contours[0].segments[0].end[0]).toBeCloseTo(-5);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('radius 5');
});
it('splits a dimensioned arc and persists its shared circular relations',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');point(5,0);point(0,5);point(3,4);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'radius'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'arc',index:0});
 document.querySelector('[aria-label="Constraint value"]').value='5';click('Apply constraint');
 tool('split');point(3,4);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0].segments).toHaveLength(2);
 expect(saved.features[0].profile.constraints.map(c=>c.kind)).toEqual(['radius','concentric','equal']);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('radius 5');
});
it('splits a dimensioned line and saves its overall length relation',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'length'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'line',index:0});
 document.querySelector('[aria-label="Constraint value"]').value='10';click('Apply constraint');
 tool('split');point(4,0);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0]).toMatchObject({kind:'distance',value:10,a:{index:0},b:{index:2}});
 expect(saved.features[0].profile.constraints[1].kind).toBe('parallel');
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('distance 10');
});
it('trims a dimensioned circle and preserves its radius through native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(5,0);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'radius'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'circle'});
 document.querySelector('[aria-label="Constraint value"]').value='5';click('Apply constraint');
 tool('line');point(0,-10);point(0,10);tool('trim');point(5,0);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0]).toMatchObject({kind:'radius',value:5,a:{kind:'arc',index:0}});
 expect(saved.features[0].profile.contours[0].segments[0].type).toBe('arc');
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('radius 5');
});
it('reports constraints removed by path Trim and restores them on undo',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(10,0);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'length'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'line',index:0});
 document.querySelector('[aria-label="Constraint value"]').value='20';click('Apply constraint');
 tool('line');click('New contour');point(-3,-5);point(-3,5);click('New contour');point(3,-5);point(3,5);
 tool('trim');point(0,0);expect(document.querySelector('[role="status"]').textContent).toContain('removed 1 constraint');
 click('Undo');expect(document.querySelector('.sketch-constraints').textContent).toContain('length 20');
});
it('trims an arc interval and saves the retained radius and shared-circle links',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');point(5,0);point(-5,0);point(0,5);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'radius'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'arc',index:0});
 document.querySelector('[aria-label="Constraint value"]').value='5';click('Apply constraint');
 tool('line');click('New contour');point(2,-1);point(2,6);click('New contour');point(-2,-1);point(-2,6);
 tool('trim');point(0,5);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.map(c=>c.kind)).toEqual(['concentric','coincident','coincident','coincident','radius','concentric','equal']);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('radius 5');
});
it('sweeps Trim across several lines as one undoable gesture',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-5,-5);point(-5,5);click('New contour');point(0,-5);point(0,5);click('New contour');point(5,-5);point(5,5);
 tool('trim');move(-10,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 svg.dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:-10,clientY:0,button:0,bubbles:true}));
 move(10,0);svg.dispatchEvent(new dom.window.MouseEvent('pointerup',{clientX:10,clientY:0,button:0,bubbles:true}));
 svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:10,clientY:0,bubbles:true}));
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);click('Redo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);
});
it('cancels a Trim stroke without keeping its temporary deletions',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,-5);point(0,5);tool('trim');move(-10,0);
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');svg.dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:-10,clientY:0,button:0,bubbles:true}));move(10,0);
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);svg.dispatchEvent(new dom.window.Event('pointercancel'));expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
});
it('sweeps an isolated point with pixel tolerance and restores it on undo',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('point');point(0,0);tool('trim');move(-10,0.2);
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');svg.dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:-10,clientY:-0.2,button:0,bubbles:true}));move(10,0.2);svg.dispatchEvent(new dom.window.MouseEvent('pointerup',{clientX:10,clientY:-0.2,button:0,bubbles:true}));
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
});
it('previews and applies a picked corner fillet with radius and native persistence',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);point(0,10);tool('fillet');point(0,0);
 const radius=document.querySelector('[aria-label="Fillet radius (mm)"]');radius.value='2';radius.dispatchEvent(new dom.window.Event('input',{bubbles:true}));expect(document.querySelector('.sketch-modification-preview')).toBeTruthy();expect(doc.features).toHaveLength(0);
 click('Apply modification');click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('radius 2');click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0].segments[1].type).toBe('arc');expect(saved.features[0].profile.constraints.some(c=>c.kind==='radius'&&c.value===2)).toBe(true);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('radius 2');
});
it('selects several fillet corners and saves a single driving radius',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(20,20);tool('fillet');point(0,0);point(20,20);
 const radius=document.querySelector('[aria-label="Fillet radius (mm)"]');radius.value='2';radius.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
 expect(document.querySelector('.sketch-modifications').textContent).toContain('2 corners selected');click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.filter(c=>c.kind==='radius')).toHaveLength(1);expect(saved.features[0].profile.constraints.some(c=>c.kind==='equal')).toBe(true);
 expect(saved.features[0].profile.contours[0].segments.filter(s=>s.type==='arc')).toHaveLength(2);
});
it('fillets two separately drawn lines by picking each curve',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);click('New contour');point(0,0);point(0,10);tool('fillet');point(-5,0);expect(document.querySelector('.sketch-modifications').textContent).toContain('First curve selected');point(0,5);
 const radius=document.querySelector('[aria-label="Fillet radius (mm)"]');radius.value='2';radius.dispatchEvent(new dom.window.Event('input',{bubbles:true}));click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0].segments.map(s=>s.type)).toEqual(['line','arc','line']);
});
it('fillets disjoint selected lines by extending to their intersection',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(-2,0);click('New contour');point(0,2);point(0,10);tool('fillet');point(-6,0);point(0,6);click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0].segments.map(s=>s.type)).toEqual(['line','arc','line']);
});
it('drags the fillet radius handle without committing until Apply',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);point(0,10);tool('fillet');point(0,0);move(0,0);
 const handle=document.querySelector('[aria-label="Fillet radius handle"]'),hx=Number(handle.getAttribute('cx')),hy=Number(handle.getAttribute('cy'));
 handle.dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:hx,clientY:hy,button:0,bubbles:true}));move(hx*2,-hy*2);
 expect(Number(document.querySelector('[aria-label="Fillet radius (mm)"]').value)).toBeCloseTo(2);expect(doc.features).toHaveLength(0);
 document.querySelector('svg').dispatchEvent(new dom.window.Event('pointercancel'));
 expect(Number(document.querySelector('[aria-label="Fillet radius (mm)"]').value)).toBeCloseTo(1);expect(doc.features).toHaveLength(0);
});
it('reopens a fillet and edits its existing radius through the Fillet panel',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);point(0,10);tool('fillet');point(0,0);click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const feature=parsePartDocument(serializePartDocument(doc)).features[0],arc=feature.profile.contours[0].segments[1];
 open(()=>doc,apply,feature);tool('fillet');point(arc.middle[0],arc.middle[1]);expect(document.querySelector('.sketch-modifications').textContent).toContain('Editing an existing fillet');expect(document.querySelector('[aria-label="Fillet radius handle"]')).toBeTruthy();
 const radius=document.querySelector('[aria-label="Fillet radius (mm)"]');radius.value='2';radius.dispatchEvent(new dom.window.Event('input',{bubbles:true}));click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));
 expect(doc.features[0].profile.constraints.filter(c=>c.kind==='radius')).toHaveLength(1);expect(doc.features[0].profile.constraints.find(c=>c.kind==='radius').value).toBe(2);
});
it('authors and reopens a finite line-to-Bezier tangent join',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);tool('cubic-bezier');point(10,0);point(12,2);point(15,5);point(20,5);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'tangent'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'curve',index:0,parameter:1});
 document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:1,kind:'curve',index:0,parameter:0});click('Apply constraint');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0]).toMatchObject({kind:'tangent',a:{kind:'curve',parameter:1},b:{kind:'curve',parameter:0}});
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('tangent');
});

it('previews, applies, undoes and saves a line-to-cubic fillet with tangent constraints',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);
 tool('cubic-bezier');point(0,0);point(1,3);point(2,7);point(0,10);
 tool('fillet');point(-5,0);point(1.125,5);
 expect(document.querySelector('.sketch-modification-preview')).toBeTruthy();
 click('Apply modification');click('Undo');click('Redo');click('Finish sketch');
 await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)),profile=saved.features[0].profile;
 expect(profile.contours[0].segments.map(s=>s.type)).toEqual(['line','arc','bezier']);
 expect(profile.constraints.filter(c=>c.kind==='tangent')).toHaveLength(2);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('[role="status"]').textContent).toContain('1 open');
});

it('fillets a picked curved corner in a reopened closed profile while preserving the surrounding path',async()=>{
 const feature={id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[-10,0],segments:[{type:'line',end:[0,0]},{type:'bezier',controls:[[1,3],[2,7]],end:[0,10]},{type:'line',end:[-10,10]},{type:'line',end:[-10,0]}]}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('fillet');point(0,0);
 expect(document.querySelector('.sketch-modifications').textContent).toContain('1 corner selected');
 expect(document.querySelector('.sketch-modification-preview')).toBeTruthy();click('Apply modification');
 expect(document.querySelector('[role="status"]').textContent).toContain('Sketch modification applied');click('Finish sketch');
 await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));
 const path=saved.features[0].profile.contours[0];expect(path.segments.map(s=>s.type)).toEqual(['line','arc','bezier','line','line']);expect(contourClosed(path)).toBe(true);
});
it('batches curved corners and reopens their shared radius with a visible handle',async()=>{
 const feature={id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[-10,0],segments:[{type:'line',end:[0,0]},{type:'bezier',controls:[[1,3],[2,7]],end:[0,10]},{type:'line',end:[-10,10]},{type:'line',end:[-10,0]}]}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('fillet');point(0,0);point(0,10);
 expect(document.querySelector('.sketch-modifications').textContent).toContain('2 corners selected');
 const radius=document.querySelector('[aria-label="Fillet radius (mm)"]');radius.value='.5';radius.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
 click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const saved=doc.features[0],profile=saved.profile;
 expect(profile.constraints.filter(c=>c.kind==='radius')).toHaveLength(1);expect(profile.constraints.filter(c=>c.kind==='equal')).toHaveLength(1);
 const arc=profile.contours[0].segments.find(s=>s.type==='arc');open(()=>doc,apply,saved);tool('fillet');point(...arc.middle);
 expect(document.querySelector('.sketch-modifications').textContent).toContain('Editing an existing fillet');
 expect(document.querySelector('[aria-label="Fillet radius handle"]')).toBeTruthy();
 const edit=document.querySelector('[aria-label="Fillet radius (mm)"]');edit.value='.6';edit.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
 click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));
 const again=parsePartDocument(serializePartDocument(doc));expect(again.features[0].profile.constraints.find(c=>c.kind==='radius').value).toBe(.6);
});
it('previews a two-distance chamfer in the workspace and saves its dimensions through undo and reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(10,10);tool('chamfer');point(10,0);
 const mode=document.querySelector('[aria-label="Chamfer mode"]');mode.value='two-distances';mode.dispatchEvent(new dom.window.Event('change',{bubbles:true}));
 for(const [name,value] of [['Chamfer distance (mm)','2'],['Second chamfer distance (mm)','3']]){const input=document.querySelector(`[aria-label="${name}"]`);input.value=value;input.dispatchEvent(new dom.window.Event('input',{bubbles:true}));}
 expect(document.querySelector('.sketch-chamfer-preview')).toBeTruthy();expect(doc.features).toHaveLength(0);click('Apply chamfer');click('Undo');click('Redo');click('Finish sketch');
 await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)),profile=saved.features[0].profile;
 expect(profile.contours[0].segments).toHaveLength(5);expect(profile.contours[0].segments[0].end).toEqual([8,0]);expect(profile.contours[0].segments[1].end).toEqual([10,3]);
 expect(profile.constraints.filter(c=>c.kind==='distance').map(c=>c.value)).toEqual([2,3]);
});
it('rejects an oversized chamfer preview and cancels without changing the sketch',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(10,10);tool('chamfer');point(10,0);
 const distance=document.querySelector('[aria-label="Chamfer distance (mm)"]');distance.value='20';distance.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
 expect(document.querySelector('.sketch-chamfer-preview')).toBeNull();expect(document.querySelector('.sketch-chamfer-controls').textContent).toContain('too large');
 expect([...document.querySelectorAll('button')].find(b=>b.textContent==='Apply chamfer').disabled).toBe(true);click('Cancel chamfer');expect(apply).not.toHaveBeenCalled();
});
it('edits a reopened equal-distance chamfer through its linked dimension',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(10,10);tool('chamfer');point(10,0);click('Apply chamfer');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const feature=doc.features[0];expect(feature.profile.constraints.some(c=>c.valueFrom)).toBe(true);open(()=>doc,apply,feature);
 const row=[...document.querySelectorAll('.sketch-constraints div')].find(r=>r.textContent.includes('(linked)')&&r.querySelector(':scope > input'));
 expect(row).toBeTruthy();row.querySelector('input').value='2';[...row.querySelectorAll('button')].find(b=>b.textContent==='Update').click();click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));
 const saved=parsePartDocument(serializePartDocument(doc)),dimensions=saved.features[0].profile.constraints.filter(c=>c.kind==='distance');expect(dimensions.find(c=>!c.valueFrom).value).toBe(2);expect(dimensions.find(c=>c.valueFrom).value).toBeUndefined();
});
it('chamfers two independently drawn lines by selecting their retained sides',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(-2,0);click('New contour');point(0,2);point(0,10);tool('chamfer');point(-6,0);
 expect(document.querySelector('.sketch-chamfer-controls').textContent).toContain('First line selected');point(0,6);expect(document.querySelector('.sketch-chamfer-preview')).toBeTruthy();
 click('Apply chamfer');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)),path=saved.features[0].profile.contours[0];expect(path.segments.map(s=>s.end)).toEqual([[-1,0],[0,1],[0,10]]);
});
it('batches picked chamfer corners with shared saved dimensions',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(10,10);tool('chamfer');point(10,0);point(0,10);
 expect(document.querySelector('.sketch-chamfer-controls').textContent).toContain('2 corners selected');click('Apply chamfer');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)),profile=saved.features[0].profile;expect(profile.contours[0].segments).toHaveLength(6);expect(profile.constraints.filter(c=>c.kind==='distance'&&c.value!==undefined)).toHaveLength(1);
});
it('deselects a drawing tool into immediate selection and clears selected geometry on empty space',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(10,10);tool('rectangle');point(5,0);expect(document.querySelector('.sketch-selection')).toBeTruthy();point(40,40);expect(document.querySelector('.sketch-selection')).toBeNull();
 tool('circle');point(20,20);const svg=document.querySelector('[aria-label="2D sketch canvas"]');svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));point(0,0);expect(document.querySelector('.sketch-selection')).toBeTruthy();expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
});
it('drags an existing sketch edge after Escape and commits one undo step',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));move(5,0);
 const pointer=(type,x,y)=>{const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:8});svg.dispatchEvent(event);};pointer('pointerdown',5,0);pointer('pointermove',7,3);pointer('pointerup',7,3);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const path=doc.features[0].profile.contours[0];expect(path.start).toEqual([2,3]);expect(path.segments[0].end).toEqual([12,3]);
});
it('shows geometric constraint state and remaining degrees of freedom',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(5,0);expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('3 degrees of freedom');
 const select=(name,value)=>{const input=document.querySelector(`[aria-label="${name}"]`);input.value=value;input.dispatchEvent(new dom.window.Event('change'));};
 select('Constraint','fix');select('Entity A',JSON.stringify({contour:0,kind:'point',index:0}));click('Apply constraint');select('Constraint','radius');select('Entity A',JSON.stringify({contour:0,kind:'circle'}));document.querySelector('[aria-label="Constraint value"]').value='5';click('Apply constraint');
 expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('Fully constrained');
});

it('preserves rectangle constraints through pointer editing, undo and native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(10,10);
 expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('4 degrees of freedom');
 tool('rectangle');move(10,10);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 const pointer=(type,x,y)=>{const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:9});svg.dispatchEvent(event);};
 pointer('pointerdown',10,10);pointer('pointermove',14,13);pointer('pointerup',14,13);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const saved=doc.features[0],path=saved.profile.contours[0];
 expect(saved.profile.constraints.map(c=>c.kind)).toEqual(['horizontal','vertical','horizontal','vertical']);
 expect(path.segments[1].end[0]).toBeCloseTo(14);expect(path.segments[1].end[1]).toBeCloseTo(13);
 expect(path.segments[0].end[1]).toBeCloseTo(path.start[1]);expect(path.segments[2].end[0]).toBeCloseTo(path.start[0]);
 open(()=>doc,apply,saved);expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('4 degrees of freedom');
});

it('persists regular polygon sizing constraints through editing, undo and native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circumscribed-polygon');document.querySelector('[aria-label="Polygon sides"]').value='4';point(0,0);point(10,0);
 expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('4 degrees of freedom');
 const select=(name,value)=>{const input=document.querySelector(`[aria-label="${name}"]`);input.value=value;input.dispatchEvent(new dom.window.Event('change'));};
 select('Constraint','radius');select('Entity A',JSON.stringify({contour:2,kind:'circle'}));document.querySelector('[aria-label="Constraint value"]').value='10';click('Apply constraint');
 const row=[...document.querySelectorAll('.sketch-constraints div')].find(r=>r.querySelector(':scope > input[aria-label="radius value"]'));expect(row).toBeTruthy();row.querySelector('input').value='12';[...row.querySelectorAll('button')].find(b=>b.textContent==='Update').click();
 click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const feature=doc.features[0],profile=feature.profile;
 expect(profile.contours[2].radius).toBeCloseTo(12);expect(profile.contours.slice(1).every(c=>c.construction)).toBe(true);
 expect(profile.constraints.filter(c=>c.kind==='equal')).toHaveLength(3);
 const path=profile.contours[0],a=path.start,b=path.segments[0].end,c=path.segments[1].end;
 expect((b[0]-a[0])*(c[0]-b[0])+(b[1]-a[1])*(c[1]-b[1])).toBeCloseTo(0,4);
 open(()=>doc,apply,feature);expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('3 degrees of freedom');
});

it('retains the midpoint-line center through fixed-center pointer editing and native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('midpoint-line');point(0,0);point(10,0);
 const select=(name,value)=>{const input=document.querySelector(`[aria-label="${name}"]`);input.value=value;input.dispatchEvent(new dom.window.Event('change'));};
 select('Constraint','fix');select('Entity A',JSON.stringify({contour:1,kind:'point',index:0}));click('Apply constraint');
 tool('midpoint-line');move(10,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 const pointer=(type,x,y)=>{const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:10});svg.dispatchEvent(event);};
 pointer('pointerdown',10,0);pointer('pointermove',14,3);pointer('pointerup',14,3);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const feature=doc.features[0],path=feature.profile.contours[0];
 expect(path.start[0]).toBeCloseTo(-14);expect(path.start[1]).toBeCloseTo(-3);expect(path.segments[0].end[0]).toBeCloseTo(14);expect(path.segments[0].end[1]).toBeCloseTo(3);
 expect(feature.profile.constraints.map(c=>c.kind)).toEqual(['midpoint','fix']);
 open(()=>doc,apply,feature);expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('2 degrees of freedom');
});

it('retains and edits three-point circle placement through undo and native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('three-point-circle');point(5,0);point(0,5);point(-5,0);
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(4);
 const select=(name,value)=>{const input=document.querySelector(`[aria-label="${name}"]`);input.value=value;input.dispatchEvent(new dom.window.Event('change'));};
 select('Constraint','fix');for(const contour of [1,3]){select('Entity A',JSON.stringify({contour,kind:'point',index:0}));click('Apply constraint');}
 tool('three-point-circle');move(0,5);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 const pointer=(type,x,y)=>{const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:11});svg.dispatchEvent(event);};
 pointer('pointerdown',0,5);pointer('pointermove',0,9);pointer('pointerup',0,9);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const feature=doc.features[0],circle=feature.profile.contours[0];
 expect(circle.center[0]).toBeCloseTo(0);expect(circle.center[1]).toBeCloseTo(28/9);expect(circle.radius).toBeCloseTo(53/9);
 expect(feature.profile.constraints.filter(c=>c.kind==='coincident')).toHaveLength(3);
 open(()=>doc,apply,feature);expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('2 degrees of freedom');
});

it('preserves the center of a center-point arc through radius editing and native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('center-arc');point(0,0);point(5,0);point(0,5);
 const select=(name,value)=>{const input=document.querySelector(`[aria-label="${name}"]`);input.value=value;input.dispatchEvent(new dom.window.Event('change'));};
 select('Constraint','fix');select('Entity A',JSON.stringify({contour:1,kind:'point',index:0}));click('Apply constraint');
 select('Constraint','radius');select('Entity A',JSON.stringify({contour:0,kind:'arc',index:0}));document.querySelector('[aria-label="Constraint value"]').value='5';click('Apply constraint');
 const row=[...document.querySelectorAll('.sketch-constraints div')].find(r=>r.querySelector(':scope > input[aria-label="radius value"]'));row.querySelector('input').value='7';[...row.querySelectorAll('button')].find(b=>b.textContent==='Update').click();
 click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));doc=parsePartDocument(serializePartDocument(doc));const feature=doc.features[0],path=feature.profile.contours[0];
 const {sketchArcGeometry}=await import('@aether/core/sketch');const arc=sketchArcGeometry(path.start,path.segments[0].middle,path.segments[0].end);
 expect(arc.center[0]).toBeCloseTo(0);expect(arc.center[1]).toBeCloseTo(0);expect(arc.radius).toBeCloseTo(7);
 expect(feature.profile.contours[1].construction).toBe(true);expect(feature.profile.constraints.some(c=>c.kind==='concentric')).toBe(true);
 open(()=>doc,apply,feature);expect(document.querySelector('[aria-label="Sketch constraint state"]').textContent).toContain('2 degrees of freedom');
});
it('previews and commits tangent arcs into a closed path with undo and native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);tool('tangent-arc');point(0,0);move(5,5);
 const preview=document.querySelector('.sketch-preview-layer path');expect(preview).toBeTruthy();expect(preview.getAttribute('d')).toContain('A');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
 point(5,5);click('Undo');click('Redo');tool('line');point(-10,5);point(-10,0);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const feature=doc.features[0],profile=feature.profile,path=profile.contours[0];
 expect(profile.contours).toHaveLength(1);expect(path.segments.map(s=>s.type)).toEqual(['line','arc','line','line']);expect(contourClosed(path)).toBe(true);
 expect(profile.constraints).toHaveLength(1);expect(profile.constraints[0]).toMatchObject({kind:'tangent',a:{kind:'curve',parameter:1,index:0},b:{kind:'curve',parameter:0,index:1}});
 open(()=>doc,apply,feature);expect(document.querySelector('.sketch-constraints').textContent).toContain('tangent');
});
it('rejects tangent arc placement away from endpoints and degenerate previews',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);tool('tangent-arc');point(30,30);
 expect(document.querySelector('[role="status"]').textContent).toContain('existing line or curve endpoint');point(0,0);move(5,0);
 expect(document.querySelector('.sketch-preview-layer path')).toBeNull();point(5,0);expect(document.querySelector('[role="status"]').textContent).toContain('tangent line');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
});
it('places a tangent arc by dragging and releasing as one undo transaction',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);tool('tangent-arc');move(0,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 const pointer=(type,x,y)=>{const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:12});svg.dispatchEvent(event);};
 pointer('pointerdown',0,0);pointer('pointermove',5,5);expect(document.querySelector('.sketch-preview-layer path').getAttribute('d')).toContain('A');expect(document.querySelector('.sketch-contour').getAttribute('d')).not.toContain('A');
 pointer('pointerup',5,5);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:5,clientY:-5,bubbles:true}));expect(document.querySelector('.sketch-contour').getAttribute('d')).toContain('A');
 click('Undo');expect(document.querySelector('.sketch-contour').getAttribute('d')).not.toContain('A');click('Redo');expect(document.querySelector('.sketch-contour').getAttribute('d')).toContain('A');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0].segments).toHaveLength(2);expect(saved.features[0].profile.constraints).toHaveLength(1);
});
it('cancels tangent arc drags without adding geometry or undo steps',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);tool('tangent-arc');move(0,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 const pointer=(type,x,y)=>{const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:13});svg.dispatchEvent(event);};
 pointer('pointerdown',0,0);pointer('pointermove',5,5);pointer('pointercancel',5,5);expect(document.querySelector('.sketch-preview-layer')).toBeNull();expect(document.querySelector('.sketch-contour').getAttribute('d')).not.toContain('A');
 pointer('pointerdown',0,0);pointer('pointermove',5,5);svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));pointer('pointerup',5,5);expect(document.querySelector('.sketch-preview-layer')).toBeNull();
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);
});
it('retains the two-click tangent arc workflow with real pointer events',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);tool('tangent-arc');move(0,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 const clickAt=(x,y)=>{for(const type of ['pointerdown','pointerup','click']){const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:14});svg.dispatchEvent(event);}};
 clickAt(0,0);move(5,5);expect(document.querySelector('.sketch-preview-layer path')).toBeTruthy();clickAt(5,5);expect(document.querySelector('.sketch-contour').getAttribute('d')).toContain('A');
});
it('rejects a tangent arc drag released on the tangent line without an undo entry',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);tool('tangent-arc');move(0,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 for(const [type,x] of [['pointerdown',0],['pointermove',5],['pointerup',5]]){const event=new dom.window.MouseEvent(type,{clientX:x,clientY:0,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:15});svg.dispatchEvent(event);}
 expect(document.querySelector('[role="status"]').textContent).toContain('tangent line');expect(document.querySelector('.sketch-contour').getAttribute('d')).not.toContain('A');click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);
});
it('keeps three-point arc endpoints fixed while previewing either side of the chord',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');point(-10,0);point(10,0);move(0,10);
 const above=document.querySelector('path.sketch-preview').getAttribute('d');expect(above).toContain('A10 10');expect(above.endsWith('10,0')).toBe(true);
 move(0,-10);const below=document.querySelector('path.sketch-preview').getAttribute('d');expect(below).not.toBe(above);expect(below.endsWith('10,0')).toBe(true);expect(document.querySelector('.sketch-preview-dimension').textContent).toContain('chord 20.00');
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);point(0,-10);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const path=parsePartDocument(serializePartDocument(doc)).features[0].profile.contours[0];expect(path.start).toEqual([-10,0]);expect(path.segments[0]).toEqual({type:'arc',middle:[0,-10],end:[10,0]});
});
it('closes a line contour by choosing the arc end before its curvature point',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);tool('arc');point(-10,0);move(-5,5);expect(document.querySelector('path.sketch-preview')).toBeTruthy();point(-5,5);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const path=parsePartDocument(serializePartDocument(doc)).features[0].profile.contours[0];expect(contourClosed(path)).toBe(true);expect(path.segments[1]).toEqual({type:'arc',middle:[-5,5],end:[-10,0]});
});
it('rejects coincident arc endpoints and collinear curvature without creating geometry',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');point(0,0);point(0,0);expect(document.querySelector('[role="status"]').textContent).toContain('endpoints must be distinct');
 point(10,0);point(5,0);expect(document.querySelector('[role="status"]').textContent).toContain('collinear');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);
 point(5,5);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);
});
it('drags a three-point arc chord and waits for the curvature click before committing',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');move(-10,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 const pointer=(type,x,y)=>{const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:16});svg.dispatchEvent(event);};
 pointer('pointerdown',-10,0);pointer('pointermove',10,0);expect(document.querySelector('line.sketch-preview')).toBeTruthy();pointer('pointerup',10,0);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:10,clientY:0,bubbles:true}));
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);move(0,10);expect(document.querySelector('path.sketch-preview').getAttribute('d')).toContain('A10 10');point(0,10);
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const path=parsePartDocument(serializePartDocument(doc)).features[0].profile.contours[0];expect(path.start).toEqual([-10,0]);expect(path.segments[0]).toEqual({type:'arc',middle:[0,10],end:[10,0]});
});
it('continues an open line with a dragged arc chord and closes after the curvature click',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(-10,0);point(0,0);tool('arc');move(0,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 for(const [type,x] of [['pointerdown',0],['pointermove',-10],['pointerup',-10]]){const event=new dom.window.MouseEvent(type,{clientX:x,clientY:0,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:17});svg.dispatchEvent(event);}
 move(-5,5);point(-5,5);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const path=parsePartDocument(serializePartDocument(doc)).features[0].profile.contours[0];expect(path.segments.map(s=>s.type)).toEqual(['line','arc']);expect(contourClosed(path)).toBe(true);
});
it('cancels an unfinished dragged chord and preserves ordinary arc endpoint clicks',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');move(-10,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 const pointer=(type,x,y)=>{const event=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(event,'pointerId',{value:18});svg.dispatchEvent(event);};
 pointer('pointerdown',-10,0);pointer('pointermove',10,0);pointer('pointercancel',10,0);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);expect(document.querySelector('.sketch-preview-layer')).toBeNull();
 for(const [x,y] of [[-10,0],[10,0],[0,10]]){pointer('pointerdown',x,y);pointer('pointerup',x,y);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:x,clientY:-y,bubbles:true}));}
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);
});
it.each([
 ['circle',[[0,0],[5,0]],'circle',undefined],
 ['three-point-circle',[[5,0],[0,5],[-5,0]],'circle',undefined],
 ['arc',[[-5,0],[5,0],[0,5]],'arc',0],
 ['center-arc',[[0,0],[5,0],[0,5]],'arc',0],
 ['tangent-arc',[[0,0],[5,5]],'arc',1],
])('adds an immediate saved radius after %s creation',async(name,points,kind,index)=>{
 open(()=>doc,apply);click('Top (XY)');if(name==='tangent-arc'){tool('line');point(-10,0);point(0,0);}tool(name);for(const p of points)point(...p);
 const input=document.querySelector('[aria-label="New curve radius (mm)"]');expect(input.closest('.sketch-recent-radius').hidden).toBe(false);input.value='7';click('Set radius');expect(input.closest('.sketch-recent-radius').hidden).toBe(true);
 click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('radius ·');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const feature=parsePartDocument(serializePartDocument(doc)).features[0],dimensions=feature.profile.constraints.filter(c=>c.kind==='radius');expect(dimensions).toHaveLength(1);expect(dimensions[0].value).toBe(7);
 const {sketchEntityRadius}=await import('@aether/core/sketch');expect(sketchEntityRadius(feature.profile,{contour:0,kind,index})).toBeCloseTo(7);open(()=>doc,apply,feature);expect(document.querySelector('[aria-label="radius value"]').value).toBe('7');
});
it('accepts immediate radius typing from the canvas and rejects invalid values atomically',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(5,0);const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'8',bubbles:true,cancelable:true}));const input=document.querySelector('[aria-label="New curve radius (mm)"]');expect(document.activeElement).toBe(input);expect(input.value).toBe('8');
 input.value='-3';input.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));expect(document.querySelector('[role="status"]').textContent).toContain('positive finite');expect(document.querySelector('.sketch-contour').getAttribute('r')).toBe('5');
 input.value='8';input.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));expect(document.activeElement).toBe(svg);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(doc.features[0].profile.constraints.filter(c=>c.kind==='radius')).toHaveLength(1);
});
it.each([['in',25.4],['cm',10],['m',1000],['ft',304.8]])('uses %s for immediate radius while persisting millimeters',async(unit,factor)=>{
 applyDocumentUnits({length:{unit,decimals:3}});
 try {
  open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(factor,0);
  const input=document.querySelector(`[aria-label="New curve radius (${unit})"]`);expect(Number(input.value)).toBeCloseTo(1);input.value='2';click('Set radius');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
  const profile=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(profile.contours[0].radius).toBeCloseTo(2*factor);expect(profile.constraints.find(c=>c.kind==='radius').value).toBeCloseTo(2*factor);
 } finally { applyDocumentUnits({}); }
});
it('converts an unsubmitted radius when document units change without changing geometry',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(10,0);const input=document.querySelector('[aria-label="New curve radius (mm)"]');input.value='25.4';
 applyDocumentUnits({length:{unit:'in',decimals:3}});
 try {
  expect(input.getAttribute('aria-label')).toBe('New curve radius (in)');expect(Number(input.value)).toBeCloseTo(1);expect(document.querySelector('.sketch-contour').getAttribute('r')).toBe('10');
  click('Set radius');expect(Number(document.querySelector('.sketch-contour').getAttribute('r'))).toBeCloseTo(25.4);
 } finally { applyDocumentUnits({}); }
});
it('authors, undoes and reopens a curvature-continuous line-to-cubic join',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);tool('cubic-bezier');point(10,0);point(12,2);point(15,5);point(20,5);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'curvature'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'curve',index:0,parameter:1});
 document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:1,kind:'curve',index:0,parameter:0});click('Apply constraint');
 expect(document.querySelectorAll('[data-constraint-kind="curvature"]')).toHaveLength(1);
 click('Undo');expect(document.querySelectorAll('[data-constraint-kind="curvature"]')).toHaveLength(0);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0]).toMatchObject({kind:'curvature',a:{parameter:1},b:{parameter:0}});
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('curvature');
});
it('authors and reopens a normal line/circle constraint with undo',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,-10);point(0,10);tool('circle');point(3,2);point(8,2);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'normal'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'line',index:0});
 document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:1,kind:'circle'});click('Apply constraint');
 expect(document.querySelector('.sketch-constraints').textContent).toContain('normalRemove');
 click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('normalRemove');click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0].kind).toBe('normal');
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('normalRemove');
});
it('previews signed offsets, cancels, undoes and reopens native offset geometry',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(5,0);tool('offset');
 const input=document.querySelector('[aria-label="Offset distance (mm)"]');expect(input).toBeTruthy();
 expect(document.querySelector('.sketch-modification-preview circle').getAttribute('r')).toBe('6');
 input.value='-2';input.dispatchEvent(new dom.window.Event('input',{bubbles:true}));expect(document.querySelector('.sketch-modification-preview circle').getAttribute('r')).toBe('3');
 click('Cancel modification');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
 tool('offset');click('Apply modification');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[1].radius).toBe(6);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
});
it('persists and edits an offset distance after native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(5,0);tool('offset');click('Apply modification');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0]).toMatchObject({kind:'offset',value:1});
 open(()=>doc,apply,saved.features[0]);const input=document.querySelector('[aria-label="offset value"]');expect(input.value).toBe('1');input.value='2';input.parentElement.querySelector('button').click();
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));expect(doc.features[0].profile.constraints[0].value).toBe(2);
 const [a,b]=doc.features[0].profile.contours;expect(b.radius-a.radius).toBeCloseTo(2,5);expect(b.center[0]).toBeCloseTo(a.center[0],5);
});
it('saves and edits an associative circular arc offset',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('arc');point(5,0);point(-5,0);point(0,5);tool('offset');click('Apply modification');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.find(c=>c.kind==='offset')).toMatchObject({kind:'offset',a:{kind:'arc'},b:{kind:'arc'},value:1});
 open(()=>doc,apply,saved.features[0]);const input=document.querySelector('[aria-label="offset value"]');input.value='2';input.parentElement.querySelector('button').click();
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));expect(doc.features[0].profile.constraints.find(c=>c.kind==='offset').value).toBe(2);
});
it('excludes construction centers from default offset selection',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('center-arc');point(0,0);point(5,0);point(0,5);tool('offset');
 const selection=document.querySelector('[aria-label="Offset entities"]');expect(selection.selectedOptions).toHaveLength(1);
 expect(document.querySelector('.sketch-modification-preview')).toBeTruthy();click('Apply modification');
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);
});
it('reopens a linked rectangular offset and edits its shared distance',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(10,10);tool('offset');click('Apply modification');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.find(c=>c.kind==='offset')).toMatchObject({a:{kind:'contour'},b:{kind:'contour'}});
 open(()=>doc,apply,saved.features[0]);const input=document.querySelector('[aria-label="offset value"]');input.value='2';input.parentElement.querySelector('button').click();
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));expect(doc.features[0].profile.constraints.find(c=>c.kind==='offset').value).toBe(2);
 const [a,b]=doc.features[0].profile.contours;expect(b.start[0]-a.start[0]).toBeCloseTo(2,5);expect(b.start[1]-a.start[1]).toBeCloseTo(2,5);
});
it('drags and cancels a signed offset handle then flips and commits with Enter',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(5,0);tool('offset');move(0,0);
 const handle=document.querySelector('[aria-label="Offset distance handle"]');expect(handle).toBeTruthy();expect(handle.hasAttribute('aria-valuemin')).toBe(false);
 handle.dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:6,clientY:0,button:0,bubbles:true}));move(3,0);
 const input=document.querySelector('[aria-label="Offset distance (mm)"]');expect(Number(input.value)).toBeCloseTo(-2,5);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
 document.querySelector('[aria-label="2D sketch canvas"]').dispatchEvent(new dom.window.Event('pointercancel'));expect(Number(input.value)).toBeCloseTo(1,5);
 click('Flip direction');expect(Number(input.value)).toBe(-1);
 input.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);expect(document.querySelector('[aria-label="Offset distance handle"]')).toBeNull();
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(doc.features[0].profile.constraints.find(c=>c.kind==='offset').value).toBe(-1);
});
it('click-selects individual offset edges, toggles them and saves linked references',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(10,10);tool('offset');point(5,0);
 expect(document.querySelector('[aria-label="Offset selection"]').value).toBe('edges');expect(document.querySelector('[aria-label="Offset entities"]').selectedOptions).toHaveLength(1);
 point(10,5);expect(document.querySelector('[aria-label="Offset entities"]').selectedOptions).toHaveLength(2);point(5,0);expect(document.querySelector('[aria-label="Offset entities"]').selectedOptions).toHaveLength(1);
 click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)),profile=saved.features[0].profile;expect(profile.contours).toHaveLength(2);expect(profile.contours[1].segments).toHaveLength(1);
 expect(profile.constraints.find(c=>c.kind==='offset')).toMatchObject({a:{kind:'line',index:1,contour:0},b:{kind:'line',index:0,contour:1}});
});
it('previews and saves a whole line-and-arc contour offset',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);tool('tangent-arc');point(10,0);point(15,5);tool('offset');
 expect(document.querySelector('.sketch-modification-preview path')).toBeTruthy();click('Apply modification');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[1].segments.map(s=>s.type)).toEqual(['line','arc']);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
});
it('edits a persisted whole mixed-profile offset distance',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);tool('tangent-arc');point(10,0);point(15,5);tool('offset');click('Apply modification');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.find(c=>c.kind==='offset')).toMatchObject({a:{kind:'contour'},b:{kind:'contour'}});
 open(()=>doc,apply,saved.features[0]);const input=document.querySelector('[aria-label="offset value"]');input.value='2';input.parentElement.querySelector('button').click();click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));expect(doc.features[0].profile.constraints.find(c=>c.kind==='offset').value).toBe(2);
});
it('creates a slot from a clicked line, undoes and edits its saved width',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);tool('slot');point(5,0);
 expect(document.querySelector('.sketch-slot-preview path')).toBeTruthy();expect(doc.features).toHaveLength(0);click('Apply slot');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0]).toMatchObject({kind:'slot',value:2});expect(saved.features[0].profile.contours[0].construction).toBe(true);
 open(()=>doc,apply,saved.features[0]);const input=document.querySelector('[aria-label="slot value"]');input.value='4';input.parentElement.querySelector('button').click();click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));expect(doc.features[0].profile.constraints[0].value).toBe(4);
});
it('drags slot width as diameter, cancels the drag and supports keyboard adjustment',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);tool('slot');point(5,0);move(0,0);
 const handle=document.querySelector('[aria-label="Slot width handle"]');expect(handle).toBeTruthy();expect(handle.getAttribute('aria-valuenow')).toBe('2');
 handle.dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:5,clientY:-1,button:0,bubbles:true}));move(5,3);
 const input=document.querySelector('[aria-label="Slot width (mm)"]');expect(Number(input.value)).toBeCloseTo(6);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
 document.querySelector('[aria-label="2D sketch canvas"]').dispatchEvent(new dom.window.Event('pointercancel'));expect(Number(input.value)).toBeCloseTo(2);
 document.querySelector('[aria-label="Slot width handle"]').dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'ArrowUp',bubbles:true,cancelable:true}));expect(Number(input.value)).toBeCloseTo(2.2);
 click('Apply slot');expect(document.querySelector('[aria-label="Slot width handle"]')).toBeNull();expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
});
it('releases a slot handle capture when switching tools mid-drag',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);tool('slot');point(5,0);
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');let captured;
 svg.setPointerCapture=id=>{captured=id;};svg.hasPointerCapture=id=>captured===id;svg.releasePointerCapture=vi.fn(id=>{if(captured===id)captured=undefined;});
 const event=new dom.window.MouseEvent('pointerdown',{button:0,bubbles:true});Object.defineProperty(event,'pointerId',{value:7});document.querySelector('[aria-label="Slot width handle"]').dispatchEvent(event);expect(captured).toBe(7);
 tool('circle');expect(svg.releasePointerCapture).toHaveBeenCalledWith(7);expect(captured).toBeUndefined();expect(document.querySelector('[aria-label="Slot width handle"]')).toBeNull();expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
});
it('selects an open slot chain, previews rounded joins and edits its saved width',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,0);point(10,0);point(10,10);tool('slot');
 const mode=document.querySelector('[aria-label="Slot selection"]');mode.value='chains';mode.dispatchEvent(new dom.window.Event('change'));
 const list=document.querySelector('[aria-label="Slot centerlines"]');expect(list.options).toHaveLength(1);list.options[0].selected=true;list.dispatchEvent(new dom.window.Event('change'));
 expect(document.querySelector('.sketch-slot-preview path')).toBeTruthy();click('Apply slot');
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.find(c=>c.kind==='slot').a.kind).toBe('contour');
 expect(saved.features[0].profile.contours[1].segments).toHaveLength(7);
 open(()=>doc,apply,saved.features[0]);const input=document.querySelector('[aria-label="slot value"]');input.value='3';input.parentElement.querySelector('button').click();
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));expect(doc.features[0].profile.constraints.find(c=>c.kind==='slot').value).toBe(3);
});
it('applies symmetry with a line axis and persists it through undo and native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,-10);point(0,10);tool('point');point(-3,4);point(2,2);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'symmetric'}));
 const axis=document.querySelector('[aria-label="Symmetry axis"]');expect(axis.parentElement.hidden).toBe(false);expect(axis.options).toHaveLength(1);
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:1,kind:'point',index:0});document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:2,kind:'point',index:0});click('Apply constraint');
 expect(document.querySelector('.sketch-constraints').textContent).toContain('symmetricRemove');click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('symmetricRemove');click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.find(c=>c.kind==='symmetric').axis).toMatchObject({kind:'line',contour:0,index:0});
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('symmetricRemove');
});
it('offers ellipse loci for symmetry and saves their axis relationship',async()=>{
 const profile={type:'drawing',contours:[{type:'path',start:[0,-10],segments:[{type:'line',end:[0,10]}]},{type:'path',start:[-2,2],segments:[{type:'ellipse',end:[-6,4],radiusX:4,radiusY:2,rotationDegrees:0,largeArc:false,sweep:true}]},{type:'path',start:[10,2],segments:[{type:'ellipse',end:[6,4],radiusX:4,radiusY:2,rotationDegrees:0,largeArc:false,sweep:true}]}]};
 const feature={id:'ellipse-sketch',type:'profile',name:'Ellipses',plane:'XY',offsetMillimeters:0,suppressed:false,profile};doc.features.push(feature);open(()=>doc,apply,feature);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'symmetric'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:1,kind:'ellipse',index:0});document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:2,kind:'ellipse',index:0});click('Apply constraint');
 expect(document.querySelector('.sketch-constraints').textContent).toContain('symmetricRemove');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints[0].a.kind).toBe('ellipse');open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('symmetricRemove');
});
it('creates and reopens full ellipses with shared halves during symmetry solving',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(0,-10);point(0,10);
 tool('ellipse');point(-6,0);point(-2,0);point(-6,2);point(7,1);point(12,1);point(7,3.5);
 expect(document.querySelector('.sketch-constraints').textContent.match(/ellipse-shapeRemove/g)).toHaveLength(2);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'symmetric'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:1,kind:'ellipse',index:0});document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:2,kind:'ellipse',index:0});click('Apply constraint');
 expect(document.querySelector('.sketch-constraints').textContent).toContain('symmetricRemove');click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('symmetricRemove');click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.filter(c=>c.kind==='ellipse-shape')).toHaveLength(2);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-constraints').textContent).toContain('symmetricRemove');
});
it('captures the nearest ellipse quadrant and persists it through undo and reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('ellipse');point(0,0);point(4,0);point(0,2);tool('point');point(3.8,.2);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'quadrant'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:1,kind:'point',index:0});document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:0,kind:'ellipse',index:0});click('Apply constraint');
 expect(document.querySelectorAll('select[aria-label^="Quadrant "]')).toHaveLength(1);click('Undo');expect(document.querySelectorAll('select[aria-label^="Quadrant "]')).toHaveLength(0);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.find(c=>c.kind==='quadrant').quadrant).toBe(0);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelectorAll('select[aria-label^="Quadrant "]')).toHaveLength(1);
});
it('infers an ellipse quadrant when a new line starts at its endpoint',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('ellipse');point(0,0);point(4,0);point(0,2);tool('line');point(0,2);point(8,8);
 expect(document.querySelectorAll('select[aria-label^="Quadrant "]')).toHaveLength(1);click('Undo');expect(document.querySelectorAll('select[aria-label^="Quadrant "]')).toHaveLength(0);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.find(c=>c.kind==='quadrant').quadrant).toBe(1);
});
it('does not infer ellipse quadrants when geometry snapping is disabled',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('ellipse');point(0,0);point(4,0);point(0,2);
 const label=[...document.querySelectorAll('label')].find(l=>l.textContent==='Snap to geometry');const input=label.querySelector('input');input.checked=false;input.dispatchEvent(new dom.window.Event('change'));
 tool('line');point(0,2);point(8,8);expect(document.querySelectorAll('select[aria-label^="Quadrant "]')).toHaveLength(0);
});
it('previews a DXF with explicit units and inserts editable native geometry in one undo step',async()=>{
 open(()=>doc,apply);click('Top (XY)');const input=document.querySelector('[aria-label="DXF file"]');
 const text='0\nSECTION\n2\nENTITIES\n0\nCIRCLE\n10\n0\n20\n0\n40\n1\n0\nENDSEC\n0\nEOF';
 Object.defineProperty(input,'files',{value:[{text:async()=>text}],configurable:true});input.dispatchEvent(new dom.window.Event('change'));await vi.waitFor(()=>expect(input.parentElement.textContent).toContain('Choose the source units'));
 const units=document.querySelector('[aria-label="DXF source units"]');units.value='25.4';units.dispatchEvent(new dom.window.Event('change'));expect(document.querySelector('.sketch-dxf-preview circle').getAttribute('r')).toBe('25.4');click('Insert DXF');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0]).toMatchObject({type:'circle',radius:25.4});
});
it('previews and reopens imported full ellipses and legacy closed polylines',async()=>{
 open(()=>doc,apply);click('Top (XY)');const input=document.querySelector('[aria-label="DXF file"]');
 const text='0\nSECTION\n2\nENTITIES\n0\nELLIPSE\n10\n10\n20\n0\n11\n4\n21\n0\n40\n0.5\n41\n0\n42\n'+(2*Math.PI)+'\n0\nPOLYLINE\n70\n1\n0\nVERTEX\n10\n0\n20\n0\n42\n1\n0\nVERTEX\n10\n4\n20\n0\n0\nSEQEND\n0\nENDSEC\n0\nEOF';
 const units=document.querySelector('[aria-label="DXF source units"]');units.value='1';Object.defineProperty(input,'files',{value:[{text:async()=>text}],configurable:true});input.dispatchEvent(new dom.window.Event('change'));
 await vi.waitFor(()=>expect(document.querySelectorAll('.sketch-dxf-preview path')).toHaveLength(2));click('Insert DXF');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[0].segments).toHaveLength(2);expect(saved.features[0].profile.contours[1].segments[0].type).toBe('arc');
 open(()=>doc,apply,saved.features[0]);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
});
it('positions, rotates and scales DXF previews before one undoable insertion',async()=>{
 open(()=>doc,apply);click('Top (XY)');const file=document.querySelector('[aria-label="DXF file"]');const units=document.querySelector('[aria-label="DXF source units"]');units.value='1';
 const text='0\nSECTION\n2\nENTITIES\n0\nCIRCLE\n10\n2\n20\n0\n40\n1\n0\nENDSEC\n0\nEOF';Object.defineProperty(file,'files',{value:[{text:async()=>text}]});file.dispatchEvent(new dom.window.Event('change'));await vi.waitFor(()=>expect(document.querySelector('.sketch-dxf-preview circle')).toBeTruthy());
 const set=(label,value)=>{const input=document.querySelector(`[aria-label="${label}"]`);input.value=value;input.dispatchEvent(new dom.window.Event('input'));};
 set('DXF X (mm)','10');set('DXF Y (mm)','20');set('DXF rotation (degrees)','90');set('DXF scale','2');let preview=document.querySelector('.sketch-dxf-preview circle');expect(Number(preview.getAttribute('cx'))).toBeCloseTo(10);expect(Number(preview.getAttribute('cy'))).toBeCloseTo(-24);expect(preview.getAttribute('r')).toBe('2');
 set('DXF scale','0');expect(document.querySelector('.sketch-dxf-preview')).toBeNull();expect([...document.querySelectorAll('button')].find(b=>b.textContent==='Insert DXF').disabled).toBe(true);set('DXF scale','2');click('Insert DXF');click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(doc.features[0].profile.contours[0].center[1]).toBeCloseTo(24);
});
it('places a DXF origin with the pointer and cancels placement with Escape',async()=>{
 open(()=>doc,apply);click('Top (XY)');const file=document.querySelector('[aria-label="DXF file"]');document.querySelector('[aria-label="DXF source units"]').value='1';
 const text='0\nSECTION\n2\nENTITIES\n0\nCIRCLE\n10\n0\n20\n0\n40\n1\n0\nENDSEC\n0\nEOF';Object.defineProperty(file,'files',{value:[{text:async()=>text}]});file.dispatchEvent(new dom.window.Event('change'));await vi.waitFor(()=>expect(document.querySelector('.sketch-dxf-preview')).toBeTruthy());
 const svg=document.querySelector('.cad-sketch-workspace svg');click('Place DXF on canvas');move(12,8);expect(document.querySelector('[aria-label="DXF X (mm)"]').value).toBe('12');svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));expect(document.querySelector('[aria-label="DXF X (mm)"]').value).toBe('0');
 click('Place DXF on canvas');move(20,10);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:20,clientY:-10,bubbles:true}));expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);click('Insert DXF');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(doc.features[0].profile.contours[0].center).toEqual([20,10]);
});
it('joins independent DXF lines into a closed profile and lets users retain separate edges',async()=>{
 open(()=>doc,apply);click('Top (XY)');const file=document.querySelector('[aria-label="DXF file"]');document.querySelector('[aria-label="DXF source units"]').value='1';
 const line=(a,b)=>`0\nLINE\n10\n${a[0]}\n20\n${a[1]}\n11\n${b[0]}\n21\n${b[1]}`;const text='0\nSECTION\n2\nENTITIES\n'+[line([0,0],[10,0]),line([10,10],[10,0]),line([0,10],[10,10]),line([0,0],[0,10])].join('\n')+'\n0\nENDSEC\n0\nEOF';
 Object.defineProperty(file,'files',{value:[{text:async()=>text}]});file.dispatchEvent(new dom.window.Event('change'));await vi.waitFor(()=>expect(document.querySelectorAll('.sketch-dxf-preview path')).toHaveLength(1));
 const join=document.querySelector('[aria-label="Join connected DXF edges"]');join.checked=false;join.dispatchEvent(new dom.window.Event('change'));expect(document.querySelectorAll('.sketch-dxf-preview path')).toHaveLength(4);join.checked=true;join.dispatchEvent(new dom.window.Event('change'));click('Insert DXF');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(doc.features[0].profile.contours).toHaveLength(1);expect(contourClosed(doc.features[0].profile.contours[0])).toBe(true);
});
it('detects imported nested holes and offers manual import for intersecting loops',async()=>{
 open(()=>doc,apply);click('Top (XY)');const file=document.querySelector('[aria-label="DXF file"]');document.querySelector('[aria-label="DXF source units"]').value='1';
 const text=(x)=>'0\nSECTION\n2\nENTITIES\n0\nCIRCLE\n10\n0\n20\n0\n40\n10\n0\nCIRCLE\n10\n'+x+'\n20\n0\n40\n5\n0\nENDSEC\n0\nEOF';
 Object.defineProperty(file,'files',{value:[{text:async()=>text(0)}],configurable:true});file.dispatchEvent(new dom.window.Event('change'));await vi.waitFor(()=>expect(file.parentElement.textContent).toContain('1 holes'));click('Insert DXF');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(doc.features[0].profile.contours.map(c=>c.hole)).toEqual([false,true]);
 const saved=parsePartDocument(serializePartDocument(doc));open(()=>doc,apply,saved.features[0]);const second=document.querySelector('[aria-label="DXF file"]');document.querySelector('[aria-label="DXF source units"]').value='1';Object.defineProperty(second,'files',{value:[{text:async()=>text(8)}]});second.dispatchEvent(new dom.window.Event('change'));await vi.waitFor(()=>expect(second.parentElement.textContent).toContain('manual region selection'));
 const holes=document.querySelector('[aria-label="Detect DXF holes"]');holes.checked=false;holes.dispatchEvent(new dom.window.Event('change'));expect(document.querySelectorAll('.sketch-dxf-preview circle')).toHaveLength(2);click('Cancel DXF');
});
it('exposes an arc center for sketch constraints and persists its fixed location',async()=>{
 open(()=>doc,apply);
 window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
 tool('arc');point(5,0);point(-5,0);point(0,5);
 const a=document.querySelector('[aria-label="Entity A"]');
 a.value=JSON.stringify({contour:0,kind:'arc',index:0});
 click('Select arc center');
 expect(JSON.parse(a.value)).toMatchObject({kind:'point',contour:1});
 const kind=document.querySelector('[aria-label="Constraint"]');kind.value='fix';kind.dispatchEvent(new Event('change'));
 click('Apply constraint');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const drawing=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(drawing.contours[1]).toMatchObject({construction:true,start:[0,0]});
 expect(drawing.constraints.map(c=>c.kind)).toEqual(expect.arrayContaining(['concentric','fix']));
});
it('persists center snap inference with drawing and removes it in the same undo step',async()=>{
 open(()=>doc,apply);window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
 tool('arc');point(15,10);point(5,10);point(10,15);
 tool('select');tool('line');point(10,10);point(20,20);
 expect(document.querySelector('.sketch-constraints').textContent).toContain('concentricRemove');
 click('Undo');expect(document.querySelectorAll('[data-constraint-kind="concentric"]')).toHaveLength(1);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const drawing=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(drawing.constraints).toEqual(expect.arrayContaining([expect.objectContaining({kind:'concentric',a:{kind:'point',contour:3,index:0},b:{kind:'arc',contour:0,index:0}})]));
});
it('infers endpoint coincidence from canvas clicks and keeps the relation through undo and native save',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(5,5);point(10,5);tool('select');tool('line');
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 for(const [x,y] of [[10,5],[20,15]]) {move(x,y);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:x,clientY:-y,bubbles:true}));}
 expect(document.querySelector('.sketch-constraints').textContent).toContain('coincidentRemove');
 click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('coincidentRemove');click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(parsePartDocument(serializePartDocument(doc)).features[0].profile.constraints).toEqual(expect.arrayContaining([expect.objectContaining({kind:'coincident'})]));
});
it('persists horizontal and vertical line alignment from canvas placement',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(5,5);
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 for(const [x,y] of [[10,5],[10,10]]) {move(x,y);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:x,clientY:-y,bubbles:true}));}
 expect(document.querySelector('.sketch-constraints').textContent).toContain('verticalRemove');
 click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('verticalRemove');click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(saved.constraints.map(c=>c.kind)).toEqual(['horizontal','vertical']);
});
it('persists midpoint inference from canvas placement',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(5,5);point(15,5);tool('select');tool('line');
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');
 for(const [x,y] of [[10,5],[20,15]]) {move(x,y);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:x,clientY:-y,bubbles:true}));}
 expect(document.querySelector('.sketch-constraints').textContent).toContain('midpointRemove');
 click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('midpointRemove');click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(parsePartDocument(serializePartDocument(doc)).features[0].profile.constraints).toEqual(expect.arrayContaining([expect.objectContaining({kind:'midpoint'})]));
});
it('creates a driving diameter dimension and saves the resulting circle',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(5,5);point(10,5);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'diameter'}));
 const a=document.querySelector('[aria-label="Entity A"]');a.value=JSON.stringify({contour:0,kind:'circle'});
 document.querySelector('[aria-label="Constraint value"]').value='16';click('Apply constraint');
 expect(document.querySelector('.sketch-constraints').textContent).toContain('diameter');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(saved.constraints.find(c=>c.kind==='diameter').value).toBe(16);expect(saved.contours[0].radius).toBeCloseTo(8);
});
it('sets independent horizontal and vertical distances between sketch points',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(5,5);point(8,9);
 const setConstraint=(kind,value)=>{
  window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:kind}));
  document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'point',index:0});
  document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:0,kind:'point',index:1});
  document.querySelector('[aria-label="Constraint value"]').value=String(value);click('Apply constraint');
 };
 setConstraint('fix',0);setConstraint('horizontal-distance',-2);setConstraint('vertical-distance',6);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(saved.contours[0].segments[0].end[0]).toBeCloseTo(3);expect(saved.contours[0].segments[0].end[1]).toBeCloseTo(11);
 expect(saved.constraints.map(c=>c.kind)).toEqual(['fix','horizontal-distance','vertical-distance']);
});
it('opens a saved dimension editor from its canvas annotation and updates the model',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(5,5);point(10,5);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'diameter'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'circle'});
 document.querySelector('[aria-label="Constraint value"]').value='10';click('Apply constraint');
 const label=document.querySelector('.sketch-dimension text');expect(label.textContent).toBe('Ø 10 mm');
 label.dispatchEvent(new dom.window.MouseEvent('click',{bubbles:true}));
 const input=document.querySelector('[aria-label="diameter value"]');expect(document.activeElement).toBe(input);
 input.value='14';input.parentElement.querySelector('button').click();
 expect(document.querySelector('.sketch-dimension text').textContent).toBe('Ø 14 mm');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(doc.features[0].profile.contours[0].radius).toBeCloseTo(7);
});
it('drags dimension labels with undo, cancellation and native presentation persistence',async()=>{
 const feature={id:'profile',type:'profile',name:'Circle',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'circle',center:[5,5],radius:5}],constraints:[{id:'diameter',kind:'diameter',a:{kind:'circle',contour:0},value:10}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');move(0,0);
 const label=()=>document.querySelector('.sketch-dimension text');const original=label().getAttribute('x');
 label().dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:10,clientY:-10,bubbles:true}));
 move(20,25);svg.dispatchEvent(new dom.window.MouseEvent('pointerup',{clientX:20,clientY:-25,bubbles:true}));
 expect(label().getAttribute('x')).toBe('20');expect(label().getAttribute('y')).toBe('-25');
 expect(document.querySelector('[data-dimension-leader]').getAttribute('x2')).toBe('20');
 click('Undo');expect(label().getAttribute('x')).toBe(original);expect(document.querySelector('[data-dimension-leader]')).toBeNull();click('Redo');expect(label().getAttribute('x')).toBe('20');
 label().dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:20,clientY:-25,bubbles:true}));move(35,40);
 svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));expect(label().getAttribute('x')).toBe('20');
 expect(document.querySelector('[data-dimension-leader]').getAttribute('x2')).toBe('20');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));expect(doc.sketchPresentation.profile.dimensionLabelPositionsMillimeters.diameter).toEqual([20,25]);
 expect(doc.features[0].profile.contours[0]).toEqual(feature.profile.contours[0]);
 open(()=>doc,apply,doc.features[0]);expect(label().getAttribute('x')).toBe('20');
});
it('moves axis guides during drag and restores them on cancellation',()=>{
 const feature={id:'profile',type:'profile',name:'Line',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[2,3],segments:[{type:'line',end:[12,13]}]}],constraints:[{id:'x',kind:'horizontal-distance',a:{kind:'point',contour:0,index:0},b:{kind:'point',contour:0,index:1},value:10}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);move(0,0);
 const svg=document.querySelector('[aria-label="2D sketch canvas"]'),label=document.querySelector('.sketch-dimension text'),line=document.querySelector('[data-dimension-measure]');
 const original=line.getAttribute('y1');label.dispatchEvent(new dom.window.MouseEvent('pointerdown',{clientX:7,clientY:-21,bubbles:true}));move(20,40);
 // Stand-off is 2 * (viewWidth / 120) mm below the label, so it is constant on
 // screen; the mm value tracks the default view width (200 mm).
 expect(line.getAttribute('y1')).toBe(String(-(40 - 2 * (200 / 120))));
 svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));expect(line.getAttribute('y1')).toBe(original);expect(document.querySelector('[data-dimension-leader]')).toBeNull();
});
it('creates a read-only reference dimension without changing sketch geometry',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(5,5);point(10,5);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'diameter'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'circle'});
 const reference=document.querySelector('[aria-label="Reference dimension"]');reference.checked=true;reference.dispatchEvent(new Event('change'));
 click('Apply constraint');expect(document.querySelector('[aria-label="diameter value"]').readOnly).toBe(true);expect(document.querySelector('.sketch-dimension text').textContent).toBe('(Ø 10 mm)');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.contours[0].radius).toBe(5);expect(saved.constraints[0]).toMatchObject({reference:true,kind:'diameter'});expect(saved.constraints[0].value).toBeUndefined();
});
it('converts saved dimensions between driving and reference with undo and stable IDs',async()=>{
 const feature={id:'profile',type:'profile',name:'Circle',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'circle',center:[5,5],radius:5}],constraints:[{id:'d',kind:'diameter',a:{kind:'circle',contour:0},value:10}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);
 click('Make reference');expect(document.querySelector('[aria-label="diameter value"]').readOnly).toBe(true);
 click('Undo');expect(document.querySelector('[aria-label="diameter value"]').readOnly).toBe(false);click('Redo');
 click('Make driving');expect(document.querySelector('[aria-label="diameter value"]').readOnly).toBe(false);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(doc.features[0].profile.constraints[0]).toMatchObject({id:'d',value:10});expect(doc.features[0].profile.constraints[0].reference).toBeUndefined();
});
it('creates and edits parallel-line spacing through the constraint panel with undo and native save',async()=>{
 const feature={id:'profile',type:'profile',name:'Lines',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]}]},{type:'path',start:[20,3],segments:[{type:'line',end:[30,3]}]}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'distance'}));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'line',index:0});
 document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:1,kind:'line',index:0});
 document.querySelector('[aria-label="Constraint value"]').value='3';click('Apply constraint');
 let value=document.querySelector('[aria-label="distance value"]');expect(value).not.toBeNull();value.value='6';value.parentElement.querySelector('button').click();
 expect(document.querySelector('[aria-label="distance value"]').value).toBe('6');
 click('Undo');expect(document.querySelector('[aria-label="distance value"]').value).toBe('3');click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints[0]).toMatchObject({kind:'distance',value:6,a:{kind:'line',contour:0},b:{kind:'line',contour:1}});
 const [a,b]=saved.contours;const u=[a.segments[0].end[0]-a.start[0],a.segments[0].end[1]-a.start[1]],v=[b.segments[0].end[0]-b.start[0],b.segments[0].end[1]-b.start[1]];
 expect((u[0]*v[1]-u[1]*v[0])/(Math.hypot(...u)*Math.hypot(...v))).toBeCloseTo(0,7);
});
it('reports selected vertex and edge freedom independently of other free geometry',()=>{
 const feature={id:'profile',type:'profile',name:'Constrained start',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]}]},{type:'circle',center:[30,20],radius:5}],constraints:[{id:'fixed',kind:'fix',a:{kind:'point',contour:0,index:0},point:[0,0]},{id:'horizontal',kind:'horizontal',a:{kind:'line',contour:0,index:0}}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('select');
 const status=()=>document.querySelector('[aria-label="Selected entity constraint state"]');
 point(0,0);expect(status().textContent).toContain('Fully constrained · 0 degrees of freedom');
 point(5,0);expect(status().textContent).toContain('Selected line: Under-constrained · 1 degrees of freedom');
 point(10,0);expect(status().textContent).toContain('Selected point: Under-constrained · 1 degrees of freedom');
 point(50,40);expect(status().hidden).toBe(true);
 expect(doc.features[0]).toEqual(feature);
});
it('keeps pattern instances linked through source dimension edits, undo and native reopen',async()=>{
 const feature={id:'profile',type:'profile',name:'Pattern source',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'circle',center:[5,0],radius:2}],constraints:[{id:'radius',kind:'radius',a:{kind:'circle',contour:0},value:2}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('linear-pattern');click('Apply modification');
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);
 const input=document.querySelector('[aria-label="radius value"]');input.value='4';input.parentElement.querySelector('button').click();
 const radii=()=>[...document.querySelectorAll('circle.sketch-contour')].map(c=>Number(c.getAttribute('r')));
 for(const r of radii())expect(r).toBeCloseTo(4,6);click('Undo');for(const r of radii())expect(r).toBeCloseTo(2,6);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));doc=parsePartDocument(serializePartDocument(doc));
 expect(doc.features[0].profile.constraints.filter(c=>c.kind==='pattern')).toHaveLength(2);open(()=>doc,apply,doc.features[0]);for(const r of radii())expect(r).toBeCloseTo(4,6);
});
it('selects a live mirror axis, excludes it from copies and saves the associative reference',async()=>{
 const feature={id:'profile',type:'profile',name:'Live mirror',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'circle',center:[5,0],radius:2},{type:'path',construction:true,start:[0,-10],segments:[{type:'line',end:[0,10]}]}],constraints:[{id:'radius',kind:'radius',a:{kind:'circle',contour:0},value:2}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('mirror');
 const axis=document.querySelector('[aria-label="Mirror axis"]');axis.value=JSON.stringify({contour:1,kind:'line',index:0});axis.dispatchEvent(new Event('change'));
 expect(document.querySelector('[aria-label="Axis start X (mm)"]').disabled).toBe(true);
 expect([...document.querySelector('[aria-label="Modification contours"]').selectedOptions].map(o=>o.value)).toEqual(['0']);
 click('Apply modification');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);click('Redo');
 const radius=document.querySelector('[aria-label="radius value"]');radius.value='3';radius.parentElement.querySelector('button').click();
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));doc=parsePartDocument(serializePartDocument(doc));
 expect(doc.features[0].profile.constraints.find(c=>c.kind==='pattern').axis).toEqual({contour:1,kind:'line',index:0});expect(doc.features[0].profile.contours[2].radius).toBeCloseTo(3,6);
});
it('edits a saved mirror axis with cancel, undo and native persistence',async()=>{
 const {mirrorSketch}=await import('@aether/core/sketch');
 const drawing=mirrorSketch({type:'drawing',contours:[{type:'circle',center:[5,3],radius:2},{type:'path',start:[0,-10],segments:[{type:'line',end:[0,10]}]},{type:'path',start:[-10,0],segments:[{type:'line',end:[10,0]}]}]},[0],[0,0],[0,10],{contour:1,kind:'line',index:0});
 const feature={id:'profile',type:'profile',name:'Mirror edit',plane:'XY',offsetMillimeters:0,suppressed:false,profile:drawing};doc.features.push(feature);open(()=>doc,apply,feature);
 const axisValue=JSON.stringify({contour:2,kind:'line',index:0});
 click('Edit mirror axis');document.querySelector('[aria-label="Saved mirror axis"]').value=axisValue;click('Cancel axis edit');expect(doc.features[0].profile).toEqual(drawing);
 click('Edit mirror axis');const select=document.querySelector('[aria-label="Saved mirror axis"]');select.value=axisValue;select.dispatchEvent(new Event('change'));click('Update mirror axis');
 const copy=()=>document.querySelector('[data-contour-index="3"]');expect(Number(copy().getAttribute('cx'))).toBeCloseTo(5);expect(Number(copy().getAttribute('cy'))).toBeCloseTo(3);
 click('Undo');expect(Number(copy().getAttribute('cx'))).toBeCloseTo(-5);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints[0]).toMatchObject({id:drawing.constraints[0].id,axis:{contour:2,kind:'line',index:0}});
});
it('edits shared pattern spacing with cancel, undo and native group persistence',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(5,0);point(6,0);tool('linear-pattern');click('Apply modification');
 click('Edit pattern');document.querySelector('[aria-label="Pattern spacing X (mm)"]').value='30';click('Cancel pattern edit');
 const xs=()=>[...document.querySelectorAll('circle.sketch-contour')].map(c=>Number(c.getAttribute('cx')));expect(xs()).toEqual([5,25,45]);
 click('Edit pattern');document.querySelector('[aria-label="Pattern spacing X (mm)"]').value='30';click('Update pattern');expect(xs()).toEqual([5,35,65]);click('Undo');expect(xs()).toEqual([5,25,45]);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));doc=parsePartDocument(serializePartDocument(doc));const d=doc.features[0].profile;expect(Object.values(d.patternGroups)[0].first).toEqual([30,0]);expect(d.constraints.filter(c=>c.kind==='pattern').every(c=>!c.transform&&c.patternGroup)).toBe(true);
});
it('changes pattern count with undo, shrink and native persistence',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(5,0);point(6,0);tool('linear-pattern');click('Apply modification');
 click('Edit pattern');document.querySelector('[aria-label="Pattern count"]').value='5';click('Update pattern');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(5);
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);click('Redo');
 click('Edit pattern');document.querySelector('[aria-label="Pattern count"]').value='2';click('Update pattern');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(Object.values(saved.patternGroups)[0].countFirst).toBe(2);expect(saved.contours).toHaveLength(2);expect(saved.constraints.filter(c=>c.kind==='pattern')).toHaveLength(1);
});
it('restores missing pattern instances with undo and native persistence',async()=>{
 const {linearPattern,removeDrawingConstraint}=await import('@aether/core/sketch');
 const p=linearPattern({type:'drawing',contours:[{type:'circle',center:[0,0],radius:1}]},[0],[10,0],3),drawing=removeDrawingConstraint(p,p.constraints[0].id);
 const feature={id:'profile',type:'profile',name:'Repair pattern',plane:'XY',offsetMillimeters:0,suppressed:false,profile:drawing};doc.features.push(feature);open(()=>doc,apply,feature);
 click('Edit pattern');expect(document.querySelector('.sketch-pattern-group-editor').textContent).toContain('keeps detached geometry');click('Restore missing instances');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(4);
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints.filter(c=>c.kind==='pattern')).toHaveLength(2);expect(saved.contours[1]).toEqual(drawing.contours[1]);
});
it('suppresses and restores pattern geometry with undo and native slot persistence',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(5,0);point(6,0);tool('linear-pattern');click('Apply modification');
 click('Suppress instance');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);click('Redo');
 click('Unsuppress instance');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);click('Suppress instance');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.contours).toHaveLength(2);expect(saved.constraints.filter(c=>c.patternSuppression)).toHaveLength(1);open(()=>doc,apply,{...doc.features[0],profile:saved});click('Unsuppress instance');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);
});
it('suppresses a multi-contour pattern placement in one undoable action',async()=>{
 const {linearPattern}=await import('@aether/core/sketch');const drawing=linearPattern({type:'drawing',contours:[{type:'circle',center:[0,0],radius:1},{type:'circle',center:[5,0],radius:2}]},[0,1],[20,0],3);
 const feature={id:'profile',type:'profile',name:'Placement controls',plane:'XY',offsetMillimeters:0,suppressed:false,profile:drawing};doc.features.push(feature);open(()=>doc,apply,feature);
 click('Edit pattern');document.querySelector('[aria-label="Suppress placement 2"]').click();expect(document.querySelectorAll('.sketch-contour')).toHaveLength(4);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(6);click('Redo');
 click('Edit pattern');expect(document.querySelector('[aria-label="Suppress placement 2"]').disabled).toBe(true);document.querySelector('[aria-label="Restore placement 2"]').click();expect(document.querySelectorAll('.sketch-contour')).toHaveLength(6);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints.filter(c=>c.patternSuppression)).toHaveLength(0);
});
it('mirrors individual edges with a live axis in the same contour and saves source references',async()=>{
 const feature={id:'profile',type:'profile',name:'Edge mirror',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,-10],segments:[{type:'line',end:[0,10]},{type:'line',end:[5,10]},{type:'line',end:[5,0]}]}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('mirror');const mode=document.querySelector('[aria-label="Mirror individual edges"]');mode.checked=true;mode.dispatchEvent(new Event('change'));
 const axis=document.querySelector('[aria-label="Mirror axis"]');axis.value=JSON.stringify({contour:0,kind:'line',index:0});axis.dispatchEvent(new Event('change'));
 const selection=document.querySelector('[aria-label="Modification contours"]');for(const option of selection.options)option.selected=JSON.parse(option.value).index===2;selection.dispatchEvent(new Event('change'));
 click('Apply modification');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');
 click('Edit mirror axis');expect([...document.querySelector('[aria-label="Saved mirror axis"]').options].some(o=>o.value===axis.value)).toBe(true);click('Cancel axis edit');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;const identified=structuredClone(feature.profile.contours[0]);identified.segments[0].id='source-edge-2';identified.segments[2].id='source-edge-1';expect(saved.contours[0]).toEqual(identified);expect(saved.constraints[0]).toMatchObject({a:{contour:0,kind:'line',index:2,segmentId:'source-edge-1'},axis:{contour:0,kind:'line',index:0,segmentId:'source-edge-2'}});expect(saved.contours[1].segments).toHaveLength(1);
});
it('click-toggles mirror edges on the canvas, highlights sources and excludes the live axis',async()=>{
 const feature={id:'profile',type:'profile',name:'Pick mirror edges',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,-10],segments:[{type:'line',end:[0,10]},{type:'line',end:[5,10]},{type:'line',end:[5,0]}]}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('mirror');
 const mode=document.querySelector('[aria-label="Mirror individual edges"]');mode.checked=true;mode.dispatchEvent(new Event('change'));
 const axis=document.querySelector('[aria-label="Mirror axis"]');axis.value=JSON.stringify({contour:0,kind:'line',index:0});axis.dispatchEvent(new Event('change'));
 const indices=()=>[...document.querySelector('[aria-label="Modification contours"]').selectedOptions].map(o=>JSON.parse(o.value).index);
 point(5,5);expect(indices()).toEqual([2]);expect(document.querySelector('.sketch-modification-source-selection').children).toHaveLength(1);
 point(2,10);expect(indices()).toEqual([1,2]);expect(document.querySelector('.sketch-modification-source-selection').children).toHaveLength(2);
 point(5,5);expect(indices()).toEqual([1]);point(0,0);expect(indices()).toEqual([1]);point(50,40);expect(indices()).toEqual([1]);
 click('Cancel modification');expect(document.querySelector('.sketch-modification-source-selection')).toBeNull();expect(doc.features[0]).toEqual(feature);
 tool('mirror');point(5,5);expect(document.querySelector('[aria-label="Modification contours"]').selectedOptions).toHaveLength(1);click('Apply modification');expect(document.querySelector('.sketch-modification-source-selection')).toBeNull();
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(doc.features[0].profile.contours).toHaveLength(2);
});
it('patterns selected canvas edges as distinct linked sources and saves them',async()=>{
 const feature={id:'profile',type:'profile',name:'Edge pattern',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,-10],segments:[{type:'line',end:[0,10]},{type:'line',end:[5,10]},{type:'line',end:[5,0]}]}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('linear-pattern');
 const mode=document.querySelector('[aria-label="Pattern individual edges"]');mode.checked=true;mode.dispatchEvent(new Event('change'));
 point(5,5);point(2,10);expect(document.querySelector('.sketch-modification-source-selection').children).toHaveLength(2);
 click('Apply modification');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(5);expect(document.querySelector('.sketch-modification-source-selection')).toBeNull();
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints.map(c=>c.a.index)).toEqual([1,2,1,2]);expect(saved.contours.slice(1).every(c=>c.segments.length===1)).toBe(true);
});
it('selects and fixes a persistent ellipse center with undo and native save',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('ellipse');point(10,10);point(15,10);point(10,12);
 const entity=document.querySelector('[aria-label="Entity A"]');entity.value=JSON.stringify({contour:0,kind:'ellipse',index:0});click('Select ellipse center');
 expect(JSON.parse(entity.value)).toMatchObject({kind:'point',contour:1});
 const kind=document.querySelector('[aria-label="Constraint"]');kind.value='fix';kind.dispatchEvent(new Event('change'));click('Apply constraint');
 click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints.map(c=>c.kind)).toEqual(expect.arrayContaining(['ellipse-shape','concentric','fix']));expect(saved.contours[1]).toMatchObject({construction:true,start:[10,10]});
});
it('dimensions an ellipse through its linked construction axis and saves the result',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('ellipse');point(10,10);point(15,10);point(10,12);
 const entity=document.querySelector('[aria-label="Entity A"]');entity.value=JSON.stringify({contour:0,kind:'ellipse',index:0});click('Select ellipse X axis');expect(JSON.parse(entity.value)).toMatchObject({kind:'line',contour:1});
 const kind=document.querySelector('[aria-label="Constraint"]');kind.value='length';kind.dispatchEvent(new Event('change'));document.querySelector('[aria-label="Constraint value"]').value='14';click('Apply constraint');click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints.filter(c=>c.kind==='quadrant')).toHaveLength(2);expect(saved.contours[0].segments[0].radiusX).toBeCloseTo(7);expect(saved.contours[1].construction).toBe(true);
});
it('reassigns a saved ellipse quadrant with undo and native persistence',async()=>{
 const {constrainSketchEllipse,sketchVariantContour}=await import('@aether/core/sketch');const drawing=constrainSketchEllipse({type:'drawing',contours:[sketchVariantContour('ellipse',[[0,0],[5,0],[0,2]]),{type:'path',start:[5,0],segments:[]}]},0);drawing.constraints.push({id:'q',kind:'quadrant',a:{kind:'point',contour:1,index:0},b:{kind:'ellipse',contour:0,index:0},quadrant:0});
 const feature={id:'profile',type:'profile',name:'Quadrant edit',plane:'XY',offsetMillimeters:0,suppressed:false,profile:drawing};doc.features.push(feature);open(()=>doc,apply,feature);
 const input=document.querySelector('[aria-label="Quadrant q"]');input.value='1';input.dispatchEvent(new Event('change'));click('Undo');expect(document.querySelector('[aria-label="Quadrant q"]').value).toBe('0');click('Redo');expect(document.querySelector('[aria-label="Quadrant q"]').value).toBe('1');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints.find(c=>c.id==='q').quadrant).toBe(1);expect(saved.contours[1].start[1]).toBeCloseTo(2);
});
it('adds curvature continuity between a circle and cubic contact and persists it',async()=>{
 const feature={id:'profile',type:'profile',name:'Circle curvature',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'bezier',controls:[[1/3,0],[2/3,1/3]],end:[1,1]}]},{type:'circle',center:[0,.5],radius:.5}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);const kind=document.querySelector('[aria-label="Constraint"]');kind.value='curvature';kind.dispatchEvent(new Event('change'));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:1,kind:'circle'});document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:0,kind:'curve',index:0,parameter:0});click('Apply constraint');expect(document.querySelectorAll('[data-constraint-kind="curvature"]')).toHaveLength(1);click('Undo');expect(document.querySelectorAll('[data-constraint-kind="curvature"]')).toHaveLength(0);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints).toEqual(expect.arrayContaining([expect.objectContaining({kind:'curvature',a:{contour:1,kind:'circle'},b:{contour:0,kind:'curve',index:0,parameter:0}})]));
});
it('creates reversed whole-spline symmetry with a live axis and saves it',async()=>{
 const feature={id:'profile',type:'profile',name:'Spline symmetry',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,-10],segments:[{type:'line',end:[0,10]}]},{type:'path',start:[-2,0],segments:[{type:'bezier',controls:[[-4,1],[-3,4]],end:[-5,5]}]},{type:'path',start:[5,5],segments:[{type:'bezier',controls:[[3,4],[4,1]],end:[2,0]}]}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);const kind=document.querySelector('[aria-label="Constraint"]');kind.value='symmetric';kind.dispatchEvent(new Event('change'));
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:1,kind:'contour'});document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:2,kind:'contour'});document.querySelector('[aria-label="Symmetry axis"]').value=JSON.stringify({contour:0,kind:'line',index:0});document.querySelector('[aria-label="Reverse spline correspondence"]').checked=true;
 click('Apply constraint');expect(document.querySelector('.sketch-constraints').textContent).toContain('symmetricRemove');click('Undo');expect(document.querySelector('.sketch-constraints').textContent).not.toContain('symmetricRemove');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints).toEqual(expect.arrayContaining([expect.objectContaining({kind:'symmetric',splineReversed:true,axis:{contour:0,kind:'line',index:0}})]));
});
it('places a DXF source anchor with rotation, scale and endpoint snapping',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('line');point(30,20);point(40,25);tool('select');
 const file=document.querySelector('[aria-label="DXF file"]');document.querySelector('[aria-label="DXF source units"]').value='1';Object.defineProperty(file,'files',{value:[{text:async()=> '0\nSECTION\n2\nENTITIES\n0\nCIRCLE\n10\n2\n20\n0\n40\n1\n0\nENDSEC\n0\nEOF'}]});file.dispatchEvent(new Event('change'));await vi.waitFor(()=>expect(document.querySelector('.sketch-dxf-preview circle')).not.toBeNull());
 const set=(label,value)=>{const input=document.querySelector(`[aria-label="${label}"]`);input.value=value;input.dispatchEvent(new Event('input'));};
 set('DXF anchor X (mm)','1');set('DXF X (mm)','10');set('DXF Y (mm)','20');set('DXF rotation (degrees)','90');set('DXF scale','2');
 const circle=()=>document.querySelector('.sketch-dxf-preview circle');expect(Number(circle().getAttribute('cx'))).toBeCloseTo(10);expect(Number(circle().getAttribute('cy'))).toBeCloseTo(-22);
 const anchor=document.querySelector('[aria-label="DXF source anchor"]');anchor.value='[2,0]';anchor.dispatchEvent(new Event('change'));expect(Number(circle().getAttribute('cy'))).toBeCloseTo(-20);
 const svg=document.querySelector('.cad-sketch-workspace svg');click('Place DXF on canvas');move(28,19);expect(document.querySelector('[aria-label="DXF X (mm)"]').value).toBe('30');expect(document.querySelector('[aria-label="DXF Y (mm)"]').value).toBe('20');svg.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));expect(document.querySelector('[aria-label="DXF X (mm)"]').value).toBe('10');
 click('Place DXF on canvas');svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:28,clientY:-19,bubbles:true}));click('Insert DXF');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.contours[1]).toMatchObject({type:'circle',center:[30,20],radius:2});
});
it('filters DXF layers including unsupported reference entities before preview and save',async()=>{
 open(()=>doc,apply);click('Top (XY)');const file=document.querySelector('[aria-label="DXF file"]');document.querySelector('[aria-label="DXF source units"]').value='1';
 Object.defineProperty(file,'files',{value:[{text:async()=> '0\nSECTION\n2\nENTITIES\n0\nCIRCLE\n8\nParts\n10\n0\n20\n0\n40\n2\n0\nTEXT\n8\nLabels\n1\nReference\n0\nENDSEC\n0\nEOF'}]});file.dispatchEvent(new Event('change'));await vi.waitFor(()=>expect(document.querySelector('[aria-label="Import DXF layer Labels"]')).not.toBeNull());expect(document.querySelector('.sketch-dxf-preview')).toBeNull();
 const labels=document.querySelector('[aria-label="Import DXF layer Labels"]');labels.checked=false;labels.dispatchEvent(new Event('change'));expect(document.querySelectorAll('.sketch-dxf-preview circle')).toHaveLength(1);
 const parts=document.querySelector('[aria-label="Import DXF layer Parts"]');parts.checked=false;parts.dispatchEvent(new Event('change'));expect(document.querySelector('.sketch-dxf-preview')).toBeNull();parts.checked=true;parts.dispatchEvent(new Event('change'));click('Insert DXF');click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(parsePartDocument(serializePartDocument(doc)).features[0].profile.contours).toHaveLength(1);
});
it('extends to an authored point boundary with preview, undo and native save',async()=>{
 const feature={id:'profile',type:'profile',name:'Point extend',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[5,0]}]},{type:'path',start:[8,0],segments:[]}]}};doc.features.push(feature);open(()=>doc,apply,feature);tool('extend');move(4.9,0);point(4.9,0);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.contours[0].segments[0].end).toEqual([8,0]);expect(saved.contours[1]).toEqual(feature.profile.contours[1]);expect(saved.constraints).toEqual(expect.arrayContaining([expect.objectContaining({kind:'coincident',a:{kind:'point',contour:0,index:1},b:{kind:'point',contour:1,index:0}})]));
});
it('persists the curve-boundary attachment created by Extend',async()=>{
 const feature={id:'profile',type:'profile',name:'Curve extend',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[5,0]}]},{type:'circle',center:[10,0],radius:2}]}};doc.features.push(feature);open(()=>doc,apply,feature);tool('extend');point(4.9,0);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints).toEqual(expect.arrayContaining([expect.objectContaining({kind:'coincident',b:{kind:'circle',contour:1}})]));expect(saved.contours[0].segments[0].end).toEqual([8,0]);
});
it('creates a sliding curve contact and preserves the option through undo and save',async()=>{
 const feature={id:'profile',type:'profile',name:'Sliding contact',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'bezier',controls:[[1,0],[2,0]],end:[3,0]}]},{type:'path',start:[0,0],segments:[]}]}};doc.features.push(feature);open(()=>doc,apply,feature);
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:1,kind:'point',index:0});document.querySelector('[aria-label="Entity B"]').value=JSON.stringify({contour:0,kind:'curve',index:0,parameter:0});document.querySelector('[aria-label="Allow curve contacts to slide"]').checked=true;click('Apply constraint');click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.constraints).toEqual(expect.arrayContaining([expect.objectContaining({kind:'coincident',b:{contour:0,kind:'curve',index:0,parameter:0,sliding:true}})]));
});
it('changes a saved contact mode independently with undo and native persistence',async()=>{
 const feature={id:'profile',type:'profile',name:'Contact modes',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[4,0]}]},{type:'path',start:[1,0],segments:[]}],constraints:[{id:'contact',kind:'coincident',a:{kind:'point',contour:1,index:0},b:{kind:'curve',contour:0,index:0,parameter:.25}}]}};doc.features.push(feature);open(()=>doc,apply,feature);
 const control=()=>document.querySelector('[aria-label="Sliding contact contact b"]');expect(control().checked).toBe(false);control().checked=true;control().dispatchEvent(new Event('change'));click('Undo');expect(control().checked).toBe(false);click('Redo');expect(control().checked).toBe(true);control().checked=false;control().dispatchEvent(new Event('change'));click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.contours).toEqual(feature.profile.contours);expect(saved.constraints[0]).toMatchObject({id:'contact',b:{parameter:.25,sliding:false}});
});
it('splits a curve while retaining its sliding contact on the correct piece',async()=>{
 const feature={id:'profile',type:'profile',name:'Split contact',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'bezier',controls:[[1,0],[2,0]],end:[3,0]}]},{type:'path',start:[2.25,0],segments:[]}],constraints:[{id:'contact',kind:'coincident',a:{kind:'point',contour:1,index:0},b:{kind:'curve',contour:0,index:0,parameter:.75,sliding:true}}]}};doc.features.push(feature);open(()=>doc,apply,feature);tool('split');point(1.5,0);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.contours[0].segments).toHaveLength(2);expect(saved.constraints[0].b).toMatchObject({index:1,parameter:expect.closeTo(.5),sliding:true});expect(saved.contours[1]).toEqual(feature.profile.contours[1]);
});

it('selects the sketch origin for dimensions with undo and native persistence',async()=>{
 const feature={id:'profile',type:'profile',name:'Origin distance',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'path',start:[3,4],segments:[]}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);
 const a=document.querySelector('[aria-label="Entity A"]');a.value=JSON.stringify({contour:0,kind:'point',index:0});
 click('Select sketch origin');expect(JSON.parse(document.querySelector('[aria-label="Entity B"]').value)).toEqual({contour:1,kind:'point',index:0});expect(JSON.parse(a.value).contour).toBe(0);
 click('Undo');expect(document.querySelectorAll('[data-constraint-kind="fix"]')).toHaveLength(0);click('Redo');click('Select sketch origin');expect(document.querySelectorAll('[data-constraint-kind="fix"]')).toHaveLength(1);
 const kind=document.querySelector('[aria-label="Constraint"]');kind.value='distance';kind.dispatchEvent(new Event('change'));document.querySelector('[aria-label="Constraint value"]').value='10';click('Apply constraint');
 expect(document.querySelectorAll('[data-constraint-kind="distance"]')).toHaveLength(1);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(saved.contours).toHaveLength(2);expect(saved.contours[1].construction).toBe(true);expect(Math.hypot(...saved.contours[1].start)).toBeLessThan(1e-7);expect(Math.hypot(...saved.contours[0].start)).toBeCloseTo(10,5);
});
it('trims finite contacts with undo and native persistence',async()=>{
 const feature={id:'profile',type:'profile',name:'Trim contacts',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[
 {type:'path',start:[0,0],segments:[{type:'line',end:[10,0]}]},
 {type:'path',construction:true,start:[3,-5],segments:[{type:'line',end:[3,5]}]},
 {type:'path',construction:true,start:[7,-5],segments:[{type:'line',end:[7,5]}]},
 {type:'path',start:[9,0],segments:[]},{type:'path',start:[5,0],segments:[]}
 ],constraints:[{id:'retained',kind:'coincident',a:{kind:'point',contour:3,index:0},b:{kind:'curve',contour:0,index:0,parameter:.9,sliding:true}},{id:'removed',kind:'coincident',a:{kind:'point',contour:4,index:0},b:{kind:'curve',contour:0,index:0,parameter:.5}}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('trim');point(5.5,0);
 expect(document.querySelector('[data-constraint-id="removed"]')).toBeNull();expect(document.querySelector('[data-constraint-id="retained"]')).not.toBeNull();
 click('Undo');expect(document.querySelector('[data-constraint-id="removed"]')).not.toBeNull();click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 const c=saved.constraints.find(c=>c.id==='retained');expect(c.b).toMatchObject({kind:'curve',contour:1,index:0,sliding:true});expect(c.b.parameter).toBeCloseTo(2/3,5);expect(saved.constraints.some(c=>c.id==='removed')).toBe(false);
});
it('keeps an existing curve contact stationary during extension with undo and native save',async()=>{
 const feature={id:'profile',type:'profile',name:'Extend contact',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[
 {type:'path',start:[0,0],segments:[{type:'line',end:[4,0]}]},
 {type:'path',start:[8,-5],segments:[{type:'line',end:[8,5]}]},
 {type:'path',start:[2,0],segments:[]}
 ],constraints:[{id:'contact',kind:'coincident',a:{kind:'point',contour:2,index:0},b:{kind:'curve',contour:0,index:0,parameter:.5,sliding:true}}]}};
 doc.features.push(feature);open(()=>doc,apply,feature);tool('extend');point(3.9,0);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(saved.contours[0].segments[0].end).toEqual([8,0]);expect(saved.contours[2].start).toEqual([2,0]);expect(saved.constraints.find(c=>c.id==='contact').b).toMatchObject({parameter:.25,sliding:true});
});
it('imports negative-normal DXF object coordinates with preview, undo and native save',async()=>{
 open(()=>doc,apply);click('Top (XY)');
 const file=document.querySelector('[aria-label="DXF file"]');document.querySelector('[aria-label="DXF source units"]').value='1';
 const text='0\nSECTION\n2\nENTITIES\n0\nCIRCLE\n10\n3\n20\n2\n40\n1\n210\n0\n220\n0\n230\n-1\n0\nENDSEC\n0\nEOF';
 Object.defineProperty(file,'files',{value:[{text:async()=>text}]});file.dispatchEvent(new dom.window.Event('change'));
 await vi.waitFor(()=>expect(document.querySelector('.sketch-dxf-preview circle')).not.toBeNull());
 click('Insert DXF');click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(parsePartDocument(serializePartDocument(doc)).features[0].profile.contours[0]).toMatchObject({type:'circle',center:[-3,2],radius:1});
});
it('edits polygon sides inline and preserves the new topology through undo and native save',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('inscribed-polygon');document.querySelector('[aria-label="Polygon sides"]').value='6';point(2,3);point(12,3);tool('select');
 const a=document.querySelector('[aria-label="Entity A"]');a.value=JSON.stringify({contour:0,kind:'point',index:0});click('Edit polygon sides');expect(document.querySelector('[aria-label="Polygon side count"]').value).toBe('6');document.querySelector('[aria-label="Polygon side count"]').value='8';click('Apply polygon sides');
 click('Undo');click('Edit polygon sides');expect(document.querySelector('[aria-label="Polygon side count"]').value).toBe('6');click('Cancel polygon edit');click('Redo');click('Edit polygon sides');expect(document.querySelector('[aria-label="Polygon side count"]').value).toBe('8');click('Cancel polygon edit');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.contours[0].segments).toHaveLength(8);expect(saved.contours[1]).toMatchObject({type:'circle',center:[2,3],radius:10});
});
it('retains attached edge constraints while editing polygon sides and saving',async()=>{
 const {constrainSketchPolygon,sketchVariantContour}=await import('@aether/core/sketch');
 const drawing=constrainSketchPolygon({type:'drawing',contours:[sketchVariantContour('circumscribed-polygon',[[0,0],[10,0]],6)]},0,[0,0],true);
 drawing.constraints.push({id:'vertical-side',kind:'vertical',a:{kind:'line',contour:0,index:0}});
 const feature={id:'profile',type:'profile',name:'Attached polygon',plane:'XY',offsetMillimeters:0,suppressed:false,profile:drawing};doc.features.push(feature);open(()=>doc,apply,feature);
 document.querySelector('[aria-label="Entity A"]').value=JSON.stringify({contour:0,kind:'line',index:0});click('Edit polygon sides');document.querySelector('[aria-label="Polygon side count"]').value='12';click('Apply polygon sides');expect(document.querySelector('[data-constraint-id="vertical-side"]')).not.toBeNull();click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;expect(saved.contours[0].segments).toHaveLength(12);expect(saved.constraints.find(c=>c.id==='vertical-side')).toMatchObject({kind:'vertical',a:{kind:'line',contour:0,index:0}});
});
it('previews polygon side changes without mutation and supports Escape, Enter and invalid counts',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('inscribed-polygon');document.querySelector('[aria-label="Polygon sides"]').value='6';point(2,3);point(12,3);tool('select');
 const a=document.querySelector('[aria-label="Entity A"]');a.value=JSON.stringify({contour:0,kind:'point',index:0});
 const original=document.querySelector('path.sketch-contour').getAttribute('d');click('Edit polygon sides');
 let count=document.querySelector('[aria-label="Polygon side count"]');count.value='8';count.dispatchEvent(new Event('input'));
 expect(document.querySelector('.sketch-polygon-preview path').getAttribute('d').match(/L/g)).toHaveLength(8);expect(document.querySelector('path.sketch-contour').getAttribute('d')).toBe(original);
 count.value='2';count.dispatchEvent(new Event('input'));expect(document.querySelector('.sketch-polygon-preview')).toBeNull();expect([...document.querySelectorAll('button')].find(b=>b.textContent==='Apply polygon sides').disabled).toBe(true);
 count.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));expect(document.querySelector('[aria-label="Polygon side count"]')).toBeNull();expect(document.querySelector('.cad-sketch-workspace')).not.toBeNull();
 click('Edit polygon sides');count=document.querySelector('[aria-label="Polygon side count"]');expect(count.value).toBe('6');count.value='8';count.dispatchEvent(new Event('input'));count.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Enter',bubbles:true}));expect(document.querySelector('.sketch-polygon-preview')).toBeNull();
 click('Undo');expect(document.querySelector('path.sketch-contour').getAttribute('d')).toBe(original);click('Redo');click('Edit polygon sides');click('Undo');expect(document.querySelector('.sketch-polygon-preview')).toBeNull();expect(document.querySelector('[aria-label="Polygon side count"]')).toBeNull();click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));expect(doc.features[0].profile.contours[0].segments).toHaveLength(8);
});
it('previews a circular slot with a width handle, undoes and saves editable boundaries',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('circle');point(0,0);point(10,0);tool('slot');point(10,0);
 expect(document.querySelectorAll('.sketch-slot-preview circle')).toHaveLength(2);expect(document.querySelector('[aria-label="Slot width handle"]')).not.toBeNull();
 const width=document.querySelector('[aria-label="Slot width (mm)"]');width.value='4';width.dispatchEvent(new Event('input'));click('Apply slot');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(3);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)),d=saved.features[0].profile;expect(d.contours[0].construction).toBe(true);expect(d.contours[1]).toMatchObject({radius:12,hole:false});expect(d.contours[2]).toMatchObject({radius:8,hole:true});expect(d.constraints.filter(c=>c.kind==='slot').map(c=>c.slotBoundary)).toEqual(['outer','inner']);
 open(()=>doc,apply,saved.features[0]);const input=document.querySelector('[aria-label="slot value"]');input.value='6';input.parentElement.querySelector('button').click();click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));const ring=doc.features[0].profile;expect(ring.contours[1].radius-ring.contours[2].radius).toBeCloseTo(6,5);
});
it('creates a closed-chain slot with preview, undo and editable saved width',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('rectangle');point(0,0);point(20,10);tool('slot');
 const mode=document.querySelector('[aria-label="Slot selection"]');mode.value='chains';mode.dispatchEvent(new Event('change'));const list=document.querySelector('[aria-label="Slot centerlines"]');expect(list.options[0].textContent).toContain('closed chain');list.options[0].selected=true;list.dispatchEvent(new Event('change'));
 expect(document.querySelectorAll('.sketch-slot-preview path')).toHaveLength(2);expect(document.querySelector('[aria-label="Slot width handle"]')).not.toBeNull();click('Apply slot');click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.contours[2].hole).toBe(true);open(()=>doc,apply,saved.features[0]);const input=document.querySelector('[aria-label="slot value"]');input.value='3';input.parentElement.querySelector('button').click();click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));expect(doc.features[0].profile.constraints.find(c=>c.kind==='slot'&&c.value!==undefined).value).toBe(3);
});

it('previews and inserts a smooth cubic point with undo, redo and native reopen',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('cubic-bezier');point(0,0);point(0,10);point(10,10);point(10,0);
 tool('insert-spline-point');move(5,7.5);
 const marker=document.querySelector('[data-spline-insertion-point]');expect(marker).toBeTruthy();expect(Number(marker.getAttribute('cx'))).toBeCloseTo(5);expect(Number(marker.getAttribute('cy'))).toBeCloseTo(-7.5);
 expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(1);
 point(5,7.5);expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(2);
 click('Undo');expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(1);
 click('Redo');expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(2);
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features[0].profile.constraints.some(c=>c.kind==='curvature')).toBe(true);
 open(()=>doc,apply,saved.features[0]);expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(2);
});

it('rejects spline insertion at an endpoint without creating an undo step',()=>{
 open(()=>doc,apply);click('Top (XY)');tool('cubic-bezier');point(0,0);point(0,10);point(10,10);point(10,0);
 tool('insert-spline-point');move(0,0);expect(document.querySelector('[data-spline-insertion-point]')).toBeNull();point(0,0);
 expect(document.querySelector('[role="status"]').textContent).toContain('endpoints');
 expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(1);
 click('Undo');expect(document.querySelector('.sketch-contour')).toBeNull();
});

it('inserts a fit-spline point with preview, undo and saved parameter intervals',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('fit-spline');point(0,0);point(10,8);point(20,0);click('Finish spline');
 const {segmentPoint}=await import('../engine/src/sketch/curves/parameterization');
 // Symmetric natural spline passes through its middle fit point; select a span interior.
 const {fitSketchSpline}=await import('@aether/core/sketch');const shape=fitSketchSpline([[0,0],[10,8],[20,0]]);const p=segmentPoint(shape.start,shape.segments[0],.5);
 tool('insert-spline-point');move(...p);expect(document.querySelector('[data-spline-insertion-point]')).toBeTruthy();point(...p);
 expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(3);click('Undo');expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(2);click('Redo');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0];expect(saved.profile.constraints.find(c=>c.kind==='spline-shape').splineSpanIntervals).toHaveLength(3);
 open(()=>doc,apply,saved);expect(document.querySelector('.sketch-contour').getAttribute('d').match(/C/g)).toHaveLength(3);
});

it('selects and dimensions a persistent spline tangent handle',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('cubic-bezier');point(0,0);point(0,5);point(10,5);point(10,0);
 const a=()=>document.querySelector('[aria-label="Entity A"]');
 const curve=[...a().options].find(o=>{const r=JSON.parse(o.value);return r.kind==='curve'&&r.contour===0;});expect(curve).toBeTruthy();a().value=curve.value;
 click('Select spline start handle');expect(JSON.parse(a().value)).toMatchObject({kind:'line',contour:1,index:0});
 click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Redo');
 a().value=curve.value;click('Select spline start handle');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'length'}));document.querySelector('[aria-label="Constraint value"]').value='8';click('Apply constraint');
 click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));const saved=parsePartDocument(serializePartDocument(doc)).features[0];
 expect(saved.profile.contours[1].construction).toBe(true);expect(saved.profile.constraints.find(c=>c.kind==='length').value).toBe(8);
 open(()=>doc,apply,saved);expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
});

it('inserts a spline point while retaining a dimensioned tangent handle',async()=>{
 open(()=>doc,apply);click('Top (XY)');tool('cubic-bezier');point(0,0);point(0,5);point(10,5);point(10,0);
 const a=document.querySelector('[aria-label="Entity A"]');a.value=[...a.options].find(o=>o.value&&JSON.parse(o.value).kind==='curve').value;
 click('Select spline start handle');window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'length'}));document.querySelector('[aria-label="Constraint value"]').value='5';click('Apply constraint');
 tool('insert-spline-point');move(5,3.75);expect(document.querySelector('[data-spline-insertion-point]')).toBeTruthy();point(5,3.75);click('Undo');click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc)).features[0].profile;
 expect(saved.contours[0].segments).toHaveLength(2);expect(saved.constraints.some(c=>c.b?.controlScale===2)).toBe(true);expect(saved.constraints.find(c=>c.kind==='length').value).toBe(5);
});

it('authors alongside live projected geometry without copying or detaching it',async()=>{
 const source={id:'source',type:'profile',name:'Source',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'circle',centerMillimeters:[0,0],radiusMillimeters:5}};
 const linked={id:'linked',type:'profile',name:'Linked',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'projection',sourceFeatureId:'source'}};
 doc.features.push(source,linked);open(()=>doc,apply,linked);
 expect(document.querySelector('.sketch-projected-background circle').getAttribute('r')).toBe('5');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);
 tool('circle');point(20,0);point(22,0);click('Undo');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(0);expect(document.querySelector('.sketch-projected-background circle')).toBeTruthy();click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));expect(doc.features[1].profile).toMatchObject({type:'projection',sourceFeatureId:'source',authored:{contours:[{type:'circle',center:[20,0],radius:2}]}});
 doc.features[0].profile.radiusMillimeters=8;open(()=>doc,apply,doc.features[1]);expect(document.querySelector('.sketch-projected-background circle').getAttribute('r')).toBe('8');expect(document.querySelectorAll('.sketch-contour')).toHaveLength(1);click('Cancel');expect(apply).toHaveBeenCalledTimes(1);
});

it('constrains authored geometry to a projected circle and saves no derived context',async()=>{
 const source={id:'source',type:'profile',name:'Source',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{id:'rim',type:'circle',center:[10,0],radius:5}]}};
 const linked={id:'linked',type:'profile',name:'Linked',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'projection',sourceFeatureId:'source'}};
 doc.features.push(source,linked);open(()=>doc,apply,linked);tool('circle');point(0,0);point(2,0);
 window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'concentric'}));
 const a=document.querySelector('[aria-label="Entity A"]'),b=document.querySelector('[aria-label="Entity B"]');
 const option=(select,predicate)=>[...select.options].find(o=>o.value&&predicate(JSON.parse(o.value))).value;
 a.value=option(a,r=>r.kind==='circle'&&r.contour===0);b.value=option(b,r=>r.kind==='circle'&&r.projectedContourId==='rim');click('Apply constraint');
 expect(Number(document.querySelector('.sketch-contour').getAttribute('cx'))).toBeCloseTo(10);
 click('Undo');expect(Number(document.querySelector('.sketch-contour').getAttribute('cx'))).toBeCloseTo(0);click('Redo');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));expect(doc.features[1].profile.authored.projectionContext).toBeUndefined();expect(doc.features[1].profile.authored.contours).toHaveLength(1);
 doc.features[0].profile.contours[0].center=[15,0];open(()=>doc,apply,doc.features[1]);expect(Number(document.querySelector('.sketch-contour').getAttribute('cx'))).toBeCloseTo(15);click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));expect(doc.features[1].profile.authored.contours[0].center[0]).toBeCloseTo(15);
});

it('selects projected geometry on canvas for constraints while preventing source dragging',async()=>{
 const source={id:'source',type:'profile',name:'Source',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{id:'rim',type:'circle',center:[10,0],radius:5}]}};
 const linked={id:'linked',type:'profile',name:'Linked',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'projection',sourceFeatureId:'source',authored:{type:'drawing',contours:[{type:'circle',center:[0,0],radius:2}]}}};
 doc.features.push(source,linked);open(()=>doc,apply,linked);window.dispatchEvent(new CustomEvent('aether-sketch-constraint',{detail:'concentric'}));
 const svg=document.querySelector('[aria-label="2D sketch canvas"]');move(2,0);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:2,clientY:0,bubbles:true}));move(15,0);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:15,clientY:0,bubbles:true}));
 expect(JSON.parse(document.querySelector('[aria-label="Entity B"]').value)).toMatchObject({projectedContourId:'rim',kind:'circle'});expect(document.querySelector('.sketch-selection circle').getAttribute('r')).toBe('5');expect(document.querySelector('[aria-label="Selected entity constraint state"]').textContent).toContain('read-only');
 const pointer=(type,x,y)=>{const e=new dom.window.MouseEvent(type,{clientX:x,clientY:-y,bubbles:true,button:0});Object.defineProperty(e,'pointerId',{value:8});svg.dispatchEvent(e);};pointer('pointerdown',15,0);pointer('pointermove',18,2);pointer('pointerup',18,2);
 expect(document.querySelector('.sketch-projected-background circle').getAttribute('cx')).toBe('10');click('Apply constraint');click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(doc.features[0].profile.contours[0].center).toEqual([10,0]);expect(doc.features[1].profile.authored.contours[0].center[0]).toBeCloseTo(10);
});

it('snaps a newly drawn endpoint to projected geometry with a saved source relation',async()=>{
 const source={id:'source',type:'profile',name:'Source',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{id:'edge',type:'path',start:[10,5],segments:[{type:'line',end:[20,5]}]}]}};
 const linked={id:'linked',type:'profile',name:'Linked',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'projection',sourceFeatureId:'source'}};
 doc.features.push(source,linked);open(()=>doc,apply,linked);tool('line');move(10.2,5.1);const svg=document.querySelector('[aria-label="2D sketch canvas"]');svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:10.2,clientY:-5.1,bubbles:true}));move(10,15);svg.dispatchEvent(new dom.window.MouseEvent('click',{clientX:10,clientY:-15,bubbles:true}));click('Finish sketch');await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const authored=doc.features[1].profile.authored;expect(authored.contours[0].start).toEqual([10,5]);expect(authored.constraints.some(c=>c.b?.projectedContourId==='edge')).toBe(true);
 doc.features[0].profile.contours[0].start=[12,8];doc.features[0].profile.contours[0].segments[0].end=[22,8];open(()=>doc,apply,doc.features[1]);const coordinates=document.querySelector('.sketch-contour').getAttribute('d').match(/[-+]?[0-9]*\.?[0-9]+(?:e[-+]?[0-9]+)?/gi).map(Number);expect(coordinates[0]).toBeCloseTo(12);expect(coordinates[1]).toBeCloseTo(-8);
});
