import { expect, it } from "vitest";
import { createWheelExample } from "./wheel-example";
import {
  insertFeature,
  moveFeature,
  removeFeature,
  setFeatureSuppressed,
  availableBodies,
} from "./feature-history";
import {
  createRectanglePartDocument,
  reviseRectanglePartDocument,
} from "./part-document";
import { parsePartDocument, serializePartDocument } from "./part-serialization";
it("inserts at rollback and retains the future history across serialization", () => {
  const doc = { ...createWheelExample(), rollbackIndex: 2 };
  const next = insertFeature(doc, {
    id: "round",
    name: "Round flange",
    type: "fillet",
    radiusMillimeters: 0.5,
    suppressed: false,
  });
  expect(next.rollbackIndex).toBe(3);
  expect(next.features[3].id).toBe(doc.features[2].id);
  expect(next.features).toHaveLength(doc.features.length + 1);
  expect(parsePartDocument(serializePartDocument(next))).toEqual(next);
});
it("prevents feature order from breaking sketch references", () => {
  const doc = createWheelExample();
  expect(() => moveFeature(doc, "revolve", -1)).toThrow(/earlier sketch/i);
});
it("suppresses descendants, restores prerequisites and safely deletes dependencies", () => {
  const doc = createWheelExample();
  const off = setFeatureSuppressed(doc, "hole", true);
  for (const f of off.features.filter((f) =>
    ["hole", "hole-cut", "mirror-x", "mirror-y", "mirror-xy"].includes(f.id),
  ))
    expect(f.suppressed).toBe(true);
  expect(off.features.find((f) => f.id === "revolve")?.suppressed).toBe(false);
  const on = setFeatureSuppressed(off, "mirror-xy", false);
  expect(on.features.find((f) => f.id === "hole")?.suppressed).toBe(false);
  expect(on.features.find((f) => f.id === "mirror-y")?.suppressed).toBe(true);
  const removed = removeFeature({ ...doc, rollbackIndex: 10 }, "hole");
  expect(removed.features.some((f) => f.id === "mirror-xy")).toBe(false);
  expect(removed.rollbackIndex).toBe(6);
});
it("rectangle parameter edits retain downstream features and empty rollback has no phantom bodies", () => {
  const doc = createRectanglePartDocument("Bracket", {
    widthMillimeters: 20,
    heightMillimeters: 10,
    depthMillimeters: 5,
  });
  doc.features.push({
    id: "finish",
    name: "Finish",
    type: "fillet",
    radiusMillimeters: 0.5,
    suppressed: false,
  });
  const next = reviseRectanglePartDocument(doc, "Revised", {
    widthMillimeters: 30,
    heightMillimeters: 10,
    depthMillimeters: 5,
  });
  expect(next.features[2]).toEqual(doc.features[2]);
  expect(availableBodies({ ...next, rollbackIndex: 1 })).toEqual([]);
});
