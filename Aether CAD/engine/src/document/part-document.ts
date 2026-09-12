import { validateDocumentTextExpressions } from "./text-expressions";
import { resolveProfileDrawing } from "./profile-projection";
import {evaluateDocumentVariables,type DocumentVariable} from "./variables";
import { validateSketchPresentation } from "./sketch-presentation";
import { validateSolidFeature, type SolidFeature } from "./solid-features";
export * from "./solid-features";
import {
  createCenterRectangleSketch,
  rectangleSketchRevision,
  reviseCenterRectangleSketch,
  validateSketchFeature,
  type RectangleProfile,
  type SketchConstraint,
  type SketchDimension,
  type SketchFeature,
  type SketchPlane,
} from "../sketch/index";

export const PART_DOCUMENT_FORMAT = "aether-part" as const;
export const LEGACY_PART_DOCUMENT_FORMAT = "open-cad-part" as const;
export const PART_DOCUMENT_VERSION = 3 as const;
export const PART_FILE_EXTENSION = ".acpart" as const;

export type {
  RectangleProfile,
  SketchConstraint,
  SketchDimension,
  SketchFeature,
  SketchPlane,
};

export type ExtrudeOperation = "new" | "add" | "cut";

export interface ExtrudeFeature {
  id: string;
  type: "extrude";
  name: string;
  profileFeatureId: string;
  distanceMillimeters: number;
  operation: ExtrudeOperation;
  bodyId?: string;
  targetBodyId?: string;
  suppressed: boolean;
}

export type PartFeature = SketchFeature | ExtrudeFeature | SolidFeature;

import { validateTreeOrganization, type TreeOrganization } from "./tree-organization";

export interface PartDocument {
  format: typeof PART_DOCUMENT_FORMAT;
  formatVersion: typeof PART_DOCUMENT_VERSION;
  documentId: string;
  name: string;
  units: "millimeter";
  features: PartFeature[];
  variables?:DocumentVariable[];
  rollbackIndex?: number;
  sketchPresentation?: Record<string, import("./sketch-presentation").SketchPresentation>;
  bodyProperties?: Record<string, { name: string; visible: boolean; description?: string; category?: string }>;
  /** Feature tree folders/grouping; organization only — never evaluation order. */
  organization?: TreeOrganization;
}

export interface RectanglePartParameters {
  widthMillimeters: number;
  heightMillimeters: number;
  depthMillimeters: number;
}

export interface PartDocumentIds {
  documentId: string;
  sketchId: string;
  extrudeId: string;
}

export interface RectanglePartCreationOptions {
  plane?: SketchPlane;
  fullyDefinedSketch?: boolean;
}

interface RuntimeCrypto {
  randomUUID?: () => string;
}

function portableId(): string {
  const runtime = globalThis as typeof globalThis & { crypto?: RuntimeCrypto };
  const generated = runtime.crypto?.randomUUID?.();
  if (generated) return generated;
  return `aether-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
}

export function createEmptyPartDocument(name: string): PartDocument {
  const doc: PartDocument = {
    format: PART_DOCUMENT_FORMAT,
    formatVersion: PART_DOCUMENT_VERSION,
    documentId: portableId(),
    name: name.trim(),
    units: "millimeter",
    features: [],
  };
  validatePartDocument(doc);
  return doc;
}

function defaultPartDocumentIds(): PartDocumentIds {
  return {
    documentId: portableId(),
    sketchId: portableId(),
    extrudeId: portableId(),
  };
}

function requirePositiveFinite(value: number, label: string): void {
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${label} must be greater than zero.`);
  }
}

