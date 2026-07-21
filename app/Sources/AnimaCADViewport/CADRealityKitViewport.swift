import AnimaCAD
import AppKit
import Metal
import QuartzCore
import RealityKit
import SwiftUI

/// The retained high-level Apple renderer from Codex Bench. One LowLevelMesh
/// keeps large STEP assemblies bounded while RealityKit supplies the scene,
/// camera, PBR materials, and native spatial/media integration.
public struct CADRealityKitViewport: View {
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

  public let document: CADGeometryDocument?
  @Bindable public var camera: CADCameraState
  public let theme: CADViewportTheme
  public let isSelected: Bool
  public let onFrame: @MainActor @Sendable () -> Void

  public init(
    document: CADGeometryDocument?,
    camera: CADCameraState,
    theme: CADViewportTheme,
    isSelected: Bool = false,
    onFrame: @escaping @MainActor @Sendable () -> Void = {}
  ) {
    self.document = document
    self.camera = camera
    self.theme = theme
    self.isSelected = isSelected
    self.onFrame = onFrame
  }

  public var body: some View {
    ZStack {
      RealityView { content in
        if let document { content.add(makeRoot(document)) }
        content.add(makeLight(theme.key, name: "CADKey"))
        content.add(makeLight(theme.fill, name: "CADFill"))
        content.add(makeLight(theme.rim, name: "CADRim"))
        let entity = PerspectiveCamera()
        entity.name = "CADCamera"
        update(entity)
        content.add(entity)
      } update: { content in
        let roots = content.entities.filter { $0.name.hasPrefix("CADGeometry-") }
        if let document {
          let expected = rootName(document)
          if !roots.contains(where: { $0.name == expected }) {
            for root in roots { content.remove(root) }
            content.add(makeRoot(document))
          } else if let root = roots.first(where: { $0.name == expected }) {
            updateAppearanceIfNeeded(root, document: document)
          }
        } else {
          for root in roots { content.remove(root) }
        }
        if let entity = content.entities.first(where: { $0.name == "CADCamera" })
          as? PerspectiveCamera
        {
          update(entity)
        }
        if let light = content.entities.first(where: { $0.name == "CADKey" }) {
          apply(theme.key, to: light)
        }
        if let light = content.entities.first(where: { $0.name == "CADFill" }) {
          apply(theme.fill, to: light)
        }
        if let light = content.entities.first(where: { $0.name == "CADRim" }) {
          apply(theme.rim, to: light)
        }
      }
      CADDisplayCadenceCounter(tick: onFrame)
      CADMouseInputOverlay(
        orbit: camera.orbit,
        pan: camera.pan,
        roll: camera.roll,
        zoom: camera.zoom,
        select: {})
    }
    .background(
      Color(
        red: Double(theme.background.x), green: Double(theme.background.y),
        blue: Double(theme.background.z)))
  }

  @MainActor
  private func makeRoot(_ document: CADGeometryDocument) -> Entity {
    let root = Entity()
    root.name = rootName(document)
    if let assembly = makeAssembly(document.renderGeometry) {
      assembly.name = "Combined Assembly"
      root.addChild(assembly)
    }
    if let edges = makeEdges(document.renderGeometry) { root.addChild(edges) }
    let marker = Entity()
    marker.name = appearanceMarkerName
    root.addChild(marker)
    return root
  }

  /// Writes the shared compact CAD arrays directly into one retained mesh.
  /// This is the optimized RealityKit path proven in Codex Bench; it avoids a
  /// scene entity per face/material while retaining material batches.
  @MainActor
  private func makeAssembly(_ geometry: CADRenderGeometry) -> ModelEntity? {
    var vertices: [LowLevelVertex] = []
    var indices: [UInt32] = []
    var parts: [LowLevelMesh.Part] = []
    var materials: [PhysicallyBasedMaterial] = []
    vertices.reserveCapacity(geometry.positions.count)
    indices.reserveCapacity(geometry.indices.count)

    for (materialIndex, batch) in geometry.batches.enumerated() {
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
      vertices.withUnsafeBytes { destination.copyMemory(from: $0) }
    }
    lowLevelMesh.withUnsafeMutableIndices { destination in
      indices.withUnsafeBytes { destination.copyMemory(from: $0) }
    }
    lowLevelMesh.parts.replaceAll(parts)
    guard let mesh = try? MeshResource(from: lowLevelMesh) else { return nil }
    return ModelEntity(mesh: mesh, materials: materials)
  }

