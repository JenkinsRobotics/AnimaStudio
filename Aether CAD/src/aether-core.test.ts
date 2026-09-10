import { describe, expect, it } from "vitest";
import {
  createRectanglePartDocument,
  parsePartDocument,
  serializePartDocument,
} from "./aether-core";

describe("Aether Core application facade", () => {
  it("preserves deterministic Part semantics through the public boundary", () => {
    const part = createRectanglePartDocument("Facade Bracket", {
      widthMillimeters: 80,
      heightMillimeters: 45,
      depthMillimeters: 12,
    });

    const serialized = serializePartDocument(part);
    const reopened = parsePartDocument(serialized);

    expect(reopened).toEqual(part);
    expect(serializePartDocument(reopened)).toBe(serialized);
  });
});
