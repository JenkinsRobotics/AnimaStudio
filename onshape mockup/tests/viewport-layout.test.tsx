import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { act, cleanup, render } from '@testing-library/react';
import { AdaptiveLayout } from '../components/layout/AdaptiveLayout';
import { CADViewport } from '../components/cad/CADViewport';
import { layoutStore } from '../components/layout/layout-store';
const lifecycle = vi.hoisted(() => ({ created: vi.fn(), disposed: vi.fn() }));
vi.mock('three', async (importOriginal) => {
  const actual = await importOriginal<typeof import('three')>();
  return {
    ...actual,
    WebGLRenderer: class {
      domElement = document.createElement('canvas');
      localClippingEnabled = false;
      constructor() {
        lifecycle.created();
      }
      setPixelRatio() {}
      setClearColor() {}
      setSize(width: number, height: number) {
        this.domElement.width = width;
        this.domElement.height = height;
      }
      render() {}
      dispose() {
        lifecycle.disposed();
      }
    },
  };
});
beforeEach(() => {
  layoutStore.resetAll();
  vi.clearAllMocks();
  vi.stubGlobal(
    'ResizeObserver',
    class {
      observe() {}
      disconnect() {}
    },
  );
  vi.stubGlobal('requestAnimationFrame', () => 1);
  vi.stubGlobal('cancelAnimationFrame', () => {});
  vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(
    () =>
      ({
        fillRect() {},
        strokeRect() {},
        fillText() {},
      }) as unknown as CanvasRenderingContext2D,
  );
});
afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});
it('preserves both renderer instances, scene canvas and cube canvas when panels move or hide', () => {
  const { container, unmount } = render(
    <AdaptiveLayout
      panels={{
        commandRibbon: 'Commands',
        historyTree: 'History',
        leftSidebar: 'Parts',
        elementTabs: 'Elements',
      }}
      auxiliary={null}
      viewport={(navigationHost) => (
        <CADViewport
          navigationHost={navigationHost}
          planes={[true, true, true]}
          sketch={false}
        />
      )}
    />,
  );
  const scene = container.querySelector('.three-host canvas'),
    cube = container.querySelector('.view-cube canvas');
  expect(scene).not.toBeNull();
  expect(cube).not.toBeNull();
  expect(lifecycle.created).toHaveBeenCalledTimes(2);
  act(() => layoutStore.setPreset('shapr3d'));
  act(() => layoutStore.movePanel('viewCube', { x: 450, y: 60 }));
  act(() => layoutStore.setPanelMode('viewCube', 'hidden'));
  act(() => layoutStore.dockPanel('viewCube', 'right'));
  act(() => layoutStore.setPreset('onshape'));
  expect(container.querySelector('.three-host canvas')).toBe(scene);
  expect(container.querySelector('.view-cube canvas')).toBe(cube);
  expect(lifecycle.created).toHaveBeenCalledTimes(2);
  expect(lifecycle.disposed).not.toHaveBeenCalled();
  unmount();
  expect(lifecycle.disposed).toHaveBeenCalledTimes(2);
});
