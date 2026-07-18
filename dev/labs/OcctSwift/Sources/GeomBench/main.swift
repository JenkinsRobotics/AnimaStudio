// GeomBench — modular benchmarking workspace for six CAD pipeline configs.
//
//   P1 OCCT shim → Swift → RealityKit      (in-process backend)
//   P2 OCCT shim → Swift → custom MetalKit (in-process backend)
//   P3 OCCT built-in GL → SwiftUI wrapper  (in-process backend)
//   P4 Qt6 + OCCT built-in GL              (external process, launched here)
//   P5 Qt6 + OCCT GLES + MetalANGLE        (blocked — see sidebar note)
//   P6 ModelIO → RealityKit quick-parser   (in-process backend, no B-rep)
//
// One workspace, one file set, toggleable viewport backend, live telemetry
// (pipeline name, load ms, FPS, CPU %, MEM MB + Apple's Metal GPU HUD).
// CAD mouse: drag orbit · middle-drag pan · scroll zoom · shift+scroll pan.
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

// ---------- Selection (P1) ---------------------------------------------------

struct BenchFeatureComponent: Component {
  enum Kind { case face, edge }
  let kind: Kind
  var isSelected = false
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

// ---------- Model / telemetry ------------------------------------------------

struct LoadedFile: Identifiable {
  let id = UUID()
  let name: String
  let kind: String
  let faceCount: Int
  let edgeCount: Int
  let triangleCount: Int
  let loadSeconds: Double
}

/// Flat mesh arrays for the custom MetalKit backend (P2) — slot transform
/// baked in so every backend shows the same layout.
struct GpuMeshData {
  var positions: [Float] = []
  var normals: [Float] = []
  var colors: [Float] = []
  var indices: [UInt32] = []
}

@MainActor @Observable
final class BenchModel {
  var files: [LoadedFile] = []
  var gpuMeshes: [GpuMeshData] = []
  var gpuRevision = 0
  var lastFileURL: URL?
  var fps: Double = 0
  var cpuPercent: Double = 0
  var memoryMB: Double = 0
  var status = "Add Files… (STEP / STL / OBJ) or Add Demo Part"

  let workspace = Entity()
  var frameCount = 0
  var subscription: EventSubscription?
  var modelIOSubscription: EventSubscription?
  var occtFPSSource: (() -> Int)?
  private var lastClock = clock()
  private var lastWall = Date()

