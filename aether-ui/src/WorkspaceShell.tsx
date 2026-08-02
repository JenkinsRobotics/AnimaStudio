import { useCallback, useRef, useState } from "react";
import type {
  CSSProperties,
  PointerEvent as ReactPointerEvent,
  ReactNode,
} from "react";
import { Rail, RailButton } from "./Rail";

/**
 * The app-window chrome, ported from the Swift `StudioWorkspaceScaffold`:
 * three layout presets — DOCKED (sidebars in flow), FLOATING (chrome
 * floats over the canvas), CANVAS (chrome hidden; edge hot-zones reveal
 * it on hover) — with per-side panel stacks toggled from icon rails and
 * tear-off floating panels that drag anywhere and restack near their
 * home edge. Spec lives in WIDGETS.md ("WorkspaceShell").
 */
export type LayoutPreset = "docked" | "floating" | "canvas";

export interface WorkspacePanel {
  id: string;
  title: string;
  icon: ReactNode;
  content: ReactNode;
}

const PRESET_ORDER: readonly LayoutPreset[] = ["floating", "docked", "canvas"];
const PRESET_GLYPH: Record<LayoutPreset, string> = {
  floating: "❏",
  docked: "▥",
  canvas: "⛶",
};
const LEFT_PANEL_WIDTH = 232;
const RIGHT_PANEL_WIDTH = 248;
const RESTACK_DISTANCE = 110;

export function nextLayoutPreset(preset: LayoutPreset): LayoutPreset {
  return PRESET_ORDER[(PRESET_ORDER.indexOf(preset) + 1) % PRESET_ORDER.length];
}

/** The studio layout button: cycles Floating → Docked → Canvas. */
export function LayoutPresetButton({
  preset,
  onChange,
}: {
  preset: LayoutPreset;
  onChange: (preset: LayoutPreset) => void;
}) {
  const next = nextLayoutPreset(preset);
  return (
    <button
      type="button"
      className="aui-icon-button"
      title={`Layout: ${preset} — click for ${next}`}
      aria-label={`Layout ${preset}, switch to ${next}`}
      onClick={() => onChange(next)}
    >
      {PRESET_GLYPH[preset]}
    </button>
  );
}

export interface FloatingPanelProps {
  title: string;
  x: number;
  y: number;
  width?: number;
  onMove: (x: number, y: number) => void;
  onDragEnd?: (x: number, y: number) => void;
  onDock?: () => void;
  onClose?: () => void;
  children: ReactNode;
}

/** A draggable floating panel (drag by header). Also used standalone for
 *  short-lived tools that must stay visible above the workspace. */
export function FloatingPanel(props: FloatingPanelProps) {
  const { title, x, y, width = LEFT_PANEL_WIDTH } = props;
  const drag = useRef<{ startX: number; startY: number; baseX: number; baseY: number } | null>(null);
  const pos = useRef({ x, y });
  pos.current = { x, y };

  const onPointerDown = (event: ReactPointerEvent) => {
    if ((event.target as HTMLElement).closest("button")) return;
    drag.current = { startX: event.clientX, startY: event.clientY, baseX: x, baseY: y };
    (event.currentTarget as HTMLElement).setPointerCapture?.(event.pointerId);
  };
  const onPointerMove = (event: ReactPointerEvent) => {
    if (!drag.current) return;
    props.onMove(
      drag.current.baseX + event.clientX - drag.current.startX,
      drag.current.baseY + event.clientY - drag.current.startY
    );
  };
  const onPointerUp = () => {
    if (!drag.current) return;
    drag.current = null;
    props.onDragEnd?.(pos.current.x, pos.current.y);
  };

  return (
    <div className="aui-float-panel" style={{ left: x, top: y, width }}>
      <div
        className="aui-float-panel-header"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
      >
        <span className="aui-float-panel-title">{title}</span>
        <span className="aui-float-panel-actions">
          {props.onDock ? (
            <button
              type="button"
              className="aui-float-panel-action"
              title="Dock panel"
              aria-label={`Dock ${title}`}
              onClick={props.onDock}
            >
              ⇤
            </button>
          ) : null}
          {props.onClose ? (
            <button
              type="button"
              className="aui-float-panel-action"
              title="Close panel"
              aria-label={`Close ${title}`}
              onClick={props.onClose}
            >
              ✕
            </button>
          ) : null}
        </span>
      </div>
      <div className="aui-float-panel-body">{props.children}</div>
    </div>
  );
}

export interface WorkspaceShellProps {
  preset: LayoutPreset;
  /** Usually a <Ribbon>; docked above the canvas or floating top-center. */
  toolbar?: ReactNode;
  leftPanels?: readonly WorkspacePanel[];
  rightPanels?: readonly WorkspacePanel[];
  defaultOpenLeft?: readonly string[];
  defaultOpenRight?: readonly string[];
  statusBar?: ReactNode;
  style?: CSSProperties;
  /** The center canvas/viewport. */
  children: ReactNode;
}

