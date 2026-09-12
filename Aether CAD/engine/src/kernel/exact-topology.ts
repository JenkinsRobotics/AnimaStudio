import type { TopAbs_ShapeEnum } from "replicad-opencascadejs";
import { cast, getOC, type AnyShape, type Edge, type Face } from "replicad";
import {
  connectorAxes,
  deleteAfterPointTuple,
  deleteAfterVectorTuple,
  pointAlongAxis,
  type ConnectorAxes,
} from "../geometry/index";
import type {
  ConnectorCandidate,
  FaceTopologyData,
  Vec3,
} from "../contracts/index";
import {
  connectorKindPreference,
  cylinderAxisStations,
  sameOrigin,
} from "../geometry/index";

function errorDescription(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "number") return `OCCT exception 0x${error.toString(16)}`;
  return String(error);
}

function addUniqueCandidate(
  candidates: ConnectorCandidate[],
  candidate: ConnectorCandidate,
): void {
  // One visible node represents one exact location. Analytic axis/center
  // candidates are inserted before coincident boundary descriptions.
  const duplicateIndex = candidates.findIndex((existing) =>
    sameOrigin(existing.origin, candidate.origin),
  );
  if (duplicateIndex < 0) {
    candidates.push(candidate);
  } else if (
    connectorKindPreference(candidate.kind) <
    connectorKindPreference(candidates[duplicateIndex].kind)
  ) {
    candidates[duplicateIndex] = candidate;
  }
}

function frameAtEdge(
  edge: Edge,
  position: number,
  fallback: ConnectorAxes,
): ConnectorAxes {
  try {
    return connectorAxes(
      fallback.zAxis,
      deleteAfterVectorTuple(edge.tangentAt(position)),
    );
  } catch {
    return fallback;
  }
}

function curveCandidates(
  faceId: number,
  edge: Edge,
  faceFrame: ConnectorAxes,
  edgeIndex: number,
): ConnectorCandidate[] {
  const oc = getOC();
  const candidates: ConnectorCandidate[] = [];
  const adaptor = new oc.BRepAdaptor_Curve_2(edge.wrapped);
  try {
    if (adaptor.GetType() === oc.GeomAbs_CurveType.GeomAbs_Circle) {
      const circle = adaptor.Circle();
      const axis = circle.Axis();
      const position = circle.Position();
      try {
        candidates.push({
          id: `face-${faceId}-circle-${edgeIndex}`,
          faceId,
          kind: "circle-center",
          label: `Circular edge ${edgeIndex + 1} center`,
          origin: deleteAfterPointTuple(circle.Location()),
          ...connectorAxes(
            deleteAfterPointTuple(axis.Direction()),
            deleteAfterPointTuple(position.XDirection()),
          ),
        });
      } finally {
        axis.delete();
        position.delete();
        circle.delete();
      }
    } else if (adaptor.GetType() === oc.GeomAbs_CurveType.GeomAbs_Ellipse) {
      const ellipse = adaptor.Ellipse();
      const axis = ellipse.Axis();
      const position = ellipse.Position();
      try {
        candidates.push({
          id: `face-${faceId}-ellipse-${edgeIndex}`,
          faceId,
          kind: "ellipse-center",
          label: `Elliptical edge ${edgeIndex + 1} center`,
          origin: deleteAfterPointTuple(ellipse.Location()),
          ...connectorAxes(
            deleteAfterPointTuple(axis.Direction()),
            deleteAfterPointTuple(position.XDirection()),
          ),
        });
      } finally {
        axis.delete();
        position.delete();
        ellipse.delete();
      }
    }
  } catch (error) {
    throw new Error(
      `face ${faceId} edge ${edgeIndex + 1} analytic curve: ${errorDescription(error)}`,
    );
  } finally {
    adaptor.delete();
  }

  candidates.push({
    id: `face-${faceId}-edge-${edgeIndex}`,
    faceId,
    kind: "edge-midpoint",
    label: `Edge ${edgeIndex + 1} midpoint`,
    origin: deleteAfterVectorTuple(edge.pointAt(0.5)),
    ...frameAtEdge(edge, 0.5, faceFrame),
  });
  candidates.push({
    id: `face-${faceId}-vertex-${edgeIndex}-a`,
    faceId,
    kind: "vertex",
    label: `Vertex ${edgeIndex + 1}A`,
    origin: deleteAfterVectorTuple(edge.startPoint),
    ...frameAtEdge(edge, 0, faceFrame),
  });
  candidates.push({
    id: `face-${faceId}-vertex-${edgeIndex}-b`,
    faceId,
    kind: "vertex",
    label: `Vertex ${edgeIndex + 1}B`,
    origin: deleteAfterVectorTuple(edge.endPoint),
    ...frameAtEdge(edge, 1, faceFrame),
  });
  return candidates;
}

