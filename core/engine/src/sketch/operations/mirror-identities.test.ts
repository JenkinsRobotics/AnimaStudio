import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { mirrorSketchEntities } from "./mirror-entities";
import { editMirrorAxis } from "./mirror-edit";
import { mirrorAxisConflicts } from "../solver/pattern-source";
const fixture = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, -5],
      segments: [
        { type: "line", id: "axis", end: [0, 5] },
        { type: "line", id: "edge", end: [4, 5] },
      ],
    },
  ],
});
it("rejects the same stable edge as mirror axis and accepts distinct edges despite stale positions", () => {
  const d = fixture(),
    before = structuredClone(d);
  const edge = {
    kind: "line" as const,
    contour: 0,
    index: 0,
    segmentId: "edge",
  };
  const axis = {
    kind: "line" as const,
    contour: 0,
    index: 0,
    segmentId: "axis",
  };
  expect(() =>
    mirrorSketchEntities(d, [edge], [0, 0], [0, 1], { ...edge, index: 1 }),
  ).toThrow(/axis itself/);
  const mirrored = mirrorSketchEntities(d, [edge], [0, 0], [0, 1], axis);
  expect(mirrored.contours[1]).toMatchObject({
    start: [0, 5],
    segments: [{ end: [-4, 5] }],
  });
  const id = mirrored.constraints![0].id;
  expect(() =>
    editMirrorAxis(mirrored, id, {
      axis: { kind: "line", contour: 0, index: 1 },
    }),
  ).toThrow(/distinct/);
  expect(
    editMirrorAxis(mirrored, id, {
      axis: { kind: "line", contour: 0, index: 0 },
    }).contours[1],
  ).toEqual(mirrored.contours[1]);
  expect(
    editMirrorAxis(mirrored, id, {
      axis: { kind: "line", contour: 0, index: 0 },
    }).constraints![0].axis,
  ).toMatchObject({ segmentId: "axis" });
  expect(
    mirrorSketchEntities(d, [edge], [0, 0], [0, 1], {
      kind: "line",
      contour: 0,
      index: 0,
    }).constraints![0].axis,
  ).toMatchObject({ segmentId: "axis" });
  expect(d).toEqual(before);
});
it("compares projected contour scope and rejects missing stable axis references", () => {
  const a = {
    kind: "line" as const,
    contour: -1,
    index: 0,
    segmentId: "edge",
    projectedContourId: "one",
  };
  expect(mirrorAxisConflicts(a, { ...a, projectedContourId: "two" })).toBe(
    false,
  );
  expect(mirrorAxisConflicts(a, { ...a, index: 9 })).toBe(true);
  expect(() =>
    mirrorAxisConflicts(
      { kind: "line", contour: 0, index: 1 },
      { kind: "line", contour: 0, index: 0, segmentId: "deleted" },
      undefined,
      fixture(),
    ),
  ).toThrow(/Broken segment/);
});
