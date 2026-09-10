/**
 * The only application-facing boundary to the future Aether Core package.
 *
 * Aether CAD still embeds the implementation today. Keep UI and viewport code
 * importing CAD semantics from this facade so extracting the implementation
 * later changes module locations, not behavior or document meaning.
 */
import type { ImportedModelData } from "./domain";
import type { PartDocument } from "./part-document";
import { OCCTWorkerClient } from "@aether/core/kernel";

export type {
  AppliedMate,
  ConnectorCandidate,
  ConnectorKind,
  FaceRangeData,
  FaceTopologyData,
  MateConnector,
  PartGeometryData,
  Vec3,
} from "@aether/core/contracts";
export type { PartDocument, PartFeature } from "@aether/core/document";
export {
  createRectanglePartDocument,
  rectanglePartParameters,
  replaceRectangleSketch,
  reviseRectanglePartDocument,
} from "@aether/core/document";
export type {
  RectangleSketchRevision,
  SketchConstraint,
  SketchDefinitionState,
  SketchDimension,
  SketchFeature,
  SketchPlane,
} from "@aether/core/sketch";
export {
  rectangleSketchRevision,
  reviseCenterRectangleSketch,
  sketchDefinitionState,
} from "@aether/core/sketch";
export { parsePartDocument, serializePartDocument } from "@aether/core/document";
export { connectorMatrix, matrixAlmostEqual, solveFastenedMate } from "./math";
export { connectorKindPreference } from "@aether/core/geometry";
export {
  FastenedMateDraft,
  MateConnectorRegistry,
  MateConstraintTracker,
} from "./mate-state";

export interface AetherCoreClient {
  readonly ready: Promise<void>;
  importSTEP(file: File): Promise<ImportedModelData>;
  evaluatePart(document: PartDocument): Promise<ImportedModelData>;
}

/** Embedded adapter used until Aether Core becomes its own package/process. */
export function createEmbeddedAetherCoreClient(): AetherCoreClient {
  return new OCCTWorkerClient();
}
