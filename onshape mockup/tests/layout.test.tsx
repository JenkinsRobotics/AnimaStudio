import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useEffect } from 'react';
import { AdaptiveLayout } from '../components/layout/AdaptiveLayout';
import { LayoutControls } from '../components/layout/LayoutControls';
import {
  createLayoutStore,
  layoutStore,
  panelIds,
  parseLayoutPreferences,
} from '../components/layout/layout-store';
import {
  computeLayout,
  dockEdgeAt,
} from '../components/layout/layout-geometry';
const observer = class {
  observe() {}
  disconnect() {}
};
beforeEach(() => {
  vi.stubGlobal('ResizeObserver', observer);
  layoutStore.resetAll();
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
describe('layout store and projection', () => {
  it('uses the requested panel contract and restores customized layouts per preset', () => {
    const store = createLayoutStore();
    expect(Object.keys(store.getSnapshot().panels).sort()).toEqual(
      [...panelIds].sort(),
    );
    store.dockPanel('historyTree', 'right');
    store.setPreset('shapr3d');
    expect(store.getSnapshot().panels.historyTree.mode).toBe('hidden');
    store.movePanel('commandRibbon', { x: 83, y: 108 });
    store.setPreset('onshape');
    expect(store.getSnapshot().panels.historyTree.dockPosition).toBe('right');
    store.setPreset('shapr3d');
    expect(store.getSnapshot().panels.commandRibbon.floatCoordinates).toEqual({
      x: 83,
      y: 108,
    });
  });
  it('round-trips validated local preferences and safely handles corrupt or unavailable storage', () => {
    let raw = '';
    const storage = {
      getItem: () => raw,
      setItem: (_key: string, value: string) => {
        raw = value;
      },
    };
    const original = createLayoutStore(storage);
    original.setPreset('shapr3d');
    original.movePanel('viewCube', { x: 421, y: 64 });
    const restored = createLayoutStore(storage);
    restored.hydrate();
    expect(restored.getSnapshot()).toEqual(original.getSnapshot());
    expect(parseLayoutPreferences('{')).toBeNull();
    const corrupt = JSON.parse(raw);
    corrupt.layouts.shapr3d.viewCube.floatCoordinates.x = 'wrong';
    expect(parseLayoutPreferences(JSON.stringify(corrupt))).toBeNull();
    const unavailable = createLayoutStore({
      getItem: () => {
        throw Error();
      },
      setItem: () => {
        throw Error();
      },
    });
    expect(() => {
      unavailable.hydrate();
      unavailable.setPreset('shapr3d');
    }).not.toThrow();
  });
  it('clamps floating panels on small windows and derives positive dock lanes on every edge', () => {
    const store = createLayoutStore();
    store.movePanel('viewCube', { x: 5000, y: 4000 });
    store.dockPanel('historyTree', 'right');
    store.dockPanel('leftSidebar', 'left');
    for (const bounds of [
      { width: 1280, height: 720 },
      { width: 360, height: 400 },
    ]) {
      const layout = computeLayout(store.getSnapshot(), bounds);
      expect(layout.viewport.width).toBeGreaterThan(0);
      expect(layout.viewport.height).toBeGreaterThan(0);
      for (const id of panelIds) {
        const r = layout.panels[id];
        expect(r.x).toBeGreaterThanOrEqual(0);
        expect(r.y).toBeGreaterThanOrEqual(0);
        expect(r.x + r.width).toBeLessThanOrEqual(bounds.width + 0.001);
        expect(r.y + r.height).toBeLessThanOrEqual(bounds.height + 0.001);
      }
    }
    store.setPreset('shapr3d');
    expect(
      computeLayout(store.getSnapshot(), { width: 1280, height: 720 }).viewport,
    ).toEqual({ x: 0, y: 0, width: 1280, height: 720 });
  });
  it('supports hiding, floating, docking and resetting without changing editor state', () => {
    const store = createLayoutStore();
    store.setPanelMode('elementTabs', 'hidden');
    expect(store.getSnapshot().panels.elementTabs.mode).toBe('hidden');
    store.setPanelMode('elementTabs', 'floating');
    expect(
      store.getSnapshot().panels.elementTabs.floatCoordinates,
    ).toBeDefined();
    store.dockPanel('elementTabs', 'bottom');
    store.resetPreset();
    expect(store.getSnapshot().panels.elementTabs).toMatchObject({
      mode: 'docked',
      dockPosition: 'bottom',
    });
    expect(dockEdgeAt({ x: 4, y: 300 }, { width: 1200, height: 700 })).toBe(
      'left',
    );
    expect(
      dockEdgeAt({ x: 600, y: 300 }, { width: 1200, height: 700 }),
    ).toBeNull();
  });
});
describe('persistent adaptive shell', () => {
  it('keeps canvas and panel DOM mounted through preset, mode, visibility and docking changes', async () => {
    const mounted = vi.fn(),
      unmounted = vi.fn();
    function PersistentCanvas() {
      useEffect(() => {
        mounted();
        return () => unmounted();
      }, []);
      return <canvas data-testid="real-canvas-node" />;
    }
    const user = userEvent.setup();
    render(
      <>
        <LayoutControls />
        <AdaptiveLayout
          panels={{
            commandRibbon: (
              <input aria-label="Tool draft" defaultValue="25 mm" />
            ),
            leftSidebar: <div>Parts content</div>,
            historyTree: <div>History content</div>,
            elementTabs: <div>Element content</div>,
          }}
          viewport={() => <PersistentCanvas />}
          auxiliary={null}
        />
      </>,
    );
    const canvas = screen.getByTestId('real-canvas-node'),
      input = screen.getByLabelText('Tool draft');
    await user.clear(input);
    await user.type(input, '40 mm');
    await user.click(screen.getByRole('button', { name: 'Shapr3D' }));
    expect(screen.getByTestId('real-canvas-node')).toBe(canvas);
    expect(screen.getByLabelText('Tool draft')).toBe(input);
    expect((input as HTMLInputElement).value).toBe('40 mm');
    await user.click(screen.getByTitle('Layout settings'));
    await user.selectOptions(screen.getByLabelText('Commands'), 'hidden');
    expect(
      document
        .querySelector('[data-panel-id="commandRibbon"]')
        ?.hasAttribute('hidden'),
    ).toBe(true);
    await user.selectOptions(screen.getByLabelText('Commands'), 'right');
    expect(
      document
        .querySelector('[data-panel-id="commandRibbon"]')
        ?.getAttribute('data-dock-position'),
    ).toBe('right');
    await user.click(screen.getByRole('button', { name: 'Onshape' }));
    expect(screen.getByTestId('real-canvas-node')).toBe(canvas);
    expect(mounted).toHaveBeenCalledTimes(1);
    expect(unmounted).not.toHaveBeenCalled();
    expect(screen.getByLabelText('Tool draft')).toBe(input);
  });
  it('moves floating panels by keyboard and docks after an edge drag', async () => {
    const user = userEvent.setup();
    render(
      <>
        <LayoutControls />
        <AdaptiveLayout
          panels={{
            commandRibbon: 'Tools',
            historyTree: 'History',
            leftSidebar: 'Parts',
            elementTabs: 'Tabs',
          }}
          viewport={() => <canvas />}
          auxiliary={null}
        />
      </>,
    );
    await user.click(screen.getByRole('button', { name: 'Shapr3D' }));
    const grip = screen.getByRole('button', { name: 'Move Commands' });
    grip.focus();
    await user.keyboard('{ArrowRight}');
    expect(
      layoutStore.getSnapshot().panels.commandRibbon.floatCoordinates?.x,
    ).toBe(26);
    Object.defineProperty(grip, 'setPointerCapture', { value: vi.fn() });
    fireEvent.pointerDown(grip, {
      button: 0,
      pointerId: 1,
      clientX: 40,
      clientY: 50,
    });
    fireEvent.pointerMove(grip, { pointerId: 1, clientX: 3, clientY: 100 });
    fireEvent.pointerUp(grip, { pointerId: 1, clientX: 3, clientY: 100 });
    expect(layoutStore.getSnapshot().panels.commandRibbon).toMatchObject({
      mode: 'docked',
      dockPosition: 'left',
    });
  });
});
