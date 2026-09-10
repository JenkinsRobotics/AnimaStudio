import { CADQuantityField } from "./CADQuantityField";
import { unitChoice } from "@aether/core/units";
import { documentUnits, subscribeDocumentUnits } from "../document-preferences";
import { CADDocumentControls } from "./CADDocumentControls";
import { CADVersionsPanel } from "./CADVersionsPanel";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import type { ReactNode } from "react";
import {
  AppIcon,
  AetherIcon,
  Button,
  BottomPanel,
  Checkbox,
  CommandPalette,
  DataTable,
  Dialog,
  DocumentBar,
  DockPanel,
  EmptyState,
  ErrorState,
  FieldRow,
  IconButton,
  ListBox,
  MenuButton,
  NumberField,
  PanelPlacementMenu,
  ProgressOverlay,
  PropertyGrid,
  Rail,
  RailButton,
  SelectField,
  SearchField,
  SegmentedControl,
  Slider,
  Tabs,
  TextField,
  Tree,
  ViewportNavigationCube,
  WorkspaceShell,
  LayoutPresetButton,
  StatusBar,
  StatusDot,
  type WorkspacePanelState,
  type DataTableColumn,
  type CommandPaletteCommand,
  type MenuItem,
  type TreeNode,
} from "@aether/ui";
import { CadIcon, type CadIconName } from "./CadIcon";
import {
  cadCommands,
  type CADCommandID,
  type CADCommandState,
} from "../cad-command-registry";
import { cadWorkspace, type CADInspectorSection } from "../cad-workspace-store";
import { cadAssemblyWorkspace } from "../cad-assembly-workspace-store";
import { cadDrawingWorkspace } from "../cad-drawing-workspace-store";
import type { BOMRowProjection } from "../cad-assembly-bridge";
import { DrawingWorkspace } from "./DrawingWorkspace";
import { CADTraditionalRibbon } from "./CADTraditionalRibbon";
import type { CADRibbonWorkspaceID, CADToolActionID } from "../cad-tool-catalog";
import {
  cadPresentation,
  type CADBrowserPanel,
  type CADPanelID,
  type CADPanelPlacement,
  type CADPresentationSnapshot,
  type CADToolbarMode,
  type CADWorkspaceLayout,
} from "../cad-presentation-store";
import {
  cadAppearance,
  type CADBackgroundPreset,
  type CADDisplayStyle,
  type CADFloorMode,
  type CADLightingPreset,
  type CADMaterialFinish,
} from "../cad-appearance-store";
import {
  cadSelection,
  normalizedSelectionBox,
  type CADSelectionFilter,
} from "../cad-selection-store";
import { cadCameraPresentation } from "../cad-camera-presentation-store";
import {
  assemblyComponentDraftIssues,
  defaultAssemblyComponentDraft,
  type AssemblyComponentDraft,
} from "../cad-assembly-authoring";
import {
  assemblyConnectorDraftIssues,
  connectorAxisOptions,
  defaultAssemblyConnectorDraft,
  type AssemblyConnectorDraft,
  type ConnectorAxisID,
} from "../cad-connector-authoring";
import {
  assemblyMateDraftIssues,
  assemblyMateDOFEditorDraft,
  assemblyMateDOFEditorIssues,
  assemblyMateTypeOptions,
  canApplyAssemblyMate,
  defaultAssemblyMateDraft,
  type AssemblyMateDraft,
  type AssemblyMateDOFEditorDraft,
  type AssemblyMateTypeID,
} from "../cad-mate-authoring";
import {
  assemblyRelationDraftIssues,
  assemblyRelationKindOptions,
  defaultAssemblyRelationDraft,
  relationKinds,
  type AssemblyRelationDraft,
  type AssemblyRelationKind,
} from "../cad-relation-authoring";

const cadCommandCatalog: readonly Omit<CommandPaletteCommand, "disabled" | "disabledReason">[] = [
  { id: "new-part", label: "New Part", category: "File", keywords: ["create workspace"], shortcut: "⌘N", recent: true, icon: "+" },
  { id: "open-part", label: "Open Part", category: "File", keywords: ["load cadpart"], shortcut: "⌘O", icon: "↗" },
  { id: "save-part", label: "Save Part", category: "File", keywords: ["write cadpart"], shortcut: "⌘S", recent: true, icon: "↓" },
  { id: "insert-step", label: "Insert STEP", category: "Insert", keywords: ["import stp exact geometry"], icon: "⇧" },
  { id: "sketch", label: "Create Sketch", category: "Create", keywords: ["plane profile"], shortcut: "R", icon: "⌁" },
  { id: "rebuild-part", label: "Rebuild Part", category: "Create", keywords: ["evaluate extrude"], icon: "↻" },
  { id: "connector", label: "Place Mate Connector", category: "Assembly", keywords: ["anchor frame"], icon: "◇" },
  { id: "fastened", label: "Create Fastened Mate", category: "Assembly", keywords: ["constraint fixed"], icon: "⛓" },
  { id: "assembly-insert-component", label: "Insert Component", category: "Assembly", keywords: ["part definition instance"], icon: "+" },
  { id: "assembly-add-connector", label: "Add Manual Mate Connector", category: "Assembly", keywords: ["part local frame axis"], icon: "◇" },
  { id: "assembly-create-mate", label: "Create Assembly Mate", category: "Assembly", keywords: ["preview fastened revolute prismatic"], icon: "⛓" },
  { id: "assembly-set-mate-dof-value", label: "Set Mate DOF Value", category: "Assembly", keywords: ["angle distance pose"], icon: "↻" },
  { id: "assembly-edit-mate-dof-limits", label: "Edit Mate DOF Limits", category: "Assembly", keywords: ["minimum maximum range"], icon: "↔" },
  { id: "assembly-create-relation", label: "Create DOF Relation", category: "Assembly", keywords: ["gear rack pinion screw linear drive"], icon: "⚙" },
  { id: "assembly-toggle-mate-suppressed", label: "Suppress or Restore Mate", category: "Assembly", keywords: ["constraint disable enable"], icon: "◌" },
  { id: "assembly-remove-mate", label: "Remove Mate", category: "Assembly", keywords: ["delete constraint"], icon: "×" },
  { id: "assembly-toggle-grounded", label: "Ground or Float Component", category: "Assembly", keywords: ["instance fixed free"], icon: "⌖" },
  { id: "assembly-toggle-suppressed", label: "Suppress or Restore Component", category: "Assembly", keywords: ["instance configuration"], icon: "◌" },
  { id: "assembly-remove-instance", label: "Remove Component", category: "Assembly", keywords: ["delete instance"], icon: "−" },
  { id: "clear-mates", label: "Clear Session Mates", category: "Assembly", keywords: ["remove constraints"], icon: "×" },
  { id: "fit-view", label: "Fit View", category: "View", keywords: ["zoom frame all"], shortcut: "F", recent: true, icon: "⌖" },
  { id: "view-top", label: "Top View", category: "View", keywords: ["camera orientation"], icon: "T" },
  { id: "view-bottom", label: "Bottom View", category: "View", keywords: ["camera orientation"], icon: "⌄" },
  { id: "view-front", label: "Front View", category: "View", keywords: ["camera orientation"], icon: "F" },
  { id: "view-back", label: "Back View", category: "View", keywords: ["camera orientation"], icon: "B" },
  { id: "view-right", label: "Right View", category: "View", keywords: ["camera orientation"], icon: "R" },
  { id: "view-left", label: "Left View", category: "View", keywords: ["camera orientation"], icon: "L" },
  { id: "view-isometric", label: "Isometric View", category: "View", keywords: ["camera home orientation"], shortcut: "0", recent: true, icon: "◇" },
  { id: "display-shaded", label: "Shaded", category: "Display", keywords: ["solid faces"], icon: "■" },
  { id: "display-shaded-edges", label: "Shaded with Edges", category: "Display", keywords: ["solid outline"], recent: true, icon: "▧" },
  { id: "display-wireframe", label: "Wireframe", category: "Display", keywords: ["mesh lines"], icon: "◇" },
  { id: "display-hidden-line", label: "Hidden Line", category: "Display", keywords: ["technical outline"], icon: "▱" },
  { id: "display-ghost", label: "Ghost", category: "Display", keywords: ["transparent xray"], icon: "◌" },
  { id: "lighting-studio", label: "Studio Lighting", category: "Scene", keywords: ["environment balanced"], recent: true, icon: "☼" },
  { id: "lighting-softbox", label: "Softbox Lighting", category: "Scene", keywords: ["environment soft"], icon: "◐" },
  { id: "lighting-daylight", label: "Daylight", category: "Scene", keywords: ["environment sun"], icon: "☀" },
  { id: "lighting-dark-room", label: "Dark Room", category: "Scene", keywords: ["environment contrast"], icon: "◑" },
  { id: "toggle-contact-shadows", label: "Toggle Contact Shadows", category: "Scene", keywords: ["floor depth"], icon: "◒" },
  { id: "background-graphite", label: "Graphite Background", category: "Appearance", keywords: ["viewport backdrop"], icon: "●" },
  { id: "background-midnight", label: "Midnight Background", category: "Appearance", keywords: ["viewport backdrop blue"], icon: "◐" },
  { id: "background-slate", label: "Slate Background", category: "Appearance", keywords: ["viewport backdrop gray"], icon: "◒" },
  { id: "finish-matte", label: "Matte Body Finish", category: "Appearance", keywords: ["material rough"], icon: "□" },
  { id: "finish-satin", label: "Satin Body Finish", category: "Appearance", keywords: ["material balanced"], icon: "▧" },
  { id: "finish-gloss", label: "Gloss Body Finish", category: "Appearance", keywords: ["material shiny"], icon: "■" },
  { id: "ground-none", label: "Hide Ground", category: "Scene", keywords: ["floor grid none"], icon: "×" },
  { id: "ground-grid", label: "Show Grid", category: "Scene", keywords: ["ground reference"], icon: "#" },
  { id: "ground-floor", label: "Show Floor", category: "Scene", keywords: ["ground plane"], icon: "▰" },
  { id: "ground-both", label: "Show Grid and Floor", category: "Scene", keywords: ["ground reference plane"], icon: "▦" },
  { id: "toggle-feature-edges", label: "Toggle Feature Edges", category: "Appearance", keywords: ["exact outline"], icon: "◇" },
  { id: "reset-appearance", label: "Reset Viewport Appearance", category: "Appearance", keywords: ["defaults display scene"], icon: "↶" },
  { id: "selection-auto", label: "Selection Filter: Auto", category: "Selection", keywords: ["pick any"], recent: true, icon: "↖" },
  { id: "selection-component", label: "Selection Filter: Component", category: "Selection", keywords: ["occurrence assembly"], icon: "▦" },
  { id: "selection-body", label: "Selection Filter: Body", category: "Selection", keywords: ["solid"], icon: "◇" },
  { id: "selection-face", label: "Selection Filter: Face", category: "Selection", keywords: ["surface topology"], icon: "▱" },
  { id: "selection-edge", label: "Selection Filter: Edge", category: "Selection", keywords: ["curve topology"], icon: "╱" },
  { id: "selection-vertex", label: "Selection Filter: Vertex", category: "Selection", keywords: ["point topology"], icon: "·" },
  { id: "selection-next-filter", label: "Cycle Selection Filter", category: "Selection", keywords: ["next F6"], shortcut: "F6", icon: "⇥" },
];

export function buildCADCommandPaletteCommands(
  states: Readonly<Record<CADCommandID, CADCommandState>>,
): readonly CommandPaletteCommand[] {
  return cadCommandCatalog.map((command) => {
    const state = states[command.id as CADCommandID];
    const disabled = !state.registered || !state.enabled;
    return {
      ...command,
      disabled,
      disabledReason: disabled
        ? state.registered
          ? "Unavailable in the current workspace state."
          : "Command is not connected."
        : undefined,
    };
  });
}

interface FloatingCommandProps {
  icon: CadIconName;
  label: string;
  command?: CADCommandID;
  panel?: CADBrowserPanel;
  active?: boolean;
  disabled?: boolean;
  disabledReason?: string;
  onActivate?: () => void;
}

function FloatingCommand({
  icon,
  label,
  command,
  panel,
  active,
  disabled,
  disabledReason,
  onActivate,
}: FloatingCommandProps) {
  const commands = useSyncExternalStore(
    cadCommands.subscribe,
    cadCommands.snapshot,
    cadCommands.snapshot,
  );
  const commandState: CADCommandState | undefined = command
    ? commands[command]
    : undefined;
  return (
    <RailButton
      className="floating-command"
      label={label}
      active={Boolean(active || commandState?.active)}
      data-command={command}
      data-browser-panel={panel}
      disabled={disabled || (commandState ? !commandState.enabled || !commandState.registered : false)}
      aria-description={disabledReason}
      onClick={() => {
        if (panel) cadPresentation.dispatch({ type: "select-panel", panel });
        if (command) cadCommands.execute(command);
        onActivate?.();
      }}
    >
      <span className="floating-command-icon"><CadIcon name={icon} /></span>
      <span className="floating-command-label" title={disabledReason}>{label}</span>
    </RailButton>
  );
}

