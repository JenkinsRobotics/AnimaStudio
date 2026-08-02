import { useRef } from "react";
import type { KeyboardEvent } from "react";

export interface TabsProps {
  tabs: readonly { id: string; label: string }[];
  activeID: string;
  onSelect: (id: string) => void;
}

/** Underlined tab strip (workspaces, documents). Keyboard: ←/→ move and
 *  select (selection follows focus), Home/End jump; roving tabindex. */
export function Tabs({ tabs, activeID, onSelect }: TabsProps) {
  const refs = useRef(new Map<string, HTMLButtonElement>());

  const onKeyDown = (event: KeyboardEvent, index: number) => {
    let next: number;
    switch (event.key) {
      case "ArrowRight":
        next = (index + 1) % tabs.length;
        break;
      case "ArrowLeft":
        next = (index - 1 + tabs.length) % tabs.length;
        break;
      case "Home":
        next = 0;
        break;
      case "End":
        next = tabs.length - 1;
        break;
      default:
        return;
    }
    event.preventDefault();
    const id = tabs[next].id;
    onSelect(id);
    refs.current.get(id)?.focus();
  };

  return (
    <div className="aui-tabs" role="tablist">
      {tabs.map((tab, index) => (
        <button
          key={tab.id}
          type="button"
          role="tab"
          aria-selected={tab.id === activeID}
          tabIndex={tab.id === activeID ? 0 : -1}
          ref={(el) => {
            if (el) refs.current.set(tab.id, el);
            else refs.current.delete(tab.id);
          }}
          className={
            tab.id === activeID ? "aui-tab aui-tab--active" : "aui-tab"
          }
          onClick={() => onSelect(tab.id)}
          onKeyDown={(event) => onKeyDown(event, index)}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
