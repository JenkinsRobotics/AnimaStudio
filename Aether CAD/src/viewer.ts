import { createPlaneVisual } from "./plane-visual";
import { rollbackPosition } from "@aether/core/document";
import type { PartDocument as PlaneDocument } from "@aether/core/document";
import * as THREE from "three/webgpu";
import { MOUSE } from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import type { AssemblyPartRow } from "./assembly-tree";
import {
  connectorKindPreference,
  connectorMatrix,
  FastenedMateDraft,
  MateConnectorRegistry,
  MateConstraintTracker,
  solveFastenedMate,
  type AppliedMate,
  type ConnectorCandidate,
  type ConnectorKind,
  type FaceRangeData,
  type FaceTopologyData,
  type MateConnector,
  type PartGeometryData,
} from "./aether-core";
import {
  createCandidateCloud,
  createConnectorGizmo,
  disposeTransientGeometry,
  type ConnectorMarker,
} from "./connector-visuals";
import {
  cadDisplayStylePolicy,
  createPartEdgeMaterial,
  viewportMaterials,
} from "./viewport-appearance";
import {
  cameraViewDefinition,
  nudgeCameraBasis,
  rollCameraBasis,
  type CameraQuaternion,
  type StandardCameraView,
} from "./camera-view";
import type { ReferenceGeometryId } from "./reference-geometry";
import type { CADAppearanceSnapshot } from "./cad-appearance-store";
import {
  boxSelectionMode,
  cadSelection,
  normalizedSelectionBox,
  selectionRectangleMatches,
  selectedPartIDs,
  type CADBoxSelectionMode,
  type CADSelectionItem,
  type CADScreenRect,
} from "./cad-selection-store";

interface RenderPart {
  data: PartGeometryData;
  group: THREE.Group;
  surface: THREE.Mesh;
  edges: THREE.LineSegments;
  topology: Map<number, FaceTopologyData>;
  faceRanges: FaceRangeData[];
}

interface CandidateHover {
  kind: "candidate";
  part: RenderPart;
  faceId: number;
  candidate: ConnectorCandidate;
}

interface ConnectorHover {
  kind: "connector";
  connector: MateConnector;
}

type HoverTarget = CandidateHover | ConnectorHover;
interface SelectionHover {
  item: CADSelectionItem;
  part: RenderPart;
  faceId?: number;
}

export type AuthoringTool = "none" | "connector" | "fastened";

export interface HoverPresentation {
  partName: string;
  label: string;
  detail: string;
}

export interface ViewerCallbacks {
  onHover(target: HoverPresentation | null): void;
  onStatus(message: string, tone?: "normal" | "error" | "success"): void;
  onStateChanged(): void;
  onMateApplied(mate: AppliedMate): void;
  onCameraChanged(orientation: CameraQuaternion): void;
}

export interface TopologyInferenceSummary {
  faceCount: number;
  candidateCount: number;
  candidatesByKind: Record<ConnectorKind, number>;
}

const emptyCandidateCounts = (): Record<ConnectorKind, number> => ({
  "face-center": 0,
  "edge-midpoint": 0,
  vertex: 0,
  "circle-center": 0,
  "ellipse-center": 0,
  "cylinder-axis": 0,
  "cone-axis": 0,
  "sphere-center": 0,
  "torus-center": 0,
});

export class MateViewport {
  private readonly renderer: THREE.WebGPURenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera = new THREE.PerspectiveCamera(42, 1, 0.1, 1_000_000);
  private readonly controls: OrbitControls;
  private readonly modelRoot = new THREE.Group();
  private readonly overlayRoot = new THREE.Group();
  private readonly referenceRoot = new THREE.Group();
  private sketchPlaneSelection = false;
  setSketchPlaneSelection(active:boolean) { this.sketchPlaneSelection=active; }

  private readonly referenceObjects = new Map<ReferenceGeometryId, THREE.Object3D>();
  private readonly grid: THREE.GridHelper;
  private readonly hemisphereLight: THREE.HemisphereLight;
  private readonly keyLight: THREE.DirectionalLight;
  private readonly fillLight: THREE.DirectionalLight;
  private readonly rimLight: THREE.DirectionalLight;
  private readonly floor: THREE.Mesh<THREE.PlaneGeometry, THREE.MeshStandardMaterial>;
  private readonly raycaster = new THREE.Raycaster();
  private readonly pointer = new THREE.Vector2();
  private readonly parts = new Map<string, RenderPart>();
  private readonly constraints = new MateConstraintTracker();
  private readonly connectorRegistry = new MateConnectorRegistry();
  private readonly mateDraft = new FastenedMateDraft();
  private readonly connectorMarkers = new Map<string, ConnectorMarker>();
  private readonly usedConnectorIds = new Set<string>();
  private readonly initialMatrices = new Map<string, THREE.Matrix4>();
  private hover: HoverTarget | null = null;
  private selectionHover: SelectionHover | null = null;
  private tool: AuthoringTool = "none";
  private markerScale = 10;
  private pointerDown: { x: number; y: number } | null = null;
  private appearance: CADAppearanceSnapshot | null = null;

