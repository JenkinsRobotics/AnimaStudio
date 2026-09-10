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

it("edits multiple lines in the workspace and preserves them through undo, redo and native reopening", async () => {
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
      frameWidthMillimeters: 12,
    },
  );
  let doc = createEmptyPartDocument("Multiline text");
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
  select.value = select.options[1].value;
  select.dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(document.querySelector(".sketch-text-preview path")).toBeTruthy(),
  );
  const text = field("Sketch text");
  expect(text.tagName).toBe("TEXTAREA");
  text.value = "O\nO";
  text.dispatchEvent(new Event("input"));
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-text-preview path")).toHaveLength(
      4,
    ),
  );
  click("Update editable text");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-contour")).toHaveLength(5),
  );
  click("Undo");
  expect(text.value).toBe("O");
  click("Redo");
  expect(text.value).toBe("O\nO");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(saved.features[0].profile.textItems[0].text).toBe("O\nO");
  expect(saved.features[0].profile.textItems[0].emSizeMillimeters).toBe(10);
});
