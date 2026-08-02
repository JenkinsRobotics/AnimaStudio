import { useState } from "react";
import type { ReactNode } from "react";

/** Product-free tree node: the app supplies data and interprets IDs. */
export interface TreeNode {
  id: string;
  label: string;
  icon?: ReactNode;
  badge?: string;
  children?: readonly TreeNode[];
}

export interface TreeProps {
  nodes: readonly TreeNode[];
  selectedIDs: ReadonlySet<string>;
  onSelect: (id: string, extend: boolean) => void;
  /** Uncontrolled expansion default: everything expanded. */
  defaultCollapsedIDs?: readonly string[];
}

/** Selectable disclosure tree (feature trees, instances, assets). */
export function Tree({ nodes, selectedIDs, onSelect, defaultCollapsedIDs }: TreeProps) {
  const [collapsed, setCollapsed] = useState<ReadonlySet<string>>(
    () => new Set(defaultCollapsedIDs ?? [])
  );
  const toggle = (id: string) => {
    setCollapsed((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };
  return (
    <div className="aui-tree" role="tree">
      <TreeLevel
        nodes={nodes}
        selectedIDs={selectedIDs}
        collapsed={collapsed}
        onSelect={onSelect}
        onToggle={toggle}
      />
    </div>
  );
}

function TreeLevel({
  nodes,
  selectedIDs,
  collapsed,
  onSelect,
  onToggle,
}: {
  nodes: readonly TreeNode[];
  selectedIDs: ReadonlySet<string>;
  collapsed: ReadonlySet<string>;
  onSelect: (id: string, extend: boolean) => void;
  onToggle: (id: string) => void;
}) {
  return (
    <>
      {nodes.map((node) => {
        const hasChildren = (node.children?.length ?? 0) > 0;
        const isCollapsed = collapsed.has(node.id);
        const isSelected = selectedIDs.has(node.id);
        return (
          <div key={node.id} role="treeitem" aria-selected={isSelected}>
            <button
              type="button"
              className={
                isSelected
                  ? "aui-tree-row aui-tree-row--selected"
                  : "aui-tree-row"
              }
              onClick={(event) =>
                onSelect(node.id, event.shiftKey || event.metaKey)
              }
            >
              <span
                className="aui-tree-disclosure"
                onClick={(event) => {
                  if (!hasChildren) return;
                  event.stopPropagation();
                  onToggle(node.id);
                }}
              >
                {hasChildren ? (isCollapsed ? "▸" : "▾") : ""}
              </span>
              <span className="aui-tree-icon" aria-hidden>
                {node.icon ?? ""}
              </span>
              <span>{node.label}</span>
              {node.badge ? (
                <span className="aui-tree-badge">{node.badge}</span>
              ) : (
                <span />
              )}
            </button>
            {hasChildren && !isCollapsed ? (
              <div className="aui-tree-children" role="group">
                <TreeLevel
                  nodes={node.children!}
                  selectedIDs={selectedIDs}
                  collapsed={collapsed}
                  onSelect={onSelect}
                  onToggle={onToggle}
                />
              </div>
            ) : null}
          </div>
        );
      })}
    </>
  );
}
