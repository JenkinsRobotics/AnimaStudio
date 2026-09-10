import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { beforeAll, afterAll, expect, it, vi } from "vitest";
import { putSketchText, sketchConstraintState } from "@aether/core/sketch";
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
it("adds a frame with undo/redo, then preserves its dimensions when editing saved text", async () => {
  const bytes = readFileSync(
    new URL(
      "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  const profile = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: Uint8Array.from(bytes).buffer,
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
    },
  );
  let doc = createEmptyPartDocument("Text frame");
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
  const choose = async () => {
    const select = field("Saved sketch text");
    select.value = select.options[1].value;
    select.dispatchEvent(new Event("change"));
    await vi.waitFor(() =>
      expect(document.querySelector(".sketch-text-preview path")).toBeTruthy(),
    );
  };
  open(() => doc, apply, doc.features[0]);
  await choose();
  expect(button("Add text frame").disabled).toBe(false);
  const original = document.querySelectorAll(".sketch-contour").length;
  click("Add text frame");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(
    original + 1,
  );
  expect(button("Add text frame").disabled).toBe(true);
  click("Undo");
  expect(button("Add text frame").disabled).toBe(false);
  click("Redo");
  expect(button("Add text frame").disabled).toBe(true);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const drawing = doc.features[0].profile,
    item = drawing.textItems[0];
  const contour = drawing.contours.findIndex(
    (c) => c.id === item.frameContourId,
  );
  drawing.constraints = [
    {
      id: "anchor",
      kind: "fix",
      a: { contour, kind: "point", index: 0 },
      point: [0, 0],
    },
    {
      id: "baseline",
      kind: "horizontal",
      a: { contour, kind: "line", index: 0 },
    },
    {
      id: "width",
      kind: "length",
      a: { contour, kind: "line", index: 0 },
      value: item.frameWidthMillimeters,
    },
    {
      id: "height",
      kind: "length",
      a: { contour, kind: "line", index: 1 },
      value: 10,
    },
  ];
  open(() => doc, apply, doc.features[0]);
  await choose();
  field("Sketch text").value = "OO";
  field("Sketch text").dispatchEvent(new Event("input"));
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-text-preview path")).toHaveLength(
      4,
    ),
  );
  click("Update editable text");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-contour")).toHaveLength(5),
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  const saved = parsePartDocument(serializePartDocument(doc)).features[0]
    .profile;
  expect(saved.textItems[0].frameContourId).toBe(item.frameContourId);
  expect(saved.textItems[0].text).toBe("OO");
  expect(saved.constraints).toHaveLength(4);
  expect(sketchConstraintState(saved)).toMatchObject({
    state: "fully-constrained",
    degreesOfFreedom: 0,
  });
});
