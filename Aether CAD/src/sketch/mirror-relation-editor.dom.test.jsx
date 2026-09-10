import { createRequire } from "node:module";
import { beforeAll, afterAll, expect, it, vi } from "vitest";
import { mirrorSketchEntities } from "@aether/core/sketch";
import {
  createEmptyPartDocument,
  parsePartDocument,
  serializePartDocument,
} from "@aether/core/document";
import { mountMirrorRelationEditor } from "./mirror-relation-editor";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom;
beforeAll(() => {
  dom = new JSDOM("<main></main>");
  vi.stubGlobal("document", dom.window.document);
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
const click = (label) => {
  const button = [...document.querySelectorAll("button")].find(
    (b) => b.textContent === label,
  );
  expect(button).toBeTruthy();
  button.click();
};
it("preselects the stable saved axis after insertion and excludes the source edge", () => {
  let drawing = mirrorSketchEntities(
    {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [0, -5],
          segments: [
            { type: "line", id: "axis", end: [0, 5] },
            { type: "line", id: "source-edge", end: [4, 5] },
          ],
        },
      ],
    },
    [{ kind: "line", contour: 0, index: 1, segmentId: "source-edge" }],
    [0, 0],
    [0, 1],
    { kind: "line", contour: 0, index: 0 },
  );
  drawing.contours[0].start = [-5, -5];
  drawing.contours[0].segments.unshift({
    type: "line",
    id: "prefix",
    end: [0, -5],
  });
  const before = structuredClone(drawing),
    commit = vi.fn((next) => {
      drawing = next;
    }),
    report = vi.fn();
  mountMirrorRelationEditor(
    document.querySelector("main"),
    () => drawing,
    drawing.constraints[0],
    commit,
    report,
  );
  click("Edit mirror axis");
  let select = document.querySelector('[aria-label="Saved mirror axis"]');
  expect(JSON.parse(select.value)).toMatchObject({
    kind: "line",
    contour: 0,
    index: 1,
  });
  const refs = [...select.options]
    .filter((o) => o.value)
    .map((o) => JSON.parse(o.value));
  expect(refs.some((r) => r.contour === 0 && r.index === 0)).toBe(true);
  expect(refs.some((r) => r.contour === 0 && r.index === 2)).toBe(false);
  expect(refs.some((r) => r.contour === 1)).toBe(false);
  select.value = "";
  click("Cancel axis edit");
  expect(commit).not.toHaveBeenCalled();
  expect(drawing).toEqual(before);
  click("Edit mirror axis");
  select = document.querySelector('[aria-label="Saved mirror axis"]');
  expect(JSON.parse(select.value).index).toBe(1);
  click("Update mirror axis");
  expect(report).not.toHaveBeenCalled();
  expect(commit).toHaveBeenCalledTimes(1);
  expect(drawing.constraints[0].axis).toMatchObject({
    index: 1,
    segmentId: "axis",
  });
  expect(drawing.contours[1]).toEqual(before.contours[1]);
  const doc = createEmptyPartDocument("Stable mirror axis");
  doc.features.push({
    type: "profile",
    id: "sketch",
    name: "Sketch",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: drawing,
  });
  expect(parsePartDocument(serializePartDocument(doc)).features[0]).toEqual(
    doc.features[0],
  );
});
