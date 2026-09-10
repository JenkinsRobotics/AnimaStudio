import { contextualDrawingTools, type ContextualDrawingTool } from "./sketch/tangent-arc-tool";
import { directModificationTools,type DirectModificationTool,modificationTools, type ModificationTool } from "./sketch/tool-instructions";
import type { SketchVariantTool } from "@aether/core/sketch";
import { sketchVariantTools } from "@aether/core/sketch";
import { drawingConstraintKinds, type DrawingConstraintKind } from "@aether/core/sketch";
export type CADCommandID =
  | `sketch-${ContextualDrawingTool}`
  | `sketch-constraint-${DrawingConstraintKind}`
  | `sketch-${DirectModificationTool}`
  | `sketch-${ModificationTool}`
  | `sketch-${SketchVariantTool}`
  | "sketch-project"
  | "sketch-text"
  | "sketch-import-dxf"
  | "sketch-select" | "sketch-line" | "sketch-arc" | "sketch-circle" | "sketch-rectangle"
  | "feature-plane"
  | "feature-profile"
  | "feature-extrude"
  | "feature-revolve"
  | "feature-mirror"
  | "feature-fillet"
  | "feature-chamfer"

  | "new-part"
  | "open-part"
  | "save-part"
  | "insert-step"
  | "sketch"
  | "rebuild-part"
  | "connector"
  | "fastened"
  | "assembly-insert-component"
  | "assembly-add-connector"
  | "assembly-create-mate"
  | "assembly-set-mate-dof-value"
  | "assembly-edit-mate-dof-limits"
  | "assembly-create-relation"
  | "assembly-toggle-mate-suppressed"
  | "assembly-remove-mate"
  | "assembly-toggle-grounded"
  | "assembly-toggle-suppressed"
  | "assembly-remove-instance"
  | "fit-view"
  | "clear-mates"
  | "view-top"
  | "view-bottom"
  | "view-front"
  | "view-back"
  | "view-right"
  | "view-left"
  | "view-isometric"
  | "display-shaded"
  | "display-shaded-edges"
  | "display-wireframe"
  | "display-hidden-line"
  | "display-ghost"
  | "lighting-studio"
  | "lighting-softbox"
  | "lighting-daylight"
  | "lighting-dark-room"
  | "toggle-contact-shadows"
  | "background-graphite"
  | "background-midnight"
  | "background-slate"
  | "finish-matte"
  | "finish-satin"
  | "finish-gloss"
  | "ground-none"
  | "ground-grid"
  | "ground-floor"
  | "ground-both"
  | "toggle-feature-edges"
  | "reset-appearance"
  | "selection-auto"
  | "selection-component"
  | "selection-body"
  | "selection-face"
  | "selection-edge"
  | "selection-vertex"
  | "selection-next-filter";

export interface CADCommandState {
  enabled: boolean;
  active: boolean;
  registered: boolean;
}

type Handler = () => void | Promise<void>;
type Listener = () => void;

export const cadCommandIDs: readonly CADCommandID[] = [
  ...contextualDrawingTools.map(tool=>`sketch-${tool}` as const),
  ...drawingConstraintKinds.filter(kind => kind !== "pattern").map(kind => `sketch-constraint-${kind}` as const),
  ...directModificationTools.map(tool=>`sketch-${tool}` as const),
  ...modificationTools.map(tool=>`sketch-${tool}` as const),
  ...sketchVariantTools.map(tool => `sketch-${tool}` as const),
  "sketch-project",
  "sketch-text",
  "sketch-import-dxf",
  "sketch-select", "sketch-line", "sketch-arc", "sketch-circle", "sketch-rectangle",
  "feature-plane", "feature-profile",
  "feature-extrude",
  "feature-revolve",
  "feature-mirror",
  "feature-fillet",
  "feature-chamfer",
  "new-part",
  "open-part",
  "save-part",
  "insert-step",
  "sketch",
  "rebuild-part",
  "connector",
  "fastened",
  "assembly-insert-component",
  "assembly-add-connector",
  "assembly-create-mate",
  "assembly-set-mate-dof-value",
  "assembly-edit-mate-dof-limits",
  "assembly-create-relation",
  "assembly-toggle-mate-suppressed",
  "assembly-remove-mate",
  "assembly-toggle-grounded",
  "assembly-toggle-suppressed",
  "assembly-remove-instance",
  "fit-view",
  "clear-mates",
  "view-top",
  "view-bottom",
  "view-front",
  "view-back",
  "view-right",
  "view-left",
  "view-isometric",
  "display-shaded",
  "display-shaded-edges",
  "display-wireframe",
  "display-hidden-line",
  "display-ghost",
  "lighting-studio",
  "lighting-softbox",
  "lighting-daylight",
  "lighting-dark-room",
  "toggle-contact-shadows",
  "background-graphite",
  "background-midnight",
  "background-slate",
  "finish-matte",
  "finish-satin",
  "finish-gloss",
  "ground-none",
  "ground-grid",
  "ground-floor",
  "ground-both",
  "toggle-feature-edges",
  "reset-appearance",
  "selection-auto",
  "selection-component",
  "selection-body",
  "selection-face",
  "selection-edge",
  "selection-vertex",
  "selection-next-filter",
];

const cadCommandIDSet: ReadonlySet<string> = new Set(cadCommandIDs);

export function isCADCommandID(value: string): value is CADCommandID {
  return cadCommandIDSet.has(value);
}

export class CADCommandRegistry {
  private handlers = new Map<CADCommandID, Handler>();
  private listeners = new Set<Listener>();
  private state: Readonly<Record<CADCommandID, CADCommandState>> =
    Object.freeze(
      Object.fromEntries(
        cadCommandIDs.map((id) => [
          id,
          Object.freeze({ enabled: true, active: false, registered: false }),
        ]),
      ) as Record<CADCommandID, CADCommandState>,
    );

  snapshot = (): Readonly<Record<CADCommandID, CADCommandState>> => this.state;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  register(id: CADCommandID, handler: Handler): () => void {
    this.handlers.set(id, handler);
    this.update(id, { registered: true });
    return () => {
      if (this.handlers.get(id) !== handler) return;
      this.handlers.delete(id);
      this.update(id, { registered: false, active: false });
    };
  }

  setEnabled(id: CADCommandID, enabled: boolean): void {
    this.update(id, { enabled });
  }

  setActive(id: CADCommandID, active: boolean): void {
    this.update(id, { active });
  }

  execute(id: CADCommandID): boolean {
    const command = this.state[id];
    const handler = this.handlers.get(id);
    if (!command.enabled || !handler) return false;
    void handler();
    return true;
  }

  private update(id: CADCommandID, patch: Partial<CADCommandState>): void {
    const current = this.state[id];
    const next = { ...current, ...patch };
    if (
      next.enabled === current.enabled &&
      next.active === current.active &&
      next.registered === current.registered
    ) return;
    this.state = Object.freeze({ ...this.state, [id]: Object.freeze(next) });
    this.listeners.forEach((listener) => listener());
  }
}

export const cadCommands = new CADCommandRegistry();
