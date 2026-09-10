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
const tool = () =>
  window.dispatchEvent(
    new CustomEvent("aether-sketch-tool", { detail: "fit-spline" }),
  );
const point = (x, y) => {
  document.querySelector('[aria-label="X (mm)"]').value = x;
  document.querySelector('[aria-label="Y (mm)"]').value = y;
  click("Place point");
};
it("keeps a live curve between clicks, finishes once, undoes and reopens native curves", async () => {
  let doc = createEmptyPartDocument("Fit spline");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool();
  point(0, 0);
  point(10, 8);
  point(20, 0);
  expect(
    document.querySelector(".sketch-preview-layer").getAttribute("d"),
  ).toContain("C");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(0);
  const canvas = document.querySelector(".cad-sketch-workspace svg");
  canvas.createSVGPoint = () => ({
    x: 0,
    y: 0,
    matrixTransform() {
      return { x: this.x, y: this.y };
    },
  });
  canvas.getScreenCTM = () => ({ inverse: () => ({}) });
  const beforePreview = document
    .querySelector(".sketch-preview-layer")
    .getAttribute("d");
  canvas.dispatchEvent(
    new dom.window.MouseEvent("pointermove", {
      clientX: 30,
      clientY: -10,
      bubbles: true,
    }),
  );
  expect(
    document.querySelector(".sketch-preview-layer").getAttribute("d"),
  ).not.toBe(beforePreview);
  click("Finish sketch");
  expect(apply).not.toHaveBeenCalled();
  expect(document.querySelector(".cad-sketch-workspace").textContent).toContain(
    "Finish spline or cancel",
  );
  click("Finish spline");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  click("Undo");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(0);
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(
    saved.features[0].profile.constraints.some(
      (c) => c.kind === "spline-shape",
    ),
  ).toBe(true);
  expect(saved.features[0].profile.contours[0].segments).toHaveLength(2);
  open(() => saved, apply, saved.features[0]);
  tool();
  point(30, 0);
  point(40, 5);
  const svg = document.querySelector(".cad-sketch-workspace svg");
  svg.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", { key: "Escape", bubbles: true }),
  );
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  tool();
  point(30, 0);
  point(40, 5);
  svg.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", { key: "Enter", bubbles: true }),
  );
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(2);
  click("Cancel");
});

it("previews closure at the start point and commits a periodic native loop", async () => {
  let doc = createEmptyPartDocument("Closed spline");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool();
  point(0, 0);
  point(10, 0);
  point(10, 10);
  point(0, 10);
  const svg = document.querySelector(".cad-sketch-workspace svg");
  svg.createSVGPoint = () => ({
    x: 0,
    y: 0,
    matrixTransform() {
      return { x: this.x, y: this.y };
    },
  });
  svg.getScreenCTM = () => ({ inverse: () => ({}) });
  svg.dispatchEvent(
    new dom.window.MouseEvent("pointermove", {
      clientX: 0,
      clientY: 0,
      bubbles: true,
    }),
  );
  const preview = document
    .querySelector(".sketch-preview-layer")
    .getAttribute("d");
  expect(preview.match(/C/g) || []).toHaveLength(4);
  point(0, 0);
  expect(document.querySelectorAll(".sketch-contour.closed")).toHaveLength(1);
  click("Undo");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(0);
  click("Redo");
  point(30, 0);
  point(40, 0);
  point(35, 10);
  click("Close spline");
  expect(document.querySelectorAll(".sketch-contour.closed")).toHaveLength(2);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(
    saved.features[0].profile.constraints.some(
      (c) => c.kind === "spline-shape",
    ),
  ).toBe(true);
  for (const c of saved.features[0].profile.contours)
    expect(c.segments.at(-1).end).toEqual(c.start);
});
