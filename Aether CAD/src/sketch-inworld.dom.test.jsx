import { createRequire } from 'node:module';
import { beforeAll,beforeEach,afterEach,afterAll,expect,it,vi } from 'vitest';
import { createEmptyPartDocument } from '@aether/core/document';
const require=createRequire(new URL('../../core/ui/package.json',import.meta.url));
const {JSDOM}=require('jsdom');
let dom,open,doc,apply;
beforeAll(async()=>{
 dom=new JSDOM('<!doctype html><html><body></body></html>',{url:'http://localhost/cad/index.html'});
 for(const key of ['window','document','HTMLElement','CustomEvent','Event','location'])vi.stubGlobal(key,dom.window[key]);
 open=(await import('./sketch-workspace')).openSketchWorkspace;
});
beforeEach(()=>{document.body.innerHTML='<div class="cad-studio-viewport"></div>';doc=createEmptyPartDocument('Part');apply=vi.fn(async next=>{doc=next;});});
afterEach(()=>{document.querySelector('.cad-sketch-workspace')?.querySelectorAll('button').forEach(b=>{if(b.textContent==='Cancel')b.click();});});
afterAll(()=>{dom.window.close();vi.unstubAllGlobals();});
const svgClick=(x,y)=>{document.querySelector('[aria-label="2D sketch canvas"]').dispatchEvent(new dom.window.MouseEvent('click',{clientX:x,clientY:y}));};

it('hands the sketch surface to the viewer with the plane frame and draws through its raycast bridge',async()=>{
 const surfaces=[];const boundsUpdates=[];let ended=0;
 const onSurface=e=>{surfaces.push(e.detail);e.detail.connect({
  toSketch:(x,y)=>[x,-y],
  scaleAt:()=>0.5,
  updateBounds:b=>boundsUpdates.push({...b}),
 });};
 const onEnd=()=>{ended+=1;};
 window.addEventListener('aether-sketch-surface',onSurface);
 window.addEventListener('aether-sketch-surface-end',onEnd);
 try{
  open(()=>doc,apply);
  window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
  expect(surfaces).toHaveLength(1);
  expect(surfaces[0].frame).toEqual({originMillimeters:[0,0,0],normal:[0,0,1],xDirection:[1,0,0]});
  expect(surfaces[0].svg.getAttribute('aria-label')).toBe('2D sketch canvas');
  const root=document.querySelector('.cad-sketch-workspace');
  expect(root.classList.contains('in-world')).toBe(true);
  // Placing the plane arms nothing; the line tool must be chosen explicitly.
  expect(document.querySelector('[role="status"]').textContent).toContain('select');
  window.dispatchEvent(new CustomEvent('aether-sketch-tool',{detail:'line'}));
  // Two clicks: bridge raycast (client → sketch mm, y-up) places the line.
  svgClick(10,-20);svgClick(30,-20);
  expect(document.querySelector('[role="status"]').textContent).toContain('1 open');
  // Drawing far outside the initial 200 mm view grows the view bounds.
  svgClick(300,-20);
  const grown=boundsUpdates.at(-1);
  expect(grown).toBeTruthy();
  expect(grown.x+grown.width).toBeGreaterThanOrEqual(325);
  click('Finish sketch');
  await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
  const contour=doc.features[0].profile.contours[0];
  expect(contour.start).toEqual([10,20]);
  expect(contour.segments[0].end).toEqual([30,20]);
  expect(ended).toBe(1);
  expect(document.querySelector('.cad-sketch-workspace')).toBeNull();
 }finally{
  window.removeEventListener('aether-sketch-surface',onSurface);
  window.removeEventListener('aether-sketch-surface-end',onEnd);
 }
});

it('falls back to the flat overlay when no viewer answers the surface event',()=>{
 open(()=>doc,apply);
 window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
 const root=document.querySelector('.cad-sketch-workspace');
 expect(root.classList.contains('in-world')).toBe(false);
 expect(root.querySelector('.cad-sketch-canvas')).toBeTruthy();
 click('Cancel');
 expect(apply).not.toHaveBeenCalled();
});

