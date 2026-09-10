import { it, expect } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { putSketchText } from "./edit";
import { resizeSketchTextFrame } from "./resize";
import { editDrawingDimension } from "../operations/edit-dimension";
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
  emSizeMillimeters: 10,
  originMillimeters: [0, 0] as [number, number],
  frameWidthMillimeters: 8,
};
const create = (extra = {}) =>
  putSketchText(
    { type: "drawing", contours: [] },
    { ...options, fontBytes: fontBytes(), ...extra },
  );
it("flips letters about the frame center without moving the frame", async () => {
  const source = await create({ flipHorizontal: true, flipVertical: true });
  const glyph = source.contours[0],
    frame = source.contours[2];
  if (glyph.type !== "path" || frame.type !== "path") throw Error();
  expect(source.textItems![0].flipAboutFrame).toBe(true);
  expect(glyph.start).toEqual([8, 10]);
  expect(glyph.segments[0].end).toEqual([2, 10]);
  expect(frame.start).toEqual([0, 0]);
  expect(frame.segments[1].end).toEqual([8, 10]);
  const resized = resizeSketchTextFrame(
    source,
    source.textItems![0].id,
    24,
    20,
  );
  const large = resized.contours[0];
  if (large.type !== "path") throw Error();
  expect(large.start).toEqual([24, 20]);
  expect(large.segments[0].end).toEqual([12, 20]);
});
it("updates the reflection center when a driving frame width changes", async () => {
  const source = await create({ flipHorizontal: true });
  source.constraints = [
    {
      id: "anchor",
      kind: "fix",
      a: { contour: 2, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "horizontal",
      kind: "horizontal",
      a: { contour: 2, kind: "line", index: 0 },
    },
    {
      id: "height",
      kind: "length",
      a: { contour: 2, kind: "line", index: 1 },
      value: 10,
    },
    {
      id: "width",
      kind: "length",
      a: { contour: 2, kind: "line", index: 0 },
      value: 8,
    },
  ];
  const wider = editDrawingDimension(source, "width", 12);
  const glyph = wider.contours[0];
  if (glyph.type !== "path") throw Error();
  expect(glyph.start[0]).toBeCloseTo(12);
  expect(glyph.segments[0].end[0]).toBeCloseTo(6);
  expect(wider.textItems![0].emSizeMillimeters).toBeCloseTo(10);
});
it("persists the flip mode and regenerates reflected multiline text after native reopening", async () => {
  const source = await create({
    text: "O\nO",
    flipHorizontal: true,
    rotationDegrees: 90,
  });
  const doc = createEmptyPartDocument("Frame flips");
  doc.features.push({
    id: "s",
    name: "Text",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: source,
  });
  const feature = parsePartDocument(serializePartDocument(doc)).features[0];
  if (feature.type !== "profile" || feature.profile.type !== "drawing")
    throw Error();
  const updated = await putSketchText(feature.profile, {
    ...options,
    id: source.textItems![0].id,
    text: "OO\nO",
    flipHorizontal: true,
    rotationDegrees: 90,
  });
  expect(updated.textItems![0].flipAboutFrame).toBe(true);
  const glyph = updated.contours.find(
    (c) => c.id === updated.textItems![0].contourIds[0],
  )!;
  if (glyph.type !== "path") throw Error();
  expect(glyph.start[0]).toBeCloseTo(0);
  expect(glyph.start[1]).toBeCloseTo(8);
});
it("preserves legacy baseline-axis flips when the mode field is absent", async () => {
  const legacy = await create({ flipHorizontal: true, flipAboutFrame: false });
  delete legacy.textItems![0].flipAboutFrame;
  const updated = await putSketchText(legacy, {
    ...options,
    id: legacy.textItems![0].id,
    text: "OO",
    flipHorizontal: true,
  });
  expect(updated.textItems![0].flipAboutFrame).toBe(false);
  const glyph = updated.contours.find(
    (c) => c.id === updated.textItems![0].contourIds[0],
  )!;
  if (glyph.type !== "path") throw Error();
  expect(glyph.start).toEqual([0, 0]);
  expect(glyph.segments[0].end).toEqual([-6, 0]);
});