  constructor(
    private readonly container: HTMLElement,
    private readonly callbacks: ViewerCallbacks,
  ) {
    this.renderer = new THREE.WebGPURenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.setAnimationLoop(() => this.render());
    this.renderer.domElement.className = "viewport-canvas";
    this.container.append(this.renderer.domElement);

    this.scene.background = new THREE.Color(0x151718);
    this.scene.add(this.referenceRoot, this.modelRoot, this.overlayRoot);
    this.camera.position.set(180, 140, 220);
    this.camera.up.set(0, 1, 0);

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.08;
    this.controls.screenSpacePanning = true;
    this.controls.mouseButtons.LEFT = -1 as THREE.MOUSE;
    this.controls.mouseButtons.MIDDLE = MOUSE.PAN;
    this.controls.mouseButtons.RIGHT = MOUSE.ROTATE;
    this.controls.addEventListener("change", () => this.publishCameraOrientation());

    this.hemisphereLight = new THREE.HemisphereLight(0xffffff, 0x6f8291, 2.2);
    this.keyLight = new THREE.DirectionalLight(0xffffff, 3.2);
    this.keyLight.position.set(4, 7, 5);
    this.fillLight = new THREE.DirectionalLight(0xb9dcff, 1.25);
    this.fillLight.position.set(-5, 2, -4);
    this.rimLight = new THREE.DirectionalLight(0x91bfff, 0.65);
    this.rimLight.position.set(2, 4, -6);
    this.keyLight.castShadow = true;
    this.keyLight.shadow.mapSize.set(2048, 2048);
    this.keyLight.shadow.camera.near = 0.1;
    this.keyLight.shadow.camera.far = 4_000;
    this.scene.add(this.hemisphereLight, this.keyLight, this.fillLight, this.rimLight);

    this.grid = new THREE.GridHelper(1_600, 64, 0x465762, 0x252d32);
    this.grid.position.y = -0.01;
    this.floor = new THREE.Mesh(
      new THREE.PlaneGeometry(1_600, 1_600),
      new THREE.MeshStandardMaterial({ color: 0x1a1d1f, roughness: 0.9, metalness: 0 }),
    );
    this.floor.rotation.x = -Math.PI / 2;
    this.floor.position.y = -0.02;
    this.floor.receiveShadow = true;
    this.floor.visible = false;
    this.scene.add(this.floor, this.grid);
    this.buildReferenceGeometry();

    this.renderer.domElement.addEventListener("pointermove", (event) =>
      this.pointerMoved(event),
    );
    this.renderer.domElement.addEventListener("pointerdown", (event) => {
      if (event.button === 0) this.pointerDown = { x: event.clientX, y: event.clientY };
    });
    this.renderer.domElement.addEventListener("pointerup", (event) =>
      this.pointerUp(event),
    );
    this.renderer.domElement.addEventListener("pointerleave", () => {
      if (this.tool !== "none") return;
      this.selectionHover = null;
      cadSelection.dispatch({ type: "set-hovered", item: null });
      cadSelection.dispatch({ type: "set-box", box: null });
      this.resetFaceMaterials();
      this.callbacks.onHover(null);
    });
    this.renderer.domElement.addEventListener("contextmenu", (event) =>
      event.preventDefault(),
    );
    new ResizeObserver(() => this.resize()).observe(this.container);
    this.resize();
    this.publishCameraOrientation();
  }

  get backendLabel(): string {
    return "gpu" in navigator ? "Three.js WebGPU" : "Three.js WebGL 2 fallback";
  }

  get activeTool(): AuthoringTool {
    return this.tool;
  }

  get firstMateConnector(): MateConnector | null {
    return this.mateDraft.movingConnector;
  }

  setAppearance(appearance: CADAppearanceSnapshot): void {
    this.appearance = appearance;
    const backgrounds = {
      graphite: 0x151718,
      midnight: 0x0c1c29,
      slate: 0x2a3238,
    } as const;
    const finishes = {
      matte: { roughness: 0.78, metalness: 0.02 },
      satin: { roughness: 0.56, metalness: 0.05 },
      gloss: { roughness: 0.24, metalness: 0.08 },
    } as const;
    const background = backgrounds[appearance.background];
    const policy = cadDisplayStylePolicy(appearance.displayStyle, appearance.edgesVisible);
    this.scene.background = new THREE.Color(background);
    this.grid.visible = appearance.floorMode === "grid" || appearance.floorMode === "both";
    this.floor.visible = appearance.floorMode === "floor" || appearance.floorMode === "both";
    this.floor.receiveShadow = appearance.contactShadowsVisible;
    this.keyLight.castShadow = appearance.contactShadowsVisible;
    this.floor.material.color.setHex(background).offsetHSL(0, 0, 0.025);
    const surfaceMaterials = [
      viewportMaterials.part,
      viewportMaterials.hoveredFace,
      viewportMaterials.selectedFace,
    ];
    surfaceMaterials.forEach((material) => {
      material.wireframe = policy.surfaceWireframe;
      material.transparent = policy.surfaceOpacity < 1;
      material.opacity = policy.surfaceOpacity;
      material.depthWrite = policy.surfaceDepthWrite;
      material.needsUpdate = true;
    });
    viewportMaterials.part.color.setHex(
      policy.masksSurfaceWithBackground ? background : 0x79a9c2,
    );
    viewportMaterials.part.emissive.setHex(
      policy.masksSurfaceWithBackground ? background : 0x000000,
    );
    viewportMaterials.part.emissiveIntensity = policy.masksSurfaceWithBackground ? 1 : 0;
    this.parts.forEach((part) => {
      part.edges.visible = policy.edgesVisible;
      const material = part.edges.material as THREE.LineBasicMaterial;
      material.opacity = policy.edgeOpacity;
      material.transparent = policy.edgeOpacity < 1;
      material.needsUpdate = true;
    });
    const finish = finishes[appearance.materialFinish];
    viewportMaterials.part.roughness = finish.roughness;
    viewportMaterials.part.metalness = finish.metalness;
    const lightingProfiles = {
      studio: { hemisphere: 2.2, key: 3.2, fill: 1.25, rim: 0.65, sky: 0xffffff, ground: 0x6f8291, keyColor: 0xffffff, fillColor: 0xb9dcff, rimColor: 0x91bfff },
      softbox: { hemisphere: 2.75, key: 2.15, fill: 1.95, rim: 0.4, sky: 0xffffff, ground: 0x91a0aa, keyColor: 0xfff7ed, fillColor: 0xd7e9ff, rimColor: 0xc6dfff },
      daylight: { hemisphere: 2.45, key: 4.1, fill: 0.8, rim: 0.3, sky: 0xdcefff, ground: 0x78917b, keyColor: 0xfff2cf, fillColor: 0xb9dcff, rimColor: 0xd8efff },
      "dark-room": { hemisphere: 0.72, key: 2.35, fill: 0.3, rim: 1.25, sky: 0x627d96, ground: 0x111820, keyColor: 0xdce9ff, fillColor: 0x607da5, rimColor: 0x62b6ff },
    } as const;
    const profile = lightingProfiles[appearance.lightingPreset];
    const lightScale = appearance.environmentPercent / 100;
    this.hemisphereLight.color.setHex(profile.sky);
    this.hemisphereLight.groundColor.setHex(profile.ground);
    this.keyLight.color.setHex(profile.keyColor);
    this.fillLight.color.setHex(profile.fillColor);
    this.rimLight.color.setHex(profile.rimColor);
    this.hemisphereLight.intensity = profile.hemisphere * lightScale;
    this.keyLight.intensity = profile.key * lightScale;
    this.fillLight.intensity = profile.fill * lightScale;
    this.rimLight.intensity = profile.rim * lightScale;
  }

