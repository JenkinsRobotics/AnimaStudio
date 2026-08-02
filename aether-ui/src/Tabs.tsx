export interface TabsProps {
  tabs: readonly { id: string; label: string }[];
  activeID: string;
  onSelect: (id: string) => void;
}

/** Underlined tab strip (workspaces, documents). */
export function Tabs({ tabs, activeID, onSelect }: TabsProps) {
  return (
    <div className="aui-tabs" role="tablist">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          type="button"
          role="tab"
          aria-selected={tab.id === activeID}
          className={
            tab.id === activeID ? "aui-tab aui-tab--active" : "aui-tab"
          }
          onClick={() => onSelect(tab.id)}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
