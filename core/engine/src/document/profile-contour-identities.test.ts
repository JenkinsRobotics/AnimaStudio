import { expect, it } from "vitest";
import { createEmptyPartDocument, type ProfileFeature } from "./part-document";
import { identifyProfileContours } from "./profile-contour-identities";
import { resolveProfileDrawing } from "./profile-projection";
import { serializePartDocument, parsePartDocument } from "./part-serialization";
it("assigns missing IDs through a mixed projection chain without changing the input", () => {
  const d = createEmptyPartDocument("Identities");
  d.features.push(
    {
      id: "source",
      name: "Source",
      type: "profile",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: {
        type: "circle",
        centerMillimeters: [0, 0],
        radiusMillimeters: 5,
      },
    },
    {
      id: "mixed",
      name: "Mixed",
      type: "profile",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: {
        type: "projection",
        sourceFeatureId: "source",
        authored: {
          type: "drawing",
          contours: [
            { id: "kept", type: "circle", center: [20, 0], radius: 2 },
            { type: "circle", center: [30, 0], radius: 1 },
          ],
        },
      },
    },
  );
  const before = structuredClone(d);
  let i = 0;
  const next = identifyProfileContours(d, "mixed", () => `id-${++i}`);
  expect(
    resolveProfileDrawing(next.features, "mixed").contours.map((c) => c.id),
  ).toEqual(["id-1", "kept", "id-2"]);
  expect(d).toEqual(before);
  const saved = parsePartDocument(serializePartDocument(next));
  expect(
    identifyProfileContours(saved, "mixed", () => {
      throw Error("should reuse");
    }),
  ).toEqual(saved);
  const feature = saved.features[1] as ProfileFeature;
  if (feature.profile.type !== "projection") throw Error();
  feature.profile.authored!.contours.reverse();
  expect(
    resolveProfileDrawing(saved.features, "mixed").contours.map((c) => c.id),
  ).toEqual(["id-1", "id-2", "kept"]);
});
it("rejects duplicate generated identities without mutating the source", () => {
  const d = createEmptyPartDocument("Duplicates");
  d.features.push({
    id: "source",
    name: "Source",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 2 },
        { type: "circle", center: [10, 0], radius: 3 },
      ],
    },
  });
  const before = structuredClone(d);
  expect(() => identifyProfileContours(d, "source", () => "same")).toThrow();
  expect(d).toEqual(before);
});

it("assigns and persists shared seam and endpoint identities on authored paths", () => {
  const d = createEmptyPartDocument("Vertices");
  d.features.push({
    id: "source",
    name: "Source",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [0, 0],
          segments: [
            { type: "line", end: [10, 0] },
            { type: "line", end: [10, 10] },
            { type: "line", end: [0, 0] },
          ],
        },
      ],
    },
  });
  let i = 0;
  const next = identifyProfileContours(d, "source", () => `vertex-test-${++i}`);
  const path = resolveProfileDrawing(next.features, "source").contours[0];
  if (path.type !== "path") throw Error();
  expect(path.startVertexId).toBeDefined();
  expect(path.segments[2].endVertexId).toBe(path.startVertexId);
  expect(path.segments[0].endVertexId).not.toBe(path.startVertexId);
  const saved = parsePartDocument(serializePartDocument(next));
  expect(
    identifyProfileContours(saved, "source", () => {
      throw Error("must reuse IDs");
    }),
  ).toEqual(saved);
  expect(d.features[0]).not.toEqual(next.features[0]);
});
