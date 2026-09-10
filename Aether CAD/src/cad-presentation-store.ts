import type { AssemblyComponentDraft } from "./cad-assembly-authoring";
import type { AssemblyConnectorDraft } from "./cad-connector-authoring";
import type { AssemblyMateDOFEditorDraft, AssemblyMateDraft } from "./cad-mate-authoring";
import type { AssemblyRelationDraft } from "./cad-relation-authoring";

export type CADBrowserPanel = "items" | "parameters" | "mates" | "inspect" | "visualization";
export type CADPresentationTool = "none" | "connector" | "fastened";
export type CADBackendState = "loading" | "ready" | "failed";
export type CADStatusTone = "normal" | "error" | "success";
export type CADStartScreen = "workspace" | "home" | "recovery";
export type CADWorkspaceLayout = "docked" | "expanded" | "canvas";
export type CADWorkspaceMode = "modeling" | "drawing";
export type CADToolbarMode = "traditional" | "floating";
export type CADPanelID = "browser" | "inspector" | "bottom";
export type CADPanelPlacement = "docked" | "floating" | "hidden";
export type CADPanelPlacements = Readonly<Record<CADPanelID, CADPanelPlacement>>;
export type CADStartDialog = "new-workspace" | "insert-component" | "add-connector" | "create-mate" | "set-mate-dof-value" | "edit-mate-dof-limits" | "create-relation" | "import" | "export" | "preferences" | "help" | null;

export type CADMatePreviewPresentation =
  | { readonly state: "loading"; readonly message: string }
  | {
      readonly state: "ready";
      readonly revision: string;
      readonly solveStatus: "solved" | "unconverged" | "invalid";
      readonly remainingFreeDOFCount: number;
      readonly residual: number | null;
      readonly diagnosticMessages: readonly string[];
    }
  | { readonly state: "error"; readonly message: string };

export interface CADHoverPresentation {
  partName: string;
  label: string;
  detail: string;
}

export interface CADLoadingPresentation {
  label: string;
  detail: string;
  canCancel?: boolean;
  canBackground?: boolean;
  backgrounded?: boolean;
  phase?: string;
  value?: number;
  max?: number;
}

export interface CADPresentationSnapshot {
  activePanel: CADBrowserPanel;
  workspaceMode: CADWorkspaceMode;
  workspaceLayout: CADWorkspaceLayout;
  toolbarMode: CADToolbarMode;
  panelPlacements: CADPanelPlacements;
  itemFilterFocusSerial: number;
  startScreen: CADStartScreen;
  startDialog: CADStartDialog;
  bottomPanelActiveID: "history" | "problems";
  bottomPanelCollapsed: boolean;
  documentName: string;
  partOpen: boolean;
  backendLabel: string;
  backendState: CADBackendState;
  statusMessage: string;
  statusTone: CADStatusTone;
  metricsText: string;
  cylinderAxisCandidates: number;
  analyticCenterCandidates: number;
  activeTool: CADPresentationTool;
  awaitingSketchPlane: boolean;
  movingPick: string;
  targetPick: string;
  hover: CADHoverPresentation | null;
  loading: CADLoadingPresentation | null;
  matePreview: CADMatePreviewPresentation | null;
}

export interface CADPresentationPreferences {
  toolbarMode: CADToolbarMode;
  workspaceLayout: CADWorkspaceLayout;
  panelPlacements: CADPanelPlacements;
}

export type CADPresentationAction =
  | { type: "select-panel"; panel: CADBrowserPanel }
  | { type: "select-workspace-mode"; mode: CADWorkspaceMode }
  | { type: "select-layout"; layout: CADWorkspaceLayout }
  | { type: "select-toolbar-mode"; mode: CADToolbarMode }
  | { type: "set-panel-placement"; panel: CADPanelID; placement: CADPanelPlacement }
  | { type: "reset-panel-placements" }
  | { type: "focus-items-filter" }
  | { type: "show-start-screen"; screen: CADStartScreen }
  | { type: "show-start-dialog"; dialog: CADStartDialog }
  | { type: "create-part-workspace"; name: string }
  | { type: "create-assembly-workspace"; name: string }
  | { type: "insert-assembly-component"; draft: AssemblyComponentDraft }
  | { type: "add-assembly-connector"; draft: AssemblyConnectorDraft }
  | { type: "preview-assembly-mate"; draft: AssemblyMateDraft }
  | { type: "commit-assembly-mate"; draft: AssemblyMateDraft }
  | { type: "set-assembly-mate-dof-value"; draft: AssemblyMateDOFEditorDraft }
  | { type: "update-assembly-mate-dof-limits"; draft: AssemblyMateDOFEditorDraft }
  | { type: "create-assembly-relation"; draft: AssemblyRelationDraft }
  | { type: "clear-assembly-mate-preview" }
  | { type: "open-assembly-workspace" }
  | { type: "save-assembly-workspace" }
  | { type: "toggle-history" }
  | { type: "select-bottom-panel"; id: "history" | "problems" }
  | { type: "set-bottom-panel-collapsed"; collapsed: boolean }
  | { type: "cancel-loading" }
  | { type: "background-loading" }
  | { type: "show-loading" }
  | { type: "cancel-tool" }
  | { type: "cancel-sketch-plane" };

