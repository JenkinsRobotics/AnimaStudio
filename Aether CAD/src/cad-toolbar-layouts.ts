import {
  cadRibbonWorkspaces,
  type CADRibbonWorkspaceDefinition,
  type CADRibbonWorkspaceID,
  type CADToolDefinition,
} from "./cad-tool-catalog";

/** Ribbon layouts per open document type. "project" preserves the complete
 * legacy arrangement; the other types refine it. Layouts only select and
 * filter the shared catalog — tool meaning and grouping stay in
 * cad-tool-catalog so there is exactly one definition of every tool. */
export type CADDocumentType = "part" | "assembly" | "drawing" | "project";

interface CADToolbarLayout {
  tabs: readonly CADRibbonWorkspaceID[];
  excludeTools?: readonly string[];
}

const ALL_TABS: readonly CADRibbonWorkspaceID[] = cadRibbonWorkspaces.map(
  (workspace) => workspace.id,
);

const LAYOUTS: Record<CADDocumentType, CADToolbarLayout> = {
  project: { tabs: ALL_TABS },
  part: {
    tabs: ["home", "sketch", "solid", "view", "manage", "output"],
    // Assembly authoring does not belong in a Part document's toolbar.
    excludeTools: ["home-new-assembly", "home-select-component"],
  },
  // Assembly and Drawing keep the full arrangement until their own
  // refinement passes.
  assembly: { tabs: ALL_TABS },
  drawing: { tabs: ALL_TABS },
};

export function toolbarTabsFor(
  type: CADDocumentType,
): readonly CADRibbonWorkspaceDefinition[] {
  return LAYOUTS[type].tabs
    .map((id) => cadRibbonWorkspaces.find((workspace) => workspace.id === id))
    .filter((workspace): workspace is CADRibbonWorkspaceDefinition => Boolean(workspace));
}

/** Resolve the workspace to render: unknown or excluded tabs fall back to the
 * layout's first tab; excluded tools are filtered and emptied groups drop. */
export function toolbarWorkspaceFor(
  type: CADDocumentType,
  id: CADRibbonWorkspaceID,
): CADRibbonWorkspaceDefinition {
  const layout = LAYOUTS[type];
  const tabs = toolbarTabsFor(type);
  const workspace = tabs.find((entry) => entry.id === id) ?? tabs[0];
  if (!layout.excludeTools?.length) return workspace;
  const excluded = new Set(layout.excludeTools);
  return {
    ...workspace,
    groups: workspace.groups
      .map((group) => ({
        ...group,
        tools: group.tools.filter((tool) => !excluded.has(tool.id)),
      }))
      .filter((group) => group.tools.length > 0),
  };
}

/* ------------------------------------------------------------------ */
/* Fusion-style layouts: tabs of sections, each with prominent tools   */
/* plus the full list in the section's dropdown. Tool ids reference    */
/* the shared catalog — the single definition of every tool.           */

export interface CADToolbarSection {
  id: string;
  label: string;
  /** Tool ids shown as large icons. */
  visible: readonly string[];
  /** Tool ids in the section dropdown (the complete section list). */
  menu: readonly string[];
}

export interface CADToolbarTab {
  id: string;
  label: string;
  sections: readonly CADToolbarSection[];
}

/** Includes variants: a tool inside a dropdown is still a tool the toolbar can
 *  be asked to render or run, and looking it up must not come back empty. */
const TOOL_INDEX: ReadonlyMap<string, CADToolDefinition> = new Map(
  cadRibbonWorkspaces.flatMap((workspace) =>
    workspace.groups.flatMap((group) =>
      group.tools.flatMap((tool) =>
        [tool, ...(tool.variants ?? [])].map((entry) => [entry.id, entry] as const),
      ),
    ),
  ),
);

export function toolbarToolById(id: string): CADToolDefinition | undefined {
  return TOOL_INDEX.get(id);
}

const section = (
  id: string,
  label: string,
  visible: readonly string[],
  extra: readonly string[] = [],
): CADToolbarSection => ({ id, label, visible, menu: [...visible, ...extra] });