function appendAxialStations(
  candidates: ConnectorCandidate[],
  faceId: number,
  kind: "cylinder-axis" | "cone-axis",
  axisOrigin: Vec3,
  axisDirection: Vec3,
  frame: ConnectorAxes,
  firstV: number,
  lastV: number,
  axialScale = 1,
): void {
  cylinderAxisStations(firstV, lastV).forEach((station) => {
    addUniqueCandidate(candidates, {
      id: `face-${faceId}-${kind}-${station.role}`,
      faceId,
      kind,
      label: `Exact ${kind === "cone-axis" ? "cone" : "cylinder"} axis ${station.role}`,
      origin: pointAlongAxis(
        axisOrigin,
        axisDirection,
        station.parameter * axialScale,
      ),
      ...frame,
    });
  });
}

function extractFaceTopology(face: Face, faceId: number): FaceTopologyData {
  const oc = getOC();
  let center: Vec3;
  try {
    center = deleteAfterVectorTuple(face.center);
  } catch (error) {
    throw new Error(`face ${faceId} center: ${errorDescription(error)}`);
  }

  let adaptor;
  try {
    adaptor = new oc.BRepAdaptor_Surface_2(face.wrapped, true);
  } catch (error) {
    throw new Error(`face ${faceId} adaptor: ${errorDescription(error)}`);
  }

  const candidates: ConnectorCandidate[] = [];
  let surfaceType = face.geomType;
  let faceFrame = connectorAxes([0, 0, 1], [1, 0, 0]);

  try {
    const type = adaptor.GetType();
    if (type === oc.GeomAbs_SurfaceType.GeomAbs_Plane) {
      surfaceType = "PLANE";
      const plane = adaptor.Plane();
      const position = plane.Position();
      try {
        faceFrame = connectorAxes(
          deleteAfterPointTuple(position.Direction()),
          deleteAfterPointTuple(position.XDirection()),
        );
      } finally {
        position.delete();
        plane.delete();
      }
    } else if (type === oc.GeomAbs_SurfaceType.GeomAbs_Cylinder) {
      // Replicad intentionally keeps OCCT's historical French spelling.
      surfaceType = "CYLINDRE";
      const cylinder = adaptor.Cylinder();
      const axis = cylinder.Axis();
      const position = cylinder.Position();
      try {
        const axisDirection = deleteAfterPointTuple(axis.Direction());
        faceFrame = connectorAxes(
          axisDirection,
          deleteAfterPointTuple(position.XDirection()),
        );
        appendAxialStations(
          candidates,
          faceId,
          "cylinder-axis",
          deleteAfterPointTuple(axis.Location()),
          axisDirection,
          faceFrame,
          adaptor.FirstVParameter(),
          adaptor.LastVParameter(),
        );
      } finally {
        position.delete();
        axis.delete();
        cylinder.delete();
      }
    } else if (type === oc.GeomAbs_SurfaceType.GeomAbs_Cone) {
      surfaceType = "CONE";
      const cone = adaptor.Cone();
      const axis = cone.Axis();
      const position = cone.Position();
      try {
        const axisDirection = deleteAfterPointTuple(axis.Direction());
        faceFrame = connectorAxes(
          axisDirection,
          deleteAfterPointTuple(position.XDirection()),
        );
        appendAxialStations(
          candidates,
          faceId,
          "cone-axis",
          deleteAfterPointTuple(axis.Location()),
          axisDirection,
          faceFrame,
          adaptor.FirstVParameter(),
          adaptor.LastVParameter(),
          Math.cos(cone.SemiAngle()),
        );
      } finally {
        position.delete();
        axis.delete();
        cone.delete();
      }
    } else if (type === oc.GeomAbs_SurfaceType.GeomAbs_Sphere) {
      surfaceType = "SPHERE";
      const sphere = adaptor.Sphere();
      const position = sphere.Position();
      try {
        faceFrame = connectorAxes(
          deleteAfterPointTuple(position.Direction()),
          deleteAfterPointTuple(position.XDirection()),
        );
        addUniqueCandidate(candidates, {
          id: `face-${faceId}-sphere-center`,
          faceId,
          kind: "sphere-center",
          label: "Exact sphere center",
          origin: deleteAfterPointTuple(sphere.Location()),
          ...faceFrame,
        });
      } finally {
        position.delete();
        sphere.delete();
      }
    } else if (type === oc.GeomAbs_SurfaceType.GeomAbs_Torus) {
      surfaceType = "TORUS";
      const torus = adaptor.Torus();
      const position = torus.Position();
      try {
        faceFrame = connectorAxes(
          deleteAfterPointTuple(position.Direction()),
          deleteAfterPointTuple(position.XDirection()),
        );
        addUniqueCandidate(candidates, {
          id: `face-${faceId}-torus-center`,
          faceId,
          kind: "torus-center",
          label: "Exact torus center and revolution axis",
          origin: deleteAfterPointTuple(torus.Location()),
          ...faceFrame,
        });
      } finally {
        position.delete();
        torus.delete();
      }
    } else {
      try {
        faceFrame = connectorAxes(
          deleteAfterVectorTuple(
            face.normalAt([center[0], center[1], center[2]]),
          ),
          [1, 0, 0],
        );
      } catch {
        // Unsupported freeform surfaces remain renderable and keep their
        // edge/vertex inference even without a stable center normal.
      }
    }
  } catch (error) {
    throw new Error(
      `face ${faceId} ${surfaceType} analytic surface: ${errorDescription(error)}`,
    );
  } finally {
    adaptor.delete();
  }

  addUniqueCandidate(candidates, {
    id: `face-${faceId}-center`,
    faceId,
    kind: "face-center",
    label: `${surfaceType.toLowerCase()} face center`,
    origin: center,
    ...faceFrame,
  });

  face.edges.forEach((edge, edgeIndex) => {
    try {
      try {
        curveCandidates(faceId, edge, faceFrame, edgeIndex).forEach((candidate) =>
          addUniqueCandidate(candidates, candidate),
        );
      } catch {
        // One unsupported curve must not discard the face or Part.
      }
    } finally {
      edge.delete();
    }
  });

  return { id: faceId, surfaceType, candidates };
}

export function extractExactTopology(shape: AnyShape): FaceTopologyData[] {
  const oc = getOC();
  const explorer = new oc.TopExp_Explorer_2(
    shape.wrapped,
    oc.TopAbs_ShapeEnum.TopAbs_FACE as TopAbs_ShapeEnum,
    oc.TopAbs_ShapeEnum.TopAbs_SHAPE as TopAbs_ShapeEnum,
  );
  const topology: FaceTopologyData[] = [];
  const hashes = new Set<number>();
  try {
    while (explorer.More()) {
      const current = explorer.Current();
      const hash = current.HashCode(2_147_483_647);
      if (!hashes.has(hash)) {
        hashes.add(hash);
        const face = cast(oc.TopoDS.Face_1(current)) as Face;
        try {
          try {
            topology.push(extractFaceTopology(face, hash));
          } catch {
            topology.push({ id: hash, surfaceType: "UNAVAILABLE", candidates: [] });
          }
        } finally {
          face.delete();
        }
      }
      explorer.Next();
    }
  } finally {
    explorer.delete();
  }
  return topology;
}

