import { describe, expect, it, vi } from "vitest";
import { cadCommandIDs, CADCommandRegistry, isCADCommandID } from "./cad-command-registry";

describe("CADCommandRegistry", () => {
  it("publishes one unique catalog including standard views and display styles", () => {
    expect(cadCommandIDs).toHaveLength(123);
    expect(isCADCommandID("sketch-text")).toBe(true);
    expect(isCADCommandID("sketch-elliptical-arc")).toBe(true);
    expect(isCADCommandID("sketch-constraint-ellipse-locus")).toBe(true);
    expect(new Set(cadCommandIDs).size).toBe(cadCommandIDs.length);
    expect(isCADCommandID("sketch-insert-spline-point")).toBe(true);
    expect(isCADCommandID("view-isometric")).toBe(true);
    expect(isCADCommandID("view-back")).toBe(true);
    expect(isCADCommandID("view-left")).toBe(true);
    expect(isCADCommandID("view-bottom")).toBe(true);
    expect(isCADCommandID("display-hidden-line")).toBe(true);
    expect(isCADCommandID("lighting-daylight")).toBe(true);
    expect(isCADCommandID("background-midnight")).toBe(true);
    expect(isCADCommandID("finish-gloss")).toBe(true);
    expect(isCADCommandID("ground-both")).toBe(true);
    expect(isCADCommandID("toggle-feature-edges")).toBe(true);
    expect(isCADCommandID("reset-appearance")).toBe(true);
    expect(isCADCommandID("assembly-insert-component")).toBe(true);
    expect(isCADCommandID("assembly-add-connector")).toBe(true);
    expect(isCADCommandID("assembly-create-mate")).toBe(true);
    expect(isCADCommandID("assembly-set-mate-dof-value")).toBe(true);
    expect(isCADCommandID("assembly-edit-mate-dof-limits")).toBe(true);
    expect(isCADCommandID("assembly-create-relation")).toBe(true);
    expect(isCADCommandID("assembly-toggle-mate-suppressed")).toBe(true);
    expect(isCADCommandID("assembly-remove-mate")).toBe(true);
    expect(isCADCommandID("assembly-toggle-grounded")).toBe(true);
    expect(isCADCommandID("assembly-toggle-suppressed")).toBe(true);
    expect(isCADCommandID("assembly-remove-instance")).toBe(true);
    expect(isCADCommandID("selection-vertex")).toBe(true);
    expect(isCADCommandID("not-a-command")).toBe(false);
  });

  it("registers and executes one typed command handler", () => {
    const registry = new CADCommandRegistry();
    const handler = vi.fn();
    const release = registry.register("fit-view", handler);
    expect(registry.snapshot()["fit-view"].registered).toBe(true);
    expect(registry.execute("fit-view")).toBe(true);
    expect(handler).toHaveBeenCalledOnce();
    release();
    expect(registry.execute("fit-view")).toBe(false);
  });

  it("blocks disabled commands and publishes immutable snapshots", () => {
    const registry = new CADCommandRegistry();
    const listener = vi.fn();
    registry.subscribe(listener);
    const handler = vi.fn();
    registry.register("connector", handler);
    const before = registry.snapshot();
    registry.setEnabled("connector", false);
    const after = registry.snapshot();
    expect(after).not.toBe(before);
    expect(after.connector.enabled).toBe(false);
    expect(registry.execute("connector")).toBe(false);
    expect(handler).not.toHaveBeenCalled();
    expect(listener).toHaveBeenCalledTimes(2);
  });

  it("tracks active state independently from availability", () => {
    const registry = new CADCommandRegistry();
    registry.setActive("fastened", true);
    registry.setEnabled("fastened", false);
    expect(registry.snapshot().fastened).toEqual({
      active: true,
      enabled: false,
      registered: false,
    });
  });
});
