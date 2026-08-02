// The imperative Three.js viewport. Mounted once through @aether/ui's
// ViewportCanvas; React never re-renders through it. It draws what the
// engine resolves — no kinematics here. Three.js and animacore are both
// right-handed Y-up, so transforms pass through unchanged.

import * as THREE from "three";
import { OBJLoader } from "three/examples/jsm/loaders/OBJLoader.js";
import { assetURL } from "./engine";
import type { PartSummary, PartTransform } from "./engine";

const PART_COLOR = 0x8da2b4;
const SELECTED_COLOR = 0x37a8f4;

export class AnimationViewport {
  private renderer: THREE.WebGLRenderer;
  private scene = new THREE.Scene();
  private camera: THREE.PerspectiveCamera;
  private partObjects = new Map<string, THREE.Object3D>();
  private selection = new Set<string>();
  private running = true;
  private orbit = { yaw: 0.6, pitch: 0.4, distance: 0.8 };
  private target = new THREE.Vector3();
  private onPick?: (part: string | null, extend: boolean) => void;
  private connectorMode = false;
  private onConnectorPick?: (pick: ConnectorPickInfo) => void;
  private ghostTriad: THREE.Object3D | null = null;
  private placedTriads: THREE.Object3D[] = [];

  constructor(private canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    this.camera = new THREE.PerspectiveCamera(45, 1, 0.001, 100);
    this.scene.background = new THREE.Color(0x14181e);
    const key = new THREE.DirectionalLight(0xffffff, 2.4);
    key.position.set(1, 1.6, 1.1);
    this.scene.add(key, new THREE.AmbientLight(0xffffff, 0.55));
    this.scene.add(new THREE.GridHelper(2, 20, 0x2c3540, 0x222a33));
    this.bindInput();
    const draw = () => {
      if (!this.running) return;
      const { clientWidth, clientHeight } = canvas;
      for (const triad of this.placedTriads) this.scaleTriad(triad);
      if (this.ghostTriad) this.scaleTriad(this.ghostTriad);
      if (clientWidth > 0 && clientHeight > 0) {
        this.renderer.setSize(clientWidth, clientHeight, false);
        this.camera.aspect = clientWidth / clientHeight;
        this.updateCamera();
        this.renderer.render(this.scene, this.camera);
      }
      requestAnimationFrame(draw);
    };
    draw();
  }

  dispose(): void {
    this.running = false;
    this.renderer.dispose();
  }

  setPickHandler(handler: (part: string | null, extend: boolean) => void) {
    this.onPick = handler;
  }

  /** Mate authoring: clicks place connectors (surface point + normal)
   *  and a ghost triad previews the placement under the cursor.
   *  ponytail: raw surface picks — the bore/face-center snapping port
   *  (MeshSnapping → TS) is the queued follow-up. */
  setConnectorMode(
    enabled: boolean,
    onPick?: (pick: ConnectorPickInfo) => void
  ): void {
    this.connectorMode = enabled;
    this.onConnectorPick = onPick;
    if (!enabled) {
      if (this.ghostTriad) this.scene.remove(this.ghostTriad);
      this.ghostTriad = null;
      this.clearPlacedTriads();
    }
  }

  addPlacedTriad(worldPosition: THREE.Vector3, worldNormal: THREE.Vector3): void {
    const triad = buildTriad(1);
    triad.position.copy(worldPosition);
    triad.quaternion.setFromUnitVectors(
      new THREE.Vector3(0, 0, 1), worldNormal);
    this.scene.add(triad);
    this.placedTriads.push(triad);
  }

  clearPlacedTriads(): void {
    for (const triad of this.placedTriads) this.scene.remove(triad);
    this.placedTriads = [];
  }

  async setParts(parts: PartSummary[], characterPath: string): Promise<void> {
    for (const object of this.partObjects.values()) this.scene.remove(object);
    this.partObjects.clear();
    const loader = new OBJLoader();
    for (const part of parts) {
      let object: THREE.Object3D | null = null;
      if (part.model.toLowerCase().endsWith(".obj")) {
        try {
          object = await loader.loadAsync(assetURL(characterPath, part.model));
          object.traverse((child) => {
            if (child instanceof THREE.Mesh) {
              child.material = new THREE.MeshStandardMaterial({
                color: PART_COLOR, roughness: 0.6, metalness: 0.1,
              });
            }
          });
        } catch {
          object = null; // fall through to the placeholder box
        }
      }
      if (!object) {
        object = new THREE.Mesh(
          new THREE.BoxGeometry(0.05, 0.05, 0.05),
          new THREE.MeshStandardMaterial({ color: PART_COLOR, roughness: 0.6 })
        );
      }
      object.name = part.name;
      this.scene.add(object);
      this.partObjects.set(part.name, object);
    }
  }

