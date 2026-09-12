import { expect, it } from "vitest";
import { linearPattern, circularPattern } from "./pattern";
import { editPatternGroup } from "./pattern-group";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
it("stores one definition and edits two-dimensional spacing with stable instance references", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [1, 2], radius: 1 }],
  };
  const pattern = linearPattern(source, [0], [10, 0], 2, [0, 20], 2),
    id = Object.keys(pattern.patternGroups!)[0];
  expect(
    pattern.constraints!.every(
      (c) => c.patternGroup === id && c.transform === undefined,
    ),
  ).toBe(true);
  const next = editPatternGroup(JSON.parse(JSON.stringify(pattern)), id, {
    kind: "linear",
    first: [15, 0],
    second: [0, 30],
    countFirst: 2,
    countSecond: 2,
  });
  expect(next.constraints).toEqual(pattern.constraints);
  expect(
    next.contours.map((c) => (c.type === "circle" ? c.center : [])),
  ).toEqual([
    [1, 2],
    [16, 2],
    [1, 32],
    [16, 32],
  ]);
  expect(pattern.contours[1]).toMatchObject({ center: [11, 2] });
  validateSketchDrawing(next);

});
it("edits shared circular center/step and rejects missing or contradictory definitions", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [5, 0], radius: 1 }],
  };
  const p = circularPattern(source, [0], [0, 0], 3, 90),
    id = Object.keys(p.patternGroups!)[0];
  const next = editPatternGroup(p, id, {
    kind: "circular",
    center: [1, 0],
    count: 3,
    stepDegrees: 180,
  });
  expect(next.contours[1]).toMatchObject({ center: [-3, expect.any(Number)] });
  expect(
    next.contours[2].type === "circle" && next.contours[2].center[0],
  ).toBeCloseTo(5);
  const bad = structuredClone(p);
  delete bad.patternGroups![id];
  expect(() => validateSketchDrawing(bad)).toThrow(/Missing pattern group/);
  const duplicate = structuredClone(p);
  duplicate.constraints![0].transform = {
    a: 1,
    b: 0,
    c: 0,
    d: 1,
    tx: 0,
    ty: 0,
  };
  expect(() => validateSketchDrawing(duplicate)).toThrow(/also contain/);
});