function CommandIconButton({
  command,
  label,
  id,
  children,
}: {
  command: CADCommandID;
  label: string;
  id?: string;
  children: ReactNode;
}) {
  const commands = useSyncExternalStore(
    cadCommands.subscribe,
    cadCommands.snapshot,
    cadCommands.snapshot,
  );
  const state = commands[command];
  return (
    <IconButton
      id={id}
      label={label}
      data-command={command}
      aria-pressed={state.active || undefined}
      disabled={!state.enabled || !state.registered}
      onClick={() => cadCommands.execute(command)}
    >
      {children}
    </IconButton>
  );
}

function CommandButton({
  command,
  id,
  className,
  children,
}: {
  command: CADCommandID;
  id?: string;
  className?: string;
  children: ReactNode;
}) {
  const commands = useSyncExternalStore(
    cadCommands.subscribe,
    cadCommands.snapshot,
    cadCommands.snapshot,
  );
  const state = commands[command];
  return (
    <Button
      id={id}
      className={className}
      primary
      active={state.active}
      disabled={!state.enabled || !state.registered}
      onClick={() => cadCommands.execute(command)}
    >
      {children}
    </Button>
  );
}

function WorkspaceLayoutMenu({ layout, toolbarMode }: { layout: CADWorkspaceLayout; toolbarMode: CADToolbarMode }) {
  const items: MenuItem[] = [
    { id: "docked", label: "Docked workbench", icon: "▦", checked: layout === "docked" },
    { id: "expanded", label: "Expanded floating docks", icon: "□", checked: layout === "expanded" },
    { id: "canvas", label: "Canvas only", icon: "◇", checked: layout === "canvas" },
    { id: "toolbar-traditional", label: "Traditional ribbon", icon: "☷", kind: "radio", checked: toolbarMode === "traditional", separatorBefore: true },
    { id: "toolbar-floating", label: "Floating tools", icon: "✥", kind: "radio", checked: toolbarMode === "floating" },
    { id: "reset-panels", label: "Reset panel placements", icon: "↺", separatorBefore: true },
  ];
  return (
    <MenuButton
      className="layout-menu-button"
      label="Workspace layout"
      items={items}
      onSelect={(id) => {
        if (id === "toolbar-traditional" || id === "toolbar-floating") {
          cadPresentation.dispatch({ type: "select-toolbar-mode", mode: id === "toolbar-traditional" ? "traditional" : "floating" });
          return;
        }
        if (id === "reset-panels") {
          cadPresentation.dispatch({ type: "reset-panel-placements" });
          return;
        }
        cadPresentation.dispatch({ type: "select-layout", layout: id as CADWorkspaceLayout });
      }}
    >
      <AetherIcon name="layout" />
    </MenuButton>
  );
}

function CADPanelPlacementMenu({ panel, label, placement }: { panel: CADPanelID; label: string; placement: CADPanelPlacement }) {
  return <PanelPlacementMenu
    className="cad-panel-placement-menu"
    label={label}
    placement={placement}
    onChange={(nextPlacement) => cadPresentation.dispatch({
      type: "set-panel-placement",
      panel,
      placement: nextPlacement,
    })}
  />;
}

function countTreeMatches(nodes: readonly TreeNode[], filter: string): number {
  const query = filter.trim().toLocaleLowerCase();
  let count = 0;
  const visit = (items: readonly TreeNode[]) => items.forEach((item) => {
    if (!query || `${item.label} ${item.badge ?? ""}`.toLocaleLowerCase().includes(query)) count += 1;
    if (item.children) visit(item.children);
  });
  visit(nodes);
  return count;
}

function ItemsPanel({ active }: { active: boolean }) {
  const workspace = useSyncExternalStore(
    cadWorkspace.subscribe,
    cadWorkspace.snapshot,
    cadWorkspace.snapshot,
  );
  const [filter, setFilter] = useState("");
  const presentation = useSyncExternalStore(
    cadPresentation.subscribe,
    cadPresentation.snapshot,
    cadPresentation.snapshot,
  );
  const filterRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (presentation.itemFilterFocusSerial > 0) filterRef.current?.focus();
  }, [presentation.itemFilterFocusSerial]);
  return (
    <section className={`browser-panel${active ? " active" : ""}`} data-panel="items">
      <header className="browser-title">
        <div><strong>Items</strong><small>Geometry · Features · Bodies</small></div>
        <span id="part-count">{workspace.partCount}</span>
      </header>
      <SearchField
        id="items-filter"
        className="browser-filter"
        inputRef={filterRef}
        ariaLabel="Filter Items"
        placeholder="All Items"
        value={filter}
        onQueryChange={setFilter}
        resultCount={countTreeMatches(workspace.itemNodes, filter)}
      />
      <div id="parts-list" className="parts-list">
        <Tree
          ariaLabel="CAD items"
          nodes={workspace.itemNodes}
          onActivate={id=>cadWorkspace.dispatch({type:"item-action",id,actionID:"edit-feature"})}
          onMove={(id,targetID,position)=>cadWorkspace.dispatch({type:"move-item",id,targetID,position})}
          canMove={(id,target,position)=>position!=="inside"&&(id==="rollback-bar"||id.startsWith("feature/"))&&target.startsWith("feature/")&&!id.startsWith("feature/body/")&&!target.startsWith("feature/body/")}

          selectedIDs={workspace.selectedItemIDs}
          expandedIDs={workspace.expandedItemIDs}
          filter={filter}
          onSelect={(ids) => {
            const id = ids[0];
            if (id) cadWorkspace.dispatch({ type: "select-item", id });
          }}
          onToggle={(id) => cadWorkspace.dispatch({ type: "toggle-item", id })}
          onAction={(id, actionID) => cadWorkspace.dispatch({ type: "item-action", id, actionID })}
          emptyState="No matching items"
        />
      </div>
      <div className="sidebar-footer"><button type="button" disabled title="Workspace folders require the canonical workspace graph"><CadIcon name="folder" /></button><button type="button" disabled title="No additional Items commands are available">•••</button></div>
    </section>
  );
}

function ParametersPanel({ active }: { active: boolean }) {
  const units=useSyncExternalStore(subscribeDocumentUnits,documentUnits,documentUnits);
  const presentation = useSyncExternalStore(
    cadPresentation.subscribe,
    cadPresentation.snapshot,
    cadPresentation.snapshot,
  );
  return (
    <section className={`browser-panel${active ? " active" : ""}`} data-panel="parameters">
      <header className="browser-title"><div><strong>Modeling</strong><small>Sketch and solid parameters</small></div><span>{unitChoice(units,"length").unit}</span></header>
      <section className="part-authoring-panel">
        <FieldRow label="Part name" htmlFor="part-name">
          <TextField id="part-name" defaultValue="Part 1" />
        </FieldRow>
        <div className="parameter-grid">
          <FieldRow label="Width" htmlFor="part-width">
            <CADQuantityField family="length" canonicalFactor={0.001} id="part-width" defaultValue={60} min={0.001} step={1}  scrubLabel="Width" />
          </FieldRow>
          <FieldRow label="Height" htmlFor="part-height">
            <CADQuantityField family="length" canonicalFactor={0.001} id="part-height" defaultValue={40} min={0.001} step={1}  scrubLabel="Height" />
          </FieldRow>
          <FieldRow label="Extrude" htmlFor="part-depth">
            <CADQuantityField family="length" canonicalFactor={0.001} id="part-depth" defaultValue={20} min={0.001} step={1}  scrubLabel="Extrude" />
          </FieldRow>
        </div>
        <CommandButton id="rebuild-part" className="author-button" command="rebuild-part">{presentation.partOpen ? "Rebuild Part" : "Create Rectangle Part"}</CommandButton>
      </section>
      <div className="feature-help"><b>Feature history</b><span>Sketch 1 defines the center rectangle. Extrude 1 rebuilds the exact OCCT solid.</span></div>
    </section>
  );
}

function MateActionsMenu() {
  const commands = useSyncExternalStore(
    cadCommands.subscribe,
    cadCommands.snapshot,
    cadCommands.snapshot,
  );
  const assembly = useSyncExternalStore(
    cadAssemblyWorkspace.subscribe,
    cadAssemblyWorkspace.snapshot,
    cadAssemblyWorkspace.snapshot,
  );
  const ready = assembly.loadState === "ready" && assembly.data !== null;
  const canSave = ready && assembly.data.commandAvailability.find((item) => item.id === "save-workspace")?.enabled === true;

  const items: MenuItem[] = [
    { id: "new-assembly", label: "New Assembly", icon: "+" },
    { id: "open-assembly", label: "Open Assembly…", icon: "↗" },
    {
      id: "insert-component",
      label: "Insert Component…",
      icon: "+",
      disabled: !commands["assembly-insert-component"].enabled,
      disabledReason: "Open an editable canonical Assembly first.",
    },
    {
      id: "add-connector",
      label: "Add Manual Connector…",
      icon: "◇",
      disabled: !commands["assembly-add-connector"].enabled,
      disabledReason: "Select exactly one editable Assembly component first.",
    },
    {
      id: "create-mate",
      label: "Create Mate…",
      icon: "⛓",
      disabled: !commands["assembly-create-mate"].enabled,
      disabledReason: "Add connectors to at least two active component instances.",
    },
    {
      id: "create-relation",
      label: "Create DOF Relation…",
      icon: "⚙",
      disabled: !commands["assembly-create-relation"].enabled,
      disabledReason: "Create at least two compatible free revolute or prismatic DOFs.",
    },
    {
      id: "set-mate-dof-value",
      label: "Set Selected Mate Value…",
      icon: "↻",
      disabled: !commands["assembly-set-mate-dof-value"].enabled,
      disabledReason: "Select one active revolute or prismatic mate with a free DOF.",
    },
    {
      id: "edit-mate-dof-limits",
      label: "Edit Selected Mate Limits…",
      icon: "↔",
      disabled: !commands["assembly-edit-mate-dof-limits"].enabled,
      disabledReason: "Select one active revolute or prismatic mate with a free DOF.",
    },
    {
      id: "toggle-mate-suppressed",
      label: commands["assembly-toggle-mate-suppressed"].active ? "Restore Selected Mate" : "Suppress Selected Mate",
      icon: "◌",
      disabled: !commands["assembly-toggle-mate-suppressed"].enabled,
      disabledReason: "Select exactly one persistent Assembly mate.",
    },
    {
      id: "remove-mate",
      label: "Remove Selected Mate",
      icon: "×",
      danger: true,
      disabled: !commands["assembly-remove-mate"].enabled,
      disabledReason: "Select exactly one persistent Assembly mate.",
    },
    {
      id: "save-assembly",
      label: "Save Assembly…",
      icon: "↓",
      disabled: !canSave,
      disabledReason: ready ? "Core has disabled workspace persistence." : "Open a canonical Assembly first.",
    },
  ];
  return (
    <MenuButton
      label="Mate actions"
      items={items}
      onSelect={(id) => {
        if (id === "new-assembly") cadPresentation.dispatch({ type: "create-assembly-workspace", name: "Untitled Assembly" });
        if (id === "open-assembly") cadPresentation.dispatch({ type: "open-assembly-workspace" });
        if (id === "insert-component") cadCommands.execute("assembly-insert-component");
        if (id === "add-connector") cadCommands.execute("assembly-add-connector");
        if (id === "create-mate") cadCommands.execute("assembly-create-mate");
        if (id === "create-relation") cadCommands.execute("assembly-create-relation");
        if (id === "set-mate-dof-value") cadCommands.execute("assembly-set-mate-dof-value");
        if (id === "edit-mate-dof-limits") cadCommands.execute("assembly-edit-mate-dof-limits");
        if (id === "toggle-mate-suppressed") cadCommands.execute("assembly-toggle-mate-suppressed");
        if (id === "remove-mate") cadCommands.execute("assembly-remove-mate");
        if (id === "save-assembly") cadPresentation.dispatch({ type: "save-assembly-workspace" });
      }}
    >
      •••
    </MenuButton>
  );
}

const assemblyTabs = [
  { id: "structure", label: "Structure" },
  { id: "constraints", label: "Mates" },
  { id: "bom", label: "BOM" },
] as const;

