import { expect, it } from "vitest";
import { solveProjectedConstraints } from "./projected-constraints";
import type { SketchDrawing } from "../sketch/drawing";
const projected = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { id: "center", type: "circle", center: [10, 20], radius: 5 },
    { id: "other", type: "circle", center: [40, 40], radius: 2 },
  ],
});
const authored = (): SketchDrawing => ({
  type: "drawing",
  contours: [{ type: "circle", center: [0, 0], radius: 2 }],
  constraints: [
    {
      id: "center-link",
      kind: "concentric",
      a: { kind: "circle", contour: 0 },
      b: { kind: "circle", contour: -1, projectedContourId: "center" },
    },
    { id: "size", kind: "radius", a: { kind: "circle", contour: 0 }, value: 2 },
  ],
});
it("solves against immutable projected geometry and retains external IDs", () => {
  const source = projected(),
    before = structuredClone(source),
    input = authored();
  const solved = solveProjectedConstraints(input, source);
  expect(solved.contours).toHaveLength(1);
  expect(solved.contours[0]).toMatchObject({
    center: [expect.closeTo(10), expect.closeTo(20)],
    radius: expect.closeTo(2),
  });
  expect(solved.constraints).toEqual(input.constraints);
  expect(source).toEqual(before);
  expect(input.contours[0]).toMatchObject({ center: [0, 0] });
  source.contours.reverse();
  const c = source.contours.find((c) => c.id === "center")!;
  if (c.type !== "circle") throw Error();
  c.center = [15, 25];
  expect(
    solveProjectedConstraints(JSON.parse(JSON.stringify(solved)), source)
      .contours[0],
  ).toMatchObject({ center: [expect.closeTo(15), expect.closeTo(25)] });
});
it("reports missing identities and conflicts instead of moving the projection", () => {
  const missing = projected();
  missing.contours.shift();
  expect(() => solveProjectedConstraints(authored(), missing)).toThrow(
    "Broken projected",
  );
  const conflict = authored();
  conflict.constraints!.push({
    id: "fixed",
    kind: "fix",
    a: { kind: "point", contour: 0, index: 0 },
    point: [0, 0],
  });
  const source = projected(),
    before = structuredClone(source);
  expect(() => solveProjectedConstraints(conflict, source)).toThrow();
  expect(source).toEqual(before);
});

it("retains optimized sliding contact parameters without persisting solver indices",()=>{
 const p:SketchDrawing={type:"drawing",contours:[{id:"edge",type:"path",start:[0,0],segments:[{type:"line",end:[10,0]}]}]};
 const a:SketchDrawing={type:"drawing",contours:[{type:"path",start:[5,0],segments:[]}],constraints:[{id:"fix",kind:"fix",a:{kind:"point",contour:0,index:0},point:[5,0]},{id:"contact",kind:"coincident",a:{kind:"point",contour:0,index:0},b:{kind:"curve",contour:-1,projectedContourId:"edge",index:0,parameter:.1,sliding:true}}]};
 const solved=solveProjectedConstraints(a,p);expect(solved.constraints![1].b).toMatchObject({contour:-1,projectedContourId:"edge",parameter:expect.closeTo(.5,5),sliding:true});expect(p.contours[0]).toMatchObject({start:[0,0],segments:[{end:[10,0]}]});
});
