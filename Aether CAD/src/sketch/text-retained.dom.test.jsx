import * as sketchCore from "@aether/core/sketch";
import { mountTextItems } from "./text-items";
import { createRequire } from "node:module";
import { beforeAll, afterAll, expect, it, vi } from "vitest";
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
const { Font, Glyph, Path } = createRequire(
  new URL("../../../core/engine/package.json", import.meta.url),
)("opentype.js");
function fontBytes() {
  const path = new Path();
  path.moveTo(0, 0);
  path.lineTo(600, 0);
  path.lineTo(600, 800);
  path.lineTo(0, 800);
  path.close();
  path.moveTo(100, 100);
  path.lineTo(100, 700);
  path.lineTo(500, 700);
  path.lineTo(500, 100);
  path.close();
  return new Font({
    familyName: "Original Test",
    styleName: "Regular",
    unitsPerEm: 1000,
    ascender: 800,
    descender: -200,
    glyphs: [
      new Glyph({ name: ".notdef", advanceWidth: 700, path: new Path() }),
      new Glyph({ name: "O", unicode: 79, advanceWidth: 700, path }),
    ],
  }).toArrayBuffer();
}
const field = (label) => document.querySelector(`[aria-label="${label}"]`);
const input = (label, value) => {
  field(label).value = value;
  field(label).dispatchEvent(new Event("input"));
};
function loadFont(arrayBuffer = async () => fontBytes()) {
  Object.defineProperty(field("Text font file"), "files", {
    value: [{ size: 1000, arrayBuffer }],
    configurable: true,
  });
  field("Text font file").dispatchEvent(new Event("change"));
}

const waitPreview = () =>
  vi.waitFor(() =>
    expect(document.querySelector(".sketch-text-preview path")).toBeTruthy(),
  );
it("creates retained text, edits after native reopening, and keeps undo/redo fields in sync", async () => {
  let doc = createEmptyPartDocument("Retained text");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  input("Sketch text", "O");
  loadFont();
  await waitPreview();
  field("Flip text horizontally").checked = true;
  field("Flip text horizontally").dispatchEvent(new Event("change"));
  click("Create editable text");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-contour")).toHaveLength(2),
  );
  click("Undo");
  expect(field("Saved sketch text").options).toHaveLength(1);
  click("Redo");
  expect(field("Saved sketch text").options).toHaveLength(2);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  expect(doc.features[0].profile.textItems[0].text).toBe("O");
  expect(doc.features[0].profile.textItems[0].flipHorizontal).toBe(true);
  expect(doc.features[0].profile.contours[0].segments[0].end[0]).toBeLessThan(
    0,
  );
  open(() => doc, apply, doc.features[0]);
  const selector = field("Saved sketch text");
  selector.value = selector.options[1].value;
  selector.dispatchEvent(new Event("change"));
  await waitPreview();
  expect(field("Sketch text").value).toBe("O");
  expect(field("Flip text horizontally").checked).toBe(true);
  input("Sketch text", "OO");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-text-preview path")).toHaveLength(
      4,
    ),
  );
  click("Update editable text");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-contour")).toHaveLength(4),
  );
  click("Undo");
  expect(field("Sketch text").value).toBe("O");
  click("Redo");
  expect(field("Sketch text").value).toBe("OO");
  click("Detach text to curves");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(4);
  expect(field("Saved sketch text").options).toHaveLength(1);
  click("Undo");
  expect(field("Saved sketch text").options).toHaveLength(2);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  expect(
    parsePartDocument(serializePartDocument(doc)).features[0].profile
      .textItems[0].text,
  ).toBe("OO");
});

it("does not overwrite concurrent sketch edits or commit after disposal", async () => {
  const source = { type: "drawing", contours: [] },
    commit = vi.fn(),
    error = vi.fn();
  let resolve;
  const operation = vi.spyOn(sketchCore, "putSketchText").mockImplementation(
    () =>
      new Promise((r) => {
        resolve = r;
      }),
  );
  const parent = document.createElement("div");
  document.body.append(parent);
  const items = mountTextItems(parent, () => source, commit, {
    read: () => ({
      text: "O",
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
    }),
    load: vi.fn(),
    clear: vi.fn(),
    error,
  });
  try {
    items.ready(true);
    parent.querySelector("button").click();
    source.contours.push({ type: "circle", center: [0, 0], radius: 3 });
    resolve({
      type: "drawing",
      contours: [],
      textItems: [{ id: "new", text: "O" }],
    });
    await vi.waitFor(() =>
      expect(error).toHaveBeenCalledWith(
        expect.stringContaining("sketch changed"),
      ),
    );
    expect(commit).not.toHaveBeenCalled();
    items.ready(true);
    parent.querySelector("button").click();
    items.dispose();
    resolve({
      type: "drawing",
      contours: [],
      textItems: [{ id: "new", text: "O" }],
    });
    await new Promise((r) => setTimeout(r, 20));
    expect(commit).not.toHaveBeenCalled();
  } finally {
    items.dispose();
    parent.remove();
    operation.mockRestore();
  }
});
