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
const tool = (name) =>
  window.dispatchEvent(new CustomEvent("aether-sketch-tool", { detail: name }));
const point = (x, y) => {
  document.querySelector('[aria-label="X (mm)"]').value = x;
  document.querySelector('[aria-label="Y (mm)"]').value = y;
  click("Place point");
};
it("retains pointer-sized radius on an axis start and resets it for the next gesture", async () => {
  let doc = createEmptyPartDocument("Pointer arc");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool("elliptical-arc");
  point(0, 0);
  point(5, 0);
  const svg = document.querySelector('[aria-label="2D sketch canvas"]');
  svg.createSVGPoint = () => ({
    x: 0,
    y: 0,
    matrixTransform() {
      return { x: this.x, y: this.y };
    },
  });
  svg.getScreenCTM = () => ({ a: 1, b: 0, inverse: () => ({}) });
  const move = (x, y) =>
    svg.dispatchEvent(
      new dom.window.MouseEvent("pointermove", {
        clientX: x,
        clientY: -y,
        bubbles: true,
      }),
    );
  move(0, 3);
  expect(document.querySelector(".sketch-ellipse-guide")).toBeTruthy();
  move(5, 0);
  expect(document.querySelector(".sketch-ellipse-guide")).toBeTruthy();
  point(5, 0);
  move(0, 6);
  const preview = document
    .querySelector(".sketch-preview-layer path:not(.sketch-ellipse-guide)")
    .getAttribute("d");
  point(0, 6);
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    preview,
  );
  // A new gesture must not inherit the previous arc's width.
  point(20, 0);
  point(25, 0);
  move(25, 0);
  expect(document.querySelector(".sketch-ellipse-guide")).toBeNull();
  tool("select");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const d = doc.features[0].profile;
  expect(d.contours[0].segments[0].radiusY).toBeCloseTo(3);
  expect(d.contours[0].start[0]).toBeCloseTo(5);
  expect(d.contours).toHaveLength(2);
  open(() => doc, apply, doc.features[0]);
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    preview,
  );
  click("Cancel");
});
