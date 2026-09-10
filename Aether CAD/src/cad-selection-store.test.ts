import { describe, expect, it, vi } from "vitest";
import {
  boxSelectionMode,
  CADSelectionStore,
  defaultCADSelection,
  normalizedSelectionBox,
  reduceCADSelection,
  selectionRectangleMatches,
  selectedPartIDs,
  type CADSelectionItem,
} from "./cad-selection-store";

const body: CADSelectionItem = { id: "body:part-1", kind: "body", partId: "part-1", label: "Body 1" };
const face: CADSelectionItem = { id: "face:part-1:4", kind: "face", partId: "part-1", label: "Face 4" };

describe("CADSelectionStore", () => {
  it("distinguishes left-to-right Window from right-to-left Crossing", () => {
    expect(boxSelectionMode(10, 50)).toBe("window");
    expect(boxSelectionMode(50, 10)).toBe("crossing");
    expect(normalizedSelectionBox({ startX: 50, startY: 40, currentX: 10, currentY: 80, mode: "crossing" })).toEqual({
      left: 10, top: 40, right: 50, bottom: 80, width: 40, height: 40,
    });
    const selection = { left: 0, top: 0, right: 100, bottom: 100 };
    const partiallyInside = { left: 80, top: 20, right: 120, bottom: 60 };
    expect(selectionRectangleMatches("window", selection, partiallyInside)).toBe(false);
    expect(selectionRectangleMatches("crossing", selection, partiallyInside)).toBe(true);
  });

  it("replaces, adds, and toggles stable selection items without duplicates", () => {
    const replaced = reduceCADSelection(defaultCADSelection, { type: "replace", items: [body] });
    const added = reduceCADSelection(replaced, { type: "add", items: [body, face] });
    expect(added.items).toEqual([body, face]);
    const toggled = reduceCADSelection(added, { type: "toggle", items: [body] });
    expect(toggled.items).toEqual([face]);
    expect(selectedPartIDs(toggled)).toEqual(new Set(["part-1"]));
  });

  it("publishes filter, hover, and selection changes from one snapshot", () => {
    const store = new CADSelectionStore();
    const listener = vi.fn();
    store.subscribe(listener);
    store.dispatch({ type: "set-filter", filter: "vertex" });
    store.dispatch({ type: "set-hovered", item: face });
    store.dispatch({ type: "replace", items: [face] });
    expect(store.snapshot()).toMatchObject({ filter: "vertex", hovered: face, items: [face] });
    expect(listener).toHaveBeenCalledTimes(3);
  });
});