/** The Part document ribbon mirrors Fusion's Design workspace. */
const PART_FUSION_TABS: readonly CADToolbarTab[] = [
  {
    id: "solid",
    label: "Solid",
    sections: [
      section("solid-create", "Create",
        ["home-sketch", "solid-extrude", "solid-revolve", "solid-cut", "solid-hole", "solid-pattern"],
        ["solid-thread", "solid-rebuild", "solid-mirror", "solid-thicken", "solid-loft", "solid-sweep", "solid-frame", "solid-weld"]),
      section("solid-modify", "Modify",
        ["solid-fillet", "solid-chamfer", "solid-shell", "solid-push-pull", "solid-move"],
        ["solid-split", "solid-replace-face", "solid-delete-face", "solid-copy", "solid-rotate", "solid-scale", "solid-draft", "solid-variable-fillet", "solid-face-fillet"]),
      section("solid-construct", "Construct",
        ["solid-plane", "solid-coordinates", "solid-point"],
        ["solid-curve", "solid-align", "solid-profile", "solid-path", "solid-sketch-reuse"]),
      section("solid-inspect", "Inspect", ["manage-check"]),
      section("solid-insert", "Insert", ["home-import"], ["manage-templates"]),
      section("solid-select", "Select",
        ["home-select-auto"],
        ["home-select-body", "home-select-face", "home-select-edge", "home-select-vertex", "home-select-next"]),
    ],
  },
  {
    id: "surface",
    label: "Surface",
    sections: [
      section("surface-create", "Create", ["solid-loft", "solid-sweep", "solid-thicken"], ["solid-profile", "solid-path"]),
      section("surface-modify", "Modify", ["solid-replace-face", "solid-delete-face"], ["solid-split"]),
    ],
  },
  {
    id: "mesh",
    label: "Mesh",
    sections: [
      section("mesh-create", "Create", ["solid-sheet"], ["solid-rebuild"]),
    ],
  },
  {
    id: "sheet-metal",
    label: "Sheet Metal",
    sections: [
      section("sheet-create", "Create", ["solid-sheet", "solid-frame"], ["solid-weld"]),
    ],
  },
  {
    id: "plastic",
    label: "Plastic",
    sections: [
      section("plastic-create", "Create", ["solid-draft", "solid-thicken"], ["solid-shell"]),
    ],
  },
  {
    id: "manage",
    label: "Manage",
    sections: [
      section("manage-project", "Project",
        ["manage-home", "manage-open", "manage-save", "manage-commit", "manage-recover"],
        ["manage-configurations", "manage-templates"]),
      section("manage-system", "System",
        ["manage-preferences", "manage-help"],
        ["manage-addins", "manage-pdm", "manage-check"]),
    ],
  },
  {
    id: "utilities",
    label: "Utilities",
    sections: [
      section("utilities-model", "Model", ["output-export", "output-step"], ["output-stl", "output-amf", "output-3mf"]),
      section("utilities-drawing", "Drawing", ["output-drawing-workspace"], ["output-dxf", "output-pdf", "output-cut-list"]),
      section("utilities-workspace", "Workspace", ["output-save-assembly"], ["output-project-file"]),
    ],
  },
];

/** Contextual Sketch tab shown while a sketch is being edited, built from
 * the catalog's sketch workspace groups. */
export function sketchContextTab(): CADToolbarTab {
  const sketch = cadRibbonWorkspaces.find((workspace) => workspace.id === "sketch");
  return {
    id: "sketch-context",
    label: "Sketch",
    sections: (sketch?.groups ?? []).map((group) => ({
      id: `sketch-context-${group.id}`,
      label: group.label,
      // Primaries are the buttons; the section menu lists everything behind
      // them, so collapsing Constrain to one button does not hide the twelve
      // relationships that live in its dropdown.
      visible: group.tools.slice(0, 6).map((tool) => tool.id),
      menu: group.tools.flatMap((tool) => [
        tool.id,
        ...(tool.variants ?? []).map((variant) => variant.id),
      ]),
    })),
  };
}

/** Fusion-style tabs for a document type, or null to use the legacy tab
 * rendering (project keeps the complete legacy ribbon by request). */
export function fusionTabsFor(type: CADDocumentType): readonly CADToolbarTab[] | null {
  return type === "part" ? PART_FUSION_TABS : null;
}
