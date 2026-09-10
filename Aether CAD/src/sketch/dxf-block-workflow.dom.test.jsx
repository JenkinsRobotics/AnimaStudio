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
it("imports transformed block geometry through layer filtering, placement and native reopen", async () => {
  let doc = createEmptyPartDocument("Block import");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  const pairs = [
    [0, "SECTION"],
    [2, "BLOCKS"],
    [0, "BLOCK"],
    [2, "ring"],
    [10, 0],
    [20, 0],
    [0, "CIRCLE"],
    [10, 0],
    [20, 0],
    [40, 3],
    [0, "CIRCLE"],
    [8, "Reference"],
    [10, 100],
    [20, 0],
    [40, 1],
    [0, "ENDBLK"],
    [0, "ENDSEC"],
    [0, "SECTION"],
    [2, "ENTITIES"],
    [0, "INSERT"],
    [2, "ring"],
    [8, "Parts"],
    [10, 0],
    [20, 0],
    [41, 2],
    [42, 1],
    [0, "ENDSEC"],
    [0, "EOF"],
  ];
  const file = document.querySelector('[aria-label="DXF file"]');
  Object.defineProperty(file, "files", {
    value: [{ text: async () => pairs.flat().join("\n") }],
    configurable: true,
  });
  const units = document.querySelector('[aria-label="DXF source units"]');
  units.value = "1";
  units.dispatchEvent(new Event("change", { bubbles: true }));
  file.dispatchEvent(new Event("change", { bubbles: true }));
  await vi.waitFor(() =>
    expect(
      document.querySelector('[aria-label="Import DXF layer Reference"]'),
    ).toBeTruthy(),
  );
  const reference = document.querySelector(
    '[aria-label="Import DXF layer Reference"]',
  );
  reference.checked = false;
  reference.dispatchEvent(new Event("change", { bubbles: true }));
  expect(
    document.querySelector('[aria-label="Import DXF layer Parts"]').checked,
  ).toBe(true);
  for (const [label, value] of [
    ["DXF X (mm)", "10"],
    ["DXF Y (mm)", "20"],
  ]) {
    const input = document.querySelector(`[aria-label="${label}"]`);
    input.value = value;
    input.dispatchEvent(new Event("input", { bubbles: true }));
  }
  expect(document.querySelectorAll(".sketch-dxf-preview path")).toHaveLength(1);
  expect(
    document.querySelector(".sketch-dxf-preview path").getAttribute("d"),
  ).toContain("A");
  click("Insert DXF");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  click("Undo");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(0);
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const profile = doc.features[0].profile;
  expect(profile.contours).toHaveLength(1);
  const contour = profile.contours[0];
  expect(contour.type).toBe("path");
  expect(contour.sourceLayer).toBe("Parts");
  expect(contour.start[0]).toBeCloseTo(16);
  expect(contour.start[1]).toBeCloseTo(20);
  expect(contour.segments[0]).toMatchObject({
    type: "ellipse",
    radiusX: 6,
    radiusY: 3,
  });
  open(() => doc, apply, doc.features[0]);
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  window.dispatchEvent(
    new CustomEvent("aether-sketch-tool", { detail: "select" }),
  );
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
      clientX: 16,
      clientY: -20,
      bubbles: true,
    }),
  );
  expect(
    document.querySelector('[aria-label="Selected entity constraint state"]')
      .textContent,
  ).toContain("Source layer: Parts");
  click("Cancel");
});
