import { createRequire } from "node:module";
import { beforeAll, afterAll, afterEach, expect, it, vi } from "vitest";
import * as core from "@aether/core/sketch";
import { mountTextPanel } from "./text-panel";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom, panel;
beforeAll(() => {
  dom = new JSDOM("<div id='controls'></div><svg tabindex='0'></svg>");
  for (const key of [
    "window",
    "document",
    "HTMLElement",
    "Event",
    "CustomEvent",
  ])
    vi.stubGlobal(key, dom.window[key]);
});
afterEach(() => {
  panel?.dispose();
  vi.restoreAllMocks();
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
const field = (label) => document.querySelector(`[aria-label="${label}"]`);
const button = (label) =>
  [...document.querySelectorAll("button")].find((b) => b.textContent === label);
const source = {
  type: "drawing",
  contours: [
    {
      type: "path",
      start: [0, 0],
      segments: [
        { type: "line", end: [2, 0] },
        { type: "line", end: [2, 1] },
        { type: "line", end: [0, 1] },
        { type: "line", end: [0, 0] },
      ],
    },
  ],
};
async function setup() {
  vi.spyOn(core, "sketchTextFontAscenderRatio").mockResolvedValue(1);
  const generate = vi
      .spyOn(core, "sketchTextOutline")
      .mockResolvedValue(source),
    commit = vi.fn(),
    svg = document.querySelector("svg");
  svg.innerHTML = "";
  svg.getScreenCTM = () => ({ a: 1, b: 0, inverse: () => ({}) });
  svg.createSVGPoint = () => ({
    x: 0,
    y: 0,
    matrixTransform() {
      return { x: this.x, y: this.y };
    },
  });
  panel = mountTextPanel(
    document.querySelector("#controls"),
    svg,
    () => ({
      type: "drawing",
      contours: [
        {
          type: "path",
          start: [30, 0],
          segments: [{ type: "arc", middle: [40, 10], end: [50, 0] }],
        },
      ],
    }),
    commit,
  );
  Object.defineProperty(field("Text font file"), "files", {
    value: [{ size: 1, arrayBuffer: async () => new ArrayBuffer(1) }],
    configurable: true,
  });
  field("Text font file").dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(button("Place text on canvas").disabled).toBe(false),
  );
  return { generate, commit, svg };
}
function pointer(svg, type, x, y) {
  svg.dispatchEvent(
    new dom.window.MouseEvent(type, {
      bubbles: true,
      cancelable: true,
      clientX: x,
      clientY: -y,
      button: 0,
    }),
  );
}
it("snaps baseline to arc centers with synchronous cached previews and an explicit insertion", async () => {
  const { generate, commit, svg } = await setup();
  const sketchClick = vi.fn();
  svg.addEventListener("click", sketchClick);
  button("Place text on canvas").click();
  pointer(svg, "pointermove", 40.4, 0.3);
  expect(field("Text baseline X (mm)").value).toBe("40");
  expect(field("Text baseline Y (mm)").value).toBe("0");
  expect(document.body.textContent).toContain("Snap: Arc center");
  expect(
    svg.querySelector(".sketch-text-preview path").getAttribute("d"),
  ).toContain("40");
  field("Text em size (mm)").value = "20";
  field("Text em size (mm)").dispatchEvent(new Event("input"));
  expect(generate).toHaveBeenCalledTimes(1);
  pointer(svg, "click", 40.4, 0.3);
  expect(button("Place text on canvas").getAttribute("aria-pressed")).toBe(
    "false",
  );
  expect(sketchClick).not.toHaveBeenCalled();
  expect(commit).not.toHaveBeenCalled();
  button("Insert text outlines").click();
  expect(commit).toHaveBeenCalledTimes(1);
  expect(commit.mock.calls[0][0].contours[1].start).toEqual([40, 0]);
  expect(commit.mock.calls[0][0].contours[1].segments[0].end).toEqual([80, 0]);
  svg.removeEventListener("click", sketchClick);
});
it("restores placement on Escape and releases event interception on disposal", async () => {
  const { svg } = await setup();
  field("Text baseline X (mm)").value = "12";
  field("Text baseline Y (mm)").value = "15";
  button("Place text on canvas").click();
  pointer(svg, "pointermove", 0.2, 0.3);
  expect(field("Text baseline X (mm)").value).toBe("0");
  svg.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", { key: "Escape", bubbles: true }),
  );
  expect(field("Text baseline X (mm)").value).toBe("12");
  expect(field("Text baseline Y (mm)").value).toBe("15");
  button("Place text on canvas").click();
  panel.dispose();
  const click = vi.fn();
  svg.addEventListener("click", click);
  pointer(svg, "click", 0, 0);
  expect(click).toHaveBeenCalledTimes(1);
  expect(svg.querySelector(".sketch-text-preview")).toBeNull();
  svg.removeEventListener("click", click);
  panel = undefined;
});
