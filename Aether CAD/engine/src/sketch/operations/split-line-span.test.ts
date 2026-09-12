import { expect, it } from "vitest";
import { splitSketchSegment } from "./split";
import { editDrawingDimension } from "./edit-dimension";
import { constraintResiduals } from "../solver/residuals";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
it("retains original midpoint and equal length through Split, reopen and dimension edits", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", id: "edge", end: [10, 0] }],
      },
      { type: "path", start: [5, 0], segments: [] },
      {
        type: "path",
        start: [0, 5],
        segments: [{ type: "line", end: [10, 5] }],
      },
    ],
    constraints: [
      {
        id: "mid",
        kind: "midpoint",
        a: { contour: 0, kind: "line", index: 0, segmentId: "edge" },
        b: { contour: 1, kind: "point", index: 0 },
      },
      {
        id: "equal",
        kind: "equal",
        a: { contour: 0, kind: "line", index: 0, segmentId: "edge" },
        b: { contour: 2, kind: "line", index: 0 },
      },
      {
        id: "length",
        kind: "length",
        a: { contour: 0, kind: "line", index: 0, segmentId: "edge" },
        value: 10,
      },
      {
        id: "origin",
        kind: "fix",
        a: { contour: 0, kind: "point", index: 0 },
        point: [0, 0],
      },
      {
        id: "horizontal",
        kind: "horizontal",
        a: { contour: 0, kind: "line", index: 0 },
      },
    ],
  };
  const before = structuredClone(d);
  const split = splitSketchSegment(d, [3, 0], 0.01);
  expect(d).toEqual(before);
  expect(split.contours).toHaveLength(4);
  expect(split.contours[3].construction).toBe(true);
  expect(split.constraints!.find((c) => c.id === "mid")!.a).toEqual({
    contour: 3,
    kind: "line",
    index: 0,
  });
  const reopened = JSON.parse(JSON.stringify(split));
  validateSketchDrawing(reopened);
  const edited = editDrawingDimension(reopened, "length", 14);
  const p = edited.contours[0];
  if (p.type !== "path") throw Error();
  expect(p.segments[1].end[0]).toBeCloseTo(14, 5);
  expect(edited.contours[1]).toMatchObject({ type: "path" });
  const midpoint = edited.contours[1];
  if (midpoint.type !== "path") throw Error();
  expect(midpoint.start[0]).toBeCloseTo(7, 5);
  for (const c of edited.constraints!)
    expect(
      constraintResiduals(edited, c).every((r) => Math.abs(r) < 1e-6),
    ).toBe(true);
  // Splitting the other child leaves the endpoint-linked original span intact.
  const again = splitSketchSegment(edited, [10, 0], 0.01);
  expect(again.contours).toHaveLength(4);
  for (const c of again.constraints!)
    expect(constraintResiduals(again, c).every((r) => Math.abs(r) < 1e-6)).toBe(
      true,
    );
});
