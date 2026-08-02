import type { ReactNode } from "react";

export interface DocumentBarProps {
  /** Left cluster: home button, project name, save state, commands. */
  leading?: ReactNode;
  /** Centered on the window (usually workspace <Tabs>). */
  center?: ReactNode;
  /** Right cluster: engine status, layout preset button, window menus. */
  trailing?: ReactNode;
}

/** The 48px top app-window row (Swift `StudioDocumentBar`): leading and
 *  trailing clusters with the center slot truly window-centered. */
export function DocumentBar({ leading, center, trailing }: DocumentBarProps) {
  return (
    <div className="aui-document-bar">
      <div className="aui-document-bar-cluster">{leading}</div>
      {center ? <div className="aui-document-bar-center">{center}</div> : null}
      <div className="aui-document-bar-cluster aui-document-bar-cluster--trailing">
        {trailing}
      </div>
    </div>
  );
}
