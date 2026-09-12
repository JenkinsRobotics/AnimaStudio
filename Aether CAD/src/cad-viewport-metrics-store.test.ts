import { describe, expect, it, vi } from "vitest";
import { CADViewportMetricsStore, emptyViewportMetrics } from "./cad-viewport-metrics-store";

describe("viewport metrics store", () => {
  it("starts empty with unmeasurable figures null", () => {
    const store = new CADViewportMetricsStore();
    expect(store.snapshot()).toEqual(emptyViewportMetrics);
    expect(store.snapshot().fps).toBeNull();
    expect(store.snapshot().memoryMegabytes).toBeNull();
  });

  it("publishes patches and notifies only on change", () => {
    const store = new CADViewportMetricsStore();
    const listener = vi.fn();
    store.subscribe(listener);
    store.publish({ fps: 60, frameMilliseconds: 16.7 });
    expect(store.snapshot()).toMatchObject({ fps: 60, frameMilliseconds: 16.7, bodies: 0 });
    expect(listener).toHaveBeenCalledTimes(1);
    store.publish({ fps: 60, frameMilliseconds: 16.7 });
    expect(listener).toHaveBeenCalledTimes(1);
    store.publish({ bodies: 2, faces: 18, triangles: 4200, edgeSegments: 900 });
    expect(store.snapshot()).toMatchObject({ fps: 60, bodies: 2, faces: 18, triangles: 4200 });
    expect(listener).toHaveBeenCalledTimes(2);
  });
});
