import {expect,it} from "vitest";
import {dxfLayers,importDxfSketch} from "./index";
const wrap=(entities:string)=>`0\nSECTION\n2\nENTITIES\n${entities}0\nENDSEC\n0\nEOF`;
const circle=(layer:string,x=0)=>`0\nCIRCLE\n8\n${layer}\n10\n${x}\n20\n0\n40\n1\n`;
it("inventories used model-space layers and decodes only selected layers",()=>{
 const text=wrap(circle("Parts")+circle("Reference",10)+'0\nTEXT\n8\nLabels\n1\nExample\n');
 expect(dxfLayers(text)).toEqual([{name:"Parts",entityCount:1},{name:"Reference",entityCount:1},{name:"Labels",entityCount:1}]);
 expect(()=>importDxfSketch(text,1)).toThrow(/TEXT/);const imported=importDxfSketch(text,25.4,{includedLayers:["Parts"]});expect(imported.entityCount).toBe(1);expect(imported.drawing.contours[0]).toMatchObject({radius:25.4});expect(()=>importDxfSketch(text,1,{includedLayers:[]})).toThrow(/selected/);
});
it("counts a legacy polyline once and excludes paper-space and skipped unsupported sequences",()=>{
 const poly='0\nPOLYLINE\n8\nLegacy\n70\n8\n0\nVERTEX\n8\nVertexLayer\n10\n0\n20\n0\n30\n4\n0\nSEQEND\n';
 const text=wrap(poly+circle("Parts")+'0\nCIRCLE\n67\n1\n8\nPaper\n10\n0\n20\n0\n40\n1\n');expect(dxfLayers(text)).toEqual([{name:"Legacy",entityCount:1},{name:"Parts",entityCount:1}]);expect(importDxfSketch(text,1,{includedLayers:["Parts"]}).entityCount).toBe(1);expect(()=>importDxfSketch(text,1,{includedLayers:["Legacy"]})).toThrow();
});
it("rejects malformed legacy structure even on excluded layers",()=>{expect(()=>importDxfSketch(wrap('0\nPOLYLINE\n8\nSkip\n'+circle("Parts")),1,{includedLayers:["Parts"]})).toThrow(/SEQEND/);});
