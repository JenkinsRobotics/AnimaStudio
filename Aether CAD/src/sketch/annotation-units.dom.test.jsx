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
it.each(["radius", "angle"])(
  "updates %s labels without replacing pending inputs",
  async (kind) => {
    const { applyDocumentUnits } = await import("../document-preferences");
    let doc = createEmptyPartDocument("Annotation units");
    const apply = vi.fn(async (next) => {
      doc = next;
    });
    open(() => doc, apply);
    click("Top (XY)");
    let a, b;
    if (kind === "radius") {
      tool("circle");
      point(10, 10);
      point(15, 10);
      a = { contour: 0, kind: "circle" };
    } else {
      tool("line");
      point(10, 10);
      point(20, 10);
      a = { contour: 0, kind: "line", index: 0 };
      click("New contour");
      point(10, 10);
      point(10, 20);
      b = { contour: 1, kind: "line", index: 0 };
    }
    window.dispatchEvent(
      new CustomEvent("aether-sketch-constraint", { detail: kind }),
    );
    document.querySelector('[aria-label="Entity A"]').value = JSON.stringify(a);
    if (b)
      document.querySelector('[aria-label="Entity B"]').value =
        JSON.stringify(b);
    document.querySelector('[aria-label="Constraint value"]').value =
      kind === "radius" ? "25.4" : "90";
    click("Apply constraint");
    let label = document.querySelector(`text[data-dimension-kind="${kind}"]`);
    expect(label.textContent).toBe(kind === "radius" ? "R 25.4 mm" : "90°");
    applyDocumentUnits({
      length: { unit: "in", decimals: 4 },
      angle: { unit: "rad", decimals: 4 },
    });
    try {
      expect(label.textContent).toBe(
        kind === "radius" ? "R 1 in" : "1.5708 rad",
      );
      let input = document.querySelector(`input[aria-label="${kind} value"]`);
      input.value = kind === "radius" ? "1/2" : "pi/3";
      label.dispatchEvent(
        new dom.window.MouseEvent("click", { bubbles: true }),
      );
      input = document.querySelector(`input[aria-label="${kind} value"]`);
      expect(document.activeElement).toBe(input);
      label = document.querySelector(`text[data-dimension-kind="${kind}"]`);
      expect(input.value).toBe(kind === "radius" ? "1/2" : "pi/3");
      applyDocumentUnits({});
      expect(document.querySelector(`input[aria-label="${kind} value"]`)).toBe(
        input,
      );
      expect(Number(input.value)).toBeCloseTo(kind === "radius" ? 12.7 : 60);
      expect(label.textContent).toBe(kind === "radius" ? "R 25.4 mm" : "90°");
      click("Finish sketch");
      await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
      doc = parsePartDocument(serializePartDocument(doc));
      expect(
        doc.features[0].profile.constraints.find((c) => c.kind === kind).value,
      ).toBe(kind === "radius" ? 25.4 : 90);
      const old = label.textContent;
      applyDocumentUnits({
        length: { unit: "in", decimals: 3 },
        angle: { unit: "rad", decimals: 3 },
      });
      expect(label.textContent).toBe(old);
    } finally {
      applyDocumentUnits({});
    }
  },
);
