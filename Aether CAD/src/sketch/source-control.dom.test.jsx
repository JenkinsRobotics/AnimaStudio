import { createRequire } from "node:module";
import { beforeAll, afterAll, expect, it, vi } from "vitest";
import { mountModificationSourceControl } from "./source-control";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom;
beforeAll(() => {
  dom = new JSDOM(
    '<main><select multiple></select><svg viewBox="-20 -20 40 40"></svg></main>',
  );
  vi.stubGlobal("document", dom.window.document);
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
it("click-selects the intended edge after its numeric position changes and highlights its actual geometry", () => {
  const parent = document.querySelector("main"),
    select = parent.querySelector("select"),
    svg = parent.querySelector("svg");
  const drawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [0, 0],
        segments: [{ type: "line", id: "edge", end: [10, 0] }],
      },
    ],
  };
  const changed = vi.fn();
  const control = mountModificationSourceControl(
    parent,
    svg,
    select,
    () => drawing,
    () => undefined,
    changed,
  );
  const mode = parent.querySelector('input[type="checkbox"]');
  mode.checked = true;
  mode.dispatchEvent(new dom.window.Event("change"));
  select.options[0].selected = false;
  select.dispatchEvent(new dom.window.Event("change"));
  drawing.contours[0].start = [-5, 0];
  drawing.contours[0].segments.unshift({
    type: "line",
    id: "prefix",
    end: [0, 0],
  });
  control.pick([5, 0], 0.1);
  expect(control.selected()).toEqual([
    expect.objectContaining({ index: 0, segmentId: "edge" }),
  ]);
  control.render();
  expect(
    svg
      .querySelector(".sketch-modification-source-selection path")
      .getAttribute("d"),
  ).toBe("M0,0L10,0");
  control.pick([5, 0], 0.1);
  expect(control.selected()).toEqual([]);
  control.render();
  expect(svg.querySelector(".sketch-modification-source-selection")).toBeNull();
  drawing.contours[0].segments[1].id = "replacement";
  control.pick([5, 0], 0.1);
  expect(control.selected()).toEqual([]);
  control.dispose();
});
