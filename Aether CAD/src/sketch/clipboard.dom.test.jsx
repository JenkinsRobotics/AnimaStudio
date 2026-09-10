import { createRequire } from "node:module";
import { beforeAll, afterAll, afterEach, expect, it, vi } from "vitest";
import {
  createEmptyPartDocument,
  parsePartDocument,
  serializePartDocument,
  createSketchClipboard,
  serializeSketchClipboard,
} from "@aether/core/document";
import { mountSketchClipboard } from "./clipboard";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom, clipboard;
beforeAll(() => {
  dom = new JSDOM('<div id="controls"></div><svg tabindex="0"></svg>');
  for (const key of [
    "window",
    "document",
    "HTMLElement",
    "Event",
    "CustomEvent",
    "location",
  ])
    vi.stubGlobal(key, dom.window[key]);
});
afterEach(() => clipboard?.dispose());
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
const click = (text) =>
  [...document.querySelectorAll("button")]
    .find((b) => b.textContent === text)
    .click();
const circle = {
  type: "drawing",
  contours: [{ id: "circle", type: "circle", center: [0, 0], radius: 5 }],
  constraints: [
    {
      id: "radius",
      kind: "radius",
      a: { kind: "circle", contour: 0 },
      value: 5,
      valueExpression: "#size",
    },
  ],
};
const variables = [{ name: "size", kind: "length", expression: "5 mm" }];
const payload = () =>
  serializeSketchClipboard(createSketchClipboard(circle, [0], variables));
function setup(definitions = []) {
  let state = {
    drawing: { type: "drawing", contours: [] },
    variables: definitions,
  };
  const commit = vi.fn((drawing, variables) => {
    state = { drawing, variables };
    clipboard.sync();
  });
  const svg = document.querySelector("svg");
  clipboard = mountSketchClipboard(
    document.querySelector("#controls"),
    svg,
    () => state,
    () => 0,
    () => true,
    commit,
    vi.fn(),
  );
  clipboard.sync();
  return { svg, commit, state: () => state };
}
function event(svg, type, text) {
  const data = new Map([["text/plain", text]]);
  const e = new Event(type, { bubbles: true, cancelable: true });
  Object.defineProperty(e, "clipboardData", {
    value: {
      getData: (key) => data.get(key) || "",
      setData: (key, value) => data.set(key, value),
    },
  });
  svg.dispatchEvent(e);
  return { e, data };
}
it("previews before committing geometry, dimensions and variables together; copies them back", () => {
  const { svg, commit, state } = setup();
  event(svg, "paste", payload());
  expect(commit).not.toHaveBeenCalled();
  expect(
    svg.querySelector(".sketch-clipboard-preview circle").getAttribute("cx"),
  ).toBe("10");
  const x = document.querySelector('[aria-label="Paste offset X (mm)"]');
  x.value = "25";
  x.dispatchEvent(new Event("input"));
  click("Apply paste");
  expect(commit).toHaveBeenCalledTimes(1);
  expect(state().drawing.contours[0].center).toEqual([25, 10]);
  expect(state().variables).toEqual(variables);
  expect(state().drawing.constraints[0].valueExpression).toBe("#size");
  expect(clipboard.pending()).toBe(false);
  const copied = event(svg, "copy", "");
  expect(copied.e.defaultPrevented).toBe(true);
  expect(JSON.parse(copied.data.get("text/plain")).variables).toEqual(
    variables,
  );
});
it("rejects conflicting variables without mutating the draft and cancels with Escape", () => {
  const { svg, commit } = setup([
    { name: "size", kind: "length", expression: "10 mm" },
  ]);
  event(svg, "paste", payload());
  expect(document.querySelector('[role="status"]').textContent).toContain(
    "different definition",
  );
  click("Apply paste");
  expect(commit).not.toHaveBeenCalled();
  svg.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", { key: "Escape", bubbles: true }),
  );
  expect(clipboard.pending()).toBe(false);
});
it("leaves text-field clipboard behavior alone and discards an async read after disposal", async () => {
  const { commit } = setup();
  const input = document.querySelector("input");
  expect(event(input, "paste", payload()).e.defaultPrevented).toBe(false);
  let resolve;
  vi.stubGlobal("navigator", {
    clipboard: {
      readText: () =>
        new Promise((r) => {
          resolve = r;
        }),
    },
  });
  click("Paste sketch");
  clipboard.dispose();
  resolve(payload());
  await Promise.resolve();
  expect(commit).not.toHaveBeenCalled();
  expect(document.querySelector(".sketch-clipboard-preview")).toBeNull();
});

it("integrates paste with workspace undo, redo and native document saving", async () => {
  document.body.innerHTML = '<div class="cad-studio-viewport"></div>';
  const { openSketchWorkspace } = await import("../sketch-workspace");
  let doc = createEmptyPartDocument("Clipboard project");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  openSketchWorkspace(() => doc, apply);
  click("Top (XY)");
  const svg = document.querySelector(".cad-sketch-workspace svg");
  event(svg, "paste", payload());
  click("Finish sketch");
  expect(apply).not.toHaveBeenCalled();
  click("Apply paste");
  expect(document.querySelector('[aria-label="Variable name"]').value).toBe(
    "size",
  );
  click("Undo");
  expect(document.querySelector('[aria-label="Variable name"]')).toBeNull();
  click("Redo");
  expect(document.querySelector('[aria-label="Variable name"]').value).toBe(
    "size",
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const reopened = parsePartDocument(serializePartDocument(doc));
  expect(reopened.variables).toEqual(variables);
  const profile = reopened.features.find((f) => f.type === "profile").profile;
  expect(profile.contours[0].center).toEqual([10, 10]);
  expect(profile.constraints[0].valueExpression).toBe("#size");
});
