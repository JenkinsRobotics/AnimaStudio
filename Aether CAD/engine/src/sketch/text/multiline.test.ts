import { it, expect } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { sketchTextOutline } from "./outline";
import { putSketchText } from "./edit";
import { resizeSketchTextFrame } from "./resize";
import { normalizeSketchText } from "./content";
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

it("lays out later lines below the first baseline, retaining blank lines and counters", async () => {
  const drawing = await sketchTextOutline(fontBytes(), "O\r\nO\n\nO", {
    emSizeMillimeters: 10,
  });
  expect(drawing.contours).toHaveLength(6);
  expect(drawing.contours.filter((c) => c.hole)).toHaveLength(3);
  const starts = drawing.contours
    .filter((c) => !c.hole)
    .map((c) => (c.type === "path" ? c.start : []));
  expect(starts[0][1]).toBeCloseTo(0);
  expect(starts[1][1]).toBeCloseTo(-10);
  expect(starts[2][1]).toBeCloseTo(-30);
});
it("retains multiline content with a first-line frame through native reopening and resizing", async () => {
  const source = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O\r\nO",
      fontBytes: fontBytes(),
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
      frameWidthMillimeters: 8,
    },
  );
  expect(source.textItems![0].text).toBe("O\nO");
  const doc = createEmptyPartDocument("Multiline text");
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
  const resized = resizeSketchTextFrame(
    feature.profile,
    source.textItems![0].id,
    8,
    20,
  );
  const frame = resized.contours.find(
    (c) => c.id === resized.textItems![0].frameContourId,
  )!;
  if (frame.type !== "path") throw Error();
  expect(frame.segments[1].end[1]).toBeCloseTo(20);
  const outlines = resized.contours.filter((c) => !c.hole && !c.construction);
  if (outlines[1].type !== "path") throw Error();
  expect(outlines[1].start[1]).toBeCloseTo(-20);
  const reworded = await putSketchText(resized, {
    id: source.textItems![0].id,
    text: "OO\nO",
    emSizeMillimeters: 20,
    originMillimeters: [0, 0],
  });
  expect(reworded.contours).toHaveLength(7);
  expect(reworded.textItems![0].frameContourId).toBe(
    source.textItems![0].frameContourId,
  );
});
it("normalizes newline conventions and rejects unsupported control characters", () => {
  expect(normalizeSketchText("O\rO\r\nO")).toBe("O\nO\nO");
  for (const value of ["\n\n", "O\tO", "O\u0000", 42, "O".repeat(1001)])
    expect(() => normalizeSketchText(value)).toThrow();
});
