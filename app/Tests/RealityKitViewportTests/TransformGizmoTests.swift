import AnimaEvaluation
import AnimaModel
import RealityKit
import XCTest

@testable import RealityKitViewport

@MainActor
final class TransformGizmoTests: XCTestCase {
  func testGizmoProvidesTranslationAndRotationHandlesForEveryAxis() {
    let gizmo = TransformGizmoFactory.make()

    XCTAssertEqual(gizmo.name, TransformGizmoFactory.gizmoName)
    for axis in [JointAxis.x, .y, .z] {
      let translation = gizmo.findEntity(
        named: "transformHandle-translate-\(axis.rawValue)"
      )
      let rotation = gizmo.findEntity(
        named: "transformHandle-rotate-\(axis.rawValue)"
      )
      XCTAssertNotNil(translation)
      XCTAssertNotNil(rotation)
      XCTAssertEqual(
        translation.flatMap(TransformGizmoFactory.handle(from:)),
        .translate(axis)
      )
      XCTAssertEqual(
        rotation.flatMap(TransformGizmoFactory.handle(from:)),
        .rotate(axis)
      )
    }
  }

  func testEveryProxyKindHasANamedSelectionHighlight() {
    for kind in RigPrimitiveKind.allCases {
      let highlight = TransformGizmoFactory.makeSelectionHighlight(for: kind)
      XCTAssertEqual(highlight.name, TransformGizmoFactory.selectionHighlightName)
    }
  }
}
