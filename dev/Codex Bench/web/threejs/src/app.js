import * as THREE from "three/webgpu";

const canvas = document.querySelector("#viewport");
const notice = document.querySelector("#notice");
const handler = () => window.webkit?.messageHandlers?.codexBenchThreeJS;
const send = value => handler()?.postMessage(value);

let modelGroup;
let edgeLines;
let referenceGroup;
let selectedPartOriginHelper;
let lastSelectedOriginScreen;
const partMeshes = new Map(); // partID -> THREE.Mesh (one mesh per assembly node)
const partTransforms = new Map(); // partID -> column-major float4x4
let hiddenParts = new Set();
let selectedParts = new Set();
let groundedParts = new Set();
let yaw = 0.65;
let pitch = 0.42;
let roll = 0;
let distance = 4;
const target = new THREE.Vector3();
let theme = {
  background: [0.16, 0.17, 0.19], edge: [0.16, 0.18, 0.22],
  selection: [1, 0.48, 0], roughness: 0.5, metallic: 0,
  edgeStrength: 0.7, overrideColor: null,
  key: { color: [1,1,1], direction: [0.5,0.9,0.6], intensity: 0.75 },
  fill: { color: [0.75,0.82,1], direction: [-0.7,0.3,0.4], intensity: 0.3 },
  rim: { color: [1,1,1], direction: [0.1,0.5,-0.8], intensity: 0.225 }
};

const renderer = new THREE.WebGPURenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(45, 1, 0.0001, 100000);
const ambient = new THREE.HemisphereLight(0xffffff, 0x223344, 0.34);
const keyLight = new THREE.DirectionalLight();
const fillLight = new THREE.DirectionalLight();
const rimLight = new THREE.DirectionalLight();
scene.add(ambient, keyLight, fillLight, rimLight);

let referenceGeometry = {
  visibility: {
    showsOrigin: true,
    showsFrontPlane: true,
    showsTopPlane: true,
    showsRightPlane: true
  },
  planeSizeMeters: 1.25,
  axisLengthMeters: 0.35,
  gridDivisions: 10
};

function disposeReferenceObject(object) {
  object.traverse(child => {
    child.geometry?.dispose();
    const materials = Array.isArray(child.material) ? child.material : [child.material];
    for (const material of materials) material?.dispose();
  });
}

function configureReferenceMaterial(object, opacity = 0.24) {
  const materials = Array.isArray(object.material) ? object.material : [object.material];
  for (const material of materials) {
    if (!material) continue;
    material.transparent = true;
    material.opacity = opacity;
    material.depthWrite = false;
  }
}

function rebuildReferenceGeometry() {
  if (referenceGroup) {
    scene.remove(referenceGroup);
    disposeReferenceObject(referenceGroup);
  }
  referenceGroup = new THREE.Group();
  referenceGroup.name = "workspace-reference-geometry";
  const size = Math.max(referenceGeometry.planeSizeMeters || 0, 0.001);
  const divisions = Math.max(referenceGeometry.gridDivisions || 10, 2);

  const origin = new THREE.AxesHelper(
    Math.max(referenceGeometry.axisLengthMeters || 0, 0.00025));
  origin.name = "workspace-origin";
  configureReferenceMaterial(origin, 0.95);
  referenceGroup.add(origin);

  const front = new THREE.GridHelper(size, divisions, 0x4f8cff, 0x4f8cff);
  front.name = "front-plane";
  front.rotation.x = Math.PI / 2;
  configureReferenceMaterial(front);
  referenceGroup.add(front);

  const top = new THREE.GridHelper(size, divisions, 0x53d36b, 0x53d36b);
  top.name = "top-plane";
  configureReferenceMaterial(top);
  referenceGroup.add(top);

  const right = new THREE.GridHelper(size, divisions, 0xff5a5a, 0xff5a5a);
  right.name = "right-plane";
  right.rotation.z = Math.PI / 2;
  configureReferenceMaterial(right);
  referenceGroup.add(right);

  const visibility = referenceGeometry.visibility || {};
  origin.visible = visibility.showsOrigin !== false;
  front.visible = visibility.showsFrontPlane !== false;
  top.visible = visibility.showsTopPlane !== false;
  right.visible = visibility.showsRightPlane !== false;
  scene.add(referenceGroup);
}

function color(value) {
  return new THREE.Color(value[0], value[1], value[2]);
}

