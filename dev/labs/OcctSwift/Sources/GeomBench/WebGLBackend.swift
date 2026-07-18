// Pipeline: Open CASCADE → WebGL (Three.js) inside Swift.
// The same shim-tessellated STEP data (positions/colors/indices, layout
// baked) is embedded into a Three.js page rendered by a WKWebView — the
// "web viewport hosted natively" configuration. Its own mouse: drag orbit,
// right-drag pan, scroll zoom (Three.js OrbitControls).
import SwiftUI
import WebKit

@MainActor
func threeJSPage(meshes: [GpuMeshData]) -> String {
  var buffers: [String] = []
  for mesh in meshes where !mesh.indices.isEmpty {
    let positions = mesh.positions.map { String(format: "%.5f", $0) }.joined(separator: ",")
    let colors = mesh.colors.map { String(format: "%.3f", $0) }.joined(separator: ",")
    let indices = mesh.indices.map(String.init).joined(separator: ",")
    buffers.append("{positions:[\(positions)],colors:[\(colors)],indices:[\(indices)]}")
  }
  let meshArray = "[" + buffers.joined(separator: ",") + "]"
  return """
  <!DOCTYPE html><html><head><meta charset="utf-8">
  <style>body{margin:0;background:#14161a;color:#9fe8e2;font:11px monospace}#hud{position:fixed;top:6px;left:8px}</style>
  </head><body><div id="hud">Open CASCADE → WebGL (Three.js in WKWebView) · drag orbit · right-drag pan · scroll zoom</div>
  <script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.169.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.169.0/examples/jsm/"}}</script>
  <script type="module">
  import * as THREE from 'three';
  import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
  const meshes = \(meshArray);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x14161a);
  const group = new THREE.Group();
  for (const data of meshes) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(data.positions, 3));
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(data.colors, 3));
    geometry.setIndex(data.indices);
    geometry.computeVertexNormals();
    group.add(new THREE.Mesh(geometry, new THREE.MeshStandardMaterial({vertexColors: true, metalness: 0.1, roughness: 0.55})));
  }
  scene.add(group);
  const box = new THREE.Box3().setFromObject(group);
  const sphere = box.getBoundingSphere(new THREE.Sphere());
  const radius = Math.max(sphere.radius, 0.01);
  const camera = new THREE.PerspectiveCamera(50, innerWidth/innerHeight, radius/100, radius*30);
  camera.position.set(sphere.center.x + radius*1.5, sphere.center.y + radius*1.1, sphere.center.z + radius*1.8);
  scene.add(new THREE.AmbientLight(0xffffff, 0.35));
  const key = new THREE.DirectionalLight(0xffffff, 1.5); key.position.set(1, 1.6, 1.2); scene.add(key);
  const fill = new THREE.DirectionalLight(0xbfd4ff, 0.5); fill.position.set(-1.4, 0.4, 0.6); scene.add(fill);
  const renderer = new THREE.WebGLRenderer({antialias: true});
  renderer.setSize(innerWidth, innerHeight);
  document.body.appendChild(renderer.domElement);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.target.copy(sphere.center);
  renderer.setAnimationLoop(() => { controls.update(); renderer.render(scene, camera); });
  addEventListener('resize', () => { camera.aspect = innerWidth/innerHeight; camera.updateProjectionMatrix(); renderer.setSize(innerWidth, innerHeight); });
  </script></body></html>
  """
}

struct WebGLViewport: NSViewRepresentable {
  let model: BenchModel

  final class Coordinator {
    var loadedRevision = -1
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> WKWebView {
    let view = WKWebView()
    view.setValue(false, forKey: "drawsBackground")
    return view
  }

  func updateNSView(_ view: WKWebView, context: Context) {
    guard context.coordinator.loadedRevision != model.gpuRevision else { return }
    context.coordinator.loadedRevision = model.gpuRevision
    view.loadHTMLString(threeJSPage(meshes: model.gpuMeshes), baseURL: nil)
  }
}
