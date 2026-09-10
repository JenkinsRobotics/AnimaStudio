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
it("retains an arc midpoint through Split, reopen and editing its saved radius", async () => {
  let doc = createEmptyPartDocument("Arc midpoint");
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
          start: [-5, 0],
          segments: [{ type: "arc", middle: [0, 5], end: [5, 0] }],
        },
        { type: "path", start: [0, 5], segments: [] },
      ],
      constraints: [
        {
          id: "mid",
          kind: "midpoint",
          a: { contour: 0, kind: "arc", index: 0 },
          b: { contour: 1, kind: "point", index: 0 },
        },
        {
          id: "radius",
          kind: "radius",
          a: { contour: 0, kind: "arc", index: 0 },
          value: 5,
        },
      ],
    },
  });
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply, doc.features[0]);
  tool("split");
  point(-3, 4);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  expect(doc.features[0].profile.contours).toHaveLength(3);
  expect(doc.features[0].profile.contours[0].segments).toHaveLength(2);
  expect(
    doc.features[0].profile.constraints.find((c) => c.id === "mid").a,
  ).toMatchObject({ kind: "arc", contour: 2, index: 0 });
  open(() => doc, apply, doc.features[0]);
  const rendered = () =>
    [...document.querySelectorAll(".sketch-contour")].map((p) =>
      p.getAttribute("d"),
    );
  const before = rendered();
  const input = document.querySelector('input[data-dimension-id="radius"]');
  expect(input).toBeTruthy();
  input.value = "7";
  const update = [...input.parentElement.querySelectorAll("button")].find(
    (b) => b.textContent === "Update",
  );
  expect(update).toBeTruthy();
  update.click();
  const after = rendered();
  expect(after).not.toEqual(before);
  click("Undo");
  expect(rendered()).toEqual(before);
  click("Redo");
  expect(rendered()).toEqual(after);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  doc = parsePartDocument(serializePartDocument(doc));
  const d = doc.features[0].profile;
  expect(d.constraints.find((c) => c.id === "radius").value).toBe(7);
  expect(d.constraints.filter((c) => c.kind === "radius")).toHaveLength(1);
  expect(d.constraints.find((c) => c.id === "mid").a).toMatchObject({
    contour: 2,
    kind: "arc",
  });
  expect(d.contours[2].construction).toBe(true);
  expect(d.contours).toHaveLength(3);
  open(() => doc, apply, doc.features[0]);
  expect(rendered()).toEqual(after);
  click("Cancel");
});