const bomColumns: readonly DataTableColumn<BOMRowProjection>[] = [
  { id: "part-number", header: "Part #", cell: (row) => row.part_number ?? "—", sortValue: (row) => row.part_number, sortable: true, pinned: true, width: 86 },
  { id: "name", header: "Name", cell: (row) => row.name, sortValue: (row) => row.name, sortable: true, width: 130 },
  { id: "quantity", header: "Qty", cell: (row) => String(row.quantity), sortValue: (row) => row.quantity, sortable: true, align: "end", width: 55 },
  { id: "material", header: "Material", cell: (row) => row.material_name ?? "—", sortValue: (row) => row.material_name, sortable: true, width: 95 },
];

function LegacyMateProof() {
  const workspace = useSyncExternalStore(
    cadWorkspace.subscribe,
    cadWorkspace.snapshot,
    cadWorkspace.snapshot,
  );
  return (
    <>
      <aside className="assembly-session-notice" role="note">
        <strong>Session-only Part proof</strong>
        <span>These Part-viewer connectors remain separate from a saved Assembly. Create or open an Assembly to use persistent mates, solve, and BOM.</span>
      </aside>
      <div className="panel-heading"><span>MATE CONNECTORS</span><span id="connector-count">{workspace.connectorItems.length}</span></div>
      <div id="connectors-list" className="connectors-list">
        <ListBox
          ariaLabel="Mate connectors"
          items={workspace.connectorItems}
          selectedIDs={workspace.selectedConnectorIDs}
          onSelect={(ids) => {
            const id = ids[0];
            if (id) cadWorkspace.dispatch({ type: "select-connector", id });
          }}
          onAction={(id, actionID) => cadWorkspace.dispatch({ type: "connector-action", id, actionID })}
          emptyState="No connector anchors yet."
        />
      </div>
      <div className="panel-heading section-heading"><span>FASTENED MATES</span><span id="mate-count">{workspace.mateItems.length}</span></div>
      <div id="mates-list" className="mates-list">
        <ListBox ariaLabel="Fastened mates" items={workspace.mateItems} selectedIDs={new Set()} selectionMode="none" emptyState="No mates yet." />
      </div>
    </>
  );
}

function MatesPanel({ active }: { active: boolean }) {
  const assembly = useSyncExternalStore(
    cadAssemblyWorkspace.subscribe,
    cadAssemblyWorkspace.snapshot,
    cadAssemblyWorkspace.snapshot,
  );
  const ready = assembly.loadState === "ready" && assembly.data !== null;
  const body = (() => {
    if (assembly.loadState === "loading") {
      return <EmptyState compact icon="…" title="Loading Assembly" description={assembly.message} />;
    }
    if (assembly.loadState === "error") {
      return <ErrorState compact title="Assembly unavailable" description={assembly.message} />;
    }
    if (!ready) {
      if (assembly.activeTab === "constraints") return <LegacyMateProof />;
      return <EmptyState
        compact
        icon={assembly.activeTab === "structure" ? "▱" : "▦"}
        title={assembly.activeTab === "structure" ? "Persistent Assembly graph unavailable" : "BOM unavailable"}
        description={assembly.message}
      />;
    }
    if (assembly.activeTab === "structure") {
      return <>
        <SearchField
          className="browser-filter"
          ariaLabel="Filter Assembly structure"
          placeholder="Filter components"
          value={assembly.filter}
          onQueryChange={(filter) => cadAssemblyWorkspace.dispatch({ type: "set-filter", filter })}
          resultCount={countTreeMatches(assembly.data.treeNodes, assembly.filter)}
        />
        <div className="canonical-assembly-tree">
          <Tree
            ariaLabel="Assembly structure"
            nodes={assembly.data.treeNodes}
            selectedIDs={assembly.selectedEntityIDs}
            expandedIDs={assembly.expandedEntityIDs}
            filter={assembly.filter}
            onSelect={(ids, mode) => cadAssemblyWorkspace.dispatch({ type: "select-entities", ids, mode })}
            onToggle={(id, expanded) => cadAssemblyWorkspace.dispatch({ type: "toggle-entity", id, expanded })}
            emptyState="No matching Assembly items"
          />
        </div>
      </>;
    }
    if (assembly.activeTab === "bom") {
      return <div className="canonical-bom-table">
        <SegmentedControl
          ariaLabel="BOM structure"
          value={assembly.data.summary.bomMode ?? "hierarchical"}
          options={[
            { id: "hierarchical", label: "Hierarchical" },
            { id: "flattened", label: "Flattened" },
          ]}
          onChange={(mode) => cadAssemblyWorkspace.dispatch({
            type: "select-bom-mode",
            mode: mode as "hierarchical" | "flattened",
          })}
        />
        <DataTable
          ariaLabel="Assembly bill of materials"
          rows={assembly.data.bomRows}
          rowID={(row) => row.row_id}
          columns={bomColumns}
          selectedIDs={assembly.selectedBOMRowIDs}
          onSelect={(ids, mode) => cadAssemblyWorkspace.dispatch({ type: "select-bom-rows", ids, mode })}
          filterText={(row) => `${row.part_number ?? ""} ${row.name} ${row.material_name ?? ""}`}
          emptyState="Core returned no BOM rows for this Assembly."
          virtualizeThreshold={100}
          height={430}
        />
      </div>;
    }
    return <div className="canonical-assembly-constraints">
      <div className="panel-heading"><span>CONNECTORS</span><span>{assembly.data.connectorItems.length}</span></div>
      <ListBox ariaLabel="Canonical mate connectors" items={assembly.data.connectorItems} selectedIDs={assembly.selectedEntityIDs} onSelect={(ids, mode) => cadAssemblyWorkspace.dispatch({ type: "select-entities", ids, mode })} emptyState="No connector definitions." />
      <div className="panel-heading section-heading"><span>MATES</span><span>{assembly.data.mateItems.length}</span></div>
      <ListBox ariaLabel="Canonical mates" items={assembly.data.mateItems} selectedIDs={assembly.selectedEntityIDs} onSelect={(ids, mode) => cadAssemblyWorkspace.dispatch({ type: "select-entities", ids, mode })} emptyState="No mates." />
      <div className="panel-heading section-heading"><span>RELATIONS</span><span>{assembly.data.relationItems.length}</span></div>
      <ListBox ariaLabel="Canonical relations" items={assembly.data.relationItems} selectedIDs={assembly.selectedEntityIDs} onSelect={(ids, mode) => cadAssemblyWorkspace.dispatch({ type: "select-entities", ids, mode })} emptyState="No relations." />
      {assembly.data.problemItems.length > 0 ? <><div className="panel-heading section-heading"><span>DIAGNOSTICS</span><span>{assembly.data.problemItems.length}</span></div><ListBox ariaLabel="Assembly diagnostics" items={assembly.data.problemItems} selectedIDs={assembly.selectedEntityIDs} onSelect={(ids, mode) => cadAssemblyWorkspace.dispatch({ type: "select-entities", ids, mode })} /></> : null}
    </div>;
  })();
  return (
    <section className={`browser-panel${active ? " active" : ""}`} data-panel="mates">
      <header className="browser-title"><div><strong>Assembly</strong><small>{ready ? assembly.message : "Canonical graph · session proof"}</small></div><MateActionsMenu /></header>
      <div className="assembly-workbench-tabs"><Tabs tabs={assemblyTabs} activeID={assembly.activeTab} onSelect={(id) => cadAssemblyWorkspace.dispatch({ type: "select-tab", tab: id as typeof assembly.activeTab })} /></div>
      <div className="assembly-workbench-body">{body}</div>
    </section>
  );
}

function ReadOnlyPropertyGrid({
  ariaLabel,
  emptyState,
}: {
  ariaLabel: string;
  emptyState: string;
}) {
  const workspace = useSyncExternalStore(
    cadWorkspace.subscribe,
    cadWorkspace.snapshot,
    cadWorkspace.snapshot,
  );
  return (
    <ReadOnlyPropertySections sections={workspace.inspectorSections} ariaLabel={ariaLabel} emptyState={emptyState} />
  );
}

function ReadOnlyPropertySections({
  sections,
  ariaLabel,
  emptyState,
}: {
  sections: readonly CADInspectorSection[];
  ariaLabel: string;
  emptyState: string;
}) {
  return <PropertyGrid
      ariaLabel={ariaLabel}
      sections={sections.map((section) => ({
        ...section,
        properties: section.properties.map((property) => ({
          ...property,
          editor: <output>{property.value}</output>,
          readOnly: true,
        })),
      }))}
      emptyState={emptyState}
    />;
}

const unavailableInspectionTools = [
  {
    id: "measure",
    label: "Measure",
    description: "Distance, angle, radius, and area queries require an exact Core measurement contract.",
  },
  {
    id: "mass-properties",
    label: "Mass properties",
    description: "Volume, center of mass, and inertia require material density and Core analysis support.",
  },
  {
    id: "section-analysis",
    label: "Section analysis",
    description: "Exact clipping curves and section faces are not exposed by the Core bridge yet.",
  },
  {
    id: "curvature",
    label: "Curvature",
    description: "Surface continuity and curvature evaluation are not exposed by the Core bridge yet.",
  },
] as const;

function InspectPanel({ active }: { active: boolean }) {
  return (
    <section className={`browser-panel${active ? " active" : ""}`} data-panel="inspect">
      <header className="browser-title"><div><strong>Inspect</strong><small>Exact model and topology facts</small></div><span>OCCT</span></header>
      <div className="inspect-panel-scroll">
        <section className="inspect-summary" aria-label="Exact model summary">
          <div className="panel-heading"><span>MODEL SUMMARY</span></div>
          <ReadOnlyPropertyGrid
            ariaLabel="Exact model inspection"
            emptyState="Create or open a Part to inspect its document, features, sketch definition, and exact topology."
          />
          <CommandButton id="inspect-fit-view" command="fit-view">Fit current model</CommandButton>
        </section>
        <section className="inspect-analysis" aria-label="Analysis availability">
          <div className="panel-heading"><span>ANALYSIS</span><span>CORE</span></div>
          <div className="inspect-capability-list">
            {unavailableInspectionTools.map((tool) => (
              <article className="inspect-capability" key={tool.id}>
                <div><strong>{tool.label}</strong><p id={`inspect-${tool.id}-reason`}>{tool.description}</p></div>
                <Button
                  disabled
                  aria-describedby={`inspect-${tool.id}-reason`}
                  title={tool.description}
                >Unavailable</Button>
              </article>
            ))}
          </div>
        </section>
      </div>
    </section>
  );
}

function VisualizationPanel({ active }: { active: boolean }) {
  const appearance = useSyncExternalStore(
    cadAppearance.subscribe,
    cadAppearance.snapshot,
    cadAppearance.snapshot,
  );
  return (
    <section className={`browser-panel${active ? " active" : ""}`} data-panel="visualization">
      <header className="browser-title"><div><strong>Visualization</strong><small>Viewport appearance · this session</small></div><span>GPU</span></header>
      <div className="visualization-panel-scroll">
        <section className="visualization-controls" aria-label="Viewport appearance">
          <div className="panel-heading"><span>DISPLAY</span></div>
          <div className="visualization-fields">
            <FieldRow label="Style">
              <SelectField
                aria-label="Viewport display style"
                value={appearance.displayStyle}
                options={[
                  { value: "shaded-edges", label: "Shaded with edges" },
                  { value: "shaded", label: "Shaded" },
                  { value: "wireframe", label: "Wireframe" },
                  { value: "hidden-line", label: "Hidden line" },
                  { value: "ghost", label: "Ghost" },
                ]}
                onChange={(event) => cadAppearance.dispatch({ type: "set-display-style", style: event.target.value as CADDisplayStyle })}
              />
            </FieldRow>
            <FieldRow label="Background" htmlFor="appearance-background">
              <SelectField
                id="appearance-background"
                value={appearance.background}
                options={[
                  { value: "graphite", label: "Graphite" },
                  { value: "midnight", label: "Midnight blue" },
                  { value: "slate", label: "Slate" },
                  { value: "paper", label: "Paper — adaptive grid required", disabled: true },
                ]}
                onChange={(event) => cadAppearance.dispatch({ type: "set-background", background: event.target.value as CADBackgroundPreset })}
              />
            </FieldRow>
            <Checkbox checked={appearance.edgesVisible} onChange={(event) => cadAppearance.dispatch({ type: "set-edges-visible", visible: event.target.checked })} label="Exact feature edges" description="Show OCCT-derived edge segments on every Body." />
          </div>
        </section>
        <section className="visualization-controls" aria-label="Material and lighting">
          <div className="panel-heading"><span>MATERIAL + LIGHTING</span></div>
          <div className="visualization-fields">
            <FieldRow label="Lighting">
              <SelectField
                aria-label="Viewport lighting preset"
                value={appearance.lightingPreset}
                options={[
                  { value: "studio", label: "Studio" },
                  { value: "softbox", label: "Softbox" },
                  { value: "daylight", label: "Daylight" },
                  { value: "dark-room", label: "Dark room" },
                ]}
                onChange={(event) => cadAppearance.dispatch({ type: "set-lighting-preset", preset: event.target.value as CADLightingPreset })}
              />
            </FieldRow>
            <FieldRow label="Body finish">
              <SegmentedControl ariaLabel="Body finish" value={appearance.materialFinish} options={[{ id: "matte", label: "Matte" }, { id: "satin", label: "Satin" }, { id: "gloss", label: "Gloss" }]} onChange={(finish) => cadAppearance.dispatch({ type: "set-material-finish", finish: finish as CADMaterialFinish })} />
            </FieldRow>
            <FieldRow label="Environment">
              <Slider ariaLabel="Environment intensity" value={appearance.environmentPercent} min={0} max={200} step={5} unit="%" onChange={(percent) => cadAppearance.dispatch({ type: "set-environment-percent", percent })} />
            </FieldRow>
            <FieldRow label="Ground">
              <SegmentedControl ariaLabel="Viewport ground mode" value={appearance.floorMode} options={[{ id: "none", label: "None" }, { id: "grid", label: "Grid" }, { id: "floor", label: "Floor" }, { id: "both", label: "Both" }]} onChange={(mode) => cadAppearance.dispatch({ type: "set-floor-mode", mode: mode as CADFloorMode })} />
            </FieldRow>
            <Checkbox checked={appearance.contactShadowsVisible} onChange={(event) => cadAppearance.dispatch({ type: "set-contact-shadows-visible", visible: event.target.checked })} label="Contact shadows" description="Ground part placement with renderer-owned shadows." />
            <Button onClick={() => cadAppearance.dispatch({ type: "reset" })}>Reset appearance</Button>
          </div>
        </section>
        <section className="visualization-unavailable" aria-label="Unavailable appearance tools">
          <button type="button" disabled title="Requires adaptive grid, edge, annotation, and contrast colors"><b>Light display theme</b><span>Adaptive renderer palette required</span></button>
          <button type="button" disabled title="Requires persistent face/body material assignments"><b>Per-face materials</b><span>Canonical assignment graph required</span></button>
        </section>
      </div>
    </section>
  );
}

