import AppKit
import RealityKit

public struct RigGuideVisibility: Equatable, Sendable {
  public var showsConnectors: Bool
  public var showsDOFHandles: Bool
  public var showsReferencePlanes: Bool
  public var showsLimits: Bool

  public init(
    showsConnectors: Bool = true,
    showsDOFHandles: Bool = true,
    showsReferencePlanes: Bool = false,
    showsLimits: Bool = true
  ) {
    self.showsConnectors = showsConnectors
    self.showsDOFHandles = showsDOFHandles
    self.showsReferencePlanes = showsReferencePlanes
    self.showsLimits = showsLimits
  }

  public static let hidden = RigGuideVisibility(
    showsConnectors: false,
    showsDOFHandles: false,
    showsReferencePlanes: false,
    showsLimits: false
  )
}

@MainActor
enum RigGuideFactory {
  static let rootName = "rigGuides"
  static let connectorName = "mateConnectorAxes"
  static let dofName = "mateDOFHandles"
  static let planeName = "mateReferencePlane"
  static let limitsName = "mateLimits"

  static func makeRevoluteGuide() -> Entity {
    let root = Entity()
    root.name = rootName

    let connector = Entity()
    connector.name = connectorName
    connector.addChild(axis(length: 0.52, color: .systemRed, direction: .x))
    connector.addChild(axis(length: 0.52, color: .systemGreen, direction: .y))
    connector.addChild(axis(length: 0.52, color: .systemBlue, direction: .z))

    let origin = ModelEntity(
      mesh: .generateSphere(radius: 0.045),
      materials: [SimpleMaterial(color: .white, isMetallic: false)]
    )
    connector.addChild(origin)
    root.addChild(connector)

    let plane = ModelEntity(
      mesh: .generateBox(width: 0.72, height: 0.004, depth: 0.72),
      materials: [
        SimpleMaterial(
          color: .systemBlue.withAlphaComponent(0.16),
          isMetallic: false
        )
      ]
    )
    plane.name = planeName
    root.addChild(plane)

    let dof = ring(
      name: dofName,
      startRadians: 0,
      endRadians: .pi * 2,
      radius: 0.46,
      color: .systemPurple,
      segmentCount: 40
    )
    root.addChild(dof)

    let limits = ring(
      name: limitsName,
      startRadians: -.pi / 3,
      endRadians: .pi / 3,
      radius: 0.39,
      color: .systemOrange,
      segmentCount: 16
    )
    root.addChild(limits)

    return root
  }

  static func apply(_ visibility: RigGuideVisibility, to root: Entity) {
    for guides in entities(named: rootName, below: root) {
      guides.findEntity(named: connectorName)?.isEnabled = visibility.showsConnectors
      guides.findEntity(named: dofName)?.isEnabled = visibility.showsDOFHandles
      guides.findEntity(named: planeName)?.isEnabled = visibility.showsReferencePlanes
      guides.findEntity(named: limitsName)?.isEnabled = visibility.showsLimits
    }
  }

  private static func entities(named name: String, below root: Entity) -> [Entity] {
    root.children.flatMap { child in
      (child.name == name ? [child] : []) + entities(named: name, below: child)
    }
  }

  private enum AxisDirection {
    case x
    case y
    case z
  }

  private static func axis(
    length: Float,
    color: NSColor,
    direction: AxisDirection
  ) -> Entity {
    let thickness: Float = 0.018
    let mesh: MeshResource
    let position: SIMD3<Float>

    switch direction {
    case .x:
      mesh = .generateBox(width: length, height: thickness, depth: thickness)
      position = SIMD3<Float>(length / 2, 0, 0)
    case .y:
      mesh = .generateBox(width: thickness, height: length, depth: thickness)
      position = SIMD3<Float>(0, length / 2, 0)
    case .z:
      mesh = .generateBox(width: thickness, height: thickness, depth: length)
      position = SIMD3<Float>(0, 0, length / 2)
    }

    let entity = ModelEntity(
      mesh: mesh,
      materials: [SimpleMaterial(color: color, isMetallic: false)]
    )
    entity.position = position
    return entity
  }

  private static func ring(
    name: String,
    startRadians: Float,
    endRadians: Float,
    radius: Float,
    color: NSColor,
    segmentCount: Int
  ) -> Entity {
    let ring = Entity()
    ring.name = name
    let step = (endRadians - startRadians) / Float(segmentCount)
    let segmentLength = max(radius * step * 0.9, 0.02)
    let material = SimpleMaterial(color: color, isMetallic: false)

    for index in 0..<segmentCount {
      let angle = startRadians + (Float(index) + 0.5) * step
      let segment = ModelEntity(
        mesh: .generateBox(width: segmentLength, height: 0.022, depth: 0.022),
        materials: [material]
      )
      segment.position = SIMD3<Float>(sin(angle) * radius, 0, cos(angle) * radius)
      segment.orientation = simd_quatf(angle: -angle, axis: SIMD3<Float>(0, 1, 0))
      ring.addChild(segment)
    }

    return ring
  }
}
