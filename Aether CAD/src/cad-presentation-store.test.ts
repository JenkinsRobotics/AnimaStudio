import { describe, expect, it, vi } from "vitest";
import {
  CADPresentationStore,
  parseCADPresentationPreferences,
  serializeCADPresentationPreferences,
} from "./cad-presentation-store";

describe("CADPresentationStore", () => {
  it("merges typed presentation patches and notifies subscribers", () => {
    const store = new CADPresentationStore();
    const listener = vi.fn();
    store.subscribe(listener);
    store.patch({
      documentName: "Bracket",
      activeTool: "connector",
      startScreen: "home",
      itemFilterFocusSerial: 1,
      loading: { label: "Importing STEP", detail: "bracket.step" },
    });
    expect(store.snapshot()).toMatchObject({
      documentName: "Bracket",
      activeTool: "connector",
      activePanel: "items",
      workspaceMode: "modeling",
      workspaceLayout: "docked",
      toolbarMode: "traditional",
      panelPlacements: { browser: "docked", inspector: "docked", bottom: "docked" },
      startScreen: "home",
      itemFilterFocusSerial: 1,
      loading: { label: "Importing STEP", detail: "bracket.step" },
    });
    expect(listener).toHaveBeenCalledOnce();
  });

  it("dispatches actions only while the CAD controller is registered", () => {
    const store = new CADPresentationStore();
    const handler = vi.fn();
    const release = store.registerActionHandler(handler);
    expect(store.dispatch({ type: "select-panel", panel: "mates" })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "select-panel", panel: "mates" });
    expect(store.dispatch({ type: "select-layout", layout: "expanded" })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "select-layout", layout: "expanded" });
    expect(store.dispatch({ type: "select-workspace-mode", mode: "drawing" })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "select-workspace-mode", mode: "drawing" });
    expect(store.dispatch({ type: "select-toolbar-mode", mode: "floating" })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "select-toolbar-mode", mode: "floating" });
    expect(store.dispatch({ type: "set-panel-placement", panel: "browser", placement: "floating" })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "set-panel-placement", panel: "browser", placement: "floating" });
    const draft = {
      partName: "Bearing",
      partNumber: "BRG-6202",
      sourceLabel: "bearing.cadpart",
      instanceName: "Bearing:1",
      massKg: 0.08,
      positionM: [0, 0, 0] as const,
      grounded: false,
    };
    expect(store.dispatch({ type: "insert-assembly-component", draft })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "insert-assembly-component", draft });
    const connectorDraft = {
      name: "Shaft axis",
      provenanceLabel: "Datum A",
      originM: [0, 0, 0] as const,
      primaryAxis: "positive-z" as const,
      secondaryAxis: "positive-x" as const,
    };
    expect(store.dispatch({ type: "add-assembly-connector", draft: connectorDraft })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "add-assembly-connector", draft: connectorDraft });
    const mateDraft = {
      name: "Fixed 1",
      typeID: "fastened" as const,
      endpointA: { instanceID: "base-1", connectorDefinitionID: "base-axis" },
      endpointB: { instanceID: "arm-1", connectorDefinitionID: "arm-axis" },
    };
    expect(store.dispatch({ type: "preview-assembly-mate", draft: mateDraft })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "preview-assembly-mate", draft: mateDraft });
    expect(store.dispatch({ type: "commit-assembly-mate", draft: mateDraft })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "commit-assembly-mate", draft: mateDraft });
    const dofDraft = {
      dofID: "dof-1",
      name: "rotation",
      kind: "rotation" as const,
      value: 45,
      limitsEnabled: true,
      minimum: -90,
      maximum: 90,
    };
    expect(store.dispatch({ type: "set-assembly-mate-dof-value", draft: dofDraft })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "set-assembly-mate-dof-value", draft: dofDraft });
    expect(store.dispatch({ type: "update-assembly-mate-dof-limits", draft: dofDraft })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "update-assembly-mate-dof-limits", draft: dofDraft });
    const relationDraft = {
      kind: "gear" as const,
      driverDOFID: "dof-1",
      drivenDOFID: "dof-2",
      ratio: 2,
      offset: 0,
      reversed: false,
    };
    expect(store.dispatch({ type: "create-assembly-relation", draft: relationDraft })).toBe(true);
    expect(handler).toHaveBeenCalledWith({ type: "create-assembly-relation", draft: relationDraft });
    expect(store.dispatch({ type: "reset-panel-placements" })).toBe(true);
    release();
    expect(store.dispatch({ type: "cancel-tool" })).toBe(false);
  });

  it("round-trips valid presentation preferences and rejects damaged values", () => {
    const store = new CADPresentationStore();
    store.patch({
      toolbarMode: "floating",
      workspaceLayout: "expanded",
      panelPlacements: { browser: "floating", inspector: "hidden", bottom: "docked" },
    });
    expect(parseCADPresentationPreferences(serializeCADPresentationPreferences(store.snapshot()))).toEqual({
      toolbarMode: "floating",
      workspaceLayout: "expanded",
      panelPlacements: { browser: "floating", inspector: "hidden", bottom: "docked" },
    });
    expect(parseCADPresentationPreferences("not-json")).toBeNull();
    expect(parseCADPresentationPreferences('{"toolbarMode":"compact"}')).toBeNull();
  });
});
