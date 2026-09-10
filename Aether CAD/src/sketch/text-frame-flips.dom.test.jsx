import { contourPath } from "./svg-geometry";
import { sketchTextOutline } from "@aether/core/sketch";
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

const normalizedPath = (value) =>
  value.replace(/-?\d*\.?\d+(?:e[+-]?\d+)?/gi, (n) =>
    String(Number(Number(n).toFixed(9))),
  );
it("previews center flips inside the frame and preserves their mode through native save", async () => {
  const bytes = Uint8Array.from(
    readFileSync(
      new URL(
        "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
        import.meta.url,
      ),
    ),
  ).buffer;
  const profile = await putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      fontBytes: bytes,
      emSizeMillimeters: 10,
      originMillimeters: [0, 0],
      frameWidthMillimeters: 12,
    },
  );
  let doc = createEmptyPartDocument("Center flips");
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
  const select = field("Saved sketch text");
  select.value = select.options[1].value;
  select.dispatchEvent(new Event("change"));
  await vi.waitFor(() =>
    expect(document.querySelector(".sketch-text-preview path")).toBeTruthy(),
  );
  expect(field("Flip about frame center").checked).toBe(true);
  for (const label of ["Flip text horizontally", "Flip text vertically"]) {
    field(label).checked = true;
    field(label).dispatchEvent(new Event("change"));
  }
  const expected = await sketchTextOutline(bytes, "O", {
    emSizeMillimeters: 10,
    frameWidthMillimeters: 12,
    flipAboutFrame: true,
    flipHorizontal: true,
    flipVertical: true,
  });
  expect(
    normalizedPath(
      document.querySelector(".sketch-text-preview path").getAttribute("d"),
    ),
  ).toBe(normalizedPath(contourPath(expected.contours[0])));
  const originalFrame = profile.contours.find(
    (c) => c.id === profile.textItems[0].frameContourId,
  );
  expect(
    document.querySelector(".sketch-text-frame-preview").getAttribute("d"),
  ).toBe(contourPath(originalFrame));
  click("Update editable text");
  await vi.waitFor(() =>
    expect(
      [...document.querySelectorAll(".sketch-contour")].some(
        (p) => p.getAttribute("d") === contourPath(expected.contours[0]),
      ),
    ).toBe(true),
  );
  click("Finish sketch");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const saved = parsePartDocument(serializePartDocument(doc)).features[0]
    .profile;
  expect(saved.textItems[0]).toMatchObject({
    flipAboutFrame: true,
    flipHorizontal: true,
    flipVertical: true,
  });
  expect(
    saved.contours.find((c) => c.id === saved.textItems[0].frameContourId)
      .start,
  ).toEqual(originalFrame.start);
});
