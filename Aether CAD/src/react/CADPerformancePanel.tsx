import { useState, useSyncExternalStore } from "react";
import { Checkbox, FieldRow } from "@aether/ui";
import { cadPresentation } from "../cad-presentation-store";
import { cadViewportMetrics } from "../cad-viewport-metrics-store";

const KERNEL = "Open CASCADE (Replicad WASM)";

const number = (value: number | null, unit: string, digits = 1): string =>
  value === null ? "Unavailable" : `${value.toFixed(digits)} ${unit}`;

/** Runtime metrics, imported from the Anima Studio right rail's "Performance"
 *  panel. Every figure is measured in the renderer; anything the browser
 *  cannot report reads "Unavailable" rather than showing a fabricated value. */
export function CADPerformancePanel({ active }: { active: boolean }) {
  const metrics = useSyncExternalStore(
    cadViewportMetrics.subscribe,
    cadViewportMetrics.snapshot,
    cadViewportMetrics.snapshot,
  );
  const presentation = useSyncExternalStore(
    cadPresentation.subscribe,
    cadPresentation.snapshot,
    cadPresentation.snapshot,
  );
  const [showOverlay, setShowOverlay] = useState(() => {
    try {
      return localStorage.getItem("aether-cad.metrics-overlay") === "on";
    } catch {
      return false;
    }
  });
  const toggleOverlay = (next: boolean) => {
    setShowOverlay(next);
    try {
      localStorage.setItem("aether-cad.metrics-overlay", next ? "on" : "off");
    } catch {
      /* session-only preference */
    }
    window.dispatchEvent(new CustomEvent("aether-cad-metrics-overlay", { detail: next }));
  };
  return (
    <section className={`browser-panel${active ? " active" : ""}`} data-panel="performance">
      <header className="browser-title">
        <div>
          <strong>Performance</strong>
          <small>Live renderer metrics · this session</small>
        </div>
        <span>{metrics.fps === null ? "—" : `${metrics.fps.toFixed(0)} fps`}</span>
      </header>
      <div className="visualization-panel-scroll">
        <section className="visualization-controls" aria-label="Viewport HUD">
          <div className="panel-heading"><span>VIEWPORT HUD</span></div>
          <div className="visualization-fields">
            <Checkbox
              checked={showOverlay}
              onChange={(event) => toggleOverlay(event.target.checked)}
              label="Show detailed CAD metrics"
              description="Pins a metrics card over the viewport with renderer, frame, memory, and geometry figures."
            />
          </div>
        </section>
        <section className="visualization-controls" aria-label="Live status">
          <div className="panel-heading"><span>LIVE STATUS</span></div>
          <div className="visualization-fields">
            <FieldRow label="Renderer FPS"><output>{number(metrics.fps, "fps")}</output></FieldRow>
            <FieldRow label="Frame time"><output>{number(metrics.frameMilliseconds, "ms", 2)}</output></FieldRow>
            <FieldRow label="Render budget"><output>{number(metrics.frameBudgetPercent, "%")}</output></FieldRow>
            <FieldRow label="JS heap"><output>{number(metrics.memoryMegabytes, "MB")}</output></FieldRow>
            <FieldRow label="Renderer"><output>{metrics.backend}</output></FieldRow>
            <FieldRow label="Geometry kernel"><output>{KERNEL}</output></FieldRow>
          </div>
        </section>
        <section className="visualization-controls" aria-label="Geometry">
          <div className="panel-heading"><span>GEOMETRY</span></div>
          <div className="visualization-fields">
            <FieldRow label="Document"><output>{presentation.documentName}</output></FieldRow>
            <FieldRow label="Bodies"><output>{metrics.bodies}</output></FieldRow>
            <FieldRow label="Faces"><output>{metrics.faces.toLocaleString()}</output></FieldRow>
            <FieldRow label="Edge segments"><output>{metrics.edgeSegments.toLocaleString()}</output></FieldRow>
            <FieldRow label="Triangles"><output>{metrics.triangles.toLocaleString()}</output></FieldRow>
            <FieldRow label="Last upload"><output>{number(metrics.lastUploadMilliseconds, "ms")}</output></FieldRow>
            <p className="cad-form-note">
              Frame figures are measured in the render loop; JS heap is reported by Chromium only.
              Process CPU and GPU timings are not exposed to web applications.
            </p>
          </div>
        </section>
      </div>
    </section>
  );
}

/** The viewport metrics card (Anima's detailed CAD metrics overlay). */
export function CADMetricsOverlay() {
  const metrics = useSyncExternalStore(
    cadViewportMetrics.subscribe,
    cadViewportMetrics.snapshot,
    cadViewportMetrics.snapshot,
  );
  const [visible, setVisible] = useState(() => {
    try {
      return localStorage.getItem("aether-cad.metrics-overlay") === "on";
    } catch {
      return false;
    }
  });
  useSyncExternalStore(
    (listener) => {
      const follow = (event: Event) => {
        setVisible(Boolean((event as CustomEvent).detail));
        listener();
      };
      window.addEventListener("aether-cad-metrics-overlay", follow);
      return () => window.removeEventListener("aether-cad-metrics-overlay", follow);
    },
    () => visible,
    () => visible,
  );
  if (!visible) return null;
  const rows: readonly [string, string][] = [
    ["PIPELINE", `Open CASCADE → ${metrics.backend}`],
    ["FPS", number(metrics.fps, "")],
    ["FRAME", number(metrics.frameMilliseconds, "ms", 2)],
    ["BUDGET", number(metrics.frameBudgetPercent, "%")],
    ["MEMORY", number(metrics.memoryMegabytes, "MB")],
    ["BODIES", String(metrics.bodies)],
    ["FACES", metrics.faces.toLocaleString()],
    ["EDGES", metrics.edgeSegments.toLocaleString()],
    ["TRIS", metrics.triangles.toLocaleString()],
    ["UPLOAD", number(metrics.lastUploadMilliseconds, "ms")],
  ];
  return (
    <aside className="cad-metrics-overlay" aria-label="Viewport metrics">
      {rows.map(([label, value]) => (
        <div key={label}>
          <span>{label}</span>
          <strong>{value}</strong>
        </div>
      ))}
    </aside>
  );
}
