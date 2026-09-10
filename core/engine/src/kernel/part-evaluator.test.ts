import { beforeAll, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import init from "replicad-opencascadejs";
import { setOC } from "replicad";
import { evaluatePartDocument } from "./part-evaluator";
import { createWheelExample } from "../document/wheel-example";
beforeAll(async () => {
  setOC(
    await (init as any)({
      wasmBinary: readFileSync(
        new URL(
          "../../node_modules/replicad-opencascadejs/src/replicad_single.wasm",
          import.meta.url,
        ),
      ),
    }),
  );
}, 30000);
it("builds a revolved wheel with additive hub, bore, and mirrored through holes", () => {
  const result = evaluatePartDocument(createWheelExample());
  expect(result.parts).toHaveLength(1);
  const body = result.parts[0];
  expect(body.triangles.length).toBeGreaterThan(100);
  const centers = body.topology
    .flatMap((f) => f.candidates)
    .filter((c) => c.kind === "cylinder-axis")
    .map((c) => c.origin);
  for (const [x, y] of [
    [16, 8],
    [-16, 8],
    [16, -8],
    [-16, -8],
  ])
    expect(
      centers.some(
        (p) => Math.abs(p[0] - x) < 0.01 && Math.abs(p[1] - y) < 0.01,
      ),
    ).toBe(true);
  const zs = Array.from(body.vertices).filter((_, i) => i % 3 === 2);
  expect(Math.min(...zs)).toBeCloseTo(0, 3);
  expect(Math.max(...zs)).toBeCloseTo(18, 3);
  const changed = createWheelExample();
  const sketch = changed.features.find((f) => f.id === "hole");
  if (sketch?.type === "profile" && sketch.profile.type === "circle")
    sketch.profile.centerMillimeters = [18, 9];
  const rebuilt = evaluatePartDocument(changed).parts[0];
  expect(
    rebuilt.topology
      .flatMap((f) => f.candidates)
      .some(
        (c) =>
          c.kind === "cylinder-axis" &&
          Math.abs(c.origin[0] - 18) < 0.01 &&
          Math.abs(c.origin[1] - 9) < 0.01,
      ),
  ).toBe(true);
  expect(Array.from(rebuilt.vertices)).not.toEqual(Array.from(body.vertices));
}, 30000);

it.each(["fillet", "chamfer"] as const)(
  "evaluates %s as exact edge geometry",
  async (type) => {
    const { createRectanglePartDocument } =
      await import("../document/part-document");
    const doc = createRectanglePartDocument("Edge finish", {
      widthMillimeters: 30,
      heightMillimeters: 20,
      depthMillimeters: 10,
    });
    const before = evaluatePartDocument(doc).parts[0];
    doc.features.push({
      id: "finish",
      name: "Finish",
      type,
      radiusMillimeters: 0.5,
      suppressed: false,
    });
    const after = evaluatePartDocument(doc).parts[0];
    expect(after.topology.length).toBeGreaterThan(before.topology.length);
  },
  30000,
);

it("rolls back exact geometry without discarding future features", () => {
  const doc = createWheelExample();
  const full = evaluatePartDocument(doc).parts[0];
  const early = evaluatePartDocument({ ...doc, rollbackIndex: 2 }).parts[0];
  expect(early.topology.length).toBeLessThan(full.topology.length);
  expect(evaluatePartDocument({ ...doc, rollbackIndex: 0 }).parts).toHaveLength(
    0,
  );
  expect(evaluatePartDocument({ ...doc, rollbackIndex: 1 }).parts).toHaveLength(
    0,
  );
  expect(
    evaluatePartDocument({ ...doc, rollbackIndex: doc.features.length })
      .parts[0].triangles,
  ).toEqual(full.triangles);
}, 30000);
it("keeps multiple bodies distinct and edits only the selected target", async () => {
  const { createRectanglePartDocument } =
    await import("../document/part-document");
  const { removeFeature, availableBodies } =
    await import("../document/feature-history");
  const doc = createRectanglePartDocument("Two bodies", {
    widthMillimeters: 20,
    heightMillimeters: 10,
    depthMillimeters: 5,
  });
  doc.features.push(
    {
      id: "circle-two",
      name: "Second sketch",
      type: "profile",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: {
        type: "circle",
        centerMillimeters: [40, 0],
        radiusMillimeters: 6,
      },
    },
    {
      id: "solid-two",
      name: "Second solid",
      type: "extrude",
      profileFeatureId: "circle-two",
      distanceMillimeters: 12,
      operation: "new",
      suppressed: false,
    },
  );
  const before = evaluatePartDocument(doc).parts;
  expect(before).toHaveLength(2);
  expect(before[0].id).not.toBe(before[1].id);
  doc.features.push({
    id: "finish-two",
    name: "Second body chamfer",
    type: "chamfer",
    radiusMillimeters: 0.5,
    targetBodyId: before[1].id,
    edgePlane: { plane: "XY", offsetMillimeters: 12 },
    suppressed: false,
  });
  const after = evaluatePartDocument(doc).parts;
  expect(after[0].triangles).toEqual(before[0].triangles);
  expect(after[1].topology.length).toBeGreaterThan(before[1].topology.length);
  const removed = removeFeature(doc, doc.features[1].id);
  expect(availableBodies(removed)[0].id).toBe(before[1].id);
  expect(evaluatePartDocument(removed).parts[0].id).toBe(before[1].id);
}, 30000);

it("rebuilds the finished wheel fixture with selective edge finishes", async () => {
  const { createFinishedWheelExample } =
    await import("../document/wheel-example");
  const doc = createFinishedWheelExample();
  const model = evaluatePartDocument(doc);
  expect(model.parts).toHaveLength(1);
  expect(model.parts[0].name).toBe("Wheel");
  expect(model.parts[0].topology.length).toBeGreaterThan(
    evaluatePartDocument(createWheelExample()).parts[0].topology.length,
  );
}, 30000);

it('persists open paths, extrudes exact closed arcs and holes on a face frame', async () => {
  const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
  const doc=createEmptyPartDocument('Arc sketch');
  doc.features.push({id:'sketch',name:'Sketch 1',type:'profile',plane:'XY',offsetMillimeters:0,suppressed:false,
    frame:{originMillimeters:[0,0,7],xDirection:[1,0,0],normal:[0,0,1]},
    profile:{type:'drawing',contours:[
      {type:'path',start:[-10,0],segments:[{type:'arc',middle:[0,10],end:[10,0]},{type:'line',end:[-10,0]}]},
      {type:'circle',center:[0,4],radius:1,hole:true},
      {type:'path',start:[20,0],segments:[{type:'line',end:[30,0]}]},
    ]}});
  expect(evaluatePartDocument(doc).parts).toHaveLength(0);
  doc.features.push({id:'extrude',name:'Extrude 1',type:'extrude',profileFeatureId:'sketch',distanceMillimeters:5,operation:'new',suppressed:false});
  const reopened=parsePartDocument(serializePartDocument(doc));
  expect(reopened.features[0]).toEqual(doc.features[0]);
  const result=evaluatePartDocument(reopened);
  expect(result.parts).toHaveLength(1);
  const z=Array.from(result.parts[0].vertices).filter((_,i)=>i%3===2);
  expect(Math.min(...z)).toBeCloseTo(7,3);expect(Math.max(...z)).toBeCloseTo(12,3);
  expect(result.parts[0].topology.filter(f=>f.surfaceType==='CYLINDRE' || f.surfaceType==='CYLINDER').length).toBeGreaterThan(0);
  const sketch=reopened.features[0];
  if(sketch.type==='profile'&&sketch.profile.type==='drawing')sketch.profile.contours=sketch.profile.contours.slice(2);
  expect(()=>evaluatePartDocument(reopened)).toThrow('closed profile');
});

it('rebuilds exact geometry from persisted sketch dimensions after reopening',async()=>{
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const doc=createEmptyPartDocument('Dimensioned circle');
 doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'drawing',contours:[{type:'circle',center:[0,0],radius:2}],constraints:[{id:'r',kind:'radius',a:{contour:0,kind:'circle'},value:5}]}});
 doc.features.push({id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:3,operation:'new',suppressed:false});
 const saved=parsePartDocument(serializePartDocument(doc));
 const diameter=()=>{const v=Array.from(evaluatePartDocument(saved).parts[0].vertices).filter((_,i)=>i%3===0);return Math.max(...v)-Math.min(...v);};
 expect(diameter()).toBeCloseTo(10,1);
 const s=saved.features[0];if(s.type==='profile'&&s.profile.type==='drawing')s.profile.constraints![0].value=8;
 expect(diameter()).toBeCloseTo(16,1);
});