type Listener = () => void;
type ActionHandler = (action: CADPresentationAction) => void;

const initialSnapshot: CADPresentationSnapshot = Object.freeze({
  activePanel: "items",
  workspaceMode: "modeling",
  workspaceLayout: "docked",
  toolbarMode: "traditional",
  panelPlacements: Object.freeze({
    browser: "docked",
    inspector: "docked",
    bottom: "docked",
  }),
  itemFilterFocusSerial: 0,
  startScreen: "workspace",
  startDialog: null,
  bottomPanelActiveID: "history",
  bottomPanelCollapsed: false,
  documentName: "Untitled Part",
  partOpen: false,
  backendLabel: "Loading OCCT…",
  backendState: "loading",
  statusMessage: "OCCT is initializing in a worker.",
  statusTone: "normal",
  metricsText: "No Part open",
  cylinderAxisCandidates: 0,
  analyticCenterCandidates: 0,
  activeTool: "none",
  awaitingSketchPlane: false,
  movingPick: "Select a saved connector",
  targetPick: "Waiting for first connector",
  hover: null,
  loading: null,
  matePreview: null,
});

const toolbarModes: readonly CADToolbarMode[] = ["traditional", "floating"];
const workspaceLayouts: readonly CADWorkspaceLayout[] = ["docked", "expanded", "canvas"];
const panelPlacements: readonly CADPanelPlacement[] = ["docked", "floating", "hidden"];

export function parseCADPresentationPreferences(value: string | null): CADPresentationPreferences | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as Partial<CADPresentationPreferences>;
    if (!toolbarModes.includes(parsed.toolbarMode as CADToolbarMode)) return null;
    if (!workspaceLayouts.includes(parsed.workspaceLayout as CADWorkspaceLayout)) return null;
    if (!parsed.panelPlacements || typeof parsed.panelPlacements !== "object") return null;
    const browser = parsed.panelPlacements.browser;
    const inspector = parsed.panelPlacements.inspector;
    const bottom = parsed.panelPlacements.bottom;
    if (![browser, inspector, bottom].every((placement) => panelPlacements.includes(placement as CADPanelPlacement))) return null;
    return Object.freeze({
      toolbarMode: parsed.toolbarMode,
      workspaceLayout: parsed.workspaceLayout,
      panelPlacements: Object.freeze({ browser, inspector, bottom }),
    }) as CADPresentationPreferences;
  } catch {
    return null;
  }
}

export function serializeCADPresentationPreferences(snapshot: CADPresentationSnapshot): string {
  return JSON.stringify({
    toolbarMode: snapshot.toolbarMode,
    workspaceLayout: snapshot.workspaceLayout,
    panelPlacements: snapshot.panelPlacements,
  } satisfies CADPresentationPreferences);
}

export class CADPresentationStore {
  private current: CADPresentationSnapshot = initialSnapshot;
  private listeners = new Set<Listener>();
  private actionHandler: ActionHandler | null = null;

  snapshot = (): CADPresentationSnapshot => this.current;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  patch(patch: Partial<CADPresentationSnapshot>): void {
    this.current = Object.freeze({ ...this.current, ...patch });
    this.listeners.forEach((listener) => listener());
  }

  registerActionHandler(handler: ActionHandler): () => void {
    this.actionHandler = handler;
    return () => {
      if (this.actionHandler === handler) this.actionHandler = null;
    };
  }

  dispatch(action: CADPresentationAction): boolean {
    if (!this.actionHandler) return false;
    this.actionHandler(action);
    return true;
  }
}

export const cadPresentation = new CADPresentationStore();
