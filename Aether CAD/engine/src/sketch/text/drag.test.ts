import { it, expect } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { putSketchText, sketchTextEditState } from "./edit";
import { dragSketchEntity } from "../operations/drag-entity";
import { sketchConstraintState } from "../solver/diagnostics";
function fontBytes() {
  const path = new Path();
  path.moveTo(0, 0);
  path.lineTo(600, 0);
  path.lineTo(600, 800);
  path.lineTo(0, 800);
  path.close();
  path.moveTo(100, 100);
  path.lineTo(100, 700);
  path.lineTo(500, 700);
  path.lineTo(500, 100);
  path.close();
  return new Font({
    familyName: "Test",
    styleName: "Regular",
    unitsPerEm: 1000,
    ascender: 800,
    descender: -200,
    glyphs: [
      new Glyph({ name: ".notdef", advanceWidth: 700, path: new Path() }),
      new Glyph({ name: "O", unicode: 79, advanceWidth: 700, path }),
    ],
  }).toArrayBuffer();
}

const create = () =>
  putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: fontBytes(),
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
      frameWidthMillimeters: 8,
    },
  );
it("moves letters and frame together while retaining editable text metadata", async () => {
  const source = await create(),
    item = source.textItems![0];
  const moved = dragSketchEntity(
    source,
    { contour: 2, kind: "line", index: 0 },
    [20, 30],
  );
  expect(moved.textItems![0].originMillimeters).toEqual([20, 30]);
  expect(moved.textItems![0].emSizeMillimeters).toBe(10);
  expect(moved.constraints).toEqual(source.constraints);
  expect(await sketchTextEditState(moved, item.id)).toBe("constrained");
  const letter = moved.contours[0];
  if (letter.type !== "path") throw Error();
  expect(letter.start).toEqual([20, 30]);
  const reworded = await putSketchText(moved, {
    id: item.id,
    text: "OO",
    emSizeMillimeters: 10,
    originMillimeters: [20, 30],
  });
  expect(reworded.contours).toHaveLength(5);
  expect(source.textItems![0].originMillimeters).toEqual([0, 0]);
});
it("resizes a frame corner around a constrained baseline without deforming glyphs", async () => {
  const source = await create();
  source.constraints = [
    {
      id: "anchor",
      kind: "fix",
      a: { contour: 2, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "baseline",
      kind: "horizontal",
      a: { contour: 2, kind: "line", index: 0 },
    },
  ];
  const moved = dragSketchEntity(
    source,
    { contour: 2, kind: "point", index: 2 },
    [8, 10],
  );
  expect(moved.textItems![0].originMillimeters[0]).toBeCloseTo(0);
  expect(moved.textItems![0].originMillimeters[1]).toBeCloseTo(0);
  expect(moved.textItems![0].emSizeMillimeters).toBeCloseTo(20);
  expect(moved.textItems![0].frameWidthMillimeters).toBeCloseTo(16);
  const glyph = moved.contours[0];
  if (glyph.type !== "path") throw Error();
  expect(glyph.segments[0].end[0]).toBeCloseTo(12);
  expect(moved.constraints).toHaveLength(2);
  expect(sketchConstraintState(moved).degreesOfFreedom).toBe(2);
});
it("rejects incompatible fixed text drags atomically", async () => {
  const source = await create();
  source.constraints = [
    {
      id: "anchor",
      kind: "fix",
      a: { contour: 2, kind: "point", index: 0 },
      point: [0, 0],
    },
  ];
  const before = structuredClone(source);
  expect(() =>
    dragSketchEntity(source, { contour: 2, kind: "point", index: 0 }, [4, 5]),
  ).toThrow();
  expect(source).toEqual(before);
});
