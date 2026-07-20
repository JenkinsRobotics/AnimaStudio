import * as THREE from "three/webgpu";

const canvas = document.querySelector("#viewport");
const notice = document.querySelector("#notice");
const handler = () => window.webkit?.messageHandlers?.codexBenchThreeJS;
const send = value => handler()?.postMessage(value);

let model;
let edgeLines;
let selected = false;
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

function color(value) {
  return new THREE.Color(value[0], value[1], value[2]);
}

function updateTheme() {
  scene.background = color(theme.background);
  keyLight.color = color(theme.key.color);
  keyLight.position.fromArray(theme.key.direction);
  keyLight.intensity = theme.key.intensity * 4;
  fillLight.color = color(theme.fill.color);
  fillLight.position.fromArray(theme.fill.direction);
  fillLight.intensity = theme.fill.intensity * 3;
  rimLight.color = color(theme.rim.color);
  rimLight.position.fromArray(theme.rim.direction);
  rimLight.intensity = theme.rim.intensity * 2;
  if (model) {
    const materials = Array.isArray(model.material) ? model.material : [model.material];
    for (const material of materials) {
      material.roughness = theme.roughness;
      material.metalness = theme.metallic;
      material.vertexColors = !theme.overrideColor;
      material.color = theme.overrideColor ? color(theme.overrideColor) : new THREE.Color(1, 1, 1);
      material.emissive = selected ? color(theme.selection) : new THREE.Color(0, 0, 0);
      material.emissiveIntensity = selected ? 0.22 : 0;
      material.needsUpdate = true;
    }
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
    disposeObject(model);
    disposeObject(edgeLines);
    model = undefined;
    edgeLines = undefined;
    notice.textContent = "Select one of your own STEP files";
    notice.style.display = "grid";
  },
  loadMesh(payload) {
    const started = performance.now();
    this.clearMesh();
    const decoded = decodeBinary(payload);
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(decoded.positions, 3));
    geometry.setAttribute("normal", new THREE.BufferAttribute(decoded.normals, 3));
    geometry.setAttribute("color", new THREE.BufferAttribute(decoded.colors, 4, true));
    geometry.setIndex(new THREE.BufferAttribute(decoded.indices, 1));
    for (let index = 0; index < payload.batches.length; index += 1) {
      const batch = payload.batches[index];
      geometry.addGroup(batch.indexStart, batch.indexCount, index);
    }
    geometry.computeBoundingSphere();
    const materials = payload.batches.map(() => new THREE.MeshStandardMaterial({
        vertexColors: true, roughness: theme.roughness, metalness: theme.metallic,
        side: THREE.DoubleSide
      }));
    model = new THREE.Mesh(geometry, materials);
    scene.add(model);
    const edgeGeometry = new THREE.BufferGeometry();
    edgeGeometry.setAttribute("position", new THREE.BufferAttribute(decoded.edges, 3));
    edgeLines = new THREE.LineSegments(edgeGeometry, new THREE.LineBasicMaterial({ color: color(theme.edge) }));
    scene.add(edgeLines);
    fitBox(new THREE.Box3().setFromBufferAttribute(geometry.getAttribute("position")));
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
  fit() {
    if (model) fitBox(new THREE.Box3().setFromObject(model));
  },
  orbit(deltaX, deltaY) {
    yaw -= deltaX * 0.006;
    pitch = Math.max(-1.52, Math.min(1.52, pitch + deltaY * 0.006));
  }
};

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
  } else if (dragMode === "roll") {
    roll += dx * 0.006;
  } else {
    updateCamera();
    const forward = target.clone().sub(camera.position).normalize();
    const right = new THREE.Vector3().crossVectors(forward, camera.up).normalize();
    const up = new THREE.Vector3().crossVectors(right, forward).normalize();
    const amount = distance * 0.0015;
    target.addScaledVector(right, -dx * amount).addScaledVector(up, dy * amount);
  }
});
addEventListener("mouseup", event => {
  if (event.button === 0 && !mouseMoved && model) {
    selected = !selected;
    updateTheme();
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
