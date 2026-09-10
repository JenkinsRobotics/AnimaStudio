import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { beforeAll, afterAll, expect, it, vi } from "vitest";
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
it("loads real bundled styles and preserves a style change in retained text", async () => {
  const originalFetch = globalThis.fetch;
  const fetched = vi.fn(async (url) => {
    const style = String(url).includes("NotoSans-Bold") ? "Bold" : "Regular";
    return {
      ok: true,
      arrayBuffer: async () =>
        Uint8Array.from(
          readFileSync(
            new URL(
              `../../../core/assets/fonts/noto-sans/NotoSans-${style}.ttf`,
              import.meta.url,
            ),
          ),
        ).buffer,
    };
  });
  vi.stubGlobal("fetch", fetched);
  let doc = createEmptyPartDocument("Styled text");
  const apply = vi.fn(async (next) => {
    doc = next;
  });
  try {
    open(() => doc, apply);
    click("Top (XY)");
    field("Sketch text").value = "Aether";
    const select = field("Bundled text font");
    expect(select.options).toHaveLength(5);
    select.value = "1";
    select.dispatchEvent(new Event("change"));
    await vi.waitFor(
      () =>
        expect(
          document.querySelector(".sketch-text-preview path"),
        ).toBeTruthy(),
      { timeout: 10000 },
    );
    expect(fetched.mock.calls[0][0]).toContain("NotoSans-Bold");
    expect(String(fetched.mock.calls[0][0])).not.toMatch(/^https?:/);
    click("Create editable text");
    await vi.waitFor(
      () => expect(field("Saved sketch text").options).toHaveLength(2),
      { timeout: 10000 },
    );
    click("Finish sketch");
    await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
    doc = parsePartDocument(serializePartDocument(doc));
    const bold = doc.features[0].profile.textItems[0].fontBase64;
    open(() => doc, apply, doc.features[0]);
    const items = field("Saved sketch text");
    items.value = items.options[1].value;
    items.dispatchEvent(new Event("change"));
    await vi.waitFor(
      () =>
        expect(
          document.querySelector(".sketch-text-preview path"),
        ).toBeTruthy(),
      { timeout: 10000 },
    );
    const regular = field("Bundled text font");
    regular.value = "0";
    regular.dispatchEvent(new Event("change"));
    await vi.waitFor(
      () =>
        expect(
          document.querySelector(".sketch-text-preview path"),
        ).toBeTruthy(),
      { timeout: 10000 },
    );
    click("Update editable text");
    await vi.waitFor(() => expect(field("Bundled text font").value).toBe(""), {
      timeout: 10000,
    });
    click("Finish sketch");
    await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
    expect(doc.features[0].profile.textItems[0].fontBase64).not.toBe(bold);
  } finally {
    vi.stubGlobal("fetch", originalFetch);
    document.querySelector(".sketch-workspace")?.remove();
  }
}, 30000);
