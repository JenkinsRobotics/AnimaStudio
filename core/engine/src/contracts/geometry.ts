import type { PartDocument } from "../document/index";

export type Vec3 = readonly [number, number, number];

export type ConnectorKind =
  | "face-center"
  | "edge-midpoint"
  | "vertex"
  | "circle-center"
  | "ellipse-center"
  | "cylinder-axis"
  | "cone-axis"
  | "sphere-center"
  | "torus-center";

export interface ConnectorFrameData {
  origin: Vec3;
  xAxis: Vec3;
  yAxis: Vec3;
  zAxis: Vec3;
}

export interface ConnectorCandidate extends ConnectorFrameData {
  id: string;
  faceId: number;
  kind: ConnectorKind;
  label: string;
}

export interface FaceTopologyData {
  id: number;
  surfaceType: string;
  candidates: ConnectorCandidate[];
}

export interface FaceRangeData {
  start: number;
  count: number;
  faceId: number;
}

export interface PartGeometryData {
  id: string;
  name: string;
  sourceDocumentId: string;
  sourceName: string;
  vertices: Float32Array;
  normals: Float32Array;
  triangles: Uint32Array;
  edgeLines: Float32Array;
  faceRanges: FaceRangeData[];
  topology: FaceTopologyData[];
}

export interface ImportedModelData {
  sourceName: string;
  parts: PartGeometryData[];
  parseMilliseconds: number;
}

export interface MateConnector {
  id: string;
  name: string;
  partId: string;
  partName: string;
  candidate: ConnectorCandidate;
}

export interface AppliedMate {
  id: string;
  movingPartId: string;
  targetPartId: string;
  movingConnectorId: string;
  targetConnectorId: string;
  movingConnector: ConnectorCandidate;
  targetConnector: ConnectorCandidate;
}

export type WorkerRequest =
  | {
      type: "import-step";
      requestId: number;
      sourceName: string;
      bytes: ArrayBuffer;
    }
  | {
      type: "evaluate-part";
      requestId: number;
      document: PartDocument;
    };

export type WorkerResponse =
  | { type: "ready" }
  | {
      type: "imported";
      requestId: number;
      model: ImportedModelData;
    }
  | {
      type: "part-evaluated";
      requestId: number;
      model: ImportedModelData;
    }
  | {
      type: "error";
      requestId?: number;
      message: string;
    };
