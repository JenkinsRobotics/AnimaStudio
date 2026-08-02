import type { ReactNode } from "react";

export type StatusKind = "ok" | "busy" | "warn" | "error";

export function StatusDot({ kind }: { kind: StatusKind }) {
  const classes = ["aui-status-dot"];
  if (kind === "ok") classes.push("aui-status-dot--ok");
  if (kind === "error") classes.push("aui-status-dot--error");
  if (kind === "busy") classes.push("aui-status-dot--busy");
  return <span className={classes.join(" ")} aria-hidden />;
}

/** Bottom application status strip. */
export function StatusBar({ children }: { children: ReactNode }) {
  return <div className="aui-status-bar">{children}</div>;
}
