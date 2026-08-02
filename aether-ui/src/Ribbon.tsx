import type { ReactNode } from "react";

/** The horizontal tool ribbon strip (groups with captions). */
export function Ribbon({ children }: { children: ReactNode }) {
  return <div className="aui-ribbon">{children}</div>;
}

export function RibbonGroup({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="aui-ribbon-group">
      <div className="aui-ribbon-group-buttons">{children}</div>
      <div className="aui-ribbon-group-label">{label}</div>
    </div>
  );
}

export interface RibbonToolProps {
  icon: ReactNode;
  label: string;
  active?: boolean;
  disabled?: boolean;
  onClick?: () => void;
}

/** Icon-over-label ribbon tool button. */
export function RibbonTool({ icon, label, active, disabled, onClick }: RibbonToolProps) {
  const classes = ["aui-ribbon-tool"];
  if (active) classes.push("aui-ribbon-tool--active");
  return (
    <button
      type="button"
      className={classes.join(" ")}
      disabled={disabled}
      onClick={onClick}
    >
      <span className="aui-ribbon-tool-icon" aria-hidden>
        {icon}
      </span>
      {label}
    </button>
  );
}
