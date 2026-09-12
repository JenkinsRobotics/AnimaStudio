import { expect, it } from "vitest";
import { createEmptyPartDocument, type ProfileFeature } from "./part-document";
import { parsePartDocument, serializePartDocument } from "./part-serialization";
import { referenceProfileContour } from "./profile-contour-reference";
import { resolveProfileDrawing } from "./profile-projection";
import { linearPattern } from "../sketch/operations/pattern";
import { offsetSketch } from "../sketch/operations/offset";
import {
  moveSketchContours,
  similarityTransform,
} from "../sketch/operations/transform";
import { validateSketchDrawing, type SketchDrawing } from "../sketch/drawing";
const make = () => {
  const doc = createEmptyPartDocument("Contour references");
  doc.features.push({
    id: "source",
    type: "profile",
    name: "Source",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 2 },
        { type: "circle", center: [10, 0], radius: 4 },
      ],
    },
  });
  return doc;
};
it("assigns source identity transactionally and follows edits/reordering across native save", () => {
  const original = make(),
    linked = referenceProfileContour(original, "source", 1, () => "selected");
  expect((original.features[0] as ProfileFeature).profile).not.toEqual(
    (linked.document.features[0] as ProfileFeature).profile,
  );
  const again = referenceProfileContour(linked.document, "source", 1, () => {
    throw Error("must reuse identity");
  });
  expect(again.reference).toEqual(linked.reference);
  linked.document.features.push({
    id: "projection",
    type: "profile",
    name: "Projection",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: { type: "projection", ...linked.reference },
  });
  const saved = parsePartDocument(serializePartDocument(linked.document)),
    source = saved.features[0] as ProfileFeature;
  if (source.profile.type !== "drawing") throw Error();
  source.profile.contours.reverse();
  const selected = source.profile.contours[0];
  if (selected.type !== "circle") throw Error();
  selected.radius = 7;
  const output = resolveProfileDrawing(saved.features, "projection");
  expect(output.contours).toHaveLength(1);
  expect(output.contours[0]).toMatchObject({
    id: "selected",
    radius: 7,
    center: [10, 0],
  });
  source.profile.contours.shift();
  const broken = parsePartDocument(serializePartDocument(saved));
  expect(() => resolveProfileDrawing(broken.features, "projection")).toThrow(
    "Broken projection contour reference",
  );
});
it("does not clone identity into patterns/offsets and retains identity for a move", () => {
  const linked = referenceProfileContour(make(), "source", 0, () => "original"),
    profile = (linked.document.features[0] as ProfileFeature).profile;
  if (profile.type !== "drawing") throw Error();
  const pattern = linearPattern(profile, [0], [20, 0], 2);
  expect(pattern.contours.map((c) => c.id)).toEqual([
    "original",
    undefined,
    undefined,
  ]);
  const offset = offsetSketch(profile, [0], 1);
  expect(offset.contours[0].id).toBe("original");
  expect(offset.contours.at(-1)!.id).toBeUndefined();
  const moved = moveSketchContours(
    profile,
    [0],
    similarityTransform([0, 0], [3, 5], 0),
  );
  expect(moved.contours[0].id).toBe("original");
});
it("rejects identity collisions rather than allowing ambiguous references", () => {
  const d: SketchDrawing = {
    type: "drawing",
    contours: [
      { type: "circle", id: "same", center: [0, 0], radius: 1 },
      { type: "circle", id: "same", center: [4, 0], radius: 1 },
    ],
  };
  expect(() => validateSketchDrawing(d)).toThrow("identities");
  expect(() => referenceProfileContour(make(), "source", 0, () => "")).toThrow(
    "identities",
  );
});

it("adds missing subentity IDs even when the selected contour already has an ID", () => {
  const d = make(),
    feature = d.features[0] as ProfileFeature;
  feature.profile = {
    type: "drawing",
    contours: [
      {
        type: "path",
        id: "existing",
        start: [0, 0],
        segments: [{ type: "line", end: [10, 0] }],
      },
    ],
  };
  let i = 0;
  const linked = referenceProfileContour(d, "source", 0, () => `sub-${++i}`),
    path = resolveProfileDrawing(linked.document.features, "source")
      .contours[0];
  if (path.type !== "path") throw Error();
  expect(linked.reference.sourceContourId).toBe("existing");
  expect(path.startVertexId).toBeTruthy();
  expect(path.segments[0].id).toBeTruthy();
  expect(path.segments[0].endVertexId).toBeTruthy();
  const saved = parsePartDocument(serializePartDocument(linked.document));
  expect(
    referenceProfileContour(saved, "source", 0, () => {
      throw Error("reuse");
    }).document,
  ).toEqual(saved);
  expect(feature.profile.contours[0]).not.toEqual(path);
});
it("selects a derived contour and identifies its authored upstream geometry atomically", () => {
  const d = make();
  d.features.push({
    id: "derived",
    type: "profile",
    name: "Derived",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: { type: "projection", sourceFeatureId: "source" },
  });
  let i = 0;
  const linked = referenceProfileContour(d, "derived", 1, () => `chain-${++i}`);
  expect(linked.reference).toEqual({
    sourceFeatureId: "derived",
    sourceContourId: "chain-2",
  });
  expect(
    resolveProfileDrawing(linked.document.features, "derived").contours[1].id,
  ).toBe("chain-2");
  expect(
    resolveProfileDrawing(d.features, "source").contours[1].id,
  ).toBeUndefined();
});
