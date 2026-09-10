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
  "infers a semicircle with snapping=%s",
  async (enabled) => {
    let doc = createEmptyPartDocument("Semicircle");
    const apply = vi.fn(async (next) => {
      doc = next;
    });
    open(() => doc, apply);
    click("Top (XY)");
    tool("arc");
    for (const [label, value] of [
      ["Snap to geometry", enabled],
      ["Snap to grid", false],
    ]) {
      const input = [...document.querySelectorAll("label")]
        .find((l) => l.textContent === label)
        .querySelector("input");
      input.checked = value;
      input.dispatchEvent(new Event("change", { bubbles: true }));
    }
    point(-5, 0);
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
    const pointer = (type) =>
      svg.dispatchEvent(
        new dom.window.MouseEvent(type, {
          clientX: 0,
          clientY: -5.02,
          bubbles: true,
        }),
      );
    pointer("pointermove");
    expect(
      document
        .querySelector(".sketch-preview-layer")
        .textContent.includes("Semicircle"),
    ).toBe(enabled);
    pointer("click");
    click("Undo");
    click("Redo");
    click("Finish sketch");
    await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
    doc = parsePartDocument(serializePartDocument(doc));
    const drawing = doc.features[0].profile;
    const { sketchArcGeometry, editDrawingDimension, sketchConstraintState } =
      await import("@aether/core/sketch");
    const path = drawing.contours[0],
      arc = path.segments[0];
    expect(arc.middle[1]).toBeCloseTo(enabled ? 5 : 5.02, 6);
    expect(drawing.contours.filter((c) => c.construction)).toHaveLength(
      enabled ? 2 : 0,
    );
    if (enabled) {
      drawing.constraints.push({
        id: "test-radius",
        kind: "radius",
        a: { contour: 0, kind: "arc", index: 0 },
        value: 5,
      });
      const edited = editDrawingDimension(drawing, "test-radius", 8);
      const p = edited.contours[0],
        a = p.segments[0];
      const geometry = sketchArcGeometry(p.start, a.middle, a.end);
      expect(geometry.radius).toBeCloseTo(8);
      expect(Math.abs(geometry.sweep)).toBeCloseTo(Math.PI);
      expect(sketchConstraintState(edited).state).toBe("under-constrained");
    }
  },
);
