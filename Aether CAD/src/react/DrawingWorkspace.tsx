import {
  Button,
  Checkbox,
  DataTable,
  EmptyState,
  ErrorState,
  ListBox,
  MenuButton,
  PropertyGrid,
  SearchField,
  Tabs,
  Tree,
  type DataTableColumn,
  type ListBoxItem,
  type MenuItem,
} from "@aether/ui";
import type { DrawingBOMRow, DrawingPresentationCommandID } from "../cad-drawing-presentation";
import type {
  CADDrawingWorkspaceAction,
  CADDrawingWorkspaceSnapshot,
} from "../cad-drawing-workspace-store";
import { DrawingSheetCanvas } from "./DrawingSheetCanvas";

export interface DrawingWorkspaceProps {
  readonly snapshot: CADDrawingWorkspaceSnapshot;
  readonly onAction: (action: CADDrawingWorkspaceAction) => void;
  readonly onCommand: (command: DrawingPresentationCommandID) => void;
  readonly commandsConnected?: boolean;
  readonly onExit?: () => void;
  readonly className?: string;
}

const drawingTabs = [
  { id: "sheets", label: "Sheets" },
  { id: "annotations", label: "Annotations" },
  { id: "bom", label: "BOM" },
  { id: "styles", label: "Styles" },
] as const;

const bomColumns: readonly DataTableColumn<DrawingBOMRow>[] = [
  { id: "item", header: "Item", cell: (row) => row.item_number, sortValue: (row) => row.item_number, sortable: true, pinned: true, width: 58 },
  { id: "part", header: "Part definition", cell: (row) => row.part_definition_id, sortValue: (row) => row.part_definition_id, sortable: true, width: 142 },
  { id: "quantity", header: "Qty", cell: (row) => String(row.quantity), sortValue: (row) => row.quantity, sortable: true, align: "end", width: 55 },
];

const commandLabels: Record<DrawingPresentationCommandID, string> = {
  "add-sheet": "Add sheet",
  "add-view": "Base view",
  "add-section": "Section view",
  "add-annotation": "Annotation",
  "add-bom": "BOM table",
  "rebuild-drawing": "Rebuild",
  "save-workspace": "Save",
  "export-pdf": "PDF",
  "export-dxf": "DXF",
  "export-svg": "SVG",
};

function filterItems(items: readonly ListBoxItem[], filter: string): readonly ListBoxItem[] {
  const query = filter.trim().toLocaleLowerCase();
  if (!query) return items;
  return items.filter((item) => `${item.label} ${item.description ?? ""} ${item.badge ?? ""}`.toLocaleLowerCase().includes(query));
}

function drawingResultCount(snapshot: CADDrawingWorkspaceSnapshot): number {
  const data = snapshot.data!;
  const query = snapshot.filter.trim().toLocaleLowerCase();
  if (snapshot.activeTab === "annotations") return filterItems(data.annotationItems, snapshot.filter).length;
  if (snapshot.activeTab === "styles") return filterItems(data.styleItems, snapshot.filter).length;
  if (snapshot.activeTab === "bom") return data.bomRows.filter((row) => !query || `${row.item_number} ${row.part_definition_id} ${row.quantity}`.toLocaleLowerCase().includes(query)).length;
  let count = 0;
  const visit = (nodes: typeof data.treeNodes) => nodes.forEach((node) => {
    if (!query || `${node.label} ${node.badge ?? ""}`.toLocaleLowerCase().includes(query)) count += 1;
    if (node.children) visit(node.children);
  });
  visit(data.treeNodes);
  return count;
}

function ReadOnlyDrawingProperties({ snapshot }: { snapshot: CADDrawingWorkspaceSnapshot }) {
  return <PropertyGrid
    ariaLabel="Drawing properties"
    sections={(snapshot.data?.inspectorSections ?? []).map((section) => ({
      ...section,
      properties: section.properties.map((property) => ({
        ...property,
        editor: <output>{property.value}</output>,
        readOnly: true,
      })),
    }))}
    emptyState="Select a sheet, view, annotation, BOM table, or exact primitive."
  />;
}

function DependencyState({ snapshot }: { snapshot: CADDrawingWorkspaceSnapshot }) {
  if (snapshot.loadState === "error") {
    return <ErrorState title="Drawing unavailable" description={snapshot.message} />;
  }
  if (snapshot.loadState === "loading") {
    return <EmptyState icon="…" title="Loading exact Drawing" description={snapshot.message} />;
  }
  return <EmptyState
    icon="▤"
    title="Exact Drawing engine unavailable"
    description={snapshot.message}
  />;
}

