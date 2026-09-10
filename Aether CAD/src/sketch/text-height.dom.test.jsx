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

it("authors ascender height and keeps height handles, undo and native records consistent", async () => {
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
  let doc = createEmptyPartDocument("Physical text height");
  doc.features.push({
    id: "s",
    type: "profile",
    name: "Text",
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
  field("Size text by ascender height").checked = true;
  field("Size text by ascender height").dispatchEvent(new Event("change"));
  field("Text height (mm)").value = "10";
  field("Text height (mm)").dispatchEvent(new Event("input"));
  const em = Number(field("Text em size (mm)").value);
  expect(em).toBeLessThan(10);
  click("Update editable text");
  await vi.waitFor(() =>
    expect(button("Update editable text").disabled).toBe(false),
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const item = doc.features[0].profile.textItems[0];
  expect(item.fontAscenderRatio).toBeGreaterThan(1);
  expect(item.emSizeMillimeters * item.fontAscenderRatio).toBeCloseTo(10);
  open(() => doc, apply, doc.features[0]);
  await choose();
  expect(field("Size text by ascender height").checked).toBe(true);
  expect(Number(field("Text height (mm)").value)).toBeCloseTo(10);
  const handle = document.querySelector('[data-text-resize="height"]'),
    svg = handle.ownerSVGElement;
  svg.getScreenCTM = () => ({ a: 1, b: 0, inverse: () => ({}) });
  svg.createSVGPoint = () => ({
    x: 0,
    y: 0,
    matrixTransform() {
      return { x: this.x, y: this.y };
    },
  });
  const pointer = (target, type, y) => {
    const e = new window.MouseEvent(type, {
      button: 0,
      clientX: 6,
      clientY: -y,
      bubbles: true,
      cancelable: true,
    });
    Object.defineProperty(e, "pointerId", { value: 1 });
    target.dispatchEvent(e);
  };
  pointer(handle, "pointerdown", 10);
  pointer(svg, "pointermove", 20);
  pointer(svg, "pointerup", 20);
  await vi.waitFor(() =>
    expect(Number(field("Text height (mm)").value)).toBeCloseTo(20),
  );
  click("Undo");
  expect(Number(field("Text height (mm)").value)).toBeCloseTo(10);
  click("Redo");
  expect(Number(field("Text height (mm)").value)).toBeCloseTo(20);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  const final = parsePartDocument(serializePartDocument(doc)).features[0]
    .profile.textItems[0];
  expect(final.emSizeMillimeters * final.fontAscenderRatio).toBeCloseTo(20);
});