  func tickTelemetry() {
    if let occtFPSSource { frameCount += occtFPSSource() }
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

  /// Place in the grid, normalized. Returns the transform so the Metal
  /// backend can bake the identical layout into its flat arrays.
  @discardableResult
  func addEntity(_ entity: Entity, normalizedTo target: Float = 0.055)
    -> (scale: Float, center: SIMD3<Float>, slot: SIMD3<Float>)
  {
    let bounds = entity.visualBounds(relativeTo: nil)
    let radius = max(bounds.boundingRadius, 0.000_1)
    let scale = target / radius
    entity.scale *= SIMD3<Float>(repeating: scale)
    let slot = nextSlot()
    entity.position = slot - bounds.center * scale
    workspace.addChild(entity)
    return (scale, bounds.center, slot)
  }

  private func bake(_ mesh: inout GpuMeshData, scale: Float, center: SIMD3<Float>, slot: SIMD3<Float>) {
    for i in 0..<(mesh.positions.count / 3) {
      let p = SIMD3<Float>(
        mesh.positions[i * 3], mesh.positions[i * 3 + 1], mesh.positions[i * 3 + 2])
      let baked = (p - center) * scale + slot
      mesh.positions[i * 3] = baked.x
      mesh.positions[i * 3 + 1] = baked.y
      mesh.positions[i * 3 + 2] = baked.z
    }
  }

  func loadDemoPart() async {
    let set = occt_demo_part_set(0.02)
    await addShapeSet(set, name: "Demo Part (kernel)", kind: "STEP")
  }

  func load(url: URL) async {
    lastFileURL = url
    let ext = url.pathExtension.lowercased()
    if ext == "step" || ext == "stp" {
      status = "Loading \(url.lastPathComponent)…"
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
      var gpu = GpuMeshData()
      if let resource = try? meshResource(from: mesh) {
        let model = ModelEntity(
          mesh: resource, materials: [featureMaterial(kind: .face, selected: false)])
        if let shape = try? await ShapeResource.generateStaticMesh(from: resource) {
          model.components.set(CollisionComponent(shapes: [shape]))
          model.components.set(InputTargetComponent())
          model.components.set(BenchFeatureComponent(kind: .face))
        }
        entity.addChild(model)
        appendGpu(&gpu, mesh: mesh, fallbackColor: SIMD4<Float>(0.72, 0.74, 0.78, 1))
      }
      files.append(
        LoadedFile(
          name: url.lastPathComponent, kind: ext.uppercased(), faceCount: 0,
          edgeCount: 0, triangleCount: Int(mesh.triangle_count),
          loadSeconds: -start.timeIntervalSinceNow))
      occt_free_mesh(mesh)
      let transform = addEntity(entity)
      bake(&gpu, scale: transform.scale, center: transform.center, slot: transform.slot)
      gpuMeshes.append(gpu)
      gpuRevision += 1
      fitView()
      status = "\(url.lastPathComponent): mesh only (no B-rep faces/edges)"
    }
  }

  private func appendGpu(
    _ gpu: inout GpuMeshData, mesh: OcctMesh, fallbackColor: SIMD4<Float>
  ) {
    let base = UInt32(gpu.positions.count / 3)
    let vertexCount = Int(mesh.vertex_count)
    for i in 0..<(vertexCount * 3) {
      gpu.positions.append(mesh.positions[i])
      gpu.normals.append(mesh.normals[i])
    }
    let color =
      mesh.has_color == 1
      ? SIMD3<Float>(mesh.color.0, mesh.color.1, mesh.color.2)
      : SIMD3<Float>(fallbackColor.x, fallbackColor.y, fallbackColor.z)
    for _ in 0..<vertexCount {
      gpu.colors.append(contentsOf: [color.x, color.y, color.z])
    }
    for i in 0..<(Int(mesh.triangle_count) * 3) {
      gpu.indices.append(base + mesh.indices[i])
    }
  }

  private func addShapeSet(_ set: OcctShapeSet, name: String, kind: String) async {
    let start = Date()
    let entity = Entity()
    var gpu = GpuMeshData()
    var triangles = 0
    var pickTargets: [(ModelEntity, MeshResource, BenchFeatureComponent)] = []
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
      pickTargets.append(
        (model, resource, BenchFeatureComponent(kind: .face, baseColor: baseColor)))
      entity.addChild(model)
      appendGpu(&gpu, mesh: face, fallbackColor: baseColor)
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
      pickTargets.append((model, resource, BenchFeatureComponent(kind: .edge)))
      entity.addChild(model)
    }
    status = "\(name): cooking \(pickTargets.count) pick targets…"
    let shapes: [ShapeResource?] = await withTaskGroup(
      of: (Int, ShapeResource?).self
    ) { group in
      for (index, target) in pickTargets.enumerated() {
        let resource = target.1
        group.addTask {
          (index, try? await ShapeResource.generateStaticMesh(from: resource))
        }
      }
      var results = [ShapeResource?](repeating: nil, count: pickTargets.count)
      for await (index, shape) in group { results[index] = shape }
      return results
    }
    for (index, target) in pickTargets.enumerated() {
      guard let shape = shapes[index] else { continue }
      target.0.components.set(CollisionComponent(shapes: [shape]))
      target.0.components.set(InputTargetComponent())
      target.0.components.set(target.2)
    }
    files.append(
      LoadedFile(
        name: name, kind: kind, faceCount: Int(set.face_count),
        edgeCount: Int(set.edge_count), triangleCount: triangles,
        loadSeconds: set.kernel_seconds + set.mesh_seconds
          + (-start.timeIntervalSinceNow)))
    occt_free_shape_set(set)
    let transform = addEntity(entity)
    bake(&gpu, scale: transform.scale, center: transform.center, slot: transform.slot)
    gpuMeshes.append(gpu)
    gpuRevision += 1
    fitView()
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
        kind: feature.kind, selected: feature.isSelected, baseColor: feature.baseColor)
    ]
    status = "\(feature.kind == .face ? "Face" : "Edge") \(feature.isSelected ? "selected" : "deselected")"
  }

  func clear() {
    workspace.children.removeAll()
    files.removeAll()
    gpuMeshes.removeAll()
    gpuRevision += 1
    slotIndex = 0
    status = "Cleared"
  }

  // ---- CAD camera (shared by P1/P2/P6; P3 handles its own mouse) ----------
  var cameraYaw: Float = 0.5
  var cameraPitch: Float = -0.35
  var cameraDistance: Float = 0.55
  var cameraTarget = SIMD3<Float>(0, 0, -0.05)

  var cameraPosition: SIMD3<Float> {
    cameraTarget
      + cameraDistance
      * SIMD3<Float>(
        cos(cameraPitch) * sin(cameraYaw),
        -sin(cameraPitch),
        cos(cameraPitch) * cos(cameraYaw))
  }

  func orbit(dx: Float, dy: Float) {
    cameraYaw -= dx * 0.008
    cameraPitch = min(max(cameraPitch + dy * 0.008, -1.5), 1.5)
  }

  func pan(dx: Float, dy: Float) {
    let forward = simd_normalize(cameraTarget - cameraPosition)
    let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
    let up = simd_cross(right, forward)
    let factor = cameraDistance * 0.0016
    cameraTarget += right * (-dx * factor) + up * (dy * factor)
  }

  func zoom(delta: Float) {
    cameraDistance = min(max(cameraDistance * (1 - delta * 0.03), 0.02), 20)
  }

  /// Center the orbit on the actual loaded geometry and pull back to frame
  /// it. Without this the camera orbits a fixed point while parts (laid out
  /// in a grid) swing out of view — the "rotation isn't centered" bug.
  func fitView() {
    let bounds = workspace.visualBounds(relativeTo: nil)
    if bounds.boundingRadius.isFinite && bounds.boundingRadius > 0 {
      cameraTarget = bounds.center
      cameraDistance = bounds.boundingRadius * 2.4
    } else {
      cameraTarget = .zero
      cameraDistance = 0.55
    }
    cameraYaw = 0.5
    cameraPitch = -0.35
  }
}

