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
it("previews a filled DXF boundary, inserts it with undo, and reopens editable edges", async () => {
  let doc = createEmptyPartDocument("Face import");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  const pairs = [
    [0, "SECTION"],
    [2, "ENTITIES"],
    [0, "SOLID"],
    [8, "Plate"],
    [10, 0],
    [20, 0],
    [11, 4],
    [21, 0],
    [12, 0],
    [22, 3],
    [13, 4],
    [23, 3],
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
    expect(document.querySelector(".sketch-dxf-preview path")).toBeTruthy(),
  );
  click("Insert DXF");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  click("Undo");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(0);
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  expect(doc.features[0].profile.contours[0]).toMatchObject({
    type: "path",
    sourceLayer: "Plate",
    start: [0, 0],
    segments: [
      { type: "line", end: [4, 0] },
      { type: "line", end: [4, 3] },
      { type: "line", end: [0, 3] },
      { type: "line", end: [0, 0] },
    ],
  });
  open(() => doc, apply, doc.features[0]);
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  click("Cancel");
});
