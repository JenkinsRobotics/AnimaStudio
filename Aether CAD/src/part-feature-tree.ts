import { availableBodies, rollbackPosition } from "@aether/core/document";
import type { PartDocument, PartFeature } from "./part-document";
import { sketchDefinitionState } from "./sketch-constraints";

export type PartTreeItemKind = "part-document" | PartFeature["type"] | "body";

export interface PartTreeItem {
  id: string;
  name: string;
  kind: PartTreeItemKind;
  detail: string;
  children: PartTreeItem[];
}

function featureDetail(feature: PartFeature): string {
  if (feature.type === "sketch") {
    const state = sketchDefinitionState(feature);
    return `${feature.plane} · ${feature.profile.widthMillimeters} × ${feature.profile.heightMillimeters} mm · ${state.label}`;
  }
  if (feature.type === "extrude")
    return `${feature.distanceMillimeters} mm · ${feature.operation}`;
  if(feature.type === "plane") return `${feature.plane} · ${feature.offsetMillimeters} mm offset`;
  if (feature.type === "profile")
    return `${feature.plane} · ${feature.profile.type}`;
  if (feature.type === "revolve")
    return `${feature.angleDegrees}° · ${feature.operation}`;
  if (feature.type === "mirror")
    return `${feature.plane} · ${feature.operation}`;
  return `${feature.radiusMillimeters} mm`;
}

/** Projects editable feature history into the Items browser without duplicating CAD state. */
export function buildPartFeatureTree(document: PartDocument): PartTreeItem {
  return {
    id: document.documentId,
    name: document.name,
    kind: "part-document",
    detail: ".acpart",
    children: [
      ...document.features.map((feature) => ({
        id: feature.id,
        name: feature.name,
        kind: feature.type,
        detail: feature.suppressed
          ? "Suppressed"
          : document.features.indexOf(feature) >= rollbackPosition(document)
            ? "Rolled back"
            : featureDetail(feature),
        children: [],
      })),
      ...availableBodies(document).map((body) => ({
        id: body.id,
        name: body.name,
        kind: "body" as const,
        detail: body.visible ? "Solid" : "Hidden",
        children: [],
      })),
    ],
  };
}
