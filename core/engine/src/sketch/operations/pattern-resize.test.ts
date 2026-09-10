import { expect, it } from "vitest";
import { linearPattern, circularPattern } from "./pattern";
import { editPatternGroup } from "./pattern-group";
import { removeDrawingConstraint } from "./edit-dimension";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [{ id: "source", type: "circle", center: [0, 0], radius: 1 }],
});
it("retains 2D grid-slot identities while growing and shrinking row width", () => {
  const p = linearPattern(source(), [0], [10, 0], 2, [0, 20], 2),
    id = Object.keys(p.patternGroups!)[0];
  p.contours[2].id = "upper-source-instance";
  const originalRelation = p.constraints!.find((c) => c.b!.contour === 2)!;
  const bigger = editPatternGroup(JSON.parse(JSON.stringify(p)), id, {
    kind: "linear",
    first: [10, 0],
    second: [0, 20],
    countFirst: 3,
    countSecond: 2,
  });
  expect(bigger.contours).toHaveLength(6);
  expect(
    bigger.constraints!.find((c) => c.id === originalRelation.id),
  ).toMatchObject({ patternInstance: 3, b: { contour: 2 } });
  expect(bigger.contours[2]).toMatchObject({
    id: "upper-source-instance",
    center: [0, 20],
  });
  const smaller = editPatternGroup(bigger, id, {
    kind: "linear",
    first: [10, 0],
    second: [0, 20],
    countFirst: 1,
    countSecond: 3,
  });
  expect(smaller.contours).toHaveLength(3);
  expect(smaller.contours[1]).toMatchObject({
    id: "upper-source-instance",
    center: [0, 20],
  });
  expect(
    smaller.constraints!.find((c) => c.id === originalRelation.id),
  ).toMatchObject({ patternInstance: 1, b: { contour: 1 } });
  expect(smaller.contours[2]).toMatchObject({ center: [0, 40] });
  validateSketchDrawing(smaller);
  expect(p.contours).toHaveLength(4);
});
it("rejects deletion of depended-on instances and remaps unrelated references on shrink", () => {
  const p = circularPattern(source(), [0], [5, 0], 4, 90),
    id = Object.keys(p.patternGroups!)[0];
  p.contours.push({ type: "circle", center: [30, 30], radius: 2 });
  p.constraints!.push({
    id: "tail-radius",
    kind: "radius",
    a: { kind: "circle", contour: 4 },
    value: 2,
  });
  const blocked = structuredClone(p);
  blocked.constraints!.push({
    id: "instance-radius",
    kind: "radius",
    a: { kind: "circle", contour: 3 },
    value: 1,
  });
  const before = structuredClone(blocked);
  expect(() =>
    editPatternGroup(blocked, id, {
      kind: "circular",
      center: [5, 0],
      count: 2,
      stepDegrees: 90,
    }),
  ).toThrow(/dependent/);
  expect(blocked).toEqual(before);
  const shrunk = editPatternGroup(p, id, {
    kind: "circular",
    center: [5, 0],
    count: 2,
    stepDegrees: 90,
  });
  expect(shrunk.contours).toHaveLength(3);
  expect(
    shrunk.constraints!.find((c) => c.id === "tail-radius")!.a.contour,
  ).toBe(2);
  validateSketchDrawing(shrunk);
});
it("grows every selected source and rejects incomplete detached groups", () => {
  const d = source();
  d.contours.push({ type: "circle", center: [5, 0], radius: 2 });
  const p = linearPattern(d, [0, 1], [20, 0], 2),
    id = Object.keys(p.patternGroups!)[0];
  const grown = editPatternGroup(p, id, {
    kind: "linear",
    first: [20, 0],
    second: [0, 0],
    countFirst: 4,
    countSecond: 1,
  });
  expect(grown.contours).toHaveLength(8);
  expect(grown.constraints).toHaveLength(6);
  const partial = linearPattern(d,[0,1],[20,0],3);
  const detached = removeDrawingConstraint(partial, partial.constraints![0].id);
  expect(() =>
    editPatternGroup(detached, id, {
      kind: "linear",
      first: [20, 0],
      second: [0, 0],
      countFirst: 4,
      countSecond: 1,
    }),
  ).toThrow(/incomplete/);
});
