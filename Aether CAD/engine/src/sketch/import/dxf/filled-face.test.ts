import { expect, it } from "vitest";
import { importDxfSketch } from "./index";
import { createEmptyPartDocument } from "../../../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../../../document/part-serialization";
const file = (type: string, points: number[][], extra = "") =>
  `0\nSECTION\n2\nENTITIES\n0\n${type}\n8\nProfile\n${points.map((p, i) => `${10 + i}\n${p[0]}\n${20 + i}\n${p[1]}\n`).join("")}${extra}0\nENDSEC\n0\nEOF`;
const quad = [
  [0, 0],
  [4, 0],
  [0, 3],
  [4, 3],
];
it.each(["SOLID", "TRACE"])(
  "imports %s strip order as an editable scaled closed boundary",
  (type) => {
    const result = importDxfSketch(file(type, quad), 2);
    expect(result.entityCount).toBe(1);
    expect(result.drawing.contours[0]).toMatchObject({
      type: "path",
      start: [0, 0],
      sourceLayer: "Profile",
      segments: [
        { type: "line", end: [8, 0] },
        { type: "line", end: [8, 6] },
        { type: "line", end: [0, 6] },
        { type: "line", end: [0, 0] },
      ],
    });
    const doc = createEmptyPartDocument("Filled face");
    doc.features.push({
      id: "sketch",
      name: "Imported",
      type: "profile",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: result.drawing,
    });
    expect(parsePartDocument(serializePartDocument(doc)).features[0]).toEqual(
      doc.features[0],
    );
  },
);
it("imports repeated-corner triangles and applies negative-Z object coordinates", () => {
  const p = importDxfSketch(
    file(
      "SOLID",
      [
        [1, 0],
        [4, 0],
        [1, 3],
        [1, 3],
      ],
      "230\n-1\n",
    ),
    1,
  ).drawing.contours[0];
  expect(p).toMatchObject({
    start: [-1, 0],
    segments: [{ end: [-4, 0] }, { end: [-1, 3] }, { end: [-1, 0] }],
  });
});
it("accepts simple concave boundaries and rejects crossing, collapsed and spatial faces", () => {
  expect(() =>
    importDxfSketch(
      file("SOLID", [
        [0, 0],
        [4, 0],
        [0, 4],
        [1, 1],
      ]),
      1,
    ),
  ).not.toThrow();
  expect(() =>
    importDxfSketch(
      file("SOLID", [
        [0, 0],
        [4, 3],
        [0, 3],
        [4, 0],
      ]),
      1,
    ),
  ).toThrow(/crossing/);
  expect(() =>
    importDxfSketch(
      file("TRACE", [
        [0, 0],
        [1, 0],
        [2, 0],
        [2, 0],
      ]),
      1,
    ),
  ).toThrow(/area/);
  for (const code of [30, 31, 32, 33, 39])
    expect(() =>
      importDxfSketch(file("SOLID", quad, `${code}\n1\n`), 1),
    ).toThrow(/non-planar/);
  expect(() => importDxfSketch(file("TRACE", quad, "210\n1\n"), 1)).toThrow(
    /tilted/,
  );
});
