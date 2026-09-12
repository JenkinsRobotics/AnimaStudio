import { expect, it } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { putSketchText, detachSketchText, sketchTextEditState } from "./edit";
import { validateSketchDrawing, type SketchDrawing } from "../drawing";
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
const options = () => ({
  text: "O",
  fontBytes: fontBytes(),
  emSizeMillimeters: 10,
  originMillimeters: [12, 15] as [number, number],
  rotationDegrees: 30,
  flipHorizontal: true,
});
it("retains font and text through native save/reopen and regenerates without the font file", async () => {
  const source: SketchDrawing = { type: "drawing", contours: [] };
  const created = await putSketchText(source, options());
  expect(source.contours).toEqual([]);
  expect(created.textItems).toHaveLength(1);
  const doc = createEmptyPartDocument("Retained text");
  doc.features.push({
    id: "s",
    type: "profile",
    name: "Text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: created,
  });
  const reopened = parsePartDocument(serializePartDocument(doc));
  const feature = reopened.features[0];
  if (feature.type !== "profile" || feature.profile.type !== "drawing")
    throw Error();
  const drawing = feature.profile,
    id = drawing.textItems![0].id;
  expect(await sketchTextEditState(drawing, id)).toBe("editable");
  const changed = await putSketchText(drawing, {
    ...options(),
    fontBytes: undefined,
    id,
    text: "OO",
    emSizeMillimeters: 20,
  });
  expect(changed.contours).toHaveLength(4);
  expect(changed.contours.filter((c) => c.hole)).toHaveLength(2);
  expect(changed.textItems![0].id).toBe(id);
  expect(changed.textItems![0].text).toBe("OO");
  expect(changed.textItems![0].flipHorizontal).toBe(true);
  expect(await sketchTextEditState(changed, id)).toBe("editable");
});
it("remaps unrelated constraints when replacement changes the contour count", async () => {
  const created = await putSketchText(
    { type: "drawing", contours: [] },
    options(),
  );
  created.contours.push({ type: "circle", center: [100, 0], radius: 3 });
  created.constraints = [
    { id: "r", kind: "radius", a: { contour: 2, kind: "circle" }, value: 3 },
  ];
  const changed = await putSketchText(created, {
    ...options(),
    id: created.textItems![0].id,
    text: "OO",
  });
  expect(changed.constraints![0].a.contour).toBe(0);
  expect(changed.contours[0]).toMatchObject({ type: "circle", radius: 3 });
  expect(created.constraints[0].a.contour).toBe(2);
});
it("refuses to overwrite manual outline edits or constraints and supports detachment", async () => {
  const created = await putSketchText(
    { type: "drawing", contours: [] },
    options(),
  );
  const id = created.textItems![0].id;
  const constrained = structuredClone(created);
  constrained.constraints = [
    {
      id: "anchor",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0 },
      point: [12, 15],
    },
  ];
  expect(await sketchTextEditState(constrained, id)).toBe("constrained");
  await expect(
    putSketchText(constrained, { ...options(), id }),
  ).rejects.toThrow(/constraints/);
  const modified = structuredClone(created);
  modified.contours.pop();
  expect(await sketchTextEditState(modified, id)).toBe("modified");
  await expect(putSketchText(modified, { ...options(), id })).rejects.toThrow(
    /edited/,
  );
  const detached = detachSketchText(modified, id);
  expect(detached.textItems).toEqual([]);
  expect(detached.contours).toEqual(modified.contours);
});
it("rejects invalid retained metadata and keeps failed regeneration atomic", async () => {
  const created = await putSketchText(
    { type: "drawing", contours: [] },
    options(),
  );
  const before = JSON.stringify(created),
    id = created.textItems![0].id;
  await expect(
    putSketchText(created, { ...options(), id, text: "X" }),
  ).rejects.toThrow(/glyph/);
  expect(JSON.stringify(created)).toBe(before);
  const invalid = structuredClone(created);
  invalid.textItems![0].fontBase64 = "bad!";
  expect(() => validateSketchDrawing(invalid)).toThrow(/font data/);
  invalid.textItems = [created.textItems![0], created.textItems![0]];
  expect(() => validateSketchDrawing(invalid)).toThrow(/unique/);
});
