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
it.each(["length", "radius", "angle"])(
  "creates and edits a calculated %s constraint",
  async (kind) => {
    let doc = createEmptyPartDocument("Calculated constraint");
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
      if (kind === "angle") {
        click("New contour");
        point(10, 10);
        point(10, 20);
        b = { contour: 1, kind: "line", index: 0 };
      }
    }
    window.dispatchEvent(
      new CustomEvent("aether-sketch-constraint", { detail: kind }),
    );
    document.querySelector('[aria-label="Entity A"]').value = JSON.stringify(a);
    if (b)
      document.querySelector('[aria-label="Entity B"]').value =
        JSON.stringify(b);
    const entry = document.querySelector('[aria-label="Constraint value"]');
    entry.value = "1/0";
    click("Apply constraint");
    expect(document.querySelectorAll("input[data-dimension-id]")).toHaveLength(
      0,
    );
    entry.value = kind === "angle" ? "45+45" : "(12+4)/2";
    click("Apply constraint");
    const value = () =>
      document.querySelector(`input[aria-label="${kind} value"]`);
    expect(Number(value().value)).toBe(kind === "angle" ? 90 : 8);
    value().value = "2+";
    value().parentElement.querySelector("button").click();
    expect(document.querySelector('[role="status"]').textContent).toContain(
      "Enter numbers",
    );
    value().value = kind === "angle" ? "180/3" : "2^3+2";
    value().parentElement.querySelector("button").click();
    const expected = kind === "angle" ? 60 : 10;
    expect(Number(value().value)).toBeCloseTo(expected);
    click("Undo");
    expect(Number(value().value)).toBe(kind === "angle" ? 90 : 8);
    click("Redo");
    click("Finish sketch");
    await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
    doc = parsePartDocument(serializePartDocument(doc));
    expect(
      doc.features[0].profile.constraints.find((c) => c.kind === kind).value,
    ).toBeCloseTo(expected);
  },
);
