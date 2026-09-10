import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { beforeAll, afterAll, expect, it, vi } from "vitest";
import { putSketchText, copySketchContours } from "@aether/core/sketch";
import {
  createEmptyPartDocument,
  parsePartDocument,
  serializePartDocument,
} from "@aether/core/document";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom, open;
beforeAll(async () => {
  dom = new JSDOM('<div class="cad-studio-viewport"></div>', {
    url: "http://localhost/cad/",
  });
  for (const key of [
    "window",
    "document",
    "HTMLElement",
    "CustomEvent",
    "Event",
    "location",
  ])
    vi.stubGlobal(key, dom.window[key]);
  open = (await import("../sketch-workspace")).openSketchWorkspace;
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
const click = (label) => {
  const b = [...document.querySelectorAll("button")].find(
    (b) => b.textContent === label && !b.closest("[hidden]"),
  );
  expect(b).toBeTruthy();
  b.click();
};

const field = (label) => document.querySelector(`[aria-label="${label}"]`);
const button = (label) =>
  [...document.querySelectorAll("button")].find((b) => b.textContent === label);

it("previews and edits a mirrored frame without changing its corner identities", async () => {
  const bytes = readFileSync(
    new URL(
      "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  const original = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: Uint8Array.from(bytes).buffer,
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
      frameWidthMillimeters: 15,
    },
  );
  const profile = copySketchContours(
    original,
    original.contours.map((_, i) => i),
    [{ a: -1, b: 0, c: 0, d: 1, tx: 30, ty: 0 }],
  );
  let doc = createEmptyPartDocument("Editable text copy");
  doc.features.push({
    id: "s",
    name: "Text",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile,
  });
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply, doc.features[0]);
  const select = field("Saved sketch text");
  expect(select.options).toHaveLength(3);
  select.value = select.options[2].value;
  select.dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  expect(field("Text baseline X (mm)").value).toBe("30");
  const frameBefore = structuredClone(
    profile.contours.find((c) => c.id === profile.textItems[1].frameContourId),
  );
  const framePreview = document.querySelector(".sketch-text-frame-preview");
  const coordinates = (path) =>
    path.match(/[-+]?(?:\d*\.)?\d+(?:e[-+]?\d+)?/gi).map(Number);
  const expected = coordinates(
    (await import("./svg-geometry")).contourPath(frameBefore),
  );
  const actual = coordinates(framePreview.getAttribute("d"));
  expect(actual).toHaveLength(expected.length);
  actual.forEach((n, i) => expect(n).toBeCloseTo(expected[i], 9));
  field("Sketch text").value = "OO";
  field("Sketch text").dispatchEvent(new Event("input"));
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  click("Update editable text");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-contour")).toHaveLength(8),
  );
  click("Undo");
  expect(field("Sketch text").value).toBe("O");
  click("Redo");
  expect(field("Sketch text").value).toBe("OO");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(saved.features[0].profile.textItems.map((i) => i.text)).toEqual([
    "O",
    "OO",
  ]);
  expect(saved.features[0].profile.textItems[1].originMillimeters[0]).toBe(30);
  expect(saved.features[0].profile.textItems[1].placementReflected).toBe(true);
  const after = saved.features[0].profile.contours.find(
    (c) => c.id === frameBefore.id,
  );
  expect(after.id).toBe(frameBefore.id);
  expect(after.segments.map((e) => [e.id, e.endVertexId])).toEqual(
    frameBefore.segments.map((e) => [e.id, e.endVertexId]),
  );
  const afterCoordinates = coordinates(
    (await import("./svg-geometry")).contourPath(after),
  );
  afterCoordinates.forEach((n, i) => expect(n).toBeCloseTo(expected[i], 9));
});
