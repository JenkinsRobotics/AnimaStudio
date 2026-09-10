import { describe, expect, it, vi } from "vitest";
import {
  CADAppearanceStore,
  defaultCADAppearance,
  reduceCADAppearance,
} from "./cad-appearance-store";

describe("CADAppearanceStore", () => {
  it("reduces renderer-only appearance settings and clamps light intensity", () => {
    const midnight = reduceCADAppearance(defaultCADAppearance, {
      type: "set-background",
      background: "midnight",
    });
    expect(midnight.background).toBe("midnight");
    expect(reduceCADAppearance(midnight, {
      type: "set-display-style",
      style: "wireframe",
    }).displayStyle).toBe("wireframe");
    expect(reduceCADAppearance(midnight, {
      type: "set-lighting-preset",
      preset: "daylight",
    }).lightingPreset).toBe("daylight");
    expect(reduceCADAppearance(midnight, {
      type: "set-floor-mode",
      mode: "both",
    }).floorMode).toBe("both");
    expect(reduceCADAppearance(midnight, {
      type: "set-environment-percent",
      percent: 240,
    }).environmentPercent).toBe(200);
    expect(reduceCADAppearance(midnight, { type: "reset" })).toBe(defaultCADAppearance);
  });

  it("publishes one snapshot to React and the renderer adapter", () => {
    const store = new CADAppearanceStore();
    const listener = vi.fn();
    const apply = vi.fn();
    store.subscribe(listener);
    store.registerApplyHandler(apply);
    store.dispatch({ type: "set-contact-shadows-visible", visible: false });
    expect(store.snapshot().contactShadowsVisible).toBe(false);
    expect(listener).toHaveBeenCalledOnce();
    expect(apply).toHaveBeenLastCalledWith(store.snapshot());
    expect(apply).toHaveBeenCalledTimes(2);
  });
});
