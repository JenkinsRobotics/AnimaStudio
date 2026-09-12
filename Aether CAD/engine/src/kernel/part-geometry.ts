import type { AnyShape } from "replicad";
import type { PartGeometryData } from "../contracts/index";
import { extractExactTopology } from "./exact-topology";

function errorDescription(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "number") return `OCCT exception 0x${error.toString(16)}`;
  return String(error);
}

/** Creates the disposable render projection while retaining exact B-Rep topology. */
export function buildPartGeometry(
  shape: AnyShape,
  sourceDocumentId: string,
  sourceName: string,
  partIndex: number,
  options: { id?: string; name?: string } = {},
): PartGeometryData {
  let mesh;
  let edges;
  let topology;
  try {
    // Capture authoritative B-Rep topology before tessellation. Some generated
    // browser bindings invalidate analytic iterators after meshing curved solids.
    topology = extractExactTopology(shape);
  } catch (error) {
    throw new Error(
      `${sourceName} Part ${partIndex + 1} analytic topology: ${errorDescription(error)}`,
    );
  }
  try {
    mesh = shape.mesh({ tolerance: 0.08, angularTolerance: 0.12 });
  } catch (error) {
    throw new Error(
      `${sourceName} Part ${partIndex + 1} surface tessellation: ${errorDescription(error)}`,
    );
  }
  try {
    edges = shape.meshEdges({ tolerance: 0.08, angularTolerance: 0.12 });
  } catch (error) {
    throw new Error(
      `${sourceName} Part ${partIndex + 1} edge tessellation: ${errorDescription(error)}`,
    );
  }
  const stem = sourceName.replace(/\.(step|stp|cadpart)$/i, "");
  return {
    id: options.id ?? `${sourceDocumentId}:body-${partIndex + 1}`,
    name: options.name ?? `${stem} · Part ${partIndex + 1}`,
    sourceDocumentId,
    sourceName,
    vertices: new Float32Array(mesh.vertices),
    normals: new Float32Array(mesh.normals),
    triangles: new Uint32Array(mesh.triangles),
    edgeLines: new Float32Array(edges.lines),
    faceRanges: mesh.faceGroups,
    topology,
  };
}

