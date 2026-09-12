/** Live viewport performance metrics published by the renderer.
 *  Measured only — values the browser cannot report stay null so the
 *  Performance panel can say so instead of inventing a number. */
export interface CADViewportMetrics {
  /** Rendered frames per second, averaged over the sampling window. */
  fps: number | null;
  /** Mean wall-clock milliseconds per rendered frame. */
  frameMilliseconds: number | null;
  /** Share of the frame interval spent inside render work (0–100). */
  frameBudgetPercent: number | null;
  /** JS heap in megabytes; Chromium-only (performance.memory). */
  memoryMegabytes: number | null;
  bodies: number;
  faces: number;
  edgeSegments: number;
  triangles: number;
  /** Milliseconds spent on the last geometry upload. */
  lastUploadMilliseconds: number | null;
  backend: string;
}

export const emptyViewportMetrics: CADViewportMetrics = Object.freeze({
  fps: null,
  frameMilliseconds: null,
  frameBudgetPercent: null,
  memoryMegabytes: null,
  bodies: 0,
  faces: 0,
  edgeSegments: 0,
  triangles: 0,
  lastUploadMilliseconds: null,
  backend: "—",
});

type Listener = () => void;

export class CADViewportMetricsStore {
  private current: CADViewportMetrics = emptyViewportMetrics;
  private listeners = new Set<Listener>();

  snapshot = (): CADViewportMetrics => this.current;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  publish(patch: Partial<CADViewportMetrics>): void {
    const next = { ...this.current, ...patch };
    if ((Object.keys(next) as (keyof CADViewportMetrics)[]).every((key) => next[key] === this.current[key]))
      return;
    this.current = Object.freeze(next);
    this.listeners.forEach((listener) => listener());
  }
}

export const cadViewportMetrics = new CADViewportMetricsStore();
