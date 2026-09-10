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
it("dimensions a partial elliptical arc through the axis controls and native reopen", async () => {
  let doc = createEmptyPartDocument("Partial ellipse dimensions");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool("elliptical-arc");
  const direction = document.querySelector('[aria-label="Arc direction"]');
  direction.value = "clockwise";
  direction.dispatchEvent(new Event("change"));
  point(0, 0);
  point(5, 0);
  point(0, 3);
  point(5, 0);
  const dimension = (axis, value) => {
    tool("select");
    const entity = document.querySelector('[aria-label="Entity A"]');
    entity.value = JSON.stringify({ contour: 0, kind: "ellipse", index: 0 });
    click(`Select ellipse ${axis} axis`);
    expect(JSON.parse(entity.value).kind).toBe("line");
    const kind = document.querySelector('[aria-label="Constraint"]');
    kind.value = "length";
    kind.dispatchEvent(new Event("change"));
    document.querySelector('[aria-label="Constraint value"]').value = value;
    click("Apply constraint");
  };
  dimension("X", 14);
  dimension("Y", 8);
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
  expect(d.contours).toHaveLength(5);
  expect(d.contours[0].segments[0].radiusX).toBeCloseTo(7, 4);
  expect(d.contours[0].segments[0].radiusY).toBeCloseTo(4, 4);
  expect(d.constraints.filter((c) => c.kind === "length")).toHaveLength(2);
  open(() => doc, apply, doc.features[0]);
  expect(rendered()).toEqual(after);
  tool("select");
  document.querySelector('[aria-label="Entity A"]').value = JSON.stringify({
    contour: 0,
    kind: "ellipse",
    index: 0,
  });
  click("Select ellipse X axis");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  expect(doc.features[0].profile.contours).toHaveLength(5);
});
