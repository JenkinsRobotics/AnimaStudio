import { createRequire } from "node:module";
import { afterAll, beforeAll, expect, it, vi } from "vitest";
import { mountSelectionConstraintStatus } from "./selection-constraint-status";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom;
beforeAll(() => {
  dom = new JSDOM("<main></main>");
  vi.stubGlobal("document", dom.window.document);
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});

it("shows missing projected edge identities and recovers when the source returns", () => {
  const parent = document.querySelector("main");
  const update = mountSelectionConstraintStatus(parent);
  const output = parent.querySelector('[role="status"]');
  const drawing = {
    type: "drawing",
    contours: [],
    projectionContext: [
      {
        type: "path",
        id: "source",
        sourceLayer: "Reference",
        start: [0, 0],
        segments: [{ type: "arc", id: "edge", middle: [1, 1], end: [2, 0] }],
      },
    ],
  };
  const ref = {
    kind: "arc",
    contour: -1,
    projectedContourId: "source",
    index: 0,
    segmentId: "edge",
  };
  update(drawing, ref);
  expect(output.dataset.state).toBe("projected");
  expect(output.textContent).toContain("read-only source geometry");
  expect(output.textContent).toContain("Source layer: Reference");
  const saved = structuredClone(drawing.projectionContext);
  drawing.projectionContext[0].segments[0].id = "replacement";
  update(drawing, ref);
  expect(output.dataset.state).toBe("invalid");
  expect(output.textContent).toContain("Broken segment reference: edge");
  expect(output.textContent).not.toContain("read-only source geometry");
  drawing.projectionContext = [];
  update(drawing, ref);
  expect(output.dataset.state).toBe("invalid");
  expect(output.textContent).toContain(
    "Broken projected constraint reference: source",
  );
  drawing.projectionContext = saved;
  update(drawing, ref);
  expect(output.dataset.state).toBe("projected");
  expect(output.textContent).not.toContain("unavailable");
  update(drawing, null);
  expect(output.hidden).toBe(true);
  expect(output.textContent).toBe("");
});
