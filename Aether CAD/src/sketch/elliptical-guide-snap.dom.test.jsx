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
it.each([true, false])(
  "snaps temporary ellipse quadrants with geometry snapping=%s",
  async (enabled) => {
    let doc = createEmptyPartDocument("Guide snapping");
    const apply = vi.fn(async (next) => {
      doc = next;
    });
    open(() => doc, apply);
    click("Top (XY)");
    tool("elliptical-arc");
    const toggle = (label, value) => {
      const input = [...document.querySelectorAll("label")]
        .find((l) => l.textContent === label)
        ?.querySelector("input");
      input.checked = value;
      input.dispatchEvent(new Event("change", { bubbles: true }));
    };
    toggle("Snap to geometry", enabled);
    toggle("Snap to grid", false);
    const radius = document.querySelector(
      '[aria-label="Elliptical arc secondary radius (mm)"]',
    );
    radius.value = "3";
    radius.dispatchEvent(new Event("input"));
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
    const pointer = (type, x, y) =>
      svg.dispatchEvent(
        new dom.window.MouseEvent(type, {
          clientX: x,
          clientY: -y,
          bubbles: true,
        }),
      );
    pointer("pointermove", 5.02, 0.01);
    pointer("click", 5.02, 0.01);
    pointer("pointermove", 0.01, 3.02);
    if (enabled)
      expect(
        document.querySelector(".sketch-preview-layer").textContent,
      ).toContain("Ellipse quadrant");
    pointer("click", 0.01, 3.02);
    click("Finish sketch");
    await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
    doc = parsePartDocument(serializePartDocument(doc));
    const d = doc.features[0].profile;
    const endpoints = d.constraints.filter(
      (c) => c.kind === "quadrant" && c.a.contour === 0,
    );
    expect(endpoints).toHaveLength(enabled ? 2 : 0);
    if (enabled) {
      expect(d.contours[0].start[0]).toBeCloseTo(5);
      expect(d.contours[0].start[1]).toBeCloseTo(0);
      expect(d.contours[0].segments[0].end[0]).toBeCloseTo(0);
      expect(d.contours[0].segments[0].end[1]).toBeCloseTo(3);
    }
  },
);
