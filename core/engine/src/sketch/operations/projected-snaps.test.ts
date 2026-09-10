import { expect, it } from "vitest";
import { projectedSnapPoints, inferProjectedSnaps } from "./projected-snaps";
import { solveDrawingConstraints } from "../solver/solve";
import type { SketchDrawing } from "../drawing";
it("retains projected endpoint and midpoint placement through source changes", () => {
  for (const x of [10, 15]) {
    const before: SketchDrawing = {
      type: "drawing",
      contours: [],
      projectionContext: [
        {
          id: "edge",
          type: "path",
          start: [10, 5],
          segments: [{ type: "line", end: [20, 5] }],
        },
      ],
    };
    const after = structuredClone(before);
    after.contours.push({
      type: "path",
      start: [x, 5],
      segments: [{ type: "line", end: [x, 10] }],
    });
    const next = inferProjectedSnaps(before, after, [
      [x, 5],
      [x, 10],
    ]);
    expect(next.constraints).toHaveLength(1);
    expect(next.constraints![0].kind).toBe(
      x === 10 ? "coincident" : "midpoint",
    );
    expect(
      [next.constraints![0].a, next.constraints![0].b].some(
        (r) => r?.projectedContourId === "edge",
      ),
    ).toBe(true);
    const source = next.projectionContext![0];
    if (source.type !== "path") throw Error();
    source.start = [12, 8];
    source.segments[0].end = [22, 8];
    const solved = solveDrawingConstraints(next),
      path = solved.contours[0];
    if (path.type !== "path") throw Error();
    expect(path.start).toEqual([expect.closeTo(x + 2), expect.closeTo(8)]);
    expect(before.contours).toHaveLength(0);
  }
});
it("exposes arc centers and ignores unidentified sources or existing vertices", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      {
        id: "arc",
        type: "path",
        start: [15, 10],
        segments: [{ type: "arc", middle: [10, 15], end: [5, 10] }],
      },
      { type: "circle", center: [30, 0], radius: 2 },
    ],
  };
  expect(
    projectedSnapPoints(d).some(
      (p) =>
        p.label === "Projected center" &&
        p.point[0] === 10 &&
        p.point[1] === 10,
    ),
  ).toBe(true);
  expect(
    projectedSnapPoints(d).every((p) => p.ref.projectedContourId === "arc"),
  ).toBe(true);
  d.contours.push({ type: "path", start: [10, 10], segments: [] });
  expect(inferProjectedSnaps(d, d, [[10, 10]]).constraints).toEqual([]);
});
