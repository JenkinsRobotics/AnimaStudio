import { describe, expect, it, vi } from "vitest";
import type { CADAssemblyPresentationProjection } from "./cad-assembly-presentation";
import { CADAssemblyWorkspaceStore } from "./cad-assembly-workspace-store";

const data: CADAssemblyPresentationProjection = {
  revision: "revision-1",
  treeNodes: [{
    id: "assembly-1",
    label: "Assembly",
    children: [{ id: "instance-1", label: "Bracket:1" }],
  }],
  connectorItems: [],
  mateEndpointOptions: [],
  selectedMateDOF: null,
  relationDOFOptions: [],
  mateItems: [],
  relationItems: [],
  problemItems: [],
  inspectorSections: [],
  bomRows: [{
    row_id: "row-1",
    parent_row_id: null,
    part_definition_id: "part-1",
    quantity: 1,
    part_number: null,
    name: "Bracket",
    description: null,
    material_name: null,
    unit_mass_kg: null,
    extended_mass_kg: null,
    source_label: null,
    custom_properties: [],
  }],
  commandAvailability: [],
  summary: {
    instanceCount: 1,
    connectorCount: 0,
    mateCount: 0,
    remainingFreeDOFCount: null,
    solveStatus: "not_solved",
    bomMode: "hierarchical",
  },
};

describe("CADAssemblyWorkspaceStore", () => {
  it("owns load, tab, filter, selection, and expansion as presentation state", () => {
    const store = new CADAssemblyWorkspaceStore();
    const listener = vi.fn();
    store.subscribe(listener);
    expect(store.snapshot()).toMatchObject({ loadState: "unavailable", activeTab: "constraints" });

    store.setLoading();
    store.setReady(data);
    store.dispatch({ type: "select-tab", tab: "structure" });
    store.dispatch({ type: "set-filter", filter: "bracket" });
    store.dispatch({ type: "select-entities", ids: ["instance-1"], mode: "single" });
    store.dispatch({ type: "toggle-entity", id: "assembly-1", expanded: true });
    store.dispatch({ type: "select-bom-rows", ids: ["row-1"], mode: "single" });

    expect(store.snapshot()).toMatchObject({
      loadState: "ready",
      activeTab: "structure",
      filter: "bracket",
      message: "Assembly revision revision-1",
      data,
    });
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set(["instance-1"]));
    expect(store.snapshot().expandedEntityIDs.has("assembly-1")).toBe(true);
    expect(store.snapshot().selectedBOMRowIDs).toEqual(new Set(["row-1"]));
    expect(listener).toHaveBeenCalledTimes(7);
  });

  it("drops stale entity and BOM selections when a refreshed projection removes them", () => {
    const store = new CADAssemblyWorkspaceStore();
    store.setReady(data);
    store.dispatch({ type: "select-entities", ids: ["instance-1"], mode: "single" });
    store.dispatch({ type: "select-bom-rows", ids: ["row-1"], mode: "single" });
    store.setReady({
      ...data,
      revision: "revision-2",
      treeNodes: [{ id: "assembly-1", label: "Assembly" }],
      bomRows: [],
    });
    expect(store.snapshot().selectedEntityIDs).toEqual(new Set());
    expect(store.snapshot().selectedBOMRowIDs).toEqual(new Set());
  });

  it("exposes error and unavailable states without retaining canonical data", () => {
    const store = new CADAssemblyWorkspaceStore();
    store.setReady(data);
    store.setError("Core bridge disconnected.");
    expect(store.snapshot()).toMatchObject({ loadState: "error", message: "Core bridge disconnected.", data: null });
    store.setUnavailable("Workspace graph is not open.");
    expect(store.snapshot()).toMatchObject({ loadState: "unavailable", message: "Workspace graph is not open.", data: null });
  });

  it("routes BOM mode intent without synthesizing a client-side projection", () => {
    const store = new CADAssemblyWorkspaceStore();
    const listener = vi.fn();
    const actions = vi.fn();
    store.setReady(data);
    store.subscribe(listener);
    store.subscribeActions(actions);

    store.dispatch({ type: "select-bom-mode", mode: "flattened" });

    expect(actions).toHaveBeenCalledWith({ type: "select-bom-mode", mode: "flattened" });
    expect(listener).not.toHaveBeenCalled();
    expect(store.snapshot().data?.summary.bomMode).toBe("hierarchical");
  });
});