interface SideState {
  open: readonly string[];
  torn: Readonly<Record<string, { x: number; y: number }>>;
}

type Edge = "top" | "left" | "right";

export function WorkspaceShell(props: WorkspaceShellProps) {
  const {
    preset, toolbar, statusBar, style, children,
    leftPanels = [], rightPanels = [],
  } = props;
  const bodyRef = useRef<HTMLDivElement>(null);
  const [left, setLeft] = useState<SideState>({
    open: props.defaultOpenLeft ?? [],
    torn: {},
  });
  const [right, setRight] = useState<SideState>({
    open: props.defaultOpenRight ?? [],
    torn: {},
  });
  const [revealed, setRevealed] = useState<ReadonlySet<Edge>>(new Set());
  const hideTimers = useRef(new Map<Edge, ReturnType<typeof setTimeout>>());

  const reveal = useCallback((edge: Edge) => {
    const timer = hideTimers.current.get(edge);
    if (timer) clearTimeout(timer);
    setRevealed((current) => {
      if (current.has(edge)) return current;
      return new Set(current).add(edge);
    });
  }, []);
  const scheduleHide = useCallback((edge: Edge) => {
    const timer = hideTimers.current.get(edge);
    if (timer) clearTimeout(timer);
    hideTimers.current.set(
      edge,
      setTimeout(() => {
        setRevealed((current) => {
          const next = new Set(current);
          next.delete(edge);
          return next;
        });
      }, 160)
    );
  }, []);

  const sideFor = (side: "left" | "right") => (side === "left" ? left : right);
  const setterFor = (side: "left" | "right") =>
    side === "left" ? setLeft : setRight;
  const panelsFor = (side: "left" | "right") =>
    side === "left" ? leftPanels : rightPanels;
  const widthFor = (side: "left" | "right") =>
    side === "left" ? LEFT_PANEL_WIDTH : RIGHT_PANEL_WIDTH;

  const togglePanel = (side: "left" | "right", id: string) => {
    setterFor(side)((current) => {
      if (current.open.includes(id)) {
        const torn = { ...current.torn };
        delete torn[id];
        return { open: current.open.filter((entry) => entry !== id), torn };
      }
      return { ...current, open: [...current.open, id] };
    });
  };

  const detachPanel = (side: "left" | "right", id: string) => {
    const body = bodyRef.current;
    const count = Object.keys(sideFor(side).torn).length;
    const width = widthFor(side);
    const x =
      side === "left"
        ? 64 + count * 18
        : Math.max(64, (body?.clientWidth ?? 900) - 64 - width - count * 18);
    setterFor(side)((current) => ({
      ...current,
      torn: { ...current.torn, [id]: { x, y: 56 + count * 28 } },
    }));
  };

  const restackPanel = (side: "left" | "right", id: string) => {
    setterFor(side)((current) => {
      const torn = { ...current.torn };
      delete torn[id];
      return { ...current, torn };
    });
  };

  const movePanel = (side: "left" | "right", id: string, x: number, y: number) => {
    const body = bodyRef.current;
    const width = widthFor(side);
    const maxX = (body?.clientWidth ?? 1200) - width - 8;
    const maxY = (body?.clientHeight ?? 700) - 48;
    const clamped = {
      x: Math.min(Math.max(x, 8), Math.max(8, maxX)),
      y: Math.min(Math.max(y, 8), Math.max(8, maxY)),
    };
    setterFor(side)((current) => ({
      ...current,
      torn: { ...current.torn, [id]: clamped },
    }));
  };

  const maybeRestack = (side: "left" | "right", id: string, x: number) => {
    const bodyWidth = bodyRef.current?.clientWidth ?? 1200;
    const nearHome =
      side === "left"
        ? x < RESTACK_DISTANCE
        : bodyWidth - (x + widthFor(side)) < RESTACK_DISTANCE;
    if (nearHome) restackPanel(side, id);
  };

  const rail = (side: "left" | "right") => {
    const state = sideFor(side);
    return (
      <Rail>
        {panelsFor(side).map((panel) => (
          <RailButton
            key={panel.id}
            label={panel.title}
            active={state.open.includes(panel.id)}
            onClick={() => togglePanel(side, panel.id)}
          >
            {panel.icon}
          </RailButton>
        ))}
      </Rail>
    );
  };

  const stackedCard = (side: "left" | "right", panel: WorkspacePanel) => (
    <div key={panel.id} className="aui-shell-panel" style={{ width: widthFor(side) }}>
      <div className="aui-shell-panel-header">
        <span>{panel.title}</span>
        <span className="aui-float-panel-actions">
          <button
            type="button"
            className="aui-float-panel-action"
            title="Float panel"
            aria-label={`Float ${panel.title}`}
            onClick={() => detachPanel(side, panel.id)}
          >
            ⇱
          </button>
          <button
            type="button"
            className="aui-float-panel-action"
            title="Close panel"
            aria-label={`Close ${panel.title}`}
            onClick={() => togglePanel(side, panel.id)}
          >
            ✕
          </button>
        </span>
      </div>
      <div className="aui-shell-panel-body">{panel.content}</div>
    </div>
  );

  const stackedIDs = (side: "left" | "right") => {
    const state = sideFor(side);
    return state.open.filter((id) => !(id in state.torn));
  };

  const tornLayer = (side: "left" | "right") => {
    const state = sideFor(side);
    return panelsFor(side)
      .filter((panel) => panel.id in state.torn)
      .map((panel) => {
        const position = state.torn[panel.id];
        return (
          <FloatingPanel
            key={panel.id}
            title={panel.title}
            x={position.x}
            y={position.y}
            width={widthFor(side)}
            onMove={(x, y) => movePanel(side, panel.id, x, y)}
            onDragEnd={(x) => maybeRestack(side, panel.id, x)}
            onDock={() => restackPanel(side, panel.id)}
            onClose={() => togglePanel(side, panel.id)}
          >
            {panel.content}
          </FloatingPanel>
        );
      });
  };

  const floatingStack = (side: "left" | "right") => {
    const ids = stackedIDs(side);
    return (
      <div className={`aui-shell-fledge aui-shell-fledge--${side}`}>
        {side === "right" && ids.length > 0 ? floatingCards(side, ids) : null}
        <div className="aui-float">{rail(side)}</div>
        {side === "left" && ids.length > 0 ? floatingCards(side, ids) : null}
      </div>
    );
  };

  const floatingCards = (side: "left" | "right", ids: readonly string[]) => (
    <div className="aui-shell-flstack">
      {panelsFor(side)
        .filter((panel) => ids.includes(panel.id))
        .map((panel) => (
          <div key={panel.id} className="aui-float">
            {stackedCard(side, panel)}
          </div>
        ))}
    </div>
  );

  const canvasEdge = (edge: Edge, content: ReactNode) => (
    <div
      className={`aui-shell-edge aui-shell-edge--${edge}`}
      onMouseEnter={() => reveal(edge)}
      onMouseLeave={() => scheduleHide(edge)}
    >
      {revealed.has(edge) ? (
        content
      ) : (
        <div className={`aui-shell-handle aui-shell-handle--${edge}`} />
      )}
    </div>
  );

  const overlayChrome = (canvasMode: boolean) => {
    const top = toolbar ? (
      <div className="aui-shell-fltoolbar">
        <div className="aui-float">{toolbar}</div>
      </div>
    ) : null;
    const leftChrome = leftPanels.length ? floatingStack("left") : null;
    const rightChrome = rightPanels.length ? floatingStack("right") : null;
    if (!canvasMode) {
      return (
        <>
          {top}
          {leftChrome}
          {rightChrome}
        </>
      );
    }
    return (
      <>
        {top ? canvasEdge("top", top) : null}
        {leftChrome ? canvasEdge("left", leftChrome) : null}
        {rightChrome ? canvasEdge("right", rightChrome) : null}
      </>
    );
  };

  return (
    <div className="aui-shell" style={style}>
      <div className="aui-shell-body" ref={bodyRef}>
        {preset === "docked" ? (
          <div className="aui-shell-row">
            {leftPanels.length ? (
              <div className="aui-shell-side">
                {rail("left")}
                {stackedIDs("left").length ? (
                  <div className="aui-shell-stack">
                    {panelsFor("left")
                      .filter((panel) => stackedIDs("left").includes(panel.id))
                      .map((panel) => stackedCard("left", panel))}
                  </div>
                ) : null}
              </div>
            ) : null}
            <div className="aui-shell-main">
              {toolbar ? <div className="aui-shell-toolbar">{toolbar}</div> : null}
              <div className="aui-shell-center">{children}</div>
            </div>
            {rightPanels.length ? (
              <div className="aui-shell-side aui-shell-side--right">
                {stackedIDs("right").length ? (
                  <div className="aui-shell-stack">
                    {panelsFor("right")
                      .filter((panel) => stackedIDs("right").includes(panel.id))
                      .map((panel) => stackedCard("right", panel))}
                  </div>
                ) : null}
                {rail("right")}
              </div>
            ) : null}
          </div>
        ) : (
          <>
            <div className="aui-shell-center">{children}</div>
            {overlayChrome(preset === "canvas")}
          </>
        )}
        {tornLayer("left")}
        {tornLayer("right")}
      </div>
      {statusBar}
    </div>
  );
}
