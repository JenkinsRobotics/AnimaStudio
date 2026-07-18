// SceneKit engine — harvested from Gemini's build (the one renderer it had
// that the others didn't). Consumes the same GpuMeshData the Metal/WebGL
// backends use, so it renders the identical scene through Apple's SceneKit.
import AppKit
import SceneKit
import SwiftUI
import simd

struct SceneKitViewport: NSViewRepresentable {
  let model: BenchModel

  final class Coordinator { var builtRevision = -1 }
  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> SCNView {
    let view = SCNView()
    view.scene = SCNScene()
    view.autoenablesDefaultLighting = false
    view.allowsCameraControl = false  // we drive the camera from the shared state
    let cameraNode = SCNNode()
    cameraNode.name = "camera"
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.zNear = 0.001
    cameraNode.camera?.zFar = 100
    view.scene?.rootNode.addChildNode(cameraNode)
    return view
  }

  func updateNSView(_ view: SCNView, context: Context) {
    guard let scene = view.scene else { return }
    // Background + rebuild geometry/lights when the file or theme changes.
    let bg = model.theme.background
    view.backgroundColor = NSColor(
      red: CGFloat(bg.x), green: CGFloat(bg.y), blue: CGFloat(bg.z), alpha: 1)

    if context.coordinator.builtRevision != model.gpuRevision {
      context.coordinator.builtRevision = model.gpuRevision
      scene.rootNode.childNodes
        .filter { $0.name == "geom" || $0.name == "light" }
        .forEach { $0.removeFromParentNode() }

      for mesh in model.gpuMeshes where !mesh.indices.isEmpty {
        let node = SCNNode(geometry: geometry(from: mesh, theme: model.theme))
        node.name = "geom"
        scene.rootNode.addChildNode(node)
      }
      for light in [model.theme.key, model.theme.fill, model.theme.rim] {
        let node = SCNNode()
        node.name = "light"
        let l = SCNLight()
        l.type = .directional
        l.intensity = CGFloat(light.intensity / 3)  // lux → SceneKit scale
        l.color = NSColor(
          red: CGFloat(light.color.x), green: CGFloat(light.color.y),
          blue: CGFloat(light.color.z), alpha: 1)
        node.light = l
        node.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0),
          localFront: SCNVector3(0, 0, -1))
        node.position = SCNVector3(-light.from.x, -light.from.y, -light.from.z)
        node.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(node)
      }
    }

    if let cam = scene.rootNode.childNode(withName: "camera", recursively: false) {
      let p = model.cameraPosition
      cam.position = SCNVector3(p.x, p.y, p.z)
      let up = model.cameraUp
      cam.look(
        at: SCNVector3(model.cameraTarget.x, model.cameraTarget.y, model.cameraTarget.z),
        up: SCNVector3(up.x, up.y, up.z), localFront: SCNVector3(0, 0, -1))
    }
  }

  private func geometry(from mesh: GpuMeshData, theme: CADTheme) -> SCNGeometry {
    let vertexCount = mesh.positions.count / 3
    var positions: [SCNVector3] = []
    var normals: [SCNVector3] = []
    positions.reserveCapacity(vertexCount)
    normals.reserveCapacity(vertexCount)
    for i in 0..<vertexCount {
      positions.append(
        SCNVector3(mesh.positions[i * 3], mesh.positions[i * 3 + 1], mesh.positions[i * 3 + 2]))
      normals.append(
        SCNVector3(mesh.normals[i * 3], mesh.normals[i * 3 + 1], mesh.normals[i * 3 + 2]))
    }
    // Per-vertex colors (faces carry the theme/CAD color; edges are dark).
    let colorData = Data(bytes: mesh.colors, count: mesh.colors.count * 4)
    let colorSource = SCNGeometrySource(
      data: colorData, semantic: .color, vectorCount: vertexCount,
      usesFloatComponents: true, componentsPerVector: 3,
      bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
    let indexData = Data(bytes: mesh.indices, count: mesh.indices.count * 4)
    let element = SCNGeometryElement(
      data: indexData, primitiveType: .triangles,
      primitiveCount: mesh.indices.count / 3, bytesPerIndex: 4)
    let geometry = SCNGeometry(
      sources: [
        SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals),
        colorSource,
      ], elements: [element])
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.roughness.contents = CGFloat(theme.roughness)
    material.metalness.contents = CGFloat(theme.metallic)
    material.diffuse.contents = NSColor.white  // vertex colors drive hue
    geometry.materials = [material]
    return geometry
  }
}
