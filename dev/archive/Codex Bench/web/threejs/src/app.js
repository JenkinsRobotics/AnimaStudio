import * as THREE from "three/webgpu";
import { LineSegmentsGeometry } from "three/addons/lines/LineSegmentsGeometry.js";
import { LineSegments2 } from "three/addons/lines/webgpu/LineSegments2.js";

const canvas = document.querySelector("#viewport");
const notice = document.querySelector("#notice");
const selectionBox = document.querySelector("#selectionBox");
const handler = () => window.webkit?.messageHandlers?.codexBenchThreeJS;
const send = value => handler()?.postMessage(value);

let modelGroup;
const edgeLines = new Map(); // partID -> THREE.LineSegments
let referenceGroup;
let selectedPartOriginHelper;
let lastSelectedOriginScreen;
const partMeshes = new Map(); // partID -> THREE.Mesh (one mesh per assembly node)
const partTransforms = new Map(); // partID -> column-major float4x4
const partAppearances = new Map(); // partID -> app-owned color/PBR override
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
  edgeStrength: 0.7, ambientStrength: 0.3, shadowStrength: 0.55, overrideColor: null,
  key: { color: [1,1,1], direction: [0.5,0.9,0.6], intensity: 0.75 },
  fill: { color: [0.75,0.82,1], direction: [-0.7,0.3,0.4], intensity: 0.3 },
  rim: { color: [1,1,1], direction: [0.1,0.5,-0.8], intensity: 0.225 }
};

const renderer = new THREE.WebGPURenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(45, 1, 0.0001, 100000);
const ambient = new THREE.HemisphereLight(0xffffff, 0x223344, 0.34);
const keyLight = new THREE.DirectionalLight();
const fillLight = new THREE.DirectionalLight();
const rimLight = new THREE.DirectionalLight();
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(2048, 2048);
keyLight.shadow.bias = -0.00035;
keyLight.shadow.normalBias = 0.015;
scene.add(
  ambient, keyLight, keyLight.target,
  fillLight, fillLight.target,
  rimLight, rimLight.target
);

