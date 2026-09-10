import { expect, it } from "vitest";
import { copySketchContours, similarityTransform } from "./transform";
import { editDrawingDimension } from "./edit-dimension";
import {
  setDimensionExpression,
  regenerateDimensionExpressions,
} from "./dimension-expression";
import { evaluateDocumentVariables } from "../../document/variables";
import { constraintResiduals } from "../solver/residuals";
import type { SketchDrawing } from "../drawing";
import { createEmptyPartDocument } from "../../document/part-document";
import { serializePartDocument, parsePartDocument } from "../../document/part-serialization";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { type: "circle", id: "first", center: [0, 0], radius: 5 },
    { type: "circle", id: "second", center: [20, 0], radius: 10 },
  ],
  constraints: [
    { id: "r", kind: "radius", a: { kind: "circle", contour: 0 }, value: 5 },
    {
      id: "f",
      kind: "radius",
      a: { kind: "circle", contour: 1 },
      valueFrom: "r",
      valueScale: 2,
    },
  ],
});
it("copies linked dimensional drivers independently and scales values", () => {
  const original = source(),
    before = structuredClone(original);
  const copied = copySketchContours(
    original,
    [0, 1],
    [similarityTransform([0, 0], [0, 30], 0, 2)],
  );
  expect(copied.constraints).toHaveLength(4);
  const [driver, follower] = copied.constraints!.slice(2);
  expect(driver.a.contour).toBe(2);
  expect(driver.value).toBe(10);
  expect(follower.valueFrom).toBe(driver.id);
  const edited = editDrawingDimension(copied, driver.id, 12);
  expect(edited.contours[3]).toMatchObject({ radius: expect.closeTo(24) });
  expect(edited.contours[0]).toEqual(original.contours[0]);
  expect(new Set(copied.contours.map((c) => c.id)).size).toBe(4);
  expect(original).toEqual(before);
});
it("retains variable expressions even when their dimension driver was not selected", () => {
  const vars = evaluateDocumentVariables([
    { name: "size", kind: "length", expression: "10 mm" },
  ]);
  const bound = setDimensionExpression(source(), "r", "#size/2", vars);
  const copied = copySketchContours(
    bound,
    [1],
    [similarityTransform([0, 0], [0, 30], 0, 2)],
  );
  const c = copied.constraints!.at(-1)!;
  expect(c.valueFrom).toBeUndefined();
  expect(c.valueExpression).toContain("#size/2");
  const changed = regenerateDimensionExpressions(
    copied,
    evaluateDocumentVariables([
      { name: "size", kind: "length", expression: "12 mm" },
    ]),
  );
  expect(changed.contours[2]).toMatchObject({ radius: expect.closeTo(24) });
});
it("swaps horizontal and vertical constraints at quarter turns and remaps fixed points", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        startVertexId: "p",
        segments: [{ id: "edge", type: "line", end: [10, 0] }],
      },
    ],
    constraints: [
      {
        id: "h",
        kind: "horizontal",
        a: { kind: "line", contour: 0, index: 0, segmentId: "edge" },
      },
      {
        id: "fix",
        kind: "fix",
        a: { kind: "point", contour: 0, index: 0, vertexId: "p" },
        point: [0, 0],
      },
      {
        id: "len",
        kind: "length",
        a: { kind: "line", contour: 0, index: 0 },
        value: 10,
      },
    ],
  };
  const copied = copySketchContours(
    d,
    [0],
    [similarityTransform([0, 0], [20, 30], 90)],
  );
  expect(copied.constraints![3].kind).toBe("vertical");
  expect(copied.constraints![4].point).toEqual([20, 30]);
  expect(copied.constraints![3].a.segmentId).toBe("edge");
  for (const c of copied.constraints!)
    expect(
      Math.max(...constraintResiduals(copied, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
  const arbitrary = copySketchContours(
    d,
    [0],
    [similarityTransform([0, 0], [20, 30], 37)],
  );
  expect(arbitrary.constraints!.slice(3).map((c) => c.kind)).toEqual([
    "fix",
    "length",
  ]);
});
it("omits relationships to unselected geometry and isolates multiple copies", () => {
  const d = source();
  d.constraints!.push({
    id: "external",
    kind: "horizontal",
    a: { kind: "point", contour: 0, index: 0 },
    b: { kind: "point", contour: 1, index: 0 },
  });
  const copied = copySketchContours(
    d,
    [0],
    [
      similarityTransform([0, 0], [0, 20], 0),
      similarityTransform([0, 0], [0, 40], 0),
    ],
  );
  expect(copied.constraints).toHaveLength(5);
  expect(new Set(copied.constraints!.map((c) => c.id)).size).toBe(5);
  expect(copied.constraints!.slice(3).map((c) => c.a.contour)).toEqual([2, 3]);
});

it("round-trips a scaled irrational variable formula without stale-cache errors",()=>{
  const doc=createEmptyPartDocument("Scaled copy");
  doc.variables=[{name:"size",kind:"length",expression:"pi mm"}];
  const bound=setDimensionExpression(source(),"r","#size/2",evaluateDocumentVariables(doc.variables));
  const profile=copySketchContours(bound,[0],[similarityTransform([0,0],[0,30],0,1.3)]);
  doc.features.push({id:"s",type:"profile",name:"Copies",plane:"XY",offsetMillimeters:0,suppressed:false,profile});
  expect(parsePartDocument(serializePartDocument(doc)).features).toEqual(doc.features);
});
