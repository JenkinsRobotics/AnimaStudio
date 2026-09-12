import { createRequire } from "node:module";
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { createEmptyPartDocument } from "@aether/core/document";
import { drawingConstraintKinds } from "@aether/core/sketch";

/**
 * Onshape-parity audit for the SKETCH and PLANE features.
 *
 * Two things are checked, and only things that can actually be verified:
 *   1. Window anatomy against `core/ui/gallery/features/{sketch,plane}.ts`,
 *      which this repo treats as the design authority.
 *   2. The declared capability inventory — the sketch tools and constraints the
 *      product claims to offer. Pinning these means a tool cannot quietly
 *      disappear, and a reviewer can diff the list against Onshape's toolbar.
 *
 * Where the product is behind Onshape the gap is asserted explicitly rather
 * than skipped, so it stays visible instead of being rediscovered.
 */
const require = createRequire(new URL("../../core/ui/package.json", import.meta.url));
const { JSDOM } = require("jsdom");

let dom, openSketch, openPlane, doc, apply;

beforeAll(async () => {
  dom = new JSDOM("<!doctype html><html><body></body></html>", {
    url: "http://localhost/cad/index.html",
  });
  for (const key of [
    "window", "document", "HTMLElement", "HTMLTextAreaElement",
    "CustomEvent", "Event", "KeyboardEvent", "location", "crypto",
  ])
    vi.stubGlobal(key, dom.window[key]);
  openSketch = (await import("./sketch-workspace")).openSketchWorkspace;
  openPlane = (await import("./plane-window")).openPlaneWindow;
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
beforeEach(() => {
  document.body.innerHTML = '<div class="cad-studio-viewport"></div>';
  doc = createEmptyPartDocument("Part");
  apply = vi.fn(async (next) => {
    doc = next;
  });
});

describe("Sketch feature", () => {
  it("opens with the gallery's Sketch anatomy and nothing else", () => {
    openSketch(() => doc, apply);
    const panel = document.querySelector(".cad-sketch-window");
    expect(panel, "sketch feature window did not open").toBeTruthy();

    // Gallery: an "Sketch plane" entities box, then exactly four display rows.
    expect(panel.textContent).toContain("Sketch plane");
    for (const label of [
      "Disable imprinting",
      "Show constraints",
      "Show expressions",
      "Show errors",
    ])
      expect(panel.querySelector(`[aria-label="${label}"]`), `missing row: ${label}`).toBeTruthy();

    // Onshape shows an empty selection box, not a prompt paragraph.
    expect(panel.querySelector('[role="status"]').textContent).toBe("");
    // And nothing is pre-selected for the user.
    expect(panel.querySelector(".aui-feature-entity")).toBeNull();
  });

  it("is invalid until it has a plane, like an Onshape feature with no selection", () => {
    openSketch(() => doc, apply);
    const panel = document.querySelector(".cad-sketch-window");
    expect(panel.getAttribute("data-feature-state")).toBe("invalid");
    window.dispatchEvent(new CustomEvent("aether-sketch-plane", { detail: "XY" }));
    expect(panel.getAttribute("data-feature-state")).toBeNull();
  });

  it("offers Onshape's sketch entity set", async () => {
    const { sketchVariantTools } = await import("@aether/core/sketch");
    const { modificationTools, directModificationTools } = await import("./sketch/tool-instructions");
    const { contextualDrawingTools } = await import("./sketch/tangent-arc-tool");
    const tools = new Set([
      "select", "line", "arc", "circle", "rectangle",
      ...sketchVariantTools, ...contextualDrawingTools,
      ...modificationTools, ...directModificationTools,
    ]);

    // Entities Onshape's sketch toolbar creates.
    for (const tool of [
      "line", "rectangle", "center-rectangle", "aligned-rectangle",
      "circle", "three-point-circle", "arc", "center-arc", "tangent-arc",
      "ellipse", "elliptical-arc", "cubic-bezier", "fit-spline",
      "point", "midpoint-line", "inscribed-polygon", "circumscribed-polygon", "slot",
    ])
      expect(tools.has(tool), `missing sketch entity tool: ${tool}`).toBe(true);

    // Editing tools Onshape puts in the same toolbar.
    for (const tool of [
      "trim", "extend", "offset", "mirror", "fillet", "chamfer",
      "linear-pattern", "circular-pattern", "transform", "split",
    ])
      expect(tools.has(tool), `missing sketch editing tool: ${tool}`).toBe(true);
  });

  it("offers Onshape's constraint and dimension set", () => {
    const kinds = new Set(drawingConstraintKinds);
    for (const kind of [
      "coincident", "concentric", "parallel", "perpendicular", "tangent",
      "equal", "midpoint", "horizontal", "vertical", "symmetric", "fix",
      "curvature", "normal",
    ])
      expect(kinds.has(kind), `missing constraint: ${kind}`).toBe(true);

    for (const kind of [
      "distance", "horizontal-distance", "vertical-distance",
      "length", "radius", "diameter", "angle",
    ])
      expect(kinds.has(kind), `missing dimension: ${kind}`).toBe(true);
  });
});

describe("Plane feature", () => {
  const open = async () => {
    await openPlane(() => doc, apply);
    await vi.waitFor(() => expect(doc.features.length).toBeGreaterThan(0));
    return document.querySelector(".cad-plane-window");
  };

  it("opens with the gallery's Plane anatomy", async () => {
    const panel = await open();
    expect(panel.textContent).toContain("Entities");
    expect(panel.querySelector('[aria-label="Plane method"]')).toBeTruthy();
    expect(panel.querySelector('[aria-label="Offset distance"]')).toBeTruthy();
    expect(panel.querySelector('[aria-label="Flip normal"]')).toBeTruthy();
    // Gallery starts each feature un-committed and, per Onshape, unselected.
    expect(panel.querySelector(".aui-feature-entity")).toBeNull();
  });

  it("refuses to commit until the method's reference count is satisfied", async () => {
    const panel = await open();
    const accept = panel.querySelector('[aria-label="Apply plane"]');
    const error = () => panel.querySelector(".aui-feature-error")?.textContent ?? "";

    expect(accept.disabled).toBe(true);
    expect(error()).toContain("exactly 1 reference plane");

    window.dispatchEvent(new CustomEvent("aether-sketch-plane", { detail: "XY" }));
    expect(accept.disabled).toBe(false);

    panel.querySelector('[aria-label="Plane method"]').click();
    [...panel.querySelectorAll(".aui-feature-picker-menu button")]
      .find((b) => b.textContent === "Mid plane")
      .click();
    expect(accept.disabled).toBe(true);
    expect(error()).toContain("exactly 2 reference planes");
  });

  it("previews the plane it describes and highlights what it is using", async () => {
    const previews = [];
    const highlights = [];
    const onPreview = (e) => previews.push(e.detail.frame);
    const onHighlight = (e) => highlights.push(e.detail.references);
    window.addEventListener("aether-plane-preview", onPreview);
    window.addEventListener("aether-plane-highlight", onHighlight);
    try {
      const panel = await open();
      expect(previews.at(-1), "incomplete plane must not draw").toBeNull();
      window.dispatchEvent(new CustomEvent("aether-sketch-plane", { detail: "XZ" }));
      // Real geometry, resolved through the engine, not a decoration.
      expect(previews.at(-1)).toMatchObject({ normal: [0, -1, 0] });
      // Orange-selection parity: the viewport is told exactly what is in use.
      expect(highlights.at(-1)).toEqual([{ kind: "principal", plane: "XZ" }]);
      void panel;
    } finally {
      window.removeEventListener("aether-plane-preview", onPreview);
      window.removeEventListener("aether-plane-highlight", onHighlight);
    }
  });

  it("offers Offset, Mid plane, Three point and Angle", async () => {
    const panel = await open();
    panel.querySelector('[aria-label="Plane method"]').click();
    const methods = [...panel.querySelectorAll(".aui-feature-picker-menu button")].map(
      (b) => b.textContent,
    );
    expect(methods).toEqual(["Offset", "Mid plane", "Three point", "Angle"]);
    // Still absent vs Onshape: Curve point and Tangent, both of which need
    // curve/surface picking that the selection layer does not produce yet.
  });

  it("builds a three point plane from picked vertices", async () => {
    const panel = await open();
    panel.querySelector('[aria-label="Plane method"]').click();
    [...panel.querySelectorAll(".aui-feature-picker-menu button")]
      .find((b) => b.textContent === "Three point")
      .click();
    const accept = panel.querySelector('[aria-label="Apply plane"]');
    expect(accept.disabled).toBe(true);
    expect(panel.querySelector(".aui-feature-error").textContent).toContain("exactly 3 points");

    const point = (id, positionMillimeters, label) => ({
      partId: "part-1", candidateId: id, label, positionMillimeters,
    });
    window.dispatchEvent(
      new CustomEvent("aether-plane-geometry", {
        detail: {
          points: [
            point("v1", [0, 0, 0], "Vertex 1"),
            point("v2", [10, 0, 0], "Vertex 2"),
            point("v3", [0, 10, 0], "Vertex 3"),
          ],
          axis: null,
        },
      }),
    );
    expect([...panel.querySelectorAll(".aui-feature-entity")].map((e) => e.textContent)).toEqual([
      "Vertex 1×", "Vertex 2×", "Vertex 3×",
    ]);
    expect(accept.disabled).toBe(false);

    accept.click();
    await vi.waitFor(() => expect(apply).toHaveBeenCalled());
    expect(doc.features.at(-1).definition).toMatchObject({ method: "three-point" });
  });

  it("builds an angled plane from an edge and a reference plane", async () => {
    const panel = await open();
    panel.querySelector('[aria-label="Plane method"]').click();
    [...panel.querySelectorAll(".aui-feature-picker-menu button")]
      .find((b) => b.textContent === "Angle")
      .click();
    const accept = panel.querySelector('[aria-label="Apply plane"]');
    const error = () => panel.querySelector(".aui-feature-error")?.textContent ?? "";
    expect(error()).toContain("edge to rotate about");

    window.dispatchEvent(
      new CustomEvent("aether-plane-geometry", {
        detail: {
          points: [],
          axis: {
            partId: "part-1", candidateId: "e1", label: "Edge 4",
            originMillimeters: [0, 0, 0], directionMillimeters: [1, 0, 0],
          },
        },
      }),
    );
    // An edge alone is not a plane: it still needs the reference to measure from.
    expect(error()).toContain("exactly 1 reference plane");

    window.dispatchEvent(new CustomEvent("aether-sketch-plane", { detail: "XY" }));
    expect([...panel.querySelectorAll(".aui-feature-entity")].map((e) => e.textContent)).toEqual([
      "Edge 4×", "Top plane×",
    ]);
    panel.querySelector('[aria-label="Plane angle"]').value = "30";
    panel.querySelector('[aria-label="Plane angle"]').dispatchEvent(new dom.window.Event("input"));
    expect(accept.disabled).toBe(false);

    accept.click();
    await vi.waitFor(() => expect(apply).toHaveBeenCalled());
    expect(doc.features.at(-1).definition).toMatchObject({
      method: "angle",
      angleDegrees: 30,
      axis: { kind: "axis", candidateId: "e1" },
      reference: { kind: "principal", plane: "XY" },
    });
  });

  it("builds a plane offset from a model face, not just from a datum", async () => {
    const panel = await open();
    // A planar face on a solid, picked in the viewport. The frame is captured
    // at pick time because face geometry lives in the kernel, not the document.
    window.dispatchEvent(
      new CustomEvent("aether-sketch-face", {
        detail: {
          partId: "part-1",
          faceId: 7,
          label: "Bracket · Face 7",
          frame: { originMillimeters: [0, 0, 12], xDirection: [1, 0, 0], normal: [0, 0, 1] },
        },
      }),
    );
    expect([...panel.querySelectorAll(".aui-feature-entity")].map((e) => e.textContent)).toEqual([
      "Bracket · Face 7×",
    ]);
    expect(panel.querySelector('[aria-label="Apply plane"]').disabled).toBe(false);

    panel.querySelector('[aria-label="Offset distance"]').value = "5";
    panel.querySelector('[aria-label="Apply plane"]').click();
    await vi.waitFor(() => expect(apply).toHaveBeenCalled());
    const saved = doc.features.at(-1);
    expect(saved.definition).toMatchObject({
      method: "offset",
      distanceMillimeters: 5,
      reference: { kind: "face", partId: "part-1", faceId: 7 },
    });
  });

  it("resolves a face-referenced plane through the engine", async () => {
    const { resolvePlaneFrame } = await import("@aether/core/document");
    const frame = resolvePlaneFrame(
      {
        id: "p1",
        type: "plane",
        name: "Plane 1",
        plane: "XY",
        offsetMillimeters: 0,
        suppressed: false,
        definition: {
          method: "offset",
          distanceMillimeters: 5,
          reference: {
            kind: "face",
            partId: "part-1",
            faceId: 7,
            frame: { originMillimeters: [0, 0, 12], xDirection: [1, 0, 0], normal: [0, 0, 1] },
          },
        },
      },
      [],
    );
    // 12 mm face + 5 mm offset along its normal.
    expect(frame.originMillimeters).toEqual([0, 0, 17]);
    expect(frame.normal).toEqual([0, 0, 1]);
  });

  it("rejects a face reference that carries no usable frame", async () => {
    const { validatePlaneDefinition } = await import("@aether/core/document");
    const feature = (reference) => ({
      id: "p1", type: "plane", name: "Plane 1", plane: "XY",
      offsetMillimeters: 0, suppressed: false,
      definition: { method: "offset", distanceMillimeters: 5, reference },
    });
    expect(() =>
      validatePlaneDefinition(feature({ kind: "face", partId: "p", faceId: 1 }), new Set()),
    ).toThrow(/captured frame/);
    expect(() =>
      validatePlaneDefinition(
        feature({
          kind: "face", partId: "p", faceId: 1,
          frame: { originMillimeters: [0, 0, 0], xDirection: [1, 0, 0], normal: [0, 0, 0] },
        }),
        new Set(),
      ),
    ).toThrow(/non-degenerate normal/);
  });
});

// Onshape infers a relationship while you draw, shows it as a glyph at the
// cursor, and APPLIES it when you commit. All three halves are checked here.
describe("Inferred constraints", () => {
  const canvas = () => document.querySelector('[aria-label="2D sketch canvas"]');
  /** Drive the real pointer path. Inference runs on pointer input, so the test
   *  connects the same surface bridge the viewer provides in the app. */
  const startSketch = () => {
    const onSurface = (e) =>
      e.detail.connect({
        toSketch: (x, y) => [x, -y],
        scaleAt: () => 1,
        updateBounds: () => {},
      });
    window.addEventListener("aether-sketch-surface", onSurface);
    openSketch(() => doc, apply);
    window.dispatchEvent(new CustomEvent("aether-sketch-plane", { detail: "XY" }));
    window.removeEventListener("aether-sketch-surface", onSurface);
    window.dispatchEvent(new CustomEvent("aether-sketch-tool", { detail: "line" }));
  };
  const at = (x, y) =>
    canvas().dispatchEvent(new dom.window.MouseEvent("pointermove", { clientX: x, clientY: y }));
  const clickAt = (x, y) =>
    canvas().dispatchEvent(new dom.window.MouseEvent("click", { clientX: x, clientY: y }));

  it("shows a horizontal glyph while drawing, then commits the constraint", async () => {
    startSketch();
    clickAt(20, -20);
    // Off horizontal by a hair: snapping pulls it flat and names the relation.
    at(60, -21);
    const preview = document.querySelector(".sketch-preview-layer");
    expect(preview, "no preview layer rendered").toBeTruthy();
    expect(preview.textContent, "no inferred relationship shown").toContain("Horizontal");
    expect(canvas().getAttribute("data-inferred-constraint")).toBe("Horizontal");
    expect(preview.querySelector(".sketch-inference-glyph")).toBeTruthy();

    clickAt(60, -21);
    document.querySelector('[aria-label="Finish sketch"]').click();
    await vi.waitFor(() => expect(apply).toHaveBeenCalled());

    // The committed sketch really carries the constraint, not just a hint.
    const profile = doc.features.at(-1).profile;
    const horizontal = (profile.constraints ?? []).filter((c) => c.kind === "horizontal");
    expect(horizontal.length, "no horizontal constraint was applied").toBeGreaterThan(0);
  });

  it("draws a mark on committed constraints, and Show constraints hides them", () => {
    startSketch();
    clickAt(20, -20);
    at(60, -21);
    clickAt(60, -21);

    const marks = () => canvas().querySelectorAll("[data-constraint-mark]");
    expect(marks().length, "committed constraint has no mark").toBeGreaterThan(0);
    expect(canvas().querySelector('[data-constraint-mark="horizontal"]')).toBeTruthy();

    // The row is a live toggle now, not a disabled "Planned" checkbox.
    const toggle = document.querySelector('[aria-label="Show constraints"]');
    expect(toggle.disabled).toBe(false);
    expect(toggle.checked).toBe(true);
    toggle.checked = false;
    toggle.dispatchEvent(new dom.window.Event("change"));
    expect(marks().length).toBe(0);
  });
});
