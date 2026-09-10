import { expect, it } from "vitest";
import { importDxfSketch } from "./index";
import { createEmptyPartDocument } from "../../../document/part-document";
import {
  serializePartDocument,
  parsePartDocument,
} from "../../../document/part-serialization";
import { validateSketchDrawing } from "../../drawing";
const line = (layer: string, x: number) =>
  `0\nLINE\n8\n${layer}\n10\n${x}\n20\n0\n11\n${x + 5}\n21\n0\n`;
const wrap = (entities: string) =>
  `0\nSECTION\n2\nENTITIES\n${entities}0\nENDSEC\n0\nEOF`;
it("keeps layer provenance through native persistence and avoids joining across layers", () => {
  const drawing = importDxfSketch(
    wrap(line("Parts", 0) + line("Reference", 5) + line("Reference", 10)),
    1,
  ).drawing;
  expect(drawing.contours).toHaveLength(2);
  expect(drawing.contours.map((c) => c.sourceLayer)).toEqual([
    "Parts",
    "Reference",
  ]);
  const doc = createEmptyPartDocument("Layers");
  doc.features.push({
    id: "import",
    name: "Import",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: drawing,
  });
  const reopened = parsePartDocument(serializePartDocument(doc));
  expect(reopened.features[0]).toEqual(doc.features[0]);
});
it("rejects malformed source layer metadata", () => {
  expect(() =>
    validateSketchDrawing({
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 1, sourceLayer: "" },
      ],
    }),
  ).toThrow(/Source layer/);
});
