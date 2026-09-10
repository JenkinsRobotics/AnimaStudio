import { expect, it } from "vitest";
import { offsetSketch, offsetSketchContour } from "./offset";
import { editDrawingDimension } from "./edit-dimension";
import { solveDrawingConstraints } from "../solver/solve";
import { sketchConstraintState } from "../solver/diagnostics";
import { splitSketchSegment } from "./split";
import { trimSketchCurve } from "./trim";
import { deleteSketchContour } from "./delete";
import type { SketchDrawing, SketchPoint } from "../drawing";
function fixture(closed: boolean): SketchDrawing {
  const vertices: SketchPoint[] = closed
    ? [
        [0, 0],
        [10, 0],
        [10, 10],
        [0, 10],
      ]
    : [
        [0, 0],
        [10, 0],
        [10, 10],
      ];
  return {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: vertices[0],
        segments: [...vertices.slice(1), ...(closed ? [vertices[0]] : [])].map(
          (end) => ({ type: "line", end }),
        ),
      },
    ],
    constraints: vertices.map((point, index) => ({
      id: `p${index}`,
      kind: "fix",
      a: { kind: "point", contour: 0, index },
      point: [...point] as SketchPoint,
    })),
  };
}
it.each([false, true])(
  "updates joined corners and end caps as a source chain changes (%s)",
  (closed) => {
    const initial = offsetSketch(fixture(closed), [0], 1),
      draft = structuredClone(initial);
    draft.constraints!.find((c) => c.id === "p1")!.point = [20, 0];
    draft.constraints!.find((c) => c.id === "p2")!.point = [20, 10];
    const solved = solveDrawingConstraints(draft),
      expected = offsetSketchContour(solved.contours[0], 1),
      actual = solved.contours[1];
    if (actual.type !== "path" || expected.type !== "path") throw Error();
    const points = [actual.start, ...actual.segments.map((s) => s.end)],
      targets = [expected.start, ...expected.segments.map((s) => s.end)];
    points.forEach((p, i) =>
      p.forEach((v, k) => expect(v).toBeCloseTo(targets[i][k], 5)),
    );
    expect(sketchConstraintState(solved).degreesOfFreedom).toBe(0);
    const resized = editDrawingDimension(solved, "offset-1", 2);
    if (resized.contours[1].type !== "path") throw Error();
    expect(resized.contours[1].start[1]).toBeCloseTo(2, 5);
  },
);
it("retains intermediate collinear vertices and rejects collapsing offsets atomically", () => {
  const d = fixture(false);
  if (d.contours[0].type !== "path") throw Error();
  d.contours[0].segments[1].end = [20, 0];
  d.constraints![2].point = [20, 0];
  const next = offsetSketch(d, [0], 2);
  expect(sketchConstraintState(next).degreesOfFreedom).toBe(0);
  const square = offsetSketch(fixture(true), [0], 1),
    before = structuredClone(square);
  expect(() => editDrawingDimension(square, "offset-1", 6)).toThrow();
  expect(square).toEqual(before);
});
it("rejects unsupported topology edits while preserving deletion semantics", () => {
  const d = offsetSketch(fixture(true), [0], 1),
    before = structuredClone(d);
  expect(() => splitSketchSegment(d, [5, 0], 0.01)).toThrow();
  expect(() => trimSketchCurve(d, [5, 0], 0.01)).toThrow();
  expect(d).toEqual(before);
  const deleted = deleteSketchContour(d, 0);
  expect(deleted.contours).toHaveLength(1);
  expect(deleted.constraints).toHaveLength(0);
});
