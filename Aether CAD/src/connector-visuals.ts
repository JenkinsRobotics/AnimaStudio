import * as THREE from "three/webgpu";
import { connectorMatrix, type ConnectorCandidate } from "./aether-core";
import { viewportMaterials } from "./viewport-appearance";

export interface ConnectorMarker {
  root: THREE.Group;
  hitTarget: THREE.Mesh;
}

/** Builds the persistent XYZ frame shown for an authored connector. */
export function createConnectorGizmo(
  scale: number,
  centerMaterial: THREE.Material,
): ConnectorMarker {
  const root = new THREE.Group();
  const origin = new THREE.Vector3();
  const headLength = scale * 0.25;
  const headWidth = scale * 0.12;
  root.add(
    new THREE.ArrowHelper(
      new THREE.Vector3(1, 0, 0), origin, scale, 0xf04444, headLength, headWidth,
    ),
    new THREE.ArrowHelper(
      new THREE.Vector3(0, 1, 0), origin, scale, 0x2bbf69, headLength, headWidth,
    ),
    new THREE.ArrowHelper(
      new THREE.Vector3(0, 0, 1), origin, scale, 0x236cff, headLength, headWidth,
    ),
  );

  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(scale * 0.3, scale * 0.04, 10, 32),
    viewportMaterials.connectorRing,
  );
  const hitTarget = new THREE.Mesh(
    new THREE.SphereGeometry(scale * 0.1, 18, 12),
    centerMaterial,
  );
  root.add(ring, hitTarget);
  root.traverse((object) => {
    object.renderOrder = 110;
    if (!("material" in object)) return;
    const material = object.material;
    const materials = Array.isArray(material) ? material : [material];
    materials.forEach((item) => {
      if (!(item instanceof THREE.Material)) return;
      item.depthTest = false;
      item.depthWrite = false;
    });
  });
  return { root, hitTarget };
}

/**
 * Creates inexpensive, face-aligned 2D snap nodes for one exact B-Rep face.
 * Instancing keeps the candidate cloud to two draw calls regardless of count.
 */
export function createCandidateCloud(
  candidates: ConnectorCandidate[],
  partWorld: THREE.Matrix4,
  markerScale: number,
): THREE.Group {
  const cloud = new THREE.Group();
  cloud.userData.transient = true;
  cloud.matrixAutoUpdate = false;
  cloud.matrix.copy(partWorld);

  const outlines = new THREE.InstancedMesh(
    new THREE.CircleGeometry(markerScale * 0.045, 16),
    viewportMaterials.candidateOutline,
    candidates.length,
  );
  const dots = new THREE.InstancedMesh(
    new THREE.CircleGeometry(markerScale * 0.03, 16),
    viewportMaterials.candidateDot,
    candidates.length,
  );
  candidates.forEach((candidate, index) => {
    const frame = connectorMatrix(candidate);
    outlines.setMatrixAt(
      index,
      frame.clone().multiply(
        new THREE.Matrix4().makeTranslation(0, 0, markerScale * 0.002),
      ),
    );
    dots.setMatrixAt(
      index,
      frame.clone().multiply(
        new THREE.Matrix4().makeTranslation(0, 0, markerScale * 0.003),
      ),
    );
  });
  outlines.instanceMatrix.needsUpdate = true;
  dots.instanceMatrix.needsUpdate = true;
  outlines.renderOrder = 100;
  dots.renderOrder = 101;
  cloud.add(outlines, dots);
  return cloud;
}

export function disposeTransientGeometry(root: THREE.Object3D): void {
  root.traverse((object) => {
    if (object instanceof THREE.Mesh || object instanceof THREE.Points) {
      object.geometry.dispose();
    }
    if (object instanceof THREE.Line) object.geometry.dispose();
  });
}
