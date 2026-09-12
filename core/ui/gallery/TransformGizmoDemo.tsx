import { useEffect, useRef, useState } from "react";
import * as THREE from "three";
import {
  applyGizmoDelta,
  beginGizmoDrag,
  pickGizmoHandle,
  updateGizmoDrag,
  type GizmoDrag,
  type GizmoFrame,
  type GizmoHandle,
  type GizmoRay,
} from "@aether/core/transform";

/** Live demo of the shared 3D transform gizmo: move a model along an axis or
 *  in a plane, spin it on a ring. Handle picking and drag meaning come from
 *  @aether/core/transform; this file only draws handles and feeds rays. */

// Anima Studio's CAD gizmo palette (CADToolGeometry.gizmoLineVertices).
const AXIS_COLOR = { x: 0xf24336, y: 0x4dd963, z: 0x408cff } as const;
const PLANE_COLOR = { z: 0xf2d433, x: 0x40d9e6, y: 0xb86bf2 } as const;
const HOVER_COLOR = 0xff9f43;
/** Handle arm in millimetres at unit scale; the group is rescaled each frame
 *  so the arm stays ~72 px like the native gizmo. */
const SIZE = 78;

function buildGizmo(): { group: THREE.Group; pickable: THREE.Mesh[] } {
  const group = new THREE.Group();
  const pickable: THREE.Mesh[] = [];
  const axes: ("x" | "y" | "z")[] = ["x", "y", "z"];
  const direction = (axis: "x" | "y" | "z") =>
    new THREE.Vector3(axis === "x" ? 1 : 0, axis === "y" ? 1 : 0, axis === "z" ? 1 : 0);
  /** Onshape-style outline artwork: thin lines, unfilled heads. */
  const outline = (geometry: THREE.BufferGeometry, color: number, host: THREE.Object3D) => {
    const lines = new THREE.LineSegments(
      new THREE.EdgesGeometry(geometry, 1),
      new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.95 }),
    );
    host.add(lines);
    return lines;
  };
  /** Mark visible artwork so hover can tint it by handle. */
  const tag = (object: THREE.Object3D, handle: GizmoHandle, color: number) => {
    object.userData.handleKey = JSON.stringify(handle);
    object.userData.baseColor = color;
    object.traverse((child) => {
      child.userData.handleKey = object.userData.handleKey;
      child.userData.baseColor = color;
    });
    return object;
  };
  /** Invisible solid under the artwork carries the pick (Anima's hit layer). */
  const pick = (geometry: THREE.BufferGeometry, handle: GizmoHandle, color: number) => {
    const mesh = new THREE.Mesh(
      geometry,
      new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0, depthWrite: false }),
    );
    mesh.userData.handle = handle;
    mesh.userData.baseColor = color;
    return mesh;
  };

  for (const axis of axes) {
    const color = AXIS_COLOR[axis];
    const unit = direction(axis);
    const quaternion = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), unit);
    const shaftLength = SIZE * 0.74;

    // Axis line + open arrowhead, with an invisible cylinder for picking.
    const shaft = pick(new THREE.CylinderGeometry(2.6, 2.6, shaftLength, 8), { kind: "translate-axis", axis }, color);
    shaft.quaternion.copy(quaternion);
    shaft.position.copy(unit.clone().multiplyScalar(shaftLength / 2));
    const line = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), unit.clone().multiplyScalar(shaftLength)]),
      new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.95 }),
    );
    tag(line, { kind: "translate-axis", axis }, color);
    group.add(line, shaft);
    pickable.push(shaft);

    const head = new THREE.Group();
    head.quaternion.copy(quaternion);
    head.position.copy(unit.clone().multiplyScalar(shaftLength + SIZE * 0.08));
    outline(new THREE.ConeGeometry(SIZE * 0.055, SIZE * 0.16, 3), color, head);
    tag(head, { kind: "translate-axis", axis }, color);
    group.add(head);
    const headPick = pick(new THREE.ConeGeometry(SIZE * 0.07, SIZE * 0.18, 8), { kind: "translate-axis", axis }, color);
    headPick.quaternion.copy(quaternion);
    headPick.position.copy(head.position);
    group.add(headPick);
    pickable.push(headPick);

    // Onshape's small tip circle: the rotation handle for this axis.
    const ringRadius = SIZE * 0.1;
    const ringCenter = unit.clone().multiplyScalar(SIZE);
    const ring = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints(
        Array.from({ length: 33 }, (_, index) => {
          const angle = (index / 32) * Math.PI * 2;
          const [u, v] = axes.filter((candidate) => candidate !== axis).map((candidate) => direction(candidate));
          return u.clone().multiplyScalar(Math.cos(angle) * ringRadius).add(v.clone().multiplyScalar(Math.sin(angle) * ringRadius)).add(ringCenter);
        }),
      ),
      new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.95 }),
    );
    tag(ring, { kind: "rotate-ring", axis }, color);
    group.add(ring);
    const ringPick = pick(new THREE.TorusGeometry(ringRadius, SIZE * 0.035, 6, 20), { kind: "rotate-ring", axis }, color);
    if (axis === "x") ringPick.rotation.y = Math.PI / 2;
    if (axis === "y") ringPick.rotation.x = Math.PI / 2;
    ringPick.position.copy(ringCenter);
    group.add(ringPick);
    pickable.push(ringPick);

    // Diamond plane handle in the plane whose normal is this axis.
    const [a, b] = axes.filter((candidate) => candidate !== axis).map(direction);
    const reach = SIZE * 0.34;
    const half = SIZE * 0.1;
    const centre = a.clone().multiplyScalar(reach).add(b.clone().multiplyScalar(reach));
    const diamond = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints([
        centre.clone().add(a.clone().multiplyScalar(half)),
        centre.clone().add(b.clone().multiplyScalar(half)),
        centre.clone().add(a.clone().multiplyScalar(-half)),
        centre.clone().add(b.clone().multiplyScalar(-half)),
        centre.clone().add(a.clone().multiplyScalar(half)),
      ]),
      new THREE.LineBasicMaterial({ color: PLANE_COLOR[axis], transparent: true, opacity: 0.95 }),
    );
    tag(diamond, { kind: "translate-plane", normal: axis }, PLANE_COLOR[axis]);
    group.add(diamond);
    const tabPick = pick(new THREE.PlaneGeometry(half * 2, half * 2), { kind: "translate-plane", normal: axis }, PLANE_COLOR[axis]);
    tabPick.position.copy(centre);
    tabPick.lookAt(centre.clone().add(unit));
    group.add(tabPick);
    pickable.push(tabPick);
  }

  // Centre point, like Onshape's pivot dot.
  const centre = new THREE.Mesh(
    new THREE.SphereGeometry(SIZE * 0.022, 12, 8),
    new THREE.MeshBasicMaterial({ color: 0x6f7b8a }),
  );
  group.add(centre);
  // Manipulators always draw over the model, as in Onshape and the native
  // Anima gizmo — otherwise the handles vanish inside the body.
  group.renderOrder = 999;
  group.traverse((object) => {
    object.renderOrder = 999;
    const material = (object as THREE.Mesh).material as THREE.Material | undefined;
    if (material && "depthTest" in material) {
      material.depthTest = false;
      material.depthWrite = false;
      material.transparent = true;
    }
  });
  return { group, pickable };
}

