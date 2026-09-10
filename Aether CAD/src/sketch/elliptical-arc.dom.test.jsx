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
it("previews the construction ellipse then commits and reopens an editable elliptical arc", async () => {
  let doc = createEmptyPartDocument("Elliptical arc");
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
  expect(document.querySelector(".sketch-contour")).toBeNull();
  point(0, 3);
  move(5, 0);
  const preview = () =>
    document
      .querySelector(".sketch-preview-layer path:not(.sketch-ellipse-guide)")
      .getAttribute("d");
  const ccw = preview();
  const direction = document.querySelector('[aria-label="Arc direction"]');
  direction.value = "clockwise";
  direction.dispatchEvent(new Event("change"));
  expect(preview()).not.toBe(ccw);
  const expected = preview();
  point(5, 0);
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    expected,
  );
  expect(document.querySelector(".sketch-ellipse-guide")).toBeNull();
  click("Undo");
  expect(document.querySelector(".sketch-contour")).toBeNull();
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const d = doc.features[0].profile;
  expect(d.contours).toHaveLength(2);
  expect(d.contours[0].segments[0]).toMatchObject({
    type: "ellipse",
    radiusX: 5,
    radiusY: 3,
    sweep: false,
    largeArc: false,
  });
  expect(d.constraints.some((c) => c.kind === "concentric")).toBe(true);
  open(() => doc, apply, doc.features[0]);
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    expected,
  );
  click("Cancel");
});
