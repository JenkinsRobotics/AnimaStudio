export type CADBackgroundPreset = "graphite" | "midnight" | "slate";
export type CADMaterialFinish = "matte" | "satin" | "gloss";
export type CADDisplayStyle = "shaded" | "shaded-edges" | "wireframe" | "hidden-line" | "ghost";
export type CADLightingPreset = "studio" | "softbox" | "daylight" | "dark-room";
export type CADFloorMode = "none" | "grid" | "floor" | "both";

export interface CADAppearanceSnapshot {
  background: CADBackgroundPreset;
  displayStyle: CADDisplayStyle;
  lightingPreset: CADLightingPreset;
  floorMode: CADFloorMode;
  contactShadowsVisible: boolean;
  edgesVisible: boolean;
  materialFinish: CADMaterialFinish;
  environmentPercent: number;
}

export type CADAppearanceAction =
  | { type: "set-background"; background: CADBackgroundPreset }
  | { type: "set-display-style"; style: CADDisplayStyle }
  | { type: "set-lighting-preset"; preset: CADLightingPreset }
  | { type: "set-floor-mode"; mode: CADFloorMode }
  | { type: "set-contact-shadows-visible"; visible: boolean }
  | { type: "set-edges-visible"; visible: boolean }
  | { type: "set-material-finish"; finish: CADMaterialFinish }
  | { type: "set-environment-percent"; percent: number }
  | { type: "reset" };

export const defaultCADAppearance: CADAppearanceSnapshot = Object.freeze({
  background: "graphite",
  displayStyle: "shaded-edges",
  lightingPreset: "studio",
  floorMode: "grid",
  contactShadowsVisible: true,
  edgesVisible: true,
  materialFinish: "satin",
  environmentPercent: 100,
});

export function reduceCADAppearance(
  current: CADAppearanceSnapshot,
  action: CADAppearanceAction,
): CADAppearanceSnapshot {
  switch (action.type) {
    case "set-background":
      return { ...current, background: action.background };
    case "set-display-style":
      return { ...current, displayStyle: action.style };
    case "set-lighting-preset":
      return { ...current, lightingPreset: action.preset };
    case "set-floor-mode":
      return { ...current, floorMode: action.mode };
    case "set-contact-shadows-visible":
      return { ...current, contactShadowsVisible: action.visible };
    case "set-edges-visible":
      return { ...current, edgesVisible: action.visible };
    case "set-material-finish":
      return { ...current, materialFinish: action.finish };
    case "set-environment-percent":
      return {
        ...current,
        environmentPercent: Math.min(200, Math.max(0, action.percent)),
      };
    case "reset":
      return defaultCADAppearance;
  }
}

type Listener = () => void;
type ApplyHandler = (snapshot: CADAppearanceSnapshot) => void;

export class CADAppearanceStore {
  private current: CADAppearanceSnapshot = defaultCADAppearance;
  private listeners = new Set<Listener>();
  private applyHandler: ApplyHandler | null = null;

  snapshot = (): CADAppearanceSnapshot => this.current;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  registerApplyHandler(handler: ApplyHandler): () => void {
    this.applyHandler = handler;
    handler(this.current);
    return () => {
      if (this.applyHandler === handler) this.applyHandler = null;
    };
  }

  dispatch(action: CADAppearanceAction): void {
    this.current = Object.freeze(reduceCADAppearance(this.current, action));
    this.applyHandler?.(this.current);
    this.listeners.forEach((listener) => listener());
  }
}

export const cadAppearance = new CADAppearanceStore();