function InspectorPanel({ placement }: { placement: CADPanelPlacement }) {
  const presentation = useSyncExternalStore(
    cadPresentation.subscribe,
    cadPresentation.snapshot,
    cadPresentation.snapshot,
  );
  const assembly = useSyncExternalStore(
    cadAssemblyWorkspace.subscribe,
    cadAssemblyWorkspace.snapshot,
    cadAssemblyWorkspace.snapshot,
  );
  const canonicalAssembly = presentation.activePanel === "mates" && assembly.loadState === "ready" && assembly.data !== null;
  return (
    <aside className="inspector-sidebar">
      <DockPanel
        title={canonicalAssembly ? "Assembly properties" : "Properties"}
        actions={<CADPanelPlacementMenu panel="inspector" label="Properties" placement={placement} />}
        width="100%"
      >
        {canonicalAssembly ? <ReadOnlyPropertySections
          sections={assembly.data!.inspectorSections}
          ariaLabel="Assembly inspector"
          emptyState="Select an Assembly entity to inspect Core-projected values."
        /> : <ReadOnlyPropertyGrid
            ariaLabel="Part inspector"
            emptyState="Create or open a Part to inspect document, feature, and exact-topology values."
          />}
      </DockPanel>
    </aside>
  );
}

function WorkbenchBottomPanel({ presentation, sidebar = false }: { presentation: CADPresentationSnapshot; sidebar?: boolean }) {
  const workspace = useSyncExternalStore(
    cadWorkspace.subscribe,
    cadWorkspace.snapshot,
    cadWorkspace.snapshot,
  );
  const history = <div id="history-list" className="history-list"><ListBox ariaLabel="Feature history" items={workspace.historyItems} selectedIDs={new Set()} onSelect={(ids) => { const id = ids[0]; if (id) cadWorkspace.dispatch({ type: "activate-history", id }); }} onActivate={(id) => cadWorkspace.dispatch({ type: "activate-history", id })} emptyState="Create or import geometry to build history." /></div>;
  const problems = <div className="problems-list"><ListBox ariaLabel="Rebuild problems" items={workspace.problemItems} selectedIDs={new Set()} selectionMode="none" emptyState="No rebuild problems." /></div>;
  if (sidebar) return <section className="cad-sidebar-history" aria-label="Feature history sidebar">
    <Tabs tabs={[{id: "history", label: "History"}, {id: "problems", label: "Problems"}]} activeID={presentation.bottomPanelActiveID} onSelect={id => cadPresentation.dispatch({type: "select-bottom-panel", id: id as "history" | "problems"})} />
    {presentation.bottomPanelActiveID === "history" ? history : problems}
  </section>;
  return (
    <div className={`cad-bottom-workbench${sidebar ? " cad-sidebar-history" : ""}`}>
      {!sidebar && <CADPanelPlacementMenu panel="bottom" label="History and Problems" placement={presentation.panelPlacements.bottom} />}
      <BottomPanel
        ariaLabel="Rebuild workbench"
        activeID={presentation.bottomPanelActiveID}
        collapsed={sidebar ? false : presentation.bottomPanelCollapsed}
        onSelect={(id) => cadPresentation.dispatch({ type: "select-bottom-panel", id: id as "history" | "problems" })}
        onCollapsedChange={(collapsed) => cadPresentation.dispatch({ type: "set-bottom-panel-collapsed", collapsed })}
        tabs={[
          { id: "history", label: "History", badge: workspace.historyItems.length, icon: "↺", content: history },
          { id: "problems", label: "Problems", badge: workspace.problemItems.length || undefined, icon: "!", content: problems },
        ]}
      />
    </div>
  );
}

function ViewportTools({
  activePanel,
}: {
  activePanel: CADBrowserPanel;
}) {
  return (
    <>
      <Rail className="viewport-mode-tools" aria-label="Workspace modes">
        <FloatingCommand icon="model" label="Modeling" panel="parameters" active={activePanel === "parameters"} />
        <FloatingCommand icon="items" label="Items" panel="items" active={activePanel === "items"} />
        <FloatingCommand icon="assembly" label="Assembly" panel="mates" active={activePanel === "mates"} />
        <FloatingCommand icon="sketch" label="Drawing" onActivate={() => cadPresentation.dispatch({ type: "select-workspace-mode", mode: "drawing" })} />
        <FloatingCommand icon="view" label="Inspect" panel="inspect" active={activePanel === "inspect"} />
        <FloatingCommand icon="view" label="Visualization" panel="visualization" active={activePanel === "visualization"} />
      </Rail>
      <Rail className="viewport-authoring-tools" aria-label="Modeling tools">
        <FloatingCommand icon="search" label="Search" onActivate={() => cadPresentation.dispatch({ type: "focus-items-filter" })} />
        <FloatingCommand icon="sketch" label="Sketch" command="sketch" />
        <FloatingCommand icon="step" label="Insert STEP" command="insert-step" />
        <FloatingCommand icon="connector" label="Connector" command="connector" />
        <FloatingCommand icon="mate" label="Fastened" command="fastened" />
        <FloatingCommand icon="items" label="Cycle Selection Filter" command="selection-next-filter" />
      </Rail>
      <Rail className="viewport-bottom-tools" aria-label="Viewport navigation">
        <FloatingCommand icon="fit" label="Zoom to Fit" command="fit-view" />
      </Rail>
      <div className="viewport-right-tools" aria-label="Viewport display tools">
        <CommandIconButton label="Zoom to Fit" command="fit-view"><CadIcon name="fit" /></CommandIconButton>
        <IconButton label="Show History" onClick={() => cadPresentation.dispatch({ type: "toggle-history" })}><CadIcon name="history" /></IconButton>
      </div>
    </>
  );
}

function SelectionControls() {
  const selection = useSyncExternalStore(
    cadSelection.subscribe,
    cadSelection.snapshot,
    cadSelection.snapshot,
  );
  const bounds = selection.box ? normalizedSelectionBox(selection.box) : null;
  return (
    <>
      <div className="selection-filter-hud" aria-label="Viewport selection tools">
        <span>Selection</span>
        <SelectField
          aria-label="Selection filter"
          value={selection.filter}
          options={[
            { value: "auto", label: "Auto" },
            { value: "component", label: "Component" },
            { value: "body", label: "Body" },
            { value: "face", label: "Face" },
            { value: "edge", label: "Edge" },
            { value: "vertex", label: "Vertex" },
          ]}
          onChange={(event) => cadSelection.dispatch({ type: "set-filter", filter: event.target.value as CADSelectionFilter })}
        />
        <small>{selection.items.length} selected · drag → Window · drag ← Crossing</small>
      </div>
      {selection.box && bounds ? <div
        className={`cad-selection-box ${selection.box.mode}`}
        style={{ left: bounds.left, top: bounds.top, width: bounds.width, height: bounds.height }}
        aria-hidden="true"
      ><span>{selection.box.mode === "window" ? "Window" : "Crossing"}</span></div> : null}
    </>
  );
}

function DrawingWorkspaceRoute({ active }: { active: boolean }) {
  const drawing = useSyncExternalStore(
    cadDrawingWorkspace.subscribe,
    cadDrawingWorkspace.snapshot,
    cadDrawingWorkspace.snapshot,
  );
  return <div
    className={`cad-drawing-route${active ? " active" : ""}`}
    aria-hidden={!active}
    inert={!active}
  >
    <DrawingWorkspace
      snapshot={drawing}
      onAction={(action) => cadDrawingWorkspace.dispatch(action)}
      onCommand={() => {}}
      commandsConnected={false}
      onExit={() => cadPresentation.dispatch({ type: "select-workspace-mode", mode: "modeling" })}
    />
  </div>;
}

function ViewportCameraNavigation() {
  const camera = useSyncExternalStore(
    cadCameraPresentation.subscribe,
    cadCameraPresentation.snapshot,
    cadCameraPresentation.snapshot,
  );
  return (
    <ViewportNavigationCube
      id="view-cube"
      className="view-cube"
      orientation={camera.orientation}
      onSelectView={(view) =>
        cadCameraPresentation.dispatch({ type: "select-view", view })
      }
      onFit={() => cadCameraPresentation.dispatch({ type: "fit-isometric" })}
      onNudge={(horizontalSteps, verticalSteps) =>
        cadCameraPresentation.dispatch({
          type: "nudge",
          horizontalSteps,
          verticalSteps,
        })
      }
      onRoll={(quarterTurns) =>
        cadCameraPresentation.dispatch({ type: "roll", quarterTurns })
      }
    />
  );
}

function ViewportSurface({
  presentation,
}: {
  presentation: CADPresentationSnapshot;
}) {
  return (
    <section id="viewport" className="viewport" aria-label="3D CAD viewport">
      <div className="instructions"><strong>CAD authoring</strong><span>Sketch → Extrude · Connector → Fastened Mate</span><span>RMB orbit · MMB pan · wheel zoom</span></div>
      <ViewportTools activePanel={presentation.activePanel} />
      <SelectionControls />
      {presentation.activeTool === "connector" ? <div id="connector-card" className="mate-card">
        <div className="mate-title"><span>Place Mate Connector</span><button type="button" aria-label="Cancel tool" onClick={() => cadPresentation.dispatch({ type: "cancel-tool" })}>×</button></div>
        <div className="single-step"><span className="step-dot active">+</span><div><b>Choose an exact anchor</b><span>Hover a face, edge, circle/ellipse, shaft/bore, cone, sphere, or vertex and click. The connector remains attached to that Part.</span></div></div>
        <p>Create as many connectors as needed. A connector is one half of a future mate.</p>
      </div> : null}
      {presentation.activeTool === "fastened" ? <div id="mate-card" className="mate-card">
        <div className="mate-title"><span>Fastened Mate</span><button type="button" aria-label="Cancel tool" onClick={() => cadPresentation.dispatch({ type: "cancel-tool" })}>×</button></div>
        <div className="mate-step"><span className="step-dot active">1</span><div><b>Moving connector</b><span>{presentation.movingPick}</span></div></div>
        <div className="mate-step"><span className={`step-dot${presentation.targetPick.startsWith("Choose") ? " active" : ""}`}>2</span><div><b>Target connector</b><span>{presentation.targetPick}</span></div></div>
        <p>Click visible connector anchors or use Pick in the connector list. Origins and X axes align; primary Z axes oppose.</p>
      </div> : null}
      {presentation.hover ? <div id="hover-card" className="hover-card"><b>{presentation.hover.partName}</b><span>{presentation.hover.label}</span><small>{presentation.hover.detail}</small></div> : null}
      {presentation.awaitingSketchPlane ? <div id="sketch-plane-card" className="sketch-plane-card">
        <header><div><b>Create Sketch</b><span>Select a plane</span></div><button type="button" title="Cancel" onClick={() => cadPresentation.dispatch({ type: "cancel-sketch-plane" })}>×</button></header>
        <p>Choose <b>Top</b>, <b>Front</b>, or <b>Right Plane</b> in the Items browser. The new sketch opens normal to that plane with its center anchored to the Origin.</p>
      </div> : null}
      <ProgressOverlay
        open={presentation.loading !== null && !presentation.loading.backgrounded}
        label={presentation.loading?.label ?? "Working"}
        detail={presentation.loading?.detail}
        phase={presentation.loading?.phase}
        value={presentation.loading?.value}
        max={presentation.loading?.max}
        onCancel={presentation.loading?.canCancel ? () => cadPresentation.dispatch({ type: "cancel-loading" }) : undefined}
        onBackground={presentation.loading?.canBackground ? () => cadPresentation.dispatch({ type: "background-loading" }) : undefined}
      />
      <ViewportCameraNavigation />
    </section>
  );
}

