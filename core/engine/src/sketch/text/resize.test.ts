import { removeDrawingConstraint } from "../operations/edit-dimension";
import { it, expect } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { putSketchText, sketchTextEditState } from "./edit";
import { resizeSketchTextFrame } from "./resize";
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
      originMillimeters: [7, 9],
      frameWidthMillimeters: 8,
    },
  );
it("resizes width independently and height proportionally with a fixed baseline", async () => {
  const source = await create();
  const wide = resizeSketchTextFrame(source, source.textItems![0].id, 20, 10);
  expect(wide.contours[0]).toEqual(source.contours[0]);
  const tall = resizeSketchTextFrame(wide, source.textItems![0].id, 20, 20);
  expect(tall.textItems![0]).toMatchObject({
    originMillimeters: [7, 9],
    emSizeMillimeters: 20,
    frameWidthMillimeters: 20,
  });
  const glyph = tall.contours[0];
  if (glyph.type !== "path") throw Error();
  expect(glyph.segments[0].end[0]).toBeCloseTo(19);
  expect(tall.constraints).toEqual(source.constraints);
  expect(await sketchTextEditState(tall, source.textItems![0].id)).toBe(
    "constrained",
  );
  expect(source.textItems![0].emSizeMillimeters).toBe(10);
});
it("preserves rotated/flipped frame and edge identities", async () => {
  const source = await create();
  const free = removeDrawingConstraint(source, source.constraints![0].id);
  const rotated = await putSketchText(free, {
    id: source.textItems![0].id,
    text: "O",
    emSizeMillimeters: 10,
    originMillimeters: [7, 9],
    rotationDegrees: 37,
    flipHorizontal: true,
  });
  const frame = rotated.contours.find(
    (c) => c.id === rotated.textItems![0].frameContourId,
  )!;
  if (frame.type !== "path") throw Error();
  frame.startVertexId = "start";
  frame.segments[0].id = "baseline";
  const resized = resizeSketchTextFrame(
    rotated,
    rotated.textItems![0].id,
    16,
    20,
  );
  expect(resized.textItems![0]).toMatchObject({
    rotationDegrees: 37,
    flipHorizontal: true,
    originMillimeters: [7, 9],
  });
  expect(resized.contours.find((c) => c.id === frame.id)).toMatchObject({
    startVertexId: "start",
    segments: [{ id: "baseline" }, {}, {}, {}],
  });
});
it("rejects conflicting locked dimensions without mutating the sketch", async () => {
  const source = await create();
  source.constraints = [
    {
      id: "width",
      kind: "length",
      a: { contour: 2, kind: "line", index: 0 },
      value: 8,
    },
  ];
  const before = structuredClone(source);
  expect(() =>
    resizeSketchTextFrame(source, source.textItems![0].id, 20, 10),
  ).toThrow();
  expect(source).toEqual(before);
  const taller = resizeSketchTextFrame(source, source.textItems![0].id, 8, 20);
  expect(taller.constraints).toEqual(source.constraints);
});
it("rejects nonpositive sizes and modified retained geometry", async () => {
  const source = await create(),
    id = source.textItems![0].id;
  expect(() => resizeSketchTextFrame(source, id, 0, 10)).toThrow(/positive/);
  const glyph = source.contours[0];
  if (glyph.type !== "path") throw Error();
  glyph.start[0] += 1;
  expect(() => resizeSketchTextFrame(source, id, 20, 10)).toThrow(/manually/);
});
