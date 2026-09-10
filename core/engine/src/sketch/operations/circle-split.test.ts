import { expect, it } from "vitest";
import { splitSketchCircle } from "./split";
import { extendSketchLine, ExtensionNeedsEndpoint } from "./trim-extend";
import {
  solveDrawingConstraints,
  constraintResiduals,
} from "../drawing-constraints";
import { sketchArcGeometry } from "../arc-geometry";
import type { SketchDrawing } from "../drawing";
it("splits a circle into two exact arcs and preserves radius/fixed-center constraints", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [2, 3], radius: 5 }],
    constraints: [
      { id: "r", kind: "radius", a: { contour: 0, kind: "circle" }, value: 5 },
      {
        id: "center",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [2, 3],
      },
    ],
  };
  const result = splitSketchCircle(d, 0, [7, 3], [2, 8]),
    c = result.contours[0];
  expect(c.type).toBe("path");
  if (c.type !== "path") throw Error();
  expect(c.segments).toHaveLength(2);
  expect(result.constraints![0].a).toEqual({
    contour: 0,
    kind: "arc",
    index: 0,
  });
  expect(result.constraints![1].a.contour).toBe(1);
  result.constraints![0].value = 7;
  const solved = solveDrawingConstraints(result),
    path = solved.contours[0];
  if (path.type !== "path") throw Error();
  let start = path.start;
  for (const segment of path.segments) {
    if (segment.type !== "arc") throw Error();
    const arc = sketchArcGeometry(start, segment.middle, segment.end);
    expect(arc.radius).toBeCloseTo(7, 5);
    expect(arc.center[0]).toBeCloseTo(2, 5);
    expect(arc.center[1]).toBeCloseTo(3, 5);
    start = segment.end;
  }
  for (const constraint of solved.constraints ?? [])
    expect(
      Math.max(...constraintResiduals(solved, constraint).map(Math.abs)),
    ).toBeLessThan(1e-6);
  expect(d.contours[0].type).toBe("circle");
});
it("rejects coincident circle split locations atomically", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [{ type: "circle", center: [0, 0], radius: 5 }],
  };
  expect(() => splitSketchCircle(d, 0, [5, 0], [10, 0])).toThrow("distinct");
  expect(d.contours[0].type).toBe("circle");
});
it("extends either free end on the original axis when no boundary exists", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", end: [5, 0] }],
      },
    ],
  };
  expect(() => extendSketchLine(d, [4.9, 0], 0.1)).toThrow(
    ExtensionNeedsEndpoint,
  );
  expect(extendSketchLine(d, [4.9, 0], 0.1, [10, 3]).contours[0]).toMatchObject(
    { segments: [{ end: [10, 0] }] },
  );
  expect(extendSketchLine(d, [0.1, 0], 0.2, [-4, 2]).contours[0]).toMatchObject(
    { start: [-4, 0] },
  );
  expect(() => extendSketchLine(d, [4.9, 0], 0.1, [3, 0])).toThrow("beyond");
});
