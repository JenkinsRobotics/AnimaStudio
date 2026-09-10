import {
  panelIds,
  type PanelId,
  type PanelState,
  type LayoutState,
} from './layout-store';
export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}
export interface LayoutGeometry {
  viewport: Rect;
  panels: Record<PanelId, Rect>;
}
const metrics: Record<
  PanelId,
  { width: number; height: number; barHeight: number }
> = {
  commandRibbon: { width: 100, height: 510, barHeight: 65 },
  historyTree: { width: 258, height: 430, barHeight: 260 },
  leftSidebar: { width: 258, height: 175, barHeight: 180 },
  viewCube: { width: 146, height: 226, barHeight: 226 },
  elementTabs: { width: 650, height: 56, barHeight: 56 },
};
export function clampRect(
  rect: Rect,
  bounds: { width: number; height: number },
): Rect {
  const width = Math.min(Math.max(0, rect.width), Math.max(0, bounds.width));
  const height = Math.min(Math.max(0, rect.height), Math.max(0, bounds.height));
  return {
    width,
    height,
    x: Math.max(0, Math.min(rect.x, bounds.width - width)),
    y: Math.max(0, Math.min(rect.y, bounds.height - height)),
  };
}
/** Derive all dock lanes from panel state. Panels never change React parents. */
export function computeLayout(
  state: LayoutState,
  bounds: { width: number; height: number },
): LayoutGeometry {
  const width = Math.max(0, bounds.width),
    height = Math.max(0, bounds.height);
  const result = {
    viewport: { x: 0, y: 0, width, height },
    panels: {} as Record<PanelId, Rect>,
  };
  const lane = (position: PanelState['dockPosition']) =>
    panelIds.filter(
      (id) =>
        state.panels[id].mode === 'docked' &&
        state.panels[id].dockPosition === position,
    );
  for (const edge of ['top', 'bottom'] as const) {
    const ids = lane(edge);
    const desired = ids.reduce((s, id) => s + metrics[id].barHeight, 0);
    const total = Math.min(desired, height * 0.32);
    for (const id of ids) {
      const h = desired ? (metrics[id].barHeight / desired) * total : 0;
      const r = result.viewport;
      const y = edge === 'top' ? r.y : r.y + r.height - h;
      result.panels[id] = { x: 0, y, width, height: h };
      if (edge === 'top') r.y += h;
      r.height -= h;
    }
  }
  for (const edge of ['left', 'right'] as const) {
    const ids = lane(edge);
    if (!ids.length) continue;
    const thickness = Math.min(
      Math.max(
        ...ids.map((id) => (id === 'elementTabs' ? 230 : metrics[id].width)),
      ),
      width * 0.3,
    );
    const r = result.viewport;
    const x = edge === 'left' ? r.x : r.x + r.width - thickness;
    const desired = ids.reduce((sum, id) => sum + metrics[id].height, 0);
    let y = r.y;
    const extra = Math.max(0, r.height - desired);
    const flexible = ids.includes('historyTree') ? 'historyTree' : ids[0];
    for (const id of ids) {
      const h =
        desired > r.height
          ? (metrics[id].height / desired) * r.height
          : metrics[id].height + (id === flexible ? extra : 0);
      result.panels[id] = { x, y, width: thickness, height: h };
      y += h;
    }
    if (edge === 'left') r.x += thickness;
    r.width -= thickness;
  }
  for (const id of panelIds) {
    const p = state.panels[id];
    if (p.mode === 'docked') continue;
    const m = metrics[id];
    const wideRibbon =
      id === 'commandRibbon' && state.activePreset === 'onshape';
    const w = wideRibbon
      ? Math.max(200, width - 32)
      : id === 'elementTabs'
        ? Math.min(m.width, Math.max(180, width - 156))
        : m.width;
    const h = wideRibbon ? m.barHeight : m.height;
    // Coordinates are always stage-local CSS pixels; clamp on every resize.
    result.panels[id] = clampRect(
      {
        x: p.floatCoordinates?.x ?? 120,
        y: p.floatCoordinates?.y ?? 60,
        width: w,
        height: h,
      },
      { width, height },
    );
  }
  return result;
}
export function dockEdgeAt(
  point: { x: number; y: number },
  bounds: { width: number; height: number },
): PanelState['dockPosition'] | null {
  const threshold = 24;
  if (point.x < threshold) return 'left';
  if (point.x > bounds.width - threshold) return 'right';
  if (point.y < threshold) return 'top';
  if (point.y > bounds.height - threshold) return 'bottom';
  return null;
}
