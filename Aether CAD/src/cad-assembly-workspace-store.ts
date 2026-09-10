import type { CADAssemblyPresentationProjection } from "./cad-assembly-presentation";

export type CADAssemblyTab = "structure" | "constraints" | "bom";
export type CADAssemblyLoadState = "unavailable" | "loading" | "ready" | "error";

export interface CADAssemblyWorkspaceSnapshot {
  readonly loadState: CADAssemblyLoadState;
  readonly message: string;
  readonly activeTab: CADAssemblyTab;
  readonly filter: string;
  readonly selectedEntityIDs: ReadonlySet<string>;
  readonly expandedEntityIDs: ReadonlySet<string>;
  readonly selectedBOMRowIDs: ReadonlySet<string>;
  readonly data: CADAssemblyPresentationProjection | null;
}

export type CADAssemblyWorkspaceAction =
  | { readonly type: "select-tab"; readonly tab: CADAssemblyTab }
  | { readonly type: "select-bom-mode"; readonly mode: "hierarchical" | "flattened" }
  | { readonly type: "set-filter"; readonly filter: string }
  | {
      readonly type: "select-entities";
      readonly ids: readonly string[];
      readonly mode: "single" | "toggle" | "range";
    }
  | { readonly type: "toggle-entity"; readonly id: string; readonly expanded: boolean }
  | {
      readonly type: "select-bom-rows";
      readonly ids: readonly string[];
      readonly mode: "single" | "toggle" | "range";
    };

type Listener = () => void;
type ActionListener = (action: CADAssemblyWorkspaceAction) => void;

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

const defaultMessage =
  "Persistent Assembly state is waiting for the canonical Core workspace graph.";

const initialSnapshot: CADAssemblyWorkspaceSnapshot = Object.freeze({
  loadState: "unavailable",
  message: defaultMessage,
  activeTab: "constraints",
  filter: "",
  selectedEntityIDs: new Set<string>(),
  expandedEntityIDs: new Set<string>(),
  selectedBOMRowIDs: new Set<string>(),
  data: null,
});

export class CADAssemblyWorkspaceStore {
  private current: CADAssemblyWorkspaceSnapshot = initialSnapshot;
  private readonly listeners = new Set<Listener>();
  private readonly actionListeners = new Set<ActionListener>();

  snapshot = (): CADAssemblyWorkspaceSnapshot => this.current;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  subscribeActions = (listener: ActionListener): (() => void) => {
    this.actionListeners.add(listener);
    return () => this.actionListeners.delete(listener);
  };

  setUnavailable(message = defaultMessage): void {
    this.publish({
      ...this.current,
      loadState: "unavailable",
      message,
      data: null,
      selectedEntityIDs: new Set(),
      selectedBOMRowIDs: new Set(),
    });
  }

  setLoading(message = "Loading the canonical Assembly projection…"): void {
    this.publish({ ...this.current, loadState: "loading", message });
  }

  setError(message: string): void {
    this.publish({ ...this.current, loadState: "error", message, data: null });
  }

  setReady(data: CADAssemblyPresentationProjection): void {
    const entityIDs = new Set<string>();
    const walk = (nodes: CADAssemblyPresentationProjection["treeNodes"]): void => {
      nodes.forEach((node) => {
        entityIDs.add(node.id);
        if (node.children) walk(node.children);
      });
    };
    walk(data.treeNodes);
    const bomIDs = new Set(data.bomRows.map((row) => row.row_id));
    const expandedEntityIDs = new Set(
      [...this.current.expandedEntityIDs].filter((id) => entityIDs.has(id)),
    );
    if (expandedEntityIDs.size === 0) {
      data.treeNodes.forEach((root) => {
        expandedEntityIDs.add(root.id);
        root.children
          ?.filter((node) => node.id === "presentation/components")
          .forEach((node) => expandedEntityIDs.add(node.id));
      });
    }
    this.publish({
      ...this.current,
      loadState: "ready",
      message: `Assembly revision ${data.revision}`,
      data,
      selectedEntityIDs: new Set(
        [...this.current.selectedEntityIDs].filter((id) => entityIDs.has(id)),
      ),
      selectedBOMRowIDs: new Set(
        [...this.current.selectedBOMRowIDs].filter((id) => bomIDs.has(id)),
      ),
      expandedEntityIDs,
    });
  }

  dispatch(action: CADAssemblyWorkspaceAction): void {
    switch (action.type) {
      case "select-tab":
        this.publish({ ...this.current, activeTab: action.tab });
        break;
      case "select-bom-mode":
        break;
      case "set-filter":
        this.publish({ ...this.current, filter: action.filter });
        break;
      case "select-entities":
        this.publish({
          ...this.current,
          selectedEntityIDs: selected(this.current.selectedEntityIDs, action.ids, action.mode),
        });
        break;
      case "toggle-entity": {
        const expandedEntityIDs = new Set(this.current.expandedEntityIDs);
        if (action.expanded) expandedEntityIDs.add(action.id);
        else expandedEntityIDs.delete(action.id);
        this.publish({ ...this.current, expandedEntityIDs });
        break;
      }
      case "select-bom-rows":
        this.publish({
          ...this.current,
          selectedBOMRowIDs: selected(this.current.selectedBOMRowIDs, action.ids, action.mode),
        });
        break;
    }
    this.actionListeners.forEach((listener) => listener(action));
  }

  private publish(snapshot: CADAssemblyWorkspaceSnapshot): void {
    this.current = Object.freeze(snapshot);
    this.listeners.forEach((listener) => listener());
  }
}

export const cadAssemblyWorkspace = new CADAssemblyWorkspaceStore();
