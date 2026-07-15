import AnimaCore
import Foundation
import RealityKit
import SwiftUI

public enum PreviewCameraProjection: String, Sendable {
  case perspective
  case orthographic
}

public enum PreviewCameraViewpoint: String, Sendable {
  case home
  case front
  case right
  case top
  case selection
}

public struct RobotPreviewView: View {
  private let frame: EvaluatedFrame
  private let rig: CharacterRig
  private let modelURL: URL?
  private let showsGrid: Bool
  private let projection: PreviewCameraProjection
  private let viewpoint: PreviewCameraViewpoint
  private let cameraCommandRevision: Int
  private let focusedModelPath: ModelEntityPath?
  private let importedHierarchyRootPath: ModelEntityPath?
  private let onSelectModelPath: (ModelEntityPath) -> Void
  private let rigGuideVisibility: RigGuideVisibility
  private let appearance: PreviewAppearance

  public init(
    frame: EvaluatedFrame,
    rig: CharacterRig = CharacterRig(joints: []),
    modelURL: URL? = nil,
    showsGrid: Bool = true,
    projection: PreviewCameraProjection = .perspective,
    viewpoint: PreviewCameraViewpoint = .home,
    cameraCommandRevision: Int = 0,
    focusedModelPath: ModelEntityPath? = nil,
    importedHierarchyRootPath: ModelEntityPath? = nil,
    rigGuideVisibility: RigGuideVisibility = .hidden,
    appearance: PreviewAppearance = .midnight,
    onSelectModelPath: @escaping (ModelEntityPath) -> Void = { _ in }
  ) {
    self.frame = frame
    self.rig = rig
    self.modelURL = modelURL
    self.showsGrid = showsGrid
    self.projection = projection
    self.viewpoint = viewpoint
    self.cameraCommandRevision = cameraCommandRevision
    self.focusedModelPath = focusedModelPath
    self.importedHierarchyRootPath = importedHierarchyRootPath
    self.rigGuideVisibility = rigGuideVisibility
    self.appearance = appearance
    self.onSelectModelPath = onSelectModelPath
  }

  public var body: some View {
    RealityView { content in
      let root = Self.makeScene(rig: rig, appearance: appearance)
      content.add(root)

      if let modelURL,
        let importedModel = try? await Entity(contentsOf: modelURL)
      {
        importedModel.name = "importedModel"
        Self.normalizeForPreview(importedModel)
        Self.prepareForSelection(importedModel)
        root.addChild(importedModel)
      }
    } update: { content in
      guard let root = content.entities.first else {
        return
      }

      root.findEntity(named: "previewGrid")?.isEnabled = showsGrid
      RigGuideFactory.apply(rigGuideVisibility, to: root)
      Self.applyProjectionIfNeeded(projection, to: root)
      Self.applyCameraCommandIfNeeded(
        revision: cameraCommandRevision,
        viewpoint: viewpoint,
        focusedModelPath: focusedModelPath,
        to: root
      )
      Self.applyRig(rig, frame: frame, to: root)
    }
    .realityViewCameraControls(.orbit)
    .gesture(
      SpatialTapGesture()
        .targetedToAnyEntity()
        .onEnded { value in
          guard let importedHierarchyRootPath,
            let importedModel = Self.ancestor(named: "importedModel", from: value.entity),
            let path = Self.modelPath(
              for: value.entity,
              below: importedModel,
              hierarchyRootPath: importedHierarchyRootPath
            )
          else { return }
          onSelectModelPath(path)
        }
    )
    .background(appearance.backgroundColor.gradient)
    .id(sceneIdentity)
  }

  private var sceneIdentity: String {
    let partIDs = rig.parts.map { $0.id.rawValue.uuidString }.joined(separator: ",")
    let jointIDs = rig.joints.map { $0.id.rawValue }.joined(separator: ",")
    return "\(modelURL?.absoluteString ?? "none")|\(appearance.rawValue)|\(partIDs)|\(jointIDs)"
  }