function updateTheme() {
  const bg = color(theme.background);
  scene.background = bg;
  // Explicit clear as well — some WebGPU builds do not paint scene.background
  // on an otherwise empty frame, which read as a "blank" viewport.
  renderer.setClearColor(bg, 1);
  keyLight.color = color(theme.key.color);
  keyLight.position.fromArray(theme.key.direction);
  keyLight.intensity = theme.key.intensity * 4;
  fillLight.color = color(theme.fill.color);
  fillLight.position.fromArray(theme.fill.direction);
  fillLight.intensity = theme.fill.intensity * 3;
  rimLight.color = color(theme.rim.color);
  rimLight.position.fromArray(theme.rim.direction);
  rimLight.intensity = theme.rim.intensity * 2;
  for (const [partID, mesh] of partMeshes) {
    const material = mesh.material;
    material.roughness = theme.roughness;
    material.metalness = theme.metallic;
    material.vertexColors = !theme.overrideColor;
    material.color = theme.overrideColor ? color(theme.overrideColor) : new THREE.Color(1, 1, 1);
    const isSel = selectedParts.has(partID);
    const isGrounded = groundedParts.has(partID);
    material.emissive = isSel ? color(theme.selection)
      : (isGrounded ? new THREE.Color(0.20, 0.62, 0.94) : new THREE.Color(0, 0, 0));
    material.emissiveIntensity = isSel ? 0.28 : (isGrounded ? 0.20 : 0);
    material.needsUpdate = true;
  }
  if (edgeLines) {
    edgeLines.material.color = color(theme.edge);
    edgeLines.visible = (theme.edgeStrength || 0) > 0.02;
  }
}

function fitBox(box) {
  if (box.isEmpty()) return;
  const size = box.getSize(new THREE.Vector3());
  box.getCenter(target);
  distance = Math.max(size.length() * 1.6, 0.05);
}

function updateCamera() {
  const cp = Math.cos(pitch);
  camera.position.set(
    target.x + distance * cp * Math.sin(yaw),
    target.y + distance * Math.sin(pitch),
    target.z + distance * cp * Math.cos(yaw)
  );
  camera.up.set(Math.sin(roll), Math.cos(roll), 0).normalize();
  camera.lookAt(target);
}

function disposeObject(object) {
  if (!object) return;
  scene.remove(object);
  object.geometry?.dispose();
  const materials = Array.isArray(object.material) ? object.material : [object.material];
  for (const material of materials) material?.dispose();
}

function applyPartTransform(partID, mesh) {
  mesh.matrixAutoUpdate = false;
  const values = partTransforms.get(partID);
  if (values?.length === 16) {
    mesh.matrix.fromArray(values);
  } else {
    mesh.matrix.identity();
  }
  mesh.matrixWorldNeedsUpdate = true;
}

function decodeBinary(payload) {
  const source = atob(payload.data);
  const bytes = new Uint8Array(source.length);
  for (let index = 0; index < source.length; index += 1) bytes[index] = source.charCodeAt(index);
  let offset = 0;
  const positions = new Float32Array(bytes.buffer, offset, payload.vertexCount * 3);
  offset += payload.vertexCount * 12;
  const normals = new Float32Array(bytes.buffer, offset, payload.vertexCount * 3);
  offset += payload.vertexCount * 12;
  const colors = new Uint8Array(bytes.buffer, offset, payload.vertexCount * 4);
  offset += payload.vertexCount * 4;
  const indices = new Uint32Array(bytes.buffer, offset, payload.indexCount);
  offset += payload.indexCount * 4;
  const edges = new Float32Array(bytes.buffer, offset, payload.edgeVertexCount * 3);
  return { positions, normals, colors, indices, edges };
}