export function createRectanglePartDocument(
  name: string,
  parameters: RectanglePartParameters,
  ids: PartDocumentIds = defaultPartDocumentIds(),
  options: RectanglePartCreationOptions = {},
): PartDocument {
  const normalizedName = name.trim();
  if (!normalizedName) throw new Error("Part name is required.");
  requirePositiveFinite(parameters.widthMillimeters, "Sketch width");
  requirePositiveFinite(parameters.heightMillimeters, "Sketch height");
  requirePositiveFinite(parameters.depthMillimeters, "Extrude distance");
  return {
    format: PART_DOCUMENT_FORMAT,
    formatVersion: PART_DOCUMENT_VERSION,
    documentId: ids.documentId,
    name: normalizedName,
    units: "millimeter",
    features: [
      createCenterRectangleSketch(
        ids.sketchId,
        options.plane ?? "XY",
        parameters.widthMillimeters,
        parameters.heightMillimeters,
        options.fullyDefinedSketch ?? true,
      ),
      {
        id: ids.extrudeId,
        type: "extrude",
        name: "Extrude 1",
        profileFeatureId: ids.sketchId,
        distanceMillimeters: parameters.depthMillimeters,
        operation: "new",
        suppressed: false,
      },
    ],
  };
}

export function rectanglePartParameters(
  document: PartDocument,
): RectanglePartParameters {
  validatePartDocument(document);
  const sketch = document.features.find(
    (feature): feature is SketchFeature => feature.type === "sketch",
  );
  const extrude = document.features.find(
    (feature): feature is ExtrudeFeature => feature.type === "extrude",
  );
  if (!sketch || !extrude) throw new Error("Part needs a Sketch and Extrude.");
  const solvedSketch = rectangleSketchRevision(sketch);
  return {
    widthMillimeters: solvedSketch.widthMillimeters,
    heightMillimeters: solvedSketch.heightMillimeters,
    depthMillimeters: extrude.distanceMillimeters,
  };
}

export function reviseRectanglePartDocument(
  document: PartDocument,
  name: string,
  parameters: RectanglePartParameters,
): PartDocument {
  validatePartDocument(document);
  const normalizedName = name.trim();
  if (!normalizedName) throw new Error("Part name is required.");
  requirePositiveFinite(parameters.widthMillimeters, "Sketch width");
  requirePositiveFinite(parameters.heightMillimeters, "Sketch height");
  requirePositiveFinite(parameters.depthMillimeters, "Extrude distance");
  const sketch = document.features.find(
    (feature): feature is SketchFeature => feature.type === "sketch",
  );
  const extrude = document.features.find(
    (feature): feature is ExtrudeFeature => feature.type === "extrude",
  );
  if (!sketch || !extrude) throw new Error("Part needs a Sketch and Extrude.");
  const current = rectangleSketchRevision(sketch);
  return {
    ...document,
    name: normalizedName,
    features: document.features.map((feature) =>
      feature.id === sketch.id
        ? reviseCenterRectangleSketch(sketch, {
            ...current,
            widthMillimeters: parameters.widthMillimeters,
            heightMillimeters: parameters.heightMillimeters,
            widthDimensioned: true,
            heightDimensioned: true,
          })
        : feature.id === extrude.id
          ? { ...extrude, distanceMillimeters: parameters.depthMillimeters }
          : feature,
    ),
  };
}

export function replaceRectangleSketch(
  document: PartDocument,
  sketch: SketchFeature,
): PartDocument {
  validatePartDocument(document);
  validateSketchFeature(sketch);
  const currentSketch = document.features.find(
    (feature): feature is SketchFeature => feature.type === "sketch",
  );
  if (!currentSketch || currentSketch.id !== sketch.id) {
    throw new Error("Edited Sketch does not belong to this Part.");
  }
  return {
    ...document,
    features: document.features.map((feature) =>
      feature.type === "sketch" ? sketch : feature,
    ),
  };
}