  applyPose(transforms: Record<string, PartTransform>): void {
    for (const [name, object] of this.partObjects) {
      const transform = transforms[name];
      object.visible = transform !== undefined;
      if (!transform) continue;
      object.position.set(...transform.position);
      object.quaternion.set(...transform.orientation);
    }
    this.fitOnce(transforms);
  }

  setSelection(names: ReadonlySet<string>): void {
    this.selection = new Set(names);
    for (const [name, object] of this.partObjects) {
      const color = this.selection.has(name) ? SELECTED_COLOR : PART_COLOR;
      object.traverse((child) => {
        if (child instanceof THREE.Mesh) {
          (child.material as THREE.MeshStandardMaterial).color.setHex(color);
        }
      });
    }
  }

  private fitted = false;
  private fitOnce(transforms: Record<string, PartTransform>): void {
    if (this.fitted || Object.keys(transforms).length === 0) return;
    const bounds = new THREE.Box3();
    for (const object of this.partObjects.values()) {
      if (object.visible) bounds.expandByObject(object);
    }
    if (bounds.isEmpty()) return;
    bounds.getCenter(this.target);
    const size = bounds.getSize(new THREE.Vector3()).length();
    this.orbit.distance = Math.max(0.15, size * 1.4);
    this.fitted = true;
  }

  private updateCamera(): void {
    const { yaw, pitch, distance } = this.orbit;
    this.camera.position.set(
      this.target.x + distance * Math.sin(yaw) * Math.cos(pitch),
      this.target.y + distance * Math.sin(pitch),
      this.target.z + distance * Math.cos(yaw) * Math.cos(pitch)
    );
    this.camera.lookAt(this.target);
    this.camera.updateProjectionMatrix();
  }

  private scaleTriad(triad: THREE.Object3D): void {
    const distance = this.camera.position.distanceTo(triad.position);
    triad.scale.setScalar(Math.max(0.004, distance * 0.045));
  }

