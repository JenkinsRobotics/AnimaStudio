import RealityKitViewport
import XCTest

@testable import AnimaStudioUI

final class ViewportRenderMenuTests: XCTestCase {
  func testShadedMenuIconReflectsIndependentEdgeVisibility() {
    XCTAssertEqual(
      ViewportRenderMenuPresentation.icon(
        renderStyle: .shaded,
        edgeDisplay: .hidden
      ),
      "cube.fill"
    )
    XCTAssertEqual(
      ViewportRenderMenuPresentation.icon(
        renderStyle: .shaded,
        edgeDisplay: .mesh
      ),
      "cube"
    )
  }

  func testNonShadedSurfaceKeepsItsOwnIcon() {
    XCTAssertEqual(
      ViewportRenderMenuPresentation.icon(
        renderStyle: .wireframe,
        edgeDisplay: .mesh
      ),
      "square.grid.3x3"
    )
  }

  func testNavigationSpeedChoicesRemainHumanReadable() {
    XCTAssertEqual(
      PreviewNavigationSpeed.allCases.map(\.title),
      ["Slow", "Reduced", "Standard", "Fast", "Very Fast"]
    )
    XCTAssertTrue(
      zip(
        PreviewNavigationSpeed.allCases,
        PreviewNavigationSpeed.allCases.dropFirst()
      ).allSatisfy { $0.multiplier < $1.multiplier }
    )
  }

  func testMouseSettingsHeaderKeepsTheApprovedControlFamilies() {
    XCTAssertEqual(
      MouseSettingsTab.allCases.map(\.title),
      ["Scroll", "Mouse", "Buttons", "Keyboard", "Exceptions", "Settings"]
    )
  }

  func testCustomBindingsExposeOptionBasedCADChords() {
    XCTAssertTrue(NavigationDragBinding.allCases.contains(.optionMiddleMouse))
    XCTAssertTrue(NavigationDragBinding.allCases.contains(.optionRightMouse))
    XCTAssertEqual(NavigationDragBinding.optionMiddleMouse.title, "Option + Middle Mouse Drag")
  }
}
