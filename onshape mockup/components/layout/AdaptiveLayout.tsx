import {
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react';
import { GripHorizontal, Pin, X } from 'lucide-react';
import {
  layoutStore,
  panelIds,
  panelLabels,
  useLayoutStore,
  type PanelId,
} from './layout-store';
import {
  clampRect,
  computeLayout,
  dockEdgeAt,
  type Rect,
} from './layout-geometry';
function rectStyle(rect: Rect): CSSProperties {
  return { left: rect.x, top: rect.y, width: rect.width, height: rect.height };
}
export function AdaptiveLayout({
  panels,
  viewport,
  auxiliary,
}: {
  panels: Record<Exclude<PanelId, 'viewCube'>, ReactNode>;
  viewport: (navigationHost: HTMLDivElement | null) => ReactNode;
  auxiliary: ReactNode;
}) {
  const state = useLayoutStore();
  const host = useRef<HTMLDivElement>(null);
  const [navigationHost, setNavigationHost] = useState<HTMLDivElement | null>(
    null,
  );
  const [bounds, setBounds] = useState({ width: 1200, height: 720 });
  const [drag, setDrag] = useState<{
    id: PanelId;
    rect: Rect;
    edge: ReturnType<typeof dockEdgeAt>;
  } | null>(null);
  const [front, setFront] = useState<PanelId | null>(null);
  useEffect(() => {
    layoutStore.hydrate();
    const el = host.current;
    if (!el) return;
    const resize = () => {
      const r = el.getBoundingClientRect();
      if (r.width && r.height) setBounds({ width: r.width, height: r.height });
    };
    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  const geometry = computeLayout(state, bounds);
  return (
    <div
      ref={host}
      className={`adaptive-layout preset-${state.activePreset}`}
      data-layout-preset={state.activePreset}
    >
      <div className="adaptive-viewport" style={rectStyle(geometry.viewport)}>
        {viewport(navigationHost)}
      </div>
      {panelIds.map((id) => {
        const p = state.panels[id];
        const rect = drag?.id === id ? drag.rect : geometry.panels[id];
        return (
          <section
            key={id}
            data-panel-id={id}
            data-panel-mode={p.mode}
            data-dock-position={p.dockPosition}
            aria-label={`${panelLabels[id]} panel`}
            hidden={p.mode === 'hidden'}
            className={`adaptive-panel ${p.mode} panel-${id}`}
            style={{
              ...rectStyle(rect),
              zIndex: front === id ? 14 : p.mode === 'floating' ? 10 : 4,
            }}
          >
            <div className="panel-grip-bar">
              <button
                className="panel-drag-grip"
                title={`Move ${panelLabels[id]}`}
                aria-label={`Move ${panelLabels[id]}`}
                onKeyDown={(e) => {
                  const deltas: Record<string, [number, number]> = {
                    ArrowLeft: [-1, 0],
                    ArrowRight: [1, 0],
                    ArrowUp: [0, -1],
                    ArrowDown: [0, 1],
                  };
                  const d = deltas[e.key];
                  if (!d) return;
                  e.preventDefault();
                  const step = e.shiftKey ? 40 : 10;
                  const moved = clampRect(
                    {
                      ...rect,
                      x: rect.x + d[0] * step,
                      y: rect.y + d[1] * step,
                    },
                    bounds,
                  );
                  layoutStore.movePanel(id, moved);
                  setFront(id);
                }}
                onPointerDown={(e) => {
                  if (e.button !== 0) return;
                  e.preventDefault();
                  setFront(id);
                  const start = { x: e.clientX, y: e.clientY };
                  const grip = e.currentTarget;
                  grip.setPointerCapture(e.pointerId);
                  const parent = host.current!.getBoundingClientRect();
                  let current = rect;
                  let edge: ReturnType<typeof dockEdgeAt> = null;
                  let moved = false;
                  const move = (event: PointerEvent) => {
                    const dx = event.clientX - start.x,
                      dy = event.clientY - start.y;
                    if (Math.hypot(dx, dy) < 4 && !moved) return;
                    moved = true;
                    current = clampRect(
                      { ...rect, x: rect.x + dx, y: rect.y + dy },
                      bounds,
                    );
                    edge = dockEdgeAt(
                      {
                        x: event.clientX - parent.left,
                        y: event.clientY - parent.top,
                      },
                      bounds,
                    );
                    setDrag({ id, rect: current, edge });
                  };
                  const cleanup = () => {
                    grip.removeEventListener('pointermove', move);
                    grip.removeEventListener('pointerup', end);
                    grip.removeEventListener('pointercancel', cancel);
                  };
                  const cancel = () => {
                    cleanup();
                    setDrag(null);
                  };
                  const end = () => {
                    cleanup();
                    if (moved) {
                      if (edge) layoutStore.dockPanel(id, edge);
                      else
                        layoutStore.movePanel(id, {
                          x: current.x,
                          y: current.y,
                        });
                    }
                    setDrag(null);
                  };
                  grip.addEventListener('pointermove', move);
                  grip.addEventListener('pointerup', end);
                  grip.addEventListener('pointercancel', cancel);
                }}
              >
                <GripHorizontal size={12} />
                <span>{panelLabels[id]}</span>
              </button>
              <button
                title={`${p.mode === 'floating' ? 'Dock' : 'Float'} ${panelLabels[id]}`}
                onClick={() =>
                  layoutStore.setPanelMode(
                    id,
                    p.mode === 'floating' ? 'docked' : 'floating',
                  )
                }
              >
                <Pin size={10} />
              </button>
              <button
                title={`Hide ${panelLabels[id]}`}
                onClick={() => layoutStore.setPanelMode(id, 'hidden')}
              >
                <X size={11} />
              </button>
            </div>
            <div className="adaptive-panel-content">
              {id === 'viewCube' ? (
                <div className="navigation-slot" ref={setNavigationHost} />
              ) : (
                panels[id]
              )}
            </div>
          </section>
        );
      })}
      {drag?.edge && (
        <div
          className={`dock-drop-indicator edge-${drag.edge}`}
          aria-live="polite"
        >
          Dock {drag.edge}
        </div>
      )}
      <div className="adaptive-auxiliary">{auxiliary}</div>
    </div>
  );
}
