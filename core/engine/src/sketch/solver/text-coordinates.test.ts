import { expect, it } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { putSketchText, sketchTextEditState } from "../text/edit";
import { textOutlineDigest } from "../text/digest";
import { solveDrawingConstraints } from "./solve";
import { sketchConstraintState } from "./diagnostics";
import { editDrawingDimension } from "../operations/edit-dimension";
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

const create = () =>
  putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: fontBytes(),
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
    },
  );
it("counts retained text as four geometric degrees of freedom", async () => {
  const text = await create();
  expect(sketchConstraintState(text)).toMatchObject({
    state: "under-constrained",
    degreesOfFreedom: 4,
  });
});
it("drives uniform text dimensions, preserving the hole, metadata and native reopening", async () => {
  const text = await create();
  text.constraints = [
    {
      id: "anchor",
      kind: "fix",
      a: { contour: 0, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "baseline",
      kind: "horizontal",
      a: { contour: 0, kind: "line", index: 0 },
    },
    {
      id: "width",
      kind: "length",
      a: { contour: 0, kind: "line", index: 0 },
      value: 6,
    },
  ];
  expect(sketchConstraintState(text)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
  const resized = editDrawingDimension(text, "width", 12);
  expect(resized.textItems![0].emSizeMillimeters).toBeCloseTo(20);
  const outer = resized.contours[0],
    hole = resized.contours[1];
  if (outer.type !== "path" || hole.type !== "path") throw Error();
  expect(outer.segments[1].end[1]).toBeCloseTo(16);
  expect(hole.start[0]).toBeCloseTo(2);
  expect(hole.start[1]).toBeCloseTo(2);
  expect(hole.hole).toBe(true);
  expect(await sketchTextEditState(resized, resized.textItems![0].id)).toBe(
    "constrained",
  );
  const doc = createEmptyPartDocument("Dimensioned text");
  doc.features.push({
    id: "text",
    type: "profile",
    name: "Text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: resized,
  });
  const saved = parsePartDocument(serializePartDocument(doc));
  const feature = saved.features[0];
  if (feature.type !== "profile" || feature.profile.type !== "drawing")
    throw Error();
  expect(sketchConstraintState(feature.profile)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
  expect(text.textItems![0].emSizeMillimeters).toBe(10);
});
it("rejects conflicting aspect-ratio dimensions instead of deforming letters", async () => {
  const text = await create();
  text.constraints = [
    {
      id: "width",
      kind: "length",
      a: { contour: 0, kind: "line", index: 0 },
      value: 12,
    },
    {
      id: "height",
      kind: "length",
      a: { contour: 0, kind: "line", index: 1 },
      value: 8,
    },
  ];
  expect(() => solveDrawingConstraints(text)).toThrow(/conflict|converge/);
  expect(text.textItems![0].emSizeMillimeters).toBe(10);
});
it("preserves compatibility with existing WebCrypto outline digests", async () => {
  const text = await create();
  const json = JSON.stringify(text.contours, (key, value) =>
    ["id", "startVertexId", "endVertexId", "sourceLayer"].includes(key)
      ? undefined
      : value,
  );
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(json),
  );
  expect(textOutlineDigest(text.contours)).toBe(
    Array.from(new Uint8Array(hash), (b) =>
      b.toString(16).padStart(2, "0"),
    ).join(""),
  );
});