function StartCenter({ presentation }: { presentation: CADPresentationSnapshot }) {
  const [partName, setPartName] = useState("Part 1");
  const [workspaceType, setWorkspaceType] = useState<"part" | "assembly">("part");
  const closeDialog = () => cadPresentation.dispatch({ type: "show-start-dialog", dialog: null });
  const enterWorkspaceAndExecute = (command: CADCommandID) => {
    cadPresentation.dispatch({ type: "show-start-screen", screen: "workspace" });
    cadCommands.execute(command);
  };
  const recovery = presentation.startScreen === "recovery";
  return (
    <>
    {presentation.startScreen !== "workspace" && <section className="cad-start-center" aria-label={recovery ? "Recovery" : "Aether CAD Home"}>
      <header className="cad-start-header">
        <div><span className="cad-start-mark"><AppIcon app="cad" size={34} /></span><div><strong>{recovery ? "Recovery" : "Aether CAD"}</strong><small>{recovery ? "Safe document restoration" : "Mechanical design workspace"}</small></div></div>
        <Button onClick={() => cadPresentation.dispatch({ type: "show-start-screen", screen: "workspace" })}>Return to workspace</Button>
      </header>
      {recovery ? (
        <EmptyState
          title="No recovery revisions"
          description="No autosave or damaged-cache revisions are available in this local workspace. Open a saved Part to continue safely."
          icon="↺"
          primaryAction={<Button primary onClick={() => enterWorkspaceAndExecute("open-part")}>Open saved Part</Button>}
          secondaryAction={<Button onClick={() => cadPresentation.dispatch({ type: "show-start-screen", screen: "home" })}>Back to Home</Button>}
        />
      ) : (
        <div className="cad-home-content">
          <section className="cad-home-hero">
            <small>START</small>
            <h1>Design a Part or bring in exact geometry.</h1>
            <p>Start with an editable sketch-and-extrude workspace, reopen a native Part, or import STEP reference geometry for assembly work.</p>
            <div className="cad-home-actions">
              <Button primary onClick={() => cadPresentation.dispatch({ type: "show-start-dialog", dialog: "new-workspace" })}>New workspace</Button>
              <Button onClick={() => enterWorkspaceAndExecute("open-part")}>Open Part</Button>
              <Button onClick={() => cadPresentation.dispatch({ type: "open-assembly-workspace" })}>Open Assembly</Button>
              <Button onClick={() => cadPresentation.dispatch({ type: "show-start-dialog", dialog: "import" })}>Import STEP</Button>
            </div>
          </section>
          <section className="cad-home-section" aria-label="Workspace types">
            <header><div><strong>Workspace types</strong><small>Choose a canonical starting context</small></div></header>
            <div className="cad-template-grid">
              <button type="button" onClick={() => { setWorkspaceType("part"); cadPresentation.dispatch({ type: "show-start-dialog", dialog: "new-workspace" }); }}><CadIcon name="model" /><b>Part</b><span>Sketch and exact solid features</span></button>
              <button type="button" onClick={() => { setWorkspaceType("assembly"); setPartName("Assembly 1"); cadPresentation.dispatch({ type: "show-start-dialog", dialog: "new-workspace" }); }}><CadIcon name="assembly" /><b>Assembly</b><span>Persistent mates, solve, and BOM</span></button>
              <button type="button" disabled title="Available when exact drawing projections land"><CadIcon name="items" /><b>Drawing</b><span>Exact projections required</span></button>
            </div>
          </section>
          <section className="cad-home-section cad-home-recent" aria-label="Recent workspaces">
            <header><div><strong>Recent workspaces</strong><small>Local recent history</small></div></header>
            <EmptyState compact title="No recent workspaces" description="Open a native .acpart or .acad workspace and it will be available during this session." icon="◇" />
          </section>
          <Button className="cad-recovery-link" onClick={() => cadPresentation.dispatch({ type: "show-start-screen", screen: "recovery" })}>Open Recovery</Button>
        </div>
      )}
    </section>}
      <Dialog
        open={presentation.startDialog === "new-workspace"}
        title={`New ${workspaceType === "assembly" ? "Assembly" : "Part"} workspace`}
        onClose={closeDialog}
        actions={<><Button onClick={closeDialog}>Cancel</Button><Button primary disabled={!partName.trim()} onClick={() => cadPresentation.dispatch({ type: workspaceType === "assembly" ? "create-assembly-workspace" : "create-part-workspace", name: partName.trim() })}>Create {workspaceType === "assembly" ? "Assembly" : "Part"}</Button></>}
      >
        <div className="cad-start-form">
          <FieldRow label="Workspace name" htmlFor="new-part-name"><TextField id="new-part-name" value={partName} onChange={(event) => setPartName(event.target.value)} /></FieldRow>
          <FieldRow label="Type" htmlFor="new-workspace-type"><SelectField id="new-workspace-type" value={workspaceType} options={[{ value: "part", label: "Part" }, { value: "assembly", label: "Assembly" }, { value: "drawing", label: "Drawing — unavailable", disabled: true }]} onChange={(event) => setWorkspaceType(event.target.value as "part" | "assembly")} /></FieldRow>
          <FieldRow label="Template" htmlFor="new-part-template"><SelectField id="new-part-template" value={workspaceType === "assembly" ? "empty-assembly" : "empty-part"} options={workspaceType === "assembly" ? [{ value: "empty-assembly", label: "Empty Assembly" }] : [{ value: "empty-part", label: "Empty Part — add sketches and features" }]} disabled /></FieldRow>
          <FieldRow label="Units" htmlFor="new-part-units"><SelectField id="new-part-units" value="millimeters" options={[{ value: "millimeters", label: "Millimeters (mm)" }]} disabled /></FieldRow>
          <p className="cad-form-note">{workspaceType === "assembly" ? "The native .acad workspace keeps Core-owned instances, connectors, mates, DOF, relations, solve state, and derived BOM." : "Start with an empty Part. Add sketch profiles, revolve or extrude them, then edit the feature tree and bodies. Geometry is rebuilt by Aether Core through OCCT."}</p>
        </div>
      </Dialog>
      <Dialog
        open={presentation.startDialog === "import"}
        title="Import STEP geometry"
        onClose={closeDialog}
        actions={<><Button onClick={closeDialog}>Cancel</Button><Button primary onClick={() => enterWorkspaceAndExecute("insert-step")}>Choose STEP files</Button></>}
      >
        <div className="cad-import-summary">
          <div><CadIcon name="step" /><div><strong>STEP / STP</strong><span>Exact B-Rep topology, analytic faces, edges, and assembly-ready connector candidates.</span></div></div>
          <dl><div><dt>Units</dt><dd>Detected from source</dd></div><div><dt>Policy</dt><dd>Copy into current local session</dd></div><div><dt>Hierarchy</dt><dd>Preserve imported document and Part rows</dd></div></dl>
          <p className="cad-form-note">Progress and failures remain visible. A failed file does not replace existing workspace geometry.</p>
        </div>
      </Dialog>
    </>
  );
}

function ExportCenter({ presentation }: { presentation: CADPresentationSnapshot }) {
  const close = () => cadPresentation.dispatch({ type: "show-start-dialog", dialog: null });
  return (
    <Dialog
      open={presentation.startDialog === "export"}
      title="Export Part"
      onClose={close}
      actions={<><Button onClick={close}>Cancel</Button><Button primary disabled={!presentation.partOpen} onClick={() => { close(); cadCommands.execute("save-part"); }}>Save native Part</Button></>}
    >
      <div className="cad-export-center">
        <div className="cad-export-target"><CadIcon name="model" /><div><strong>{presentation.documentName}</strong><span>Current editable Part document</span></div><em>Exact</em></div>
        <FieldRow label="Target" htmlFor="export-target"><SelectField id="export-target" value="active-part" options={[{ value: "active-part", label: presentation.documentName }]} disabled /></FieldRow>
        <FieldRow label="Format" htmlFor="export-format"><SelectField id="export-format" defaultValue="cadpart" options={[{ value: "cadpart", label: "Aether native Part (.acpart)" }, { value: "step", label: "STEP — exact writer unavailable", disabled: true }, { value: "stl", label: "STL — mesh export unavailable", disabled: true }, { value: "drawing", label: "Drawing PDF — projections unavailable", disabled: true }]} /></FieldRow>
        <Checkbox checked disabled label="Include editable feature history" description="Sketch constraints, dimensions, and Extrude parameters remain canonical." />
        <Checkbox checked disabled label="Validate dependency closure" description="The current native Part has no external runtime dependency; display meshes are regenerated." />
        <div className="cad-export-classification"><span>CLASSIFICATION</span><strong>Exact editable document</strong><small>Not a tessellated interchange mesh</small></div>
        <section className="cad-unavailable-outputs" aria-label="Unavailable export formats">
          <button type="button" disabled title="Requires an exact Core STEP writer"><b>STEP</b><span>Exact interchange</span><small>Core writer required</small></button>
          <button type="button" disabled title="Requires Core tessellation export policy"><b>Mesh</b><span>STL / 3MF</span><small>Export policy required</small></button>
          <button type="button" disabled title="Requires exact drawing projections"><b>Drawing</b><span>PDF / DXF / SVG</span><small>Projection engine required</small></button>
        </section>
      </div>
    </Dialog>
  );
}

function AssemblyComponentDialog({ presentation }: { presentation: CADPresentationSnapshot }) {
  const [draft, setDraft] = useState<AssemblyComponentDraft>(defaultAssemblyComponentDraft);
  const close = () => cadPresentation.dispatch({ type: "show-start-dialog", dialog: null });
  const issues = assemblyComponentDraftIssues(draft);
  const setPosition = (index: 0 | 1 | 2, value: number | null) => {
    if (value === null) return;
    setDraft((current) => {
      const position = [...current.positionM] as [number, number, number];
      position[index] = value;
      return { ...current, positionM: position };
    });
  };
  return (
    <Dialog
      open={presentation.startDialog === "insert-component"}
      title="Insert Assembly component"
      onClose={close}
      actions={(
        <>
          <Button onClick={close}>Cancel</Button>
          <Button
            primary
            disabled={issues.length > 0}
            onClick={() => cadPresentation.dispatch({ type: "insert-assembly-component", draft })}
          >Insert Component</Button>
        </>
      )}
    >
      <div className="cad-start-form">
        <FieldRow label="Part name" htmlFor="assembly-part-name">
          <TextField id="assembly-part-name" value={draft.partName} onChange={(event) => setDraft({ ...draft, partName: event.target.value })} />
        </FieldRow>
        <FieldRow label="Part number" htmlFor="assembly-part-number">
          <TextField id="assembly-part-number" value={draft.partNumber} placeholder="Optional" onChange={(event) => setDraft({ ...draft, partNumber: event.target.value })} />
        </FieldRow>
        <FieldRow label="Source label" htmlFor="assembly-source-label">
          <TextField id="assembly-source-label" value={draft.sourceLabel} onChange={(event) => setDraft({ ...draft, sourceLabel: event.target.value })} />
        </FieldRow>
        <FieldRow label="Instance name" htmlFor="assembly-instance-name">
          <TextField id="assembly-instance-name" value={draft.instanceName} onChange={(event) => setDraft({ ...draft, instanceName: event.target.value })} />
        </FieldRow>
        <FieldRow label="Mass" htmlFor="assembly-mass-kg">
          <CADQuantityField family="mass" id="assembly-mass-kg" value={draft.massKg} min={0} step={0.01}  scrubLabel="Mass" onValueChange={(massKg) => setDraft({ ...draft, massKg })} />
        </FieldRow>
        <FieldRow label="Position X" htmlFor="assembly-position-x">
          <CADQuantityField family="length" id="assembly-position-x" value={draft.positionM[0]} step={0.01}  scrubLabel="Position X" onValueChange={(value) => setPosition(0, value)} />
        </FieldRow>
        <FieldRow label="Position Y" htmlFor="assembly-position-y">
          <CADQuantityField family="length" id="assembly-position-y" value={draft.positionM[1]} step={0.01}  scrubLabel="Position Y" onValueChange={(value) => setPosition(1, value)} />
        </FieldRow>
        <FieldRow label="Position Z" htmlFor="assembly-position-z">
          <CADQuantityField family="length" id="assembly-position-z" value={draft.positionM[2]} step={0.01}  scrubLabel="Position Z" onValueChange={(value) => setPosition(2, value)} />
        </FieldRow>
        <Checkbox
          checked={draft.grounded}
          onChange={(event) => setDraft({ ...draft, grounded: event.target.checked })}
          label="Ground component"
          description="Fix this instance at its authored rest transform."
        />
        <p className="cad-form-note">The canonical Core creates the Part definition and stable Assembly instance. Viewport geometry remains dependent on a resolved source asset.</p>
        {issues.length > 0 ? <p className="cad-form-note" role="alert">{issues.join(" ")}</p> : null}
      </div>
    </Dialog>
  );
}

