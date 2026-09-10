import type { ListBoxItem, TreeNode } from "@aether/ui";

export interface CADInspectorProperty {
  id: string;
  label: string;
  value: string;
  help?: string;
}

export interface CADInspectorSection {
  id: string;
  label: string;
  badge?: string;
  properties: readonly CADInspectorProperty[];
}

export interface CADWorkspaceSnapshot {
  itemNodes: readonly TreeNode[];
  selectedItemIDs: ReadonlySet<string>;
  expandedItemIDs: ReadonlySet<string>;
  historyItems: readonly ListBoxItem[];
  connectorItems: readonly ListBoxItem[];
  mateItems: readonly ListBoxItem[];
  problemItems: readonly ListBoxItem[];
  inspectorSections: readonly CADInspectorSection[];
  selectedConnectorIDs: ReadonlySet<string>;
  partCount: number;
}

export type CADWorkspaceAction =
  | {type:"move-item";id:string;targetID:string;position:"before"|"inside"|"after"}
  | { type: "select-item"; id: string }
  | { type: "toggle-item"; id: string }
  | { type: "item-action"; id: string; actionID: string }
  | { type: "activate-history"; id: string }
  | { type: "select-connector"; id: string }
  | { type: "connector-action"; id: string; actionID: string };

type Listener = () => void;
type ActionHandler = (action: CADWorkspaceAction) => void;

const initialSnapshot: CADWorkspaceSnapshot = Object.freeze({
  itemNodes: [],
  selectedItemIDs: new Set<string>(),
  expandedItemIDs: new Set<string>(),
  historyItems: [],
  connectorItems: [],
  mateItems: [],
  problemItems: [],
  inspectorSections: [],
  selectedConnectorIDs: new Set<string>(),
  partCount: 0,
});

export class CADWorkspaceStore {
  private current: CADWorkspaceSnapshot = initialSnapshot;
  private listeners = new Set<Listener>();
  private actionHandler: ActionHandler | null = null;

  snapshot = (): CADWorkspaceSnapshot => this.current;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  publish(snapshot: CADWorkspaceSnapshot): void {
    this.current = Object.freeze(snapshot);
    this.listeners.forEach((listener) => listener());
  }

  registerActionHandler(handler: ActionHandler): () => void {
    this.actionHandler = handler;
    return () => {
      if (this.actionHandler === handler) this.actionHandler = null;
    };
  }

  dispatch(action: CADWorkspaceAction): boolean {
    if (!this.actionHandler) return false;
    this.actionHandler(action);
    return true;
  }
}

export const cadWorkspace = new CADWorkspaceStore();