it('finishes an empty sketch — the plane choice alone defines it',async()=>{
 open(()=>doc,apply);
 window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XZ'}));
 click('Finish sketch');
 await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 expect(doc.features[0].plane).toBe('XZ');
 expect(doc.features[0].profile.contours).toHaveLength(0);
 expect(document.querySelector('.cad-sketch-workspace')).toBeNull();
});

it('creates a plane instantly with a floating edit window; discard removes it',async()=>{
 const {mountFeatureAuthoring}=await import('./feature-authoring');
 const {cadCommands}=await import('./cad-command-registry');
 mountFeatureAuthoring(()=>doc,apply);
 cadCommands.execute('feature-plane');
 await vi.waitFor(()=>expect(doc.features).toHaveLength(1));
 expect(doc.features[0]).toMatchObject({type:'plane',name:'Plane 1',plane:'XY',offsetMillimeters:10});
 expect(document.querySelector('dialog')).toBeNull();
 const win=document.querySelector('.cad-plane-window');
 expect(win).toBeTruthy();
 win.querySelector('[aria-label="Discard plane"]').click();
 await vi.waitFor(()=>expect(doc.features).toHaveLength(0));
 expect(document.querySelector('.cad-plane-window')).toBeNull();
});

function click(label){const b=[...document.querySelectorAll('button')].find(b=>b.textContent===label&&!b.closest('[hidden]'));expect(b).toBeTruthy();b.click();}

// The in-world svg is reparented out of .cad-sketch-workspace into the viewer's
// CSS3D layer, so any geometry rule scoped under that ancestor silently stops
// matching and the sketch renders invisible. Scope geometry to the canvas.
it('scopes sketch geometry styling to the canvas, not the workspace ancestor',async()=>{
 const {readFileSync}=await import('node:fs');
 const css=readFileSync(new URL('./sketch-workspace.css',import.meta.url),'utf8');
 const orphaned=css.split('\n').filter(line=>/^[^{]*\.cad-sketch-workspace[^{]*\.sketch-|^[^{]*\.cad-sketch-workspace\s+svg/.test(line));
 expect(orphaned).toEqual([]);
});

// The shared @aether/ui feature window mounts inside .cad-sketch-workspace, and a
// bare element selector under that ancestor (0,1,1) outranks the widget's own
// single-class rules (0,1,0) — that is how the app silently stopped matching the
// UI gallery. The gallery is the design authority; this sheet styles sketch
// geometry only.
it('never restyles the shared feature window with bare element selectors',async()=>{
 const {readFileSync}=await import('node:fs');
 const css=readFileSync(new URL('./sketch-workspace.css',import.meta.url),'utf8');
 const leaking=css.split('\n').filter(line=>
  /^\.cad-sketch-workspace[^{,]*\s(aside|button|input|select|textarea|label|p|h[1-6])\b/.test(line));
 expect(leaking).toEqual([]);
});

// Picking a plane switches the viewer OUT of plane-selection mode. Clearing the
// plane chip must switch it back on, or the viewport stops routing clicks to
// plane/face picking and only the first selection of a sketch ever commits.
it('re-arms viewport plane picking after the sketch plane is cleared',async()=>{
 const selecting=[];
 const onSelecting=e=>selecting.push(e.detail);
 window.addEventListener('aether-sketch-plane-selection',onSelecting);
 try{
  open(()=>doc,apply);
  expect(selecting.at(-1)).toBe(true);            // opens asking for a plane
  window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
  expect(selecting.at(-1)).toBe(false);           // plane chosen — picking off
  const chip=[...document.querySelectorAll('button')]
   .find(b=>/remove/i.test(b.getAttribute('aria-label')??''));
  expect(chip,'no remove control on the sketch-plane chip').toBeTruthy();
  chip.click();
  expect(selecting.at(-1),'clearing the plane must re-arm picking').toBe(true);
  // and a second pick must still commit
  window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XZ'}));
  expect(selecting.at(-1)).toBe(false);
  expect(document.querySelector('.cad-sketch-workspace').classList.contains('choosing-plane')).toBe(false);
 }finally{window.removeEventListener('aether-sketch-plane-selection',onSelecting);}
});