let referenceGeometry = {
  visibility: {
    showsOrigin: true,
    showsFrontPlane: true,
    showsTopPlane: true,
    showsRightPlane: true
  },
  planeSizeMeters: 1.25,
  axisLengthMeters: 0.35,
  gridDivisions: 10,
  showsFloorGrid: true,
  floorGridSpacingMeters: 0.1,
  floorGridExtentMeters: 4,
  floorGridMajorLineInterval: 5,
  floorGridOpacity: 0.24
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

function makeFloorGrid() {
  const requestedSpacing = Math.max(referenceGeometry.floorGridSpacingMeters || 0.1, 0.0001);
  const halfExtent = Math.max(
    (referenceGeometry.floorGridExtentMeters || 4) * 0.5,
    requestedSpacing
  );
  // A pathological import scale must not create an unbounded GPU line buffer.
  // Widen the effective spacing instead while retaining the requested extent.
  const lineCount = Math.min(
    Math.max(Math.ceil(halfExtent / requestedSpacing), 1),
    240
  );
  const spacing = halfExtent / lineCount;
  const majorInterval = Math.max(referenceGeometry.floorGridMajorLineInterval || 5, 2);
  const opacity = Math.max(
    0.02,
    Math.min(referenceGeometry.floorGridOpacity ?? 0.24, 0.9)
  );
  const positions = [];
  const colors = [];
  const minor = new THREE.Color(0.47, 0.53, 0.60);
  const major = new THREE.Color(0.36, 0.43, 0.51);
  const xAxis = new THREE.Color(0.95, 0.24, 0.28);
  const zAxis = new THREE.Color(0.24, 0.50, 1.0);

  const appendLine = (start, end, lineColor) => {
    positions.push(...start, ...end);
    colors.push(lineColor.r, lineColor.g, lineColor.b);
    colors.push(lineColor.r, lineColor.g, lineColor.b);
  };

  for (let index = -lineCount; index <= lineCount; index += 1) {
    const coordinate = index * spacing;
    const isMajor = index % majorInterval === 0;
    appendLine(
      [-halfExtent, 0, coordinate],
      [halfExtent, 0, coordinate],
      index === 0 ? xAxis : (isMajor ? major : minor)
    );
    appendLine(
      [coordinate, 0, -halfExtent],
      [coordinate, 0, halfExtent],
      index === 0 ? zAxis : (isMajor ? major : minor)
    );
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute(
    "position",
    new THREE.Float32BufferAttribute(positions, 3)
  );
  geometry.setAttribute(
    "color",
    new THREE.Float32BufferAttribute(colors, 3)
  );
  const material = new THREE.LineBasicMaterial({
    vertexColors: true,
    transparent: true,
    opacity,
    depthWrite: false
  });
  const floor = new THREE.LineSegments(geometry, material);
  floor.name = "world-floor-grid";
  floor.visible = referenceGeometry.showsFloorGrid !== false;
  return floor;
}

// Unreal-style solid ground plane at Y=0, matching the Metal renderer's
// floor: same extent as the grid, matte theme floor color, receives the
// model's shadow. The grid draws over it (depthWrite off) for Grid+Floor.
function makeSolidFloor() {
  const requestedSpacing = Math.max(referenceGeometry.floorGridSpacingMeters || 0.1, 0.0001);
  const halfExtent = Math.max(
    (referenceGeometry.floorGridExtentMeters || 4) * 0.5,
    requestedSpacing
  );
  const geometry = new THREE.PlaneGeometry(halfExtent * 2, halfExtent * 2);
  const material = new THREE.MeshStandardMaterial({
    color: color(theme.floorColor || [0.36, 0.37, 0.40]),
    roughness: 0.92,
    metalness: 0.0
  });
  const floor = new THREE.Mesh(geometry, material);
  floor.rotation.x = -Math.PI / 2;
  floor.name = "world-solid-floor";
  floor.receiveShadow = true;
  floor.visible = referenceGeometry.showsSolidFloor === true;
  return floor;
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

  // The floor is a camera/display aid shared with the native preview and
  // Metal renderer. It remains distinct from the selectable semantic Top Plane.
  referenceGroup.add(makeFloorGrid());
  referenceGroup.add(makeSolidFloor());

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

// Two-stop vertical gradient texture for the scene background, matching the
// Metal renderer's fullscreen gradient pass.
function backgroundGradientTexture(top, bottom) {
  const canvas = document.createElement("canvas");
  canvas.width = 1;
  canvas.height = 256;
  const context = canvas.getContext("2d");
  const gradient = context.createLinearGradient(0, 0, 0, canvas.height);
  gradient.addColorStop(0, `#${color(top).getHexString()}`);
  gradient.addColorStop(1, `#${color(bottom).getHexString()}`);
  context.fillStyle = gradient;
  context.fillRect(0, 0, canvas.width, canvas.height);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function updateTheme() {
  const bg = color(theme.background);
  if (Array.isArray(theme.backgroundBottom)) {
    if (scene.background && scene.background.isTexture) scene.background.dispose();
    scene.background = backgroundGradientTexture(theme.background, theme.backgroundBottom);
  } else {
    if (scene.background && scene.background.isTexture) scene.background.dispose();
    scene.background = bg;
  }
  // Explicit clear as well — some WebGPU builds do not paint scene.background
  // on an otherwise empty frame, which read as a "blank" viewport.
  renderer.setClearColor(bg, 1);
  const solidFloor = referenceGroup && referenceGroup.getObjectByName("world-solid-floor");
  if (solidFloor) {
    solidFloor.material.color = color(theme.floorColor || [0.36, 0.37, 0.40]);
    solidFloor.material.needsUpdate = true;
  }
  // Zero is an intentional operator choice. A hard-coded floor made the
  // environment appear unchanged after all lighting controls were disabled.
  ambient.intensity = Math.max(0, theme.ambientStrength ?? 0.3);
  keyLight.color = color(theme.key.color);
  keyLight.position.copy(target).add(
    new THREE.Vector3().fromArray(theme.key.direction).normalize().multiplyScalar(distance));
  keyLight.target.position.copy(target);
  keyLight.intensity = theme.key.intensity * 4;
  keyLight.castShadow = (theme.shadowStrength ?? 0.55) > 0.02;
  keyLight.shadow.intensity = Math.max(0, Math.min(theme.shadowStrength ?? 0.55, 1));
  fillLight.color = color(theme.fill.color);
  fillLight.position.copy(target).add(
    new THREE.Vector3().fromArray(theme.fill.direction).normalize().multiplyScalar(distance));
  fillLight.target.position.copy(target);
  fillLight.intensity = theme.fill.intensity * 3;
  rimLight.color = color(theme.rim.color);
  rimLight.position.copy(target).add(
    new THREE.Vector3().fromArray(theme.rim.direction).normalize().multiplyScalar(distance));
  rimLight.target.position.copy(target);
  rimLight.intensity = theme.rim.intensity * 2;
  for (const [partID, mesh] of partMeshes) {
    const material = mesh.material;
    const appearance = partAppearances.get(partID);
    const overrideColor = appearance?.color || theme.overrideColor;
    material.roughness = appearance?.roughness ?? theme.roughness;
    material.metalness = appearance?.metallic ?? theme.metallic;
    material.vertexColors = !overrideColor;
    material.color = overrideColor ? color(overrideColor) : new THREE.Color(1, 1, 1);
    material.opacity = appearance?.color?.[3] ?? 1;
    material.transparent = material.opacity < 0.999;
    material.depthWrite = material.opacity >= 0.999;
    const isSel = selectedParts.has(partID);
    const isGrounded = groundedParts.has(partID);
    material.emissive = isSel ? color(theme.selection)
      : (isGrounded ? new THREE.Color(0.20, 0.62, 0.94) : new THREE.Color(0, 0, 0));
    material.emissiveIntensity = isSel ? 0.28 : (isGrounded ? 0.20 : 0);
    material.needsUpdate = true;
  }
  for (const [partID, lines] of edgeLines) {
    const strength = Math.max(0, Math.min(theme.edgeStrength || 0, 1));
    lines.material.color = color(theme.edge);
    lines.material.linewidth = 0.85 + strength * 2.65;
    lines.material.opacity = 0.3 + strength * 0.7;
    lines.material.transparent = lines.material.opacity < 0.999;
    lines.visible = !hiddenParts.has(partID) && (theme.edgeStrength || 0) > 0.02;
  }
}

function fitBox(box) {
  if (box.isEmpty()) return;
  const size = box.getSize(new THREE.Vector3());
  box.getCenter(target);
  distance = Math.max(size.length() * 1.6, 0.05);
  const radius = Math.max(size.length() * 0.75, 0.025);
  const shadowCamera = keyLight.shadow.camera;
  shadowCamera.left = -radius;
  shadowCamera.right = radius;
  shadowCamera.top = radius;
  shadowCamera.bottom = -radius;
  shadowCamera.near = Math.max(radius * 0.02, 0.0001);
  shadowCamera.far = radius * 8;
  shadowCamera.updateProjectionMatrix();
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
  offset += payload.edgeVertexCount * 12;
  const edgePartIDs = payload.formatVersion >= 2
    ? new Uint32Array(bytes.buffer, offset, payload.edgeVertexCount)
    : new Uint32Array(payload.edgeVertexCount);
  return { positions, normals, colors, indices, edges, edgePartIDs };
}

window.codexBenchThreeJS = {
  setNavigation(value) {
    if (value) navigation = { ...navigation, ...value };
  },
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
    for (const lines of edgeLines.values()) disposeObject(lines);
    edgeLines.clear();
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
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      mesh.userData.partID = partID;
      mesh.visible = !hiddenParts.has(partID);
      applyPartTransform(partID, mesh);
      partMeshes.set(partID, mesh);
      modelGroup.add(mesh);
    }
    scene.add(modelGroup);
    const edgesByPart = new Map();
    for (let index = 0; index < payload.edgeVertexCount; index += 2) {
      const partID = decoded.edgePartIDs[index] || 0;
      if (!edgesByPart.has(partID)) edgesByPart.set(partID, []);
      const points = edgesByPart.get(partID);
      points.push(
        decoded.edges[index * 3],
        decoded.edges[index * 3 + 1],
        decoded.edges[index * 3 + 2],
        decoded.edges[(index + 1) * 3],
        decoded.edges[(index + 1) * 3 + 1],
        decoded.edges[(index + 1) * 3 + 2]
      );
    }
    for (const [partID, points] of edgesByPart) {
      const strength = Math.max(0, Math.min(theme.edgeStrength || 0, 1));
      const edgeGeometry = new LineSegmentsGeometry();
      edgeGeometry.setPositions(new Float32Array(points));
      const lines = new LineSegments2(
        edgeGeometry,
        new THREE.Line2NodeMaterial({
          color: color(theme.edge),
          linewidth: 0.85 + strength * 2.65,
          transparent: true,
          opacity: 0.3 + strength * 0.7
        })
      );
      lines.visible = !hiddenParts.has(partID);
      applyPartTransform(partID, lines);
      edgeLines.set(partID, lines);
      scene.add(lines);
    }
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
    for (const [partID, lines] of edgeLines) {
      lines.visible = !hiddenParts.has(partID) && (theme.edgeStrength || 0) > 0.02;
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
    for (const [partID, lines] of edgeLines) applyPartTransform(partID, lines);
  },
  setPartAppearances(values) {
    partAppearances.clear();
    for (const value of values || []) {
      if (Number.isInteger(value.partID) && Array.isArray(value.color)
        && value.color.length === 4) {
        partAppearances.set(value.partID, value);
      }
    }
    updateTheme();
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
    roll = Number.isFinite(dir[3]) ? dir[3] : 0;
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
    const projectPoint = world => {
      const cameraSpace = world.clone().applyMatrix4(camera.matrixWorldInverse);
      const projected = world.clone().project(camera);
      if (cameraSpace.z >= 0 || !Number.isFinite(projected.x)
        || !Number.isFinite(projected.y)) return undefined;
      return { x: (projected.x + 1) * 0.5, y: (1 - projected.y) * 0.5 };
    };
    const originWorld = new THREE.Vector3().setFromMatrixPosition(
      selectedPartOriginHelper.matrixWorld);
    const positions = selectedPartOriginHelper.geometry.getAttribute("position");
    const endpoint = index => new THREE.Vector3(
      positions.getX(index), positions.getY(index), positions.getZ(index)
    ).applyMatrix4(selectedPartOriginHelper.matrixWorld);
    const origin = projectPoint(originWorld);
    const xAxis = projectPoint(endpoint(1));
    const yAxis = projectPoint(endpoint(3));
    const zAxis = projectPoint(endpoint(5));
    const originNDC = originWorld.clone().project(camera);
    const visible = origin && xAxis && yAxis && zAxis
      && originNDC.x >= -1 && originNDC.x <= 1
      && originNDC.y >= -1 && originNDC.y <= 1
      && originNDC.z >= -1 && originNDC.z <= 1;
    if (visible) {
      next = {
        type: "selectedOriginScreen",
        visible: true,
        origin,
        axes: { x: xAxis, y: yAxis, z: zAxis }
      };
    }
  }
  const pointsChanged = (a, b) => !a || !b
    || Math.abs(a.x - b.x) > 0.0005
    || Math.abs(a.y - b.y) > 0.0005;
  const changed = !lastSelectedOriginScreen
    || next.visible !== lastSelectedOriginScreen.visible
    || (next.visible && (
      pointsChanged(next.origin, lastSelectedOriginScreen.origin)
      || pointsChanged(next.axes.x, lastSelectedOriginScreen.axes?.x)
      || pointsChanged(next.axes.y, lastSelectedOriginScreen.axes?.y)
      || pointsChanged(next.axes.z, lastSelectedOriginScreen.axes?.z)));
  if (changed) {
    lastSelectedOriginScreen = next;
    send(next);
  }
}

let dragMode;
let lastPoint;
let dragStartPoint;
let directPartID;
let mouseMoved = false;
const raycaster = new THREE.Raycaster();
let navigation = {
  orbit: ["rightMouse"],
  pan: ["middleMouse", "controlRightMouse"],
  preciseZoom: [],
  orbitMultiplier: 1,
  panMultiplier: 1,
  zoomMultiplier: 0.65,
  reversesWheelZoom: false
};
function pointerBinding(event) {
  if (event.button === 2) {
    if (event.altKey) return "optionRightMouse";
    if (event.ctrlKey) return "controlRightMouse";
    if (event.shiftKey) return "shiftRightMouse";
    return "rightMouse";
  }
  if (event.button === 1) {
    if (event.ctrlKey && event.shiftKey) return "controlShiftMiddleMouse";
    if (event.altKey) return "optionMiddleMouse";
    if (event.ctrlKey) return "controlMiddleMouse";
    if (event.shiftKey) return "shiftMiddleMouse";
    return "middleMouse";
  }
  return undefined;
}
function pickedPartAt(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  const ndc = new THREE.Vector2(
    ((clientX - rect.left) / rect.width) * 2 - 1,
    -((clientY - rect.top) / rect.height) * 2 + 1
  );
  raycaster.setFromCamera(ndc, camera);
  const meshes = [];
  for (const mesh of partMeshes.values()) if (mesh.visible) meshes.push(mesh);
  const hits = raycaster.intersectObjects(meshes, false);
  return hits.length ? hits[0].object.userData.partID : 0;
}
function updateSelectionBox(start, end) {
  const crossing = end[0] < start[0];
  selectionBox.style.display = "block";
  selectionBox.style.left = `${Math.min(start[0], end[0])}px`;
  selectionBox.style.top = `${Math.min(start[1], end[1])}px`;
  selectionBox.style.width = `${Math.abs(end[0] - start[0])}px`;
  selectionBox.style.height = `${Math.abs(end[1] - start[1])}px`;
  selectionBox.classList.toggle("crossing", crossing);
}
function boxPickedParts(start, end) {
  const rect = canvas.getBoundingClientRect();
  const selection = {
    left: Math.min(start[0], end[0]), right: Math.max(start[0], end[0]),
    top: Math.min(start[1], end[1]), bottom: Math.max(start[1], end[1])
  };
  const crossing = end[0] < start[0];
  const result = [];
  for (const [partID, mesh] of partMeshes) {
    if (!mesh.visible) continue;
    mesh.updateWorldMatrix(true, false);
    if (!mesh.geometry.boundingBox) mesh.geometry.computeBoundingBox();
    const box = mesh.geometry.boundingBox;
    if (!box) continue;
    const points = [];
    for (const x of [box.min.x, box.max.x]) {
      for (const y of [box.min.y, box.max.y]) {
        for (const z of [box.min.z, box.max.z]) {
          const projected = new THREE.Vector3(x, y, z).applyMatrix4(mesh.matrixWorld).project(camera);
          points.push({
            x: rect.left + (projected.x + 1) * 0.5 * rect.width,
            y: rect.top + (1 - projected.y) * 0.5 * rect.height
          });
        }
      }
    }
    const bounds = {
      left: Math.min(...points.map(p => p.x)), right: Math.max(...points.map(p => p.x)),
      top: Math.min(...points.map(p => p.y)), bottom: Math.max(...points.map(p => p.y))
    };
    const intersects = selection.left <= bounds.right && selection.right >= bounds.left
      && selection.top <= bounds.bottom && selection.bottom >= bounds.top;
    const enclosed = selection.left <= bounds.left && selection.right >= bounds.right
      && selection.top <= bounds.top && selection.bottom >= bounds.bottom;
    if (crossing ? intersects : enclosed) result.push(partID);
  }
  return result;
}
canvas.addEventListener("contextmenu", event => event.preventDefault());
canvas.addEventListener("mousedown", event => {
  canvas.focus();
  if (event.button === 1 && event.detail === 2) {
    window.codexBenchThreeJS.fit();
    dragMode = undefined;
    lastPoint = undefined;
    return;
  }
  lastPoint = [event.clientX, event.clientY];
  dragStartPoint = [...lastPoint];
  mouseMoved = false;
  if (event.button === 0) {
    directPartID = pickedPartAt(event.clientX, event.clientY);
    if (directPartID && !groundedParts.has(directPartID)) {
      dragMode = "part";
      send({ type: "partDragBegin", partID: directPartID });
      return;
    }
    dragMode = "box";
    return;
  }
  const binding = pointerBinding(event);
  dragMode = navigation.orbit.includes(binding) ? "orbit"
    : navigation.pan.includes(binding) ? "pan"
    : navigation.preciseZoom.includes(binding) ? "zoom"
    : undefined;
});
addEventListener("mousemove", event => {
  if (!lastPoint) return;
  const dx = event.clientX - lastPoint[0];
  const dy = event.clientY - lastPoint[1];
  if (Math.hypot(dx, dy) > 2) mouseMoved = true;
  if (!dragMode) return;
  lastPoint = [event.clientX, event.clientY];
  if (dragMode === "box") {
    updateSelectionBox(dragStartPoint, [event.clientX, event.clientY]);
  } else if (dragMode === "part") {
    const rect = canvas.getBoundingClientRect();
    send({
      type: "partDrag",
      partID: directPartID,
      deltaX: event.clientX - dragStartPoint[0],
      deltaY: event.clientY - dragStartPoint[1],
      viewportWidth: rect.width,
      viewportHeight: rect.height
    });
  } else if (dragMode === "orbit") {
    yaw -= dx * 0.006 * navigation.orbitMultiplier;
    pitch = Math.max(
      -1.52, Math.min(1.52, pitch + dy * 0.006 * navigation.orbitMultiplier));
    reportCamera();
  } else if (dragMode === "zoom") {
    distance = Math.max(
      0.002,
      distance * Math.exp(dy * 0.0015 * navigation.zoomMultiplier * 0.35));
  } else {
    updateCamera();
    const forward = target.clone().sub(camera.position).normalize();
    const right = new THREE.Vector3().crossVectors(forward, camera.up).normalize();
    const up = new THREE.Vector3().crossVectors(right, forward).normalize();
    const amount = distance * 0.0015 * navigation.panMultiplier;
    target.addScaledVector(right, -dx * amount).addScaledVector(up, dy * amount);
  }
});
addEventListener("mouseup", event => {
  if (dragMode === "part") {
    send({ type: "partDragEnd", partID: directPartID });
  } else if (dragMode === "box" && mouseMoved) {
    send({
      type: "boxPick",
      partIDs: boxPickedParts(dragStartPoint, [event.clientX, event.clientY]),
      extend: event.shiftKey || event.metaKey
    });
  } else if (event.button === 2 && !mouseMoved) {
    const rect = canvas.getBoundingClientRect();
    send({
      type: "context",
      partID: pickedPartAt(event.clientX, event.clientY),
      x: event.clientX - rect.left,
      y: event.clientY - rect.top
    });
  } else if (event.button === 0 && !mouseMoved) {
    // Click-to-select: raycast the visible part meshes and report the hit part.
    const partID = pickedPartAt(event.clientX, event.clientY);
    send({ type: "pick", partID, extend: event.shiftKey || event.metaKey });
  }
  dragMode = undefined;
  lastPoint = undefined;
  dragStartPoint = undefined;
  directPartID = undefined;
  selectionBox.style.display = "none";
});
canvas.addEventListener("wheel", event => {
  event.preventDefault();
  const direction = navigation.reversesWheelZoom ? -1 : 1;
  distance = Math.max(
    0.002,
    distance * Math.exp(event.deltaY * 0.0015 * navigation.zoomMultiplier * direction));
}, { passive: false });
canvas.addEventListener("keydown", event => {
  if (event.key.toLowerCase() === "f") {
    window.codexBenchThreeJS.fit();
    event.preventDefault();
    return;
  }
  const step = (event.shiftKey ? 90 : 15) * Math.PI / 180;
  if (event.key === "ArrowLeft") yaw += step;
  else if (event.key === "ArrowRight") yaw -= step;
  else if (event.key === "ArrowUp") pitch = Math.max(-1.52, pitch - step);
  else if (event.key === "ArrowDown") pitch = Math.min(1.52, pitch + step);
  else return;
  reportCamera();
  event.preventDefault();
});

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
    send({ type: "frames", count: frames, elapsedMilliseconds: now - lastReport });
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
