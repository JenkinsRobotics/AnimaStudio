import { describe, expect, it, vi } from "vitest";
import { CADWorkspaceStore } from "./cad-workspace-store";

describe("CADWorkspaceStore", () => {
  it("publishes immutable presentation snapshots", () => {
    const store = new CADWorkspaceStore();
    const listener = vi.fn();
    store.subscribe(listener);
    store.publish({ itemNodes: [], selectedItemIDs: new Set(["part/a"]), expandedItemIDs: new Set(), historyItems: [], connectorItems: [], mateItems: [], problemItems: [], inspectorSections: [], selectedConnectorIDs: new Set(), partCount: 1 });
    expect(store.snapshot().partCount).toBe(1);
    expect(store.snapshot().selectedItemIDs.has("part/a")).toBe(true);
    expect(listener).toHaveBeenCalledOnce();
  });

  it("dispatches typed actions only while a controller is registered", () => {
    const store = new CADWorkspaceStore();
    const handler = vi.fn();
    const release = store.registerActionHandler(handler);
    expect(store.dispatch({ type: "select-item", id: "part/a" })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "select-item", id: "part/a" });
    release();
    expect(store.dispatch({ type: "toggle-item", id: "document/a" })).toBe(false);
  });
});
