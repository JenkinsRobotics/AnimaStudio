import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { beforeAll, afterAll, expect, it, vi } from "vitest";
import { putSketchText, sketchConstraintState } from "@aether/core/sketch";
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

const field = (label) => document.querySelector(`[aria-label="${label}"]`);
const button = (label) =>
  [...document.querySelectorAll("button")].find((b) => b.textContent === label);

it("authors dimension formulas with variable updates, undo, annotation focus and native reopening", async () => {
  let doc = createEmptyPartDocument("Formula editor");
  doc.variables = [{ name: "size", kind: "length", expression: "20 mm" }];
  doc.features.push({
    id: "s",
    name: "Circle",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "drawing",
      contours: [{ type: "circle", center: [0, 0], radius: 5 }],
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
  const formula = field("Formula for r");
  formula.closest("details").open = true;
  formula.value = "#size/2";
  click("Apply formula");
  expect(field("radius value").value).toBe("10");
  expect(field("radius value").readOnly).toBe(true);
  expect(document.body.textContent).toContain("formula: #size/2");
  click("Undo");
  expect(field("radius value").readOnly).toBe(false);
  expect(field("radius value").value).toBe("5");
  click("Redo");
  expect(field("Formula for r").value).toBe("#size/2");
  field("Formula for r").value = "#size / 3";
  window.dispatchEvent(
    new CustomEvent("aether-sketch-edit-dimension", { detail: "r" }),
  );
  expect(document.activeElement).toBe(field("Formula for r"));
  expect(field("Formula for r").value).toBe("#size / 3");
  field("Formula for r").value = "20 deg";
  click("Apply formula");
  expect(document.body.textContent).toContain("must resolve to length");
  expect(field("radius value").value).toBe("10");
  field("Formula for r").value = "#size/2";
  field("Variable expression").value = "30 mm";
  field("Variable expression").dispatchEvent(new Event("input"));
  click("Apply variables to sketch");
  await vi.waitFor(() => expect(field("radius value").value).toBe("15"));
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  expect(doc.features[0].profile.constraints[0].valueExpression).toBe(
    "#size/2",
  );
  open(() => doc, apply, doc.features[0]);
  expect(field("Formula for r").value).toBe("#size/2");
  click("Remove formula");
  expect(field("radius value").readOnly).toBe(false);
  expect(field("radius value").value).toBe("15");
  field("radius value").value = "7";
  click("Update");
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(
    saved.features[0].profile.constraints[0].valueExpression,
  ).toBeUndefined();
  expect(saved.features[0].profile.contours[0].radius).toBeCloseTo(7);
});

it("edits the shared formula when invoked from a linked follower", async () => {
  const { setDimensionExpression } = await import("@aether/core/sketch");
  const { evaluateDocumentVariables } = await import("@aether/core/document");
  let doc = createEmptyPartDocument("Shared formula");
  doc.variables = [{ name: "size", kind: "length", expression: "10 mm" }];
  const profile = setDimensionExpression(
    {
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 5 },
        { type: "circle", center: [20, 0], radius: 10 },
      ],
      constraints: [
        {
          id: "driver",
          kind: "radius",
          a: { kind: "circle", contour: 0 },
          value: 5,
        },
        {
          id: "follower",
          kind: "radius",
          a: { kind: "circle", contour: 1 },
          valueFrom: "driver",
          valueScale: 2,
        },
      ],
    },
    "driver",
    "#size/2",
    evaluateDocumentVariables(doc.variables),
  );
  doc.features.push({
    id: "s",
    name: "Circles",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile,
  });
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  open(() => doc, apply, doc.features[0]);
  const row = document.querySelector('div[data-constraint-id="follower"]');
  expect(row.textContent).toContain("Edits shared driver driver");
  expect(row.querySelector('[aria-label="radius value"]').readOnly).toBe(true);
  field("Formula for follower").value = "#size/4";
  [...row.querySelectorAll("button")]
    .find((b) => b.textContent === "Apply formula")
    .click();
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(saved.features[0].profile.constraints[0].valueExpression).toBe(
    "#size/4",
  );
  expect(saved.features[0].profile.constraints[1].valueFrom).toBe("driver");
  expect(saved.features[0].profile.contours[0].radius).toBeCloseTo(2.5);
  expect(saved.features[0].profile.contours[1].radius).toBeCloseTo(5);
});
