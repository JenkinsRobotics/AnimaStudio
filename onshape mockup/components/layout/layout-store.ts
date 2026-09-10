import { useSyncExternalStore } from 'react';

export type PanelId =
  | 'leftSidebar'
  | 'commandRibbon'
  | 'historyTree'
  | 'viewCube'
  | 'elementTabs';
export interface PanelState {
  id: PanelId;
  mode: 'docked' | 'floating' | 'hidden';
  dockPosition?: 'left' | 'right' | 'top' | 'bottom';
  floatCoordinates?: { x: number; y: number };
}
export interface LayoutTheme {
  activePreset: 'onshape' | 'shapr3d';
}
export type LayoutPreset = LayoutTheme['activePreset'];
export type PanelMap = Record<PanelId, PanelState>;
export interface LayoutState extends LayoutTheme {
  panels: PanelMap;
}
export const panelIds: PanelId[] = [
  'commandRibbon',
  'historyTree',
  'leftSidebar',
  'viewCube',
  'elementTabs',
];
export const panelLabels: Record<PanelId, string> = {
  commandRibbon: 'Commands',
  historyTree: 'Feature history',
  leftSidebar: 'Parts',
  viewCube: 'View cube',
  elementTabs: 'Elements',
};
const STORAGE_KEY = 'cad-studio.layout.v1';
const presets: Record<LayoutPreset, PanelMap> = {
  onshape: {
    commandRibbon: { id: 'commandRibbon', mode: 'docked', dockPosition: 'top' },
    historyTree: { id: 'historyTree', mode: 'docked', dockPosition: 'left' },
    leftSidebar: { id: 'leftSidebar', mode: 'docked', dockPosition: 'left' },
    viewCube: {
      id: 'viewCube',
      mode: 'floating',
      floatCoordinates: { x: 1060, y: 70 },
    },
    elementTabs: { id: 'elementTabs', mode: 'docked', dockPosition: 'bottom' },
  },
  shapr3d: {
    commandRibbon: {
      id: 'commandRibbon',
      mode: 'floating',
      floatCoordinates: { x: 16, y: 20 },
    },
    historyTree: {
      id: 'historyTree',
      mode: 'hidden',
      dockPosition: 'right',
      floatCoordinates: { x: 850, y: 20 },
    },
    leftSidebar: {
      id: 'leftSidebar',
      mode: 'hidden',
      dockPosition: 'left',
      floatCoordinates: { x: 120, y: 20 },
    },
    viewCube: {
      id: 'viewCube',
      mode: 'floating',
      floatCoordinates: { x: 1060, y: 20 },
    },
    elementTabs: {
      id: 'elementTabs',
      mode: 'floating',
      floatCoordinates: { x: 130, y: 610 },
    },
  },
};
function copyPreset(preset: LayoutPreset): PanelMap {
  return Object.fromEntries(
    panelIds.map((id) => [
      id,
      {
        ...presets[preset][id],
        floatCoordinates: presets[preset][id].floatCoordinates
          ? { ...presets[preset][id].floatCoordinates }
          : undefined,
      },
    ]),
  ) as PanelMap;
}
/** Validate device-local preferences before allowing them to affect the shell. */
export function parseLayoutPreferences(
  raw: string,
): {
  activePreset: LayoutPreset;
  layouts: Record<LayoutPreset, PanelMap>;
} | null {
  try {
    const data = JSON.parse(raw);
    if (
      data.version !== 1 ||
      !['onshape', 'shapr3d'].includes(data.activePreset)
    )
      return null;
    const layouts = {} as Record<LayoutPreset, PanelMap>;
    for (const preset of ['onshape', 'shapr3d'] as const) {
      const panels = copyPreset(preset);
      for (const id of panelIds) {
        const p = data.layouts?.[preset]?.[id];
        if (
          !p ||
          p.id !== id ||
          !['docked', 'floating', 'hidden'].includes(p.mode)
        )
          return null;
        if (
          p.dockPosition !== undefined &&
          !['left', 'right', 'top', 'bottom'].includes(p.dockPosition)
        )
          return null;
        if (p.mode === 'docked' && !p.dockPosition) return null;
        if (
          p.floatCoordinates !== undefined &&
          (!Number.isFinite(p.floatCoordinates.x) ||
            !Number.isFinite(p.floatCoordinates.y))
        )
          return null;
        if (p.mode === 'floating' && !p.floatCoordinates) return null;
        panels[id] = {
          id,
          mode: p.mode,
          dockPosition: p.dockPosition,
          floatCoordinates: p.floatCoordinates
            ? {
                x: Math.max(0, p.floatCoordinates.x),
                y: Math.max(0, p.floatCoordinates.y),
              }
            : undefined,
        };
      }
      layouts[preset] = panels;
    }
    return { activePreset: data.activePreset, layouts };
  } catch {
    return null;
  }
}
export function createLayoutStore(
  storage?: Pick<Storage, 'getItem' | 'setItem'>,
) {
  let layouts: Record<LayoutPreset, PanelMap> = {
    onshape: copyPreset('onshape'),
    shapr3d: copyPreset('shapr3d'),
  };
  let state: LayoutState = { activePreset: 'onshape', panels: layouts.onshape };
  const listeners = new Set<() => void>();
  const publish = () => {
    try {
      storage?.setItem(
        STORAGE_KEY,
        JSON.stringify({
          version: 1,
          activePreset: state.activePreset,
          layouts,
        }),
      );
    } catch {
      /* Storage can be unavailable; the live editor remains usable. */
    }
    listeners.forEach((fn) => fn());
  };
  const update = (id: PanelId, patch: Partial<PanelState>) => {
    const panels = {
      ...state.panels,
      [id]: { ...state.panels[id], ...patch, id },
    };
    layouts = { ...layouts, [state.activePreset]: panels };
    state = { ...state, panels };
    publish();
  };
  return {
    getSnapshot: () => state,
    subscribe: (fn: () => void) => {
      listeners.add(fn);
      return () => {
        listeners.delete(fn);
      };
    },
    hydrate: () => {
      try {
        const raw = storage?.getItem(STORAGE_KEY);
        const parsed = raw ? parseLayoutPreferences(raw) : null;
        if (parsed) {
          layouts = parsed.layouts;
          state = {
            activePreset: parsed.activePreset,
            panels: layouts[parsed.activePreset],
          };
          listeners.forEach((fn) => fn());
        }
      } catch {
        /* Keep defaults. */
      }
    },
    setPreset: (preset: LayoutPreset) => {
      if (state.activePreset === preset) return;
      state = { activePreset: preset, panels: layouts[preset] };
      publish();
    },
    setPanelMode: (id: PanelId, mode: PanelState['mode']) =>
      update(id, {
        mode,
        ...(mode === 'docked'
          ? { dockPosition: state.panels[id].dockPosition ?? 'left' }
          : {}),
        ...(mode === 'floating'
          ? {
              floatCoordinates: state.panels[id].floatCoordinates ?? {
                x: 120,
                y: 60,
              },
            }
          : {}),
      }),
    dockPanel: (
      id: PanelId,
      dockPosition: NonNullable<PanelState['dockPosition']>,
    ) => update(id, { mode: 'docked', dockPosition }),
    movePanel: (id: PanelId, coordinates: { x: number; y: number }) => {
      if (!Number.isFinite(coordinates.x) || !Number.isFinite(coordinates.y))
        return;
      update(id, {
        mode: 'floating',
        floatCoordinates: {
          x: Math.max(0, coordinates.x),
          y: Math.max(0, coordinates.y),
        },
      });
    },
    restorePanel: (id: PanelId) => {
      const previous = state.panels[id];
      update(id, {
        mode: previous.floatCoordinates ? 'floating' : 'docked',
        dockPosition: previous.dockPosition ?? 'left',
      });
    },
    resetPreset: () => {
      const panels = copyPreset(state.activePreset);
      layouts = { ...layouts, [state.activePreset]: panels };
      state = { ...state, panels };
      publish();
    },
    resetAll: () => {
      layouts = {
        onshape: copyPreset('onshape'),
        shapr3d: copyPreset('shapr3d'),
      };
      state = { activePreset: 'onshape', panels: layouts.onshape };
      publish();
    },
  };
}
// One authority for layout preferences. No document, feature, or camera data lives here.
export const layoutStore = createLayoutStore({
  getItem: (key) => window.localStorage.getItem(key),
  setItem: (key, value) => window.localStorage.setItem(key, value),
});
export function useLayoutStore() {
  return useSyncExternalStore(
    layoutStore.subscribe,
    layoutStore.getSnapshot,
    layoutStore.getSnapshot,
  );
}
