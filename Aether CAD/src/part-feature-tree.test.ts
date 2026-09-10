import { describe, expect, it } from "vitest";
import { createRectanglePartDocument } from "./part-document";
import { buildPartFeatureTree } from "./part-feature-tree";

describe("Part feature tree", () => {
  it("projects Sketch, Extrude, and Body rows in history order", () => {
    const document = createRectanglePartDocument(
      "Bracket",
      { widthMillimeters: 60, heightMillimeters: 40, depthMillimeters: 12 },
      { documentId: "part-1", sketchId: "sketch-1", extrudeId: "extrude-1" },
    );
    const tree = buildPartFeatureTree(document);
    expect(tree.children.map((item) => item.kind)).toEqual([
      "sketch",
      "extrude",
      "body",
    ]);
    expect(tree.children[0].detail).toBe("XY · 60 × 40 mm · Fully defined");
  });
});
