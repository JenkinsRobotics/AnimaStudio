// GeomBench — standalone dev app for evaluating the OCCT -> Swift -> Metal
// pipeline under real conditions:
//   · load any files you choose (STL / STEP), as many as you want, one workspace
//   · STEP parts are pickable: click a FACE or an EDGE to highlight it
//     (STL has no faces/edges — that contrast is the point)
//   · live telemetry: per-file load time, FPS, CPU %, memory
//   · Apple's own Metal GPU HUD is enabled (top-right overlay) for GPU stats
//
//   swift run GeomBench            (or run the built binary directly)
//   Drag orbits · pinch/scroll zooms via trackpad · buttons top-left.
import AppKit
import Darwin
import OcctShim
import RealityKit
import SwiftUI
import UniformTypeIdentifiers

// ---------- OCCT -> RealityKit conversion ----------------------------------

func meshResource(from mesh: OcctMesh) throws -> MeshResource {
  let vertexCount = Int(mesh.vertex_count)
  var descriptor = MeshDescriptor(name: "occt")
  descriptor.positions = MeshBuffers.Positions(
    (0..<vertexCount).map { i in
      SIMD3<Float>(
        mesh.positions[i * 3], mesh.positions[i * 3 + 1], mesh.positions[i * 3 + 2])
    })
  descriptor.normals = MeshBuffers.Normals(
    (0..<vertexCount).map { i in
      SIMD3<Float>(mesh.normals[i * 3], mesh.normals[i * 3 + 1], mesh.normals[i * 3 + 2])
    })
  descriptor.primitives = .triangles(
    (0..<(Int(mesh.triangle_count) * 3)).map { UInt32(mesh.indices[$0]) })
  return try MeshResource.generate(from: [descriptor])
}

/// Thin square tube along a polyline, one merged mesh per edge.
func tubeResource(points: [SIMD3<Float>], radius: Float) throws -> MeshResource {
  var positions: [SIMD3<Float>] = []
  var normals: [SIMD3<Float>] = []
  var indices: [UInt32] = []
  for i in 0..<(points.count - 1) {
    let a = points[i], b = points[i + 1]
    let axis = simd_normalize(b - a)
    let ref: SIMD3<Float> = abs(axis.x) < 0.8 ? [1, 0, 0] : [0, 1, 0]
    let u = simd_normalize(simd_cross(axis, ref)) * radius
    let v = simd_normalize(simd_cross(axis, u)) * radius
    let base = UInt32(positions.count)
    for corner in [u + v, u - v, -u - v, -u + v] {
      positions.append(a + corner)
      positions.append(b + corner)
      normals.append(simd_normalize(corner))
      normals.append(simd_normalize(corner))
    }
    for s in 0..<4 {
      let p0 = base + UInt32(s * 2), p1 = p0 + 1
      let q0 = base + UInt32(((s + 1) % 4) * 2), q1 = q0 + 1
      indices.append(contentsOf: [p0, q0, p1, q0, q1, p1])
    }
  }
  var descriptor = MeshDescriptor(name: "edge")
  descriptor.positions = MeshBuffers.Positions(positions)
  descriptor.normals = MeshBuffers.Normals(normals)
  descriptor.primitives = .triangles(indices)
  return try MeshResource.generate(from: [descriptor])
}

// ---------- Selection ------------------------------------------------------

struct BenchFeatureComponent: Component {
  enum Kind { case face, edge }
  let kind: Kind
  var isSelected = false
  /// The CAD-authored face color from STEP (XCAF), or the neutral default.
  var baseColor = SIMD4<Float>(0.72, 0.74, 0.78, 1)
}

