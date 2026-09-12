import { expect, it } from "vitest";
import { createEmptyPartDocument, validatePartDocument } from "./part-document";
import { parsePartDocument, serializePartDocument } from "./part-serialization";
it("round-trips sketch label presentation without introducing geometry", () => {
  const doc = createEmptyPartDocument("Labels");
  doc.sketchPresentation = {
    sketch: { dimensionLabelPositionsMillimeters: { diameter: [12, -8] } },
  };
  const reopened = parsePartDocument(serializePartDocument(doc));
  expect(reopened.sketchPresentation).toEqual(doc.sketchPresentation);
  expect(reopened.features).toEqual([]);
});
it("rejects malformed and nonfinite label coordinates", () => {
  for (const metadata of [
    [],
    { sketch: {} },
    { sketch: { dimensionLabelPositionsMillimeters: { d: [NaN, 0] } } },
    { sketch: { dimensionLabelPositionsMillimeters: { d: [1] } } },
  ]) {
    const doc = {
      ...createEmptyPartDocument("Invalid"),
      sketchPresentation: metadata,
    };
    expect(() => validatePartDocument(doc)).toThrow();
  }
});
