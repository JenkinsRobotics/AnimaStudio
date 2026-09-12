/* The native RealityKitViewport PreviewAppearance themes, ported exactly. */
export type CADBackgroundPreset = "midnight" | "graphite" | "cad-light" | "blueprint" | "onshape";
export type CADMaterialFinish = "matte" | "satin" | "gloss";
export type CADDisplayStyle = "shaded" | "shaded-edges" | "wireframe" | "hidden-line" | "ghost";
export type CADLightingPreset = "studio" | "softbox" | "daylight" | "dark-room";
export type CADFloorMode = "none" | "grid" | "floor" | "both";

export type CADEnvironmentTheme = "aether" | "onshape" | "custom";

export interface CADAppearanceSnapshot {
  environmentTheme: CADEnvironmentTheme;
  gridOpacityPercent: number;
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
  | { type: "set-grid-opacity-percent"; percent: number }
  | { type: "apply-environment-theme"; theme: "aether" | "onshape" }
  | { type: "reset" };

export const defaultCADAppearance: CADAppearanceSnapshot = Object.freeze({
  // Onshape is the shipped default environment (Jonathan, 2026-09-11).
  environmentTheme: "onshape" as CADEnvironmentTheme,
  gridOpacityPercent: 100,
  background: "onshape",
  displayStyle: "shaded-edges",
  lightingPreset: "daylight",
  floorMode: "none",
  contactShadowsVisible: false,
  edgesVisible: true,
  materialFinish: "satin",
  environmentPercent: 100,
});

/** The Aether environment bundle (the previous default look). */
export const aetherEnvironmentBundle = Object.freeze({
  environmentTheme: "aether" as CADEnvironmentTheme,
  gridOpacityPercent: 100,
  background: "graphite" as const,
  displayStyle: "shaded-edges" as const,
  lightingPreset: "studio" as const,
  floorMode: "grid" as const,
  contactShadowsVisible: true,
  edgesVisible: true,
  materialFinish: "satin" as const,
  environmentPercent: 100,
});

export function reduceCADAppearance(
  current: CADAppearanceSnapshot,
  action: CADAppearanceAction,
): CADAppearanceSnapshot {
  // Named environment bundles; any manual change marks the theme "custom".
  if (action.type === "apply-environment-theme") {
    const bundles: Record<"aether" | "onshape", Partial<CADAppearanceSnapshot>> = {
      aether: { ...aetherEnvironmentBundle },
      onshape: {
        background: "onshape",
        floorMode: "none",
        lightingPreset: "daylight",
        contactShadowsVisible: false,
        edgesVisible: true,
        materialFinish: "satin",
        displayStyle: "shaded-edges",
        gridOpacityPercent: 100,
        environmentPercent: 100,
      },
    };
    return { ...current, ...bundles[action.theme], environmentTheme: action.theme };
  }
  if (action.type === "set-grid-opacity-percent")
    return {
      ...current,
      environmentTheme: "custom",
      gridOpacityPercent: Math.min(100, Math.max(0, Math.round(action.percent))),
    };
  switch (action.type) {
    case "set-background":
      return { ...current, environmentTheme: "custom", background: action.background };
    case "set-display-style":
      return { ...current, environmentTheme: "custom", displayStyle: action.style };
    case "set-lighting-preset":
      return { ...current, environmentTheme: "custom", lightingPreset: action.preset };
    case "set-floor-mode":
      return { ...current, environmentTheme: "custom", floorMode: action.mode };
    case "set-contact-shadows-visible":
      return { ...current, environmentTheme: "custom", contactShadowsVisible: action.visible };
    case "set-edges-visible":
      return { ...current, environmentTheme: "custom", edgesVisible: action.visible };
    case "set-material-finish":
      return { ...current, environmentTheme: "custom", materialFinish: action.finish };
    case "set-environment-percent":
      return {
        ...current,
        environmentTheme: "custom",
        environmentPercent: Math.min(200, Math.max(0, action.percent)),
      };
    case "reset":
      return defaultCADAppearance;
  }
}

type Listener = () => void;
type ApplyHandler = (snapshot: CADAppearanceSnapshot) => void;

export class CADAppearanceStore {
  private current: CADAppearanceSnapshot;
  private listeners = new Set<Listener>();
  private applyHandler: ApplyHandler | null = null;

  constructor(initial: CADAppearanceSnapshot = defaultCADAppearance) {
    this.current = initial;
  }

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

/* Viewport rendering appearance is an Aether CAD app setting (CAD owns the
 * WebGPU/OCCT viewport) — persisted per device, distinct from the universal
 * suite themes in core/assets/themes. */
const CAD_APPEARANCE_KEY = "aether-cad-appearance";
function restoreCADAppearance(): CADAppearanceSnapshot {
  try {
    const raw = localStorage.getItem(CAD_APPEARANCE_KEY);
    if (!raw) return defaultCADAppearance;
    const saved = JSON.parse(raw) as Partial<CADAppearanceSnapshot> & { background?: string };
    const background = ["midnight", "graphite", "cad-light", "blueprint"].includes(saved.background ?? "")
      ? (saved.background as CADBackgroundPreset)
      : defaultCADAppearance.background;
    return { ...defaultCADAppearance, ...saved, background };
  } catch {
    return defaultCADAppearance;
  }
}
export const cadAppearance = new CADAppearanceStore(restoreCADAppearance());
if (typeof localStorage !== "undefined") {
  cadAppearance.subscribe(() => {
    try { localStorage.setItem(CAD_APPEARANCE_KEY, JSON.stringify(cadAppearance.snapshot())); } catch { /* device preference only */ }
  });
}
