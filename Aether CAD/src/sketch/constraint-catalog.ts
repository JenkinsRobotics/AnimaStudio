import type { DrawingConstraintKind } from "@aether/core/sketch";

/** The canonical constraint catalog: order, labels, glyphs and shortcuts, taken
 *  from Onshape's Constrain menu so the ribbon, the canvas marks and the hover
 *  readout all render the same thing. One list — adding a constraint here makes
 *  it appear in every surface at once.
 *
 *  `glyph` is a single character so it renders inside the SVG canvas without an
 *  icon font; the ribbon uses the shared ToolIcon where one exists. */
export interface SketchConstraintEntry {
  kind: DrawingConstraintKind;
  label: string;
  glyph: string;
  /** Onshape's keyboard shortcut, shown in the menu. */
  shortcut: string;
}

/** Relationships, in Onshape's menu order. Dimensions are a separate concept
 *  and are listed below. */
export const sketchConstraintCatalog: readonly SketchConstraintEntry[] = [
  { kind: "coincident", label: "Coincident", glyph: "⌖", shortcut: "i" },
  { kind: "concentric", label: "Concentric", glyph: "◎", shortcut: "shift o" },
  { kind: "parallel", label: "Parallel", glyph: "∥", shortcut: "b" },
  { kind: "tangent", label: "Tangent", glyph: "◌", shortcut: "t" },
  { kind: "horizontal", label: "Horizontal", glyph: "—", shortcut: "h" },
  { kind: "vertical", label: "Vertical", glyph: "❘", shortcut: "v" },
  { kind: "perpendicular", label: "Perpendicular", glyph: "⊥", shortcut: "shift l" },
  { kind: "equal", label: "Equal", glyph: "=", shortcut: "e" },
  { kind: "midpoint", label: "Midpoint", glyph: "▸", shortcut: "shift m" },
  { kind: "normal", label: "Normal", glyph: "⊾", shortcut: "shift k" },
  { kind: "symmetric", label: "Symmetric", glyph: "↔", shortcut: "shift q" },
  { kind: "fix", label: "Fix", glyph: "✕", shortcut: "shift j" },
  { kind: "curvature", label: "Curvature", glyph: "∿", shortcut: "shift u" },
] as const;

/** Dimensional constraints. Onshape puts these on the Dimension tool rather
 *  than the Constrain menu, and they draw as annotations, not glyph badges. */
export const sketchDimensionKinds: readonly DrawingConstraintKind[] = [
  "distance",
  "horizontal-distance",
  "vertical-distance",
  "length",
  "radius",
  "diameter",
  "angle",
] as const;

const byKind = new Map(sketchConstraintCatalog.map((entry) => [entry.kind, entry]));

export function sketchConstraintEntry(kind: string): SketchConstraintEntry | undefined {
  return byKind.get(kind as DrawingConstraintKind);
}

/** True when this constraint draws as a dimension annotation instead of a badge. */
export function isDimensionConstraint(kind: string): boolean {
  return (sketchDimensionKinds as readonly string[]).includes(kind);
}
