import * as THREE from "three/webgpu";
import type { CADDisplayStyle } from "./cad-appearance-store";

export interface CADDisplayStylePolicy {
  surfaceWireframe: boolean;
  surfaceOpacity: number;
  surfaceDepthWrite: boolean;
  edgesVisible: boolean;
  edgeOpacity: number;
  masksSurfaceWithBackground: boolean;
}

export function cadDisplayStylePolicy(
  style: CADDisplayStyle,
  edgesEnabled: boolean,
): CADDisplayStylePolicy {
  switch (style) {
    case "shaded":
      return { surfaceWireframe: false, surfaceOpacity: 1, surfaceDepthWrite: true, edgesVisible: false, edgeOpacity: 0, masksSurfaceWithBackground: false };
    case "shaded-edges":
      return { surfaceWireframe: false, surfaceOpacity: 1, surfaceDepthWrite: true, edgesVisible: edgesEnabled, edgeOpacity: 0.8, masksSurfaceWithBackground: false };
    case "wireframe":
      return { surfaceWireframe: true, surfaceOpacity: 1, surfaceDepthWrite: true, edgesVisible: false, edgeOpacity: 0, masksSurfaceWithBackground: false };
    case "hidden-line":
      return { surfaceWireframe: false, surfaceOpacity: 1, surfaceDepthWrite: true, edgesVisible: true, edgeOpacity: 1, masksSurfaceWithBackground: true };
    case "ghost":
      return { surfaceWireframe: false, surfaceOpacity: 0.22, surfaceDepthWrite: false, edgesVisible: edgesEnabled, edgeOpacity: 0.42, masksSurfaceWithBackground: false };
  }
}

/** Shared CAD viewport materials. Keep visual policy out of interaction code. */
export const viewportMaterials = {
  part: new THREE.MeshStandardMaterial({
    color: 0x79a9c2,
    metalness: 0.05,
    roughness: 0.56,
    side: THREE.DoubleSide,
  }),
  hoveredFace: new THREE.MeshStandardMaterial({
    color: 0x33d0ff,
    emissive: 0x063948,
    metalness: 0.03,
    roughness: 0.42,
    side: THREE.DoubleSide,
  }),
  selectedFace: new THREE.MeshStandardMaterial({
    color: 0xffac39,
    emissive: 0x4f2100,
    metalness: 0.04,
    roughness: 0.38,
    side: THREE.DoubleSide,
  }),
  connector: new THREE.MeshStandardMaterial({
    color: 0x1598e8,
    emissive: 0x063047,
    roughness: 0.35,
  }),
  hoveredConnector: new THREE.MeshStandardMaterial({
    color: 0x42d8ff,
    emissive: 0x0a5269,
    roughness: 0.3,
  }),
  selectedConnector: new THREE.MeshStandardMaterial({
    color: 0xffa52f,
    emissive: 0x5b2800,
    roughness: 0.3,
  }),
  candidateOutline: new THREE.MeshBasicMaterial({
    color: 0x59636c,
    side: THREE.DoubleSide,
    depthTest: true,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -2,
  }),
  candidateDot: new THREE.MeshBasicMaterial({
    color: 0xffffff,
    side: THREE.DoubleSide,
    depthTest: true,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -3,
  }),
  connectorRing: new THREE.MeshBasicMaterial({
    color: 0xffffff,
    depthTest: false,
    depthWrite: false,
  }),
} as const;

export function createPartEdgeMaterial(): THREE.LineBasicMaterial {
  return new THREE.LineBasicMaterial({
    color: 0x14242d,
    transparent: true,
    opacity: 0.8,
  });
}
