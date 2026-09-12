import { it, expect } from "vitest";
import { trimSketchSweep } from "./trim-sweep";
import type { SketchDrawing } from "../drawing";
it("trims every crossed line even when a stroke has only two pointer positions", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [-5, 0, 5].map((x) => ({
      type: "path",
      start: [x, -5],
      segments: [{ type: "line", end: [x, 5] }],
    })),
  };
  const next = trimSketchSweep(source, [-10, 0], [10, 0]);
  expect(next.contours).toHaveLength(0);
  expect(source.contours).toHaveLength(3);
});
it("does not double-trim a circle crossed twice by the same stroke", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [0, 0], radius: 5 }],
  };
  expect(trimSketchSweep(source, [-10, 0], [10, 0]).contours).toHaveLength(0);
  expect(trimSketchSweep(source, [0, 10], [10, 10])).toBe(source);
});
it("removes only standalone points within the stroke tolerance and remaps surviving constraints", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      { type: "path", start: [0, 0.2], segments: [] },
      { type: "path", start: [5, 2], segments: [] },
      { type: "path", start: [3, 0], segments: [] },
    ],
    constraints: [
      {
        id: "removed",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [0, 0.2],
      },
      {
        id: "kept",
        kind: "fix",
        a: { contour: 1, kind: "point", index: 0 },
        point: [5, 2],
      },
    ],
  };
  const next = trimSketchSweep(source, [-10, 0], [10, 0], 0.5);
  expect(next.contours).toHaveLength(1);
  expect(next.constraints).toEqual([
    {
      id: "kept",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0 },
      point: [5, 2],
    },
  ]);
  expect(source.contours).toHaveLength(3);
  expect(() => trimSketchSweep(source, [NaN, 0], [1, 1])).toThrow("finite");
});
