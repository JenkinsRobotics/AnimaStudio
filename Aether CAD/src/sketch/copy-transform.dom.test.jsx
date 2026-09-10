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
it("previews and commits a transformed copy with an independent saved radius and undo", async () => {
  let doc = createEmptyPartDocument("Copy constrained circle");
  doc.features.push({
    id: "s",
    name: "Circle",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "drawing",
      contours: [{ id: "circle", type: "circle", center: [0, 0], radius: 5 }],
      constraints: [
        {
          id: "r",
          kind: "radius",
          a: { kind: "circle", contour: 0 },
          value: 5,
        },
      ],
    },
  });
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply, doc.features[0]);
  tool("transform");
  const toggle = document.querySelector(
    '[aria-label="Copy selected geometry"]',
  );
  toggle.checked = true;
  toggle.dispatchEvent(new Event("change"));
  const move = document.querySelector('[aria-label="Move X (mm)"]');
  move.value = "20";
  move.dispatchEvent(new Event("input"));
  expect(
    document
      .querySelector(".sketch-modification-preview circle")
      .getAttribute("cx"),
  ).toBe("20");
  click("Apply modification");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(2);
  const values = () => [
    ...document.querySelectorAll('[aria-label="radius value"]'),
  ];
  expect(values()).toHaveLength(2);
  values()[1].value = "7";
  values()[1].parentElement.querySelector("button").click();
  click("Undo");
  expect(Number(values()[1].value)).toBe(5);
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(saved.features[0].profile.contours[0].radius).toBe(5);
  expect(saved.features[0].profile.contours[1].radius).toBeCloseTo(7);
  expect(saved.features[0].profile.contours[1].center[0]).toBeCloseTo(20);
});
