import { beforeAll, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { Font, Glyph, Path } from "opentype.js";
import init from "replicad-opencascadejs";
import { setOC } from "replicad";
import { evaluatePartDocument } from "./part-evaluator";
import { sketchTextOutline } from "../sketch/text/outline";
import { createEmptyPartDocument } from "../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../document/part-serialization";
beforeAll(async () => {
  setOC(
    await (init as any)({
      wasmBinary: readFileSync(
        new URL(
          "../../node_modules/replicad-opencascadejs/src/replicad_single.wasm",
          import.meta.url,
        ),
      ),
    }),
  );
}, 30000);

/** Original glyphs with analytically known area; no external fonts or fixtures. */
function fontBytes() {
  const ring = new Path();
  ring.moveTo(0, 0);
  ring.lineTo(600, 0);
  ring.lineTo(600, 800);
  ring.lineTo(0, 800);
  ring.close();
  ring.moveTo(100, 100);
  ring.lineTo(100, 700);
  ring.lineTo(500, 700);
  ring.lineTo(500, 100);
  ring.close();
  const curved = new Path();
  curved.moveTo(0, 0);
  curved.lineTo(600, 0);
  curved.curveTo(600, 800, 0, 800, 0, 0);
  curved.close();
  return new Font({
    familyName: "Solid Test",
    styleName: "Regular",
    unitsPerEm: 1000,
    ascender: 800,
    descender: -200,
    glyphs: [
      new Glyph({ name: ".notdef", advanceWidth: 700, path: new Path() }),
      new Glyph({ name: "O", unicode: 79, advanceWidth: 700, path: ring }),
      new Glyph({ name: "C", unicode: 67, advanceWidth: 700, path: curved }),
    ],
  }).toArrayBuffer();
}

it.each(
  [
    { text: "O", em: 10, angle: 0, area: 24 },
    { text: "OO", em: 20, angle: 37, area: 192 },
    // Cubic arch area = 0.288 em², from integrating (x dy - y dx)/2.
    { text: "C", em: 10, angle: 90, area: 28.8 },
    { text: "OC", em: 10, angle: -25, area: 52.8 },
    { text: "OO", em: 20, angle: 37, area: 192, flipHorizontal: true },
    {
      text: "OC",
      em: 10,
      angle: -25,
      area: 52.8,
      flipHorizontal: true,
      flipVertical: true,
    },
  ].flatMap((test) =>
    (["new", "cut"] as const).map((operation) => ({
      flipHorizontal: false,
      flipVertical: false,
      ...test,
      operation,
    })),
  ),
)(
  "$operation extrudes native text $text at em $em and rotation $angle, flips $flipHorizontal/$flipVertical",
  async ({
    text,
    em,
    angle,
    area,
    operation,
    flipHorizontal,
    flipVertical,
  }) => {
    const doc = createEmptyPartDocument("Font solid");
    if (operation === "cut")
      doc.features.push(
        {
          id: "plate-profile",
          type: "profile",
          name: "Plate",
          plane: "XY",
          offsetMillimeters: 0,
          suppressed: false,
          profile: {
            type: "drawing",
            contours: [
              {
                type: "path",
                start: [-50, -50],
                segments: [
                  { type: "line", end: [50, -50] },
                  { type: "line", end: [50, 50] },
                  { type: "line", end: [-50, 50] },
                  { type: "line", end: [-50, -50] },
                ],
              },
            ],
          },
        },
        {
          id: "plate",
          type: "extrude",
          name: "Plate",
          profileFeatureId: "plate-profile",
          distanceMillimeters: 5,
          operation: "new",
          suppressed: false,
        },
      );
    const profile = await sketchTextOutline(fontBytes(), text, {
      emSizeMillimeters: em,
      originMillimeters: [12, -7],
      rotationDegrees: angle,
      flipHorizontal,
      flipVertical,
    });
    doc.features.push(
      {
        id: "text",
        type: "profile",
        name: "Letter outlines",
        plane: "XY",
        offsetMillimeters: 0,
        suppressed: false,
        profile,
      },
      {
        id: "extrude",
        type: "extrude",
        name: "Letters",
        profileFeatureId: "text",
        distanceMillimeters: 5,
        operation,
        suppressed: false,
      },
    );
    const saved = parsePartDocument(serializePartDocument(doc));
    const result = evaluatePartDocument(saved);
    expect(result.parts).toHaveLength(1);
    const { vertices, triangles } = result.parts[0];
    expect(triangles.length).toBeGreaterThan(0);
    const point = (i: number) => Array.from(vertices.slice(3 * i, 3 * i + 3));
    let volume = 0;
    const edges = new Map<string, number>();
    for (let i = 0; i < triangles.length; i += 3) {
      const [a, b, c] = [
        point(triangles[i]),
        point(triangles[i + 1]),
        point(triangles[i + 2]),
      ];
      volume +=
        (a[0] * (b[1] * c[2] - b[2] * c[1]) +
          a[1] * (b[2] * c[0] - b[0] * c[2]) +
          a[2] * (b[0] * c[1] - b[1] * c[0])) /
        6;
      for (const [u, v] of [
        [a, b],
        [b, c],
        [c, a],
      ]) {
        const key = [
          u.map((n) => n.toFixed(5)).join(","),
          v.map((n) => n.toFixed(5)).join(","),
        ]
          .sort()
          .join("/");
        edges.set(key, (edges.get(key) ?? 0) + 1);
      }
    }
    // Display tessellation approximates curved boundaries at 0.08 mm tolerance.
    expect(
      Math.abs(
        Math.abs(volume) - (operation === "cut" ? 50000 - area * 5 : area * 5),
      ) /
        (area * 5),
    ).toBeLessThan(0.03);
    expect([...edges.values()].every((count) => count === 2)).toBe(true);
    const zs = Array.from(vertices).filter((_, i) => i % 3 === 2);
    expect(Math.min(...zs)).toBeCloseTo(0);
    expect(Math.max(...zs)).toBeCloseTo(5);
  },
  30000,
);
