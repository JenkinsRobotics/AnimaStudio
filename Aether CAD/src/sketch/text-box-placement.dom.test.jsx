import { createRequire } from "node:module";
import { beforeAll, afterAll, afterEach, expect, it, vi } from "vitest";
import { readFileSync } from "node:fs";
import {
  createEmptyPartDocument,
  serializePartDocument,
  parsePartDocument,
} from "@aether/core/document";
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

async function setup() {
  const svg = document.querySelector("svg"),
    commit = vi.fn((next) => {
      drawing = next;
    });
  let drawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [30, 0],
        segments: [{ type: "arc", middle: [40, 10], end: [50, 0] }],
      },
    ],
  };
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
    () => drawing,
    commit,
  );
  const bytes = readFileSync(
    new URL(
      "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  field("Sketch text").value = "O";
  Object.defineProperty(field("Text font file"), "files", {
    value: [
      {
        size: bytes.length,
        arrayBuffer: async () => Uint8Array.from(bytes).buffer,
      },
    ],
    configurable: true,
  });
  field("Text font file").dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(button("Draw text frame").disabled).toBe(false),
  );
  return { svg, commit, drawing: () => drawing };
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
it("draws a snapped live frame by dragging and saves real retained text with that frame", async () => {
  const { svg, commit, drawing } = await setup();
  const underlying = vi.fn();
  svg.addEventListener("click", underlying);
  button("Draw text frame").click();
  pointer(svg, "pointerdown", 40.3, 0.2);
  pointer(svg, "pointermove", 60, 20);
  expect(field("Text baseline X (mm)").value).toBe("40");
  expect(field("Text baseline Y (mm)").value).toBe("0");
  expect(field("Text em size (mm)").value).toBe("20");
  expect(field("Text frame width (mm)").value).toBe("20");
  const first = svg
    .querySelector(".sketch-text-preview path")
    .getAttribute("d");
  pointer(svg, "pointermove", 70, 30);
  expect(
    svg.querySelector(".sketch-text-preview path").getAttribute("d"),
  ).not.toBe(first);
  expect(svg.querySelector(".sketch-text-frame-preview")).toBeTruthy();
  expect(commit).not.toHaveBeenCalled();
  pointer(svg, "pointerup", 70, 30);
  pointer(svg, "click", 70, 30);
  expect(button("Draw text frame").getAttribute("aria-pressed")).toBe("false");
  expect(underlying).not.toHaveBeenCalled();
  button("Create editable text").click();
  await vi.waitFor(() => expect(commit).toHaveBeenCalledTimes(1));
  const item = drawing().textItems[0];
  expect(item).toMatchObject({
    emSizeMillimeters: 30,
    frameWidthMillimeters: 30,
    originMillimeters: [40, 0],
  });
  expect(
    drawing().contours.find((c) => c.id === item.frameContourId).construction,
  ).toBe(true);
  const doc = createEmptyPartDocument("Canvas text");
  doc.features.push({
    id: "s",
    name: "Text",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: drawing(),
  });
  expect(
    parsePartDocument(serializePartDocument(doc)).features[0].profile
      .textItems[0],
  ).toEqual(item);
  svg.removeEventListener("click", underlying);
});
it("supports two clicks and rejects a zero-area frame without committing", async () => {
  const { svg, commit } = await setup();
  button("Draw text frame").click();
  pointer(svg, "pointerdown", 0, 0);
  pointer(svg, "pointerup", 0, 0);
  pointer(svg, "click", 0, 0);
  expect(button("Draw text frame").getAttribute("aria-pressed")).toBe("true");
  pointer(svg, "pointermove", 20, 0);
  pointer(svg, "click", 20, 0);
  expect(button("Draw text frame").getAttribute("aria-pressed")).toBe("true");
  pointer(svg, "pointermove", 20, 15);
  pointer(svg, "click", 20, 15);
  expect(button("Draw text frame").getAttribute("aria-pressed")).toBe("false");
  expect(field("Text em size (mm)").value).toBe("15");
  expect(commit).not.toHaveBeenCalled();
});
it("restores fields on Escape or switching to baseline placement and cleans up listeners", async () => {
  const { svg, commit } = await setup();
  button("Draw text frame").click();
  pointer(svg, "click", 0, 0);
  pointer(svg, "pointermove", 20, 15);
  svg.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", { key: "Escape", bubbles: true }),
  );
  expect(field("Text frame width (mm)").value).toBe("");
  expect(field("Text em size (mm)").value).toBe("10");
  expect(svg.querySelector(".sketch-text-frame-preview")).toBeNull();
  button("Draw text frame").click();
  pointer(svg, "click", 0, 0);
  pointer(svg, "pointermove", 20, 15);
  button("Place text on canvas").click();
  expect(button("Draw text frame").getAttribute("aria-pressed")).toBe("false");
  expect(field("Text frame width (mm)").value).toBe("");
  panel.dispose();
  panel = undefined;
  pointer(svg, "pointermove", 80, 90);
  pointer(svg, "click", 80, 90);
  expect(commit).not.toHaveBeenCalled();
});

it("honors rotated text axes, reverse corners, and invalid angle recovery", async () => {
  const { svg } = await setup();
  field("Snap text placement").checked = false;
  field("Text rotation (degrees)").value = "90";
  button("Draw text frame").click();
  pointer(svg, "click", 0, 0);
  pointer(svg, "pointermove", 15, -20);
  expect(Number(field("Text frame width (mm)").value)).toBeCloseTo(20);
  expect(Number(field("Text em size (mm)").value)).toBeCloseTo(15);
  expect(Number(field("Text baseline X (mm)").value)).toBeCloseTo(15);
  expect(Number(field("Text baseline Y (mm)").value)).toBeCloseTo(-20);
  field("Text rotation (degrees)").value = "invalid";
  pointer(svg, "click", 15, -20);
  expect(button("Draw text frame").getAttribute("aria-pressed")).toBe("true");
  expect(document.body.textContent).toContain("finite text rotation");
  field("Text rotation (degrees)").value = "90";
  pointer(svg, "click", 15, -20);
  expect(button("Draw text frame").getAttribute("aria-pressed")).toBe("false");
});
