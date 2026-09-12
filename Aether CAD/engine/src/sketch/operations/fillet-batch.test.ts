import { it, expect } from "vitest";
import { filletSketchCorners } from "./fillet-batch";
import { solveDrawingConstraints } from "../drawing-constraints";
import { sketchArcGeometry } from "../arc-geometry";
import { contourClosed, type SketchDrawing } from "../drawing";
const rectangle = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        { type: "line", end: [20, 0] },
        { type: "line", end: [20, 20] },
        { type: "line", end: [0, 20] },
        { type: "line", end: [0, 0] },
      ],
    },
  ],
});
it("fillets original corner selections with one editable shared radius", () => {
  const source = rectangle(),
    next = filletSketchCorners(
      source,
      [
        { contour: 0, vertex: 0 },
        { contour: 0, vertex: 2 },
        { contour: 0, vertex: 0 },
      ],
      2,
    );
  expect(contourClosed(next.contours[0])).toBe(true);
  const radii = next.constraints!.filter((c) => c.kind === "radius");
  expect(radii).toHaveLength(1);
  radii[0].value = 3;
  const solved = solveDrawingConstraints(next),
    c = solved.contours[0];
  if (c.type !== "path") throw Error("path");
  let start = c.start;
  const values: number[] = [];
  for (const segment of c.segments) {
    if (segment.type === "arc")
      values.push(sketchArcGeometry(start, segment.middle, segment.end).radius);
    start = segment.end;
  }
  expect(values).toHaveLength(2);
  for (const radius of values) expect(radius).toBeCloseTo(3, 5);
  expect(source.contours).toHaveLength(1);
});
it("rejects an invalid batch without partially changing the source", () => {
  const source = rectangle(),
    before = JSON.stringify(source);
  expect(() =>
    filletSketchCorners(
      source,
      [
        { contour: 0, vertex: 2 },
        { contour: 0, vertex: 99 },
      ],
      2,
    ),
  ).toThrow();
  expect(JSON.stringify(source)).toBe(before);
});
