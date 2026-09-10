import { expect, it } from "vitest";
import { mirrorSketch } from "./mirror";
import { dragSketchEntity } from "./drag-entity";
import { editDrawingDimension } from "./edit-dimension";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
const source = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    { type: "circle", center: [5, 0], radius: 2 },
    {
      type: "path",
      construction: true,
      start: [0, -10],
      segments: [{ type: "line", end: [0, 10] }],
    },
  ],
  constraints: [
    {
      id: "center",
      kind: "fix",
      a: { kind: "point", contour: 0, index: 0 },
      point: [5, 0],
    },
    {
      id: "radius",
      kind: "radius",
      a: { kind: "circle", contour: 0 },
      value: 2,
    },
  ],
});
it("follows a live mirror axis and source radius after native serialization", () => {
  const d = source(),
    m = mirrorSketch(d, [0], [0, 0], [0, 10], {
      kind: "line",
      contour: 1,
      index: 0,
    });
  expect(m.constraints!.at(-1)).toMatchObject({
    kind: "pattern",
    axis: { kind: "line", contour: 1, index: 0 },
  });
  expect(m.constraints!.at(-1)!.transform).toBeUndefined();
  const moved = dragSketchEntity(
    JSON.parse(JSON.stringify(m)),
    { kind: "line", contour: 1, index: 0 },
    [2, 0],
  );
  const copy = moved.contours[2];
  if (copy.type !== "circle") throw Error();
  expect(copy.center[0]).toBeCloseTo(-1, 6);
  expect(copy.center[1]).toBeCloseTo(0, 6);
  const changed = editDrawingDimension(moved, "radius", 3);
  if (changed.contours[2].type !== "circle") throw Error();
  expect(changed.contours[2].radius).toBeCloseTo(3, 6);
  expect(d).toEqual(source());
});
it("retains fixed numeric reflection and rejects invalid live axes atomically", () => {
  const d = source();
  const m = mirrorSketch(d, [0], [0, 0], [0, 10]);
  const edited = editDrawingDimension(m, "radius", 4);
  if (edited.contours[2].type !== "circle") throw Error();
  expect(edited.contours[2].radius).toBeCloseTo(4, 6);
  expect(() =>
    mirrorSketch(d, [0, 1], [0, 0], [0, 10], {
      kind: "line",
      contour: 1,
      index: 0,
    }),
  ).toThrow(/Exclude/);
  expect(() =>
    mirrorSketch(d, [0], [0, 0], [0, 10], { kind: "circle", contour: 0 }),
  ).toThrow(/line/);
  const bad = structuredClone(m);
  bad.constraints!.at(-1)!.axis = { kind: "line", contour: 1, index: 0 };
  expect(() => validateSketchDrawing(bad)).toThrow(/fixed transform/);
});