@MainActor
func featureMaterial(
  kind: BenchFeatureComponent.Kind, selected: Bool,
  baseColor: SIMD4<Float> = SIMD4<Float>(0.72, 0.74, 0.78, 1)
) -> RealityKit.Material {
  var material = PhysicallyBasedMaterial()
  switch (kind, selected) {
  case (.face, false):
    material.baseColor = .init(
      tint: NSColor(
        red: CGFloat(baseColor.x), green: CGFloat(baseColor.y),
        blue: CGFloat(baseColor.z), alpha: CGFloat(baseColor.w)))
    material.roughness = 0.5
  case (.face, true):
    material.baseColor = .init(tint: .systemOrange)
    material.emissiveColor = .init(color: NSColor.systemOrange.withAlphaComponent(0.4))
    material.roughness = 0.4
  case (.edge, false):
    material.baseColor = .init(tint: NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1))
    material.roughness = 0.7
  case (.edge, true):
    material.baseColor = .init(tint: .systemTeal)
    material.emissiveColor = .init(color: NSColor.systemTeal.withAlphaComponent(0.6))
    material.roughness = 0.3
  }
  return material
}

// ---------- Model / telemetry ----------------------------------------------

struct LoadedFile: Identifiable {
  let id = UUID()
  let name: String
  let kind: String  // "STEP" or "STL"
  let faceCount: Int
  let edgeCount: Int
  let triangleCount: Int
  let loadSeconds: Double
}

@MainActor @Observable
final class BenchModel {
  var files: [LoadedFile] = []
  var fps: Double = 0
  var cpuPercent: Double = 0
  var memoryMB: Double = 0
  var status = "Add Files… (STL / STEP) or Add Demo Part"

  let workspace = Entity()
  var frameCount = 0
  var subscription: EventSubscription?
  private var lastClock = clock()
  private var lastWall = Date()

  func tickTelemetry() {
    fps = Double(frameCount)
    frameCount = 0
    let nowClock = clock()
    let wallDelta = -lastWall.timeIntervalSinceNow
    if wallDelta > 0 {
      cpuPercent =
        Double(nowClock - lastClock) / Double(CLOCKS_PER_SEC) / wallDelta * 100
    }
    lastClock = nowClock
    lastWall = Date()
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<Int32>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    if kr == KERN_SUCCESS { memoryMB = Double(info.phys_footprint) / 1_048_576 }
  }

  var slotIndex = 0
  func nextSlot() -> SIMD3<Float> {
    let column = slotIndex % 5
    let row = slotIndex / 5
    slotIndex += 1
    return SIMD3<Float>(Float(column) * 0.14 - 0.28, 0, -Float(row) * 0.14)
  }

  func addEntity(_ entity: Entity, normalizedTo target: Float = 0.055) {
    let bounds = entity.visualBounds(relativeTo: nil)
    let radius = max(bounds.boundingRadius, 0.000_1)
    entity.scale *= SIMD3<Float>(repeating: target / radius)
    let scaledCenter = bounds.center * (target / radius)
    entity.position = nextSlot() - scaledCenter
    workspace.addChild(entity)
  }

  func loadDemoPart() async {
    let set = occt_demo_part_set(0.02)
    await addShapeSet(set, name: "Demo Part (kernel)", kind: "STEP")
  }

  func load(url: URL) async {
    let ext = url.pathExtension.lowercased()
    if ext == "step" || ext == "stp" {
      // Fine deflection: STEP's exact surfaces make quality a load-time dial.
      let set = occt_load_step_set(url.path, 0.02)
      if set.face_count == 0 {
        status = "STEP load failed: \(url.lastPathComponent)"
        return
      }
      await addShapeSet(set, name: url.lastPathComponent, kind: "STEP")
    } else {
      let start = Date()
      let mesh =
        ext == "obj"
        ? occt_load_obj(url.path, 0.001) : occt_load_stl(url.path, 0.001)
      guard mesh.vertex_count > 0 else {
        status = "\(ext.uppercased()) load failed: \(url.lastPathComponent)"
        return
      }
      let entity = Entity()
      if let resource = try? meshResource(from: mesh) {
        let model = ModelEntity(
          mesh: resource,
          materials: [featureMaterial(kind: .face, selected: false)])
        // Whole-part pick target only — STL has no faces/edges to select.
        if let shape = try? await ShapeResource.generateStaticMesh(from: resource) {
          model.components.set(CollisionComponent(shapes: [shape]))
          model.components.set(InputTargetComponent())
          model.components.set(BenchFeatureComponent(kind: .face))
        }
        entity.addChild(model)
      }
      files.append(
        LoadedFile(
          name: url.lastPathComponent, kind: ext.uppercased(), faceCount: 0, edgeCount: 0,
          triangleCount: Int(mesh.triangle_count),
          loadSeconds: -start.timeIntervalSinceNow))
      occt_free_mesh(mesh)
      addEntity(entity)
      status = "\(url.lastPathComponent): STL, whole-part selection only"
    }
  }

