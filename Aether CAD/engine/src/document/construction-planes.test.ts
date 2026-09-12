import { describe, expect, it } from "vitest";
import { resolvePlaneFrame } from "./construction-planes";
import type { ConstructionPlaneFeature } from "./construction-planes";
import {
  createEmptyPartDocument,
  parsePartDocument,
  serializePartDocument,
  validatePartDocument,
} from "./index";

const plane = (overrides: Partial<ConstructionPlaneFeature>): ConstructionPlaneFeature => ({
  id: "p1",
  name: "Plane 1",
  type: "plane",
  plane: "XY",
  offsetMillimeters: 0,
  suppressed: false,
  ...overrides,
});

describe("construction plane definitions", () => {
  it("legacy planes resolve as principal plus offset", () => {
    expect(resolvePlaneFrame(plane({ plane: "XZ", offsetMillimeters: 25 }))).toEqual({
      originMillimeters: [0, -25, 0],
      normal: [0, -1, 0],
      xDirection: [1, 0, 0],
    });
  });

  it("offsets from an earlier plane feature, recursively", () => {
    const base = plane({ id: "base", offsetMillimeters: 5 });
    const derived = plane({
      id: "derived",
      name: "Plane 2",
      definition: {
        method: "offset",
        reference: { kind: "feature", featureId: "base" },
        distanceMillimeters: 7,
      },
    });
    expect(resolvePlaneFrame(derived, [base]).originMillimeters).toEqual([0, 0, 12]);
  });

  it("mid plane sits halfway between two parallel planes", () => {
    const a = plane({ id: "a", offsetMillimeters: 10 });
    const b = plane({ id: "b", offsetMillimeters: 30 });
    const mid = plane({
      id: "mid",
      name: "Mid",
      definition: {
        method: "mid",
        references: [
          { kind: "feature", featureId: "a" },
          { kind: "feature", featureId: "b" },
        ],
      },
    });
    expect(resolvePlaneFrame(mid, [a, b])).toEqual({
      originMillimeters: [0, 0, 20],
      normal: [0, 0, 1],
      xDirection: [1, 0, 0],
    });
  });

  it("flip negates the resolved normal", () => {
    const flipped = plane({
      definition: {
        method: "offset",
        reference: { kind: "principal", plane: "XY" },
        distanceMillimeters: 5,
        flip: true,
      },
    });
    expect(resolvePlaneFrame(flipped, [])).toMatchObject({
      originMillimeters: [0, 0, 5],
      normal: [-0, -0, -1],
    });
  });

  it("rejects a mid plane between non-parallel planes", () => {
    const mid = plane({
      id: "mid",
      name: "Mid",
      definition: {
        method: "mid",
        references: [
          { kind: "principal", plane: "XY" },
          { kind: "principal", plane: "XZ" },
        ],
      },
    });
    expect(() => resolvePlaneFrame(mid, [])).toThrow(/parallel/);
  });

  it("validation rejects references to missing or later planes and round-trips definitions", () => {
    const doc = createEmptyPartDocument("Planes");
    doc.features.push(
      plane({
        id: "orphan",
        definition: {
          method: "offset",
          reference: { kind: "feature", featureId: "nope" },
          distanceMillimeters: 5,
        },
      }),
    );
    expect(() => validatePartDocument(doc)).toThrow(/earlier construction planes/);
    doc.features.length = 0;
    doc.features.push(
      plane({ id: "base" }),
      plane({
        id: "mid",
        name: "Plane 2",
        definition: {
          method: "mid",
          references: [
            { kind: "feature", featureId: "base" },
            { kind: "principal", plane: "XY" },
          ],
        },
      }),
    );
    validatePartDocument(doc);
    const reopened = parsePartDocument(serializePartDocument(doc));
    expect(reopened.features[1]).toMatchObject({
      definition: { method: "mid" },
    });
  });
});
