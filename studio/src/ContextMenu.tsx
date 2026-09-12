import { useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";

export interface ContextMenuItem {
  id: string;
  label: string;
  icon?: ReactNode;
  disabled?: boolean;
  children?: ContextMenuItem[];
}

/** OneDrive-style right-click menu with one optional submenu level.
 *  Dismisses on outside click or Escape. */
export function ContextMenu({
  x,
  y,
  items,
  onPick,
  onClose,
}: {
  x: number;
  y: number;
  items: ContextMenuItem[];
  onPick: (id: string) => void;
  onClose: () => void;
}) {
  const root = useRef<HTMLDivElement>(null);
  const [submenu, setSubmenu] = useState<string | null>(null);
  useEffect(() => {
    const dismiss = (event: MouseEvent) => {
      if (!root.current?.contains(event.target as Node)) onClose();
    };
    const key = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("pointerdown", dismiss);
    window.addEventListener("keydown", key);
    return () => {
      window.removeEventListener("pointerdown", dismiss);
      window.removeEventListener("keydown", key);
    };
  }, [onClose]);
  return (
    <div
      ref={root}
      className="library-context-menu"
      role="menu"
      style={{ left: x, top: y }}
      onContextMenu={(event) => event.preventDefault()}
    >
      {items.map((item) => (
        <div
          key={item.id}
          className="library-context-item"
          onPointerEnter={() => setSubmenu(item.children ? item.id : null)}
        >
          <button
            type="button"
            role="menuitem"
            disabled={item.disabled}
            aria-haspopup={item.children ? "menu" : undefined}
            onClick={() => {
              if (item.children) setSubmenu(item.id);
              else onPick(item.id);
            }}
          >
            {item.icon}
            <span>{item.label}</span>
            {item.children ? <span className="library-context-caret">›</span> : null}
          </button>
          {item.children && submenu === item.id ? (
            <div className="library-context-submenu" role="menu">
              {item.children.map((child) => (
                <button
                  key={child.id}
                  type="button"
                  role="menuitem"
                  disabled={child.disabled}
                  onClick={() => onPick(child.id)}
                >
                  {child.icon}
                  <span>{child.label}</span>
                </button>
              ))}
            </div>
          ) : null}
        </div>
      ))}
    </div>
  );
}
