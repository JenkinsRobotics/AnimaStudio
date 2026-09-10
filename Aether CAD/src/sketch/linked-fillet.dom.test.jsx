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
it("edits a reopened linked fillet without replacing its relationship", async () => {
  const { linkSketchDimension } = await import("@aether/core/sketch");
  let doc = createEmptyPartDocument("Linked fillet");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool("line");
  point(-10, 0);
  point(0, 0);
  point(0, 10);
  tool("fillet");
  point(0, 0);
  click("Apply modification");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const feature = doc.features[0],
    drawing = feature.profile;
  const radiusId = drawing.constraints.find((c) => c.kind === "radius").id;
  const contour = drawing.contours.length;
  drawing.contours.push({ type: "circle", center: [30, 30], radius: 1 });
  drawing.constraints.push({
    id: "driver",
    kind: "radius",
    a: { contour, kind: "circle" },
    value: 1,
  });
  feature.profile = linkSketchDimension(drawing, radiusId, "driver", 2, 0);
  doc = parsePartDocument(serializePartDocument(doc));
  open(() => doc, apply, doc.features[0]);
  const arc = doc.features[0].profile.contours[0].segments.find(
    (s) => s.type === "arc",
  );
  tool("fillet");
  point(...arc.middle);
  expect(
    document
      .querySelector('[aria-label="Fillet radius handle"]')
      .getAttribute("aria-valuenow"),
  ).toBe("2");
  const radius = document.querySelector('[aria-label="Fillet radius (mm)"]');
  radius.value = "3";
  radius.dispatchEvent(new Event("input", { bubbles: true }));
  click("Apply modification");
  click("Undo");
  click("Redo");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  doc = parsePartDocument(serializePartDocument(doc));
  const linked = doc.features[0].profile.constraints.find(
    (c) => c.id === radiusId,
  );
  expect(linked).toMatchObject({ valueFrom: "driver", valueScale: 2 });
  expect(linked.value).toBeUndefined();
  expect(
    doc.features[0].profile.constraints.find((c) => c.id === "driver").value,
  ).toBe(1.5);
});
