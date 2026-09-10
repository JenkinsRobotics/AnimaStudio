import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { it, expect, vi } from "vitest";
import { putSketchText, sketchTextEditState } from "@aether/core/sketch";
import {
  createEmptyPartDocument,
  serializePartDocument,
  parsePartDocument,
} from "@aether/core/document";
import { bindSelectionDrag } from "./selection-drag";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
it("drags real retained text through selection and preserves frame resizing after native reopen", async () => {
  const dom = new JSDOM("<svg></svg>"),
    svg = dom.window.document.querySelector("svg");
  try {
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
    const commit = vi.fn((before, after) => {
        drawing = after;
      }),
      report = vi.fn();
    const drag = bindSelectionDrag({
      svg,
      enabled: () => true,
      point: (e) => [e.clientX, e.clientY],
      drawing: () => drawing,
      tolerance: () => 0.1,
      preview: (d) => {
        drawing = d;
      },
      commit,
      select: vi.fn(),
      report,
    });
    const pointer = (type, x, y) => {
      const event = new dom.window.MouseEvent(type, {
        clientX: x,
        clientY: y,
        button: 0,
        bubbles: true,
      });
      Object.defineProperty(event, "pointerId", { value: 1 });
      svg.dispatchEvent(event);
    };
    pointer("pointerdown", 20, 10);
    pointer("pointermove", 30, 30);
    pointer("pointerup", 30, 30);
    expect(commit).toHaveBeenCalledTimes(1);
    expect(drag.consumeClick()).toBe(true);
    expect(drawing.textItems[0].originMillimeters).toEqual([10, 20]);
    expect(await sketchTextEditState(drawing, drawing.textItems[0].id)).toBe(
      "constrained",
    );
    const doc = createEmptyPartDocument("Dragged text");
    doc.features.push({
      id: "s",
      name: "Text",
      type: "profile",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: drawing,
    });
    drawing = parsePartDocument(serializePartDocument(doc)).features[0].profile;
    const contour = drawing.contours.findIndex(
      (c) => c.id === drawing.textItems[0].frameContourId,
    );
    drawing.constraints = [
      {
        id: "anchor",
        kind: "fix",
        a: { contour, kind: "point", index: 0 },
        point: [10, 20],
      },
      {
        id: "baseline",
        kind: "horizontal",
        a: { contour, kind: "line", index: 0 },
      },
    ];
    pointer("pointerdown", 30, 30);
    pointer("pointermove", 40, 40);
    pointer("pointerup", 40, 40);
    expect(commit).toHaveBeenCalledTimes(2);
    expect(drawing.textItems[0].emSizeMillimeters).toBeCloseTo(20);
    expect(drawing.textItems[0].frameWidthMillimeters).toBeCloseTo(30);
    expect(drawing.textItems[0].originMillimeters[0]).toBeCloseTo(10);
    expect(drawing.textItems[0].originMillimeters[1]).toBeCloseTo(20);
    expect(drawing.constraints).toHaveLength(2);
    expect(report).not.toHaveBeenCalled();
  } finally {
    dom.window.close();
  }
});
