import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { afterEach, expect, it, vi } from "vitest";
import { putSketchText } from "@aether/core/sketch";
import {
  createEmptyPartDocument,
  serializePartDocument,
  parsePartDocument,
} from "@aether/core/document";
import { mountTextResize } from "./text-resize";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom, handles;
afterEach(() => {
  handles?.dispose();
  dom?.window.close();
  vi.unstubAllGlobals();
});
async function setup() {
  dom = new JSDOM("<svg tabindex='0'></svg>");
  vi.stubGlobal("document", dom.window.document);
  vi.stubGlobal("window", dom.window);
  const svg = document.querySelector("svg");
  svg.getScreenCTM = () => ({ a: 1, b: 0, inverse: () => ({}) });
  svg.createSVGPoint = () => ({
    x: 0,
    y: 0,
    matrixTransform() {
      return { x: this.x, y: this.y };
    },
  });
  const bytes = readFileSync(
    new URL(
      "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  let drawing = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: Uint8Array.from(bytes).buffer,
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
      frameWidthMillimeters: 20,
    },
  );
  const commit = vi.fn((next) => {
      drawing = next;
    }),
    report = vi.fn();
  handles = mountTextResize(
    svg,
    () => drawing,
    () => drawing.textItems[0].id,
    commit,
    report,
  );
  handles.render();
  const pointer = (target, type, x, y) => {
    const e = new dom.window.MouseEvent(type, {
      button: 0,
      clientX: x,
      clientY: -y,
      bubbles: true,
      cancelable: true,
    });
    Object.defineProperty(e, "pointerId", { value: 1 });
    target.dispatchEvent(e);
  };
  const start = (kind) =>
    pointer(
      svg.querySelector(`[data-text-resize="${kind}"]`),
      "pointerdown",
      0,
      0,
    );
  return { svg, start, pointer, commit, report, drawing: () => drawing };
}
it("previews width and corner resizing then commits a native retained frame", async () => {
  const { svg, start, pointer, commit, drawing } = await setup();
  expect(svg.querySelectorAll("[data-text-resize]")).toHaveLength(3);
  start("width");
  pointer(svg, "pointermove", 30, 5);
  expect(commit).not.toHaveBeenCalled();
  expect(svg.querySelector(".sketch-text-resize path")).toBeTruthy();
  pointer(svg, "pointerup", 30, 5);
  expect(commit).toHaveBeenCalledTimes(1);
  expect(drawing().textItems[0]).toMatchObject({
    emSizeMillimeters: 10,
    frameWidthMillimeters: 30,
  });
  start("corner");
  pointer(svg, "pointermove", 40, 20);
  pointer(svg, "pointerup", 40, 20);
  expect(drawing().textItems[0]).toMatchObject({
    emSizeMillimeters: 20,
    frameWidthMillimeters: 40,
    originMillimeters: [0, 0],
  });
  const doc = createEmptyPartDocument("Resized text");
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
  ).toEqual(drawing().textItems[0]);
});
it("cancels without committing and rejects a locked-width resize", async () => {
  const { svg, start, pointer, commit, report, drawing } = await setup();
  start("height");
  pointer(svg, "pointermove", 10, 20);
  svg.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", { key: "Escape", bubbles: true }),
  );
  pointer(svg, "pointerup", 10, 20);
  expect(commit).not.toHaveBeenCalled();
  const contour = drawing().contours.findIndex(
    (c) => c.id === drawing().textItems[0].frameContourId,
  );
  drawing().constraints = [
    {
      id: "width",
      kind: "length",
      a: { contour, kind: "line", index: 0 },
      value: 20,
    },
  ];
  start("width");
  pointer(svg, "pointermove", 30, 5);
  pointer(svg, "pointerup", 30, 5);
  expect(commit).not.toHaveBeenCalled();
  expect(report.mock.calls.some(([s]) => s.length > 0)).toBe(true);
  expect(drawing().textItems[0].frameWidthMillimeters).toBe(20);
});
it("does not overwrite a concurrent sketch change or commit after disposal", async () => {
  const { svg, start, pointer, commit, report, drawing } = await setup();
  start("width");
  pointer(svg, "pointermove", 30, 5);
  drawing().contours.push({ type: "circle", center: [100, 100], radius: 3 });
  pointer(svg, "pointerup", 30, 5);
  expect(commit).not.toHaveBeenCalled();
  expect(report).toHaveBeenCalledWith(
    expect.stringContaining("sketch changed"),
  );
  start("height");
  pointer(svg, "pointermove", 10, 20);
  handles.dispose();
  handles = undefined;
  pointer(svg, "pointerup", 10, 20);
  expect(commit).not.toHaveBeenCalled();
  expect(svg.querySelector(".sketch-text-resize")).toBeNull();
});
