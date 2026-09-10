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

it("copies retained text through Transform then independently edits and reopens the copied wording", async () => {
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
      frameWidthMillimeters: 15,
    },
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
  window.dispatchEvent(
    new CustomEvent("aether-sketch-tool", { detail: "transform" }),
  );
  const toggle = field("Copy selected geometry");
  toggle.checked = true;
  toggle.dispatchEvent(new Event("change"));
  field("Move X (mm)").value = "30";
  field("Move X (mm)").dispatchEvent(new Event("input"));
  click("Apply modification");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(6);
  const select = field("Saved sketch text");
  expect(select.options).toHaveLength(3);
  select.value = select.options[2].value;
  select.dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  expect(field("Text baseline X (mm)").value).toBe("30");
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
});
