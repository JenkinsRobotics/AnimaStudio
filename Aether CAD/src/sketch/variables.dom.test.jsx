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

it("edits draft variables with regenerated text, undo/redo, finish and cancel", async () => {
  const bytes = readFileSync(
    new URL(
      "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  const profile = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: Uint8Array.from(bytes).buffer,
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
    },
  );
  let doc = createEmptyPartDocument("Draft variables");
  doc.variables = [{ name: "label", kind: "string", expression: '"O"' }];
  profile.textItems[0].expression = "#label";
  doc.features.push({
    id: "s",
    name: "Text",
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
  const expression = field("Variable expression");
  expression.value = '"OO"';
  expression.dispatchEvent(new Event("input"));
  click("Finish sketch");
  expect(apply).not.toHaveBeenCalled();
  expect(document.body.textContent).toContain("Apply pending variable edits");
  click("Apply variables to sketch");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-contour")).toHaveLength(4),
  );
  expect(doc.variables[0].expression).toBe('"O"');
  expect(apply).not.toHaveBeenCalled();
  click("Undo");
  expect(field("Variable expression").value).toBe('"O"');
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(2);
  click("Redo");
  expect(field("Variable expression").value).toBe('"OO"');
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  expect(doc.variables[0].expression).toBe('"OO"');
  expect(doc.features[0].profile.textItems[0].text).toBe("OO");
  open(() => doc, apply, doc.features[0]);
  field("Variable expression").value = "#missing";
  field("Variable expression").dispatchEvent(new Event("input"));
  click("Apply variables to sketch");
  await vi.waitFor(() =>
    expect(document.body.textContent).toContain("Unknown variable #missing"),
  );
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(4);
  field("Variable expression").value = '"O"';
  field("Variable expression").dispatchEvent(new Event("input"));
  click("Apply variables to sketch");
  await vi.waitFor(() =>
    expect(document.querySelectorAll(".sketch-contour")).toHaveLength(2),
  );
  click("Cancel");
  expect(apply).toHaveBeenCalledTimes(1);
  expect(doc.variables[0].expression).toBe('"OO"');
});

it("adds typed definitions and removes unused variables", async () => {
  const { mountSketchVariables } = await import("./variables");
  const parent = document.createElement("aside");
  document.body.append(parent);
  let state = { drawing: { type: "drawing", contours: [] } };
  const commit = vi.fn((drawing, variables) => {
    state = { drawing, variables };
  });
  const panel = mountSketchVariables(parent, () => state, commit);
  click("Add variable");
  field("Variable name").value = "length";
  field("Variable type").value = "length";
  field("Variable expression").value = "2 in";
  click("Apply variables to sketch");
  await vi.waitFor(() => expect(commit).toHaveBeenCalledTimes(1));
  expect(state.variables).toEqual([
    { name: "length", kind: "length", expression: "2 in" },
  ]);
  click("Remove variable");
  click("Apply variables to sketch");
  await vi.waitFor(() => expect(commit).toHaveBeenCalledTimes(2));
  expect(state.variables).toEqual([]);
  panel.dispose();
  parent.remove();
});

it("regenerates a formula-driven radius through the draft variable editor", async () => {
  const { setDimensionExpression } = await import("@aether/core/sketch");
  const { evaluateDocumentVariables } = await import("@aether/core/document");
  let doc = createEmptyPartDocument("Radius variable");
  doc.variables = [{ name: "size", kind: "length", expression: "10 mm" }];
  const profile = setDimensionExpression(
    {
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
    "r",
    "#size/2",
    evaluateDocumentVariables(doc.variables),
  );
  doc.features.push({
    id: "s",
    name: "Circle",
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
  field("Variable expression").value = "20 mm";
  field("Variable expression").dispatchEvent(new Event("input"));
  click("Apply variables to sketch");
  await vi.waitFor(() =>
    expect(document.body.textContent).toContain(
      "Variables applied to this draft",
    ),
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect(saved.features[0].profile.contours[0].radius).toBeCloseTo(10);
  expect(saved.features[0].profile.constraints[0].valueExpression).toBe(
    "#size/2",
  );
});
