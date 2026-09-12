import { createRequire } from 'node:module';
import { beforeAll,beforeEach,afterAll,expect,it,vi } from 'vitest';
import { createEmptyPartDocument } from '@aether/core/document';
const require=createRequire(new URL('../../core/ui/package.json',import.meta.url));
const {JSDOM}=require('jsdom');
let dom,openPlane,doc,apply;
beforeAll(async()=>{
 dom=new JSDOM('<!doctype html><html><body></body></html>',{url:'http://localhost/cad/index.html'});
 for(const key of ['window','document','HTMLElement','HTMLTextAreaElement','CustomEvent','Event','KeyboardEvent','location'])vi.stubGlobal(key,dom.window[key]);
 openPlane=(await import('./plane-window')).openPlaneWindow;
});
beforeEach(()=>{document.body.innerHTML='<div class="cad-studio-viewport"></div>';doc=createEmptyPartDocument('Part');apply=vi.fn(async next=>{doc=next;});});
afterAll(()=>{dom.window.close();vi.unstubAllGlobals();});

it('authors a mid plane from viewport/tree picked references and commits on Enter',async()=>{
 doc.features.push({id:'base',type:'plane',name:'Plane 1',plane:'XY',offsetMillimeters:30,suppressed:false});
 await openPlane(()=>doc,apply);
 await vi.waitFor(()=>expect(doc.features).toHaveLength(2));
 const win=document.querySelector('.cad-plane-window');
 expect(win.classList.contains('aui-feature-window')).toBe(true);
 // The method is an anchored picker: open it and choose Mid plane.
 win.querySelector('[aria-label="Plane method"]').click();
 [...win.querySelectorAll('.aui-feature-picker-menu button')].find(b=>b.textContent==='Mid plane').click();
 // A new plane starts with nothing selected — no auto-populated reference.
 expect(win.querySelectorAll('.aui-feature-entity')).toHaveLength(0);
 // Entities arrive from clicks in the viewport/tree, not a picker widget.
 window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
 window.dispatchEvent(new CustomEvent('aether-plane-feature-picked',{detail:{featureId:'base'}}));
 expect([...win.querySelectorAll('.aui-feature-entity')].map(e=>e.textContent)).toEqual(['Top plane×','Plane 1×']);
 win.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'Enter',bubbles:true}));
 await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(2));
 expect(doc.features[1].definition).toEqual({method:'mid',references:[{kind:'principal',plane:'XY'},{kind:'feature',featureId:'base'}]});
});

it('starts empty and validates the reference count against the chosen method',async()=>{
 await openPlane(()=>doc,apply);
 await vi.waitFor(()=>expect(doc.features).toHaveLength(1));
 const win=document.querySelector('.cad-plane-window');
 const accept=win.querySelector('[aria-label="Apply plane"]');
 const status=()=>win.querySelector('.aui-feature-error')?.textContent ?? '';
 const pickMethod=name=>{
  win.querySelector('[aria-label="Plane method"]').click();
  [...win.querySelectorAll('.aui-feature-picker-menu button')].find(b=>b.textContent===name).click();
 };

 // Nothing is pre-selected, so Offset is short of its one reference and the
 // window refuses to commit until that is fixed.
 expect(win.querySelectorAll('.aui-feature-entity')).toHaveLength(0);
 expect(status()).toContain('exactly 1 reference plane');
 expect(accept.disabled).toBe(true);

 window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
 expect(win.querySelectorAll('.aui-feature-entity')).toHaveLength(1);
 expect(accept.disabled).toBe(false);

 // Switching method re-validates against the NEW arity: one is now too few.
 pickMethod('Mid plane');
 expect(status()).toContain('exactly 2 reference planes');
 expect(accept.disabled).toBe(true);

 win.querySelector('[aria-label="Remove Top plane"]').click();
 expect(win.querySelectorAll('.aui-feature-entity')).toHaveLength(0);
 expect(status()).toContain('0 selected');

 win.querySelector('[aria-label="Flip normal"]').click();
 // The opacity slider was removed from the standard feature window.
 expect(win.querySelector('input[type="range"]')).toBeNull();
});

// The plane feature exists in the document from the moment the window opens, so
// the viewport must show what the controls describe — not the seeded definition
// until commit, and nothing at all while the definition is incomplete.
it('previews the plane live as references and offset change',async()=>{
 doc.features.push({id:'base',type:'plane',name:'Plane 1',plane:'XY',offsetMillimeters:30,suppressed:false});
 const previews=[];
 const onPreview=e=>previews.push(e.detail);
 window.addEventListener('aether-plane-preview',onPreview);
 try{
  await openPlane(()=>doc,apply);
  await vi.waitFor(()=>expect(doc.features).toHaveLength(2));
  const win=document.querySelector('.cad-plane-window');
  const id=doc.features[1].id;

  // Nothing selected yet: the plane is hidden rather than showing the seed.
  expect(previews.at(-1)).toMatchObject({featureId:id,frame:null});

  window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XY'}));
  const offset=win.querySelector('[aria-label="Offset distance"]');
  offset.value='40';
  offset.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
  // One reference plus a finite distance resolves to a real frame.
  expect(previews.at(-1).frame).toMatchObject({normal:[0,0,1],originMillimeters:[0,0,40]});

  // Removing the reference takes the plane back off screen.
  win.querySelector('[aria-label="Remove Top plane"]').click();
  expect(previews.at(-1).frame).toBeNull();

  // Closing the window clears the preview too.
  win.querySelector('[aria-label="Discard plane"]').click();
  await vi.waitFor(()=>expect(previews.at(-1).frame).toBeNull());
 }finally{window.removeEventListener('aether-plane-preview',onPreview);}
});

// Orange means "selected" everywhere: the references a feature is using must be
// reported to the viewport so the entity chips and the geometry agree.
it('reports the referenced planes so the viewport can highlight them',async()=>{
 doc.features.push({id:'base',type:'plane',name:'Plane 1',plane:'XY',offsetMillimeters:30,suppressed:false});
 const highlights=[];
 const onHighlight=e=>highlights.push(e.detail.references);
 window.addEventListener('aether-plane-highlight',onHighlight);
 try{
  await openPlane(()=>doc,apply);
  await vi.waitFor(()=>expect(doc.features).toHaveLength(2));
  const win=document.querySelector('.cad-plane-window');
  expect(highlights.at(-1)).toEqual([]);

  window.dispatchEvent(new CustomEvent('aether-sketch-plane',{detail:'XZ'}));
  expect(highlights.at(-1)).toEqual([{kind:'principal',plane:'XZ'}]);

  // A second reference joins the highlight, matching the entity chips.
  win.querySelector('[aria-label="Plane method"]').click();
  [...win.querySelectorAll('.aui-feature-picker-menu button')].find(b=>b.textContent==='Mid plane').click();
  window.dispatchEvent(new CustomEvent('aether-plane-feature-picked',{detail:{featureId:'base'}}));
  expect(highlights.at(-1)).toEqual([{kind:'principal',plane:'XZ'},{kind:'feature',featureId:'base'}]);

  // Removing a chip clears that plane's highlight.
  win.querySelector('[aria-label="Remove Front plane"]').click();
  expect(highlights.at(-1)).toEqual([{kind:'feature',featureId:'base'}]);

  // Closing releases every highlight.
  win.querySelector('[aria-label="Discard plane"]').click();
  await vi.waitFor(()=>expect(highlights.at(-1)).toEqual([]));
 }finally{window.removeEventListener('aether-plane-highlight',onHighlight);}
});