export function TransformGizmoDemo() {
  const host = useRef<HTMLDivElement>(null);
  const [snap, setSnap] = useState(false);
  const [readout, setReadout] = useState("Drag an arrow, ring, or plane tab.");
  const snapRef = useRef(snap);
  snapRef.current = snap;

  useEffect(() => {
    const element = host.current;
    if (!element) return;
    const width = element.clientWidth || 520;
    const height = 380;
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    renderer.setSize(width, height);
    renderer.domElement.style.width = "100%";
    element.append(renderer.domElement);
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(42, width / height, 1, 5000);
    camera.position.set(120, 96, 150);
    camera.lookAt(0, 0, 0);
    scene.add(new THREE.HemisphereLight(0xffffff, 0x6f8291, 2.4));
    const key = new THREE.DirectionalLight(0xffffff, 2.2);
    key.position.set(120, 200, 160);
    scene.add(key);
    scene.add(new THREE.GridHelper(600, 24, 0x8895a5, 0x394250));

    const body = new THREE.Mesh(
      new THREE.BoxGeometry(70, 40, 50),
      new THREE.MeshStandardMaterial({ color: 0x79a9c2, roughness: 0.55, metalness: 0.05 }),
    );
    scene.add(body);

    const gizmo = buildGizmo();
    scene.add(gizmo.group);

    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    const rayFor = (event: PointerEvent): GizmoRay => {
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.set(
        ((event.clientX - rect.left) / rect.width) * 2 - 1,
        -((event.clientY - rect.top) / rect.height) * 2 + 1,
      );
      raycaster.setFromCamera(pointer, camera);
      return {
        origin: raycaster.ray.origin.toArray() as [number, number, number],
        direction: raycaster.ray.direction.toArray() as [number, number, number],
      };
    };
    const frameFor = (): GizmoFrame => ({
      originMillimeters: body.position.toArray() as [number, number, number],
      xAxis: [1, 0, 0],
      yAxis: [0, 1, 0],
      zAxis: [0, 0, 1],
    });

    let drag: GizmoDrag | null = null;
    let startPosition = body.position.clone();
    let startQuaternion = body.quaternion.clone();

    const handleUnder = (event: PointerEvent): GizmoHandle | null => {
      const hit = raycaster.intersectObjects(gizmo.pickable, false)[0];
      if (hit) return (hit.object.userData.handle as GizmoHandle) ?? null;
      // Fall back to the shared math so picking works even between meshes.
      return pickGizmoHandle(rayFor(event), frameFor(), SIZE);
    };

    const onDown = (event: PointerEvent) => {
      const ray = rayFor(event);
      const handle = handleUnder(event);
      if (!handle) return;
      drag = beginGizmoDrag(handle, ray, frameFor(), SIZE);
      startPosition = body.position.clone();
      startQuaternion = body.quaternion.clone();
      renderer.domElement.setPointerCapture(event.pointerId);
    };
    const onMove = (event: PointerEvent) => {
      if (!drag) {
        const hovered = raycaster.intersectObjects(gizmo.pickable, false)[0]?.object as THREE.Mesh | undefined;
        const handle = hovered?.userData.handle as GizmoHandle | undefined;
        const key = handle ? JSON.stringify(handle) : null;
        gizmo.group.traverse((artwork) => {
          const material = (artwork as THREE.Line).material as THREE.LineBasicMaterial | undefined;
          const base = artwork.userData.baseColor as number | undefined;
          if (!material?.color || base === undefined || !artwork.userData.handleKey) return;
          material.color.setHex(artwork.userData.handleKey === key ? HOVER_COLOR : base);
        });
        renderer.domElement.style.cursor = hovered ? "grab" : "";
        return;
      }
      const delta = updateGizmoDrag(drag, rayFor(event), {
        translationMillimeters: snapRef.current ? 10 : 0,
        rotationRadians: snapRef.current ? Math.PI / 12 : 0,
      });
      if (delta.rotationAxis && delta.angleRadians !== 0) {
        const axis = new THREE.Vector3(...delta.rotationAxis).normalize();
        body.quaternion.copy(
          new THREE.Quaternion().setFromAxisAngle(axis, delta.angleRadians).multiply(startQuaternion),
        );
        const label = ["X", "Y", "Z"][delta.rotationAxis.findIndex((value) => Math.abs(value) > 0.5)] ?? "axis";
        setReadout(`Rotate ${((delta.angleRadians * 180) / Math.PI).toFixed(1)}° about ${label}`);
      } else {
        const moved = applyGizmoDelta(
          startPosition.toArray() as [number, number, number],
          delta,
          frameFor().originMillimeters,
        );
        body.position.set(moved[0], moved[1], moved[2]);
        const [dx, dy, dz] = delta.translationMillimeters;
        setReadout(`Move X ${dx.toFixed(1)} · Y ${dy.toFixed(1)} · Z ${dz.toFixed(1)} mm`);
      }
      gizmo.group.position.copy(body.position);
    };
    const onUp = (event: PointerEvent) => {
      if (!drag) return;
      drag = null;
      renderer.domElement.releasePointerCapture?.(event.pointerId);
    };
    renderer.domElement.addEventListener("pointerdown", onDown);
    renderer.domElement.addEventListener("pointermove", onMove);
    renderer.domElement.addEventListener("pointerup", onUp);

    // Screen-constant handles: the native gizmo keeps a ~72 px arm.
    const rescale = () => {
      const distance = camera.position.distanceTo(gizmo.group.position);
      const metersPerPixel = (2 * distance * Math.tan((camera.fov * Math.PI) / 360)) / height;
      gizmo.group.scale.setScalar(Math.max((96 * metersPerPixel) / SIZE, 0.05));
    };
    const resize = new ResizeObserver(() => {
      const next = element.clientWidth || width;
      renderer.setSize(next, height);
      camera.aspect = next / height;
      camera.updateProjectionMatrix();
    });
    resize.observe(element);

    renderer.setAnimationLoop(() => {
      rescale();
      renderer.render(scene, camera);
    });
    return () => {
      renderer.setAnimationLoop(null);
      resize.disconnect();
      renderer.domElement.removeEventListener("pointerdown", onDown);
      renderer.domElement.removeEventListener("pointermove", onMove);
      renderer.domElement.removeEventListener("pointerup", onUp);
      renderer.dispose();
      renderer.domElement.remove();
    };
  }, []);

  return (
    <div style={{ display: "grid", gap: 10, width: "100%", minWidth: 0, justifySelf: "stretch" }}>
      <div style={{ display: "flex", gap: 14, alignItems: "center", flexWrap: "wrap" }}>
        <label style={{ display: "inline-flex", alignItems: "center", gap: 6, font: "12px system-ui" }}>
          <input type="checkbox" className="aui-switch" checked={snap} onChange={(event) => setSnap(event.target.checked)} />
          Snap (10 mm / 15°)
        </label>
        <output style={{ font: "12px ui-monospace, Menlo, monospace", opacity: 0.8 }}>{readout}</output>
      </div>
      <div ref={host} style={{ width: "100%", minHeight: 380, borderRadius: 10, overflow: "hidden" }} />
    </div>
  );
}
