import { createRequire } from "node:module";
import { afterAll, beforeAll, expect, it, vi } from "vitest";
import { mountCenterControls } from "./center-controls";
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
it("selects an arc center after its stable edge moves to another index", () => {
  const parent = document.querySelector("main");
  const entity = document.createElement("select"),
    message = document.createElement("p");
  const ref = { contour: 0, kind: "arc", index: 0, segmentId: "arc-edge" };
  const option = document.createElement("option");
  option.value = JSON.stringify(ref);
  entity.append(option);
  const centerRef = { contour: 1, kind: "point", index: 0 };
  const centerOption = document.createElement("option");
  centerOption.value = JSON.stringify(centerRef);
  entity.append(centerOption);
  parent.append(entity, message);
  let drawing = {
    type: "drawing",
    contours: [
      {
        type: "path",
        start: [-5, 0],
        segments: [
          { type: "line", end: [5, 0] },
          { type: "arc", id: "arc-edge", middle: [0, 5], end: [-5, 0] },
        ],
      },
    ],
  };
  const commit = vi.fn((next) => {
    drawing = next;
  });
  const choose = vi.fn();
  mountCenterControls(parent, entity, () => drawing, commit, choose, message);
  const button = [...parent.querySelectorAll("button")].find(
    (b) => b.textContent === "Select arc center",
  );
  button.click();
  expect(commit).toHaveBeenCalledTimes(1);
  expect(entity.value).toBe(JSON.stringify(centerRef));
  expect(choose).toHaveBeenCalledWith("select");
  expect(message.textContent).toContain("Arc center selected");
  entity.value = JSON.stringify(ref);
  button.click();
  expect(drawing.contours).toHaveLength(2);
  expect(drawing.constraints).toHaveLength(1);
  expect(entity.value).toBe(JSON.stringify(centerRef));
  // A freshly generated numeric selection must also reuse the stable relation.
  const currentOption = document.createElement("option");
  currentOption.value = JSON.stringify({ contour: 0, kind: "arc", index: 1 });
  entity.append(currentOption);
  entity.value = currentOption.value;
  button.click();
  expect(entity.value).toBe(JSON.stringify(centerRef));
  expect(drawing.constraints).toHaveLength(1);
});
