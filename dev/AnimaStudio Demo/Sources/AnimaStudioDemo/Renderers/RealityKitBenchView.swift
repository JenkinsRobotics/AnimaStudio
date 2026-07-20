import AppKit
import GeomKit
import Metal
import QuartzCore
import RealityKit
import SwiftUI

struct RealityKitBenchView: View {
  private struct LowLevelVertex {
    var position: MTLPackedFloat3
    var normal: MTLPackedFloat3

    init(position: SIMD3<Float>, normal: SIMD3<Float>) {
      var packedPosition = MTLPackedFloat3()
      packedPosition.x = position.x
      packedPosition.y = position.y
      packedPosition.z = position.z
      var packedNormal = MTLPackedFloat3()
      packedNormal.x = normal.x
      packedNormal.y = normal.y
      packedNormal.z = normal.z
      self.position = packedPosition
      self.normal = packedNormal
    }
  }

  @Bindable var session: BenchSession
  var document: GeometryDocument?

  init(session: BenchSession, document: GeometryDocument? = nil) {
    self.session = session
    self.document = document
  }

  var body: some View {
    ZStack {
      RealityView { content in
        if let document { content.add(makeRealityRoot(document)) }
        content.add(makeThemeLight(session.theme.key, name: "ThemeKey"))
        content.add(makeThemeLight(session.theme.fill, name: "ThemeFill"))
        content.add(makeThemeLight(session.theme.rim, name: "ThemeRim"))
        let camera = PerspectiveCamera()
        camera.name = "BenchCamera"
        update(camera: camera)
        content.add(camera)
      } update: { content in
        let roots = content.entities.filter { $0.name.hasPrefix("BenchGeometry-") }
        if let document {
          let expectedName = geometryRootName(document)
          if !roots.contains(where: { $0.name == expectedName }) {
            for root in roots { content.remove(root) }
            content.add(makeRealityRoot(document))
          } else if let root = roots.first(where: { $0.name == expectedName }) {
            updateAppearanceIfNeeded(root: root, document: document)
          }
        } else {
          for root in roots { content.remove(root) }
        }
        if let camera = content.entities.first(where: { $0.name == "BenchCamera" })
          as? PerspectiveCamera
        {
          update(camera: camera)
        }
        if let light = content.entities.first(where: { $0.name == "ThemeKey" }) {
          updateThemeLight(light, value: session.theme.key)
        }
        if let light = content.entities.first(where: { $0.name == "ThemeFill" }) {
          updateThemeLight(light, value: session.theme.fill)
        }
        if let light = content.entities.first(where: { $0.name == "ThemeRim" }) {
          updateThemeLight(light, value: session.theme.rim)
        }
      }
      RealityKitDisplayCadenceCounter { session.tickFrame() }
      CADInputOverlay(
        orbit: { dx, dy in session.camera.orbit(deltaX: dx, deltaY: dy) },
        pan: { dx, dy, height in session.camera.pan(deltaX: dx, deltaY: dy, viewportHeight: height)
        },
        roll: { delta in session.camera.roll(deltaX: delta) },
        zoom: { delta in session.camera.zoom(scrollDelta: delta) },
        select: { session.toggleModelSelection() })
    }
    .background(session.theme.backgroundColor)
  }

  private func update(camera: PerspectiveCamera) {
    camera.position = session.camera.position
    camera.look(at: session.camera.target, from: session.camera.position, relativeTo: nil)
    camera.orientation *= simd_quatf(
      angle: session.camera.rollRadians, axis: SIMD3<Float>(0, 0, -1))
  }

  @MainActor private func makeRealityRoot(_ document: GeometryDocument) -> Entity {
    let root = Entity()
    root.name = geometryRootName(document)
    let geometry = document.renderGeometry
    // RealityKit is the high-level secondary renderer. One retained mesh keeps
    // its entity/resource overhead bounded for CAD assemblies; the Metal
    // production candidate keeps the per-part transform table needed for live
    // animatronic motion without multiplying scene resources.
    if let entity = makeLowLevelAssemblyEntity(batches: geometry.batches, geometry: geometry) {
      entity.name = "Combined Assembly"
      root.addChild(entity)
    }
    if let edgeEntity = makeEdgeEntity(document) {
      root.addChild(edgeEntity)
    }
    let appearanceMarker = Entity()
    appearanceMarker.name = appearanceMarkerName
    root.addChild(appearanceMarker)
    return root
  }