  selectedSketchFrame(): import("@aether/core/sketch").SketchFrame | null {
    const selected=cadSelection.snapshot().items.find(item=>item.kind==="face");
    if(!selected || selected.faceId===undefined) return null;
    const part=this.parts.get(selected.partId), topology=part?.topology.get(selected.faceId);
    if(!part || topology?.surfaceType!=="PLANE") return null;
    const candidate=topology.candidates.find(c=>c.kind==="face-center");
    if(!candidate) return null;
    part.group.updateWorldMatrix(true,false);
    const origin=new THREE.Vector3(...candidate.origin).applyMatrix4(part.group.matrixWorld);
    const x=new THREE.Vector3(...candidate.xAxis).transformDirection(part.group.matrixWorld);
    const normal=new THREE.Vector3(...candidate.zAxis).transformDirection(part.group.matrixWorld);
    return {originMillimeters:[origin.x,origin.y,origin.z],xDirection:[x.x,x.y,x.z],normal:[normal.x,normal.y,normal.z]};
  }

  getPartRows(): AssemblyPartRow[] {
    const selectedParts = selectedPartIDs(cadSelection.snapshot());
    return [...this.parts.values()].map((part) => ({
      id: part.data.id,
      name: part.data.name,
      sourceDocumentId: part.data.sourceDocumentId,
      sourceName: part.data.sourceName,
      constrained: this.constraints.isConstrained(part.data.id),
      visible: part.group.visible,
      selected: selectedParts.has(part.data.id),
    }));
  }

  selectPart(id: string): void {
    const part = this.parts.get(id);
    if (!part) return;
    cadSelection.dispatch({
      type: "toggle",
      items: [{ id: `body:${id}`, kind: "body", partId: id, label: part.data.name }],
    });
    this.resetFaceMaterials();
    this.callbacks.onStateChanged();
  }

  refreshSelectionAppearance(): void {
    if (cadSelection.snapshot().hovered === null && this.selectionHover !== null) {
      this.selectionHover = null;
      this.callbacks.onHover(null);
    }
    this.resetFaceMaterials();
  }

  setPartVisibility(id: string, visible: boolean): void {
    const part = this.parts.get(id);
    if (!part) return;
    part.group.visible = visible;
    if (!visible) {
      cadSelection.dispatch({
        type: "replace",
        items: cadSelection.snapshot().items.filter((item) => item.partId !== id),
      });
    }
    this.resetFaceMaterials();
    this.callbacks.onStateChanged();
    this.callbacks.onStatus(`${part.data.name} is now ${visible ? "visible" : "hidden"}.`);
  }

  getConnectorRows(): MateConnector[] {
    return this.connectorRegistry.list();
  }

  getTopologyInferenceSummary(): TopologyInferenceSummary {
    const summary: TopologyInferenceSummary = {
      faceCount: 0,
      candidateCount: 0,
      candidatesByKind: emptyCandidateCounts(),
    };
    this.parts.forEach((part) => {
      part.topology.forEach((face) => {
        summary.faceCount += 1;
        summary.candidateCount += face.candidates.length;
        face.candidates.forEach((candidate) => {
          summary.candidatesByKind[candidate.kind] += 1;
        });
      });
    });
    return summary;
  }

  /** Adds one STEP document as an assembly while preserving all solid offsets. */
  addModel(parts: PartGeometryData[]): void {
    if (parts.length === 0) return;
    const batchBounds = new THREE.Box3();
    parts.forEach((part) => batchBounds.union(this.localBounds(part)));

    const placement = new THREE.Matrix4();
    if (this.parts.size > 0) {
      const existing = this.renderedPartBounds();
      const existingSize = existing.getSize(new THREE.Vector3());
      const batchSize = batchBounds.getSize(new THREE.Vector3());
      const gap = Math.max(existingSize.length(), batchSize.length()) * 0.08 + 10;
      placement.makeTranslation(existing.max.x - batchBounds.min.x + gap, 0, 0);
    }

    parts.forEach((part) => this.addPart(part, placement));
    this.callbacks.onStateChanged();
  }

  private assemblyPreviewIDs = new Set<string>();
  replaceAssemblyBodies(bodies: {data:PartGeometryData;positionMillimeters:readonly number[];quaternion:readonly number[]}[]): void {
    for(const id of this.assemblyPreviewIDs){const part=this.parts.get(id);if(part)this.removeRenderedPart(part);}
    this.assemblyPreviewIDs.clear();
    for(const body of bodies){
      const placement=new THREE.Matrix4().compose(new THREE.Vector3(...body.positionMillimeters as [number,number,number]),new THREE.Quaternion(...body.quaternion as [number,number,number,number]),new THREE.Vector3(1,1,1));
      this.addPart(body.data,placement);this.assemblyPreviewIDs.add(body.data.id);
    }
    this.callbacks.onStateChanged();
  }
  removeAuthoredPart(id:string):void {const part=this.parts.get(id);if(part)this.removeRenderedPart(part);}

  /** Replaces one authored Body after feature-history evaluation. */
  async capturePrintImage(): Promise<string> {
    await this.renderer.renderAsync(this.scene, this.camera);
    return this.renderer.domElement.toDataURL("image/png");
  }

  replaceAuthoredPart(data: PartGeometryData, replacingPartId?: string): void {
    const existing = this.parts.get(replacingPartId ?? data.id);
    const placement = existing?.group.matrix.clone() ?? new THREE.Matrix4();
    if (existing) this.removeRenderedPart(existing);
    this.addPart(data, placement);
    cadSelection.dispatch({
      type: "replace",
      items: [{ id: `body:${data.id}`, kind: "body", partId: data.id, label: data.name }],
    });
    this.callbacks.onStateChanged();
  }

  setTool(tool: AuthoringTool): void {
    this.tool = tool;
    this.selectionHover = null;
    cadSelection.dispatch({ type: "set-hovered", item: null });
    cadSelection.dispatch({ type: "set-box", box: null });
    this.mateDraft.clear();
    this.hover = null;
    this.clearTransientOverlay();
    this.resetFaceMaterials();
    this.refreshConnectorMaterials();
    const message =
      tool === "connector"
        ? "Place Connector: hover exact topology, then click an inferred anchor."
        : tool === "fastened"
          ? "Fastened Mate: choose the moving connector, then the target connector."
          : "Authoring tool cancelled.";
    this.callbacks.onStatus(message);
    this.callbacks.onHover(null);
    this.callbacks.onStateChanged();
  }