  private func addShapeSet(_ set: OcctShapeSet, name: String, kind: String) async {
    let start = Date()
    let entity = Entity()
    var triangles = 0
    for i in 0..<Int(set.face_count) {
      let face = set.faces[i]
      triangles += Int(face.triangle_count)
      guard let resource = try? meshResource(from: face) else { continue }
      let baseColor =
        face.has_color == 1
        ? SIMD4<Float>(face.color.0, face.color.1, face.color.2, face.color.3)
        : SIMD4<Float>(0.72, 0.74, 0.78, 1)
      let model = ModelEntity(
        mesh: resource,
        materials: [featureMaterial(kind: .face, selected: false, baseColor: baseColor)])
      if let shape = try? await ShapeResource.generateStaticMesh(from: resource) {
        model.components.set(CollisionComponent(shapes: [shape]))
        model.components.set(InputTargetComponent())
        model.components.set(BenchFeatureComponent(kind: .face, baseColor: baseColor))
      }
      entity.addChild(model)
    }
    let bounds = entity.visualBounds(relativeTo: nil)
    let edgeRadius = max(bounds.boundingRadius, 0.001) * 0.006
    for i in 0..<Int(set.edge_count) {
      let edge = set.edges[i]
      let points = (0..<Int(edge.point_count)).map { p in
        SIMD3<Float>(
          edge.points[p * 3], edge.points[p * 3 + 1], edge.points[p * 3 + 2])
      }
      guard points.count > 1,
        let resource = try? tubeResource(points: points, radius: edgeRadius)
      else { continue }
      let model = ModelEntity(
        mesh: resource, materials: [featureMaterial(kind: .edge, selected: false)])
      if let shape = try? await ShapeResource.generateStaticMesh(from: resource) {
        model.components.set(CollisionComponent(shapes: [shape]))
        model.components.set(InputTargetComponent())
        model.components.set(BenchFeatureComponent(kind: .edge))
      }
      entity.addChild(model)
    }
    files.append(
      LoadedFile(
        name: name, kind: kind, faceCount: Int(set.face_count),
        edgeCount: Int(set.edge_count), triangleCount: triangles,
        loadSeconds: set.kernel_seconds + set.mesh_seconds
          + (-start.timeIntervalSinceNow)))
    occt_free_shape_set(set)
    addEntity(entity)
    status =
      "\(name): \(set.face_count) faces, \(set.edge_count) edges — click to select"
  }

  func toggle(_ entity: Entity) {
    guard var feature = entity.components[BenchFeatureComponent.self],
      let model = entity as? ModelEntity
    else { return }
    feature.isSelected.toggle()
    entity.components.set(feature)
    model.model?.materials = [
      featureMaterial(
        kind: feature.kind, selected: feature.isSelected,
        baseColor: feature.baseColor)
    ]
    status = "\(feature.kind == .face ? "Face" : "Edge") \(feature.isSelected ? "selected" : "deselected")"
  }

  func clear() {
    workspace.children.removeAll()
    files.removeAll()
    slotIndex = 0
    status = "Cleared"
  }
}

// ---------- UI --------------------------------------------------------------

struct BenchView: View {
  @State private var model = BenchModel()
  @State private var yaw: Float = 0.5
  @State private var pitch: Float = -0.4
  @State private var zoom: Float = 1.0
  private let telemetryTimer = Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()

