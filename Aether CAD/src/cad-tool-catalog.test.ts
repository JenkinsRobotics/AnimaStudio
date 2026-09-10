import { describe, expect, it } from "vitest";
import { cadRibbonWorkspace, cadRibbonWorkspaces } from "./cad-tool-catalog";

describe("CAD tool catalog", () => {
  it("owns the complete traditional workspace structure", () => {
    expect(cadRibbonWorkspaces.map(({ id }) => id)).toEqual([
      "home",
      "sketch",
      "solid",
      "assembly",
      "view",
      "manage",
      "output",
    ]);
    expect(cadRibbonWorkspace("assembly").label).toBe("Assembly");
  });

  it("keeps every tool unique and either actionable or honestly gated", () => {
    const tools = cadRibbonWorkspaces.flatMap((workspace) =>
      workspace.groups.flatMap((group) => group.tools),
    );
    expect(tools).toHaveLength(217);
    expect(new Set(tools.map(({ id }) => id)).size).toBe(tools.length);
    for (const definition of tools) {
      expect(Boolean(definition.action) || Boolean(definition.unavailableReason)).toBe(true);
      if (!definition.action) expect(definition.unavailableReason?.length).toBeGreaterThan(20);
    }
  });

  it("covers the core modeling, assembly, inspection, and output families", () => {
    const ids = new Set(cadRibbonWorkspaces.flatMap((workspace) =>
      workspace.groups.flatMap((group) => group.tools.map(({ id }) => id)),
    ));
    for (const id of [
      "sketch-spline",
      "solid-hole",
      "solid-loft",
      "solid-pattern",
      "assembly-revolute",
      "assembly-slider",
      "assembly-gear",
      "assembly-interference",
      "assembly-ground",
      "assembly-suppress",
      "assembly-remove",
      "view-wireframe",
      "manage-configurations",
      "output-step",
      "output-dxf",
      "output-cut-list",
    ]) expect(ids.has(id)).toBe(true);
    expect(cadRibbonWorkspace("view").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "view-hidden-line")?.action).toBe("display-hidden-line");
    expect(cadRibbonWorkspace("view").groups.flatMap((group) => group.tools)
      .filter(({ id }) => ["view-front", "view-back", "view-left", "view-right", "view-top", "view-bottom"].includes(id))
      .every(({ action }) => Boolean(action))).toBe(true);
    expect(cadRibbonWorkspace("view").groups.flatMap((group) => group.tools)
      .filter(({ id }) => id.startsWith("view-ground-") || id.startsWith("view-background-") || id.startsWith("view-finish-") || id === "view-feature-edges" || id === "view-reset-appearance")
      .every(({ action }) => Boolean(action))).toBe(true);
    expect(cadRibbonWorkspace("assembly").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "assembly-insert")?.action).toBe("assembly-insert-component");
    expect(cadRibbonWorkspace("assembly").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "assembly-connector")?.action).toBe("assembly-add-connector");
    expect(cadRibbonWorkspace("assembly").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "assembly-fixed")?.action).toBe("assembly-create-mate");
    expect(cadRibbonWorkspace("assembly").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "assembly-mate-suppress")?.action).toBe("assembly-toggle-mate-suppressed");
    expect(cadRibbonWorkspace("assembly").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "assembly-mate-dof-value")?.action).toBe("assembly-set-mate-dof-value");
    expect(cadRibbonWorkspace("assembly").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "assembly-mate-dof-limits")?.action).toBe("assembly-edit-mate-dof-limits");
    expect(cadRibbonWorkspace("assembly").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "assembly-relation-create")?.action).toBe("assembly-create-relation");
    expect(cadRibbonWorkspace("assembly").groups.flatMap((group) => group.tools)
      .find(({ id }) => id === "assembly-mate-remove")?.action).toBe("assembly-remove-mate");
  });
});

it("exposes spline point insertion in the spline dropdown", () => {
  const spline = cadRibbonWorkspace("sketch").groups.flatMap(g => g.tools).find(t => t.id === "sketch-spline");
  expect(spline?.variants?.some(v => v.action === "sketch-insert-spline-point" && v.label === "Insert spline point")).toBe(true);
});
