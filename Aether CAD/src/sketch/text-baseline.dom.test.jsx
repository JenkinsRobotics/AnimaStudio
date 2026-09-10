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

it("shows the default horizontal constraint and supports removing it, undoing, and rotating saved text", async () => {
  const bytes = Uint8Array.from(
    readFileSync(
      new URL(
        "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
        import.meta.url,
      ),
    ),
  ).buffer;
  const profile = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: bytes,
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
      frameWidthMillimeters: 12,
    },
  );
  let doc = createEmptyPartDocument("Text baseline");
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
  const row = () =>
    document.querySelector('[data-constraint-kind="horizontal"]');
  expect(row()).toBeTruthy();
  const remove = () =>
    [...row().querySelectorAll("button")]
      .find((b) => b.textContent === "Remove")
      .click();
  remove();
  expect(row()).toBeNull();
  click("Undo");
  expect(row()).toBeTruthy();
  click("Redo");
  expect(row()).toBeNull();
  const select = field("Saved sketch text");
  select.value = select.options[1].value;
  select.dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(document.querySelector(".sketch-text-preview path")).toBeTruthy(),
  );
  const angle = field("Text rotation (degrees)");
  angle.value = "37";
  angle.dispatchEvent(new Event("input"));
  click("Update editable text");
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc)).features[0]
    .profile;
  expect(saved.constraints).toEqual([]);
  expect(saved.textItems[0].rotationDegrees).toBeCloseTo(37);
});
