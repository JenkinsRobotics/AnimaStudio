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
it("switches arc direction in live preview and saves the chosen sweep", async () => {
  let doc = createEmptyPartDocument("Clockwise arc");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool("center-arc");
  const direction = document.querySelector('[aria-label="Arc direction"]');
  expect(direction.parentElement.hidden).toBe(false);
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
  svg.dispatchEvent(
    new dom.window.MouseEvent("pointermove", {
      clientX: 0,
      clientY: -5,
      bubbles: true,
    }),
  );
  const preview = () =>
    document.querySelector(".sketch-preview-layer path").getAttribute("d");
  const counterclockwise = preview();
  direction.value = "clockwise";
  direction.dispatchEvent(new Event("change"));
  const clockwise = preview();
  expect(clockwise).not.toEqual(counterclockwise);
  point(0, 5);
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    clockwise,
  );
  click("Undo");
  expect(document.querySelector(".sketch-contour")).toBeNull();
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const arc = doc.features[0].profile.contours[0].segments[0];
  expect(arc.middle[0]).toBeLessThan(0);
  expect(arc.middle[1]).toBeLessThan(0);
  expect(arc.end[0]).toBeCloseTo(0);
  expect(arc.end[1]).toBeCloseTo(5);
  open(() => doc, apply, doc.features[0]);
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    clockwise,
  );
  tool("line");
  expect(
    document.querySelector('[aria-label="Arc direction"]').parentElement.hidden,
  ).toBe(true);
  click("Cancel");
});
