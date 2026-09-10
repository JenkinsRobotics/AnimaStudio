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
it("splits an authored ellipse then dimensions both axes with undo and native reopen", async () => {
  let doc = createEmptyPartDocument("Ellipse split dimensions");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply);
  click("Top (XY)");
  tool("ellipse");
  point(0, 0);
  point(5, 0);
  point(0, 3);
  tool("split");
  point(3, 2.4);
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
  const before = document.querySelector(".sketch-contour").getAttribute("d");
  dimension("Y", 8);
  const after = document.querySelector(".sketch-contour").getAttribute("d");
  expect(after).not.toBe(before);
  click("Undo");
  expect(document.querySelector(".sketch-contour").getAttribute("d")).not.toBe(
    after,
  );
  click("Redo");
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    after,
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const drawing = doc.features[0].profile;
  expect(drawing.contours[0].segments).toHaveLength(3);
  for (const segment of drawing.contours[0].segments) {
    expect(segment.radiusX).toBeCloseTo(7, 4);
    expect(segment.radiusY).toBeCloseTo(4, 4);
  }
  expect(
    drawing.constraints.filter((c) => c.kind === "ellipse-locus"),
  ).toHaveLength(2);
  expect(drawing.constraints.filter((c) => c.kind === "quadrant")).toHaveLength(
    4,
  );
  open(() => doc, apply, doc.features[0]);
  expect(document.querySelector(".sketch-contour").getAttribute("d")).toBe(
    after,
  );
  tool("select");
  document.querySelector('[aria-label="Entity A"]').value = JSON.stringify({
    contour: 0,
    kind: "ellipse",
    index: 0,
  });
  click("Select ellipse X axis");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  expect(doc.features[0].profile.contours).toHaveLength(3);
  expect(
    doc.features[0].profile.constraints.filter((c) => c.kind === "quadrant"),
  ).toHaveLength(4);
});
