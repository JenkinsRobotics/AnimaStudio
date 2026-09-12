import { sketchConstraintCatalog, sketchDimensionKinds } from "./sketch/constraint-catalog";
import type { ToolIconName } from "@aether/ui";
import type { CADCommandID } from "./cad-command-registry";

export type CADRibbonWorkspaceID =
  | "home"
  | "sketch"
  | "solid"
  | "assembly"
  | "view"
  | "manage"
  | "output";

export type CADToolActionID = CADCommandID
  | "new-assembly"
  | "open-assembly"
  | "save-assembly"
  | "show-home"
  | "show-recovery"
  | "show-preferences"
  | "show-help"
  | "show-export"
  | "open-drawing"
  | "show-items"
  | "show-parameters"
  | "show-mates"
  | "show-inspect"
  | "show-visualization"
  | "show-history"
  | "reset-panels";

export interface CADToolDefinition {
  id: string;
  label: string;
  icon: ToolIconName;
  action?: CADToolActionID;
  unavailableReason?: string;
  variants?: CADToolDefinition[];
}

export interface CADToolGroupDefinition {
  id: string;
  label: string;
  tools: readonly CADToolDefinition[];
}

export interface CADRibbonWorkspaceDefinition {
  id: CADRibbonWorkspaceID;
  label: string;
  groups: readonly CADToolGroupDefinition[];
}

const solidProducer = "Requires a canonical Core solid-feature command that is not connected yet.";
const assemblyProducer = "Requires a canonical Core Assembly mutation or mate solver command that is not connected yet.";
const analysisProducer = "Requires an exact Core analysis contract and result producer.";
const exportProducer = "Requires a canonical Core export producer for this format.";
const projectProducer = "Requires persistent workspace metadata that is not connected yet.";

const tool = (
  id: string,
  label: string,
  icon: ToolIconName,
  action?: CADToolActionID,
  unavailableReason?: string,
): CADToolDefinition => ({ id, label, icon, action, unavailableReason });

/** Icon for a constraint kind. Falls back to a neutral glyph so a newly added
 *  kind shows up rather than crashing the ribbon. */
const constraintIcon = (kind: string): ToolIconName =>
  (({
    coincident: "point", horizontal: "parallel", vertical: "perpendicular",
    parallel: "parallel", perpendicular: "perpendicular", concentric: "concentric",
    equal: "parallel", midpoint: "point", tangent: "tangent", curvature: "curvature",
    normal: "normal", symmetric: "symmetric", quadrant: "quadrant",
    "ellipse-shape": "ellipse", "ellipse-locus": "ellipse", "spline-shape": "curve",
    offset: "offset", slot: "slot", distance: "measure",
    "horizontal-distance": "measure", "vertical-distance": "measure",
    length: "measure", radius: "circle", diameter: "circle", angle: "angle",
    fix: "ground",
  }) as Record<string, ToolIconName>)[kind] ?? "point";

const constraintTool = (kind: string, label: string): CADToolDefinition =>
  tool(`sketch-constraint-${kind}`, label, constraintIcon(kind), `sketch-constraint-${kind}` as CADToolActionID);

/** One Constrain button; every other relationship lives in its dropdown, in
 *  Onshape's menu order. */
const constraintRibbonTool = (): CADToolDefinition => {
  const [first, ...rest] = sketchConstraintCatalog;
  return {
    ...constraintTool(first.kind, first.label),
    id: "sketch-constrain",
    variants: rest.map((entry) => constraintTool(entry.kind, entry.label)),
  };
};

/** One Dimension button. Onshape drives every dimension type from this tool
 *  rather than listing them beside the relationships. */
const dimensionRibbonTool = (): CADToolDefinition => {
  const labels: Record<string, string> = {
    distance: "Dimension",
    "horizontal-distance": "Horizontal distance",
    "vertical-distance": "Vertical distance",
    length: "Length",
    radius: "Radius",
    diameter: "Diameter",
    angle: "Angle",
  };
  const [first, ...rest] = sketchDimensionKinds;
  return {
    ...constraintTool(first, labels[first] ?? first),
    id: "sketch-dimension",
    icon: "measure",
    label: "Dimension",
    variants: rest.map((kind) => constraintTool(kind, labels[kind] ?? kind)),
  };
};

