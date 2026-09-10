import { expect, it } from "vitest";
import { inferSketchSemicircle } from "./semicircle";
import { editDrawingDimension } from "./edit-dimension";
import { sketchArcGeometry } from "../arc-geometry";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
import { sketchConstraintState } from "../solver/diagnostics";
it.each([5, -5])(
  "preserves the semicircle with midpoint %s through a radius edit",
  (y) => {
    const source: SketchDrawing = {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [-5, 0],
          segments: [{ type: "arc", middle: [0, y], end: [5, 0] }],
        },
      ],
    };
    const original = structuredClone(source);
    const next = inferSketchSemicircle(source, 0, 0);
    expect(source).toEqual(original);
    expect(next.contours).toHaveLength(3);
    expect(next.contours.slice(1).every((c) => c.construction)).toBe(true);
    next.constraints!.push({
      id: "radius",
      kind: "radius",
      a: { contour: 0, kind: "arc", index: 0 },
      value: 5,
    });
    const edited = editDrawingDimension(
      JSON.parse(JSON.stringify(next)),
      "radius",
      8,
    );
    validateSketchDrawing(edited);
    const path = edited.contours[0];
    if (path.type !== "path" || path.segments[0].type !== "arc") throw Error();
    const arc = sketchArcGeometry(
      path.start,
      path.segments[0].middle,
      path.segments[0].end,
    );
    expect(arc.radius).toBeCloseTo(8);
    expect(Math.abs(arc.sweep)).toBeCloseTo(Math.PI);
    expect(Math.sign(arc.sweep)).toBe(-Math.sign(y));
    expect(sketchConstraintState(edited).state).toBe("under-constrained");
  },
);
it("does not infer on an ordinary arc", () => {
  const source: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-5, 0],
        segments: [{ type: "arc", middle: [0, 3], end: [5, 0] }],
      },
    ],
  };
  expect(inferSketchSemicircle(source, 0, 0)).toBe(source);
});
