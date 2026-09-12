import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { projectedCurveSnap } from "./projected-curve-snap";
import { inferProjectedSnaps } from "./projected-snaps";
import { solveDrawingConstraints } from "../solver/solve";
it("persists a finite sliding curve relation and follows source edits", () => {
  const before: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      {
        id: "path",
        type: "path",
        start: [0, 0],
        segments: [{ id: "edge", type: "line", end: [10, 0] }],
      },
    ],
  };
  const snap = projectedCurveSnap(before, [3, 0.1], 0.2)!;
  expect(snap.point).toEqual([3, 0]);
  const after = structuredClone(before);
  after.contours.push({
    type: "path",
    start: snap.point,
    segments: [{ type: "line", end: [3, 8] }],
  });
  const linked = inferProjectedSnaps(before, after, [snap.point]);
  expect(linked.constraints![0].b).toMatchObject({
    segmentId: "edge",
    kind: "curve",
    sliding: true,
    parameter: 0.3,
  });
  const source = linked.projectionContext![0];
  if (source.type !== "path") throw Error();
  source.start = [0, 5];
  source.segments[0].end = [10, 5];
  linked.constraints!.push({
    id: "placed",
    kind: "fix",
    a: { kind: "point", contour: 0, index: 0 },
    point: [8, 5],
  });
  const solved = solveDrawingConstraints(linked),
    path = solved.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.start[0]).toBeCloseTo(8);
  expect(path.start[1]).toBeCloseTo(5);
  expect(solved.constraints![0].b!.parameter).toBeCloseTo(0.8);
});
it("uses finite spans and picks native cubic and circle geometry", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      {
        id: "curve",
        type: "path",
        start: [0, 0],
        segments: [
          {
            id: "cubic",
            type: "bezier",
            controls: [
              [0, 10],
              [10, 10],
            ],
            end: [10, 0],
          },
        ],
      },
    ],
  };
  const snap = projectedCurveSnap(d, [5, 7.6], 0.2)!;
  expect(snap.point[0]).toBeCloseTo(5);
  expect(snap.point[1]).toBeCloseTo(7.5);
  expect(snap.ref.segmentId).toBe("cubic");
  expect(projectedCurveSnap(d, [20, 0], 0.2)).toBeUndefined();
  d.projectionContext = [
    { id: "circle", type: "circle", center: [0, 0], radius: 5 },
  ];
  expect(projectedCurveSnap(d, [3.03, 4.04], 0.1)?.point).toEqual([3, 4]);
});
