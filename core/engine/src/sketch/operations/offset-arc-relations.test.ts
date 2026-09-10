import { expect, it } from "vitest";
import { offsetSketch } from "./offset";
import { editDrawingDimension } from "./edit-dimension";
import { sketchArcGeometry } from "../arc-geometry";
import { sketchConstraintState } from "../solver/diagnostics";
import type { SketchDrawing } from "../drawing";
const geometry = (d: SketchDrawing, i: number) => {
  const p = d.contours[i];
  if (p.type !== "path" || p.segments[0].type !== "arc") throw Error();
  return sketchArcGeometry(p.start, p.segments[0].middle, p.segments[0].end);
};
function source(clockwise = false): SketchDrawing {
  return {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [5, 0],
        segments: [
          { type: "arc", middle: [0, clockwise ? -5 : 5], end: [-5, 0] },
        ],
      },
    ],
    constraints: [
      {
        id: "radius",
        kind: "radius",
        a: { kind: "arc", contour: 0, index: 0 },
        value: 5,
      },
    ],
  };
}
it.each([false, true])(
  "preserves arc center and span during source and signed distance edits (%s)",
  (clockwise) => {
    const initial = offsetSketch(source(clockwise), [0], 1);
    expect(initial.constraints?.find((c) => c.kind === "offset")?.a.kind).toBe(
      "arc",
    );
    const resized = editDrawingDimension(initial, "radius", 8);
    for (const d of [resized, editDrawingDimension(resized, "offset-1", -2)]) {
      const a = geometry(d, 0),
        b = geometry(d, 1),
        distance = d.constraints!.find((c) => c.kind === "offset")!.value!;
      expect(a.radius).toBeCloseTo(8, 5);
      expect(b.radius).toBeCloseTo(a.radius - Math.sign(a.sweep) * distance, 5);
      expect(b.center[0]).toBeCloseTo(a.center[0], 5);
      expect(b.center[1]).toBeCloseTo(a.center[1], 5);
      expect(b.sweep).toBeCloseTo(a.sweep, 5);
      expect(Math.sin(b.startAngle - a.startAngle)).toBeCloseTo(0, 5);
    }
    expect(geometry(initial, 0).radius).toBeCloseTo(5, 5);
  },
);
it("reports independent arc degrees of freedom without redundant through-point equations", () => {
  const d = offsetSketch(source(), [0], 1),
    state = sketchConstraintState(d);
  expect(state.state).toBe("under-constrained");
  expect(state.degreesOfFreedom).toBe(4);
  expect(state.redundantEquations).toBe(0);
});
it("rejects an impossible fixed-radius offset without changing the original", () => {
  const d = offsetSketch(source(), [0], 1),
    before = structuredClone(d);
  expect(() => editDrawingDimension(d, "offset-1", 6)).toThrow();
  expect(d).toEqual(before);
});
