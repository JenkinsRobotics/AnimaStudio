import AnimaCore
import RealityKitViewport
import XCTest

@testable import AnimaStudioUI

@MainActor
final class ComponentAppearanceTests: XCTestCase {
  func testComponentAppearanceEditsAndResetUseTheViewportOverride() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    let original = try XCTUnwrap(model.componentAppearance(for: part.id))
    let edited = try XCTUnwrap(
      PreviewPartAppearance(hexRGB: "#9DCFED", opacity: 0.65, isVisible: true)
    )

    model.setComponentAppearance(id: part.id, to: edited)
    XCTAssertEqual(model.componentAppearance(for: part.id), edited)

    model.resetComponentAppearance(id: part.id)
    XCTAssertEqual(model.componentAppearance(for: part.id), original)
    XCTAssertNil(model.componentAppearances[part.id])
  }

  func testLockedComponentRejectsAppearanceChangesAndReset() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .sphere)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    let edited = try XCTUnwrap(PreviewPartAppearance(hexRGB: "#EA4335"))
    model.setComponentAppearance(id: part.id, to: edited)
    model.toggleComponentLock(part.id)

    model.setComponentAppearance(
      id: part.id,
      to: try XCTUnwrap(PreviewPartAppearance(hexRGB: "#4285F4"))
    )
    model.resetComponentAppearance(id: part.id)

    XCTAssertEqual(model.componentAppearance(for: part.id), edited)
  }

  func testUnknownComponentHasNoAppearance() {
    let model = StudioWorkspaceModel()

    XCTAssertNil(model.componentAppearance(for: PartID()))
  }
}
