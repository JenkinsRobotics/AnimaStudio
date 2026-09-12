import { it, expect } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { putSketchText } from "./edit";
import { attachSketchTextFrame } from "./frame";
import { removeDrawingConstraint } from "../operations/edit-dimension";
import { sketchConstraintState } from "../solver/diagnostics";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
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
it("creates one horizontal baseline relation and preserves its identity on rewording", async () => {
  const source = await putSketchText(
    { type: "drawing", contours: [] },
    { ...options, fontBytes: fontBytes() },
  );
  expect(source.constraints).toHaveLength(1);
  expect(source.constraints![0].kind).toBe("horizontal");
  expect(sketchConstraintState(source).degreesOfFreedom).toBe(4);
  const next = await putSketchText(source, {
    ...options,
    id: source.textItems![0].id,
    text: "OO",
  });
  expect(next.constraints).toHaveLength(1);
  expect(next.constraints![0].id).toBe(source.constraints![0].id);
  expect(next.contours[next.constraints![0].a.contour].id).toBe(
    next.textItems![0].frameContourId,
  );
});
it("does not restore a removed baseline constraint when rotating and reopening text", async () => {
  const source = await putSketchText(
    { type: "drawing", contours: [] },
    { ...options, fontBytes: fontBytes() },
  );
  const free = removeDrawingConstraint(source, source.constraints![0].id);
  const rotated = await putSketchText(free, {
    ...options,
    id: source.textItems![0].id,
    rotationDegrees: 37,
  });
  expect(rotated.constraints).toEqual([]);
  expect(rotated.textItems![0].rotationDegrees).toBe(37);
  const doc = createEmptyPartDocument("Rotated text");
  doc.features.push({
    id: "s",
    type: "profile",
    name: "Text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: rotated,
  });
  const feature = parsePartDocument(serializePartDocument(doc)).features[0];
  if (feature.type !== "profile" || feature.profile.type !== "drawing")
    throw Error();
  const updated = await putSketchText(feature.profile, {
    ...options,
    id: source.textItems![0].id,
    text: "OO",
    rotationDegrees: 37,
  });
  expect(updated.constraints).toEqual([]);
  expect(updated.textItems![0].rotationDegrees).toBe(37);
});
it("does not force rotated frames horizontal or add redundant constraints to existing constrained letters", async () => {
  const rotated = await putSketchText(
    { type: "drawing", contours: [] },
    { ...options, fontBytes: fontBytes(), rotationDegrees: 30 },
  );
  expect(rotated.constraints).toBeUndefined();
  const letters = await putSketchText(
    { type: "drawing", contours: [] },
    { ...options, frameWidthMillimeters: undefined, fontBytes: fontBytes() },
  );
  letters.constraints = [
    {
      id: "letter-base",
      kind: "horizontal",
      a: { contour: 0, kind: "line", index: 0 },
    },
  ];
  const framed = attachSketchTextFrame(letters, letters.textItems![0].id, 8);
  expect(framed.constraints).toEqual(letters.constraints);
});
