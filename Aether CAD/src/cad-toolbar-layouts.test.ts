import { describe, expect, it } from "vitest";
import { fusionTabsFor, sketchContextTab, toolbarTabsFor, toolbarToolById, toolbarWorkspaceFor } from "./cad-toolbar-layouts";
import { cadRibbonWorkspaces } from "./cad-tool-catalog";
import { sketchConstraintCatalog, sketchDimensionKinds } from "./sketch/constraint-catalog";

describe("per-document-type toolbar layouts", () => {
  it("project preserves the complete legacy ribbon", () => {
    expect(toolbarTabsFor("project").map((w) => w.id)).toEqual(
      cadRibbonWorkspaces.map((w) => w.id),
    );
    const home = toolbarWorkspaceFor("project", "home");
    expect(home).toEqual(cadRibbonWorkspaces.find((w) => w.id === "home"));
  });

  it("part drops the assembly tab and assembly-scoped home tools", () => {
    const tabs = toolbarTabsFor("part").map((w) => w.id);
    expect(tabs).toEqual(["home", "sketch", "solid", "view", "manage", "output"]);
    const home = toolbarWorkspaceFor("part", "home");
    const toolIDs = home.groups.flatMap((group) => group.tools.map((tool) => tool.id));
    expect(toolIDs).not.toContain("home-new-assembly");
    expect(toolIDs).not.toContain("home-select-component");
    expect(toolIDs).toContain("home-new-part");
    expect(toolIDs).toContain("home-sketch");
  });

  it("an excluded tab falls back to the layout's first tab", () => {
    expect(toolbarWorkspaceFor("part", "assembly").id).toBe("home");
  });

  it("assembly and drawing keep the full arrangement for now", () => {
    for (const type of ["assembly", "drawing"] as const)
      expect(toolbarTabsFor(type).map((w) => w.id)).toEqual(
        cadRibbonWorkspaces.map((w) => w.id),
      );
  });
});

describe("fusion part layout", () => {
  it("every referenced tool id resolves in the shared catalog", () => {
    for (const tab of fusionTabsFor("part") ?? [])
      for (const section of tab.sections)
        for (const id of section.menu)
          expect(toolbarToolById(id), `${tab.id}/${section.id}/${id}`).toBeDefined();
  });

  it("mirrors Fusion's tab order for parts and keeps other types legacy", () => {
    expect((fusionTabsFor("part") ?? []).map((tab) => tab.label)).toEqual([
      "Solid", "Surface", "Mesh", "Sheet Metal", "Plastic", "Manage", "Utilities",
    ]);
    expect(fusionTabsFor("project")).toBeNull();
    expect(fusionTabsFor("assembly")).toBeNull();
  });

  it("section dropdowns contain the visible tools plus overflow", () => {
    const solid = (fusionTabsFor("part") ?? [])[0];
    const create = solid.sections[0];
    for (const id of create.visible) expect(create.menu).toContain(id);
    expect(create.menu.length).toBeGreaterThan(create.visible.length);
  });

  it("the contextual sketch tab exposes the catalog sketch tools", () => {
    const tab = sketchContextTab();
    expect(tab.sections.length).toBeGreaterThan(0);
    const ids = tab.sections.flatMap((section) => section.menu);
    expect(ids.length).toBeGreaterThan(5);
    for (const id of ids) expect(toolbarToolById(id)).toBeDefined();
  });
});

// Collapsing Constrain to one ribbon button must not hide the relationships in
// the contextual Sketch tab, which renders sections as buttons + a menu and
// does not descend into variants on its own.
describe("contextual Sketch tab", () => {
  const sectionById = (id: string) =>
    sketchContextTab().sections.find((section) => section.id === id)!;
  const constrain = sectionById("sketch-context-sketch-constraints");
  const dimension = sectionById("sketch-context-sketch-dimensions");

  it("shows a single icon per section, each with its own dropdown", () => {
    expect(constrain.visible).toEqual(["sketch-constrain"]);
    expect(dimension.visible).toEqual(["sketch-dimension"]);
  });

  it("keeps relationships and dimensions in separate menus", () => {
    for (const entry of sketchConstraintCatalog.slice(1))
      expect(constrain.menu, `${entry.label} missing from Constrain`).toContain(
        `sketch-constraint-${entry.kind}`,
      );
    for (const kind of sketchDimensionKinds.slice(1))
      expect(dimension.menu, `${kind} missing from Dimension`).toContain(
        `sketch-constraint-${kind}`,
      );
    // A dimension must not appear in the Constrain menu, or the split is
    // cosmetic only.
    expect(constrain.menu).not.toContain("sketch-constraint-radius");
    expect(dimension.menu).not.toContain("sketch-constraint-parallel");
  });

  it("resolves every menu entry to a real, runnable tool", () => {
    for (const id of [...constrain.menu, ...dimension.menu]) {
      const definition = toolbarToolById(id);
      expect(definition, `${id} does not resolve`).toBeTruthy();
      expect(definition!.action, `${id} has no command`).toBeTruthy();
    }
  });
});
