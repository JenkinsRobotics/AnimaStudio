import type { ReactNode } from "react";

export interface DialogProps {
  open: boolean;
  title: string;
  onClose: () => void;
  actions?: ReactNode;
  children: ReactNode;
}

/** Modal dialog with scrim; Escape or scrim click closes. */
export function Dialog({ open, title, onClose, actions, children }: DialogProps) {
  if (!open) return null;
  return (
    <div
      className="aui-dialog-scrim"
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
      onKeyDown={(event) => {
        if (event.key === "Escape") onClose();
      }}
    >
      <div className="aui-dialog" role="dialog" aria-label={title}>
        <div className="aui-dialog-title">
          <span>{title}</span>
          <button
            type="button"
            className="aui-icon-button"
            aria-label="Close"
            onClick={onClose}
          >
            ✕
          </button>
        </div>
        <div className="aui-dialog-body">{children}</div>
        {actions ? <div className="aui-dialog-actions">{actions}</div> : null}
      </div>
    </div>
  );
}
