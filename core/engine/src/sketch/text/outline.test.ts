import { expect, it } from "vitest";
import { Font, Glyph, Path } from "opentype.js";
import { fontPathContours, sketchTextOutline } from "./outline";

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
it("converts quadratic curves exactly and flips font coordinates", () => {
  const drawing = fontPathContours([
    { type: "M", x: 0, y: 0 },
    { type: "Q", x1: 3, y1: 6, x: 6, y: 0 },
    { type: "Z" },
  ]);
  expect(drawing.contours[0]).toMatchObject({
    type: "path",
    segments: [
      {
        type: "bezier",
        controls: [
          [2, -4],
          [4, -4],
        ],
        end: [6, -0],
      },
      { type: "line", end: [0, -0] },
    ],
  });
});
it("preserves cubic control points", () => {
  expect(
    fontPathContours([
      { type: "M", x: 0, y: 0 },
      { type: "C", x1: 1, y1: 2, x2: 3, y2: 4, x: 5, y: 6 },
      { type: "Z" },
    ]).contours[0],
  ).toMatchObject({
    segments: [
      {
        controls: [
          [1, -2],
          [3, -4],
        ],
        end: [5, -6],
      },
      { end: [0, -0] },
    ],
  });
});
it("rejects incomplete contours", () => {
  expect(() => fontPathContours([{ type: "L", x: 0, y: 0 }])).toThrow(
    /starting point/,
  );
  expect(() => fontPathContours([{ type: "Z" }])).toThrow(/missing/);
});
it("loads a serialized font and retains holes, scale, rotation and baseline placement", async () => {
  const drawing = await sketchTextOutline(fontBytes(), "OO", {
    emSizeMillimeters: 10,
    originMillimeters: [20, 30],
    rotationDegrees: 90,
  });
  expect(drawing.contours).toHaveLength(4);
  expect(drawing.contours.filter((c) => c.hole)).toHaveLength(2);
  const points = drawing.contours.flatMap((c) =>
    c.type === "path" ? [c.start, ...c.segments.map((s) => s.end)] : [],
  );
  expect(Math.min(...points.map((p) => p[0]))).toBeCloseTo(12);
  expect(Math.max(...points.map((p) => p[0]))).toBeCloseTo(20);
  expect(Math.min(...points.map((p) => p[1]))).toBeCloseTo(30);
  expect(Math.max(...points.map((p) => p[1]))).toBeCloseTo(43);
});
it("rejects missing glyphs and invalid authoring inputs", async () => {
  await expect(
    sketchTextOutline(fontBytes(), "X", { emSizeMillimeters: 10 }),
  ).rejects.toThrow(/glyph/);
  await expect(
    sketchTextOutline(fontBytes(), "O", { emSizeMillimeters: 0 }),
  ).rejects.toThrow(/positive/);
  await expect(
    sketchTextOutline(fontBytes(), "\tO", { emSizeMillimeters: 10 }),
  ).rejects.toThrow(/tabs/);
  await expect(
    sketchTextOutline(new ArrayBuffer(0), "O", { emSizeMillimeters: 10 }),
  ).rejects.toThrow(/Font data/);
});
