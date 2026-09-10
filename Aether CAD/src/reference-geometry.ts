import type { SketchPlane } from "./part-document";

export type ReferenceGeometryId = "origin" | "top-plane" | "front-plane" | "right-plane";

export interface ReferenceGeometryDefinition {
  id: ReferenceGeometryId;
  label: string;
  icon: string;
}

export const referenceGeometry: readonly ReferenceGeometryDefinition[] = [
  { id: "origin", label: "Origin", icon: "⊙" },
  { id: "top-plane", label: "Top Plane", icon: "▱" },
  { id: "front-plane", label: "Front Plane", icon: "▰" },
  { id: "right-plane", label: "Right Plane", icon: "▯" },
] as const;

export function sketchPlaneForReference(
  id: ReferenceGeometryId,
): SketchPlane | null {
  if (id === "top-plane") return "XY";
  if (id === "front-plane") return "XZ";
  if (id === "right-plane") return "YZ";
  return null;
}