  @MainActor
  private func makeEdges(_ geometry: CADRenderGeometry) -> ModelEntity? {
    guard theme.edgeStrength > 0.02, geometry.edgeSegmentCount <= 20_000,
      !geometry.edgePositions.isEmpty
    else { return nil }
    let vertices = geometry.edgePositions.map {
      LowLevelVertex(position: $0, normal: SIMD3<Float>(0, 1, 0))
    }
    let indices = geometry.edgePositions.indices.map(UInt32.init)
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
    let edge = isSelected ? theme.edgeSelectionColor : theme.edgeColor
    let entity = ModelEntity(
      mesh: mesh,
      materials: [
        UnlitMaterial(
          color: NSColor(
            srgbRed: CGFloat(edge.x), green: CGFloat(edge.y), blue: CGFloat(edge.z),
            alpha: 1))
      ])
    entity.name = "B-Rep Edges"
    return entity
  }

  @MainActor
  private func makeMaterial(_ rgba8: SIMD4<UInt8>) -> PhysicallyBasedMaterial {
    let source = SIMD4<Float>(rgba8) / 255
    let display = theme.displayColor(for: source)
    let face = SIMD3(display.x, display.y, display.z)
    let base =
      isSelected
      ? simd_mix(face, theme.selectionColor, SIMD3(repeating: 0.38)) : face
    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(
      tint: NSColor(
        red: CGFloat(base.x), green: CGFloat(base.y), blue: CGFloat(base.z),
        alpha: CGFloat(display.w)))
    material.roughness = .init(floatLiteral: theme.roughness)
    material.metallic = .init(floatLiteral: theme.metallic)
    return material
  }

  @MainActor
  private func updateAppearanceIfNeeded(_ root: Entity, document: CADGeometryDocument) {
    guard
      root.children.first(where: { $0.name.hasPrefix("CADAppearance-") })?.name
        != appearanceMarkerName
    else { return }
    for child in root.children {
      guard let model = child as? ModelEntity else { continue }
      if child.name == "Combined Assembly" {
        model.model?.materials = document.renderGeometry.batches.map {
          makeMaterial($0.materialColor)
        }
      } else if child.name == "B-Rep Edges" {
        let edge = isSelected ? theme.edgeSelectionColor : theme.edgeColor
        model.model?.materials = [
          UnlitMaterial(
            color: NSColor(
              srgbRed: CGFloat(edge.x), green: CGFloat(edge.y), blue: CGFloat(edge.z),
              alpha: 1))
        ]
        model.isEnabled = theme.edgeStrength > 0.02
      }
    }
    root.children.first(where: { $0.name.hasPrefix("CADAppearance-") })?.name =
      appearanceMarkerName
  }

  private var appearanceMarkerName: String {
    "CADAppearance-\(theme.hashValue)-\(isSelected)"
  }

  private func rootName(_ document: CADGeometryDocument) -> String {
    "CADGeometry-\(document.identity.uuidString)"
  }

  private func update(_ entity: PerspectiveCamera) {
    entity.position = camera.position
    entity.look(at: camera.target, from: camera.position, relativeTo: nil)
    entity.orientation *= simd_quatf(angle: camera.rollRadians, axis: [0, 0, -1])
  }

  @MainActor
  private func makeLight(_ light: CADViewportTheme.Light, name: String) -> Entity {
    let entity = Entity()
    entity.name = name
    apply(light, to: entity)
    return entity
  }

  @MainActor
  private func apply(_ light: CADViewportTheme.Light, to entity: Entity) {
    entity.components.set(
      DirectionalLightComponent(
        color: NSColor(
          red: CGFloat(light.color.x), green: CGFloat(light.color.y),
          blue: CGFloat(light.color.z), alpha: 1),
        intensity: light.intensity))
    entity.look(at: .zero, from: light.directionFrom, relativeTo: nil)
  }
}

private struct CADDisplayCadenceCounter: NSViewRepresentable {
  let tick: @MainActor @Sendable () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(tick: tick) }

  func makeNSView(context: Context) -> NSView {
    context.coordinator.start()
    let view = NSView()
    view.isHidden = true
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.tick = tick }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.stop()
  }

  @MainActor final class Coordinator: NSObject {
    var tick: @MainActor @Sendable () -> Void
    private var displayLink: CADisplayLink?

    init(tick: @escaping @MainActor @Sendable () -> Void) { self.tick = tick }

    func start() {
      guard displayLink == nil,
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
