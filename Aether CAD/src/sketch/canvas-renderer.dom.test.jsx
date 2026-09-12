import { createRequire } from "node:module";
import { afterAll, beforeAll, expect, it, vi } from "vitest";
import { renderSketchCanvas, SKETCH_PLANE_HALF_MILLIMETRES } from "./canvas-renderer";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom;
beforeAll(() => {
  dom = new JSDOM();
  vi.stubGlobal("document", dom.window.document);
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
it("paints an outer boundary, hole and island in order while preserving entity indices", () => {
  const drawing = {
    type: "drawing",
    contours: [
      { type: "circle", center: [0, 0], radius: 2 },
      {
        type: "path",
        start: [-12, 0],
        segments: [{ type: "line", end: [12, 0] }],
      },
      { type: "circle", center: [0, 0], radius: 5, hole: true },
      { type: "circle", center: [0, 0], radius: 10 },
      { type: "circle", center: [0, 0], radius: 7, construction: true },
    ],
  };
  const before = structuredClone(drawing);
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  renderSketchCanvas(
    svg,
    drawing,
    { x: -15, y: -15, width: 30, height: 30 },
    [],
  );
  const contours = [...svg.querySelectorAll(".sketch-contour")];
  expect(contours.map((c) => c.getAttribute("data-contour-index"))).toEqual([
    "3",
    "2",
    "0",
    "1",
    "4",
  ]);
  expect(contours.slice(0, 3).map((c) => c.getAttribute("r"))).toEqual([
    "10",
    "5",
    "2",
  ]);
  expect(contours[1].classList.contains("hole")).toBe(true);
  expect(contours[2].classList.contains("hole")).toBe(false);
  expect(drawing).toEqual(before);
});

it("keeps the grid bounded when fitting a very large projected sketch",()=>{
 const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
 renderSketchCanvas(svg,{type:"drawing",contours:[]},{x:0,y:0,width:1e9,height:1e9},[]);
 expect(svg.querySelectorAll(".sketch-grid").length).toBeLessThanOrEqual(200);
});
it('renders linked signed axis values from canonical dimensions',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'path',start:[2,3],segments:[{type:'line',end:[-3,-2]}]}],constraints:[{id:'x',kind:'horizontal-distance',a:{kind:'point',contour:0,index:0},b:{kind:'point',contour:0,index:1},value:-5},{id:'y',kind:'vertical-distance',a:{kind:'point',contour:0,index:0},b:{kind:'point',contour:0,index:1},valueFrom:'x'}]};
 renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[]);
 expect([...svg.querySelectorAll('.sketch-dimension text')].map(t=>t.textContent)).toEqual(['X -5 mm','Y -5 mm ↗']);
 expect(svg.querySelector('.sketch-dimension text').getAttribute('role')).toBe('button');
});
it('renders angle arcs and axis extension guides without altering geometry',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]},{type:'line',end:[10,10]}]}],constraints:[{id:'angle',kind:'angle',a:{kind:'line',contour:0,index:0},b:{kind:'line',contour:0,index:1},value:90},{id:'dx',kind:'horizontal-distance',a:{kind:'point',contour:0,index:0},b:{kind:'point',contour:0,index:2},value:10}]};
 const before=structuredClone(drawing);renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[]);
 expect(svg.querySelector('[data-constraint-id="angle"] text').textContent).toBe('90°');
 expect(svg.querySelector('[data-constraint-id="angle"] path')).toBeTruthy();
 expect(svg.querySelectorAll('[data-constraint-id="dx"] line')).toHaveLength(3);expect(drawing).toEqual(before);
});
it('renders signed offsets and the complete slot width from canonical handles',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]}]},{type:'path',start:[0,-2],segments:[{type:'line',end:[10,-2]}]}],constraints:[{id:'offset',kind:'offset',a:{kind:'line',contour:0,index:0},b:{kind:'line',contour:1,index:0},value:-2},{id:'width',kind:'slot',a:{kind:'line',contour:0,index:0},value:6}]};
 renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[]);
 expect(svg.querySelector('[data-constraint-id="offset"] text').textContent).toBe('Offset -2 mm');
 expect(svg.querySelector('[data-constraint-id="width"] text').textContent).toBe('Width 6 mm');
 const width=svg.querySelector('[data-constraint-id="width"] line');
 expect(Math.abs(Number(width.getAttribute('y2'))-Number(width.getAttribute('y1')))).toBe(6);
 const offset=svg.querySelector('[data-constraint-id="offset"] line');
 expect(offset.getAttribute('y1')).toBe('0');expect(offset.getAttribute('y2')).toBe('2');
});
it('activates dimension labels with the keyboard without forwarding the gesture',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');document.body.append(svg);
 const drawing={type:'drawing',contours:[{type:'circle',center:[0,0],radius:5}],constraints:[{id:'d',kind:'diameter',a:{kind:'circle',contour:0},value:10}]};
 renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[]);
 const edit=vi.fn(),bubble=vi.fn();dom.window.addEventListener('aether-sketch-edit-dimension',edit);svg.addEventListener('keydown',bubble);
 const event=new dom.window.KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true});
 svg.querySelector('.sketch-dimension text').dispatchEvent(event);
 expect(edit).toHaveBeenCalledTimes(1);expect(edit.mock.calls[0][0].detail).toBe('d');expect(bubble).not.toHaveBeenCalled();expect(event.defaultPrevented).toBe(true);
 dom.window.removeEventListener('aether-sketch-edit-dimension',edit);svg.remove();
});
it('rebuilds manual label connectors from current dimension geometry',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'circle',center:[5,5],radius:5}],constraints:[{id:'d',kind:'diameter',a:{kind:'circle',contour:0},value:10}]};
 const positions={d:[20,25]};renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[],positions);
 let leader=svg.querySelector('[data-dimension-leader]');expect(leader.getAttribute('x1')).toBe(svg.querySelector('[data-dimension-measure]').getAttribute('x2'));expect(leader.getAttribute('x2')).toBe('20');
 drawing.contours[0].center=[8,9];renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[],positions);
 leader=svg.querySelector('[data-dimension-leader]');expect(leader.getAttribute('x1')).toBe(svg.querySelector('[data-dimension-measure]').getAttribute('x2'));expect(leader.getAttribute('y1')).toBe(svg.querySelector('[data-dimension-measure]').getAttribute('y2'));expect(leader.getAttribute('y2')).toBe('-25');
});
it('moves X/Y measurement lines and extension endpoints with saved labels',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'path',start:[2,3],segments:[{type:'line',end:[12,13]}]}],constraints:[{id:'x',kind:'horizontal-distance',a:{kind:'point',contour:0,index:0},b:{kind:'point',contour:0,index:1},value:10},{id:'y',kind:'vertical-distance',a:{kind:'point',contour:0,index:0},b:{kind:'point',contour:0,index:1},value:10}]};
 renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[],{x:[7,30],y:[40,8]});
 const x=svg.querySelector('[data-constraint-id="x"] [data-dimension-measure]');expect(x.getAttribute('y1')).toBe('-28');expect(x.getAttribute('y2')).toBe('-28');expect(x.getAttribute('x1')).toBe('2');
 const y=svg.querySelector('[data-constraint-id="y"] [data-dimension-measure]');expect(y.getAttribute('x1')).toBe('40');expect(y.getAttribute('x2')).toBe('40');expect(y.getAttribute('y1')).toBe('-3');
 const guide=svg.querySelector('[data-constraint-id="x"] [data-dimension-extension]');expect(guide.getAttribute('y1')).toBe('-3');expect(guide.getAttribute('y2')).toBe('-28');
});
it('relocates diagonal length and distance guides parallel to their source geometry',()=>{
 for(const kind of ['length','distance']) {
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
  const constraint=kind==='length'?{id:'d',kind,a:{kind:'line',contour:0,index:0},value:Math.sqrt(200)}:{id:'d',kind,a:{kind:'point',contour:0,index:0},b:{kind:'point',contour:0,index:1},value:Math.sqrt(200)};
  const drawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,10]}]}],constraints:[constraint]};
  for(const point of [[20,0],[-20,30]]) {
   renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[],{d:point});
   const line=svg.querySelector('[data-dimension-measure]');
   const dx=Number(line.getAttribute('x2'))-Number(line.getAttribute('x1')),dy=Number(line.getAttribute('y2'))-Number(line.getAttribute('y1'));
   expect(dx).toBeCloseTo(10);expect(dy).toBeCloseTo(-10);
   const extensions=svg.querySelectorAll('[data-dimension-extension]');expect(extensions).toHaveLength(2);
   expect(extensions[0].getAttribute('x1')).toBe('0');expect(extensions[1].getAttribute('y1')).toBe('-10');
   expect(Math.hypot(dx,dy)).toBeCloseTo(Math.sqrt(200));
  }
 }
});
it('orients radial guides toward manual labels and resizes angular arcs',()=>{
 for(const kind of ['radius','diameter']) {
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
  const drawing={type:'drawing',contours:[{type:'circle',center:[0,0],radius:5}],constraints:[{id:'d',kind,a:{kind:'circle',contour:0},value:kind==='radius'?5:10}]};
  renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[],{d:[20,0]});
  const line=svg.querySelector('[data-dimension-measure]');expect(Number(line.getAttribute('x1'))).toBeCloseTo(kind==='radius'?0:-5);expect(Number(line.getAttribute('x2'))).toBeCloseTo(5);expect(Number(line.getAttribute('y2'))).toBeCloseTo(0);
 }
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]},{type:'line',end:[10,10]}]}],constraints:[{id:'a',kind:'angle',a:{kind:'line',contour:0,index:0},b:{kind:'line',contour:0,index:1},value:90}]};
 renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[],{a:[10,26]});
 expect(svg.querySelector('.sketch-dimension path').getAttribute('d')).toContain('A 20 20');
});
it('keeps an arc radius guide on its visible sweep when its label moves outside',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'path',start:[5,0],segments:[{type:'arc',middle:[3,4],end:[-5,0]}]}],constraints:[{id:'r',kind:'radius',a:{kind:'arc',contour:0,index:0},value:5}]};
 renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[],{r:[20,-10]});
 const line=svg.querySelector('[data-dimension-measure]');expect(Number(line.getAttribute('x2'))).toBeCloseTo(5);expect(Number(line.getAttribute('y2'))).toBeCloseTo(0);
});
it('restores automatic radial geometry when manual placement is cancelled',async()=>{
 const {updateCurvedDimensionLayout}=await import('./curved-dimension-layout');
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'circle',center:[0,0],radius:5}],constraints:[{id:'d',kind:'diameter',a:{kind:'circle',contour:0},value:10}]};
 const bounds={x:-60,y:-40,width:120,height:80};renderSketchCanvas(svg,drawing,bounds,[]);
 const original=svg.querySelector('[data-dimension-measure]').outerHTML;
 renderSketchCanvas(svg,drawing,bounds,[],{d:[20,0]});expect(svg.querySelector('[data-dimension-measure]').outerHTML).not.toBe(original);
 updateCurvedDimensionLayout(svg.querySelector('.sketch-dimension text'),false);
 expect(svg.querySelector('[data-dimension-measure]').outerHTML).toBe(original);
});
it('spaces automatic labels around manual placements deterministically without saving layout',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'circle',center:[0,0],radius:5},{type:'circle',center:[0,0],radius:6},{type:'circle',center:[0,0],radius:7}],constraints:[5,6,7].map((r,i)=>({id:`r${i}`,kind:'radius',a:{kind:'circle',contour:i},value:r}))};
 const positions={r0:[2,4]},before=structuredClone(drawing);
 const render=()=>renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[],positions);
 render();
 const coordinates=()=>[...svg.querySelectorAll('.sketch-dimension text')].map(t=>[t.getAttribute('x'),t.getAttribute('y')]);
 const first=coordinates();expect(first[0]).toEqual(['2','-4']);expect(new Set(first.map(p=>p.join(','))).size).toBe(3);
 const boxes=[...svg.querySelectorAll('.sketch-dimension text')].map(t=>({x:Number(t.getAttribute('x'))-(t.textContent.length*2*.65)/2-.8,y:Number(t.getAttribute('y'))-2.8,width:t.textContent.length*2*.65+1.6,height:3.6}));
 for(let i=0;i<boxes.length;i++)for(let j=i+1;j<boxes.length;j++){const a=boxes[i],b=boxes[j];expect(a.x<b.x+b.width&&a.x+a.width>b.x&&a.y<b.y+b.height&&a.y+a.height>b.y).toBe(false);}
 render();expect(coordinates()).toEqual(first);expect(drawing).toEqual(before);expect(positions).toEqual({r0:[2,4]});
});
it('annotates point-to-line distance using the perpendicular projection',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]}]},{type:'path',construction:true,start:[20,3],segments:[]}],constraints:[{id:'d',kind:'distance',reference:true,a:{kind:'point',contour:1,index:0},b:{kind:'line',contour:0,index:0}}]};
 renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[]);
 expect(svg.querySelector('.sketch-dimension text').textContent).toBe('(3 mm)');
 const line=svg.querySelector('[data-dimension-measure]');expect(Number(line.getAttribute('y2'))-Number(line.getAttribute('y1'))).toBeCloseTo(3);
 const extension=svg.querySelectorAll('[data-dimension-extension]')[1];expect(extension.getAttribute('x1')).toBe('20');expect(extension.getAttribute('y1')).toBe('0');
});
it('annotates parallel-line spacing across disjoint segments',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const drawing={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]}]},{type:'path',start:[20,3],segments:[{type:'line',end:[30,3]}]}],constraints:[{id:'d',kind:'distance',reference:true,a:{kind:'line',contour:0,index:0},b:{kind:'line',contour:1,index:0}}]};
 renderSketchCanvas(svg,drawing,{x:-60,y:-40,width:120,height:80},[]);
 expect(svg.querySelector('.sketch-dimension text').textContent).toBe('(3 mm)');
 const line=svg.querySelector('[data-dimension-measure]');expect(Math.abs(Number(line.getAttribute('y2'))-Number(line.getAttribute('y1')))).toBeCloseTo(3);
 expect(line.getAttribute('x1')).toBe(line.getAttribute('x2'));
});
it('colors fixed vertices and free edges separately and updates after dimension changes',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const d={type:'drawing',contours:[{type:'path',construction:true,start:[0,0],segments:[{type:'line',end:[10,0]}]},{type:'circle',center:[30,20],radius:5}],constraints:[{id:'fixed',kind:'fix',a:{kind:'point',contour:0,index:0},point:[0,0]},{id:'h',kind:'horizontal',a:{kind:'line',contour:0,index:0}}]};
 const render=()=>renderSketchCanvas(svg,d,{x:-60,y:-40,width:120,height:80},[]);
 const before=structuredClone(d);render();
 const state=n=>n.getAttribute('data-entity-constraint-state');
 expect(state(svg.querySelector('.sketch-vertex'))).toBe('fully-constrained');
 expect(state(svg.querySelector('.sketch-entity-edge'))).toBe('under-constrained');
 expect(svg.querySelector('.sketch-entity-edge').classList.contains('construction')).toBe(true);
 expect(state(svg.querySelector('[data-contour-index="1"]'))).toBe('under-constrained');expect(d).toEqual(before);
 d.constraints.push({id:'length',kind:'length',a:{kind:'line',contour:0,index:0},value:10});render();
 expect(state(svg.querySelector('.sketch-entity-edge'))).toBe('fully-constrained');expect(state(svg.querySelector('[data-contour-index="1"]'))).toBe('under-constrained');
});
it('keeps a cubic edge movable when an endpoint or control remains free',()=>{
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 const d={type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'bezier',controls:[[3,5],[7,5]],end:[10,0]}]}],constraints:[{id:'start',kind:'fix',a:{kind:'point',contour:0,index:0},point:[0,0]},{id:'end',kind:'fix',a:{kind:'point',contour:0,index:1},point:[10,0]}]};
 renderSketchCanvas(svg,d,{x:-60,y:-40,width:120,height:80},[]);
 expect(svg.querySelector('.sketch-entity-edge').getAttribute('data-entity-constraint-state')).toBe('under-constrained');
 expect([...svg.querySelectorAll('.sketch-point')].every(n=>n.getAttribute('data-entity-constraint-state')==='under-constrained')).toBe(true);
});