  selectConnectorForMate(id: string): void {
    if (this.tool !== "fastened") {
      this.callbacks.onStatus("Activate Fastened Mate before selecting connectors.", "error");
      return;
    }
    const connector = this.connectorRegistry.get(id);
    if (connector) this.acceptSavedConnector(connector);
  }

  removeConnector(id: string): void {
    if (this.usedConnectorIds.has(id)) {
      this.callbacks.onStatus("Clear the mate before deleting one of its connectors.", "error");
      return;
    }
    const marker = this.connectorMarkers.get(id);
    if (marker) {
      marker.root.removeFromParent();
      disposeTransientGeometry(marker.root);
      this.connectorMarkers.delete(id);
    }
    this.connectorRegistry.remove(id);
    if (this.mateDraft.movingConnector?.id === id) this.mateDraft.clear();
    this.callbacks.onStateChanged();
    this.callbacks.onStatus("Mate connector deleted.");
  }

  clearMates(): void {
    this.constraints.clear();
    this.mateDraft.clear();
    this.usedConnectorIds.clear();
    for (const [id, part] of this.parts) {
      part.group.matrix.copy(this.initialMatrices.get(id) ?? new THREE.Matrix4());
      part.group.updateMatrixWorld(true);
    }
    this.clearTransientOverlay();
    this.resetFaceMaterials();
    this.refreshConnectorMaterials();
    this.callbacks.onStateChanged();
    this.callbacks.onStatus(
      "All mates cleared; connector anchors remain attached to their Parts.",
    );
  }

  frameAll(): void {
    const bounds = this.renderedPartBounds();
    if (bounds.isEmpty()) return;
    const size = bounds.getSize(new THREE.Vector3());
    const center = bounds.getCenter(new THREE.Vector3());
    const diameter = Math.max(size.x, size.y, size.z, 1);
    this.markerScale = Math.max(diameter * 0.1, 2);
    this.controls.target.copy(center);
    const direction = new THREE.Vector3(1, 0.72, 1).normalize();
    this.camera.position.copy(center).addScaledVector(direction, diameter * 1.8);
    this.camera.near = Math.max(diameter / 10_000, 0.01);
    this.camera.far = Math.max(diameter * 100, 10_000);
    this.camera.updateProjectionMatrix();
    this.controls.update();
  }

  setCameraView(view: StandardCameraView): void {
    const definition = cameraViewDefinition(view);
    const bounds = this.renderedPartBounds();
    const center = bounds.isEmpty()
      ? this.controls.target.clone()
      : bounds.getCenter(new THREE.Vector3());
    const size = bounds.isEmpty()
      ? new THREE.Vector3(100, 100, 100)
      : bounds.getSize(new THREE.Vector3());
    const distance = Math.max(
      this.camera.position.distanceTo(this.controls.target),
      Math.max(size.x, size.y, size.z, 1) * 1.8,
    );
    const direction = new THREE.Vector3(...definition.direction).normalize();
    this.camera.up.set(...definition.up);
    this.controls.target.copy(center);
    this.camera.position.copy(center).addScaledVector(direction, distance);
    this.camera.lookAt(center);
    this.controls.update();
    this.callbacks.onStatus(`${definition.label} view.`);
  }

  nudgeCamera(horizontalSteps: number, verticalSteps: number): void {
    const offset = this.camera.position.clone().sub(this.controls.target);
    const distance = Math.max(offset.length(), 1);
    const basis = nudgeCameraBasis(
      {
        direction: [offset.x / distance, offset.y / distance, offset.z / distance],
        up: [this.camera.up.x, this.camera.up.y, this.camera.up.z],
      },
      horizontalSteps * Math.PI / 12,
      verticalSteps * Math.PI / 12,
    );
    this.camera.position.copy(this.controls.target).addScaledVector(
      new THREE.Vector3(...basis.direction),
      distance,
    );
    this.camera.up.set(...basis.up);
    this.camera.lookAt(this.controls.target);
    this.controls.update();
    this.callbacks.onStatus("View nudged 15°.");
  }

  rollCamera(quarterTurns: number): void {
    const offset = this.camera.position.clone().sub(this.controls.target).normalize();
    const basis = rollCameraBasis(
      {
        direction: [offset.x, offset.y, offset.z],
        up: [this.camera.up.x, this.camera.up.y, this.camera.up.z],
      },
      quarterTurns * Math.PI / 2,
    );
    this.camera.up.set(...basis.up);
    this.camera.lookAt(this.controls.target);
    this.controls.update();
    this.callbacks.onStatus("View rolled 90°.");
  }

  setReferenceGeometryVisibility(id: ReferenceGeometryId, visible: boolean): void {
    const object = this.referenceObjects.get(id);
    if (!object) return;
    object.visible = visible;
    this.callbacks.onStatus(`${object.name} ${visible ? "shown" : "hidden"}.`);
  }

  private addPart(data: PartGeometryData, placement: THREE.Matrix4): void {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(data.vertices, 3));
    geometry.setAttribute("normal", new THREE.BufferAttribute(data.normals, 3));
    geometry.setIndex(new THREE.BufferAttribute(data.triangles, 1));
    geometry.clearGroups();
    data.faceRanges.forEach((range) => geometry.addGroup(range.start, range.count, 0));
    geometry.computeBoundingBox();
    geometry.computeBoundingSphere();

    const surface = new THREE.Mesh(geometry, [
      viewportMaterials.part,
      viewportMaterials.hoveredFace,
      viewportMaterials.selectedFace,
    ]);
    surface.castShadow = true;
    surface.receiveShadow = true;
    surface.userData.partId = data.id;
    const edgesGeometry = new THREE.BufferGeometry();
    edgesGeometry.setAttribute("position", new THREE.BufferAttribute(data.edgeLines, 3));
    const edges = new THREE.LineSegments(
      edgesGeometry,
      createPartEdgeMaterial(),
    );
    const displayPolicy = cadDisplayStylePolicy(
      this.appearance?.displayStyle ?? "shaded-edges",
      this.appearance?.edgesVisible ?? true,
    );
    edges.visible = displayPolicy.edgesVisible;
    const edgeMaterial = edges.material as THREE.LineBasicMaterial;
    edgeMaterial.opacity = displayPolicy.edgeOpacity;
    edgeMaterial.transparent = displayPolicy.edgeOpacity < 1;

