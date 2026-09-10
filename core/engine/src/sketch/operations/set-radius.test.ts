import { expect, it } from "vitest";
import { setSketchRadius, sketchEntityRadius } from "./set-radius";
import { createSketchTangentArc } from "./tangent-arc";
import { constraintResiduals } from "../solver/residuals";
import type { SketchDrawing } from "../drawing";

it("rejects a radius conflicting with fixed geometry without changing the sketch", () => {
  const d: SketchDrawing = { type: "drawing", contours: [
    { type: "circle", center: [0, 0], radius: 5 },
    { type: "path", construction: true, start: [5, 0], segments: [] },
  ], constraints: [
    { id: "center", kind: "fix", a: { contour: 0, kind: "point", index: 0 }, point: [0, 0] },
    { id: "point", kind: "fix", a: { contour: 1, kind: "point", index: 0 }, point: [5, 0] },
    { id: "on-circle", kind: "coincident", a: { contour: 1, kind: "point", index: 0 }, b: { contour: 0, kind: "circle" } },
  ] };
  const before = structuredClone(d);
  expect(() => setSketchRadius(d, { contour: 0, kind: "circle" }, 6)).toThrow();
  expect(d).toEqual(before);
});

it("adds and updates a circle radius without duplicate dimensions", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [0, 0], radius: 5 }],
  };
  const ref = { contour: 0, kind: "circle" as const };
  const first = setSketchRadius(source, ref, 7),
    second = setSketchRadius(first, ref, 9);
  expect(second.constraints).toHaveLength(1);
  expect(second.constraints![0].id).toBe(first.constraints![0].id);
  expect(sketchEntityRadius(second, ref)).toBeCloseTo(9);
  expect(source.constraints).toBeUndefined();
});
it("edits a linked radius through its existing driver", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [0, 1].map((x) => ({
      type: "circle",
      center: [x * 20, 0],
      radius: 5,
    })),
    constraints: [
      {
        id: "driver",
        kind: "radius",
        a: { contour: 0, kind: "circle" },
        value: 5,
      },
      {
        id: "follower",
        kind: "radius",
        a: { contour: 1, kind: "circle" },
        valueFrom: "driver",
      },
    ],
  };
  const result = setSketchRadius(d, { contour: 1, kind: "circle" }, 8);
  expect(result.constraints).toHaveLength(2);
  expect(result.constraints![0].value).toBe(8);
  expect(
    sketchEntityRadius(result, { contour: 0, kind: "circle" }),
  ).toBeCloseTo(8);
});
it("sizes a tangent arc while retaining endpoint tangency", () => {
  const { drawing } = createSketchTangentArc(
    {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [-10, 0],
          segments: [{ type: "line", end: [0, 0] }],
        },
      ],
    },
    { contour: 0, segment: 0, endpoint: 1 },
    [5, 5],
  );
  const result = setSketchRadius(
    drawing,
    { contour: 0, kind: "arc", index: 1 },
    7,
  );
  expect(
    sketchEntityRadius(result, { contour: 0, kind: "arc", index: 1 }),
  ).toBeCloseTo(7);
  for (const c of result.constraints!)
    expect(
      Math.max(...constraintResiduals(result, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
});
it("rejects invalid values and incompatible targets without modifying input", () => {
  const d: SketchDrawing = {
      type: "drawing",
      contours: [{ type: "circle", center: [0, 0], radius: 5 }],
    },
    before = structuredClone(d);
  for (const value of [0, -1, NaN, Infinity])
    expect(() =>
      setSketchRadius(d, { contour: 0, kind: "circle" }, value),
    ).toThrow();
  expect(() =>
    setSketchRadius(d, { contour: 0, kind: "point", index: 0 }, 4),
  ).toThrow();
  expect(d).toEqual(before);
});