window.codexBenchThreeJS = {
  setTheme(value) {
    if (value) Object.assign(theme, value);
    updateTheme();
  },
  clearMesh() {
    if (modelGroup) scene.remove(modelGroup);
    for (const mesh of partMeshes.values()) {
      mesh.geometry?.dispose();
      mesh.material?.dispose();
    }
    partMeshes.clear();
    modelGroup = undefined;
    disposeObject(edgeLines);
    edgeLines = undefined;
    notice.textContent = "Select one of your own STEP files";
    notice.style.display = "grid";
  },
  loadMesh(payload) {
    const started = performance.now();
    this.clearMesh();
    const decoded = decodeBinary(payload);
    // Shared vertex attributes; one mesh per assembly node (a part) so each part
    // can be hidden / selected / moved independently — Onshape-style.
    const position = new THREE.BufferAttribute(decoded.positions, 3);
    const normal = new THREE.BufferAttribute(decoded.normals, 3);
    const vcolor = new THREE.BufferAttribute(decoded.colors, 4, true);
    const byPart = new Map();
    for (const batch of payload.batches) {
      const partID = batch.assemblyNode + 1;
      if (!byPart.has(partID)) byPart.set(partID, []);
      byPart.get(partID).push(batch);
    }
    modelGroup = new THREE.Group();
    for (const [partID, batches] of byPart) {
      let total = 0;
      for (const b of batches) total += b.indexCount;
      const indices = new Uint32Array(total);
      let offset = 0;
      for (const b of batches) {
        indices.set(decoded.indices.subarray(b.indexStart, b.indexStart + b.indexCount), offset);
        offset += b.indexCount;
      }
      const g = new THREE.BufferGeometry();
      g.setAttribute("position", position);
      g.setAttribute("normal", normal);
      g.setAttribute("color", vcolor);
      g.setIndex(new THREE.BufferAttribute(indices, 1));
      const material = new THREE.MeshStandardMaterial({
        vertexColors: true, roughness: theme.roughness, metalness: theme.metallic,
        side: THREE.DoubleSide
      });
      const mesh = new THREE.Mesh(g, material);
      mesh.userData.partID = partID;
      mesh.visible = !hiddenParts.has(partID);
      applyPartTransform(partID, mesh);
      partMeshes.set(partID, mesh);
      modelGroup.add(mesh);
    }
    scene.add(modelGroup);
    const edgeGeometry = new THREE.BufferGeometry();
    edgeGeometry.setAttribute("position", new THREE.BufferAttribute(decoded.edges, 3));
    edgeLines = new THREE.LineSegments(edgeGeometry, new THREE.LineBasicMaterial({ color: color(theme.edge) }));
    scene.add(edgeLines);
    fitBox(new THREE.Box3().setFromBufferAttribute(position));
    updateTheme();
    notice.style.display = "none";
    const result = {
      type: "loaded", triangles: payload.triangles,
      milliseconds: performance.now() - started,
      version: THREE.REVISION
    };
    send(result);
    return result;
  },
  // Per-part hide/select state pushed from the native assembly tree. partIDs are
  // assemblyNode + 1 (same convention as the Metal renderer).
  setPartState(hiddenIDs, selectedIDs, groundedIDs) {
    hiddenParts = new Set(hiddenIDs || []);
    selectedParts = new Set(selectedIDs || []);
    groundedParts = new Set(groundedIDs || []);
    for (const [partID, mesh] of partMeshes) {
      mesh.visible = !hiddenParts.has(partID);
    }
    updateTheme();
  },
  setPartTransforms(values) {
    partTransforms.clear();
    for (const value of values || []) {
      if (Number.isInteger(value.partID) && Array.isArray(value.matrixColumnMajor)
        && value.matrixColumnMajor.length === 16) {
        partTransforms.set(value.partID, value.matrixColumnMajor);
      }
    }
    for (const [partID, mesh] of partMeshes) applyPartTransform(partID, mesh);
  },
  setReferenceGeometry(value) {
    if (!value) return;
    referenceGeometry = value;
    rebuildReferenceGeometry();
  },
  setSelectedPartOrigin(value) {
    disposeObject(selectedPartOriginHelper);
    selectedPartOriginHelper = undefined;
    if (!value || !Array.isArray(value.matrixColumnMajor)
      || value.matrixColumnMajor.length !== 16) return;
    selectedPartOriginHelper = new THREE.AxesHelper(
      Math.max(value.axisLengthMeters || 0, 0.00025));
    selectedPartOriginHelper.name = "selected-part-origin";
    configureReferenceMaterial(selectedPartOriginHelper, 1);
    selectedPartOriginHelper.matrixAutoUpdate = false;
    selectedPartOriginHelper.matrix.fromArray(value.matrixColumnMajor);
    selectedPartOriginHelper.matrixWorldNeedsUpdate = true;
    scene.add(selectedPartOriginHelper);
  },
  fit() {
    if (modelGroup) fitBox(new THREE.Box3().setFromObject(modelGroup));
  },
  orbit(deltaX, deltaY) {
    yaw -= deltaX * 0.006;
    pitch = Math.max(-1.52, Math.min(1.52, pitch + deltaY * 0.006));
  },
  // Snap the camera to a unit view direction (target→camera, Y-up) sent by the
  // native ViewCube. This is Swift-initiated, so it does NOT report back.
  setViewDirection(dir) {
    if (!dir || dir.length < 3) return;
    const v = new THREE.Vector3(dir[0], dir[1], dir[2]);
    if (v.lengthSq() < 1e-6) return;
    v.normalize();
    pitch = Math.max(-1.52, Math.min(1.52, Math.asin(v.y)));
    yaw = Math.atan2(v.x, v.z);
    roll = 0;
  }
};

rebuildReferenceGeometry();

// Report the current view direction to Swift so the ViewCube tracks orbits.
function reportCamera() {
  const cp = Math.cos(pitch);
  send({
    type: "camera",
    direction: [cp * Math.sin(yaw), Math.sin(pitch), cp * Math.cos(yaw)],
    roll
  });
}

