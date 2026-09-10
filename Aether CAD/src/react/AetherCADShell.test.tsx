import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { CADAssemblyPresentationProjection } from "../cad-assembly-presentation";
import { cadAssemblyWorkspace } from "../cad-assembly-workspace-store";
import { cadDrawingWorkspace } from "../cad-drawing-workspace-store";
import { cadPresentation } from "../cad-presentation-store";
import { AetherCADShell, buildCADCommandPaletteCommands } from "./AetherCADShell";
import { cadCommands } from "../cad-command-registry";
import { cadAppearance } from "../cad-appearance-store";
import { cadSelection } from "../cad-selection-store";

const canonicalAssemblyData: CADAssemblyPresentationProjection = {
  revision: "revision-12",
  treeNodes: [{ id: "assembly-1", label: "Drive Assembly", children: [{ id: "instance-1", label: "Bracket:1" }] }],
  connectorItems: [{ id: "connector-1", label: "Mount connector", description: "Bracket · Top face" }],
  mateEndpointOptions: [
    { id: '["instance-1","connector-1"]', label: "Bracket:1 · Mount connector", description: "Bracket · Top face", instanceID: "instance-1", connectorDefinitionID: "connector-1" },
    { id: '["instance-2","connector-2"]', label: "Arm:1 · Pivot connector", description: "Arm · Bore axis", instanceID: "instance-2", connectorDefinitionID: "connector-2" },
  ],
  selectedMateDOF: null,
  relationDOFOptions: [],
  mateItems: [{ id: "mate-1", label: "Pivot", description: "Bracket:1 ↔ Arm:1", badge: "revolute · satisfied" }],
  relationItems: [],
  problemItems: [],
  inspectorSections: [{ id: "assembly", label: "Assembly", badge: "solved", properties: [{ id: "revision", label: "Revision", value: "revision-12" }] }],
  bomRows: [{ row_id: "row-1", parent_row_id: null, part_definition_id: "part-1", quantity: 2, part_number: "BR-100", name: "Bracket", description: null, material_name: "Aluminum", unit_mass_kg: 0.1, extended_mass_kg: 0.2, source_label: "Bracket", custom_properties: [] }],
  commandAvailability: [],
  summary: { instanceCount: 1, connectorCount: 1, mateCount: 1, remainingFreeDOFCount: 0, solveStatus: "solved", bomMode: "hierarchical" },
};