  var body: some View {
    ZStack(alignment: .topLeading) {
      RealityView { content in
        content.add(model.workspace)
        let camera = PerspectiveCamera()
        camera.name = "camera"
        camera.position = SIMD3<Float>(0, 0.22, 0.42)
        camera.look(at: SIMD3<Float>(0, 0, -0.05), from: camera.position, relativeTo: nil)
        content.add(camera)

        // Studio-style three-point lighting — PBR materials are unlit sludge
        // without it, which made the first bench look far worse than the
        // geometry actually is.
        let key = Entity()
        key.components.set(DirectionalLightComponent(
          color: .white, intensity: 3_000))
        key.look(at: .zero, from: SIMD3<Float>(0.5, 0.9, 0.6), relativeTo: nil)
        content.add(key)
        let fill = Entity()
        fill.components.set(DirectionalLightComponent(
          color: NSColor(calibratedRed: 0.75, green: 0.82, blue: 1.0, alpha: 1),
          intensity: 1_200))
        fill.look(at: .zero, from: SIMD3<Float>(-0.7, 0.3, 0.4), relativeTo: nil)
        content.add(fill)
        let rim = Entity()
        rim.components.set(DirectionalLightComponent(
          color: .white, intensity: 900))
        rim.look(at: .zero, from: SIMD3<Float>(0.1, 0.5, -0.8), relativeTo: nil)
        content.add(rim)
        model.subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
          Task { @MainActor in model.frameCount += 1 }
        }
      } update: { content in
        model.workspace.orientation =
          simd_quatf(angle: pitch, axis: [1, 0, 0])
          * simd_quatf(angle: yaw, axis: [0, 1, 0])
        if let camera = content.entities.first(where: { $0.name == "camera" }) {
          camera.position = SIMD3<Float>(0, 0.22, 0.42) * zoom
          camera.look(
            at: SIMD3<Float>(0, 0, -0.05), from: camera.position, relativeTo: nil)
        }
      }
      .gesture(
        SpatialTapGesture().targetedToAnyEntity().onEnded { value in
          model.toggle(value.entity)
        }
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: 4).onChanged { value in
          yaw = 0.5 + Float(value.translation.width) * 0.008
          pitch = -0.4 + Float(value.translation.height) * 0.008
        }
      )
      .simultaneousGesture(
        MagnifyGesture().onChanged { value in
          zoom = min(max(1.0 / Float(value.magnification), 0.15), 6.0)
        }
      )

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Button("Add Files…") { pickFiles() }
          Button("Add Demo Part") { Task { await model.loadDemoPart() } }
          Button("Clear") { model.clear() }
        }
        Text(model.status).font(.system(.caption, design: .monospaced))
        Text(String(
          format: "FPS %3.0f   CPU %5.1f%%   MEM %6.1f MB   files %d   tris %d",
          model.fps, model.cpuPercent, model.memoryMB, model.files.count,
          model.files.reduce(0) { $0 + $1.triangleCount }))
          .font(.system(.caption, design: .monospaced))
        ForEach(model.files.suffix(14)) { file in
          Text(String(
            format: "%@ [%@]  %.0f ms  tri=%d  faces=%d edges=%d",
            file.name, file.kind, file.loadSeconds * 1000, file.triangleCount,
            file.faceCount, file.edgeCount))
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
        }
      }
      .padding(10)
      .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
      .padding(12)
    }
    .frame(minWidth: 1200, minHeight: 800)
    .onReceive(telemetryTimer) { _ in model.tickTelemetry() }
    .onAppear {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func pickFiles() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = ["stl", "step", "stp", "obj"].compactMap {
      UTType(filenameExtension: $0)
    }
    guard panel.runModal() == .OK else { return }
    Task {
      for url in panel.urls { await model.load(url: url) }
    }
  }
}

struct GeomBenchApp: App {
  var body: some SwiftUI.Scene {
    WindowGroup("GeomBench — OCCT + Swift + Metal test bench") {
      BenchView()
    }
  }
}

// Enable Apple's Metal Performance HUD (GPU stats overlay) before any Metal
// device is created — shows real GPU utilization/frame timing top-right.
setenv("MTL_HUD_ENABLED", "1", 1)
GeomBenchApp.main()