function CommandButton({
  id,
  snapshot,
  onCommand,
  commandsConnected,
}: {
  id: DrawingPresentationCommandID;
  snapshot: CADDrawingWorkspaceSnapshot;
  onCommand: (command: DrawingPresentationCommandID) => void;
  commandsConnected: boolean;
}) {
  const availability = snapshot.data?.commandAvailability.find((item) => item.id === id);
  const enabled = commandsConnected && availability?.enabled === true;
  const disabledReason = commandsConnected
    ? availability?.disabledReason ?? "Core capability unavailable."
    : "Drawing command transport is not connected.";
  return <Button
    data-drawing-command={id}
    disabled={!enabled}
    title={enabled ? undefined : disabledReason}
    onClick={() => onCommand(id)}
  >{commandLabels[id]}</Button>;
}

function DrawingCommandBar({ snapshot, onCommand, commandsConnected = true }: Pick<DrawingWorkspaceProps, "snapshot" | "onCommand" | "commandsConnected">) {
  const exportItems: MenuItem[] = (["export-pdf", "export-dxf", "export-svg"] as const).map((id) => {
    const availability = snapshot.data?.commandAvailability.find((item) => item.id === id);
    return {
      id,
      label: commandLabels[id],
      disabled: !commandsConnected || availability?.enabled !== true,
      disabledReason: commandsConnected ? availability?.disabledReason : "Drawing command transport is not connected.",
    };
  });
  return <header className="cad-drawing-commandbar" aria-label="Drawing commands">
    <div className="cad-drawing-command-group" aria-label="Sheet and view commands">
      <CommandButton id="add-sheet" snapshot={snapshot} onCommand={onCommand} commandsConnected={commandsConnected} />
      <CommandButton id="add-view" snapshot={snapshot} onCommand={onCommand} commandsConnected={commandsConnected} />
      <CommandButton id="add-section" snapshot={snapshot} onCommand={onCommand} commandsConnected={commandsConnected} />
    </div>
    <div className="cad-drawing-command-group" aria-label="Annotation commands">
      <CommandButton id="add-annotation" snapshot={snapshot} onCommand={onCommand} commandsConnected={commandsConnected} />
      <CommandButton id="add-bom" snapshot={snapshot} onCommand={onCommand} commandsConnected={commandsConnected} />
    </div>
    <div className="cad-drawing-command-group cad-drawing-command-group--end" aria-label="Document commands">
      <CommandButton id="rebuild-drawing" snapshot={snapshot} onCommand={onCommand} commandsConnected={commandsConnected} />
      <CommandButton id="save-workspace" snapshot={snapshot} onCommand={onCommand} commandsConnected={commandsConnected} />
      <MenuButton label="Export Drawing" items={exportItems} onSelect={(id) => onCommand(id as DrawingPresentationCommandID)}>Export</MenuButton>
    </div>
  </header>;
}

function DrawingBrowser({ snapshot, onAction }: Pick<DrawingWorkspaceProps, "snapshot" | "onAction">) {
  const data = snapshot.data!;
  const select = (ids: readonly string[], mode: "single" | "toggle" | "range") => onAction({ type: "select-entities", ids, mode });
  let content;
  switch (snapshot.activeTab) {
    case "sheets":
      content = <Tree
        ariaLabel="Drawing sheets and views"
        nodes={data.treeNodes}
        selectedIDs={snapshot.selectedEntityIDs}
        expandedIDs={snapshot.expandedEntityIDs}
        filter={snapshot.filter}
        onSelect={select}
        onToggle={(id, expanded) => onAction({ type: "toggle-entity", id, expanded })}
        emptyState="No matching Drawing entities."
        virtualizeThreshold={100}
        height={560}
      />;
      break;
    case "annotations":
      content = <ListBox
        ariaLabel="Drawing annotations"
        items={filterItems(data.annotationItems, snapshot.filter)}
        selectedIDs={snapshot.selectedEntityIDs}
        onSelect={select}
        emptyState="No matching annotations."
        virtualizeThreshold={100}
        height={560}
      />;
      break;
    case "bom":
      content = <DataTable
        ariaLabel="Drawing bill of materials"
        rows={data.bomRows}
        rowID={(row) => row.selection_id}
        columns={bomColumns}
        selectedIDs={snapshot.selectedEntityIDs}
        onSelect={select}
        filter={snapshot.filter}
        filterText={(row) => `${row.item_number} ${row.part_definition_id} ${row.quantity}`}
        emptyState="No matching Drawing BOM rows."
        virtualizeThreshold={100}
        height={560}
      />;
      break;
    case "styles":
      content = <ListBox
        ariaLabel="Drawing styles"
        items={filterItems(data.styleItems, snapshot.filter)}
        selectedIDs={snapshot.selectedEntityIDs}
        onSelect={select}
        emptyState="No matching Drawing styles."
        virtualizeThreshold={100}
        height={560}
      />;
      break;
  }
  return <aside className="cad-drawing-browser" aria-label="Drawing browser">
    <Tabs tabs={drawingTabs} activeID={snapshot.activeTab} onSelect={(id) => onAction({ type: "select-tab", tab: id as CADDrawingWorkspaceSnapshot["activeTab"] })} />
    <div className="cad-drawing-filter">
      <SearchField ariaLabel="Filter Drawing browser" placeholder={`Filter ${snapshot.activeTab}`} value={snapshot.filter} onQueryChange={(filter) => onAction({ type: "set-filter", filter })} resultCount={drawingResultCount(snapshot)} />
    </div>
    <div className="cad-drawing-browser-content">{content}</div>
  </aside>;
}

