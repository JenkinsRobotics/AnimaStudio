import { useRef, useState } from "react";
import type { ReactElement } from "react";
import type { ListBoxItem } from "@aether/ui";
import { cadWorkspace } from "../cad-workspace-store";

/** Fusion-style feature history: a left-to-right icons-only strip with
 * rollback playback controls and a draggable rollback marker. */
export function CADHistoryTimeline({ items, rollbackIndex }: {
  items: readonly ListBoxItem[];
  rollbackIndex: number;
}) {
  const features = items.filter((item) => item.id.startsWith("history/feature/"));
  const stripRef = useRef<HTMLDivElement>(null);
  const [dragIndex, setDragIndex] = useState<number | null>(null);
  const markerIndex = Math.max(0, Math.min(dragIndex ?? rollbackIndex, features.length));
  const step = (actionID: "rollback-start" | "rollback-back" | "rollback-forward" | "rollback-end") =>
    cadWorkspace.dispatch({ type: "item-action", id: "rollback-bar", actionID });
  const indexFromClientX = (clientX: number): number => {
    const strip = stripRef.current;
    if (!strip) return markerIndex;
    const chips = [...strip.querySelectorAll<HTMLElement>("[data-history-index]")];
    for (let i = 0; i < chips.length; i++) {
      const rect = chips[i].getBoundingClientRect();
      if (clientX < rect.left + rect.width / 2) return i;
    }
    return chips.length;
  };
  if (!features.length) {
    return <p className="cad-history-empty">Create or import geometry to build history.</p>;
  }
  const marker = (
    <button
      key="rollback-marker"
      type="button"
      className="cad-history-marker"
      aria-label={`Rollback position ${markerIndex} of ${features.length} — drag or use arrow keys`}
      title="Rollback — drag along the timeline"
      onKeyDown={(event) => {
        if (event.key === "ArrowLeft") { event.preventDefault(); step("rollback-back"); }
        if (event.key === "ArrowRight") { event.preventDefault(); step("rollback-forward"); }
      }}
      onPointerDown={(event) => {
        event.currentTarget.setPointerCapture(event.pointerId);
        setDragIndex(indexFromClientX(event.clientX));
      }}
      onPointerMove={(event) => {
        if (dragIndex !== null) setDragIndex(indexFromClientX(event.clientX));
      }}
      onPointerUp={() => {
        if (dragIndex !== null) {
          cadWorkspace.dispatch({ type: "rollback-to", index: dragIndex });
          setDragIndex(null);
        }
      }}
    />
  );
  const slots: ReactElement[] = [];
  features.forEach((item, index) => {
    if (index === markerIndex) slots.push(marker);
    const dimmed = index >= markerIndex || item.description === "Suppressed";
    slots.push(
      <button
        key={item.id}
        type="button"
        data-history-index={index}
        className={`cad-history-chip${dimmed ? " cad-history-chip--dimmed" : ""}`}
        title={`${item.label}${item.description ? ` — ${item.description}` : ""}`}
        aria-label={item.label}
        onClick={() => cadWorkspace.dispatch({ type: "activate-history", id: item.id })}
      >
        {item.icon}
      </button>,
    );
  });
  if (markerIndex >= features.length) slots.push(marker);
  return (
    <div className="cad-history-timeline" aria-label="Feature history timeline">
      <div className="cad-history-controls">
        <button type="button" aria-label="Roll back to start" title="Roll back to start" disabled={markerIndex === 0} onClick={() => step("rollback-start")}>⏮</button>
        <button type="button" aria-label="Roll back one feature" title="Roll back one feature" disabled={markerIndex === 0} onClick={() => step("rollback-back")}>◀</button>
        <button type="button" aria-label="Roll forward one feature" title="Roll forward one feature" disabled={markerIndex >= features.length} onClick={() => step("rollback-forward")}>▶</button>
        <button type="button" aria-label="Roll forward to end" title="Roll forward to end" disabled={markerIndex >= features.length} onClick={() => step("rollback-end")}>⏭</button>
      </div>
      <div ref={stripRef} className="cad-history-strip">{slots}</div>
    </div>
  );
}