it('extrudes reopened variant contours as exact geometry',async()=>{
 const {sketchVariantContour}=await import('../sketch/primitives');
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 for(const [tool,points] of [
  ['ellipse',[[0,0],[10,0],[0,3]]],
  ['cubic-bezier',[[0,0],[0,10],[10,10],[10,0]]],
  ['center-rectangle',[[0,0],[10,5]]],
  ['aligned-rectangle',[[0,0],[10,5],[-2,8]]],
  ['three-point-circle',[[5,0],[0,5],[-5,0]]],
  ['inscribed-polygon',[[0,0],[5,0]]],
  ['circumscribed-polygon',[[0,0],[5,0]]],
  ['center-arc',[[0,0],[5,0],[0,5]]],
 ] as const){
  const contour=sketchVariantContour(tool,points.map(p=>[...p]));
  if((tool==='center-arc'||tool==='cubic-bezier')&&contour.type==='path')contour.segments.push({type:'line',end:[...contour.start]});
  const doc=createEmptyPartDocument(tool);
  let profile:import('../sketch/drawing').SketchDrawing={type:'drawing',contours:[contour]};
  if(tool==='center-rectangle'||tool==='aligned-rectangle'){
   const {constrainSketchRectangle}=await import('../sketch/operations/rectangle-relations');
   profile=constrainSketchRectangle(profile,0,tool);
  }
  if(tool==='inscribed-polygon'||tool==='circumscribed-polygon'){
   const {constrainSketchPolygon}=await import('../sketch/operations/polygon-relations');
   profile=constrainSketchPolygon(profile,0,[0,0],tool==='circumscribed-polygon');
  }
  if(tool==='three-point-circle'){
   const {constrainThreePointCircle}=await import('../sketch/operations/circle-points');
   profile=constrainThreePointCircle(profile,0,points.map(p=>[...p]));
  }
  if(tool==='center-arc'){
   const {addSketchArcCenter}=await import('../sketch/operations/arc-center');
   profile=addSketchArcCenter(profile,{contour:0,kind:'arc',index:0});
  }
  doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile});
  doc.features.push({id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
  const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));
  expect(result.parts).toHaveLength(1);
  const z=Array.from(result.parts[0].vertices).filter((_,i)=>i%3===2);
  expect(Math.max(...z)-Math.min(...z)).toBeCloseTo(4,5);
  if(tool==='ellipse'){const vertices=Array.from(result.parts[0].vertices);const x=vertices.filter((_,i)=>i%3===0),y=vertices.filter((_,i)=>i%3===1);expect(Math.max(...x)-Math.min(...x)).toBeCloseTo(20,1);expect(Math.max(...y)-Math.min(...y)).toBeCloseTo(6,1);}
 }
});
it('persists construction planes before any body and supports rollback/suppression',async()=>{
 const {createEmptyPartDocument,insertFeature,parsePartDocument,serializePartDocument}=await import('../document/index');
 const d=insertFeature(createEmptyPartDocument('Planes'),{id:'p',name:'Plane 1',type:'plane',plane:'XZ',offsetMillimeters:15,suppressed:false});
 const reopened=parsePartDocument(serializePartDocument(d));expect(reopened.features[0]).toEqual(d.features[0]);
 expect(evaluatePartDocument(reopened).parts).toHaveLength(0);
 expect(()=>insertFeature(d,{id:'bad',name:'Bad',type:'plane',plane:'XY',offsetMillimeters:NaN,suppressed:false})).toThrow();
});
it('excludes construction curves from solids and evaluates mirrored hole patterns after reopen',async()=>{
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const {linearPattern}=await import('../sketch/operations/pattern');
 const d=createEmptyPartDocument('Construction and pattern');
 let drawing:import('../sketch/drawing').SketchDrawing={type:'drawing',contours:[
  {type:'circle',center:[0,0],radius:100,construction:true},
  {type:'path',start:[-10,-10],segments:[{type:'line',end:[30,-10]},{type:'line',end:[30,10]},{type:'line',end:[-10,10]},{type:'line',end:[-10,-10]}]},
  {type:'circle',center:[0,0],radius:2,hole:true},
 ]};
 drawing=linearPattern(drawing,[2],[10,0],3);
 d.features.push({id:'s',name:'Sketch',type:'profile',plane:'XY',offsetMillimeters:0,suppressed:false,profile:drawing});
 d.features.push({id:'e',name:'Extrude',type:'extrude',profileFeatureId:'s',distanceMillimeters:5,operation:'new',suppressed:false});
 const saved=parsePartDocument(serializePartDocument(d)),body=evaluatePartDocument(saved).parts[0];
 const x=Array.from(body.vertices).filter((_,i)=>i%3===0);expect(Math.min(...x)).toBeCloseTo(-10,4);expect(Math.max(...x)).toBeCloseTo(30,4);
 const cylinders=body.topology.flatMap(f=>f.candidates).filter(c=>c.kind==='cylinder-axis');
 for(const center of [0,10,20])expect(cylinders.some(c=>Math.abs(c.origin[0]-center)<1e-5&&Math.abs(c.origin[1])<1e-5)).toBe(true);
});
it('extrudes a persisted sketch fillet as an exact cylindrical face',async()=>{
 const {filletSketchCorner}=await import('../sketch/operations/fillet');
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const profile=filletSketchCorner({type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]},{type:'line',end:[10,10]},{type:'line',end:[0,10]},{type:'line',end:[0,0]}]}]},0,0,2);
 const doc=createEmptyPartDocument('Fillet');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile});doc.features.push({id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:5,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);
 expect(result.parts[0].topology.flatMap(f=>f.candidates).some(c=>c.kind==='cylinder-axis'&&Math.abs(c.origin[0]-2)<1e-5&&Math.abs(c.origin[1]-2)<1e-5)).toBe(true);
});
it('extrudes a saved closed line/Bezier profile with a connected curved fillet',async()=>{
 const {filletSketchCurves}=await import('../sketch/operations/fillet-curves');
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const profile=filletSketchCurves({type:'drawing',contours:[{type:'path',start:[-10,0],segments:[{type:'line',end:[0,0]},{type:'bezier',controls:[[1,3],[2,7]],end:[0,10]},{type:'line',end:[-10,10]},{type:'line',end:[-10,0]}]}]},{contour:0,segment:0},{contour:0,segment:1},1);
 const doc=createEmptyPartDocument('Curved fillet');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile});doc.features.push({id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:5,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);
 expect(result.parts[0].topology.flatMap(f=>f.candidates).some(c=>c.kind==='cylinder-axis')).toBe(true);
 const z=Array.from(result.parts[0].vertices).filter((_,i)=>i%3===2);expect(Math.max(...z)-Math.min(...z)).toBeCloseTo(5,5);
});
it('extrudes a reopened asymmetric sketch chamfer into a closed solid',async()=>{
 const {chamferSketchCorner}=await import('../sketch/operations/chamfer');
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const profile=chamferSketchCorner({type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]},{type:'line',end:[10,10]},{type:'line',end:[0,10]},{type:'line',end:[0,0]}]}]},0,1,{mode:'two-distances',distance:2,secondDistance:3});
 const doc=createEmptyPartDocument('Chamfer');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile});doc.features.push({id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);
 const vertices=Array.from(result.parts[0].vertices),z=vertices.filter((_,i)=>i%3===2);expect(Math.max(...z)-Math.min(...z)).toBeCloseTo(4,5);
 expect(vertices.some((x,i)=>i%3===0&&Math.abs(x-8)<1e-5&&Math.abs(vertices[i+1])<1e-5)).toBe(true);
});
it('extrudes a native reopened path containing a constrained tangent arc',async()=>{
 const {createSketchTangentArc}=await import('../sketch/operations/tangent-arc');
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const {drawing}=createSketchTangentArc({type:'drawing',contours:[{type:'path',start:[-10,0],segments:[{type:'line',end:[0,0]}]}]},{contour:0,segment:0,endpoint:1},[5,5]);
 const path=drawing.contours[0];if(path.type!=='path')throw Error();path.segments.push({type:'line',end:[-10,5]},{type:'line',end:[-10,0]});
 const doc=createEmptyPartDocument('Tangent arc');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile:drawing},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);const z=Array.from(result.parts[0].vertices).filter((_,i)=>i%3===2);expect(Math.max(...z)-Math.min(...z)).toBeCloseTo(4);
});
it('extrudes a reopened linked slot with its construction centerline excluded',async()=>{
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const {slotSketchEntities}=await import('../sketch/operations/slot');
 const profile=slotSketchEntities({type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]}]}]},[{kind:'line',contour:0,index:0}],4);
 const doc=createEmptyPartDocument('Slot');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);expect(result.parts[0].triangles.length).toBeGreaterThan(10);
});
it('extrudes a native open-chain slot into one solid with exact rounded faces',async()=>{
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const {slotSketchEntities}=await import('../sketch/operations/slot');
 const profile=slotSketchEntities({type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[10,0]},{type:'line',end:[10,10]}]}]},[{kind:'contour',contour:0}],2);
 const doc=createEmptyPartDocument('Chain slot');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);
 expect(result.parts[0].topology.flatMap(f=>f.candidates).filter(c=>c.kind==='cylinder-axis').length).toBeGreaterThanOrEqual(3);
});
it('extrudes a saved ellipse with its full-shape relationship',async()=>{
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const {constrainSketchEllipse}=await import('../sketch/operations/ellipse-relations');const {sketchVariantContour}=await import('../sketch/primitives');
 const profile=constrainSketchEllipse({type:'drawing',contours:[sketchVariantContour('ellipse',[[0,0],[4,0],[0,2]])]},0);
 const doc=createEmptyPartDocument('Ellipse');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);expect(result.parts[0].triangles.length).toBeGreaterThan(10);
});
it('extrudes a closed bulged DXF polyline after native document serialization',async()=>{
 const {importDxfSketch}=await import('../sketch/import/dxf');const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const text='0\nSECTION\n2\nENTITIES\n0\nLWPOLYLINE\n90\n2\n70\n1\n10\n0\n20\n0\n42\n1\n10\n10\n20\n0\n0\nENDSEC\n0\nEOF';
 const profile=importDxfSketch(text,1).drawing,doc=createEmptyPartDocument('DXF');doc.features.push({id:'s',type:'profile',name:'Imported sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);expect(result.parts[0].topology.flatMap(f=>f.candidates).some(c=>c.kind==='cylinder-axis')).toBe(true);
});
it('extrudes a rotated full DXF ellipse through the native kernel',async()=>{
 const {importDxfSketch}=await import('../sketch/import/dxf');const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const text='0\nSECTION\n2\nENTITIES\n0\nELLIPSE\n10\n10\n20\n20\n11\n3\n21\n4\n40\n0.4\n41\n0\n42\n'+(2*Math.PI)+'\n0\nENDSEC\n0\nEOF';
 const profile=importDxfSketch(text,1).drawing,doc=createEmptyPartDocument('DXF ellipse');doc.features.push({id:'s',type:'profile',name:'Imported sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);const z=Array.from(result.parts[0].vertices).filter((_,i)=>i%3===2);expect(Math.max(...z)-Math.min(...z)).toBeCloseTo(4);
});
it('extrudes independent DXF line entities after endpoint joining',async()=>{
 const {importDxfSketch}=await import('../sketch/import/dxf');const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const line=(a:number[],b:number[])=>`0\nLINE\n10\n${a[0]}\n20\n${a[1]}\n11\n${b[0]}\n21\n${b[1]}`;
 const text='0\nSECTION\n2\nENTITIES\n'+[line([0,0],[10,0]),line([10,10],[10,0]),line([0,10],[10,10]),line([0,0],[0,10])].join('\n')+'\n0\nENDSEC\n0\nEOF';
 const profile=importDxfSketch(text,1).drawing,doc=createEmptyPartDocument('Joined DXF');doc.features.push({id:'s',type:'profile',name:'Imported sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);const vertices=Array.from(result.parts[0].vertices);for(const axis of [0,1,2]){const coordinates=vertices.filter((_,i)=>i%3===axis);expect(Math.max(...coordinates)-Math.min(...coordinates)).toBeCloseTo(axis===2?4:10);}
});
it('preserves a nested solid island when extruding imported holes',async()=>{
 const {importDxfSketch}=await import('../sketch/import/dxf');const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const text='0\nSECTION\n2\nENTITIES\n'+[2,10,5].map(r=>`0\nCIRCLE\n10\n0\n20\n0\n40\n${r}`).join('\n')+'\n0\nENDSEC\n0\nEOF';
 const profile=importDxfSketch(text,1).drawing,doc=createEmptyPartDocument('Nested DXF');expect(profile.contours.map(c=>c.hole)).toEqual([false,false,true]);doc.features.push({id:'s',type:'profile',name:'Imported sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));
 expect(result.parts.length).toBeGreaterThan(0);
 const radii=result.parts.flatMap(p=>Array.from(p.vertices)).reduce<number[]>((out,_,i,vertices)=>{if(i%3===0)out.push(Math.hypot(vertices[i],vertices[i+1]));return out;},[]);
 for(const r of [2,5,10])expect(radii.some(v=>Math.abs(v-r)<1e-4)).toBe(true);
});
it('extrudes a periodic fit-point spline after native save and reopen',async()=>{
 const {fitSketchSpline}=await import('../sketch/curves/fit-spline');
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const profile={type:'drawing' as const,contours:[fitSketchSpline([[0,0],[10,0],[10,10],[0,10]],{closed:true})]};
 const doc=createEmptyPartDocument('Closed spline');doc.features.push({id:'s',type:'profile',name:'Spline',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);
 const z=Array.from(result.parts[0].vertices).filter((_,i)=>i%3===2);expect(Math.max(...z)-Math.min(...z)).toBeCloseTo(4);
 expect(result.parts[0].triangles.length).toBeGreaterThan(10);
});
it('extrudes a projected oblique circle as a native ellipse after save/reopen',async()=>{
 const {projectSketchDrawing}=await import('../sketch/projection/drawing');
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const sourceFrame={originMillimeters:[0,0,0] as [number,number,number],xDirection:[1,0,0] as [number,number,number],normal:[0,0,1] as [number,number,number]};
 const profile=projectSketchDrawing({type:'drawing',contours:[{type:'circle',center:[0,0],radius:5}]},sourceFrame,{...sourceFrame,normal:[0,.6,.8]});
 const doc=createEmptyPartDocument('Projected circle');doc.features.push({id:'s',type:'profile',name:'Projection',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:2,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);
 const v=Array.from(result.parts[0].vertices);for(const axis of [0,1,2]){const p=v.filter((_,i)=>i%3===axis);expect(Math.max(...p)-Math.min(...p)).toBeCloseTo([10,8,2][axis],1);}
});
it('rebuilds an associative projected profile from its source and rejects suppression',async()=>{
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const doc=createEmptyPartDocument('Associative projection');
 doc.features.push({id:'source',type:'profile',name:'Source',plane:'XY',offsetMillimeters:0,suppressed:false,frame:{originMillimeters:[0,0,0],xDirection:[1,0,0],normal:[0,.6,.8]},profile:{type:'circle',centerMillimeters:[0,0],radiusMillimeters:5}},
 {id:'linked',type:'profile',name:'Projection',plane:'XY',offsetMillimeters:0,suppressed:false,profile:{type:'projection',sourceFeatureId:'source'}},
 {id:'e',type:'extrude',name:'Extrude',profileFeatureId:'linked',distanceMillimeters:2,operation:'new',suppressed:false});
 for(const radius of [5,8]){
  const source=doc.features[0];if(source.type!=='profile'||source.profile.type!=='circle')throw Error();source.profile.radiusMillimeters=radius;
  const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);
  const v=Array.from(result.parts[0].vertices);for(const axis of [0,1,2]){const p=v.filter((_,i)=>i%3===axis);expect(Math.max(...p)-Math.min(...p)).toBeCloseTo([2*radius,1.6*radius,2][axis],1);}
 }
 doc.features[0].suppressed=true;expect(()=>evaluatePartDocument(doc)).toThrow('Projection source is suppressed');
 doc.features[0].suppressed=false;doc.rollbackIndex=1;expect(evaluatePartDocument(doc).parts).toHaveLength(0);
});
it('extrudes a linked circular slot with an open center bore',async()=>{
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');
 const {slotSketchEntities}=await import('../sketch/operations/slot');
 const profile=slotSketchEntities({type:'drawing',contours:[{type:'circle',center:[0,0],radius:10}]},[{kind:'circle',contour:0}],4);
 const doc=createEmptyPartDocument('Circular slot');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);
 const vertices=Array.from(result.parts[0].vertices);for(let i=0;i<vertices.length;i+=3)expect(Math.hypot(vertices[i],vertices[i+1])).toBeGreaterThanOrEqual(8-1e-5);
 expect(result.parts[0].topology.flatMap(f=>f.candidates).filter(c=>c.kind==='cylinder-axis').length).toBeGreaterThanOrEqual(2);
});
it('extrudes a closed rectangular slot with the exact ring volume',async()=>{
 const {createEmptyPartDocument,serializePartDocument,parsePartDocument}=await import('../document/index');const {slotSketchEntities}=await import('../sketch/operations/slot');
 const profile=slotSketchEntities({type:'drawing',contours:[{type:'path',start:[0,0],segments:[{type:'line',end:[20,0]},{type:'line',end:[20,10]},{type:'line',end:[0,10]},{type:'line',end:[0,0]}]}]},[{kind:'contour',contour:0}],2);
 const doc=createEmptyPartDocument('Closed slot');doc.features.push({id:'s',type:'profile',name:'Sketch',plane:'XY',offsetMillimeters:0,suppressed:false,profile},{id:'e',type:'extrude',name:'Extrude',profileFeatureId:'s',distanceMillimeters:4,operation:'new',suppressed:false});
 const result=evaluatePartDocument(parsePartDocument(serializePartDocument(doc)));expect(result.parts).toHaveLength(1);const p=result.parts[0],v=p.vertices,t=p.triangles;let volume=0;
 for(let i=0;i<t.length;i+=3){const a=t[i]*3,b=t[i+1]*3,c=t[i+2]*3;volume+=(v[a]*(v[b+1]*v[c+2]-v[b+2]*v[c+1])+v[a+1]*(v[b+2]*v[c]-v[b]*v[c+2])+v[a+2]*(v[b]*v[c+1]-v[b+1]*v[c]))/6;}
 expect(Math.abs(volume)).toBeCloseTo((22*12-18*8)*4,5);
});