  /// RealityKit's descriptor convenience API spends substantial time
  /// rebuilding and validating large CAD arrays. LowLevelMesh writes the same
  /// part/material topology directly into retained vertex and index storage.
  @MainActor private func makeLowLevelAssemblyEntity(
    batches: [RenderBatch], geometry: RenderGeometry
  ) -> ModelEntity? {
    var vertices: [LowLevelVertex] = []
    var indices: [UInt32] = []
    var parts: [LowLevelMesh.Part] = []
    var materials: [PhysicallyBasedMaterial] = []
    vertices.reserveCapacity(batches.reduce(0) { $0 + $1.vertexRange.count })
    indices.reserveCapacity(batches.reduce(0) { $0 + $1.indexRange.count })

    for (materialIndex, batch) in batches.enumerated() {
      let localVertexStart = UInt32(vertices.count)
      let globalVertexStart = UInt32(batch.vertexRange.lowerBound)
      var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
      var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
      for index in batch.vertexRange {
        let position = geometry.positions[index]
        vertices.append(LowLevelVertex(position: position, normal: geometry.normals[index]))
        minimum = simd_min(minimum, position)
        maximum = simd_max(maximum, position)
      }
      let localIndexStart = indices.count
      indices.append(
        contentsOf: geometry.indices[batch.indexRange].map {
          $0 - globalVertexStart + localVertexStart
        })
      parts.append(
        LowLevelMesh.Part(
          indexOffset: localIndexStart * MemoryLayout<UInt32>.stride,
          indexCount: batch.indexRange.count,
          topology: .triangle,
          materialIndex: materialIndex,
          bounds: BoundingBox(min: minimum, max: maximum)))
      materials.append(makeMaterial(batch.materialColor))
    }
    guard !vertices.isEmpty, !indices.isEmpty else { return nil }

    let descriptor = LowLevelMesh.Descriptor(
      vertexCapacity: vertices.count,
      vertexAttributes: [
        LowLevelMesh.Attribute(semantic: .position, format: .float3, offset: 0),
        LowLevelMesh.Attribute(semantic: .normal, format: .float3, offset: 12),
      ],
      vertexLayouts: [LowLevelMesh.Layout(bufferIndex: 0, bufferStride: 24)],
      indexCapacity: indices.count,
      indexType: .uint32)
    guard let lowLevelMesh = try? LowLevelMesh(descriptor: descriptor) else { return nil }
    lowLevelMesh.withUnsafeMutableBytes(bufferIndex: 0) { destination in
      vertices.withUnsafeBytes { source in
        destination.copyMemory(from: source)
      }
    }
    lowLevelMesh.withUnsafeMutableIndices { destination in
      indices.withUnsafeBytes { source in
        destination.copyMemory(from: source)
      }
    }
    lowLevelMesh.parts.replaceAll(parts)
    guard let mesh = try? MeshResource(from: lowLevelMesh) else { return nil }
    return ModelEntity(mesh: mesh, materials: materials)
  }

  @MainActor private func updateAppearance(root: Entity, document: GeometryDocument) {
    for child in root.children {
      guard let model = child as? ModelEntity else { continue }
      if child.name == "B-Rep Edges" {
        let edge =
          session.isModelSelected ? session.theme.edgeSelectionColor : session.theme.edgeColor
        model.model?.materials = [
          UnlitMaterial(
            color: NSColor(
              srgbRed: CGFloat(edge.x), green: CGFloat(edge.y), blue: CGFloat(edge.z), alpha: 1))
        ]
        model.isEnabled = session.theme.edgeStrength > 0.02
        continue
      }
      guard child.name == "Combined Assembly" else { continue }
      let materials = document.renderGeometry.batches.map { makeMaterial($0.materialColor) }
      if !materials.isEmpty { model.model?.materials = materials }
    }
  }

  /// Camera and telemetry changes can update the RealityView at display rate.
  /// Material creation is deliberately gated behind the much rarer appearance
  /// revision so orbiting never rebuilds hundreds of CAD materials per frame.
  @MainActor private func updateAppearanceIfNeeded(root: Entity, document: GeometryDocument) {
    let marker = root.children.first { $0.name.hasPrefix("BenchAppearance-") }
    guard marker?.name != appearanceMarkerName else { return }
    updateAppearance(root: root, document: document)
    marker?.name = appearanceMarkerName
  }

  private var appearanceMarkerName: String {
    "BenchAppearance-\(session.renderRevision)"
  }

  private func geometryRootName(_ document: GeometryDocument) -> String {
    "BenchGeometry-\(document.identity.uuidString)"
  }

