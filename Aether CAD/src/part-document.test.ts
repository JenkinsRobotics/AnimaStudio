import { describe, expect, it } from "vitest";
import {
  createRectanglePartDocument,
  rectanglePartParameters,
  reviseRectanglePartDocument,
  validatePartDocument,
} from "./part-document";
import { sketchDefinitionState } from "./sketch-constraints";
import { parsePartDocument, serializePartDocument } from "./part-file";

const ids = {
  documentId: "part-document-1",
  sketchId: "sketch-1",
  extrudeId: "extrude-1",
};

describe("Part document", () => {
  it("creates a deterministic rectangle Sketch to Extrude history", () => {
    const document = createRectanglePartDocument(
      "Bracket",
      { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 12 },
      ids,
    );
    expect(document.features.map((feature) => feature.type)).toEqual([
      "sketch",
      "extrude",
    ]);
    expect(rectanglePartParameters(document)).toEqual({
      widthMillimeters: 60,
      heightMillimeters: 40,
      depthMillimeters: 12,
    });
    const sketch = document.features.find((feature) => feature.type === "sketch");
    expect(sketch && sketchDefinitionState(sketch).fullyDefined).toBe(true);
  });

  it("round-trips the editable history without losing stable IDs", () => {
    const original = createRectanglePartDocument(
      "Bracket",
      { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 12 },
      ids,
    );
    const reopened = parsePartDocument(serializePartDocument(original));
    expect(reopened).toEqual(original);
    expect(serializePartDocument(reopened)).toBe(serializePartDocument(original));
  });

  it("opens the provisional format identity and migrates it to Aether", () => {
    const original = createRectanglePartDocument(
      "Legacy Bracket",
      { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 12 },
      ids,
    );
    const legacy = JSON.stringify({ ...original, format: "open-cad-part" });

    const migrated = parsePartDocument(legacy);

    expect(migrated.format).toBe("aether-part");
    expect(JSON.parse(serializePartDocument(migrated)).format).toBe("aether-part");
  });

  it("migrates a v1 rectangle profile into structured constraints and dimensions", () => {
    const legacy = {
      format: "aether-part",
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
    };

    const migrated = parsePartDocument(JSON.stringify(legacy));
    const sketch = migrated.features.find((feature) => feature.type === "sketch");

    expect(migrated.formatVersion).toBe(3);
    expect(sketch?.constraints.map((constraint) => constraint.type)).toEqual([
      "horizontal",
      "vertical",
      "coincident-origin",
    ]);
    expect(sketch?.dimensions.map((dimension) => dimension.type)).toEqual([
      "width",
      "height",
    ]);
    expect(sketch && sketchDefinitionState(sketch).fullyDefined).toBe(true);
  });

  it("keeps document and feature IDs while parameters are revised", () => {
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
    expect(revised.documentId).toBe(ids.documentId);
    expect(revised.features.map((feature) => feature.id)).toEqual([
      ids.sketchId,
      ids.extrudeId,
    ]);
    expect(revised.name).toBe("Long Bracket");
  });

  it("rejects an Extrude that references a missing or later Sketch", () => {
    const document = createRectanglePartDocument(
      "Bracket",
      { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 12 },
      ids,
    );
    const invalid = { ...document, features: [...document.features].reverse() };
    expect(() => validatePartDocument(invalid)).toThrow(
      "Extrude must reference an earlier Sketch",
    );
  });
});