function DrawingInspector({ snapshot, onAction }: Pick<DrawingWorkspaceProps, "snapshot" | "onAction">) {
  const problems = snapshot.data?.problemItems ?? [];
  return <aside className="cad-drawing-inspector" aria-label="Drawing inspector">
    <header><strong>Properties</strong><small>Core projection</small></header>
    <ReadOnlyDrawingProperties snapshot={snapshot} />
    <section className="cad-drawing-problems" aria-label="Drawing diagnostics">
      <div className="cad-drawing-section-heading"><span>Problems</span><span>{problems.length}</span></div>
      <ListBox
        ariaLabel="Drawing diagnostics"
        items={problems}
        selectedIDs={snapshot.selectedEntityIDs}
        onSelect={(ids, mode) => onAction({ type: "select-entities", ids, mode })}
        emptyState="No Drawing problems."
        virtualizeThreshold={100}
        height={180}
      />
    </section>
  </aside>;
}

function DrawingCanvas({ snapshot, onAction }: Pick<DrawingWorkspaceProps, "snapshot" | "onAction">) {
  const projection = snapshot.projection!;
  const data = snapshot.data!;
  if (projection.revision !== data.revision) {
    return <ErrorState title="Drawing revision mismatch" description="The visible projection and presentation snapshot do not share one Core revision." />;
  }
  const sheet = projection.sheets.find((item) => item.id === data.activeSheetID);
  if (!sheet) {
    return <EmptyState icon="▤" title="No active sheet" description="Create or activate a sheet through the canonical Drawing engine." />;
  }
  if (sheet.revision !== projection.revision) {
    return <ErrorState title="Sheet revision mismatch" description="The active sheet is stale relative to the Drawing projection." />;
  }
  return <section className="cad-drawing-canvas" aria-label="Drawing sheet canvas">
    <header>
      <div><strong>{sheet.name}</strong><small>{sheet.width_mm} × {sheet.height_mm} mm · {sheet.projection_standard.replace("_", " ")}</small></div>
      <Checkbox
        checked={snapshot.showSnapPoints}
        label="Snap points"
        onChange={(event) => onAction({ type: "set-show-snap-points", visible: event.target.checked })}
      />
    </header>
    <div className="cad-drawing-paper-stage">
      <DrawingSheetCanvas
        sheet={sheet}
        styles={projection.styles}
        selectedIDs={snapshot.selectedEntityIDs}
        showSnapPoints={snapshot.showSnapPoints}
        onSelect={(id) => onAction({ type: "select-entities", ids: [id], mode: "single" })}
      />
    </div>
  </section>;
}

export function DrawingWorkspace({ snapshot, onAction, onCommand, commandsConnected = true, onExit, className }: DrawingWorkspaceProps) {
  const ready = snapshot.loadState === "ready" && snapshot.data !== null && snapshot.projection !== null;
  return <section className={["cad-drawing-workspace", onExit ? "cad-drawing-workspace--routed" : "", className].filter(Boolean).join(" ")} aria-label="Drawing workspace">
    {onExit ? <nav className="cad-drawing-routebar" aria-label="Drawing workspace navigation">
      <Button
        onClick={onExit}
        onKeyDown={(event) => {
          if (event.key !== "Enter" && event.key !== " ") return;
          event.preventDefault();
          onExit();
        }}
      >← 3D model</Button>
      <div><strong>Drawing</strong><small>Exact Core projection workspace</small></div>
    </nav> : null}
    {!ready ? <div className="cad-drawing-dependency-state"><DependencyState snapshot={snapshot} /></div> : <>
      <DrawingCommandBar snapshot={snapshot} onCommand={onCommand} commandsConnected={commandsConnected} />
      <div className="cad-drawing-workbench">
        <DrawingBrowser snapshot={snapshot} onAction={onAction} />
        <DrawingCanvas snapshot={snapshot} onAction={onAction} />
        <DrawingInspector snapshot={snapshot} onAction={onAction} />
      </div>
      <footer className="cad-drawing-status" role="status" aria-live="polite">
        <span>{snapshot.message}</span>
        <span>{snapshot.data!.summary.sheetCount} sheets · {snapshot.data!.summary.viewCount} views · {snapshot.data!.summary.primitiveCount} exact primitives</span>
        <span>{snapshot.data!.summary.rebuildStatus.replace("_", " ")}</span>
      </footer>
    </>}
  </section>;
}