export const cadRibbonWorkspaces: readonly CADRibbonWorkspaceDefinition[] = [
  {
    id: "home",
    label: "Home",
    groups: [
      { id: "home-create", label: "Create", tools: [
        tool("home-new-part", "New Part", "new-part", "new-part"),
        tool("home-new-assembly", "New Assembly", "assembly", "new-assembly"),
        tool("home-sketch", "Sketch", "sketch", "sketch"),
        tool("home-extrude", "Rebuild Extrude", "extrude", "rebuild-part"),
        tool("home-cut", "Cut", "cut", undefined, solidProducer),
        tool("home-revolve", "Revolve", "revolve", "feature-revolve"),
      ] },
      { id: "home-modify", label: "Modify", tools: [
        tool("home-fillet", "Fillet", "fillet", "feature-fillet"),
        tool("home-chamfer", "Chamfer", "chamfer", "feature-chamfer"),
        tool("home-shell", "Shell", "shell", undefined, solidProducer),
      ] },
      { id: "home-project", label: "Project", tools: [
        tool("home-open", "Open Part", "open", "open-part"),
        tool("home-save", "Save Part", "save", "save-part"),
        tool("home-commit", "Commit", "commit", "commit-part"),
        tool("home-import", "Insert STEP", "import", "insert-step"),
        tool("home-recovery", "Recover", "history", "show-recovery"),
      ] },
      { id: "home-selection", label: "Selection", tools: [
        tool("home-select-auto", "Auto", "select", "selection-auto"),
        tool("home-select-component", "Component", "assembly", "selection-component"),
        tool("home-select-body", "Body", "part", "selection-body"),
        tool("home-select-face", "Face", "face", "selection-face"),
        tool("home-select-edge", "Edge", "edge", "selection-edge"),
        tool("home-select-vertex", "Vertex", "vertex", "selection-vertex"),
        tool("home-select-next", "Next Filter", "select", "selection-next-filter"),
      ] },
    ],
  },
  {
    id: "sketch",
    label: "Sketch",
    groups: [
      { id: "sketch-create", label: "Create", tools: [
        tool("sketch-start", "Create Sketch", "sketch", "sketch"),
        tool("sketch-point", "Point", "point", "sketch-point"),
        {...tool("sketch-line", "Line", "line", "sketch-line"), variants:[tool("sketch-midpoint-line", "Midpoint line", "midpoint-line", "sketch-midpoint-line")]},
        {...tool("sketch-arc", "3 point arc", "arc", "sketch-arc"), variants:[tool("sketch-center-arc", "Center point arc", "center-arc", "sketch-center-arc"), tool("sketch-tangent-arc", "Tangent arc", "tangent-arc", "sketch-tangent-arc"), tool("sketch-elliptical-arc", "Elliptical arc", "elliptical-arc", "sketch-elliptical-arc")]},
        {...tool("sketch-spline", "Cubic Bézier", "curve", "sketch-cubic-bezier"), variants:[tool("sketch-fit-spline", "Fit-point spline", "curve", "sketch-fit-spline"), tool("sketch-insert-spline-point", "Insert spline point", "point", "sketch-insert-spline-point")]},
        {...tool("sketch-rectangle", "Rectangle", "rectangle", "sketch-rectangle"), variants:[tool("sketch-center-rectangle", "Center point rectangle", "center-rectangle", "sketch-center-rectangle"), tool("sketch-aligned-rectangle", "Aligned rectangle", "aligned-rectangle", "sketch-aligned-rectangle")]},
        {...tool("sketch-circle", "Circle", "circle", "sketch-circle"), variants:[tool("sketch-three-point-circle", "3 point circle", "circle-three-point", "sketch-three-point-circle"),tool("sketch-ellipse", "Ellipse", "ellipse", "sketch-ellipse")]},
        {...tool("sketch-polygon", "Inscribed polygon", "polygon", "sketch-inscribed-polygon"), variants:[tool("sketch-circumscribed-polygon", "Circumscribed polygon", "circumscribed-polygon", "sketch-circumscribed-polygon")]},
      ] },
      { id: "sketch-modify", label: "Modify", tools: [
        tool("sketch-mirror", "Mirror", "mirror", "sketch-mirror"),
        tool("sketch-linear-pattern", "Linear pattern", "pattern", "sketch-linear-pattern"),
        tool("sketch-circular-pattern", "Circular pattern", "pattern", "sketch-circular-pattern"),
        tool("sketch-transform", "Transform", "move", "sketch-transform"),
        tool("sketch-fillet", "Fillet", "fillet", "sketch-fillet"),
        tool("sketch-chamfer", "Chamfer", "chamfer", "sketch-chamfer"),
        tool("sketch-offset", "Offset", "offset", "sketch-offset"),
        tool("sketch-slot", "Slot", "slot", "sketch-slot"),
        tool("sketch-trim", "Trim", "trim", "sketch-trim"),
        tool("sketch-extend", "Extend", "line", "sketch-extend"),
        tool("sketch-split", "Split", "trim", "sketch-split"),
        tool("sketch-project", "Project sketch", "plane", "sketch-project"),
      ] },
      // Onshape collapses relationships into ONE Constrain button with a
      // dropdown, and dimensions onto a separate Dimension tool — not 26 flat
      // buttons. Both lists come from the constraint catalog so the ribbon, the
      // canvas glyphs and the keyboard map can never disagree.
      // Two separate groups, not one: the contextual Sketch tab gives each
      // section a single dropdown, so pairing them would put relationships and
      // dimensions in one mixed menu. One icon each, everything else behind it.
      { id: "sketch-constraints", label: "Constrain", tools: [constraintRibbonTool()] },
      { id: "sketch-dimensions", label: "Dimension", tools: [dimensionRibbonTool()] },
      { id: "sketch-insert", label: "Insert", tools: [tool("sketch-text", "Text", "text", "sketch-text"), tool("sketch-import-dxf", "Import DXF", "import", "sketch-import-dxf")] },
      // No Navigate group: Select, Pan and Fit are viewport controls, not sketch
      // tools, and Onshape's sketch toolbar carries none of them. Escape returns
      // to Select, and clicking an active tool toggles back to it.
    ],
  },
  {
    id: "solid",
    label: "3D Tools",
    groups: [
      { id: "solid-create", label: "Modeling", tools: [
        tool("solid-rebuild", "Rebuild", "extrude", "rebuild-part"),
        tool("solid-extrude", "Extrude", "extrude", "feature-extrude"),
        tool("solid-cut", "Cut", "cut", undefined, solidProducer),
        tool("solid-hole", "Hole", "hole", undefined, solidProducer),
        tool("solid-thread", "Thread", "thread", undefined, solidProducer),
        tool("solid-frame", "Frame Member", "frame", undefined, solidProducer),
        tool("solid-weld", "Weld", "weld", undefined, solidProducer),
        tool("solid-sheet", "Sheet Metal", "sheet", undefined, solidProducer),
        tool("solid-revolve", "Revolve", "revolve", "feature-revolve"),
      ] },
      { id: "solid-edit", label: "Solid Editing", tools: [
        tool("solid-fillet", "Fillet", "fillet", "feature-fillet"),
        tool("solid-chamfer", "Chamfer", "chamfer", "feature-chamfer"),
        tool("solid-shell", "Shell", "shell", undefined, solidProducer),
        tool("solid-split", "Split Body", "split", undefined, solidProducer),
        tool("solid-push-pull", "Push/Pull", "push-pull", undefined, solidProducer),
        tool("solid-replace-face", "Replace Face", "replace-face", undefined, solidProducer),
        tool("solid-delete-face", "Delete Face", "remove", undefined, solidProducer),
      ] },
      { id: "solid-reference", label: "Reference", tools: [
        tool("solid-plane", "Plane", "plane", "feature-plane"),
        tool("solid-coordinates", "Coordinates", "axis", undefined, solidProducer),
        tool("solid-point", "Point", "point", undefined, solidProducer),
        tool("solid-curve", "Curve", "curve", undefined, solidProducer),
        tool("solid-sketch-reuse", "Reuse Sketch", "sketch", undefined, solidProducer),
        tool("solid-align", "Align", "parallel", undefined, solidProducer),
        tool("solid-profile", "Profile", "polygon", undefined, solidProducer),
        tool("solid-path", "Path", "curve", undefined, solidProducer),
      ] },
      { id: "solid-advanced", label: "Advanced Shape", tools: [
        tool("solid-loft", "Loft", "loft", undefined, solidProducer),
        tool("solid-sweep", "Sweep", "sweep", undefined, solidProducer),
        tool("solid-partial-revolve", "Partial Revolve", "revolve", undefined, solidProducer),
        tool("solid-draft", "Draft", "draft", undefined, solidProducer),
        tool("solid-thicken", "Thicken", "thicken", undefined, solidProducer),
        tool("solid-variable-fillet", "Variable Fillet", "fillet", undefined, solidProducer),
        tool("solid-face-fillet", "Face Fillet", "fillet", undefined, solidProducer),
        tool("solid-pattern", "Pattern", "pattern", undefined, solidProducer),
      ] },
      { id: "solid-transform", label: "Transform", tools: [
        tool("solid-move", "Move", "move", undefined, solidProducer),
        tool("solid-copy", "Copy", "copy", undefined, solidProducer),
        tool("solid-rotate", "Rotate", "rotate", undefined, solidProducer),
        tool("solid-mirror", "Mirror", "mirror", "feature-mirror"),
        tool("solid-scale", "Scale", "scale", undefined, solidProducer),
      ] },
    ],
  },
  {
    id: "assembly",
    label: "Assembly",
    groups: [
      { id: "assembly-structure", label: "Structure", tools: [
        tool("assembly-new", "New Assembly", "assembly", "new-assembly"),
        tool("assembly-open", "Open Assembly", "open", "open-assembly"),
        tool("assembly-save", "Save Assembly", "save", "save-assembly"),
        tool("assembly-insert", "Insert Component", "insert", "assembly-insert-component"),
        tool("assembly-fastener", "Smart Fastener", "thread", undefined, assemblyProducer),
        tool("assembly-cut", "Assembly Cut", "cut", undefined, assemblyProducer),
        tool("assembly-linked", "Linked Copy", "link", undefined, assemblyProducer),
        tool("assembly-independent", "Make Independent", "part", undefined, assemblyProducer),
        tool("assembly-replace", "Replace", "replace-face", undefined, assemblyProducer),
        tool("assembly-variant", "Variant", "copy", undefined, assemblyProducer),
        tool("assembly-drag", "Drag with Mates", "move", undefined, assemblyProducer),
        tool("assembly-ground", "Ground / Float", "ground", "assembly-toggle-grounded"),
        tool("assembly-suppress", "Suppress / Restore", "suppressed", "assembly-toggle-suppressed"),
        tool("assembly-remove", "Remove Component", "remove", "assembly-remove-instance"),
      ] },
      { id: "assembly-rigid", label: "Rigid Mates", tools: [
        tool("assembly-connector", "Connector", "connector", "assembly-add-connector"),
        tool("assembly-fixed", "Mate", "link", "assembly-create-mate"),
        tool("assembly-coincident", "Coincident", "plane", undefined, assemblyProducer),
        tool("assembly-concentric", "Concentric", "concentric", undefined, assemblyProducer),
        tool("assembly-distance", "Distance", "measure", undefined, assemblyProducer),
        tool("assembly-angle", "Angle", "angle", undefined, assemblyProducer),
        tool("assembly-parallel", "Parallel", "parallel", undefined, assemblyProducer),
        tool("assembly-perpendicular", "Perpendicular", "perpendicular", undefined, assemblyProducer),
        tool("assembly-tangent", "Tangent", "tangent", undefined, assemblyProducer),
        tool("assembly-revolute", "Revolute", "revolve", undefined, assemblyProducer),
        tool("assembly-slider", "Slider", "slider", undefined, assemblyProducer),
      ] },
      { id: "assembly-advanced", label: "Advanced Mates", tools: [
        tool("assembly-width", "Width", "measure", undefined, assemblyProducer),
        tool("assembly-symmetry", "Symmetry", "mirror", undefined, assemblyProducer),
        tool("assembly-path", "Path", "curve", undefined, assemblyProducer),
        tool("assembly-coupler", "Linear Coupler", "link", undefined, assemblyProducer),
        tool("assembly-limit-distance", "Limit Distance", "measure", undefined, assemblyProducer),
        tool("assembly-limit-angle", "Limit Angle", "angle", undefined, assemblyProducer),
        tool("assembly-gear", "Gear", "settings", undefined, assemblyProducer),
        tool("assembly-hinge", "Hinge", "hinge", undefined, assemblyProducer),
      ] },
      { id: "assembly-context", label: "Context", tools: [
        tool("assembly-edit", "Edit Component", "sketch", undefined, assemblyProducer),
        tool("assembly-return", "Return", "back", "show-mates"),
        tool("assembly-pattern", "Component Pattern", "pattern", undefined, assemblyProducer),
        tool("assembly-relation-create", "Relation", "settings", "assembly-create-relation"),
        tool("assembly-mate-dof-value", "Set DOF Value", "rotate", "assembly-set-mate-dof-value"),
        tool("assembly-mate-dof-limits", "Edit DOF Limits", "measure", "assembly-edit-mate-dof-limits"),
        tool("assembly-mate-suppress", "Suppress / Restore Mate", "suppressed", "assembly-toggle-mate-suppressed"),
        tool("assembly-mate-remove", "Remove Mate", "remove", "assembly-remove-mate"),
      ] },
      { id: "assembly-inspect", label: "Inspect", tools: [
        tool("assembly-properties", "Properties", "properties", "show-mates"),
        tool("assembly-section", "Section", "split", undefined, analysisProducer),
        tool("assembly-explode", "Explode", "move", undefined, assemblyProducer),
        tool("assembly-material", "Material", "material", undefined, projectProducer),
        tool("assembly-mass", "Mass & Health", "mass", undefined, analysisProducer),
        tool("assembly-measure", "Measure", "measure", undefined, analysisProducer),
        tool("assembly-clearance", "Clearance", "measure", undefined, analysisProducer),
        tool("assembly-interference", "Interference", "split", undefined, analysisProducer),
      ] },
    ],
  },
  {
    id: "view",
    label: "View",
    groups: [
      { id: "view-orientation", label: "Orientation", tools: [
        tool("view-fit", "Fit Model", "fit", "fit-view"),
        tool("view-top", "Top", "view-top", "view-top"),
        tool("view-bottom", "Bottom", "view-top", "view-bottom"),
        tool("view-front", "Front", "view-front", "view-front"),
        tool("view-back", "Back", "view-front", "view-back"),
        tool("view-right", "Right", "view-right", "view-right"),
        tool("view-left", "Left", "view-right", "view-left"),
        tool("view-iso", "Isometric", "part", "view-isometric"),
        tool("view-save", "Save View", "save", undefined, projectProducer),
      ] },
      { id: "view-display", label: "Display", tools: [
        tool("view-appearance", "Appearance", "material", "show-visualization"),
        tool("view-shaded", "Shaded + Edges", "part", "display-shaded-edges"),
        tool("view-shaded-only", "Shaded", "part", "display-shaded"),
        tool("view-wireframe", "Wireframe", "wireframe", "display-wireframe"),
        tool("view-hidden-line", "Hidden Line", "wireframe", "display-hidden-line"),
        tool("view-ghost", "Ghost", "eye", "display-ghost"),
      ] },
      { id: "view-scene", label: "Scene", tools: [
        tool("view-studio", "Studio", "light", "lighting-studio"),
        tool("view-softbox", "Softbox", "light", "lighting-softbox"),
        tool("view-daylight", "Daylight", "light", "lighting-daylight"),
        tool("view-dark-room", "Dark Room", "light", "lighting-dark-room"),
        tool("view-shadows", "Contact Shadows", "plane", "toggle-contact-shadows"),
      ] },
      { id: "view-material", label: "Material", tools: [
        tool("view-background-graphite", "Graphite", "material", "background-graphite"),
        tool("view-background-midnight", "Midnight", "material", "background-midnight"),
        tool("view-background-cad-light", "CAD Light", "material", "background-cad-light"),
        tool("view-background-blueprint", "Blueprint", "material", "background-blueprint"),
        tool("view-finish-matte", "Matte", "material", "finish-matte"),
        tool("view-finish-satin", "Satin", "material", "finish-satin"),
        tool("view-finish-gloss", "Gloss", "material", "finish-gloss"),
        tool("view-feature-edges", "Feature Edges", "edge", "toggle-feature-edges"),
      ] },
      { id: "view-ground", label: "Ground", tools: [
        tool("view-ground-none", "None", "remove", "ground-none"),
        tool("view-ground-grid", "Grid", "grid", "ground-grid"),
        tool("view-ground-floor", "Floor", "plane", "ground-floor"),
        tool("view-ground-both", "Grid + Floor", "grid", "ground-both"),
        tool("view-reset-appearance", "Reset", "history", "reset-appearance"),
      ] },
      { id: "view-panels", label: "Panels", tools: [
        tool("view-items", "Items", "list", "show-items"),
        tool("view-properties", "Properties", "properties", "show-parameters"),
        tool("view-mates", "Assembly", "assembly", "show-mates"),
        tool("view-inspect", "Inspect", "inspect", "show-inspect"),
        tool("view-history", "History", "history", "show-history"),
        tool("view-reset-panels", "Reset Panels", "panels", "reset-panels"),
      ] },
    ],
  },
  {
    id: "manage",
    label: "Manage",
    groups: [
      { id: "manage-project", label: "Project", tools: [
        tool("manage-home", "Start", "home", "show-home"),
        tool("manage-open", "Open Part", "open", "open-part"),
        tool("manage-save", "Save Part", "save", "save-part"),
        tool("manage-commit", "Commit", "commit", "commit-part"),
        tool("manage-recover", "Recover", "history", "show-recovery"),
        tool("manage-configurations", "Configurations", "properties", undefined, projectProducer),
        tool("manage-templates", "Templates", "document", undefined, projectProducer),
      ] },
      { id: "manage-system", label: "System", tools: [
        tool("manage-preferences", "Preferences", "settings", "show-preferences"),
        tool("manage-addins", "Add-ins", "add", undefined, "Requires a signed extension host and permission model."),
        tool("manage-pdm", "Project Data", "document", undefined, "Requires a persistent document-management provider."),
        tool("manage-check", "Design Check", "check", undefined, analysisProducer),
        tool("manage-help", "Help", "help", "show-help"),
      ] },
    ],
  },
  {
    id: "output",
    label: "Output",
    groups: [
      { id: "output-model", label: "Model", tools: [
        tool("output-export", "Export Center", "export", "show-export"),
        tool("output-step", "STEP", "export", "show-export"),
        tool("output-stl", "STL", "export", undefined, exportProducer),
        tool("output-amf", "AMF", "export", undefined, exportProducer),
        tool("output-3mf", "3MF", "export", undefined, exportProducer),
      ] },
      { id: "output-drawing", label: "Drawing", tools: [
        tool("output-drawing-workspace", "Drawing", "document", "open-drawing"),
        tool("output-dxf", "DXF", "document", undefined, exportProducer),
        tool("output-pdf", "PDF / Print", "document", undefined, exportProducer),
        tool("output-cut-list", "Cut List", "list", undefined, exportProducer),
      ] },
      { id: "output-project", label: "Workspace", tools: [
        tool("output-save-assembly", "Save Assembly", "save", "save-assembly"),
        tool("output-project-file", "Workspace File", "document", undefined, projectProducer),
      ] },
    ],
  },
];

export function cadRibbonWorkspace(id: CADRibbonWorkspaceID): CADRibbonWorkspaceDefinition {
  return cadRibbonWorkspaces.find((workspace) => workspace.id === id) ?? cadRibbonWorkspaces[0];
}
