import AnimaCore
import RealityKit
import SwiftUI

public struct RobotPreviewView: View {
  private let frame: EvaluatedFrame
  private let modelURL: URL?

  public init(frame: EvaluatedFrame, modelURL: URL? = nil) {
    self.frame = frame
    self.modelURL = modelURL
  }

  public var body: some View {
    RealityView { content in
      let root = Self.makeScene()
      content.add(root)

      if let modelURL,
        let importedModel = try? await Entity(contentsOf: modelURL)
      {
        importedModel.name = "importedModel"
        Self.normalizeForPreview(importedModel)
        root.findEntity(named: "sampleMechanism")?.isEnabled = false
        root.addChild(importedModel)
      }
    } update: { content in
      guard let root = content.entities.first,
        let headYaw = root.findEntity(named: SampleContent.headYawID.rawValue)
      else {
        return
      }

      let radians = Float(
        frame.jointAnglesRadians[SampleContent.headYawID] ?? 0
      )
      headYaw.orientation = simd_quatf(
        angle: radians,
        axis: SIMD3<Float>(0, 1, 0)
      )
    }
    .realityViewCameraControls(.orbit)
    .background(.black.gradient)
    .id(modelURL)
  }

  private static func makeScene() -> Entity {
    let root = Entity()
    root.name = "animaPreviewRoot"

    let floor = ModelEntity(
      mesh: .generateBox(width: 4, height: 0.04, depth: 4),
      materials: [SimpleMaterial(color: .darkGray, isMetallic: false)]
    )
    floor.position.y = -0.02
    root.addChild(floor)

    let sampleMechanism = Entity()
    sampleMechanism.name = "sampleMechanism"
    root.addChild(sampleMechanism)

    let body = ModelEntity(
      mesh: .generateBox(width: 0.8, height: 1.1, depth: 0.5),
      materials: [SimpleMaterial(color: .systemIndigo, isMetallic: true)]
    )
    body.position.y = 0.55
    sampleMechanism.addChild(body)

    let headYaw = Entity()
    headYaw.name = SampleContent.headYawID.rawValue
    headYaw.position.y = 1.25
    sampleMechanism.addChild(headYaw)

    let head = ModelEntity(
      mesh: .generateBox(width: 0.72, height: 0.46, depth: 0.58),
      materials: [SimpleMaterial(color: .systemOrange, isMetallic: false)]
    )
    head.position.y = 0.23
    headYaw.addChild(head)

    let face = ModelEntity(
      mesh: .generateBox(width: 0.48, height: 0.18, depth: 0.015),
      materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
    )
    face.position = SIMD3<Float>(0, 0.26, 0.30)
    headYaw.addChild(face)

    let camera = Entity(components: PerspectiveCameraComponent())
    camera.position = SIMD3<Float>(2.8, 1.8, 3.8)
    camera.look(at: SIMD3<Float>(0, 0.8, 0), from: camera.position, relativeTo: nil)
    root.addChild(camera)

    let light = Entity(components: DirectionalLightComponent(color: .white, intensity: 12_000))
    light.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(1, 0, 0))
    root.addChild(light)

    return root
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
