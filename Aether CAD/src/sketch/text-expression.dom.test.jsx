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

it("previews document-variable text, rejects invalid expressions and retains formula edits through undo and native save", async () => {
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
  let doc = createEmptyPartDocument("Expression editor");
  doc.variables = [{ name: "label", kind: "string", expression: '"OO"' }];
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
  const enabled = field("Use text expression"),
    formula = field("Text expression"),
    text = field("Sketch text");
  enabled.checked = true;
  enabled.dispatchEvent(new Event("change"));
  expect(formula.value).toBe('"O"');
  formula.value = "#label";
  formula.dispatchEvent(new Event("input"));
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-text-preview path")).toHaveLength(
      4,
    ),
  );
  expect(text.readOnly).toBe(true);
  expect(text.value).toBe("OO");
  formula.value = "#missing";
  formula.dispatchEvent(new Event("input"));
  await vi.waitFor(() =>
    expect(document.body.textContent).toContain("Unknown variable #missing"),
  );
  expect(button("Update editable text").disabled).toBe(true);
  expect(document.querySelector(".sketch-text-preview")).toBeNull();
  formula.value = "#label";
  formula.dispatchEvent(new Event("input"));
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  doc.variables[0].expression = '"OOO"';
  expect(text.value).toBe("OO"); // Draft variables are isolated from the saved document.
  doc.variables[0].expression = '"OO"';
  click("Update editable text");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-contour")).toHaveLength(5),
  );
  click("Undo");
  expect(enabled.checked).toBe(false);
  expect(text.value).toBe("O");
  click("Redo");
  expect(enabled.checked).toBe(true);
  expect(formula.value).toBe("#label");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  expect(doc.features[0].profile.textItems[0]).toMatchObject({
    text: "OO",
    expression: "#label",
  });
  open(() => doc, apply, doc.features[0]);
  const again = field("Saved sketch text");
  again.value = again.options[1].value;
  again.dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  const toggle = field("Use text expression");
  expect(toggle.checked).toBe(true);
  toggle.checked = false;
  toggle.dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  expect(field("Sketch text").readOnly).toBe(false);
  click("Update editable text");
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  expect(
    parsePartDocument(serializePartDocument(doc)).features[0].profile
      .textItems[0].expression,
  ).toBeUndefined();
});
