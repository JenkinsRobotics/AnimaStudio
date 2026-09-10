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
it("authors and trims a full ellipse with undo and retained shared arcs after reopen", async () => {
  let doc = createEmptyPartDocument("Ellipse trim");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool("ellipse");
  point(0, 0);
  point(5, 0);
  point(0, 3);
  for (const x of [-2, 2]) {
    tool("select");
    tool("line");
    point(x, -5);
    point(x, 5);
  }
  const before = document.querySelector(".sketch-contour").getAttribute("d");
  tool("trim");
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
    new dom.window.MouseEvent("click", {
      clientX: 0,
      clientY: -3,
      bubbles: true,
    }),
  );
  const after = document.querySelector(".sketch-contour").getAttribute("d");
  expect(after).not.toBe(before);
  click("Undo");
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    before,
  );
  click("Redo");
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    after,
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const drawing = doc.features[0].profile;
  expect(drawing.contours[0].segments).toHaveLength(3);
  expect(
    drawing.constraints.filter((c) => c.kind === "ellipse-locus"),
  ).toHaveLength(2);
  expect(drawing.constraints.some((c) => c.kind === "ellipse-shape")).toBe(
    false,
  );
  open(() => doc, apply, doc.features[0]);
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    after,
  );
  click("Cancel");
});