describe("AetherCADShell", () => {
  beforeEach(() => {
    cadAppearance.dispatch({ type: "reset" });
    cadSelection.dispatch({ type: "clear" });
    cadSelection.dispatch({ type: "set-filter", filter: "auto" });
    cadAssemblyWorkspace.setUnavailable();
    cadDrawingWorkspace.setUnavailable();
    cadAssemblyWorkspace.dispatch({ type: "select-tab", tab: "constraints" });
    cadPresentation.patch({
      activePanel: "items",
      workspaceMode: "modeling",
      workspaceLayout: "docked",
      toolbarMode: "traditional",
      panelPlacements: { browser: "docked", inspector: "docked", bottom: "docked" },
      itemFilterFocusSerial: 0,
      startScreen: "workspace",
      startDialog: null,
      documentName: "Untitled Part",
      partOpen: false,
      bottomPanelActiveID: "history",
      bottomPanelCollapsed: false,
      activeTool: "none",
      awaitingSketchPlane: false,
      hover: null,
      loading: null,
      matePreview: null,
    });
  });

  it("keeps every live CAD command in the React-owned shell", () => {
    const html = renderToStaticMarkup(<AetherCADShell />);
    for (const id of [
      "new-part",
      "part-picker",
      "save-part",
      "step-picker",
      "parts-list",
      "history-list",
      "viewport",
      "view-cube",
    ]) {
      expect(html).toContain(`id="${id}"`);
    }
    for (const command of [
      "new-part",
      "open-part",
      "save-part",
      "insert-step",
      "sketch",
      "connector",
      "fastened",
      "fit-view",
    ]) {
      expect(html).toContain(`data-command="${command}"`);
    }
    expect(html).not.toContain("CAD command bridge");
    expect(html).toContain('aria-label="Commands"');
  });

  it("defaults to full-suite ribbon with left history and version controls", () => {
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain("chrome-suite toolbar-traditional");
    expect(html).toContain("cad-suite-workspace");
    expect(html).toContain('aria-label="Design"');
    expect(html).toContain('aria-label="Model"');
    expect(html).toContain('aria-label="Version control"');
    expect(html).toContain('aria-label="History"');
    expect(html).toContain('aria-label="Interface theme"');
    expect(html).not.toContain('aria-label="Rebuild workbench"');
  });

  it("retains the classic centered tabs and bottom history as a saved alternative", () => {
    vi.stubGlobal("localStorage", {getItem: () => "classic"});
    try {
      const html = renderToStaticMarkup(<AetherCADShell />);
      expect(html).toContain("chrome-classic toolbar-traditional");
      expect(html).toContain('aria-label="Animate"');
      expect(html).toContain('aria-label="Rebuild workbench"');
      expect(html).not.toContain("cad-suite-workspace");
      cadPresentation.patch({toolbarMode: "floating"});
      expect(renderToStaticMarkup(<AetherCADShell />)).toContain("chrome-classic toolbar-floating");
    } finally { vi.unstubAllGlobals(); }
  });

  it("projects independent browser, inspector, and bottom panel placements", () => {
    cadPresentation.patch({
      panelPlacements: { browser: "floating", inspector: "hidden", bottom: "docked" },
    });
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain("aui-float-panel");
    expect(html).toContain("aui-shell");
    expect(html).toContain("panel-bottom-docked");
    expect(html).toContain('aria-label="Model placement"');
    expect(html).toContain('aria-label="Properties placement"');
    expect(html).toContain('aria-label="History"');
    expect(html).toContain('aria-label="Workspace layout"');
  });

  it("projects the typed command registry into the shared palette without inventing handlers", () => {
    const disconnected = buildCADCommandPaletteCommands(cadCommands.snapshot());
    expect(disconnected).toHaveLength(57);
    expect(disconnected.map((command) => command.id)).toContain("fit-view");
    expect(disconnected.map((command) => command.id)).toEqual(expect.arrayContaining([
      "view-front", "view-back", "view-left", "view-right", "view-top", "view-bottom",
      "background-graphite", "background-midnight", "background-slate",
      "finish-matte", "finish-satin", "finish-gloss",
      "ground-none", "ground-grid", "ground-floor", "ground-both",
      "toggle-feature-edges", "reset-appearance",
      "assembly-insert-component",
      "assembly-add-connector",
      "assembly-create-mate",
      "assembly-set-mate-dof-value", "assembly-edit-mate-dof-limits",
      "assembly-create-relation",
      "assembly-toggle-mate-suppressed", "assembly-remove-mate",
      "assembly-toggle-grounded", "assembly-toggle-suppressed", "assembly-remove-instance",
    ]));
    expect(disconnected.every((command) => command.disabled)).toBe(true);
    expect(disconnected.every((command) => command.disabledReason === "Command is not connected.")).toBe(true);

    const unregister = cadCommands.register("fit-view", () => {});
    const connected = buildCADCommandPaletteCommands(cadCommands.snapshot());
    expect(connected.find((command) => command.id === "fit-view")?.disabled).toBe(false);
    unregister();
  });

  it("renders Shapr-style Items, tool, and History surfaces", () => {
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain("Items");
    expect(html).toContain("Insert STEP");
    expect(html).toContain("History");
    expect(html).toContain('aria-label="Mate actions"');
    expect(html).toContain('aria-label="Mate connectors"');
    expect(html).toContain('aria-label="Fastened mates"');
    expect(html).toContain("Session-only Part proof");
    expect(html).toContain('aria-label="Part inspector"');
    expect(html).toContain('aria-label="History"');
    expect(html).toContain("Problems");
    expect(html).toContain('class="browser-panel active" data-panel="items"');
    expect(html).toContain('class="browser-panel active" data-panel="mates"');
    expect(html).toContain('class="browser-panel active" data-panel="inspect"');
    expect(html).toContain('class="browser-panel active" data-panel="visualization"');
    expect(html).toContain('class="aui-number-field"');
    expect(html).toContain('class="aui-search-field browser-filter"');
    expect(html).toContain('data-aether-window-drag-region="true"');
    expect(html).toContain('aria-label="Design"');
    expect(html).toContain('class="aui-tree"');
    expect(html).toContain('class="aui-listbox"');
    expect(html).not.toContain('id="reference-list"');
    expect(html).not.toContain('class="history-row"');
    expect(html).not.toContain('class="connector-row"');
    expect(html).not.toContain('class="mate-row"');
    expect(html).not.toContain('class="history-sidebar"');
    expect(html).toContain('id="part-width"');
    expect(html).toContain('id="items-filter"');
    expect(html).toContain("Viewport appearance · this session");
    expect(html).toContain('aria-label="Adjust Width"');
    expect(html).not.toContain('id="connector-card"');
    expect(html).not.toContain('id="loading-card"');
  });

  it("renders canonical-ready Structure, Mates, BOM, and inspector datasets through shared widgets", () => {
    cadPresentation.patch({ activePanel: "mates" });
    cadAssemblyWorkspace.setReady(canonicalAssemblyData);
    cadAssemblyWorkspace.dispatch({ type: "select-tab", tab: "structure" });
    const structure = renderToStaticMarkup(<AetherCADShell />);
    expect(structure).toContain('role="tablist"');
    expect(structure).toContain('aria-label="Assembly structure"');
    expect(structure).toContain("Drive Assembly");
    expect(structure).toContain("Bracket:1");
    expect(structure).toContain('aria-label="Assembly inspector"');
    expect(structure).toContain("revision-12");
    expect(structure).not.toContain("Session-only Part proof");

    cadAssemblyWorkspace.dispatch({ type: "select-tab", tab: "constraints" });
    const constraints = renderToStaticMarkup(<AetherCADShell />);
    expect(constraints).toContain('aria-label="Canonical mate connectors"');
    expect(constraints).toContain('aria-label="Canonical mates"');
    expect(constraints).toContain("revolute · satisfied");

    cadAssemblyWorkspace.dispatch({ type: "select-tab", tab: "bom" });
    const bom = renderToStaticMarkup(<AetherCADShell />);
    expect(bom).toContain('aria-label="BOM structure"');
    expect(bom).toContain('role="radio" aria-checked="true" tabindex="0"><span>Hierarchical</span>');
    expect(bom).toContain("Flattened");
    expect(bom).toContain('aria-label="Assembly bill of materials"');
    expect(bom).toContain("BR-100");
    expect(bom).toContain("Aluminum");
  });

  it("shows honest Structure and BOM dependency states before the canonical producer is connected", () => {
    cadPresentation.patch({ activePanel: "mates" });
    cadAssemblyWorkspace.dispatch({ type: "select-tab", tab: "structure" });
    const structure = renderToStaticMarkup(<AetherCADShell />);
    expect(structure).toContain("Persistent Assembly graph unavailable");
    expect(structure).toContain("waiting for the canonical Core workspace graph");

    cadAssemblyWorkspace.dispatch({ type: "select-tab", tab: "bom" });
    const bom = renderToStaticMarkup(<AetherCADShell />);
    expect(bom).toContain("BOM unavailable");
    expect(bom).not.toContain('aria-label="Assembly bill of materials"');
  });

  it("names the shell landmarks and live status surfaces", () => {
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain('aria-label="Aether CAD Home"');
    expect(html).toContain('aria-label="CAD workspace"');
    expect(html).toContain('aria-label="3D CAD viewport"');
    expect(html).toContain('aria-label="Workspace status"');
    expect(html).toContain('aria-label="Workspace metrics"');
    expect(html).toContain('aria-label="Workspace layout"');
    expect(html).toContain('data-layout="docked"');
    expect(html).toContain('class="backend" role="status"');
    expect(html).toContain('id="status-message" role="status"');
    expect(html.match(/aria-live="polite"/g)).toHaveLength(4);
    expect(html.match(/aria-atomic="true"/g)).toHaveLength(2);
  });

  it("renders Docked, Expanded, and Canvas from one persistent workspace shell", () => {
    for (const layout of ["docked", "expanded", "canvas"] as const) {
      cadPresentation.patch({ workspaceLayout: layout });
      const html = renderToStaticMarkup(<AetherCADShell />);
      expect(html).toContain(`data-layout="${layout}"`);
      expect(html).toContain('class="aui-shell"');
      expect(html).toContain('id="viewport"');
      expect(html).toContain('data-workspace-mode="modeling"');
      expect(html).toContain('aria-label="Workspace layout"');
    }
  });

  it("routes to the truthful Drawing dependency workbench without unmounting the 3D viewport", () => {
    cadPresentation.patch({ workspaceMode: "drawing" });
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain('data-workspace-mode="drawing"');
    expect(html).toContain('class="cad-studio-viewport" aria-hidden="true" inert=""');
    expect(html).toContain('class="cad-drawing-route active" aria-hidden="false"');
    expect(html).toContain('aria-label="Drawing workspace navigation"');
    expect(html).toContain("← 3D model");
    expect(html).toContain("Exact Drawing engine unavailable");
    expect(html).toContain("waiting for the canonical Core projection engine");
    expect(html).toContain('id="viewport"');
    expect(html).not.toContain('data-drawing-command="add-sheet"');
  });

  it("renders an exact Inspect workbench and gates unsupported analysis", () => {
    cadPresentation.patch({ activePanel: "inspect" });
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain('class="browser-panel active" data-panel="inspect"');
    expect(html).toContain('aria-label="Exact model inspection"');
    expect(html).toContain('data-command="fit-view"');
    expect(html).toContain('id="inspect-fit-view"');
    expect(html).toContain("Measure");
    expect(html).toContain("Mass properties");
    expect(html).toContain("Section analysis");
    expect(html).toContain("Curvature");
    expect(html).toContain("require an exact Core measurement contract");
    expect(html.match(/disabled=""/g)?.length).toBeGreaterThanOrEqual(4);
  });

  it("renders a working Visualization screen with honest assignment limits", () => {
    cadPresentation.patch({ activePanel: "visualization" });
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain('class="browser-panel active" data-panel="visualization"');
    expect(html).toContain('aria-label="Viewport appearance"');
    expect(html).toContain('aria-label="Viewport display style"');
    expect(html).toContain("Shaded with edges");
    expect(html).toContain("Hidden line");
    expect(html).toContain("Ghost");
    expect(html).toContain('id="appearance-background"');
    expect(html).toContain('aria-label="Body finish"');
    expect(html).toContain('aria-label="Environment intensity"');
    expect(html).toContain('aria-label="Viewport lighting preset"');
    expect(html).toContain('aria-label="Viewport ground mode"');
    expect(html).toContain("Contact shadows");
    expect(html).toContain('role="radiogroup"');
    expect(html).toContain('type="range"');
    expect(html).toContain("Exact feature edges");
    expect(html).toContain("Reset appearance");
    expect(html).toContain("Paper — adaptive grid required");
    expect(html).toContain("Canonical assignment graph required");
  });

  it("projects controller presentation state into React-owned workflow surfaces", () => {
    cadPresentation.patch({
      activePanel: "mates",
      bottomPanelCollapsed: true,
      documentName: "Bracket",
      partOpen: true,
      activeTool: "connector",
      hover: { partName: "Body 1", label: "Plane face center", detail: "Face 4" },
      loading: { label: "Rebuilding exact feature history", detail: "Bracket" },
    });
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).not.toContain('class="aui-bottom-panel aui-bottom-panel--collapsed"');
    expect(html).toContain('class="browser-panel active" data-panel="mates"');
    expect(html).toContain("Place Mate Connector");
    expect(html).toContain("Plane face center");
    expect(html).toContain('class="aui-progress-surface"');
    expect(html).toContain("Rebuilding exact feature history");
    expect(html).toContain("Rebuild Part");
  });

  it("exposes cancellable and backgroundable STEP task controls", () => {
    cadPresentation.patch({
      loading: {
        label: "Extracting B-Rep topology",
        detail: "assembly.step · analytic faces and edges",
        canCancel: true,
        canBackground: true,
        phase: "1 of 3",
        value: 0,
        max: 3,
      },
    });
    const foreground = renderToStaticMarkup(<AetherCADShell />);
    expect(foreground).toContain("Run in background");
    expect(foreground).toContain(">Cancel</button>");
    expect(foreground).toContain("1 of 3");
    expect(foreground).toContain('aria-valuemax="3"');

    cadPresentation.patch({ loading: { ...cadPresentation.snapshot().loading!, backgrounded: true } });
    const background = renderToStaticMarkup(<AetherCADShell />);
    expect(background).not.toContain('class="aui-progress-surface"');
    expect(background).toContain("Show import task");
  });

  it("renders working Home, New Part, Import, and honest Recovery states", () => {
    cadPresentation.patch({ startScreen: "home", startDialog: "new-workspace" });
    const newHTML = renderToStaticMarkup(<AetherCADShell />);
    expect(newHTML).toContain('aria-label="Aether CAD Home"');
    expect(newHTML).toContain("New workspace");
    expect(newHTML).toContain("No recent workspaces");
    expect(newHTML).toContain('aria-label="New Part workspace"');
    expect(newHTML).toContain('id="new-part-name"');
    expect(newHTML).toContain('<option value="assembly">Assembly</option>');
    expect(newHTML).toContain("Open Assembly");

    cadPresentation.patch({ startDialog: "import" });
    const importHTML = renderToStaticMarkup(<AetherCADShell />);
    expect(importHTML).toContain('aria-label="Import STEP geometry"');
    expect(importHTML).toContain("Choose STEP files");
    expect(importHTML).toContain("Detected from source");

    cadPresentation.patch({ startScreen: "recovery", startDialog: null });
    const recoveryHTML = renderToStaticMarkup(<AetherCADShell />);
    expect(recoveryHTML).toContain('aria-label="Recovery"');
    expect(recoveryHTML).toContain("No recovery revisions");
    expect(recoveryHTML).toContain("Open saved Part");
  });

  it("renders an exact native Export center and explains unavailable outputs", () => {
    cadPresentation.patch({
      startDialog: "export",
      documentName: "Drive Bracket",
      partOpen: true,
    });
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain('aria-label="Export Part"');
    expect(html).toContain("Aether native Part (.acpart)");
    expect(html).toContain("Exact editable document");
    expect(html).toContain("Save native Part");
    expect(html).toContain("STEP — exact writer unavailable");
    expect(html).toContain("Drawing PDF — projections unavailable");
  });

  it("renders component identity, preferred placement units, mass, and grounding authoring fields", () => {
    cadPresentation.patch({ startDialog: "insert-component" });
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain('aria-label="Insert Assembly component"');
    expect(html).toContain('id="assembly-part-name"');
    expect(html).toContain('id="assembly-part-number"');
    expect(html).toContain('id="assembly-source-label"');
    expect(html).toContain('id="assembly-instance-name"');
    expect(html).toContain('id="assembly-mass-kg"');
    expect(html).toContain('id="assembly-position-x"');
    expect(html).toContain('id="assembly-position-y"');
    expect(html).toContain('id="assembly-position-z"');
    expect(html).toContain(">kg<");
    expect(html).toContain(">mm<");
    expect(html).toContain("Ground component");
    expect(html).toContain("Insert Component");
  });

  it("renders one explicit Part-local manual connector frame", () => {
    cadPresentation.patch({ startDialog: "add-connector" });
    const html = renderToStaticMarkup(<AetherCADShell />);
    expect(html).toContain('aria-label="Add manual mate connector"');
    expect(html).toContain('id="connector-name"');
    expect(html).toContain('id="connector-frame-label"');
    expect(html).toContain('id="connector-origin-x"');
    expect(html).toContain('id="connector-origin-y"');
    expect(html).toContain('id="connector-origin-z"');
    expect(html).toContain('id="connector-primary-axis"');
    expect(html).toContain('id="connector-secondary-axis"');
    expect(html).toContain(">mm<");
    expect(html).toContain("Core normalizes the two nonparallel axes");
    expect(html).toContain("Add Connector");
  });

  it("renders persistent mate endpoints, all v1 types, and solved-preview gating", () => {
    cadAssemblyWorkspace.setReady(canonicalAssemblyData);
    cadPresentation.patch({ startDialog: "create-mate" });
    const draft = renderToStaticMarkup(<AetherCADShell />);
    expect(draft).toContain('aria-label="Create Assembly mate"');
    expect(draft).toContain('id="assembly-mate-name"');
    expect(draft).toContain('id="assembly-mate-type"');
    expect(draft).toContain('<option value="fastened" selected="">Fastened</option>');
    expect(draft).toContain('<option value="revolute">Revolute</option>');
    expect(draft).toContain('<option value="prismatic">Prismatic</option>');
    expect(draft).toContain('id="assembly-mate-endpoint-a"');
    expect(draft).toContain('id="assembly-mate-endpoint-b"');
    expect(draft).toContain("Bracket:1 · Mount connector");
    expect(draft).toContain("Arm:1 · Pivot connector");
    expect(draft).toContain("Preview Solve");
    expect(draft).toContain("Apply Mate");

    cadPresentation.patch({
      matePreview: {
        state: "ready",
        revision: "revision-12",
        solveStatus: "solved",
        remainingFreeDOFCount: 0,
        residual: 0,
        diagnosticMessages: [],
      },
    });
    const solved = renderToStaticMarkup(<AetherCADShell />);
    expect(solved).toContain("Preview solved");
    expect(solved).toContain("0 free DOF · residual 0");

  });

  it("renders Preferences and Help instead of inert header controls", () => {
    cadPresentation.patch({ startDialog: "preferences" });
    const preferences = renderToStaticMarkup(<AetherCADShell />);
    expect(preferences).toContain('aria-label="Preferences"');
    expect(preferences).toContain("Aether Dark");
    expect(preferences).toContain("0.01 mm");
    expect(preferences).toContain("canonical `.acad` workspace graph");

    cadPresentation.patch({ startDialog: "help" });
    const help = renderToStaticMarkup(<AetherCADShell />);
    expect(help).toContain('aria-label="Aether CAD Help"');
    expect(help).toContain("Part workflow");
    expect(help).toContain("Assembly workflow");
    expect(help).toContain("Zoom to fit");
  });
});