  private raycastPart(event: MouseEvent): {
    part: string;
    point: THREE.Vector3;
    normal: THREE.Vector3;
  } | null {
    const rect = this.canvas.getBoundingClientRect();
    if (event.clientX < rect.left || event.clientX > rect.right ||
        event.clientY < rect.top || event.clientY > rect.bottom) return null;
    const pointer = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1
    );
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(pointer, this.camera);
    const hits = raycaster.intersectObjects(
      [...this.partObjects.values()], true);
    for (const hit of hits) {
      let object: THREE.Object3D | null = hit.object;
      while (object && !this.partObjects.has(object.name)) object = object.parent;
      if (!object || !hit.face) continue;
      const normal = hit.face.normal.clone()
        .transformDirection(hit.object.matrixWorld).normalize();
      return { part: object.name, point: hit.point.clone(), normal };
    }
    return null;
  }

  private updateGhost(event: MouseEvent): void {
    if (!this.connectorMode) return;
    const hit = this.raycastPart(event);
    if (!hit) {
      if (this.ghostTriad) this.ghostTriad.visible = false;
      return;
    }
    if (!this.ghostTriad) {
      this.ghostTriad = buildTriad(0.75);
      this.scene.add(this.ghostTriad);
    }
    this.ghostTriad.visible = true;
    this.ghostTriad.position.copy(hit.point);
    this.ghostTriad.quaternion.setFromUnitVectors(
      new THREE.Vector3(0, 0, 1), hit.normal);
  }

  private bindInput(): void {
    const canvas = this.canvas;
    let dragging: "orbit" | "pan" | null = null;
    let moved = false;
    let last: [number, number] = [0, 0];
    canvas.addEventListener("contextmenu", (event) => event.preventDefault());
    canvas.addEventListener("mousedown", (event) => {
      last = [event.clientX, event.clientY];
      moved = false;
      dragging = event.button === 2 ? "orbit"
        : event.button === 1 ? "pan" : null;
    });
    window.addEventListener("mousemove", (event) => {
      this.updateGhost(event);
      const dx = event.clientX - last[0];
      const dy = event.clientY - last[1];
      if (Math.hypot(dx, dy) > 2) moved = true;
      if (!dragging) return;
      last = [event.clientX, event.clientY];
      if (dragging === "orbit") {
        this.orbit.yaw -= dx * 0.006;
        this.orbit.pitch = Math.min(1.5, Math.max(-1.5, this.orbit.pitch + dy * 0.006));
      } else {
        const amount = this.orbit.distance * 0.0015;
        const right = new THREE.Vector3();
        this.camera.getWorldDirection(right);
        right.cross(this.camera.up).normalize();
        this.target.addScaledVector(right, -dx * amount);
        this.target.addScaledVector(this.camera.up, dy * amount);
      }
    });
    window.addEventListener("mouseup", (event) => {
      if (event.button === 0 && !moved) {
        if (this.connectorMode) this.pickConnector(event);
        else this.pick(event);
      }
      dragging = null;
    });
    canvas.addEventListener("wheel", (event) => {
      event.preventDefault();
      this.orbit.distance = Math.max(
        0.01, this.orbit.distance * Math.exp(event.deltaY * 0.0015));
    }, { passive: false });
  }

  private pickConnector(event: MouseEvent): void {
    if (!this.onConnectorPick) return;
    const hit = this.raycastPart(event);
    if (!hit) return;
    const object = this.partObjects.get(hit.part);
    if (!object) return;
    const inverse = object.matrixWorld.clone().invert();
    const localPoint = hit.point.clone().applyMatrix4(inverse);
    const localNormal = hit.normal.clone()
      .transformDirection(inverse).normalize();
    let secondary = new THREE.Vector3(0, 1, 0).cross(localNormal);
    if (secondary.lengthSq() < 1e-4) {
      secondary = new THREE.Vector3(1, 0, 0).cross(localNormal);
    }
    secondary.normalize();
    this.addPlacedTriad(hit.point, hit.normal);
    this.onConnectorPick({
      part: hit.part,
      originM: [localPoint.x, localPoint.y, localPoint.z],
      primaryAxis: [localNormal.x, localNormal.y, localNormal.z],
      secondaryAxis: [secondary.x, secondary.y, secondary.z],
    });
  }

  // ponytail: raycast picking for the animation v1 — the GPU ID-buffer
  // pick migrates in from the CAD viewport stack with the shared renderer.
  private pick(event: MouseEvent): void {
    if (!this.onPick) return;
    const rect = this.canvas.getBoundingClientRect();
    if (event.clientX < rect.left || event.clientX > rect.right ||
        event.clientY < rect.top || event.clientY > rect.bottom) return;
    const pointer = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1
    );
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(pointer, this.camera);
    const hits = raycaster.intersectObjects(
      [...this.partObjects.values()], true);
    let name: string | null = null;
    if (hits.length > 0) {
      let object: THREE.Object3D | null = hits[0].object;
      while (object && !this.partObjects.has(object.name)) {
        object = object.parent;
      }
      name = object?.name ?? null;
    }
    this.onPick(name, event.shiftKey || event.metaKey);
  }
}

export interface ConnectorPickInfo {
  part: string;
  originM: [number, number, number];
  primaryAxis: [number, number, number];
  secondaryAxis: [number, number, number];
}

/** Screen-constant RGB connector triad (primary = blue Z, matching the
 *  engine-drawn tool convention); opacity dims the hover ghost. */
function buildTriad(opacity: number): THREE.Object3D {
  const group = new THREE.Group();
  const arms: [THREE.Vector3, number][] = [
    [new THREE.Vector3(0.42, 0, 0), 0xe64545],
    [new THREE.Vector3(0, 0.42, 0), 0x4db857],
    [new THREE.Vector3(0, 0, 0.6), 0x4073eb],
  ];
  for (const [direction, color] of arms) {
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(), direction,
    ]);
    const material = new THREE.LineBasicMaterial({
      color, transparent: opacity < 1, opacity,
    });
    group.add(new THREE.Line(geometry, material));
  }
  const hub = new THREE.Mesh(
    new THREE.SphereGeometry(0.07, 12, 12),
    new THREE.MeshBasicMaterial({
      color: 0xf2d84b, transparent: opacity < 1, opacity,
    })
  );
  group.add(hub);
  return group;
}
