import { expect, it } from "vitest";
import { mirrorSketch, mirrorTransform } from "./mirror";
import { linearPattern, circularPattern } from "./pattern";
import {
  moveSketchContours,
  similarityTransform,
  transformContour,
} from "./transform";
import { trimSketchLine, extendSketchLine } from "./trim-extend";
import { sketchVariantContour } from "../primitives";
import {
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "../drawing";
const circle: SketchDrawing = {
  type: "drawing",
  contours: [{ type: "circle", center: [5, 0], radius: 1 }],
};
const line = (a: SketchPoint, b: SketchPoint) => ({
  type: "path" as const,
  start: a,
  segments: [{ type: "line" as const, end: b }],
});
it("mirrors exact circles and curve controls without mutating originals", () => {
  const source = structuredClone(circle);
  source.contours.push(
    sketchVariantContour("cubic-bezier", [
      [2, 0],
      [3, 1],
      [4, 1],
      [5, 0],
    ]),
  );
  source.contours.push(
    sketchVariantContour("ellipse", [
      [5, 5],
      [8, 6],
      [4, 8],
    ]),
  );
  const before = JSON.stringify(source),
    next = mirrorSketch(source, [0, 1, 2], [0, 0], [0, 10]);
  expect(JSON.stringify(source)).toBe(before);
  expect(next.contours[3]).toMatchObject({ center: [-5, 0], radius: 1 });
  const curve = next.contours[4];
  if (curve.type !== "path" || curve.segments[0].type !== "bezier")
    throw Error();
  expect(curve.segments[0].controls[0]).toEqual([-3, 1]);
  const ellipse = next.contours[5];
  if (ellipse.type !== "path" || ellipse.segments[0].type !== "ellipse")
    throw Error();
  expect(ellipse.segments[0].sweep).toBe(false);
  validateSketchDrawing(next);
  const twice = transformContour(
    next.contours[5],
    mirrorTransform([0, 0], [0, 10]),
  );
  if (twice.type !== "path") throw Error();
  expect(twice.start[0]).toBeCloseTo(8);
  expect(twice.start[1]).toBeCloseTo(6);
});
it("patterns selected contours in two directions and about an arbitrary center", () => {
  const grid = linearPattern(circle, [0], [10, 0], 3, [0, 5], 2);
  expect(grid.contours).toHaveLength(6);
  expect(grid.contours[5]).toMatchObject({ center: [25, 5] });
  const radial = circularPattern(circle, [0], [0, 0], 4, 90);
  expect(radial.contours).toHaveLength(4);
  const second = radial.contours[1];
  if (second.type !== "circle") throw Error();
  expect(second.center[0]).toBeCloseTo(0);
  expect(second.center[1]).toBeCloseTo(5);
  expect(() => linearPattern(circle, [0], [0, 0], 3)).toThrow("spacing");
  expect(() => linearPattern(circle, [0], [1, 0], 100, [0, 1], 100)).toThrow(
    "1000",
  );
});
it("moves unconstrained geometry but rejects a conflicting fixed constraint atomically", () => {
  const transform = similarityTransform([0, 0], [10, 5], 90, 2);
  const moved = moveSketchContours(circle, [0], transform);
  const c = moved.contours[0];
  if (c.type !== "circle") throw Error();
  expect(c.radius).toBe(2);
  expect(c.center[0]).toBeCloseTo(10);
  expect(c.center[1]).toBeCloseTo(15);
  const fixed = {
    ...circle,
    constraints: [
      {
        id: "fix",
        kind: "fix" as const,
        a: { contour: 0, kind: "point" as const, index: 0 },
        point: [5, 0] as SketchPoint,
      },
    ],
  };
  expect(() => moveSketchContours(fixed, [0], transform)).toThrow("conflicts");
  expect(fixed.contours[0]).toMatchObject({ center: [5, 0] });
  const copied = mirrorSketch(fixed, [0], [0, 0], [0, 1]);
  expect(copied.constraints?.slice(0, fixed.constraints.length)).toEqual(fixed.constraints);
  expect(copied.constraints?.at(-1)?.kind).toBe("pattern");
});
it("trims between exact line boundaries and remaps unaffected constraints", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      line([-10, 0], [10, 0]),
      line([-3, -5], [-3, 5]),
      line([3, -5], [3, 5]),
      { type: "circle", center: [20, 0], radius: 2 },
    ],
    constraints: [
      { id: "r", kind: "radius", a: { contour: 3, kind: "circle" }, value: 2 },
    ],
  };
  const next = trimSketchLine(d, [0, 0], 0.2);
  expect(next.contours).toHaveLength(5);
  expect(next.contours[0]).toMatchObject({
    start: [-10, 0],
    segments: [{ end: [-3, 0] }],
  });
  expect(next.contours[1]).toMatchObject({
    start: [3, 0],
    segments: [{ end: [10, 0] }],
  });
  expect(next.constraints![0].a.contour).toBe(4);
  expect(d.contours).toHaveLength(4);
});
it("extends to the nearest circle boundary and removes an isolated trimmed line", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      line([0, 0], [5, 0]),
      { type: "circle", center: [10, 0], radius: 2 },
    ],
  };
  expect(extendSketchLine(d, [4.9, 0], 0.2).contours[0]).toMatchObject({
    segments: [{ end: [8, 0] }],
  });
  expect(
    trimSketchLine(
      { type: "drawing", contours: [line([0, 0], [5, 0])] },
      [2, 0],
      0.2,
    ).contours,
  ).toHaveLength(0);
  expect(() =>
    extendSketchLine(
      { type: "drawing", contours: [line([0, 0], [5, 0])] },
      [4, 0],
      0.2,
    ),
  ).toThrow("No boundary");
});
it("removes constraints on deleted targets and extends to an exact ellipse boundary", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [line([0, 0], [5, 0])],
    constraints: [
      {
        id: "length",
        kind: "length",
        a: { contour: 0, kind: "line", index: 0 },
        value: 5,
      },
    ],
  };
  const removed = trimSketchLine(d, [2, 0], 0.2);
  expect(removed.contours).toEqual([]);
  expect(removed.constraints).toEqual([]);
  expect(d.constraints).toHaveLength(1);
  const curves: SketchDrawing = {
    type: "drawing",
    contours: [
      ...d.contours,
      sketchVariantContour("ellipse", [
        [10, 0],
        [12, 0],
        [10, 2],
      ]),
    ],
  };
  expect(extendSketchLine(curves,[4,0],.2).contours[0]).toMatchObject({segments:[{end:[8,0]}]});
});

it("line Trim preserves finite contacts even when a point is closer to the pick", () => {
 const d: SketchDrawing={type:"drawing",contours:[line([0,0],[10,0]),line([3,-2],[3,2]),line([7,-2],[7,2]),{type:"path",start:[5,.05],segments:[]},{type:"path",start:[9,0],segments:[]}],constraints:[
 {id:"contact",kind:"coincident",a:{kind:"point",contour:4,index:0},b:{kind:"curve",contour:0,index:0,parameter:.9,sliding:true}},
 {id:"h",kind:"horizontal",a:{kind:"line",contour:0,index:0}}
 ]};
 const next=trimSketchLine(d,[5,.05],.1);
 expect(next.contours).toHaveLength(6);
 expect(next.contours[4]).toMatchObject({start:[5,.05],segments:[]});
 const contact=next.constraints!.find(c=>c.id==="contact")!;
 expect(contact.b).toMatchObject({contour:1,index:0,sliding:true});
 expect(contact.b!.parameter).toBeCloseTo(2/3,6);
 expect(next.constraints!.find(c=>c.id==="h")).toBeDefined();
 validateSketchDrawing(next);
});