    const group = new THREE.Group();
    group.name = data.name;
    group.matrixAutoUpdate = false;
    group.matrix.copy(placement);
    group.add(surface, edges);
    this.modelRoot.add(group);
    group.updateMatrixWorld(true);
    this.parts.set(data.id, {
      data,
      group,
      surface,
      edges,
      topology: new Map(data.topology.map((face) => [face.id, face])),
      faceRanges: data.faceRanges,
    });
    this.initialMatrices.set(data.id, placement.clone());
  }

  private constructionPlaneKey="";
  private constructionPlanes = new THREE.Group();
  setConstructionPlanes(document:PlaneDocument|null):void {
    const key=JSON.stringify(document?.features.slice(0,rollbackPosition(document)).filter(f=>f.type==="plane")??[]);if(key===this.constructionPlaneKey)return;this.constructionPlaneKey=key;
    for(const child of [...this.constructionPlanes.children]){child.traverse(object=>{if(object instanceof THREE.Mesh||object instanceof THREE.LineSegments){object.geometry.dispose();const materials=Array.isArray(object.material)?object.material:[object.material];for(const material of materials){if('map' in material)(material.map as THREE.Texture|null)?.dispose();material.dispose();}}});this.constructionPlanes.remove(child);}
    if(!this.constructionPlanes.parent)this.referenceRoot.add(this.constructionPlanes);
    for(const feature of document?.features.slice(0,rollbackPosition(document))??[]){
      if(feature.type!=='plane'||feature.suppressed)continue;
      const rotation:[number,number,number]=feature.plane==='XZ'?[-Math.PI/2,0,0]:feature.plane==='YZ'?[0,Math.PI/2,0]:[0,0,0];
      const group=createPlaneVisual(feature.name,0x89aaff,rotation);
      const normal=new THREE.Vector3(0,0,1).applyEuler(group.rotation);
      group.position.copy(normal.multiplyScalar(feature.offsetMillimeters));
      group.updateMatrixWorld(true);
      const x=new THREE.Vector3(1,0,0).applyEuler(group.rotation),n=new THREE.Vector3(0,0,1).applyEuler(group.rotation);
      group.userData.sketchFrame={originMillimeters:group.position.toArray(),xDirection:x.toArray(),normal:n.toArray()};
      this.constructionPlanes.add(group);
    }
  }

  private buildReferenceGeometry(): void {
    const createPlane = (
      id: ReferenceGeometryId,
      name: string,
      color: number,
      rotation: readonly [number, number, number],
    ): void => {
      const group=createPlaneVisual(name,color,rotation);
      group.visible = false;
      this.referenceRoot.add(group);
      this.referenceObjects.set(id, group);
    };

    const origin = new THREE.AxesHelper(45);
    origin.name = "Origin";
    origin.visible = false;
    this.referenceRoot.add(origin);
    this.referenceObjects.set("origin", origin);
    createPlane("top-plane", "Top Plane", 0x4f8dff, [0, 0, 0]);
    createPlane("front-plane", "Front Plane", 0xef6976, [-Math.PI / 2, 0, 0]);
    createPlane("right-plane", "Right Plane", 0x4ccf8a, [0, Math.PI / 2, 0]);
  }

  private publishCameraOrientation(): void {
    const { x, y, z, w } = this.camera.quaternion;
    this.callbacks.onCameraChanged([x, y, z, w]);
  }

  private removeRenderedPart(part: RenderPart): void {
    const relatedConnectors = this.connectorRegistry
      .list()
      .filter((connector) => connector.partId === part.data.id);
    if (relatedConnectors.some((connector) => this.usedConnectorIds.has(connector.id))) {
      this.clearMates();
    }
    relatedConnectors.forEach((connector) => this.removeConnector(connector.id));
    part.group.removeFromParent();
    part.group.traverse((object) => {
      const geometry = (object as THREE.Mesh).geometry;
      if (geometry instanceof THREE.BufferGeometry) geometry.dispose();
    });
    this.parts.delete(part.data.id);
    this.initialMatrices.delete(part.data.id);
    cadSelection.dispatch({
      type: "replace",
      items: cadSelection.snapshot().items.filter((item) => item.partId !== part.data.id),
    });
  }

  private localBounds(data: PartGeometryData): THREE.Box3 {
    const bounds = new THREE.Box3();
    for (let index = 0; index < data.vertices.length; index += 3) {
      bounds.expandByPoint(
        new THREE.Vector3(
          data.vertices[index],
          data.vertices[index + 1],
          data.vertices[index + 2],
        ),
      );
    }
    return bounds;
  }

  private renderedPartBounds(): THREE.Box3 {
    const bounds = new THREE.Box3();
    this.parts.forEach((part) => bounds.expandByObject(part.surface, true));
    return bounds;
  }

  private resize(): void {
    const width = Math.max(this.container.clientWidth, 1);
    const height = Math.max(this.container.clientHeight, 1);
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
  }

  private render(): void {
    this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }

  private pointerMoved(event: PointerEvent): void {
    if (this.tool === "none") {
      if (event.buttons === 0) this.updateSelectionHover(event);
      else if ((event.buttons & 1) === 1) this.updateSelectionBox(event);
      return;
    }
    if (event.buttons !== 0) return;
    this.updatePointer(event);
    if (this.tool === "connector") this.updateCandidateHover(event);
    else this.updateConnectorHover();
  }

  private updateCandidateHover(event: PointerEvent): void {
    const hit = this.raycaster.intersectObjects(
      [...this.parts.values()].map((part) => part.surface),
      false,
    )[0];
    if (!hit || hit.faceIndex === undefined || hit.faceIndex === null) {
      this.setHover(null);
      return;
    }
    const part = this.parts.get(String(hit.object.userData.partId));
    if (!part) return this.setHover(null);
    const faceId = this.faceIdForTriangle(part.faceRanges, hit.faceIndex);
    const topology = faceId === undefined ? undefined : part.topology.get(faceId);
    if (!topology || topology.candidates.length === 0) return this.setHover(null);
    this.setHover({
      kind: "candidate",
      part,
      faceId: topology.id,
      candidate: this.closestCandidate(topology.candidates, part.group, event),
    });
  }

  private updateConnectorHover(): void {
    const hit = this.raycaster.intersectObjects(
      [...this.connectorMarkers.values()].map((marker) => marker.hitTarget),
      false,
    )[0];
    const id = hit ? String(hit.object.userData.connectorId ?? "") : "";
    const connector = id ? this.connectorRegistry.get(id) : undefined;
    this.setHover(connector ? { kind: "connector", connector } : null);
  }

  private pointerUp(event: PointerEvent): void {
    if (event.button !== 0) return;
    const down = this.pointerDown;
    this.pointerDown = null;
    if (!down) return;
    const distance = Math.hypot(event.clientX - down.x, event.clientY - down.y);
    if (this.tool === "none") {
      if (distance > 4) this.completeBoxSelection(event);
      else this.commitSelectionClick(event);
      cadSelection.dispatch({ type: "set-box", box: null });
      return;
    }
    if (distance > 4) return;
    if (!this.hover) return;
    if (this.tool === "connector" && this.hover.kind === "candidate") {
      this.createConnector(this.hover);
    } else if (this.tool === "fastened" && this.hover.kind === "connector") {
      this.acceptSavedConnector(this.hover.connector);
    }
  }

  private updateSelectionHover(event: PointerEvent): void {
    const next = this.selectionHit(event);
    if (next?.item.id === this.selectionHover?.item.id) return;
    this.selectionHover = next;
    cadSelection.dispatch({ type: "set-hovered", item: next?.item ?? null });
    this.resetFaceMaterials();
    this.callbacks.onHover(next ? {
      partName: next.part.data.name,
      label: next.item.label,
      detail: next.item.detail ?? `${next.item.kind} selection`,
    } : null);
  }

  private selectionHit(event: PointerEvent): SelectionHover | null {
    this.updatePointer(event);
    const hit = this.raycaster.intersectObjects(
      [...this.parts.values()].map((part) => part.surface),
      false,
    )[0];
    if (!hit || hit.faceIndex === undefined || hit.faceIndex === null) return null;
    const part = this.parts.get(String(hit.object.userData.partId));
    if (!part) return null;
    const faceId = this.faceIdForTriangle(part.faceRanges, hit.faceIndex);
    const topology = faceId === undefined ? undefined : part.topology.get(faceId);
    const filter = cadSelection.snapshot().filter;
    const kind = filter === "auto" ? "body" : filter;
    if (kind === "component" || kind === "body") {
      return {
        part,
        item: {
          id: `${kind}:${part.data.id}`,
          kind,
          partId: part.data.id,
          label: part.data.name,
          detail: kind === "component" ? "Component occurrence" : "Exact Body",
        },
      };
    }
    if (!topology) return null;
    if (kind === "face") {
      return {
        part,
        faceId: topology.id,
        item: {
          id: `face:${part.data.id}:${topology.id}`,
          kind: "face",
          partId: part.data.id,
          faceId: topology.id,
          label: `Face ${topology.id}`,
          detail: topology.surfaceType,
        },
      };
    }
    const candidateKind = kind === "edge" ? "edge-midpoint" : "vertex";
    const candidates = topology.candidates.filter((candidate) => candidate.kind === candidateKind);
    if (candidates.length === 0) return null;
    const candidate = this.closestCandidate(candidates, part.group, event);
    return {
      part,
      faceId: topology.id,
      item: {
        id: `${kind}:${part.data.id}:${candidate.id}`,
        kind,
        partId: part.data.id,
        faceId: topology.id,
        label: candidate.label,
        detail: kind === "edge" ? "Exact edge" : "Exact vertex",
      },
    };
  }

  private commitSelectionClick(event: PointerEvent): void {
    const hit = this.selectionHit(event);
    if(this.sketchPlaneSelection && !hit){
      this.updatePointer(event);
      const custom=this.raycaster.intersectObjects(this.constructionPlanes.children,true)[0];
      if(custom){let object:THREE.Object3D|null=custom.object;while(object&&!object.userData.sketchFrame)object=object.parent;if(object){window.dispatchEvent(new CustomEvent('aether-sketch-face',{detail:{frame:object.userData.sketchFrame}}));return;}}
      const surfaces=[...this.referenceObjects].filter(([id,o])=>id!=="origin"&&o.visible).flatMap(([id,o])=>o.children.filter(c=>c instanceof THREE.Mesh).map(mesh=>({id,mesh})));
      const picked=this.raycaster.intersectObjects(surfaces.map(s=>s.mesh),false)[0];
      const id=surfaces.find(s=>s.mesh===picked?.object)?.id;
      const plane=id==="top-plane"?"XY":id==="front-plane"?"XZ":id==="right-plane"?"YZ":null;
      if(plane){window.dispatchEvent(new CustomEvent("aether-sketch-plane",{detail:plane}));return;}
    }
    const extendsSelection = event.shiftKey || event.metaKey || event.ctrlKey;
    if (!hit) {
      if (!extendsSelection) cadSelection.dispatch({ type: "clear" });
      this.selectionHover = null;
      this.callbacks.onHover(null);
      this.callbacks.onStateChanged();
      return;
    }
    cadSelection.dispatch({
      type: extendsSelection ? "toggle" : "replace",
      items: [hit.item],
    });
    if(this.sketchPlaneSelection && hit.item.kind==="face") window.dispatchEvent(new CustomEvent("aether-sketch-face-request"));
    this.selectionHover = hit;
    this.callbacks.onStatus(`${hit.item.label} selected.`);
    this.callbacks.onStateChanged();
  }

  private updateSelectionBox(event: PointerEvent): void {
    const down = this.pointerDown;
    if (!down || Math.hypot(event.clientX - down.x, event.clientY - down.y) <= 4) return;
    const rect = this.renderer.domElement.getBoundingClientRect();
    const startX = down.x - rect.left;
    const startY = down.y - rect.top;
    const currentX = event.clientX - rect.left;
    const currentY = event.clientY - rect.top;
    cadSelection.dispatch({
      type: "set-box",
      box: {
        startX,
        startY,
        currentX,
        currentY,
        mode: boxSelectionMode(startX, currentX),
      },
    });
  }

  private completeBoxSelection(event: PointerEvent): void {
    const box = cadSelection.snapshot().box;
    if (!box) return;
    const items = this.itemsInsideSelectionBox(box.mode, normalizedSelectionBox(box));
    cadSelection.dispatch({
      type: event.shiftKey || event.metaKey || event.ctrlKey ? "add" : "replace",
      items,
    });
    this.selectionHover = null;
    this.callbacks.onHover(null);
    this.callbacks.onStateChanged();
    this.callbacks.onStatus(
      `${box.mode === "window" ? "Window" : "Crossing"} selected ${items.length} ${items.length === 1 ? "item" : "items"}.`,
    );
  }

  private itemsInsideSelectionBox(
    mode: CADBoxSelectionMode,
    selection: CADScreenRect,
  ): readonly CADSelectionItem[] {
    const filter = cadSelection.snapshot().filter;
    const kind = filter === "auto" ? "body" : filter;
    const items: CADSelectionItem[] = [];
    const containsPoint = (x: number, y: number): boolean =>
      x >= selection.left && x <= selection.right && y >= selection.top && y <= selection.bottom;

    this.parts.forEach((part) => {
      if (!part.group.visible) return;
      if (kind === "component" || kind === "body") {
        const bounds = new THREE.Box3().setFromObject(part.surface, true);
        const points = [
          [bounds.min.x, bounds.min.y, bounds.min.z],
          [bounds.min.x, bounds.min.y, bounds.max.z],
          [bounds.min.x, bounds.max.y, bounds.min.z],
          [bounds.min.x, bounds.max.y, bounds.max.z],
          [bounds.max.x, bounds.min.y, bounds.min.z],
          [bounds.max.x, bounds.min.y, bounds.max.z],
          [bounds.max.x, bounds.max.y, bounds.min.z],
          [bounds.max.x, bounds.max.y, bounds.max.z],
        ].map(([x, y, z]) => this.projectScreenPoint(new THREE.Vector3(x, y, z)));
        const screenBounds = this.screenRectForPoints(
          points.filter((point): point is { x: number; y: number } => point !== null),
        );
        if (screenBounds && selectionRectangleMatches(mode, selection, screenBounds)) {
          items.push({
            id: `${kind}:${part.data.id}`,
            kind,
            partId: part.data.id,
            label: part.data.name,
            detail: kind === "component" ? "Component occurrence" : "Exact Body",
          });
        }
        return;
      }

      if (kind === "face") {
        part.faceRanges.forEach((range) => {
          const screenBounds = this.projectedFaceBounds(part, range);
          const topology = part.topology.get(range.faceId);
          if (!screenBounds || !topology || !selectionRectangleMatches(mode, selection, screenBounds)) return;
          items.push({
            id: `face:${part.data.id}:${range.faceId}`,
            kind: "face",
            partId: part.data.id,
            faceId: range.faceId,
            label: `Face ${range.faceId}`,
            detail: topology.surfaceType,
          });
        });
        return;
      }

      const candidateKind = kind === "edge" ? "edge-midpoint" : "vertex";
      part.topology.forEach((face) => {
        face.candidates
          .filter((candidate) => candidate.kind === candidateKind)
          .forEach((candidate) => {
            const projected = this.projectScreenPoint(
              new THREE.Vector3(...candidate.origin).applyMatrix4(part.group.matrixWorld),
            );
            if (!projected || !containsPoint(projected.x, projected.y)) return;
            items.push({
              id: `${kind}:${part.data.id}:${candidate.id}`,
              kind,
              partId: part.data.id,
              faceId: face.id,
              label: candidate.label,
              detail: kind === "edge" ? "Exact edge" : "Exact vertex",
            });
          });
      });
    });
    return [...new Map(items.map((item) => [item.id, item] as const)).values()];
  }

  private projectedFaceBounds(part: RenderPart, range: FaceRangeData): CADScreenRect | null {
    const geometry = part.surface.geometry;
    const index = geometry.index;
    const positions = geometry.getAttribute("position");
    if (!index || !positions) return null;
    const points: Array<{ x: number; y: number }> = [];
    const end = Math.min(range.start + range.count, index.count);
    for (let offset = range.start; offset < end; offset += 1) {
      const vertexIndex = index.getX(offset);
      const local = new THREE.Vector3().fromBufferAttribute(positions, vertexIndex);
      const projected = this.projectScreenPoint(local.applyMatrix4(part.group.matrixWorld));
      if (projected) points.push(projected);
    }
    return this.screenRectForPoints(points);
  }

  private projectScreenPoint(world: THREE.Vector3): { x: number; y: number } | null {
    const projected = world.clone().project(this.camera);
    if (projected.z < -1 || projected.z > 1) return null;
    const rect = this.renderer.domElement.getBoundingClientRect();
    return {
      x: (projected.x + 1) * 0.5 * rect.width,
      y: (1 - projected.y) * 0.5 * rect.height,
    };
  }

  private screenRectForPoints(points: readonly { x: number; y: number }[]): CADScreenRect | null {
    if (points.length === 0) return null;
    return {
      left: Math.min(...points.map((point) => point.x)),
      top: Math.min(...points.map((point) => point.y)),
      right: Math.max(...points.map((point) => point.x)),
      bottom: Math.max(...points.map((point) => point.y)),
    };
  }

  private updatePointer(event: PointerEvent): void {
    const rect = this.renderer.domElement.getBoundingClientRect();
    this.pointer.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    this.raycaster.setFromCamera(this.pointer, this.camera);
  }

  private faceIdForTriangle(
    ranges: FaceRangeData[],
    triangleIndex: number,
  ): number | undefined {
    const indexOffset = triangleIndex * 3;
    return ranges.find(
      (range) => indexOffset >= range.start && indexOffset < range.start + range.count,
    )?.faceId;
  }

  private closestCandidate(
    candidates: ConnectorCandidate[],
    group: THREE.Group,
    event: PointerEvent,
  ): ConnectorCandidate {
    const rect = this.renderer.domElement.getBoundingClientRect();
    return [...candidates].sort((left, right) => {
      const distance = (candidate: ConnectorCandidate): number => {
        const projected = new THREE.Vector3(...candidate.origin)
          .applyMatrix4(group.matrixWorld)
          .project(this.camera);
        const x = rect.left + (projected.x + 1) * 0.5 * rect.width;
        const y = rect.top + (1 - projected.y) * 0.5 * rect.height;
        return Math.hypot(x - event.clientX, y - event.clientY);
      };
      const delta = distance(left) - distance(right);
      return Math.abs(delta) > 5
        ? delta
        : connectorKindPreference(left.kind) - connectorKindPreference(right.kind);
    })[0];
  }

  private setHover(target: HoverTarget | null): void {
    const oldKey = this.hoverKey(this.hover);
    const newKey = this.hoverKey(target);
    if (oldKey === newKey) return;
    this.hover = target;
    this.resetFaceMaterials();
    this.clearTransientOverlay();
    this.refreshConnectorMaterials();
    if (target?.kind === "candidate") {
      this.setFaceMaterial(target.part, target.faceId, 1);
      this.showCandidateCloud(target);
      this.callbacks.onHover({
        partName: target.part.data.name,
        label: target.candidate.label,
        detail: target.part.topology.get(target.faceId)?.surfaceType ?? "B-Rep",
      });
    } else if (target?.kind === "connector") {
      this.setConnectorMaterial(
        target.connector.id,
        viewportMaterials.hoveredConnector,
      );
      this.callbacks.onHover({
        partName: target.connector.partName,
        label: target.connector.name,
        detail: target.connector.candidate.label,
      });
    } else {
      this.callbacks.onHover(null);
    }
  }

  private hoverKey(target: HoverTarget | null): string {
    if (!target) return "";
    return target.kind === "candidate"
      ? `candidate:${target.part.data.id}:${target.candidate.id}`
      : `connector:${target.connector.id}`;
  }

  private showCandidateCloud(target: CandidateHover): void {
    const topology = target.part.topology.get(target.faceId);
    if (!topology) return;
    const cloud = createCandidateCloud(
      topology.candidates,
      target.part.group.matrixWorld,
      this.markerScale,
    );
    this.overlayRoot.add(cloud);
    this.addTransientTriad(target.part.group.matrixWorld, target.candidate);
  }

  private addTransientTriad(partWorld: THREE.Matrix4, candidate: ConnectorCandidate): void {
    const marker = createConnectorGizmo(
      this.markerScale,
      viewportMaterials.hoveredConnector,
    );
    marker.root.matrixAutoUpdate = false;
    marker.root.matrix.copy(partWorld).multiply(connectorMatrix(candidate));
    marker.root.userData.transient = true;
    this.overlayRoot.add(marker.root);
  }

  private createConnector(target: CandidateHover): void {
    const connector = this.connectorRegistry.create(
      target.part.data.id,
      target.part.data.name,
      target.candidate,
    );
    const marker = createConnectorGizmo(
      this.markerScale,
      viewportMaterials.connector,
    );
    const root = marker.root;
    root.name = connector.name;
    root.matrixAutoUpdate = false;
    root.matrix.copy(connectorMatrix(connector.candidate));
    const hitTarget = marker.hitTarget;
    hitTarget.userData.connectorId = connector.id;
    hitTarget.userData.partId = connector.partId;
    target.part.group.add(root);
    this.connectorMarkers.set(connector.id, { root, hitTarget });
    this.callbacks.onStatus(
      `${connector.name} placed on ${connector.partName}. Place another connector or start a mate.`,
      "success",
    );
    this.callbacks.onStateChanged();
    this.setHover(null);
  }

  private acceptSavedConnector(connector: MateConnector): void {
    if (!this.mateDraft.movingConnector) {
      const decision = this.constraints.canUseAsMoving(connector.partId);
      if (!decision.allowed) {
        this.callbacks.onStatus(`${connector.partName}: ${decision.reason}`, "error");
        return;
      }
    }

    const result = this.mateDraft.choose(connector);
    if (result.kind === "rejected") {
      this.callbacks.onStatus(result.reason, "error");
      return;
    }
    if (result.kind === "first") {
      this.refreshConnectorMaterials();
      this.callbacks.onStatus(
        `Moving connector: ${connector.name} on ${connector.partName}. Choose the target connector.`,
      );
      this.callbacks.onStateChanged();
      return;
    }

    const moving = this.parts.get(result.moving.partId);
    const destination = this.parts.get(result.target.partId);
    if (!moving || !destination) return;
    destination.group.updateMatrixWorld(true);
    moving.group.matrix.copy(
      solveFastenedMate(
        result.moving.candidate,
        result.target.candidate,
        destination.group.matrixWorld,
      ),
    );
    moving.group.updateMatrixWorld(true);
    this.constraints.markMovingPart(moving.data.id);
    this.usedConnectorIds.add(result.moving.id);
    this.usedConnectorIds.add(result.target.id);
    const mate: AppliedMate = {
      id: crypto.randomUUID(),
      movingPartId: moving.data.id,
      targetPartId: destination.data.id,
      movingConnectorId: result.moving.id,
      targetConnectorId: result.target.id,
      movingConnector: result.moving.candidate,
      targetConnector: result.target.candidate,
    };
    this.callbacks.onMateApplied(mate);
    this.clearTransientOverlay();
    this.resetFaceMaterials();
    this.refreshConnectorMaterials();
    this.callbacks.onStateChanged();
    this.callbacks.onStatus(
      `Fastened mate applied: ${result.moving.name} → ${result.target.name}.`,
      "success",
    );
  }

  private setFaceMaterial(part: RenderPart, faceId: number, materialIndex: number): void {
    const groupIndex = part.faceRanges.findIndex((range) => range.faceId === faceId);
    if (groupIndex >= 0) part.surface.geometry.groups[groupIndex].materialIndex = materialIndex;
  }

  private resetFaceMaterials(): void {
    const selection = cadSelection.snapshot().items;
    this.parts.forEach((part) => {
      const selectsWholePart = selection.some(
        (item) => item.partId === part.data.id && (item.kind === "component" || item.kind === "body"),
      );
      const selectedFaces = new Set(
        selection
          .filter((item) => item.partId === part.data.id && item.faceId !== undefined)
          .map((item) => item.faceId),
      );
      part.surface.geometry.groups.forEach((group, index) => {
        const faceId = part.faceRanges[index]?.faceId;
        group.materialIndex = selectsWholePart || selectedFaces.has(faceId) ? 2 : 0;
      });
    });
    if (this.tool === "none" && this.selectionHover) {
      if (this.selectionHover.faceId !== undefined) {
        const groupIndex = this.selectionHover.part.faceRanges.findIndex(
          (range) => range.faceId === this.selectionHover?.faceId,
        );
        const group = this.selectionHover.part.surface.geometry.groups[groupIndex];
        if (group && group.materialIndex === 0) group.materialIndex = 1;
      } else {
        this.selectionHover.part.surface.geometry.groups.forEach((group) => {
          if (group.materialIndex === 0) group.materialIndex = 1;
        });
      }
    }
  }

  private setConnectorMaterial(id: string, material: THREE.Material): void {
    const marker = this.connectorMarkers.get(id);
    if (marker) marker.hitTarget.material = material;
  }

  private refreshConnectorMaterials(): void {
    this.connectorMarkers.forEach((marker, id) => {
      marker.hitTarget.material =
        this.mateDraft.movingConnector?.id === id
          ? viewportMaterials.selectedConnector
          : viewportMaterials.connector;
    });
  }

  private clearTransientOverlay(): void {
    for (const child of [...this.overlayRoot.children]) {
      if (!child.userData.transient) continue;
      this.overlayRoot.remove(child);
      disposeTransientGeometry(child);
    }
  }
}