  private static func makeScene(
    rig: CharacterRig,
    appearance: PreviewAppearance
  ) -> Entity {
    let root = Entity()
    root.name = "animaPreviewRoot"

    root.addChild(makeGrid(appearance: appearance))

    for part in rig.parts {
      root.addChild(makePart(part))
    }

    for joint in rig.joints {
      guard let childPartID = joint.childPartID,
        let child = root.findEntity(named: partEntityName(childPartID))
      else { continue }
      child.addChild(RigGuideFactory.makeRevoluteGuide())
    }

    let camera = Entity(components: PerspectiveCameraComponent())
    camera.name = "previewCamera"
    camera.position = SIMD3<Float>(2.8, 1.8, 3.8)
    camera.look(at: SIMD3<Float>(0, 0.8, 0), from: camera.position, relativeTo: nil)
    root.addChild(camera)

    let light = Entity(
      components: DirectionalLightComponent(color: .white, intensity: appearance.lightIntensity)
    )
    light.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(1, 0, 0))
    root.addChild(light)

    return root
  }

  private static func makePart(_ part: RigPartDefinition) -> Entity {
    let material = SimpleMaterial(color: .systemTeal, isMetallic: false)
    let entity: ModelEntity
    switch part.primitiveKind {
    case .box:
      entity = ModelEntity(
        mesh: .generateBox(width: 0.55, height: 0.55, depth: 0.55, cornerRadius: 0.035),
        materials: [material]
      )
    case .cylinder:
      entity = ModelEntity(
        mesh: .generateCylinder(height: 0.72, radius: 0.25),
        materials: [material]
      )
    case .sphere:
      entity = ModelEntity(
        mesh: .generateSphere(radius: 0.32),
        materials: [material]
      )
    case .locator:
      entity = ModelEntity(
        mesh: .generateSphere(radius: 0.08),
        materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)]
      )
    }
    entity.name = partEntityName(part.id)
    entity.position = simdPosition(part.positionMeters)
    return entity
  }

  private static func applyRig(
    _ rig: CharacterRig,
    frame: EvaluatedFrame,
    to root: Entity
  ) {
    for part in rig.parts {
      root.findEntity(named: partEntityName(part.id))?.position = simdPosition(part.positionMeters)
    }

    for joint in rig.joints {
      guard let childPartID = joint.childPartID,
        let child = root.findEntity(named: partEntityName(childPartID))
      else { continue }
      let axis: SIMD3<Float> =
        switch joint.axis {
        case .x: SIMD3<Float>(1, 0, 0)
        case .y: SIMD3<Float>(0, 1, 0)
        case .z: SIMD3<Float>(0, 0, 1)
        }
      child.orientation = simd_quatf(
        angle: Float(frame.jointAnglesRadians[joint.id] ?? joint.neutralRadians),
        axis: axis
      )
    }
  }

  private static func partEntityName(_ id: PartID) -> String {
    "semanticPart-\(id.rawValue.uuidString)"
  }

  private static func simdPosition(_ vector: RigVector3) -> SIMD3<Float> {
    SIMD3<Float>(Float(vector.x), Float(vector.y), Float(vector.z))
  }

  private static func applyProjectionIfNeeded(
    _ projection: PreviewCameraProjection,
    to root: Entity
  ) {
    let markerName = "previewProjection-\(projection.rawValue)"
    guard root.findEntity(named: markerName) == nil,
      let camera = root.findEntity(named: "previewCamera")
    else { return }

    for child in Array(root.children)
    where child.name.hasPrefix("previewProjection-") {
      child.removeFromParent()
    }

    switch projection {
    case .perspective:
      camera.components.remove(OrthographicCameraComponent.self)
      camera.components.set(PerspectiveCameraComponent())
    case .orthographic:
      camera.components.remove(PerspectiveCameraComponent.self)
      var component = OrthographicCameraComponent()
      component.scale = 2.8
      camera.components.set(component)
    }

    let marker = Entity()
    marker.name = markerName
    root.addChild(marker)
  }

  private static func applyCameraCommandIfNeeded(
    revision: Int,
    viewpoint: PreviewCameraViewpoint,
    focusedModelPath: ModelEntityPath?,
    to root: Entity
  ) {
    let markerName = "previewCameraCommand-\(revision)"
    guard root.findEntity(named: markerName) == nil,
      let camera = root.findEntity(named: "previewCamera")
    else { return }

    for child in Array(root.children)
    where child.name.hasPrefix("previewCameraCommand-") {
      child.removeFromParent()
    }

    let defaultTarget = SIMD3<Float>(0, 0.8, 0)
    var target = defaultTarget
    var distance: Float = 4.5

    if viewpoint == .selection,
      let focusedModelPath,
      let importedModel = root.findEntity(named: "importedModel"),
      let focusedEntity = entity(at: focusedModelPath, below: importedModel)
    {
      let bounds = focusedEntity.visualBounds(relativeTo: root)
      target = bounds.center
      distance = max(bounds.extents.x, bounds.extents.y, bounds.extents.z) * 2.5
      distance = max(distance, 0.8)
    }

    switch viewpoint {
    case .home, .selection:
      camera.position = target + SIMD3<Float>(distance * 0.62, distance * 0.22, distance * 0.78)
    case .front:
      camera.position = target + SIMD3<Float>(0, 0, distance)
    case .right:
      camera.position = target + SIMD3<Float>(distance, 0, 0)
    case .top:
      camera.position = target + SIMD3<Float>(0, distance, 0.001)
    }
    camera.look(at: target, from: camera.position, relativeTo: nil)

    let marker = Entity()
    marker.name = markerName
    root.addChild(marker)
  }

  private static func entity(
    at path: ModelEntityPath,
    below root: Entity
  ) -> Entity? {
    var entity = root
    for component in path.components.dropFirst() {
      guard component.siblingIndex >= 0,
        component.siblingIndex < entity.children.count
      else { return nil }
      entity = entity.children[component.siblingIndex]
    }
    return entity
  }

  private static func prepareForSelection(_ entity: Entity) {
    entity.generateCollisionShapes(recursive: true)
    addInputTargets(to: entity)
  }

  private static func addInputTargets(to entity: Entity) {
    entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    for child in entity.children {
      addInputTargets(to: child)
    }
  }

  private static func modelPath(
    for selectedEntity: Entity,
    below importedRoot: Entity,
    hierarchyRootPath: ModelEntityPath
  ) -> ModelEntityPath? {
    guard let rootComponent = hierarchyRootPath.components.first else { return nil }

    var components: [ModelEntityPathComponent] = []
    var current = selectedEntity
    while current != importedRoot {
      guard let parent = current.parent,
        let siblingIndex = parent.children.firstIndex(of: current)
      else { return nil }
      components.append(
        ModelEntityPathComponent(name: current.name, siblingIndex: siblingIndex)
      )
      current = parent
    }

    return ModelEntityPath(components: [rootComponent] + components.reversed())
  }

  private static func ancestor(named name: String, from entity: Entity) -> Entity? {
    var candidate: Entity? = entity
    while let current = candidate {
      if current.name == name {
        return current
      }
      candidate = current.parent
    }
    return nil
  }

  private static func makeGrid(appearance: PreviewAppearance) -> Entity {
    let grid = Entity()
    grid.name = "previewGrid"

    let minorMaterial = SimpleMaterial(color: appearance.minorGridColor, isMetallic: false)
    let majorMaterial = SimpleMaterial(color: appearance.majorGridColor, isMetallic: false)
    let extent: Float = 10
    let spacing: Float = 0.5

    for index in -10...10 {
      let isMajor = index.isMultiple(of: 5)
      let thickness: Float = isMajor ? 0.012 : 0.004
      let material = isMajor ? majorMaterial : minorMaterial
      let offset = Float(index) * spacing

      let xLine = ModelEntity(
        mesh: .generateBox(width: extent, height: 0.002, depth: thickness),
        materials: [material]
      )
      xLine.position.z = offset
      grid.addChild(xLine)

      let zLine = ModelEntity(
        mesh: .generateBox(width: thickness, height: 0.002, depth: extent),
        materials: [material]
      )
      zLine.position.x = offset
      grid.addChild(zLine)
    }

    return grid
  }

  private static func normalizeForPreview(_ entity: Entity) {
    let bounds = entity.visualBounds(relativeTo: entity)
    let largestExtent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
    guard largestExtent.isFinite, largestExtent > 0 else { return }

    let scale = 1.6 / largestExtent
    entity.scale = SIMD3<Float>(repeating: scale)
    entity.position = SIMD3<Float>(
      -bounds.center.x * scale,
      0.8 - (bounds.center.y * scale),
      -bounds.center.z * scale
    )
  }
}
