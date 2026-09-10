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
it.each(["ellipse", "elliptical-arc"])(
  "offers persistent inline diameters after %s placement",
  async (toolName) => {
    let doc = createEmptyPartDocument("Inline diameters");
    const apply = vi.fn(async (next) => {
      doc = next;
    });
    open(() => doc, apply);
    click("Top (XY)");
    tool(toolName);
    point(0, 0);
    point(5, 0);
    point(0, 3);
    if (toolName === "elliptical-arc") point(5, 0);
    const primary = () =>
      document.querySelector(
        '[aria-label="New ellipse primary diameter (mm)"]',
      );
    const secondary = () =>
      document.querySelector(
        '[aria-label="New ellipse secondary diameter (mm)"]',
      );
    expect(primary().closest(".sketch-recent-ellipse").hidden).toBe(false);
    const before = document.querySelector(".sketch-contour").getAttribute("d");
    primary().value = "14";
    secondary().value = "";
    click("Set ellipse diameters");
    expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
      before,
    );
    expect(primary().closest(".sketch-recent-ellipse").hidden).toBe(false);
    secondary().value = "6";
    primary().value = "14";
    primary().dispatchEvent(
      new dom.window.KeyboardEvent("keydown", { key: "Enter", bubbles: true }),
    );
    expect(document.activeElement).toBe(secondary());
    secondary().value = "8";
    secondary().dispatchEvent(
      new dom.window.KeyboardEvent("keydown", { key: "Enter", bubbles: true }),
    );
    expect(primary().closest(".sketch-recent-ellipse").hidden).toBe(true);
    const rendered = () =>
      document.querySelector(".sketch-contour").getAttribute("d");
    const after = rendered();
    click("Undo");
    expect(rendered()).not.toBe(after);
    click("Redo");
    expect(rendered()).toBe(after);
    click("Finish sketch");
    await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
    doc = parsePartDocument(serializePartDocument(doc));
    const d = doc.features[0].profile;
    expect(d.contours[0].segments[0].radiusX).toBeCloseTo(7, 4);
    expect(d.contours[0].segments[0].radiusY).toBeCloseTo(4, 4);
    expect(d.constraints.filter((c) => c.kind === "length")).toHaveLength(2);
    open(() => doc, apply, doc.features[0]);
    expect(rendered()).toBe(after);
    click("Cancel");
  },
);