function AssemblyConnectorDialog({ presentation }: { presentation: CADPresentationSnapshot }) {
  const [draft, setDraft] = useState<AssemblyConnectorDraft>(defaultAssemblyConnectorDraft);
  const close = () => cadPresentation.dispatch({ type: "show-start-dialog", dialog: null });
  const issues = assemblyConnectorDraftIssues(draft);
  const setOrigin = (index: 0 | 1 | 2, value: number | null) => {
    if (value === null) return;
    setDraft((current) => {
      const origin = [...current.originM] as [number, number, number];
      origin[index] = value;
      return { ...current, originM: origin };
    });
  };
  return (
    <Dialog
      open={presentation.startDialog === "add-connector"}
      title="Add manual mate connector"
      onClose={close}
      actions={(
        <>
          <Button onClick={close}>Cancel</Button>
          <Button
            primary
            disabled={issues.length > 0}
            onClick={() => cadPresentation.dispatch({ type: "add-assembly-connector", draft })}
          >Add Connector</Button>
        </>
      )}
    >
      <div className="cad-start-form">
        <FieldRow label="Connector name" htmlFor="connector-name">
          <TextField id="connector-name" value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} />
        </FieldRow>
        <FieldRow label="Frame label" htmlFor="connector-frame-label">
          <TextField id="connector-frame-label" value={draft.provenanceLabel} placeholder="Optional manual datum label" onChange={(event) => setDraft({ ...draft, provenanceLabel: event.target.value })} />
        </FieldRow>
        <FieldRow label="Origin X" htmlFor="connector-origin-x">
          <CADQuantityField family="length" id="connector-origin-x" value={draft.originM[0]} step={0.001}  scrubLabel="Origin X" onValueChange={(value) => setOrigin(0, value)} />
        </FieldRow>
        <FieldRow label="Origin Y" htmlFor="connector-origin-y">
          <CADQuantityField family="length" id="connector-origin-y" value={draft.originM[1]} step={0.001}  scrubLabel="Origin Y" onValueChange={(value) => setOrigin(1, value)} />
        </FieldRow>
        <FieldRow label="Origin Z" htmlFor="connector-origin-z">
          <CADQuantityField family="length" id="connector-origin-z" value={draft.originM[2]} step={0.001}  scrubLabel="Origin Z" onValueChange={(value) => setOrigin(2, value)} />
        </FieldRow>
        <FieldRow label="Primary axis" htmlFor="connector-primary-axis">
          <SelectField id="connector-primary-axis" value={draft.primaryAxis} options={connectorAxisOptions} onChange={(event) => setDraft({ ...draft, primaryAxis: event.target.value as ConnectorAxisID })} />
        </FieldRow>
        <FieldRow label="Secondary axis" htmlFor="connector-secondary-axis">
          <SelectField id="connector-secondary-axis" value={draft.secondaryAxis} options={connectorAxisOptions} onChange={(event) => setDraft({ ...draft, secondaryAxis: event.target.value as ConnectorAxisID })} />
        </FieldRow>
        <p className="cad-form-note">The origin is Part-local in meters. Core normalizes the two nonparallel axes into the persistent right-handed connector frame.</p>
        {issues.length > 0 ? <p className="cad-form-note" role="alert">{issues.join(" ")}</p> : null}
      </div>
    </Dialog>
  );
}

function AssemblyMateDialog({ presentation }: { presentation: CADPresentationSnapshot }) {
  const assembly = useSyncExternalStore(
    cadAssemblyWorkspace.subscribe,
    cadAssemblyWorkspace.snapshot,
    cadAssemblyWorkspace.snapshot,
  );
  const endpoints = assembly.data?.mateEndpointOptions ?? [];
  const [draft, setDraft] = useState<AssemblyMateDraft>(defaultAssemblyMateDraft);
  const open = presentation.startDialog === "create-mate";
  const close = () => cadPresentation.dispatch({ type: "show-start-dialog", dialog: null });
  const endpointDraft = (id: string) => {
    const option = endpoints.find((candidate) => candidate.id === id);
    return option
      ? { instanceID: option.instanceID, connectorDefinitionID: option.connectorDefinitionID }
      : { instanceID: "", connectorDefinitionID: "" };
  };
  const updateDraft = (next: AssemblyMateDraft) => {
    setDraft(next);
    cadPresentation.dispatch({ type: "clear-assembly-mate-preview" });
  };

  useEffect(() => {
    if (!open) return;
    setDraft((current) => {
      const currentA = endpoints.find((option) => option.instanceID === current.endpointA.instanceID && option.connectorDefinitionID === current.endpointA.connectorDefinitionID);
      const endpointAOption = currentA ?? endpoints[0];
      const currentB = endpoints.find((option) => option.instanceID === current.endpointB.instanceID && option.connectorDefinitionID === current.endpointB.connectorDefinitionID && option.instanceID !== endpointAOption?.instanceID);
      const endpointBOption = currentB ?? endpoints.find((option) => option.instanceID !== endpointAOption?.instanceID);
      return {
        ...current,
        endpointA: endpointAOption
          ? { instanceID: endpointAOption.instanceID, connectorDefinitionID: endpointAOption.connectorDefinitionID }
          : { instanceID: "", connectorDefinitionID: "" },
        endpointB: endpointBOption
          ? { instanceID: endpointBOption.instanceID, connectorDefinitionID: endpointBOption.connectorDefinitionID }
          : { instanceID: "", connectorDefinitionID: "" },
      };
    });
  }, [open, assembly.data?.revision]);

  const issues = assemblyMateDraftIssues(draft);
  const endpointOptions = endpoints.map(({ id, label }) => ({ value: id, label }));
  const endpointAID = endpoints.find((option) => option.instanceID === draft.endpointA.instanceID && option.connectorDefinitionID === draft.endpointA.connectorDefinitionID)?.id ?? "";
  const endpointBID = endpoints.find((option) => option.instanceID === draft.endpointB.instanceID && option.connectorDefinitionID === draft.endpointB.connectorDefinitionID)?.id ?? "";
  const preview = presentation.matePreview;
  const canApply = canApplyAssemblyMate(draft, assembly.data?.revision, preview);

  return (
    <Dialog
      open={open}
      title="Create Assembly mate"
      onClose={close}
      actions={(
        <>
          <Button onClick={close}>Cancel</Button>
          <Button
            disabled={issues.length > 0 || preview?.state === "loading"}
            onClick={() => cadPresentation.dispatch({ type: "preview-assembly-mate", draft })}
          >Preview Solve</Button>
          <Button
            primary
            disabled={!canApply}
            onClick={() => cadPresentation.dispatch({ type: "commit-assembly-mate", draft })}
          >Apply Mate</Button>
        </>
      )}
    >
      <div className="cad-start-form">
        <FieldRow label="Mate name" htmlFor="assembly-mate-name">
          <TextField id="assembly-mate-name" value={draft.name} onChange={(event) => updateDraft({ ...draft, name: event.target.value })} />
        </FieldRow>
        <FieldRow label="Type" htmlFor="assembly-mate-type">
          <SelectField
            id="assembly-mate-type"
            value={draft.typeID}
            options={assemblyMateTypeOptions}
            onChange={(event) => {
              const typeID = event.target.value as AssemblyMateTypeID;
              const oldDefault = `${draft.typeID[0].toUpperCase()}${draft.typeID.slice(1)} 1`;
              const nextDefault = `${typeID[0].toUpperCase()}${typeID.slice(1)} 1`;
              updateDraft({ ...draft, typeID, name: draft.name === oldDefault ? nextDefault : draft.name });
            }}
          />
        </FieldRow>
        <FieldRow label="Moving endpoint" htmlFor="assembly-mate-endpoint-a">
          <SelectField
            id="assembly-mate-endpoint-a"
            value={endpointAID}
            options={endpointOptions}
            onChange={(event) => {
              const endpointA = endpointDraft(event.target.value);
              const endpointB = endpointA.instanceID === draft.endpointB.instanceID
                ? endpointDraft(endpoints.find((option) => option.instanceID !== endpointA.instanceID)?.id ?? "")
                : draft.endpointB;
              updateDraft({ ...draft, endpointA, endpointB });
            }}
          />
        </FieldRow>
        <FieldRow label="Target endpoint" htmlFor="assembly-mate-endpoint-b">
          <SelectField id="assembly-mate-endpoint-b" value={endpointBID} options={endpointOptions} onChange={(event) => updateDraft({ ...draft, endpointB: endpointDraft(event.target.value) })} />
        </FieldRow>
        <p className="cad-form-note">Preview is non-mutating. Apply remains disabled until Core solves the current endpoints and mate type.</p>
        {issues.length > 0 ? <p className="cad-form-note" role="alert">{issues.join(" ")}</p> : null}
        {preview?.state === "loading" ? <p className="cad-form-note" role="status">{preview.message}</p> : null}
        {preview?.state === "error" ? <p className="cad-form-note" role="alert">{preview.message}</p> : null}
        {preview?.state === "ready" ? (
          <div className="cad-form-note" role="status">
            <strong>Preview {preview.solveStatus}</strong>
            <span>{preview.remainingFreeDOFCount} free DOF{preview.residual !== null && preview.residual !== undefined ? ` · residual ${preview.residual}` : ""}</span>
            {preview.diagnosticMessages?.map((message) => <span key={message}>{message}</span>)}
          </div>
        ) : null}
      </div>
    </Dialog>
  );
}

