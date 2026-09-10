import type { DrawingProjectionV1, DrawingRebuildProjection } from "./cad-drawing-bridge";
import {
  buildCADDrawingPresentation,
  type CADDrawingPresentationProjection,
  type DrawingPresentationTab,
} from "./cad-drawing-presentation";

export type CADDrawingLoadState = "unavailable" | "loading" | "ready" | "error";

export interface CADDrawingWorkspaceSnapshot {
  readonly loadState: CADDrawingLoadState;
  readonly message: string;
  readonly activeTab: DrawingPresentationTab;
  readonly filter: string;
  readonly showSnapPoints: boolean;
  readonly selectedEntityIDs: ReadonlySet<string>;
  readonly expandedEntityIDs: ReadonlySet<string>;
  readonly projection: DrawingProjectionV1 | null;
  readonly rebuild: DrawingRebuildProjection | null;
  readonly data: CADDrawingPresentationProjection | null;
}

export type CADDrawingWorkspaceAction =
  | { readonly type: "select-tab"; readonly tab: DrawingPresentationTab }
  | { readonly type: "set-filter"; readonly filter: string }
  | { readonly type: "set-show-snap-points"; readonly visible: boolean }
  | { readonly type: "select-entities"; readonly ids: readonly string[]; readonly mode: "single" | "toggle" | "range" }
  | { readonly type: "toggle-entity"; readonly id: string; readonly expanded: boolean };

type Listener = () => void;

function selected(
  current: ReadonlySet<string>,
  ids: readonly string[],
  mode: "single" | "toggle" | "range",
): ReadonlySet<string> {
  if (mode === "single") return new Set(ids.slice(0, 1));
  if (mode === "range") return new Set(ids);
  const next = new Set(current);
  ids.forEach((id) => {
    if (next.has(id)) next.delete(id);
    else next.add(id);
  });
  return next;
}

const defaultMessage = "Exact Drawing sheets are waiting for the canonical Core projection engine.";

const initialSnapshot: CADDrawingWorkspaceSnapshot = Object.freeze({
  loadState: "unavailable",
  message: defaultMessage,
  activeTab: "sheets",
  filter: "",
  showSnapPoints: false,
  selectedEntityIDs: new Set<string>(),
  expandedEntityIDs: new Set<string>(),
  projection: null,
  rebuild: null,
  data: null,
});

function selectableIDs(data: CADDrawingPresentationProjection): Set<string> {
  const ids = new Set<string>();
  const walk = (nodes: CADDrawingPresentationProjection["treeNodes"]): void => {
    nodes.forEach((node) => {
      ids.add(node.id);
      if (node.children) walk(node.children);
    });
  };
  walk(data.treeNodes);
  [data.sheetItems, data.viewItems, data.annotationItems, data.styleItems, data.problemItems]
    .forEach((items) => items.forEach((item) => ids.add(item.id)));
  data.primitiveRows.forEach((row) => ids.add(row.primitive_id));
  data.bomRows.forEach((row) => {
    ids.add(row.table_id);
    ids.add(row.selection_id);
  });
  return ids;
}

export class CADDrawingWorkspaceStore {
  private current: CADDrawingWorkspaceSnapshot = initialSnapshot;
  private readonly listeners = new Set<Listener>();

  snapshot = (): CADDrawingWorkspaceSnapshot => this.current;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  setUnavailable(message = defaultMessage): void {
    this.publish({ ...this.current, loadState: "unavailable", message, projection: null, rebuild: null, data: null, selectedEntityIDs: new Set() });
  }

  setLoading(message = "Loading exact Drawing sheets…"): void {
    this.publish({ ...this.current, loadState: "loading", message });
  }

  setError(message: string): void {
    this.publish({ ...this.current, loadState: "error", message, projection: null, rebuild: null, data: null });
  }

  setReady(projection: DrawingProjectionV1, rebuild: DrawingRebuildProjection | null): void {
    const firstPresentation = buildCADDrawingPresentation(projection, rebuild);
    const entityIDs = selectableIDs(firstPresentation);
    const selectedEntityIDs = new Set([...this.current.selectedEntityIDs].filter((id) => entityIDs.has(id)));
    const selectedID = selectedEntityIDs.values().next().value ?? null;
    const data = selectedID
      ? buildCADDrawingPresentation(projection, rebuild, selectedID)
      : firstPresentation;
    const expandedEntityIDs = new Set(
      [...this.current.expandedEntityIDs].filter((id) => entityIDs.has(id)),
    );
    if (expandedEntityIDs.size === 0) {
      data.treeNodes.forEach((sheet) => {
        expandedEntityIDs.add(sheet.id);
        sheet.children?.filter((node) => node.id.endsWith("/views")).forEach((node) => expandedEntityIDs.add(node.id));
      });
    }
    this.publish({
      ...this.current,
      loadState: "ready",
      message: `Drawing revision ${data.revision}`,
      projection,
      rebuild,
      data,
      selectedEntityIDs,
      expandedEntityIDs,
    });
  }

  dispatch(action: CADDrawingWorkspaceAction): void {
    switch (action.type) {
      case "select-tab":
        this.publish({ ...this.current, activeTab: action.tab });
        break;
      case "set-filter":
        this.publish({ ...this.current, filter: action.filter });
        break;
      case "set-show-snap-points":
        this.publish({ ...this.current, showSnapPoints: action.visible });
        break;
      case "select-entities":
        {
          const selectedEntityIDs = selected(this.current.selectedEntityIDs, action.ids, action.mode);
          const selectedID = selectedEntityIDs.values().next().value ?? null;
          const data = this.current.projection
            ? buildCADDrawingPresentation(this.current.projection, this.current.rebuild, selectedID)
            : this.current.data;
          this.publish({ ...this.current, selectedEntityIDs, data });
        }
        break;
      case "toggle-entity": {
        const expandedEntityIDs = new Set(this.current.expandedEntityIDs);
        if (action.expanded) expandedEntityIDs.add(action.id);
        else expandedEntityIDs.delete(action.id);
        this.publish({ ...this.current, expandedEntityIDs });
        break;
      }
    }
  }

  private publish(snapshot: CADDrawingWorkspaceSnapshot): void {
    this.current = Object.freeze(snapshot);
    this.listeners.forEach((listener) => listener());
  }
}

export const cadDrawingWorkspace = new CADDrawingWorkspaceStore();
