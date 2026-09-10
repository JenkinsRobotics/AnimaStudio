import { it, expect } from "vitest";
import { filletSketchCurves } from "./fillet-curves";
import {
  constraintResiduals,
  solveDrawingConstraints,
} from "../drawing-constraints";
import type { SketchDrawing } from "../drawing";
const drawing = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [-10, 0],
      segments: [{ type: "line", end: [0, 0] }],
    },
    {
      type: "path",
      start: [0, 0],
      segments: [
        {
          type: "bezier",
          controls: [
            [1, 3],
            [2, 7],
          ],
          end: [0, 10],
        },
      ],
    },
    { type: "path", start: [30, 30], segments: [], construction: true },
  ],
  constraints: [
    {
      id: "outer",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0 },
      point: [-10, 0],
    },
    {
      id: "unrelated",
      kind: "fix",
      a: { contour: 2, kind: "point", index: 0 },
      point: [30, 30],
    },
  ],
});
const a = { contour: 0, segment: 0, parameter: 0.5 },
  b = { contour: 1, segment: 0, parameter: 0.7 };
it("creates an exact curved fillet with persistent finite tangent joins and remapped references", () => {
  const source = drawing(),
    before = structuredClone(source),
    result = filletSketchCurves(source, a, b, 1);
  expect(source).toEqual(before);
  expect(result.contours).toHaveLength(2);
  const path = result.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments.map((s) => s.type)).toEqual(["line", "arc", "bezier"]);
  expect(result.constraints!.find((c) => c.id === "unrelated")!.a.contour).toBe(
    1,
  );
  const reopened = JSON.parse(JSON.stringify(result));
  for (const c of reopened.constraints)
    for (const r of constraintResiduals(reopened, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
  const radius = reopened.constraints.find(
    (c: { kind: string }) => c.kind === "radius",
  );
  radius.value = 1.2;
  const solved = solveDrawingConstraints(reopened);
  for (const c of solved.constraints!)
    for (const r of constraintResiduals(solved, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("preserves the selected sides when curve order is reversed", () => {
  const result = filletSketchCurves(drawing(), b, a, 1),
    path = result.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments.map((s) => s.type)).toEqual(["bezier", "arc", "line"]);
  expect(path.start).toEqual([0, 10]);
  expect(path.segments[2].end).toEqual([-10, 0]);
});
it("rejects unsupported trimmed endpoint references atomically", () => {
  const source = drawing();
  source.constraints!.push({
    id: "corner",
    kind: "fix",
    a: { contour: 0, kind: "point", index: 1 },
    point: [0, 0],
  });
  const before = structuredClone(source);
  expect(() => filletSketchCurves(source, a, b, 1)).toThrow("remapping");
  expect(source).toEqual(before);
});
it("preserves a trimmed arc radius reference while joining a line to its circular locus", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [20, 0] }],
      },
      {
        type: "path",
        start: [5, 3],
        segments: [{ type: "arc", middle: [10, -2], end: [15, 3] }],
      },
    ],
    constraints: [
      {
        id: "arc-radius",
        kind: "radius",
        a: { contour: 1, kind: "arc", index: 0 },
        value: 5,
      },
    ],
  };
  const result = filletSketchCurves(
    source,
    { contour: 0, segment: 0, parameter: 0.1 },
    { contour: 1, segment: 0, parameter: 0.9 },
    2,
  );
  expect(result.constraints!.find((c) => c.id === "arc-radius")!.a).toEqual({
    contour: 0,
    kind: "arc",
    index: 2,
  });
  for (const c of result.constraints!)
    for (const r of constraintResiduals(result, c))
      expect(Math.abs(r)).toBeLessThan(1e-6);
});
it("does not commit an unstable near-zero bridge between already tangent curves", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [20, 0] }],
      },
      {
        type: "path",
        start: [5, 5],
        segments: [{ type: "arc", middle: [10, 0], end: [15, 5] }],
      },
    ],
  };
  const before = structuredClone(source);
  expect(() =>
    filletSketchCurves(
      source,
      { contour: 0, segment: 0, parameter: 0.1 },
      { contour: 1, segment: 0, parameter: 0.9 },
      2,
    ),
  ).toThrow();
  expect(source).toEqual(before);
});
