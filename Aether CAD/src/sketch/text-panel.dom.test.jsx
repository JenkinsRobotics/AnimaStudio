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
it("previews placed font outlines, inserts atomically, undoes and reopens native holes", async () => {
  let doc = createEmptyPartDocument("Text outline");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  input("Sketch text", "O");
  input("Text baseline X (mm)", "12");
  loadFont();
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-text-preview path")).toHaveLength(
      2,
    ),
  );
  input("Text em size (mm)", "20");
  await vi.waitFor(() =>
    expect(
      [...document.querySelectorAll("button")].find(
        (b) => b.textContent === "Insert text outlines",
      ).disabled,
    ).toBe(false),
  );
  click("Insert text outlines");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(2);
  expect(document.querySelector(".sketch-text-preview")).toBeNull();
  click("Undo");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(0);
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  const contours = saved.features[0].profile.contours;
  expect(contours.filter((c) => c.hole)).toHaveLength(1);
  const xs = contours.flatMap((c) => [
    c.start[0],
    ...c.segments.map((s) => s.end[0]),
  ]);
  expect(Math.min(...xs)).toBeCloseTo(12);
  expect(Math.max(...xs)).toBeCloseTo(24);
  open(() => saved, apply, saved.features[0]);
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(2);
  click("Cancel");
});
it("rejects invalid text and ignores late font reads after cancellation", async () => {
  const doc = createEmptyPartDocument("Text errors");
  open(() => doc, vi.fn());
  click("Top (XY)");
  input("Sketch text", "X");
  loadFont();
  await vi.waitFor(() =>
    expect(document.body.textContent).toContain("has no glyph"),
  );
  expect(document.querySelector(".sketch-text-preview")).toBeNull();
  let resolve;
  loadFont(
    () =>
      new Promise((r) => {
        resolve = r;
      }),
  );
  click("Cancel text");
  resolve(fontBytes());
  await new Promise((r) => setTimeout(r, 20));
  expect(document.querySelector(".sketch-text-preview")).toBeNull();
  expect(
    [...document.querySelectorAll("button")].find(
      (b) => b.textContent === "Insert text outlines",
    ).disabled,
  ).toBe(true);
  click("Cancel");
});