// The plane square IS the sketch's reference frame made visible: origin at the
// frame origin, fixed size, fixed area. It must not move or resize with the
// pan/zoom viewport, and everything describing it stays inside it.
it('draws the plane as one fixed square on the origin, whatever the viewport', () => {
  const half = SKETCH_PLANE_HALF_MILLIMETRES;
  for (const bounds of [
    { x: -100, y: -100, width: 200, height: 200 },
    { x: -60, y: -180, width: 120, height: 260 },
    { x: 20, y: -40, width: 150, height: 80 },
  ]) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.dataset.sketchName = 'Sketch 3';
    renderSketchCanvas(svg, { contours: [] }, bounds, []);
    const card = svg.querySelector('.sketch-plane-face');
    expect([
      card.getAttribute('x'), card.getAttribute('y'),
      card.getAttribute('width'), card.getAttribute('height'),
    ]).toEqual([String(-half), String(-half), String(half * 2), String(half * 2)]);
    const origin = svg.querySelector('.sketch-origin');
    expect([origin.getAttribute('cx'), origin.getAttribute('cy')]).toEqual(['0', '0']);
    expect(svg.querySelector('.sketch-plane-title').textContent).toBe('Sketch 3');
    for (const line of svg.querySelectorAll('.sketch-grid, .sketch-axis'))
      for (const attr of ['x1', 'y1', 'x2', 'y2'])
        expect(Math.abs(Number(line.getAttribute(attr)))).toBeLessThanOrEqual(half);
  }
});
