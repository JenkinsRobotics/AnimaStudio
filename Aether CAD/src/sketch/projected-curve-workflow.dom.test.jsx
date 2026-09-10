import { createRequire } from "node:module";
import {
  beforeAll,
  beforeEach,
  afterEach,
  afterAll,
  expect,
  it,
  vi,
} from "vitest";
import {
  createEmptyPartDocument,
  parsePartDocument,
  serializePartDocument,
  resolveProfileDrawing,
} from "@aether/core/document";
import { openSketchWorkspace } from "../sketch-workspace";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom, doc, apply;
beforeAll(() => {
  dom = new JSDOM("", { url: "http://localhost/cad/" });
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
beforeEach(() => {
  document.body.innerHTML = '<div class="cad-studio-viewport"></div>';
  doc = createEmptyPartDocument("Projected curve workflow");
  doc.features.push(
    {
      id: "source",
      name: "Source",
      type: "profile",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: {
        type: "drawing",
        contours: [
          {
            id: "path",
            type: "path",
            start: [10, 5],
            startVertexId: "start",
            segments: [
              { id: "edge", type: "line", end: [110, 5], endVertexId: "end" },
            ],
          },
        ],
      },
    },
    {
      id: "linked",
      name: "Linked",
      type: "profile",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: { type: "projection", sourceFeatureId: "source" },
    },
  );
  apply = vi.fn(async (next) => {
    doc = next;
  });
});
afterEach(() => {
  document.querySelectorAll("button").forEach((b) => {
    if (b.textContent === "Cancel") b.click();
  });
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
function click(label) {
  const b = [...document.querySelectorAll("button")].find(
    (b) => b.textContent === label && !b.closest("[hidden]"),
  );
  expect(b).toBeTruthy();
  b.click();
}
function drawPoint(x, y) {
  const svg = document.querySelector('[aria-label="2D sketch canvas"]');
  svg.createSVGPoint = () => ({
    x: 0,
    y: 0,
    matrixTransform() {
      return { x: this.x, y: this.y };
    },
  });
  svg.getScreenCTM = () => ({ a: 1, b: 0, inverse: () => ({}) });
  for (const type of ["pointermove", "click"])
    svg.dispatchEvent(
      new dom.window.MouseEvent(type, {
        clientX: x,
        clientY: -y,
        bubbles: true,
      }),
    );
}
it("draws on a projected edge, undoes/redoes, saves and reopens a live sliding relation", async () => {
  const originalSource = structuredClone(doc.features[0]);
  openSketchWorkspace(() => doc, apply, doc.features[1]);
  window.dispatchEvent(
    new CustomEvent("aether-sketch-tool", { detail: "line" }),
  );
  drawPoint(37.3, 5.1);
  drawPoint(37.3, 30);
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  click("Undo");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(0);
  click("Redo");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const authored = doc.features[1].profile.authored;
  expect(authored.projectionContext).toBeUndefined();
  expect(authored.contours[0].start).toEqual([37.3, 5]);
  const relation = authored.constraints.find(
    (c) => c.b?.projectedContourId === "path",
  );
  expect(relation).toMatchObject({
    kind: "coincident",
    b: {
      kind: "curve",
      segmentId: "edge",
      sliding: true,
      parameter: expect.closeTo(0.273),
    },
  });
  expect(doc.features[0]).toEqual(originalSource);
  doc.features[0].profile.contours[0].start = [10, 8];
  doc.features[0].profile.contours[0].segments[0].end = [110, 8];
  openSketchWorkspace(() => doc, apply, doc.features[1]);
  const coordinates = document
    .querySelector(".sketch-contour")
    .getAttribute("d")
    .match(/[-+]?[0-9]*\.?[0-9]+(?:e[-+]?[0-9]+)?/gi)
    .map(Number);
  expect(coordinates[1]).toBeCloseTo(-8);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  const reopened = parsePartDocument(serializePartDocument(doc));
  const result = resolveProfileDrawing(reopened.features, "linked");
  expect(result.contours[1].start[1]).toBeCloseTo(8);
});

it("persists a pointer-created circle quadrant relation through source edits", async () => {
  doc.features[0].profile = {
    type: "drawing",
    contours: [{ id: "rim", type: "circle", center: [50, 50], radius: 20 }],
  };
  openSketchWorkspace(() => doc, apply, doc.features[1]);
  window.dispatchEvent(
    new CustomEvent("aether-sketch-tool", { detail: "line" }),
  );
  drawPoint(50.1, 70.2);
  drawPoint(50, 100);
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  doc = parsePartDocument(serializePartDocument(doc));
  const relation = doc.features[1].profile.authored.constraints.find(
    (c) => c.kind === "quadrant",
  );
  expect(relation).toMatchObject({
    quadrant: 1,
    b: { projectedContourId: "rim", kind: "circle" },
  });
  const circle = doc.features[0].profile.contours[0];
  circle.center = [60, 60];
  circle.radius = 25;
  openSketchWorkspace(() => doc, apply, doc.features[1]);
  const coordinates = document
    .querySelector(".sketch-contour")
    .getAttribute("d")
    .match(/[-+]?[0-9]*\.?[0-9]+(?:e[-+]?[0-9]+)?/gi)
    .map(Number);
  expect(coordinates[0]).toBeCloseTo(60);
  expect(coordinates[1]).toBeCloseTo(-85);
  click("Cancel");
  expect(apply).toHaveBeenCalledTimes(1);
});