  @MainActor private func makeMaterial(_ rgba8: SIMD4<UInt8>) -> PhysicallyBasedMaterial {
    let source = SIMD4<Float>(rgba8) / 255
    let displayColor = session.theme.displayColor(for: source)
    let faceColor = SIMD3(displayColor.x, displayColor.y, displayColor.z)
    let base =
      session.isModelSelected
      ? simd_mix(faceColor, session.theme.selectionColor, SIMD3(repeating: 0.38)) : faceColor
    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(
      tint: NSColor(
        red: CGFloat(base.x), green: CGFloat(base.y), blue: CGFloat(base.z),
        alpha: CGFloat(displayColor.w)))
    material.roughness = .init(floatLiteral: session.theme.roughness)
    material.metallic = .init(floatLiteral: session.theme.metallic)
    return material
  }

  /// LowLevelMesh exposes Metal line topology that MeshDescriptor does not.
  /// This keeps exact B-Rep edges as one compact draw instead of expanding
  /// every segment into artificial prism triangles.
  @MainActor private func makeEdgeEntity(_ document: GeometryDocument) -> ModelEntity? {
    guard session.theme.edgeStrength > 0.02 else { return nil }
    let geometry = document.renderGeometry
    // RealityKit's public material stack does not expose a CAD wire pass, and
    // Metal line topology is not reliable when bridged back through
    // MeshResource on large assemblies. Keep exact edges in the shared model
    // and in the Metal/Web pipelines; use this overlay only for bounded parts.
    guard geometry.edgeSegmentCount <= 20_000 else { return nil }
    let edgePositions = geometry.edgePositions
    guard !edgePositions.isEmpty else { return nil }
    let vertices = edgePositions.map {
      LowLevelVertex(position: $0, normal: SIMD3<Float>(0, 1, 0))
    }
    let indices = edgePositions.indices.map(UInt32.init)
    let descriptor = LowLevelMesh.Descriptor(
      vertexCapacity: vertices.count,
      vertexAttributes: [
        LowLevelMesh.Attribute(semantic: .position, format: .float3, offset: 0),
        LowLevelMesh.Attribute(semantic: .normal, format: .float3, offset: 12),
      ],
      vertexLayouts: [LowLevelMesh.Layout(bufferIndex: 0, bufferStride: 24)],
      indexCapacity: indices.count,
      indexType: .uint32)
    guard let lowLevelMesh = try? LowLevelMesh(descriptor: descriptor) else { return nil }
    lowLevelMesh.withUnsafeMutableBytes(bufferIndex: 0) { destination in
      vertices.withUnsafeBytes { destination.copyMemory(from: $0) }
    }
    lowLevelMesh.withUnsafeMutableIndices { destination in
      indices.withUnsafeBytes { destination.copyMemory(from: $0) }
    }
    lowLevelMesh.parts.replaceAll([
      LowLevelMesh.Part(
        indexCount: indices.count, topology: .line,
        bounds: BoundingBox(min: geometry.bounds.minimum, max: geometry.bounds.maximum))
    ])
    guard let mesh = try? MeshResource(from: lowLevelMesh) else { return nil }
    let edge =
      session.isModelSelected ? session.theme.edgeSelectionColor : session.theme.edgeColor
    let entity = ModelEntity(
      mesh: mesh,
      materials: [
        UnlitMaterial(
          color: NSColor(
            srgbRed: CGFloat(edge.x), green: CGFloat(edge.y), blue: CGFloat(edge.z), alpha: 1))
      ])
    entity.name = "B-Rep Edges"
    return entity
  }

  @MainActor private func makeThemeLight(_ light: BenchTheme.Light, name: String) -> Entity {
    let entity = Entity()
    entity.name = name
    entity.components.set(
      DirectionalLightComponent(
        color: NSColor(
          red: CGFloat(light.color.x), green: CGFloat(light.color.y),
          blue: CGFloat(light.color.z), alpha: 1),
        intensity: light.intensity))
    entity.look(at: .zero, from: light.directionFrom, relativeTo: nil)
    return entity
  }

  @MainActor private func updateThemeLight(_ entity: Entity, value light: BenchTheme.Light) {
    entity.components.set(
      DirectionalLightComponent(
        color: NSColor(
          red: CGFloat(light.color.x), green: CGFloat(light.color.y),
          blue: CGFloat(light.color.z), alpha: 1),
        intensity: light.intensity))
    entity.look(at: SIMD3<Float>.zero, from: light.directionFrom, relativeTo: nil)
  }
}

