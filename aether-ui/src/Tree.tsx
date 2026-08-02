import { useCallback, useMemo, useRef, useState } from "react";
import type { KeyboardEvent, ReactNode } from "react";

/**
 * THE tree. Every list-tree in every Aether app is this component —
 * spec and definition-of-done live in WIDGETS.md ("Tree — spec v2").
 * Apps supply nodes and handlers; they never re-implement behavior.
 */
export interface TreeNode {
  id: string;
  label: string;
  icon?: ReactNode;
  badge?: string;
  /** Row cannot be focused or selected. */
  disabled?: boolean;
  /** Visually de-emphasized (e.g. suppressed/hidden entities). */
  dimmed?: boolean;
  /** Hover-revealed trailing actions; clicks never change selection. */
  actions?: readonly { id: string; label: string; icon: ReactNode }[];
  children?: readonly TreeNode[];
}

export interface TreeProps {
  nodes: readonly TreeNode[];
  selectedIDs: ReadonlySet<string>;
  /**
   * mode: "single" replaces the selection, "toggle" (⌘/ctrl) flips one
   * row, "range" (⇧) selects from the anchor over the visible order.
   */
  onSelect: (
    ids: readonly string[],
    mode: "single" | "toggle" | "range"
  ) => void;
  /** Double-click, or Enter on an already-selected row. */
  onActivate?: (id: string) => void;
  onContextMenu?: (id: string, x: number, y: number) => void;
  onAction?: (nodeID: string, actionID: string) => void;
  /** Controlled expansion; omit for internal state. */
  expandedIDs?: ReadonlySet<string>;
  onToggle?: (id: string, expanded: boolean) => void;
  defaultCollapsedIDs?: readonly string[];
  /** Case-insensitive filter: keeps matching rows and their ancestors,
   *  and auto-reveals matches inside collapsed branches. */
  filter?: string;
  emptyState?: ReactNode;
}

interface FlatRow {
  node: TreeNode;
  depth: number;
  hasChildren: boolean;
  expanded: boolean;
}