export function validatePartDocument(
  value: unknown,
): asserts value is PartDocument {
  if (!value || typeof value !== "object") {
    throw new Error("Part file is not an object.");
  }
  const document = value as Partial<PartDocument>;
  const expressionVariables = evaluateDocumentVariables(document.variables);
  validateSketchPresentation(document.sketchPresentation);
  validateTreeOrganization(document.organization);
  if (document.format !== PART_DOCUMENT_FORMAT) {
    throw new Error(
      `Unsupported Part format: ${String(document.format ?? "missing")}.`,
    );
  }
  if (document.formatVersion !== PART_DOCUMENT_VERSION) {
    throw new Error(
      `Unsupported Part format version: ${String(document.formatVersion ?? "missing")}.`,
    );
  }
  if (!document.documentId || typeof document.documentId !== "string") {
    throw new Error("Part documentId is required.");
  }
  if (!document.name?.trim()) throw new Error("Part name is required.");
  if (document.units !== "millimeter") {
    throw new Error("Part units must be millimeter.");
  }
  if (!Array.isArray(document.features)) {
    throw new Error("Part features must be an array.");
  }

  if (
    document.rollbackIndex !== undefined &&
    (!Number.isInteger(document.rollbackIndex) ||
      document.rollbackIndex < 0 ||
      document.rollbackIndex > document.features.length)
  )
    throw new Error("Rollback position is outside the feature history.");
  if (document.bodyProperties !== undefined) {
    if (!document.bodyProperties || typeof document.bodyProperties !== "object")
      throw new Error("Invalid body properties.");
    for (const value of Object.values(document.bodyProperties))
      if (
        !value ||
        typeof value.name !== "string" ||
        !value.name.trim() ||
        typeof value.visible !== "boolean"
      )
        throw new Error("Bodies need a name and visibility state.");
  }
  const ids = new Set<string>();
  const earlier = new Map<string, string>();
  const bodies = new Set<string>();
  document.features.forEach((feature, index) => {
    if (
      !feature ||
      typeof feature !== "object" ||
      typeof feature.id !== "string" ||
      !feature.id ||
      ids.has(feature.id)
    )
      throw new Error("Feature IDs must be unique.");
    if (typeof feature.name !== "string" || !feature.name.trim())
      throw new Error(`Feature ${index + 1} needs a name.`);
    if (typeof feature.suppressed !== "boolean")
      throw new Error(`${feature.name} has an invalid suppressed state.`);
    ids.add(feature.id);
    if (
      (feature.type === "extrude" || feature.type === "revolve") &&
      feature.operation === "new"
    ) {
      const id =
        feature.bodyId ??
        (bodies.size === 0
          ? `${document.documentId}:body-1`
          : `${document.documentId}:body-${feature.id}`);
      if (typeof id !== "string" || !id || bodies.has(id))
        throw new Error("Body IDs must be unique.");
      bodies.add(id);
    } else if (!["profile", "sketch", "plane"].includes(feature.type)) {
      if (!bodies.size)
        throw new Error(
          `${feature.name} needs an earlier body-producing feature.`,
        );
      if (
        "targetBodyId" in feature &&
        feature.targetBodyId &&
        !bodies.has(feature.targetBodyId)
      )
        throw new Error(
          `${feature.name} refers to an unavailable target body.`,
        );
    }
    if (feature.type === "sketch") validateSketchFeature(feature);
    else if (feature.type === "extrude") {
      if (
        !["sketch", "profile"].includes(
          earlier.get(feature.profileFeatureId) || "",
        )
      )
        throw new Error("Extrude must reference an earlier Sketch.");
      if (!["new", "add", "cut"].includes(feature.operation))
        throw new Error("Unsupported extrude operation.");
      requirePositiveFinite(feature.distanceMillimeters, "Extrude distance");
    } else validateSolidFeature(feature, earlier);
    earlier.set(feature.id, feature.type);
  });
  validateDocumentTextExpressions(document.features, expressionVariables);
  for(const feature of document.features) {
    if(feature.type==="profile" && feature.profile.type==="projection" && feature.profile.authored?.constraints?.some(c=>[c.a,c.b,c.axis].some(r=>r?.projectedContourId!==undefined))) {
      // Validate against actual projected geometry, never silently discard external relations.
      resolveProfileDrawing(document.features.map(f=>f.type==="profile"?{...f,suppressed:false}:f),feature.id);
    }
  }
}
