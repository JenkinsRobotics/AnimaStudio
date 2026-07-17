// Swift + Open CASCADE standalone test.
//   OCCT (C++) computes exact B-rep geometry and tessellates it;
//   Swift lifts the buffers into RealityKit (Metal) for native rendering.
// This is the exact architecture Anima Studio would use for STEP import.
//
//   swift run OcctSwiftViewer ["/path/to/part.stl" [scaleToMeters]]
//
// Left: the OCCT demo part (box + bore + fillets, exact kernel geometry).
// Right: the given STL (default: the user's exported CAD part).
// Drag orbits. Results also written to /tmp/occt_swift_result.txt.
import AppKit
import OcctShim
import RealityKit
import SwiftUI

func meshResource(from mesh: OcctMesh) throws -> MeshResource {
  let vertexCount = Int(mesh.vertex_count)
  let indexCount = Int(mesh.triangle_count) * 3
  var descriptor = MeshDescriptor(name: "occt")
  descriptor.positions = MeshBuffers.Positions(
    (0..<vertexCount).map { i in
      SIMD3<Float>(
        mesh.positions[i * 3], mesh.positions[i * 3 + 1], mesh.positions[i * 3 + 2])
    })
  descriptor.normals = MeshBuffers.Normals(
    (0..<vertexCount).map { i in
      SIMD3<Float>(
        mesh.normals[i * 3], mesh.normals[i * 3 + 1], mesh.normals[i * 3 + 2])
    })
  descriptor.primitives = .triangles((0..<indexCount).map { UInt32(mesh.indices[$0]) })
  return try MeshResource.generate(from: [descriptor])
}

@MainActor
func makeEntity(_ mesh: OcctMesh, color: NSColor) throws -> ModelEntity {
  var material = PhysicallyBasedMaterial()
  material.baseColor = .init(tint: color)
  material.roughness = 0.55
  material.metallic = 0.1
  return ModelEntity(mesh: try meshResource(from: mesh), materials: [material])
}

let args = CommandLine.arguments
let positional = args.dropFirst().filter { !$0.hasPrefix("--") }
let stlPath =
  positional.first
  ?? "/Users/jonathanjenkins/Documents/AnimaStudio/single part/characters/test-part/assets/ARCADA001 - Part 1 (2).stl"
let stlScale = positional.count > 1 ? Double(positional[1]) ?? 0.001 : 0.001

struct ViewerView: View {
  @State private var status = "running OCCT kernel…"
  @State private var yaw: Float = 0.6
  @State private var pitch: Float = -0.35
  @State private var root = Entity()

  var body: some View {
    VStack(spacing: 0) {
      Text(status).font(.system(.caption, design: .monospaced)).padding(4)
      RealityView { content in
        var report: [String] = []

        // 1. Exact B-rep from the OCCT kernel (box + bore + fillets).
        let demo = occt_make_demo_part(0.05)
        report.append(String(
          format: "DEMO PART  kernel %.3fs  mesh %.3fs  v=%d tri=%d",
          demo.kernel_seconds, demo.mesh_seconds, demo.vertex_count,
          demo.triangle_count))
        if let entity = try? makeEntity(demo, color: .systemOrange) {
          entity.position = SIMD3<Float>(-0.05, 0, 0)
          root.addChild(entity)
        }
        occt_free_mesh(demo)

        // 2. The user's STL through OCCT's reader.
        let stl = occt_load_stl(stlPath, stlScale)
        if stl.vertex_count > 0 {
          report.append(String(
            format: "STL        read %.3fs  v=%d tri=%d  (%@)",
            stl.mesh_seconds, stl.vertex_count, stl.triangle_count,
            (stlPath as NSString).lastPathComponent))
          if let entity = try? makeEntity(stl, color: .systemTeal) {
            let bounds = entity.visualBounds(relativeTo: nil)
            entity.position = SIMD3<Float>(0.06, 0, 0) - bounds.center
            root.addChild(entity)
          }
        } else {
          report.append("STL READ FAILED: \(stlPath)")
        }
        occt_free_mesh(stl)

        content.add(root)
        let camera = PerspectiveCamera()
        camera.position = SIMD3<Float>(0, 0.10, 0.28)
        camera.look(at: .zero, from: camera.position, relativeTo: nil)
        content.add(camera)

        status = report.joined(separator: "   |   ")
        try? (report.joined(separator: "\n") + "\n").write(
          toFile: "/tmp/occt_swift_result.txt", atomically: true, encoding: .utf8)
      } update: { _ in
        root.orientation =
          simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
          * simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
      }
      .gesture(
        DragGesture().onChanged { value in
          yaw = 0.6 + Float(value.translation.width) * 0.01
          pitch = -0.35 + Float(value.translation.height) * 0.01
        })
    }
    .frame(minWidth: 1000, minHeight: 700)
    .onAppear {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}

struct OcctSwiftApp: App {
  var body: some SwiftUI.Scene {
    WindowGroup("Swift + Open CASCADE — kernel to Metal") {
      ViewerView()
    }
  }
}

// Headless verification path: compute and report without a window.
if args.contains("--headless") {
  let demo = occt_make_demo_part(0.05)
  print(String(
    format: "DEMO PART  kernel %.3fs  mesh %.3fs  v=%d tri=%d",
    demo.kernel_seconds, demo.mesh_seconds, demo.vertex_count, demo.triangle_count))
  occt_free_mesh(demo)
  let stl = occt_load_stl(stlPath, stlScale)
  print(String(
    format: "STL        read %.3fs  v=%d tri=%d", stl.mesh_seconds,
    stl.vertex_count, stl.triangle_count))
  occt_free_mesh(stl)
} else {
  OcctSwiftApp.main()
}