export function Tree(props: TreeProps) {
  const {
    nodes, selectedIDs, onSelect, onActivate, onContextMenu, onAction,
    expandedIDs, onToggle, defaultCollapsedIDs, filter, emptyState,
  } = props;

  const [internalCollapsed, setInternalCollapsed] = useState<
    ReadonlySet<string>
  >(() => new Set(defaultCollapsedIDs ?? []));
  const isExpanded = useCallback(
    (id: string) =>
      expandedIDs ? expandedIDs.has(id) : !internalCollapsed.has(id),
    [expandedIDs, internalCollapsed]
  );
  const toggle = useCallback(
    (id: string, currentlyExpanded: boolean) => {
      onToggle?.(id, !currentlyExpanded);
      if (!expandedIDs) {
        setInternalCollapsed((current) => {
          const next = new Set(current);
          if (currentlyExpanded) next.add(id);
          else next.delete(id);
          return next;
        });
      }
    },
    [expandedIDs, onToggle]
  );

  const filterText = (filter ?? "").trim().toLowerCase();
  const matchesFilter = useCallback(
    function matches(node: TreeNode): boolean {
      if (node.label.toLowerCase().includes(filterText)) return true;
      return (node.children ?? []).some(matches);
    },
    [filterText]
  );

  // The visible, ordered row list — selection ranges and keyboard
  // navigation are defined over exactly this order.
  const rows = useMemo<FlatRow[]>(() => {
    const out: FlatRow[] = [];
    const walk = (level: readonly TreeNode[], depth: number) => {
      for (const node of level) {
        if (filterText && !matchesFilter(node)) continue;
        const hasChildren = (node.children?.length ?? 0) > 0;
        const expanded =
          hasChildren && (filterText ? true : isExpanded(node.id));
        out.push({ node, depth, hasChildren, expanded });
        if (expanded) walk(node.children!, depth + 1);
      }
    };
    walk(nodes, 0);
    return out;
  }, [nodes, filterText, matchesFilter, isExpanded]);

  const anchorRef = useRef<string | null>(null);
  const [focusedID, setFocusedID] = useState<string | null>(null);
  const rowRefs = useRef(new Map<string, HTMLButtonElement>());

  const applySelect = useCallback(
    (
      row: FlatRow,
      event: { metaKey: boolean; ctrlKey: boolean; shiftKey: boolean }
    ) => {
      if (row.node.disabled) return;
      if (event.shiftKey && anchorRef.current) {
        const ids = rows.map((entry) => entry.node.id);
        const from = ids.indexOf(anchorRef.current);
        const to = ids.indexOf(row.node.id);
        if (from >= 0 && to >= 0) {
          const [start, end] = from < to ? [from, to] : [to, from];
          onSelect(
            rows
              .slice(start, end + 1)
              .filter((entry) => !entry.node.disabled)
              .map((entry) => entry.node.id),
            "range"
          );
          return;
        }
      }
      anchorRef.current = row.node.id;
      onSelect(
        [row.node.id],
        event.metaKey || event.ctrlKey ? "toggle" : "single"
      );
    },
    [rows, onSelect]
  );

  const focusRow = useCallback((id: string) => {
    setFocusedID(id);
    rowRefs.current.get(id)?.focus();
  }, []);

  const onKeyDown = useCallback(
    (event: KeyboardEvent, row: FlatRow, index: number) => {
      const enabled = rows.filter((entry) => !entry.node.disabled);
      const enabledIndex = enabled.findIndex(
        (entry) => entry.node.id === row.node.id
      );
      const move = (target: FlatRow | undefined) => {
        if (target) focusRow(target.node.id);
      };
      switch (event.key) {
        case "ArrowDown":
          move(enabled[enabledIndex + 1]);
          break;
        case "ArrowUp":
          move(enabled[enabledIndex - 1]);
          break;
        case "ArrowRight":
          if (row.hasChildren && !row.expanded) toggle(row.node.id, false);
          else if (row.hasChildren) move(rows[index + 1]);
          break;
        case "ArrowLeft":
          if (row.hasChildren && row.expanded) {
            toggle(row.node.id, true);
          } else {
            for (let i = index - 1; i >= 0; i--) {
              if (rows[i].depth < row.depth) {
                move(rows[i]);
                break;
              }
            }
          }
          break;
        case "Home":
          move(enabled[0]);
          break;
        case "End":
          move(enabled[enabled.length - 1]);
          break;
        case "Enter":
        case " ":
          if (event.key === "Enter" && selectedIDs.has(row.node.id)) {
            onActivate?.(row.node.id);
          } else {
            applySelect(row, event);
          }
          break;
        default:
          return;
      }
      event.preventDefault();
    },
    [rows, toggle, focusRow, applySelect, selectedIDs, onActivate]
  );

  if (rows.length === 0) {
    return (
      <div className="aui-tree" role="tree">
        <div className="aui-tree-empty">{emptyState ?? "empty"}</div>
      </div>
    );
  }

  return (
    <div className="aui-tree" role="tree">
      {rows.map((row, index) => {
        const { node } = row;
        const isSelected = selectedIDs.has(node.id);
        const classes = ["aui-tree-row"];
        if (isSelected) classes.push("aui-tree-row--selected");
        if (node.dimmed) classes.push("aui-tree-row--dimmed");
        return (
          <div
            key={node.id}
            role="treeitem"
            aria-selected={isSelected}
            aria-expanded={row.hasChildren ? row.expanded : undefined}
            aria-level={row.depth + 1}
          >
            <button
              type="button"
              ref={(el) => {
                if (el) rowRefs.current.set(node.id, el);
                else rowRefs.current.delete(node.id);
              }}
              className={classes.join(" ")}
              style={{ paddingLeft: 7 + row.depth * 16 }}
              disabled={node.disabled}
              tabIndex={
                focusedID === node.id || (focusedID === null && index === 0)
                  ? 0
                  : -1
              }
              onFocus={() => setFocusedID(node.id)}
              onClick={(event) => applySelect(row, event)}
              onDoubleClick={() => !node.disabled && onActivate?.(node.id)}
              onContextMenu={(event) => {
                if (!onContextMenu) return;
                event.preventDefault();
                onContextMenu(node.id, event.clientX, event.clientY);
              }}
              onKeyDown={(event) => onKeyDown(event, row, index)}
            >
              <span
                className="aui-tree-disclosure"
                onClick={(event) => {
                  if (!row.hasChildren) return;
                  event.stopPropagation();
                  toggle(node.id, row.expanded);
                }}
              >
                {row.hasChildren ? (row.expanded ? "▾" : "▸") : ""}
              </span>
              <span className="aui-tree-icon" aria-hidden>
                {node.icon ?? ""}
              </span>
              <span className="aui-tree-label">{node.label}</span>
              {node.badge ? (
                <span className="aui-tree-badge">{node.badge}</span>
              ) : (
                <span />
              )}
              {node.actions?.length ? (
                <span className="aui-tree-actions">
                  {node.actions.map((action) => (
                    <span
                      key={action.id}
                      role="button"
                      title={action.label}
                      aria-label={action.label}
                      className="aui-tree-action"
                      onClick={(event) => {
                        event.stopPropagation();
                        onAction?.(node.id, action.id);
                      }}
                    >
                      {action.icon}
                    </span>
                  ))}
                </span>
              ) : null}
            </button>
          </div>
        );
      })}
    </div>
  );
}
