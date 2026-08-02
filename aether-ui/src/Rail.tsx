import type { ReactNode } from "react";

/** The vertical icon rail beside a sidebar. */
export function Rail({ children }: { children: ReactNode }) {
  return <div className="aui-rail">{children}</div>;
}

export interface RailButtonProps {
  label: string;
  active?: boolean;
  onClick?: () => void;
  children: ReactNode;
}

export function RailButton({ label, active, onClick, children }: RailButtonProps) {
  const classes = ["aui-rail-button"];
  if (active) classes.push("aui-rail-button--active");
  return (
    <button
      type="button"
      className={classes.join(" ")}
      title={label}
      aria-label={label}
      aria-pressed={active ?? false}
      onClick={onClick}
    >
      {children}
    </button>
  );
}