/// Counts display opportunities without mutating observable state from inside
/// RealityView's update closure. Doing that would recursively invalidate the
/// SwiftUI graph and turn telemetry itself into the dominant workload.
private struct RealityKitDisplayCadenceCounter: NSViewRepresentable {
  let tick: @MainActor () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(tick: tick) }

  func makeNSView(context: Context) -> NSView {
    context.coordinator.start()
    let view = NSView()
    view.isHidden = true
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.tick = tick
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.stop()
  }

  @MainActor final class Coordinator: NSObject {
    var tick: @MainActor () -> Void
    private var displayLink: CADisplayLink?

    init(tick: @escaping @MainActor () -> Void) {
      self.tick = tick
    }

    func start() {
      guard displayLink == nil else { return }
      guard
        let link = NSScreen.main?.displayLink(
          target: self, selector: #selector(frameDidPresent(_:)))
      else { return }
      link.add(to: .main, forMode: .common)
      displayLink = link
    }

    func stop() {
      displayLink?.invalidate()
      displayLink = nil
    }

    @objc private func frameDidPresent(_ sender: CADisplayLink) { tick() }
  }
}

struct CADInputOverlay: NSViewRepresentable {
  let orbit: (Float, Float) -> Void
  let pan: (Float, Float, Float) -> Void
  let roll: (Float) -> Void
  let zoom: (Float) -> Void
  let select: () -> Void

  init(
    orbit: @escaping (Float, Float) -> Void,
    pan: @escaping (Float, Float, Float) -> Void,
    roll: @escaping (Float) -> Void,
    zoom: @escaping (Float) -> Void,
    select: @escaping () -> Void = {}
  ) {
    self.orbit = orbit
    self.pan = pan
    self.roll = roll
    self.zoom = zoom
    self.select = select
  }

  func makeNSView(context: Context) -> CADInputNSView {
    let view = CADInputNSView()
    view.orbit = orbit
    view.pan = pan
    view.roll = roll
    view.zoom = zoom
    view.select = select
    return view
  }

  func updateNSView(_ view: CADInputNSView, context: Context) {
    view.orbit = orbit
    view.pan = pan
    view.roll = roll
    view.zoom = zoom
    view.select = select
  }
}

final class CADInputNSView: NSView {
  var orbit: ((Float, Float) -> Void)?
  var pan: ((Float, Float, Float) -> Void)?
  var roll: ((Float) -> Void)?
  var zoom: ((Float) -> Void)?
  var select: (() -> Void)?
  private var lastPoint: NSPoint?
  private var dragged = false
  private var mode: Mode = .none
  enum Mode { case none, orbit, pan, roll }

  override var acceptsFirstResponder: Bool { true }
  override func hitTest(_ point: NSPoint) -> NSView? { self }
  override func rightMouseDown(with event: NSEvent) {
    lastPoint = convert(event.locationInWindow, from: nil)
    mode = event.modifierFlags.contains(.shift) ? .roll : .orbit
  }
  override func otherMouseDown(with event: NSEvent) {
    lastPoint = convert(event.locationInWindow, from: nil)
    mode = .pan
  }
  override func mouseDown(with event: NSEvent) {
    lastPoint = convert(event.locationInWindow, from: nil)
    dragged = false
    mode = event.modifierFlags.contains(.shift) ? .pan : .none
  }
  override func rightMouseDragged(with event: NSEvent) { drag(event) }
  override func otherMouseDragged(with event: NSEvent) { drag(event) }
  override func mouseDragged(with event: NSEvent) { drag(event) }
  override func rightMouseUp(with event: NSEvent) {
    mode = .none
    lastPoint = nil
  }
  override func otherMouseUp(with event: NSEvent) {
    mode = .none
    lastPoint = nil
  }
  override func mouseUp(with event: NSEvent) {
    if mode == .none, !dragged { select?() }
    mode = .none
    lastPoint = nil
  }
  override func scrollWheel(with event: NSEvent) { zoom?(Float(event.scrollingDeltaY)) }

  private func drag(_ event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let lastPoint else {
      self.lastPoint = point
      return
    }
    let dx = Float(point.x - lastPoint.x)
    let dy = Float(point.y - lastPoint.y)
    if hypot(dx, dy) > 2 { dragged = true }
    switch mode {
    case .orbit: orbit?(dx, dy)
    case .pan: pan?(dx, dy, Float(bounds.height))
    case .roll: roll?(dx)
    case .none: break
    }
    self.lastPoint = point
  }
}