function AssemblyMateDOFDialog({ presentation }: { presentation: CADPresentationSnapshot }) {
  const assembly = useSyncExternalStore(
    cadAssemblyWorkspace.subscribe,
    cadAssemblyWorkspace.snapshot,
    cadAssemblyWorkspace.snapshot,
  );
  const valueMode = presentation.startDialog === "set-mate-dof-value";
  const limitsMode = presentation.startDialog === "edit-mate-dof-limits";
  const open = valueMode || limitsMode;
  const [draft, setDraft] = useState<AssemblyMateDOFEditorDraft | null>(null);
  const dof = assembly.data?.selectedMateDOF ?? null;
  const close = () => cadPresentation.dispatch({ type: "show-start-dialog", dialog: null });

  useEffect(() => {
    if (open && dof) setDraft(assemblyMateDOFEditorDraft(dof));
  }, [open, dof?.id, assembly.data?.revision]);

  const mode = valueMode ? "value" : "limits";
  const issues = draft ? assemblyMateDOFEditorIssues(draft, mode) : ["Select one editable mate DOF."];
  const rotation = draft?.kind === "rotation";
  
  const step = rotation ? 1 : 0.001;
  const precision = rotation ? 3 : 6;
  const enableLimits = (enabled: boolean) => {
    if (!draft) return;
    setDraft({
      ...draft,
      limitsEnabled: enabled,
      minimum: enabled ? draft.minimum ?? (rotation ? -90 : -0.1) : null,
      maximum: enabled ? draft.maximum ?? (rotation ? 90 : 0.1) : null,
    });
  };

  return (
    <Dialog
      open={open}
      title={valueMode ? "Set mate DOF value" : "Edit mate DOF limits"}
      onClose={close}
      actions={(
        <>
          <Button onClick={close}>Cancel</Button>
          <Button
            primary
            disabled={!draft || issues.length > 0}
            onClick={() => {
              if (!draft) return;
              cadPresentation.dispatch(valueMode
                ? { type: "set-assembly-mate-dof-value", draft }
                : { type: "update-assembly-mate-dof-limits", draft });
            }}
          >{valueMode ? "Set Value" : "Apply Limits"}</Button>
        </>
      )}
    >
      <div className="cad-start-form">
        {draft ? (
          <>
            <FieldRow label="DOF"><output>{draft.name} · {rotation ? "Revolute" : "Prismatic"}</output></FieldRow>
            {valueMode ? (
              <FieldRow label={rotation ? "Angle" : "Distance"} htmlFor="assembly-mate-dof-value">
                <CADQuantityField family={rotation?"angle":"length"} canonicalFactor={rotation?Math.PI/180:1}
                  id="assembly-mate-dof-value"
                  value={draft.value}
                  step={step}
                  precision={precision}
                  scrubLabel={rotation ? "Angle" : "Distance"}
                  onValueChange={(value) => setDraft({ ...draft, value })}
                />
              </FieldRow>
            ) : (
              <>
                <Checkbox
                  checked={draft.limitsEnabled}
                  onChange={(event) => enableLimits(event.target.checked)}
                  label="Enable authored limits"
                  description="Core reports, rather than silently clamps, values outside this range."
                />
                <FieldRow label="Minimum" htmlFor="assembly-mate-dof-minimum">
                  <CADQuantityField family={rotation?"angle":"length"} canonicalFactor={rotation?Math.PI/180:1}
                    id="assembly-mate-dof-minimum"
                    value={draft.minimum}
                    step={step}
                    precision={precision}
                      disabled={!draft.limitsEnabled}
                    scrubLabel="Minimum"
                    onValueChange={(minimum) => setDraft({ ...draft, minimum })}
                  />
                </FieldRow>
                <FieldRow label="Maximum" htmlFor="assembly-mate-dof-maximum">
                  <CADQuantityField family={rotation?"angle":"length"} canonicalFactor={rotation?Math.PI/180:1}
                    id="assembly-mate-dof-maximum"
                    value={draft.maximum}
                    step={step}
                    precision={precision}
                      disabled={!draft.limitsEnabled}
                    scrubLabel="Maximum"
                    onValueChange={(maximum) => setDraft({ ...draft, maximum })}
                  />
                </FieldRow>
              </>
            )}
            <p className="cad-form-note">Uses workspace display units. Core retains angles in radians and distances in meters.</p>
          </>
        ) : <p className="cad-form-note" role="alert">The selected mate no longer exposes an editable free DOF.</p>}
        {issues.length > 0 && draft ? <p className="cad-form-note" role="alert">{issues.join(" ")}</p> : null}
      </div>
    </Dialog>
  );
}

function AssemblyRelationDialog({ presentation }: { presentation: CADPresentationSnapshot }) {
  const assembly = useSyncExternalStore(
    cadAssemblyWorkspace.subscribe,
    cadAssemblyWorkspace.snapshot,
    cadAssemblyWorkspace.snapshot,
  );
  const options = assembly.data?.relationDOFOptions ?? [];
  const [draft, setDraft] = useState<AssemblyRelationDraft>(defaultAssemblyRelationDraft);
  const open = presentation.startDialog === "create-relation";
  const close = () => cadPresentation.dispatch({ type: "show-start-dialog", dialog: null });

  const defaultsFor = (kind: AssemblyRelationKind, current: AssemblyRelationDraft): AssemblyRelationDraft => {
    const expected = relationKinds(kind);
    const drivers = options.filter((option) => option.kind === expected.driverKind);
    const driverDOFID = drivers.some(({ id }) => id === current.driverDOFID)
      ? current.driverDOFID : drivers[0]?.id ?? "";
    const driven = options.filter((option) => option.kind === expected.drivenKind && option.id !== driverDOFID);
    const drivenDOFID = driven.some(({ id }) => id === current.drivenDOFID)
      ? current.drivenDOFID : driven[0]?.id ?? "";
    return { ...current, kind, driverDOFID, drivenDOFID };
  };

  useEffect(() => {
    if (open) setDraft((current) => defaultsFor(current.kind, current));
  }, [open, assembly.data?.revision]);

  const expected = relationKinds(draft.kind);
  const driverOptions = options
    .filter(({ kind }) => kind === expected.driverKind)
    .map(({ id, label }) => ({ value: id, label }));
  const drivenOptions = options
    .filter(({ kind, id }) => kind === expected.drivenKind && id !== draft.driverDOFID)
    .map(({ id, label }) => ({ value: id, label }));
  const issues = assemblyRelationDraftIssues(draft, options);
  const mixedUnits = expected.driverKind !== expected.drivenKind;
  const offsetUnit = expected.drivenKind === "rotation" ? "°" : "m";

  return (
    <Dialog
      open={open}
      title="Create DOF relation"
      onClose={close}
      actions={(
        <>
          <Button onClick={close}>Cancel</Button>
          <Button
            primary
            disabled={issues.length > 0}
            onClick={() => cadPresentation.dispatch({ type: "create-assembly-relation", draft })}
          >Create Relation</Button>
        </>
      )}
    >
      <div className="cad-start-form">
        <FieldRow label="Type" htmlFor="assembly-relation-kind">
          <SelectField
            id="assembly-relation-kind"
            value={draft.kind}
            options={assemblyRelationKindOptions}
            onChange={(event) => setDraft(defaultsFor(event.target.value as AssemblyRelationKind, draft))}
          />
        </FieldRow>
        <FieldRow label="Driver DOF" htmlFor="assembly-relation-driver">
          <SelectField id="assembly-relation-driver" value={draft.driverDOFID} options={driverOptions} onChange={(event) => setDraft(defaultsFor(draft.kind, { ...draft, driverDOFID: event.target.value, drivenDOFID: "" }))} />
        </FieldRow>
        <FieldRow label="Driven DOF" htmlFor="assembly-relation-driven">
          <SelectField id="assembly-relation-driven" value={draft.drivenDOFID} options={drivenOptions} onChange={(event) => setDraft({ ...draft, drivenDOFID: event.target.value })} />
        </FieldRow>
        <FieldRow label={mixedUnits ? "Ratio (m/rad)" : "Ratio"} htmlFor="assembly-relation-ratio">
          <NumberField id="assembly-relation-ratio" value={draft.ratio} min={0.000001} step={0.1} precision={6} scrubLabel="Ratio" onValueChange={(ratio) => setDraft({ ...draft, ratio })} />
        </FieldRow>
        <FieldRow label="Driven offset" htmlFor="assembly-relation-offset">
          <NumberField id="assembly-relation-offset" value={draft.offset} step={expected.drivenKind === "rotation" ? 1 : 0.001} precision={6} unit={offsetUnit} scrubLabel="Driven offset" onValueChange={(offset) => setDraft({ ...draft, offset })} />
        </FieldRow>
        <Checkbox checked={draft.reversed} onChange={(event) => setDraft({ ...draft, reversed: event.target.checked })} label="Reverse direction" description="Core receives a negative ratio while preserving this presentation flag." />
        <p className="cad-form-note">Core validates unit pairing, dependency ownership, solve order, and the driven value. Mixed rotation-to-translation ratios are authored in meters per radian.</p>
        {issues.length > 0 ? <p className="cad-form-note" role="alert">{issues.join(" ")}</p> : null}
      </div>
    </Dialog>
  );
}

function UtilityDialogs({ presentation }: { presentation: CADPresentationSnapshot }) {
  const units=useSyncExternalStore(subscribeDocumentUnits,documentUnits,documentUnits);
  const close = () => cadPresentation.dispatch({ type: "show-start-dialog", dialog: null });
  return (
    <>
      <Dialog open={presentation.startDialog === "preferences"} title="Preferences" onClose={close} actions={<Button primary onClick={close}>Done</Button>}>
        <div className="cad-preferences">
          <section><header><strong>Appearance</strong><small>Current application presentation</small></header>
            <FieldRow label="Theme" htmlFor="preference-theme"><SelectField id="preference-theme" value="dark" options={[{ value: "dark", label: "Aether Dark" }, { value: "light", label: "Light — unavailable", disabled: true }]} disabled /></FieldRow>
            <FieldRow label="Tool presentation"><SegmentedControl ariaLabel="Tool presentation" value={presentation.toolbarMode} options={[{ id: "traditional", label: "Traditional" }, { id: "floating", label: "Floating" }]} onChange={(mode) => cadPresentation.dispatch({ type: "select-toolbar-mode", mode: mode as CADToolbarMode })} /></FieldRow>
            <Checkbox checked disabled label="Follow reduced-motion preference" description="Animations use the operating-system accessibility setting." />
            <Checkbox disabled label="High-contrast override" description="Dedicated override is not implemented; system contrast remains respected by shared controls." />
          </section>
          <section><header><strong>Navigation</strong><small>Viewport input</small></header>
            <FieldRow label="Preset" htmlFor="preference-navigation"><SelectField id="preference-navigation" value="cad" options={[{ value: "cad", label: "CAD: RMB orbit · MMB pan" }]} disabled /></FieldRow>
            <FieldRow label="Fit shortcut"><output>F</output></FieldRow>
            <FieldRow label="Sketch shortcut"><output>R</output></FieldRow>
          </section>
          <section><header><strong>Units and precision</strong><small>Current Part contract</small></header>
            <FieldRow label="Length units" htmlFor="preference-units"><SelectField id="preference-units" value={unitChoice(units,"length").unit} options={[{value:unitChoice(units,"length").unit,label:unitChoice(units,"length").unit+" — change in Document controls → Workspace units"}]} disabled /></FieldRow>
            <FieldRow label="Display precision"><output>0.01 mm</output></FieldRow>
            <p className="cad-form-note">Per-workspace preference persistence arrives with the canonical `.acad` workspace graph.</p>
          </section>
        </div>
      </Dialog>
      <Dialog open={presentation.startDialog === "help"} title="Aether CAD Help" onClose={close} actions={<Button primary onClick={close}>Close Help</Button>}>
        <div className="cad-help-center">
          <section><strong>Part workflow</strong><ol><li>Start New Part and choose a principal plane.</li><li>Rough in the center rectangle and apply dimensions/constraints.</li><li>Finish Sketch to rebuild the exact OCCT Body.</li></ol></section>
          <section><strong>Assembly workflow</strong><ol><li>Import STEP Parts or create a Part.</li><li>Place exact mate connectors on inferred topology.</li><li>Choose Fastened and pick moving then target connectors.</li></ol></section>
          <section className="cad-shortcut-list"><strong>Keyboard and viewport</strong><dl><div><dt>F</dt><dd>Zoom to fit</dd></div><div><dt>R</dt><dd>Open Sketch</dd></div><div><dt>Esc</dt><dd>Cancel the active tool or plane choice</dd></div><div><dt>RMB</dt><dd>Orbit</dd></div><div><dt>MMB</dt><dd>Pan</dd></div><div><dt>Wheel</dt><dd>Zoom</dd></div></dl></section>
          <p className="cad-form-note">Problems reports definition warnings. Properties shows canonical Part values and exact topology statistics.</p>
        </div>
      </Dialog>
    </>
  );
}

