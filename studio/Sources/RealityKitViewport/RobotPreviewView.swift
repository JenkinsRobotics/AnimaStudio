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
  @State private var transformDragState: TransformDragState?
  @State private var navigationAction: CADNavigationAction?
  @State private var navigationCommandRevision = 0

  private let frame: EvaluatedFrame
  private let rig: CharacterRig
  private let modelURL: URL?
  private let showsGrid: Bool
  private let projection: PreviewCameraProjection
  private let viewpoint: PreviewCameraViewpoint
  private let cameraCommandRevision: Int
  private let navigationProfile: PreviewNavigationProfile
  private let focusedModelPath: ModelEntityPath?
  private let focusedPartID: PartID?
  private let importedHierarchyRootPath: ModelEntityPath?
  private let onSelectModelPath: (ModelEntityPath) -> Void
  private let onSelectPartID: (PartID) -> Void
  private let onSetPartPosition: (PartID, RigVector3) -> Void
  private let onSetPartRotation: (PartID, RigVector3) -> Void
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
    navigationProfile: PreviewNavigationProfile = .onshape,
    focusedModelPath: ModelEntityPath? = nil,
    focusedPartID: PartID? = nil,
    importedHierarchyRootPath: ModelEntityPath? = nil,
    rigGuideVisibility: RigGuideVisibility = .hidden,
    appearance: PreviewAppearance = .midnight,
    onSelectModelPath: @escaping (ModelEntityPath) -> Void = { _ in },
    onSelectPartID: @escaping (PartID) -> Void = { _ in },
    onSetPartPosition: @escaping (PartID, RigVector3) -> Void = { _, _ in },
    onSetPartRotation: @escaping (PartID, RigVector3) -> Void = { _, _ in }
  ) {
    self.frame = frame
    self.rig = rig
    self.modelURL = modelURL
    self.showsGrid = showsGrid
    self.projection = projection
    self.viewpoint = viewpoint
    self.cameraCommandRevision = cameraCommandRevision
    self.navigationProfile = navigationProfile
    self.focusedModelPath = focusedModelPath
    self.focusedPartID = focusedPartID
    self.importedHierarchyRootPath = importedHierarchyRootPath
    self.rigGuideVisibility = rigGuideVisibility
    self.appearance = appearance
    self.onSelectModelPath = onSelectModelPath
    self.onSelectPartID = onSelectPartID
    self.onSetPartPosition = onSetPartPosition
    self.onSetPartRotation = onSetPartRotation
  }

  public var body: some View {
    RealityView { content in
      let root = Self.makeScene(rig: rig, appearance: appearance)
      content.add(root)
      content.cameraTarget = root.findEntity(named: "previewCameraTarget")

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
        focusedPartID: focusedPartID,
        to: root
      )
      Self.applyRig(rig, frame: frame, to: root)
      Self.applySelection(focusedPartID, rig: rig, to: root)
      if let navigationAction {
        Self.applyNavigation(
          navigationAction,
          revision: navigationCommandRevision,
          to: root
        )
      }
    }
    .realityViewCameraControls(.none)
    .gesture(
      SpatialTapGesture()
        .targetedToAnyEntity()
        .onEnded { value in
          if let partID = Self.partID(for: value.entity) {
            onSelectPartID(partID)
            return
          }

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
    .simultaneousGesture(
      DragGesture(minimumDistance: 2)
        .targetedToAnyEntity()
        .onChanged { value in
          guard let focusedPartID,
            let handle = TransformGizmoFactory.handle(from: value.entity),
            let part = rig.parts.first(where: { $0.id == focusedPartID }),
            let partEntity = Self.semanticPartAncestor(from: value.entity)
          else { return }

          let dragState: TransformDragState
          if let transformDragState,
            transformDragState.partID == focusedPartID,
            transformDragState.handle == handle
          {
            dragState = transformDragState
          } else {
            dragState = TransformDragState(
              partID: focusedPartID,
              handle: handle,
              startPosition: part.positionMeters,
              startRotation: part.rotationEulerRadians
            )
            transformDragState = dragState
          }

          switch handle {
          case .translate(let axis):
            guard
              let start = value.unproject(value.startLocation, from: .local, to: .scene),
              let current = value.unproject(value.location, from: .local, to: .scene)
            else { return }
            let worldAxis = simd_normalize(
              partEntity.convert(direction: TransformGizmoFactory.vector(for: axis), to: nil)
            )
            let distance = simd_dot(current - start, worldAxis)
            let startPosition = Self.simdPosition(dragState.startPosition)
            onSetPartPosition(
              focusedPartID,
              Self.rigVector(startPosition + worldAxis * distance)
            )
          case .rotate(let axis):
            let angle = Self.rotationAngle(
              for: value.translation,
              axis: axis
            )
            var rotation = dragState.startRotation
            switch axis {
            case .x: rotation.x += angle
            case .y: rotation.y += angle
            case .z: rotation.z += angle
            }
            onSetPartRotation(focusedPartID, rotation)
          }
        }
        .onEnded { _ in
          transformDragState = nil
        }
    )
    .overlay {
      CADNavigationCapture(profile: navigationProfile) { action in
        navigationAction = action
        navigationCommandRevision += 1
      }
      .allowsHitTesting(false)
    }
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

    let cameraTarget = Entity()
    cameraTarget.name = "previewCameraTarget"
    cameraTarget.position = SIMD3<Float>(0, 0.8, 0)
    root.addChild(cameraTarget)

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
    entity.orientation = orientation(part.rotationEulerRadians)
    prepareForSelection(entity)
    return entity
  }

  private static func applyRig(
    _ rig: CharacterRig,
    frame: EvaluatedFrame,
    to root: Entity
  ) {
    for part in rig.parts {
      guard let entity = root.findEntity(named: partEntityName(part.id)) else { continue }
      entity.position = simdPosition(part.positionMeters)
      entity.orientation = orientation(part.rotationEulerRadians)
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
      let animatedRotation = simd_quatf(
        angle: Float(frame.jointAnglesRadians[joint.id] ?? joint.neutralRadians),
        axis: axis
      )
      let restRotation =
        rig.parts.first { $0.id == childPartID }?
        .rotationEulerRadians ?? RigVector3()
      child.orientation = orientation(restRotation) * animatedRotation
    }
  }

  private static func applySelection(
    _ selectedPartID: PartID?,
    rig: CharacterRig,
    to root: Entity
  ) {
    for part in rig.parts {
      guard let entity = root.findEntity(named: partEntityName(part.id)) else { continue }
      let isSelected = part.id == selectedPartID
      let highlight = entity.findEntity(named: TransformGizmoFactory.selectionHighlightName)
      let gizmo = entity.findEntity(named: TransformGizmoFactory.gizmoName)

      if isSelected {
        if highlight == nil {
          entity.addChild(TransformGizmoFactory.makeSelectionHighlight(for: part.primitiveKind))
        }
        if gizmo == nil {
          entity.addChild(TransformGizmoFactory.make())
        }
      } else {
        highlight?.removeFromParent()
        gizmo?.removeFromParent()
      }
    }
  }

  private static func partEntityName(_ id: PartID) -> String {
    "semanticPart-\(id.rawValue.uuidString)"
  }

  private static func simdPosition(_ vector: RigVector3) -> SIMD3<Float> {
    SIMD3<Float>(Float(vector.x), Float(vector.y), Float(vector.z))
  }

  private static func rigVector(_ vector: SIMD3<Float>) -> RigVector3 {
    RigVector3(x: Double(vector.x), y: Double(vector.y), z: Double(vector.z))
  }

  private static func orientation(_ eulerRadians: RigVector3) -> simd_quatf {
    let x = simd_quatf(angle: Float(eulerRadians.x), axis: SIMD3<Float>(1, 0, 0))
    let y = simd_quatf(angle: Float(eulerRadians.y), axis: SIMD3<Float>(0, 1, 0))
    let z = simd_quatf(angle: Float(eulerRadians.z), axis: SIMD3<Float>(0, 0, 1))
    return z * y * x
  }

  private static func rotationAngle(
    for translation: CGSize,
    axis: JointAxis
  ) -> Double {
    let pixels: CGFloat =
      switch axis {
      case .x: -translation.height
      case .y: translation.width
      case .z: translation.width - translation.height
      }
    return Double(pixels) * 0.01
  }

  private static func applyNavigation(
    _ action: CADNavigationAction,
    revision: Int,
    to root: Entity
  ) {
    let markerName = "previewNavigationCommand-\(revision)"
    guard root.findEntity(named: markerName) == nil,
      let camera = root.findEntity(named: "previewCamera"),
      let cameraTarget = root.findEntity(named: "previewCameraTarget")
    else { return }

    for child in Array(root.children)
    where child.name.hasPrefix("previewNavigationCommand-") {
      child.removeFromParent()
    }

    let target = cameraTarget.position
    var offset = camera.position - target
    let distance = max(simd_length(offset), 0.001)

    switch action {
    case .orbit(let deltaX, let deltaY):
      let yaw = atan2(offset.x, offset.z) - Float(deltaX) * 0.008
      let existingPitch = asin(max(min(offset.y / distance, 1), -1))
      let pitch = max(
        min(existingPitch + Float(deltaY) * 0.008, .pi / 2 - 0.02),
        -.pi / 2 + 0.02
      )
      let horizontal = cos(pitch) * distance
      offset = SIMD3<Float>(sin(yaw) * horizontal, sin(pitch) * distance, cos(yaw) * horizontal)
      camera.position = target + offset
    case .pan(let deltaX, let deltaY):
      let forward = simd_normalize(target - camera.position)
      var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
      if simd_length_squared(right) < 0.0001 {
        right = SIMD3<Float>(1, 0, 0)
      } else {
        right = simd_normalize(right)
      }
      let up = simd_normalize(simd_cross(right, forward))
      let scale = max(distance, 0.2) * 0.002
      let shift = (-right * Float(deltaX) + up * Float(deltaY)) * scale
      camera.position += shift
      cameraTarget.position += shift
    case .zoom(let delta):
      let factor = exp(-Float(delta) * 0.025)
      if var orthographic = camera.components[OrthographicCameraComponent.self] {
        orthographic.scale = min(max(orthographic.scale * factor, 0.05), 100)
        camera.components.set(orthographic)
      } else {
        let newDistance = min(max(distance * factor, 0.15), 100)
        camera.position = target + simd_normalize(offset) * newDistance
      }
    }

    camera.look(at: cameraTarget.position, from: camera.position, relativeTo: nil)
    let marker = Entity()
    marker.name = markerName
    root.addChild(marker)
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
    focusedPartID: PartID?,
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

    if viewpoint == .selection {
      let focusedEntity: Entity? = {
        if let focusedPartID {
          return root.findEntity(named: partEntityName(focusedPartID))
        }
        guard let focusedModelPath,
          let importedModel = root.findEntity(named: "importedModel")
        else { return nil }
        return entity(at: focusedModelPath, below: importedModel)
      }()
      if let focusedEntity {
        let bounds = focusedEntity.visualBounds(relativeTo: root)
        target = bounds.center
        distance = max(bounds.extents.x, bounds.extents.y, bounds.extents.z) * 2.5
        distance = max(distance, 0.8)
      }
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
    root.findEntity(named: "previewCameraTarget")?.position = target

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

  private static func semanticPartAncestor(from entity: Entity) -> Entity? {
    var candidate: Entity? = entity
    while let current = candidate {
      if current.name.hasPrefix("semanticPart-") {
        return current
      }
      candidate = current.parent
    }
    return nil
  }

  private static func partID(for entity: Entity) -> PartID? {
    guard let partEntity = semanticPartAncestor(from: entity) else { return nil }
    let rawValue = String(partEntity.name.dropFirst("semanticPart-".count))
    guard let uuid = UUID(uuidString: rawValue) else { return nil }
    return PartID(rawValue: uuid)
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

private struct TransformDragState {
  let partID: PartID
  let handle: TransformHandleKind
  let startPosition: RigVector3
  let startRotation: RigVector3
}
