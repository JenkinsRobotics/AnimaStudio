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
  "uses document units for %s creation and pending edits",
  async (kind) => {
    const { applyDocumentUnits } = await import("../document-preferences");
    let doc = createEmptyPartDocument("Dimension units");
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
    applyDocumentUnits({
      length: { unit: "in", decimals: 3 },
      angle: { unit: "rad", decimals: 3 },
    });
    try {
      window.dispatchEvent(
        new CustomEvent("aether-sketch-constraint", { detail: kind }),
      );
      document.querySelector('[aria-label="Entity A"]').value =
        JSON.stringify(a);
      if (b)
        document.querySelector('[aria-label="Entity B"]').value =
          JSON.stringify(b);
      const creation = document.querySelector(
        '[aria-label="Constraint value"]',
      );
      expect(creation.parentElement.textContent).toContain(
        kind === "radius" ? "(in)" : "(rad)",
      );
      creation.value = kind === "radius" ? "sqrt(1/64)" : "pi*sqrt(1/4)";
      click("Apply constraint");
      const input = document.querySelector(`input[aria-label="${kind} value"]`);
      expect(Number(input.value)).toBeCloseTo(
        kind === "radius" ? 0.125 : Math.PI / 2,
      );
      input.value = kind === "radius" ? "1/4" : "pi/3";
      applyDocumentUnits({});
      expect(Number(input.value)).toBeCloseTo(kind === "radius" ? 6.35 : 60);
      input.parentElement.querySelector("button").click();
      click("Finish sketch");
      await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
      doc = parsePartDocument(serializePartDocument(doc));
      expect(
        doc.features[0].profile.constraints.find((c) => c.kind === kind).value,
      ).toBeCloseTo(kind === "radius" ? 6.35 : 60);
      // Closing disposes listeners; detached inputs must no longer update.
      const detached = input.value;
      applyDocumentUnits({
        length: { unit: "ft", decimals: 3 },
        angle: { unit: "rad", decimals: 3 },
      });
      expect(input.value).toBe(detached);
    } finally {
      applyDocumentUnits({});
    }
  },
);
