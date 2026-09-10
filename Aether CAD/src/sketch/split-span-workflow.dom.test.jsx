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
it("splits a midpoint-constrained line with undo and retained native relationships", async () => {
  let doc = createEmptyPartDocument("Split span");
  doc.features.push({
    id: "sketch",
    name: "Sketch",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [0, 0],
          segments: [{ type: "line", end: [10, 0] }],
        },
        { type: "path", start: [5, 0], segments: [] },
      ],
      constraints: [
        {
          id: "mid",
          kind: "midpoint",
          a: { contour: 0, kind: "line", index: 0 },
          b: { contour: 1, kind: "point", index: 0 },
        },
      ],
    },
  });
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply, doc.features[0]);
  tool("split");
  point(3, 0);
  const rendered = () =>
    [...document.querySelectorAll(".sketch-contour")].map((p) =>
      p.getAttribute("d"),
    );
  const after = rendered();
  click("Undo");
  expect(rendered()).not.toEqual(after);
  click("Redo");
  expect(rendered()).toEqual(after);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const d = doc.features[0].profile;
  expect(d.contours[0].segments).toHaveLength(2);
  expect(d.contours).toHaveLength(3);
  expect(d.contours[2]).toMatchObject({
    construction: true,
    start: [0, 0],
    segments: [{ type: "line", end: [10, 0] }],
  });
  expect(d.constraints.find((c) => c.id === "mid")).toMatchObject({
    a: { contour: 2, kind: "line", index: 0 },
  });
  expect(d.constraints.filter((c) => c.kind === "coincident")).toHaveLength(2);
  open(() => doc, apply, doc.features[0]);
  expect(rendered()).toEqual(after);
  click("Cancel");
});