// ---------- P1 viewport ------------------------------------------------------

struct RealityKitViewportView: View {
  let model: BenchModel

  var body: some View {
    RealityView { content in
      content.add(model.workspace)
      let camera = PerspectiveCamera()
      camera.name = "camera"
      content.add(camera)
      addBenchLighting(to: content)
      model.subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
        Task { @MainActor in model.frameCount += 1 }
      }
    } update: { content in
      if let camera = content.entities.first(where: { $0.name == "camera" }) {
        camera.position = model.cameraPosition
        camera.look(at: model.cameraTarget, from: camera.position, relativeTo: nil)
      }
    }
    .gesture(
      SpatialTapGesture().targetedToAnyEntity().onEnded { value in
        model.toggle(value.entity)
      }
    )
  }
}

// ---------- Workspace UI -----------------------------------------------------

struct BenchView: View {
  @State private var model = BenchModel()
  @State private var backend: PipelineBackend = .realityKit
  @State private var eventMonitor: Any?
  private let telemetryTimer = Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()

  var body: some View {
    HSplitView {
      sidebar.frame(minWidth: 250, maxWidth: 320)
      viewport.frame(minWidth: 700, maxWidth: .infinity)
    }
    .frame(minWidth: 1200, minHeight: 800)
    .onReceive(telemetryTimer) { _ in model.tickTelemetry() }
    .onAppear {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
      // Auto-load files passed on the command line (TestLab compare launches,
      // and the agent's end-to-end verification).
      let cliFiles = CommandLine.arguments.dropFirst()
        .filter { !$0.hasPrefix("--") && $0.contains("/") }
      if !cliFiles.isEmpty {
        Task { @MainActor in
          for path in cliFiles {
            await model.load(url: URL(fileURLWithPath: path))
          }
          let report = model.files.map {
            "\($0.name) [\($0.kind)] tri=\($0.triangleCount) faces=\($0.faceCount) edges=\($0.edgeCount) \(Int($0.loadSeconds * 1000))ms"
          }.joined(separator: "\n")
          try? (report + "\nstatus: \(model.status)\n").write(
            toFile: "/tmp/geombench_result.txt", atomically: true, encoding: .utf8)
        }
      }
      eventMonitor = NSEvent.addLocalMonitorForEvents(
        matching: [
          .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
          .scrollWheel, .magnify,
        ]
      ) { event in
        guard backend != .occtGL else { return event }  // P3 owns its mouse
        switch event.type {
        case .leftMouseDragged, .rightMouseDragged:
          model.orbit(dx: Float(event.deltaX), dy: Float(event.deltaY))
        case .otherMouseDragged:
          model.pan(dx: Float(event.deltaX), dy: Float(event.deltaY))
        case .scrollWheel:
          if event.modifierFlags.contains(.shift) {
            model.pan(dx: Float(event.scrollingDeltaX + event.scrollingDeltaY), dy: 0)
          } else {
            model.zoom(delta: Float(event.scrollingDeltaY) * 0.4)
          }
        case .magnify:
          model.zoom(delta: Float(event.magnification) * 8)
        default:
          break
        }
        return event
      }
    }
    .onDisappear {
      if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Claude Bench").font(.title3.bold())
      Text("Viewport backend").font(.caption).foregroundStyle(.secondary)
      Picker("", selection: $backend) {
        ForEach(PipelineBackend.allCases) { pipeline in
          Text(pipeline.rawValue).tag(pipeline)
        }
      }
      .pickerStyle(.radioGroup)
      .labelsHidden()

      Divider()
      HStack {
        Button("Add Files…") { pickFiles() }
        Button("Demo") { Task { await model.loadDemoPart() } }
      }
      HStack {
        Button("Fit View") { model.fitView() }
        Button("Clear") { model.clear() }
      }

      Divider()
      Text("Files").font(.caption).foregroundStyle(.secondary)
      List(model.files) { file in
        VStack(alignment: .leading, spacing: 1) {
          Text(file.name).font(.system(size: 11, weight: .medium))
          Text(
            "\(file.kind) · tri \(file.triangleCount) · f \(file.faceCount) · e \(file.edgeCount) · \(Int(file.loadSeconds * 1000))ms"
          )
          .font(.system(size: 9, design: .monospaced))
          .foregroundStyle(.secondary)
        }
      }
      .listStyle(.sidebar)

      Divider()
      Text("External Qt pipelines").font(.caption).foregroundStyle(.secondary)
      Button("Launch: Qt + Open CASCADE viewer") { launchQt() }
        .disabled(model.lastFileURL == nil)
      Text("Qt + OpenGL-ES + MetalANGLE: blocked (needs MetalANGLE built from source AND Open CASCADE rebuilt with GLES). Unity: not installed — needs the Unity editor + account sign-in.")
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
  }

  private var viewport: some View {
    ZStack(alignment: .topLeading) {
      switch backend {
      case .realityKit: AnyView(RealityKitViewportView(model: model))
      case .metalKit: AnyView(MetalViewport(model: model))
      case .occtGL: AnyView(OcctGLViewport(model: model))
      case .webGL: AnyView(WebGLViewport(model: model))
      case .modelIO: AnyView(ModelIOViewport(model: model))
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(backend.fullName).font(.system(.caption, design: .monospaced).bold())
        Text(backend.capabilities)
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(.secondary)
        Text(String(
          format: "FPS %3.0f   CPU %5.1f%%   MEM %6.1f MB   files %d   tris %d",
          model.fps, model.cpuPercent, model.memoryMB, model.files.count,
          model.files.reduce(0) { $0 + $1.triangleCount }))
          .font(.system(.caption, design: .monospaced))
        Text(model.status).font(.system(size: 10, design: .monospaced))
          .foregroundStyle(model.status.contains("failed") ? .red : .secondary)
        Text("drag orbit · middle-drag pan · scroll zoom · shift+scroll pan · click select")
          .font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
      }
      .padding(8)
      .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
      .padding(10)
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

  private func launchQt() {
    guard let file = model.lastFileURL else { return }
    let qt = labsRootURL().appendingPathComponent(
      "qtbench/build/qtbench.app/Contents/MacOS/qtbench")
    let process = Process()
    process.executableURL = qt
    process.arguments = [file.path]
    try? process.run()
  }
}

func labsRootURL() -> URL {
  var url = URL(fileURLWithPath: Bundle.main.executablePath ?? ".")
    .resolvingSymlinksInPath()
  for _ in 0..<8 {
    url.deleteLastPathComponent()
    if FileManager.default.fileExists(atPath: url.appendingPathComponent("build.sh").path) {
      return url
    }
    let nested = url.appendingPathComponent("dev/labs", isDirectory: true)
    if FileManager.default.fileExists(atPath: nested.appendingPathComponent("build.sh").path) {
      return nested
    }
  }
  return URL(fileURLWithPath: "/Users/jonathanjenkins/GITHUB/AnimaStudio/dev/labs")
}

struct GeomBenchApp: App {
  init() {
    DispatchQueue.main.async {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  var body: some SwiftUI.Scene {
    WindowGroup("Claude Bench — six-pipeline CAD workspace") {
      BenchView()
    }
  }
}

// NOTE: do NOT set MTL_HUD_ENABLED here. Apple's Metal Performance HUD
// (libMTLHud) crashes at window creation with SwiftUI+RealityKit on this OS
// (null jump in HUDMTLLayerTracking safeAreaInsets — crash report on file),
// which is exactly why GeomBench windows kept silently dying. To see GPU
// stats, enable the system-wide Metal HUD toggle instead.

if CommandLine.arguments.contains("--headless") {
  let paths = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
  Task { @MainActor in
    let model = BenchModel()
    for path in paths {
      await model.load(url: URL(fileURLWithPath: path))
    }
    for file in model.files {
      print(
        "\(file.name) [\(file.kind)] tri=\(file.triangleCount) faces=\(file.faceCount) edges=\(file.edgeCount) \(Int(file.loadSeconds * 1000))ms entities=\(model.workspace.children.count) gpuMeshes=\(model.gpuMeshes.count)"
      )
    }
    print("status: \(model.status)")
    exit(model.files.count == paths.count ? 0 : 1)
  }
  RunLoop.main.run()
} else {
  GeomBenchApp.main()
}
