import { it, expect } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { putSketchText } from "./edit";
import { textFrameHeight } from "./height";
import { resizeSketchTextFrame } from "./resize";
import { editDrawingDimension } from "../operations/edit-dimension";
import { sketchTextFontAscenderRatio } from "./font";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  serializePartDocument,
  parsePartDocument,
} from "../../document/part-serialization";
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

const options = {
  text: "O",
  emSizeMillimeters: 99,
  textHeightMillimeters: 8,
  originMillimeters: [0, 0] as [number, number],
  frameWidthMillimeters: 12,
};
const create = () =>
  putSketchText(
    { type: "drawing", contours: [] },
    { ...options, fontBytes: fontBytes() },
  );
it("uses font ascender to convert requested height to em size and first-line frame height", async () => {
  expect(await sketchTextFontAscenderRatio(fontBytes())).toBe(0.8);
  const drawing = await create(),
    item = drawing.textItems![0];
  expect(item.emSizeMillimeters).toBe(10);
  expect(item.fontAscenderRatio).toBe(0.8);
  expect(textFrameHeight(item)).toBe(8);
  const frame = drawing.contours.find((c) => c.id === item.frameContourId)!;
  if (frame.type !== "path") throw Error();
  expect(frame.segments[1].end[1]).toBe(8);
});
it("keeps ascender height through native reopen, dimension solves and explicit resizing", async () => {
  const drawing = await create();
  drawing.constraints!.push({
    id: "height",
    kind: "length",
    a: { contour: 2, kind: "line", index: 1 },
    value: 8,
  });
  const doc = createEmptyPartDocument("Ascender height");
  doc.features.push({
    id: "s",
    type: "profile",
    name: "Text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: drawing,
  });
  const feature = parsePartDocument(serializePartDocument(doc)).features[0];
  if (feature.type !== "profile" || feature.profile.type !== "drawing")
    throw Error();
  const resized = editDrawingDimension(feature.profile, "height", 16);
  expect(resized.textItems![0].emSizeMillimeters).toBeCloseTo(20);
  expect(textFrameHeight(resized.textItems![0])).toBeCloseTo(16);
  const free = { ...resized, constraints: [] };
  const taller = resizeSketchTextFrame(free, free.textItems![0].id, 12, 30);
  expect(textFrameHeight(taller.textItems![0])).toBeCloseTo(24);
});
it("reflects about physical frame height and permits returning to legacy em sizing", async () => {
  const flipped = await putSketchText(
    { type: "drawing", contours: [] },
    { ...options, fontBytes: fontBytes(), flipVertical: true },
  );
  const glyph = flipped.contours[0];
  if (glyph.type !== "path") throw Error();
  expect(glyph.start[1]).toBe(8);
  const legacy = await putSketchText(flipped, {
    ...options,
    id: flipped.textItems![0].id,
    emSizeMillimeters: 10,
    textHeightMillimeters: null,
  });
  expect(legacy.textItems![0].fontAscenderRatio).toBeUndefined();
  expect(textFrameHeight(legacy.textItems![0])).toBe(10);
});
it("rejects nonpositive heights and invalid persisted ascender ratios", async () => {
  await expect(
    putSketchText(
      { type: "drawing", contours: [] },
      { ...options, fontBytes: fontBytes(), textHeightMillimeters: 0 },
    ),
  ).rejects.toThrow(/positive/);
  expect(() =>
    textFrameHeight({ emSizeMillimeters: 10, fontAscenderRatio: -1 }),
  ).toThrow(/positive/);
});
