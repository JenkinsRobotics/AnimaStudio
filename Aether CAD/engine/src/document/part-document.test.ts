import { describe, expect, it } from "vitest";
import { sketchDefinitionState } from "../sketch/index";
import {
  createRectanglePartDocument,
  parsePartDocument,
  rectanglePartParameters,
  reviseRectanglePartDocument,
  serializePartDocument,
} from "./index";

const ids = {
  documentId: "part-document-1",
  sketchId: "sketch-1",
  extrudeId: "extrude-1",
};

describe("canonical Part document", () => {
  it("round-trips deterministic history and stable IDs", () => {
    const original = createRectanglePartDocument(
      "Bracket",
      { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 12 },
      ids,
    );
    const serialized = serializePartDocument(original);
    const reopened = parsePartDocument(serialized);

    expect(reopened).toEqual(original);
    expect(serializePartDocument(reopened)).toBe(serialized);
    expect(rectanglePartParameters(reopened)).toEqual({
      widthMillimeters: 60,
      heightMillimeters: 40,
      depthMillimeters: 12,
    });
  });

  it("preserves identity when a feature parameter changes", () => {
    const original = createRectanglePartDocument(
      "Bracket",
      { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 12 },
      ids,
    );
    const revised = reviseRectanglePartDocument(original, "Long Bracket", {
      widthMillimeters: 90,
      heightMillimeters: 45,
      depthMillimeters: 16,
    });

    expect(revised.documentId).toBe(original.documentId);
    expect(revised.features.map((feature) => feature.id)).toEqual(
      original.features.map((feature) => feature.id),
    );
  });

  it("migrates legacy rectangle state into fully defined constraints", () => {
    const legacy = JSON.stringify({
      format: "open-cad-part",
      formatVersion: 1,
      documentId: ids.documentId,
      name: "Legacy Bracket",
      units: "millimeter",
      features: [
        {
          id: ids.sketchId,
          type: "sketch",
          name: "Sketch 1",
          plane: "XY",
          profile: {
            type: "center-rectangle",
            widthMillimeters: 60,
            heightMillimeters: 40,
          },
          suppressed: false,
        },
        {
          id: ids.extrudeId,
          type: "extrude",
          name: "Extrude 1",
          profileFeatureId: ids.sketchId,
          distanceMillimeters: 12,
          operation: "new",
          suppressed: false,
        },
      ],
    });
    const migrated = parsePartDocument(legacy);
    const sketch = migrated.features.find((feature) => feature.type === "sketch");

    expect(migrated.format).toBe("aether-part");
    expect(migrated.formatVersion).toBe(3);
    expect(sketch && sketchDefinitionState(sketch).fullyDefined).toBe(true);
  });
});
