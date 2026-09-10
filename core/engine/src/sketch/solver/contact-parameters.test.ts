import { expect, it } from "vitest";
import { solveDrawingConstraints } from "./solve";
import { sketchConstraintState } from "./diagnostics";
import { dragSketchEntity } from "../operations/drag-entity";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const fixture = (parameter = 0.25): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        {
          type: "bezier",
          controls: [
            [1, 0],
            [2, 0],
          ],
          end: [3, 0],
        },
      ],
    },
    { type: "path", start: [3 * parameter, 0], segments: [] },
  ],
  constraints: [
    {
      id: "a",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [0, 0],
    },
    {
      id: "b",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0, control: 0 },
      point: [1, 0],
    },
    {
      id: "c",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0, control: 1 },
      point: [2, 0],
    },
    {
      id: "d",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 1 },
      point: [3, 0],
    },
    {
      id: "slide",
      kind: "coincident",
      a: { kind: "point", contour: 1, index: 0 },
      b: { kind: "curve", contour: 0, index: 0, parameter, sliding: true },
    },
  ],
});
it("reports one geometric freedom and retains solved contact parameter through drag and native save", () => {
  const source = fixture();
  expect(sketchConstraintState(source)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 1,
  });
  expect(
    sketchConstraintState(source, { kind: "point", contour: 1, index: 0 }),
  ).toMatchObject({ degreesOfFreedom: 1 });
  const next = dragSketchEntity(
    JSON.parse(JSON.stringify(source)),
    { kind: "point", contour: 1, index: 0 },
    [1.5, 0],
  );
  expect(next.constraints!.at(-1)!.b!.parameter).toBeCloseTo(0.75);
  validateSketchDrawing(JSON.parse(JSON.stringify(next)));
  expect(source.constraints!.at(-1)!.b!.parameter).toBe(0.25);
  const fixed = fixture();
  fixed.constraints!.at(-1)!.b!.sliding = false;
  expect(sketchConstraintState(fixed)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
});
it("allows inward movement from either endpoint and rejects motion outside the finite curve", () => {
  for (const t of [0, 1]) {
    const next = dragSketchEntity(
      fixture(t),
      { kind: "point", contour: 1, index: 0 },
      [t === 0 ? 1.5 : -1.5, 0],
    );
    expect(next.constraints!.at(-1)!.b!.parameter).toBeCloseTo(0.5);
  }
  const source = fixture();
  expect(() =>
    dragSketchEntity(source, { kind: "point", contour: 1, index: 0 }, [4, 0]),
  ).toThrow();
  expect(source.constraints!.at(-1)!.b!.parameter).toBe(0.25);
});
it("rejects malformed sliding flags even on otherwise satisfied drawings", () => {
  const d = fixture();
  d.constraints![0].a.sliding = true;
  expect(() => solveDrawingConstraints(d)).toThrow(/Sliding/);
  const bad = fixture();
  bad.constraints!.at(-1)!.b!.parameter = 2;
  expect(() => solveDrawingConstraints(bad)).toThrow(/between/);
});

it("solves sliding tangency along a fixed cubic while retaining circle dimensions",()=>{
 const d=fixture();d.contours[1]={type:"circle",center:[1.5,1],radius:1};d.constraints![4]={id:"tangent",kind:"tangent",a:{kind:"circle",contour:1},b:{kind:"curve",contour:0,index:0,parameter:.25,sliding:true}};d.constraints!.push({id:"center",kind:"fix",a:{kind:"point",contour:1,index:0},point:[1.5,1]},{id:"radius",kind:"radius",a:{kind:"circle",contour:1},value:1});
 const next=solveDrawingConstraints(d);expect(next.constraints![4].b!.parameter).toBeCloseTo(.5);validateSketchDrawing(next);
});
