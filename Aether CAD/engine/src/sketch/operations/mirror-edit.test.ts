import { expect, it } from "vitest";
import { editMirrorAxis, mirrorAxisPoints } from "./mirror-edit";
import { mirrorSketch } from "./mirror";
import type { SketchDrawing } from "../drawing";
const fixture = () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      { id: "source", type: "circle", center: [5, 3], radius: 2 },
      {
        type: "path",
        start: [0, -10],
        segments: [{ type: "line", end: [0, 10] }],
      },
      {
        type: "path",
        start: [-10, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
    ],
  };
  const m = mirrorSketch(d, [0], [0, 0], [0, 10], {
    contour: 1,
    kind: "line",
    index: 0,
  });
  m.contours[3].id = "instance";
  return m;
};
it("reassigns a live axis and converts to fixed coordinates with stable relation/instance IDs", () => {
  const original = fixture(),
    id = original.constraints![0].id;
  const next = editMirrorAxis(original, id, {
    axis: { contour: 2, kind: "line", index: 0 },
  });
  expect(next.contours[3]).toMatchObject({
    id: "instance",
    center: [5, -3],
    radius: 2,
  });
  const identified = structuredClone(original.contours.slice(0, 3));
  if (identified[2].type !== "path") throw Error();
  identified[2].segments[0].id = "source-edge-1";
  expect(next.contours.slice(0, 3)).toEqual(identified);
  expect(next.constraints![0].id).toBe(id);
  const fixed = editMirrorAxis(JSON.parse(JSON.stringify(next)), id, {
    start: [2, -10],
    end: [2, 10],
  });
  expect(fixed.contours[3]).toMatchObject({ id: "instance", center: [-1, 3] });
  expect(fixed.constraints![0].axis).toBeUndefined();
  const [a, b] = mirrorAxisPoints(fixed, fixed.constraints![0]);
  expect(a[0]).toBeCloseTo(2);
  expect(b[0]).toBeCloseTo(2);
  expect(original).toEqual(fixture());
});
it("rejects self-reference, missing relations and degenerate axes without mutating the source", () => {
  const source = fixture(),
    before = structuredClone(source),
    id = source.constraints![0].id;
  expect(() =>
    editMirrorAxis(source, id, { axis: { contour: 0, kind: "circle" } }),
  ).toThrow(/outside/);
  expect(() =>
    editMirrorAxis(source, id, { start: [0, 0], end: [0, 0] }),
  ).toThrow(/distinct/);
  expect(() =>
    editMirrorAxis(source, "missing", { start: [0, 0], end: [1, 0] }),
  ).toThrow(/existing/);
  expect(source).toEqual(before);
});
