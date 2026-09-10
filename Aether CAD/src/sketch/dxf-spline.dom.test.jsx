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
it("previews and inserts editable spline controls, undoes, and saves/reopens native geometry", async () => {
  let doc = createEmptyPartDocument("Imported spline");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  const pairs = [
    [0, "SECTION"],
    [2, "ENTITIES"],
    [0, "SPLINE"],
    [70, 8],
    [71, 3],
    [72, 8],
    [73, 4],
    ...[0, 0, 0, 0, 1, 1, 1, 1].map((v) => [40, v]),
    ...[
      [0, 0],
      [0, 2],
      [3, 2],
      [3, 0],
    ].flatMap(([x, y]) => [
      [10, x],
      [20, y],
    ]),
    [0, "ENDSEC"],
    [0, "EOF"],
  ];
  const input = document.querySelector('[aria-label="DXF file"]');
  Object.defineProperty(input, "files", {
    value: [{ text: async () => pairs.flat().join("\n") }],
    configurable: true,
  });
  const units = document.querySelector('[aria-label="DXF source units"]');
  units.value = "1";
  units.dispatchEvent(new Event("change", { bubbles: true }));
  input.dispatchEvent(new Event("change", { bubbles: true }));
  await vi.waitFor(() =>
    expect(document.querySelector(".sketch-dxf-preview path")).toBeTruthy(),
  );
  expect(
    document.querySelector(".sketch-dxf-preview path").getAttribute("d"),
  ).toContain("C");
  click("Insert DXF");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  click("Undo");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(0);
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  const c = saved.features[0].profile.contours[0];
  expect(c.segments[0].type).toBe("bezier");
  expect(c.segments[0].controls[0][1]).toBeCloseTo(2);
  open(() => saved, apply, saved.features[0]);
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  click("Cancel");
});