export function AetherCADShell() {
  const presentation = useSyncExternalStore(
    cadPresentation.subscribe,
    cadPresentation.snapshot,
    cadPresentation.snapshot,
  );
  const commands = useSyncExternalStore(
    cadCommands.subscribe,
    cadCommands.snapshot,
    cadCommands.snapshot,
  );
  const [chromeTheme, setChromeTheme] = useState<"suite" | "classic">(() => {
    try { return localStorage.getItem("aether-cad-chrome-theme") === "classic" ? "classic" : "suite"; } catch { return "suite"; }
  });
  const chooseChromeTheme = (theme: "suite" | "classic") => {
    setChromeTheme(theme);
    try { localStorage.setItem("aether-cad-chrome-theme", theme); } catch { /* Session-only preference. */ }
  };
  const suite = chromeTheme === "suite";
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false);
  const [ribbonWorkspace, setRibbonWorkspace] = useState<CADRibbonWorkspaceID>("solid");
  useEffect(() => {
    const onSketchMode=(event:Event)=>setRibbonWorkspace((event as CustomEvent).detail ? "sketch" : "solid");
    window.addEventListener("aether-sketch-mode",onSketchMode);
    return ()=>window.removeEventListener("aether-sketch-mode",onSketchMode);
  }, []);

  useEffect(() => {
    const onKeyDown = (event: globalThis.KeyboardEvent) => {
      if (!(event.metaKey || event.ctrlKey) || event.key.toLocaleLowerCase() !== "k") return;
      event.preventDefault();
      setCommandPaletteOpen(true);
    };
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, []);

  const runRibbonAction = (action: CADToolActionID) => {
    if (action in commands) {
      cadCommands.execute(action as CADCommandID);
      return;
    }
    switch (action) {
      case "new-assembly":
        cadPresentation.dispatch({ type: "create-assembly-workspace", name: "Assembly 1" });
        break;
      case "open-assembly":
        cadPresentation.dispatch({ type: "open-assembly-workspace" });
        break;
      case "save-assembly":
        cadPresentation.dispatch({ type: "save-assembly-workspace" });
        break;
      case "show-home":
        if (window.location.pathname.startsWith("/cad/")) window.location.assign("/cad/");
        else cadPresentation.dispatch({ type: "show-start-screen", screen: "home" });
        break;
      case "show-recovery":
        cadPresentation.dispatch({ type: "show-start-screen", screen: "recovery" });
        break;
      case "show-preferences":
        cadPresentation.dispatch({ type: "show-start-dialog", dialog: "preferences" });
        break;
      case "show-help":
        cadPresentation.dispatch({ type: "show-start-dialog", dialog: "help" });
        break;
      case "show-export":
        cadPresentation.dispatch({ type: "show-start-dialog", dialog: "export" });
        break;
      case "open-drawing":
        cadPresentation.dispatch({ type: "select-workspace-mode", mode: "drawing" });
        break;
      case "show-items":
        openLeftPanel("browser");
        break;
      case "show-parameters":
      case "show-mates":
      case "show-inspect":
      case "show-visualization":
        openRightPanel(action.slice("show-".length));
        cadPresentation.dispatch({
          type: "select-panel",
          panel: action.slice("show-".length) as CADBrowserPanel,
        });
        break;
      case "show-history":
        if (suite) openLeftPanel("history");
        else cadPresentation.dispatch({ type: "toggle-history" });
        break;
      case "reset-panels":
        setPanelPositions({});
        cadPresentation.dispatch({ type: "reset-panel-placements" });
        break;
    }
  };

  const selectRibbonWorkspace = (workspace: CADRibbonWorkspaceID) => {
    setRibbonWorkspace(workspace);

  };

  const [panelPositions, setPanelPositions] = useState<WorkspacePanelState>({});
  const previousHistoryCollapsed = useRef(presentation.bottomPanelCollapsed);
  useEffect(() => {
    if (suite && previousHistoryCollapsed.current !== presentation.bottomPanelCollapsed) {
      openLeftPanel("history");
    }
    previousHistoryCollapsed.current = presentation.bottomPanelCollapsed;
  }, [suite, presentation.bottomPanelCollapsed]);

  const studioPanelState: WorkspacePanelState = {
    ...panelPositions,
    browser: { ...panelPositions.browser, placement: presentation.panelPlacements.browser },
    inspector: { ...panelPositions.inspector, placement: presentation.panelPlacements.inspector },
  };
  const leftPanelIDs = ["browser", "versions", "history"];
  const rightPanelIDs = ["inspector", "parameters", "mates", "inspect", "visualization"];
  const openLeftPanel = (id: string) => {
    const next = { ...studioPanelState };
    for (const key of leftPanelIDs) next[key] = { ...next[key], placement: key === id ? "docked" : "hidden" };
    updateStudioPanels(next);
  };
  const openRightPanel = (id: string) => {
    const next = { ...studioPanelState };
    for (const key of rightPanelIDs) next[key] = { ...next[key], placement: key === id ? "docked" : "hidden" };
    updateStudioPanels(next);
  };
  const updateStudioPanels = (state: WorkspacePanelState) => {
    const next = { ...state };
    // Rails select a view within their side, rather than stacking competing views.
    for (const ids of [leftPanelIDs, rightPanelIDs]) {
      const opened = ids.find(id => state[id]?.placement && state[id].placement !== "hidden"
        && (!studioPanelState[id] || studioPanelState[id].placement === "hidden"));
      if (opened) for (const id of ids) if (id !== opened) next[id] = { ...next[id], placement: "hidden" };
    }
    setPanelPositions(next);
    for (const panel of ["browser", "inspector"] as const) {
      const placement = next[panel]?.placement ?? "hidden";
      if (placement !== presentation.panelPlacements[panel]) {
        cadPresentation.dispatch({ type: "set-panel-placement", panel, placement });
      }
    }
  };
  // Authoring commands may request a property view; this never changes the model tree.
  useEffect(() => {
    if (presentation.activePanel !== "items") openRightPanel(presentation.activePanel);
  }, [presentation.activePanel]);

  return (
    <main className={`shell shapr-shell studio-shell chrome-${chromeTheme} toolbar-${suite ? "traditional" : presentation.toolbarMode}`}>
      <DocumentBar
        className="cad-document-bar"
        leading={
          <>
            
            <a href="/cad/" title="Aether CAD Home" aria-label="Aether CAD Home" style={{display: "inline-flex", color: "inherit"}} onClick={event => {if (!window.location.pathname.startsWith("/cad/")) {event.preventDefault(); cadPresentation.dispatch({type: "show-start-screen", screen: "home"});}}}><AppIcon app="cad" size={30} /></a>
            <CADDocumentControls name={presentation.documentName} partOpen={presentation.partOpen} />
            <span className="cad-header-divider" aria-hidden="true" />
            <div className="document-toolbar">
              <CommandIconButton id="new-part" command="new-part" label="New Part"><AetherIcon name="new" /></CommandIconButton>
              <CommandIconButton command="open-part" label="Open Part"><AetherIcon name="open" /></CommandIconButton>
              <input id="part-picker" type="file" accept=".acpart,.cadpart,application/json" hidden />
              <input id="assembly-picker" type="file" accept=".acad,.acasm,.aether,application/vnd.acad.workspace+zip,application/zip" hidden />
              <CommandIconButton id="save-part" command="save-part" label="Save Part"><AetherIcon name="save" /></CommandIconButton>
              <CommandIconButton command="insert-step" label="Insert STEP"><AetherIcon name="import" /></CommandIconButton>
              <input id="step-picker" type="file" accept=".step,.stp" multiple hidden />
            </div>
          </>
        }
        center={!suite ?
          <Tabs
            tabs={[
              { id: "design", label: "Design", icon: <AetherIcon name="design" /> },
              { id: "animate", label: "Animate", icon: <AetherIcon name="animate" />, disabled: true, title: "Animation authoring opens in Aether Animation until suite routing is connected." },
              { id: "show", label: "Show", icon: <AetherIcon name="show" />, disabled: true, title: "Show sequencing opens in Aether Animation until suite routing is connected." },
              { id: "hardware", label: "Hardware", icon: <AetherIcon name="hardware" />, disabled: true, title: "Hardware mapping opens in Aether Animation until suite routing is connected." },
            ]}
            activeID="design"
            onSelect={() => {}}
          /> : null
        }
        trailing={
          <>
            <div className="backend" role="status" aria-live="polite" aria-atomic="true"><StatusDot kind={presentation.backendState === "ready" ? "ok" : presentation.backendState === "failed" ? "error" : "busy"} /><span id="backend-label">{presentation.backendLabel}</span></div>
            <LayoutPresetButton preset={presentation.workspaceLayout === "expanded" ? "floating" : presentation.workspaceLayout} onChange={(preset) => cadPresentation.dispatch({ type: "select-layout", layout: preset === "floating" ? "expanded" : preset })} />
            <WorkspaceLayoutMenu layout={presentation.workspaceLayout} toolbarMode={presentation.toolbarMode} />
            <MenuButton label="Interface theme" items={[
              {id: "suite", label: "Full suite — default", kind: "radio", checked: suite},
              {id: "classic", label: "Classic — centered workspaces", kind: "radio", checked: !suite},
            ]} onSelect={id => chooseChromeTheme(id as "suite" | "classic")}>Theme ▾</MenuButton>
            <Button disabled={!presentation.partOpen} title={presentation.partOpen ? "Export Part" : "Create or open a Part to export"} onClick={() => cadPresentation.dispatch({ type: "show-start-dialog", dialog: "export" })}>Export</Button>
            <IconButton label="Commands" title="Commands · ⌘K" onClick={() => setCommandPaletteOpen(true)}><AetherIcon name="commands" /></IconButton>
            <IconButton label="Settings" onClick={() => cadPresentation.dispatch({ type: "show-start-dialog", dialog: "preferences" })}><AetherIcon name="settings" /></IconButton>
            <div data-aether-account="" />
            <IconButton label="Help" onClick={() => cadPresentation.dispatch({ type: "show-start-dialog", dialog: "help" })}><AetherIcon name="help" /></IconButton>
          </>
        }
      />
      <section
        className={`cad-studio-workspace panel-bottom-${presentation.panelPlacements.bottom}`}
        data-layout={presentation.workspaceLayout}
        data-toolbar-mode={suite ? "traditional" : presentation.toolbarMode}
        data-workspace-mode={presentation.workspaceMode}
        aria-label="CAD workspace"
        aria-hidden={presentation.startScreen !== "workspace"}
        inert={presentation.startScreen !== "workspace"}
      >
        <WorkspaceShell
          preset={presentation.workspaceLayout === "expanded" ? "floating" : presentation.workspaceLayout}
          preservePanelContent
          style={{ height: "100%" }}
          panelState={studioPanelState}
          onPanelStateChange={updateStudioPanels}
          toolbar={<CADTraditionalRibbon
            suite={suite}
            activeWorkspace={ribbonWorkspace}
            documentName={presentation.documentName}
            partOpen={presentation.partOpen}
            onSelectWorkspace={selectRibbonWorkspace}
            onAction={runRibbonAction}
            onUseFloatingTools={() => {
              cadPresentation.dispatch({ type: "select-layout", layout: "expanded" });
              cadPresentation.dispatch({ type: "select-toolbar-mode", mode: "floating" });
            }}
          />}
          leftPanels={[{ id: "browser", title: "Model", icon: <AetherIcon name="design" />, content: <>
            <CADPanelPlacementMenu panel="browser" label="Model" placement={presentation.panelPlacements.browser} />
            <ItemsPanel active />
          </> }, ...(suite ? [
            {id: "versions", title: "Version control", icon: <AetherIcon name="document" />, content: <CADVersionsPanel documentName={presentation.documentName} />},
            {id: "history", title: "History", icon: <CadIcon name="history" />, content: <WorkbenchBottomPanel presentation={presentation} sidebar />},
          ] : [])]}
          rightPanels={[
            { id: "inspector", title: "Properties", icon: <AetherIcon name="settings" />, content: <InspectorPanel placement={presentation.panelPlacements.inspector} /> },
            { id: "parameters", title: "Parameters", icon: <AetherIcon name="settings" />, content: <ParametersPanel active /> },
            { id: "mates", title: "Assembly", icon: <AetherIcon name="design" />, content: <MatesPanel active /> },
            { id: "inspect", title: "Inspect", icon: <AetherIcon name="search" />, content: <InspectPanel active /> },
            { id: "visualization", title: "Appearance", icon: <AetherIcon name="settings" />, content: <VisualizationPanel active /> },
          ]}
          bottom={suite ? undefined : <WorkbenchBottomPanel presentation={presentation} />}
        >
          <div className="cad-studio-viewport" aria-hidden={presentation.workspaceMode !== "modeling"} inert={presentation.workspaceMode !== "modeling"}>
            <ViewportSurface presentation={presentation} />
          </div>
          <DrawingWorkspaceRoute active={presentation.workspaceMode === "drawing"} />
        </WorkspaceShell>
      </section>
      <StartCenter presentation={presentation} />
      <AssemblyComponentDialog presentation={presentation} />
      <AssemblyConnectorDialog presentation={presentation} />
      <AssemblyMateDialog presentation={presentation} />
      <AssemblyMateDOFDialog presentation={presentation} />
      <AssemblyRelationDialog presentation={presentation} />
      <ExportCenter presentation={presentation} />
      <UtilityDialogs presentation={presentation} />
      <CommandPalette
        open={commandPaletteOpen}
        commands={buildCADCommandPaletteCommands(commands)}
        title="CAD commands"
        placeholder="Search CAD commands"
        onClose={() => setCommandPaletteOpen(false)}
        onSelect={(id) => cadCommands.execute(id as CADCommandID)}
      />
      <StatusBar><span id="status-message" role="status" aria-live="polite" aria-atomic="true" data-tone={presentation.statusTone}>{presentation.statusMessage}</span>{presentation.loading?.backgrounded ? <button className="cad-background-task" type="button" onClick={() => cadPresentation.dispatch({ type: "show-loading" })}>Show import task</button> : null}<span id="metrics" aria-label="Workspace metrics" data-cylinder-axis-candidates={presentation.cylinderAxisCandidates} data-analytic-center-candidates={presentation.analyticCenterCandidates}>{presentation.metricsText}</span></StatusBar>
    </main>
  );
}