function reportSelectedOriginScreen() {
  let next = { type: "selectedOriginScreen", visible: false };
  if (selectedPartOriginHelper) {
    selectedPartOriginHelper.updateMatrixWorld(true);
    camera.updateMatrixWorld(true);
    const world = new THREE.Vector3().setFromMatrixPosition(
      selectedPartOriginHelper.matrixWorld);
    const cameraSpace = world.clone().applyMatrix4(camera.matrixWorldInverse);
    const projected = world.clone().project(camera);
    const visible = cameraSpace.z < 0
      && projected.x >= -1 && projected.x <= 1
      && projected.y >= -1 && projected.y <= 1
      && projected.z >= -1 && projected.z <= 1;
    if (visible) {
      next = {
        type: "selectedOriginScreen",
        visible: true,
        x: (projected.x + 1) * 0.5,
        y: (1 - projected.y) * 0.5
      };
    }
  }
  const changed = !lastSelectedOriginScreen
    || next.visible !== lastSelectedOriginScreen.visible
    || (next.visible && (
      Math.abs(next.x - lastSelectedOriginScreen.x) > 0.0005
      || Math.abs(next.y - lastSelectedOriginScreen.y) > 0.0005));
  if (changed) {
    lastSelectedOriginScreen = next;
    send(next);
  }
}

let dragMode;
let lastPoint;
let mouseMoved = false;
canvas.addEventListener("contextmenu", event => event.preventDefault());
canvas.addEventListener("mousedown", event => {
  canvas.focus();
  lastPoint = [event.clientX, event.clientY];
  mouseMoved = false;
  dragMode = event.button === 2 ? (event.shiftKey ? "roll" : "orbit")
    : (event.button === 1 || event.shiftKey ? "pan" : undefined);
});
addEventListener("mousemove", event => {
  if (!lastPoint) return;
  const dx = event.clientX - lastPoint[0];
  const dy = event.clientY - lastPoint[1];
  if (Math.hypot(dx, dy) > 2) mouseMoved = true;
  if (!dragMode) return;
  lastPoint = [event.clientX, event.clientY];
  if (dragMode === "orbit") {
    yaw -= dx * 0.006;
    pitch = Math.max(-1.52, Math.min(1.52, pitch + dy * 0.006));
    reportCamera();
  } else if (dragMode === "roll") {
    roll += dx * 0.006;
    reportCamera();
  } else {
    updateCamera();
    const forward = target.clone().sub(camera.position).normalize();
    const right = new THREE.Vector3().crossVectors(forward, camera.up).normalize();
    const up = new THREE.Vector3().crossVectors(right, forward).normalize();
    const amount = distance * 0.0015;
    target.addScaledVector(right, -dx * amount).addScaledVector(up, dy * amount);
  }
});
const raycaster = new THREE.Raycaster();
addEventListener("mouseup", event => {
  if (event.button === 0 && !mouseMoved) {
    // Click-to-select: raycast the visible part meshes and report the hit part.
    const rect = canvas.getBoundingClientRect();
    const ndc = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1
    );
    raycaster.setFromCamera(ndc, camera);
    const meshes = [];
    for (const mesh of partMeshes.values()) if (mesh.visible) meshes.push(mesh);
    const hits = raycaster.intersectObjects(meshes, false);
    const partID = hits.length ? hits[0].object.userData.partID : 0;
    send({ type: "pick", partID, extend: event.shiftKey || event.metaKey });
  }
  dragMode = undefined;
  lastPoint = undefined;
});
canvas.addEventListener("wheel", event => {
  event.preventDefault();
  distance = Math.max(0.002, distance * Math.exp(event.deltaY * 0.0015));
}, { passive: false });

let frames = 0;
let lastReport = performance.now();
function draw(now) {
  const width = Math.max(canvas.clientWidth, 1);
  const height = Math.max(canvas.clientHeight, 1);
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  updateCamera();
  renderer.render(scene, camera);
  reportSelectedOriginScreen();
  frames += 1;
  if (now - lastReport >= 1000) {
    send({ type: "frames", count: frames });
    frames = 0;
    lastReport = now;
  }
}

async function start() {
  await renderer.init();
  const backend = renderer.backend?.isWebGPUBackend ? "WebGPU" : "WebGL 2 fallback";
  notice.textContent = "Select one of your own STEP files";
  send({ type: "ready", version: THREE.REVISION, backend, navigatorWebGPU: !!navigator.gpu });
  await renderer.setAnimationLoop(draw);
}

start().catch(error => {
  notice.textContent = `Three.js renderer failed: ${error?.message || error}`;
  send({ type: "error", message: notice.textContent });
});
