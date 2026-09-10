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
it("starts an elliptical arc on the primary axis with a driving secondary radius", async () => {
  let doc = createEmptyPartDocument("Axis start");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool("elliptical-arc");
  const radius = document.querySelector(
    '[aria-label="Elliptical arc secondary radius (mm)"]',
  );
  expect(radius.parentElement.hidden).toBe(false);
  radius.value = "3";
  radius.dispatchEvent(new Event("input"));
  point(0, 0);
  point(5, 0);
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
  svg.dispatchEvent(
    new dom.window.MouseEvent("pointermove", {
      clientX: 0,
      clientY: -6,
      bubbles: true,
    }),
  );
  const preview = () =>
    document
      .querySelector(".sketch-preview-layer path:not(.sketch-ellipse-guide)")
      .getAttribute("d");
  const before = preview();
  radius.value = "4";
  radius.dispatchEvent(new Event("input"));
  expect(preview()).not.toBe(before);
  point(0, 6);
  const rendered = () =>
    document.querySelector(".sketch-contour").getAttribute("d");
  const after = rendered();
  click("Undo");
  expect(document.querySelector(".sketch-contour")).toBeNull();
  click("Redo");
  expect(rendered()).toBe(after);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const d = doc.features[0].profile;
  expect(d.contours[0].start[0]).toBeCloseTo(5);
  expect(d.contours[0].start[1]).toBeCloseTo(0);
  expect(d.contours[0].segments[0].radiusY).toBeCloseTo(4);
  expect(d.contours[0].segments[0].end[1]).toBeCloseTo(4);
  expect(d.constraints.find((c) => c.kind === "length").value).toBe(8);
  open(() => doc, apply, doc.features[0]);
  expect(rendered()).toBe(after);
  tool("line");
  expect(
    document.querySelector(
      '[aria-label="Elliptical arc secondary radius (mm)"]',
    ).parentElement.hidden,
  ).toBe(true);
  click("Cancel");
});
