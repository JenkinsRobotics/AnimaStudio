import { cadCommands } from "../cad-command-registry";
import { registerSketchTextCommand } from "./text-command";
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

it("opens the ribbon Text command only in an active sketch and loads the local default font", async () => {
  const unregister = registerSketchTextCommand(),
    originalFetch = globalThis.fetch;
  const fetchFont = vi.fn(async () => ({
    ok: true,
    arrayBuffer: async () =>
      Uint8Array.from(
        readFileSync(
          new URL(
            "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
            import.meta.url,
          ),
        ),
      ).buffer,
  }));
  vi.stubGlobal("fetch", fetchFont);
  const doc = createEmptyPartDocument("Ribbon text"),
    apply = vi.fn();
  try {
    expect(cadCommands.execute("sketch-text")).toBe(false);
    open(() => doc, apply);
    expect(cadCommands.execute("sketch-text")).toBe(false);
    click("Top (XY)");
    window.dispatchEvent(
      new CustomEvent("aether-sketch-tool", { detail: "circle" }),
    );
    expect(cadCommands.execute("sketch-text")).toBe(true);
    expect(field("Sketch text").closest("details").open).toBe(true);
    expect(document.activeElement).toBe(field("Sketch text"));
    await vi.waitFor(
      () =>
        expect(
          document.querySelector(".sketch-text-preview path"),
        ).toBeTruthy(),
      { timeout: 10000 },
    );
    expect(fetchFont).toHaveBeenCalledTimes(1);
    expect(fetchFont.mock.calls[0][0]).toContain("NotoSans-Regular");
    expect(cadCommands.execute("sketch-text")).toBe(true);
    expect(fetchFont).toHaveBeenCalledTimes(1);
    expect(document.querySelector(".sketch-text-preview path")).toBeTruthy();
    click("Cancel");
    expect(cadCommands.execute("sketch-text")).toBe(false);
    window.dispatchEvent(new Event("aether-sketch-text"));
    expect(document.querySelector('[aria-label="Sketch text"]')).toBeNull();
  } finally {
    unregister();
    vi.stubGlobal("fetch", originalFetch);
  }
}, 30000);
