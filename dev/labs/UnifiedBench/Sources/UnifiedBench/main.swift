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

/// Thin square tube along a polyline — the raw geometry, so it can feed both
/// a RealityKit MeshResource and the flat GPU buffers (Metal/WebGL) that need
/// the dark edges to get the same "outlined" look.
func tubeGeometry(points: [SIMD3<Float>], radius: Float)
  -> (positions: [SIMD3<Float>], normals: [SIMD3<Float>], indices: [UInt32])
{
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
  return (positions, normals, indices)
}

func tubeResource(points: [SIMD3<Float>], radius: Float) throws -> MeshResource {
  let g = tubeGeometry(points: points, radius: radius)
  var descriptor = MeshDescriptor(name: "edge")
  descriptor.positions = MeshBuffers.Positions(g.positions)
  descriptor.normals = MeshBuffers.Normals(g.normals)
  descriptor.primitives = .triangles(g.indices)
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
  baseColor: SIMD4<Float> = SIMD4<Float>(0.72, 0.74, 0.78, 1),
  theme: CADTheme = .studioBlue
) -> RealityKit.Material {
  switch (kind, selected) {
  case (.face, false):
    return theme.surfaceMaterial(baseColor: theme.faceColor(fileColor: baseColor))
  case (.face, true):
    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(tint: theme.selectedFace)
    material.emissiveColor = .init(color: theme.selectedFace.withAlphaComponent(0.4))
    material.roughness = 0.4
    return material
  case (.edge, false):
    // Unlit = flat, no shading/specular, so an edge reads as a LINE drawn on
    // the model, not a shaded 3D tube sitting on top of it.
    return UnlitMaterial(color: theme.edge)
  case (.edge, true):
    return UnlitMaterial(color: theme.selectedEdge)
  }
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
  var theme: CADTheme = .studioBlue
  var themeRevision = 0
  var appliedThemeRevisionRK = -1  // last theme revision the RealityKit lights reflect
  var loadedURLs: [URL] = []
  var status = "Add Files… (STEP / STL / OBJ) or Add Demo Part"

  /// Apply a theme: re-material + relight immediately (instant lighting/color
  /// feedback), then reload loaded files so edge PROMINENCE re-bakes per theme
  /// (Technical = thick outlines, Showroom = none). No re-parse if nothing is
  /// loaded.
  func setTheme(_ newTheme: CADTheme) {
    theme = newTheme
    for entity in workspace.children { reMaterial(entity) }
    themeRevision += 1
    gpuRevision += 1
    status = "Theme: \(newTheme.name)"
    let urls = loadedURLs
    guard !urls.isEmpty else { return }
    Task {
      clear()
      for url in urls { await load(url: url) }
    }
  }

  private func reMaterial(_ entity: Entity) {
    if let feature = entity.components[BenchFeatureComponent.self],
      let model = entity as? ModelEntity
    {
      model.model?.materials = [
        featureMaterial(
          kind: feature.kind, selected: feature.isSelected,
          baseColor: feature.baseColor, theme: theme)
      ]
    }
    for child in entity.children { reMaterial(child) }
  }

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
    if !loadedURLs.contains(url) { loadedURLs.append(url) }
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
          mesh: resource, materials: [featureMaterial(kind: .face, selected: false, theme: theme)])
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
    let fileColor =
      mesh.has_color == 1
      ? SIMD4<Float>(mesh.color.0, mesh.color.1, mesh.color.2, mesh.color.3)
      : fallbackColor
    // Honor the theme's whole-part color override (SolidWorks/Onshape/etc.).
    let c = theme.faceColor(fileColor: fileColor)
    for _ in 0..<vertexCount {
      gpu.colors.append(contentsOf: [c.x, c.y, c.z])
    }
    for i in 0..<(Int(mesh.triangle_count) * 3) {
      gpu.indices.append(base + mesh.indices[i])
    }
  }

  /// Append raw triangle geometry (e.g. an edge tube) with one flat color, so
  /// the Metal/WebGL buffers carry the dark edges that give the outlined look.
  private func appendRaw(
    _ gpu: inout GpuMeshData, positions: [SIMD3<Float>],
    normals: [SIMD3<Float>], indices: [UInt32], color: SIMD3<Float>
  ) {
    let base = UInt32(gpu.positions.count / 3)
    for p in positions { gpu.positions.append(contentsOf: [p.x, p.y, p.z]) }
    for n in normals { gpu.normals.append(contentsOf: [n.x, n.y, n.z]) }
    for _ in positions { gpu.colors.append(contentsOf: [color.x, color.y, color.z]) }
    for idx in indices { gpu.indices.append(base + idx) }
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
        materials: [featureMaterial(kind: .face, selected: false, baseColor: baseColor, theme: theme)])
      pickTargets.append(
        (model, resource, BenchFeatureComponent(kind: .face, baseColor: baseColor)))
      entity.addChild(model)
      appendGpu(&gpu, mesh: face, fallbackColor: baseColor)
    }
    let bounds = entity.visualBounds(relativeTo: nil)
    // Thin, line-like — an edge should read as a drawn line, not a tube.
    // Per-theme level only nudges the width; it never gets object-thick.
    let edgeRadius = max(bounds.boundingRadius, 0.001) * 0.0016
      * (0.6 + theme.edgeStrength * 0.7)
    for i in 0..<Int(set.edge_count) where theme.edgeStrength > 0.02 {
      let edge = set.edges[i]
      let points = (0..<Int(edge.point_count)).map { p in
        SIMD3<Float>(
          edge.points[p * 3], edge.points[p * 3 + 1], edge.points[p * 3 + 2])
      }
      guard points.count > 1 else { continue }
      let geometry = tubeGeometry(points: points, radius: edgeRadius)
      guard
        let resource = try? {
          var d = MeshDescriptor(name: "edge")
          d.positions = MeshBuffers.Positions(geometry.positions)
          d.normals = MeshBuffers.Normals(geometry.normals)
          d.primitives = .triangles(geometry.indices)
          return try MeshResource.generate(from: [d])
        }()
      else { continue }
      let model = ModelEntity(
        mesh: resource, materials: [featureMaterial(kind: .edge, selected: false, theme: theme)])
      pickTargets.append((model, resource, BenchFeatureComponent(kind: .edge)))
      entity.addChild(model)
      // Feed the same dark edges into the GPU buffers (Metal/WebGL).
      appendRaw(
        &gpu, positions: geometry.positions, normals: geometry.normals,
        indices: geometry.indices, color: theme.edgeColorRGB)
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
        kind: feature.kind, selected: feature.isSelected,
        baseColor: feature.baseColor, theme: theme)
    ]
    status = "\(feature.kind == .face ? "Face" : "Edge") \(feature.isSelected ? "selected" : "deselected")"
  }

  func clear() {
    workspace.children.removeAll()
    files.removeAll()
    loadedURLs.removeAll()
    gpuMeshes.removeAll()
    gpuRevision += 1
    slotIndex = 0
    status = "Cleared"
  }

  // ---- CAD camera — orbit/pan/zoom/ROLL (roll harvested from Codex's
  // CADCameraState). Shared by RealityKit/Metal/SceneKit; the GL/web views
  // own their own mouse.
  var cameraYaw: Float = 0.5
  var cameraPitch: Float = -0.35
  var cameraDistance: Float = 0.55
  var cameraRoll: Float = 0
  var cameraTarget = SIMD3<Float>(0, 0, -0.05)

  var cameraPosition: SIMD3<Float> {
    cameraTarget
      + cameraDistance
      * SIMD3<Float>(
        cos(cameraPitch) * sin(cameraYaw),
        -sin(cameraPitch),
        cos(cameraPitch) * cos(cameraYaw))
  }

  /// Camera-up after applying roll about the viewing axis (Codex's technique).
  var cameraUp: SIMD3<Float> {
    let forward = simd_normalize(cameraTarget - cameraPosition)
    var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
    if simd_length_squared(right) < 0.000_001 { right = SIMD3<Float>(1, 0, 0) }
    right = simd_normalize(right)
    let baseUp = simd_normalize(simd_cross(right, forward))
    return simd_quatf(angle: cameraRoll, axis: forward).act(baseUp)
  }

  func orbit(dx: Float, dy: Float) {
    cameraYaw -= dx * 0.008
    cameraPitch = min(max(cameraPitch + dy * 0.008, -1.5), 1.5)
  }

  func roll(dx: Float) {
    cameraRoll -= dx * 0.006
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
    cameraRoll = 0
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
      model.theme.addLighting(to: content)
      model.subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
        Task { @MainActor in model.frameCount += 1 }
      }
    } update: { content in
      if let camera = content.entities.first(where: { $0.name == "camera" }) {
        camera.position = model.cameraPosition
        camera.look(at: model.cameraTarget, from: camera.position, relativeTo: nil)
        let forward = simd_normalize(model.cameraTarget - camera.position)
        camera.orientation = simd_quatf(angle: model.cameraRoll, axis: forward) * camera.orientation
      }
    }
    // Rebuild the RealityView when the theme changes — make: re-runs, so the
    // theme's lights are added fresh (materials are already re-applied by
    // setTheme). This is the reliable way to get lighting to actually change.
    .id(model.themeRevision)
    .background(Color(model.theme.backgroundNSColor))
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
          if event.modifierFlags.contains(.shift) {
            model.roll(dx: Float(event.deltaX))
          } else {
            model.orbit(dx: Float(event.deltaX), dy: Float(event.deltaY))
          }
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

  private var themeBinding: Binding<CADTheme> {
    Binding(get: { model.theme }, set: { model.setTheme($0) })
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Unified Bench").font(.title3.bold())
      Text("Viewport backend").font(.caption).foregroundStyle(.secondary)
      Picker("", selection: $backend) {
        ForEach(PipelineBackend.allCases) { pipeline in
          Text(pipeline.rawValue).tag(pipeline)
        }
      }
      .pickerStyle(.radioGroup)
      .labelsHidden()

      Divider()
      Text("Theme").font(.caption).foregroundStyle(.secondary)
      Picker("", selection: themeBinding) {
        ForEach(CADTheme.all) { theme in
          Text(theme.name).tag(theme)
        }
      }
      .pickerStyle(.menu)
      .labelsHidden()
      Text("Applies to the RealityKit / Metal views live — same look, switchable.")
        .font(.system(size: 9)).foregroundStyle(.tertiary)

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
      Text("Qt + GLES + MetalANGLE: not built (needs MetalANGLE + Open CASCADE rebuilt with GLES).")
        .font(.system(size: 9))
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
  }

  private var viewport: some View {
    ZStack(alignment: .topLeading) {
      switch backend {
      case .realityKit: AnyView(RealityKitViewportView(model: model))
      case .metalKit: AnyView(MetalViewport(model: model))
      case .sceneKit: AnyView(SceneKitViewport(model: model))
      case .occtGL: AnyView(OcctGLViewport(model: model))
      case .webGL: AnyView(WebGLViewport(model: model))
      case .openGeometry: AnyView(OpenGeometryViewport())
      case .qtOCCT:
        AnyView(
          ExternalPipelineView(
            title: "Qt6 + Open CASCADE built-in viewer",
            detail:
              "Qt has its own event loop, so it can't share this Swift app's process — it opens as a separate window. (The same Open CASCADE viewer is embedded here as the \"Open CASCADE built-in viewer\" backend.)",
            launchTitle: "Open Qt window with current file",
            canLaunch: model.lastFileURL != nil, action: { launchQt() }))
      case .unity:
        AnyView(
          ExternalPipelineView(
            title: "Unity (what Bottango is built on)",
            detail:
              "Unity can't read STEP. Our Open CASCADE shim converts the file to OBJ + CAD colors, then Unity renders it — proving Unity is only the renderer, our kernel does the CAD. Opens in the Unity editor (separate app).",
            launchTitle: "Convert current file + open in Unity",
            canLaunch: model.lastFileURL != nil, action: { launchUnity() }))
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
        Text("drag orbit · shift+drag roll · middle-drag pan · scroll zoom · click select")
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
      "UnifiedBench/pipelines/qt/build/qtbench.app/Contents/MacOS/qtbench")
    let process = Process()
    process.executableURL = qt
    process.arguments = [file.path]
    try? process.run()
  }

  private func launchUnity() {
    guard let file = model.lastFileURL else { return }
    let labs = labsRootURL()
    let converter = labs.appendingPathComponent("UnifiedBench/pipelines/unity/step_to_obj")
    let modelsDir = labs.appendingPathComponent("UnifiedBench/pipelines/unity/UnityBench/Assets/Models")
    let base = modelsDir.appendingPathComponent(
      file.deletingPathExtension().lastPathComponent).path
    // Convert the current STEP via the Open CASCADE shim, then open the project.
    if FileManager.default.fileExists(atPath: converter.path) {
      let convert = Process()
      convert.executableURL = converter
      convert.arguments = [file.path, base]
      try? convert.run()
      convert.waitUntilExit()
    }
    let project = labs.appendingPathComponent("UnifiedBench/pipelines/unity/UnityBench")
    let unity = URL(fileURLWithPath:
      "/Applications/Unity/Hub/Editor/2022.3.30f1/Unity.app/Contents/MacOS/Unity")
    if FileManager.default.fileExists(atPath: unity.path) {
      let process = Process()
      process.executableURL = unity
      process.arguments = ["-projectPath", project.path]
      try? process.run()
    } else {
      NSWorkspace.shared.open(project)  // fall back to opening the folder
    }
  }
}

/// Panel for pipelines that must run as a separate process (Qt / Unity own
/// their event loop — no in-Swift embedding). Keeps them as radio buttons for
/// a consistent list, while being honest about the separate window.
struct ExternalPipelineView: View {
  let title: String
  let detail: String
  let launchTitle: String
  let canLaunch: Bool
  let action: () -> Void

  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: "macwindow.on.rectangle").font(.system(size: 40))
        .foregroundStyle(.secondary)
      Text(title).font(.title3.bold())
      Text(detail).font(.callout).foregroundStyle(.secondary)
        .multilineTextAlignment(.center).frame(maxWidth: 460)
      Button(launchTitle, action: action).disabled(!canLaunch)
      if !canLaunch {
        Text("Load a file first.").font(.caption).foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(NSColor(red: 0.1, green: 0.11, blue: 0.13, alpha: 1)))
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
    WindowGroup("Unified Bench — all pipelines, one workspace") {
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
