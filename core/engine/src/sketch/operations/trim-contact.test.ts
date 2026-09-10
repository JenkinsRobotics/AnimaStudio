import { expect, it } from "vitest";
import { trimSketchCurve } from "./trim";
import { remapTrimContact } from "./trim-contact";
import { segmentPoint } from "../curves/parameterization";
import { constraintResiduals } from "../solver/residuals";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchSegment,
} from "../drawing";
const segments: SketchSegment[] = [
  { type: "line", end: [4, 0] },
  {
    type: "bezier",
    controls: [
      [1, 2],
      [3, 2],
    ],
    end: [4, 0],
  },
  { type: "arc", middle: [2, 2], end: [4, 0] },
  {
    type: "ellipse",
    radiusX: 2,
    radiusY: 1,
    rotationDegrees: 0,
    largeArc: false,
    sweep: true,
    end: [4, 0],
  },
];

it("retains finite contacts only on surviving line, arc, ellipse and cubic intervals", () => {
  for (const segment of segments) {
    const d: SketchDrawing = {
      type: "drawing",
      contours: [{ type: "path", start: [0, 0], segments: [segment] }],
      constraints: [],
    };
    for (const x of [1, 3])
      d.contours.push({
        type: "path",
        construction: true,
        start: [x, -4],
        segments: [{ type: "line", end: [x, 4] }],
      });
    for (const t of [0, 0.1, 0.5, 0.9, 1]) {
      const contour = d.contours.length;
      d.contours.push({
        type: "path",
        start: segmentPoint([0, 0], segment, t),
        segments: [],
      });
      d.constraints!.push({
        id: `contact-${t}`,
        kind: "coincident",
        a: { kind: "point", contour, index: 0 },
        b: {
          kind: "curve",
          contour: 0,
          index: 0,
          parameter: t,
          sliding: t !== 0.1,
        },
      });
    }
    const before = structuredClone(d);
    // Avoid picking the standalone contact at the center of the removed interval.
    const next = trimSketchCurve(d, segmentPoint([0, 0], segment, 0.55), 0.001);
    expect(next.constraints!.some((c) => c.id === "contact-0.5")).toBe(false);
    for (const t of [0, 0.1, 0.9, 1]) {
      const c = next.constraints!.find((c) => c.id === `contact-${t}`)!;
      expect(c).toBeDefined();
      expect(c.b!.contour).toBe(t < 0.5 ? 0 : 1);
      expect(c.b!.sliding).toBe(t !== 0.1);
      expect(
        constraintResiduals(next, c).every((r) => Math.abs(r) < 1e-6),
      ).toBe(true);
    }
    validateSketchDrawing(JSON.parse(JSON.stringify(next)));
    expect(d).toEqual(before);
  }
});
it("keeps contacts at cut endpoints and removes those inside the discarded interval", () => {
  const pieces = [
    { contour: 0, index: 0, interval: [0, 0.25] as [number, number] },
    { contour: 1, index: 0, interval: [0.75, 1] as [number, number] },
  ];
  const ref = {
    kind: "curve" as const,
    contour: 0,
    index: 0,
    parameter: 0.25,
    sliding: true,
  };
  expect(remapTrimContact(ref, pieces)).toMatchObject({
    contour: 0,
    parameter: 1,
    sliding: true,
  });
  expect(remapTrimContact({ ...ref, parameter: 0.75 }, pieces)).toMatchObject({
    contour: 1,
    parameter: 0,
  });
  expect(remapTrimContact({ ...ref, parameter: 0.5 }, pieces)).toBeUndefined();
  expect(() => remapTrimContact({ ...ref, parameter: NaN }, pieces)).toThrow(
    /invalid/,
  );
});
it("remaps contacts around the new seam when trimming a closed path", () => {
 const d: SketchDrawing={type:"drawing",contours:[
  {type:"path",start:[0,0],segments:[{type:"line",end:[4,0]},{type:"line",end:[2,4]},{type:"line",end:[0,0]}]},
  {type:"path",start:[1,-1],segments:[{type:"line",end:[1,1]}]},
  {type:"path",start:[3,-1],segments:[{type:"line",end:[3,1]}]},
  {type:"path",start:[.4,0],segments:[]},
  {type:"path",start:[3.6,0],segments:[]}
 ],constraints:[
  {id:"left",kind:"coincident",a:{kind:"point",contour:3,index:0},b:{kind:"curve",contour:0,index:0,parameter:.1}},
  {id:"right",kind:"coincident",a:{kind:"point",contour:4,index:0},b:{kind:"curve",contour:0,index:0,parameter:.9,sliding:true}}
 ]};
 const next=trimSketchCurve(d,[2,0],.01);
 expect(next.contours).toHaveLength(5);
 expect(next.constraints!.find(c=>c.id==="left")!.b).toMatchObject({contour:0,index:3,parameter:.4});
 expect(next.constraints!.find(c=>c.id==="right")!.b!.index).toBe(0);
 for(const c of next.constraints!)expect(constraintResiduals(next,c).every(r=>Math.abs(r)<1e-6)).toBe(true);
});
