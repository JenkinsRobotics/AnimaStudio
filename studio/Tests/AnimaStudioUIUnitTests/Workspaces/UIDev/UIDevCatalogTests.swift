import XCTest

@testable import AnimaStudioUI

final class UIDevCatalogTests: XCTestCase {
  func testGallerySectionsHaveStableReadablePresentation() {
    XCTAssertEqual(
      UIDevSection.allCases,
      [
        .overview, .designKit, .navigator, .inspector, .timeline, .workspace3D, .buttons,
        .inputs, .menus, .panels, .mateEditor, .triadManipulator, .dialogs, .popovers,
        .tokens,
      ]
    )

    for section in UIDevSection.allCases {
      XCTAssertFalse(section.title.isEmpty)
      XCTAssertFalse(section.systemImage.isEmpty)
      XCTAssertFalse(section.purpose.isEmpty)
    }
  }

  func testProductionSurfacePreviewsStayEmbeddedInUIDev() {
    let embedded: [UIDevSection] = [.navigator, .inspector, .timeline, .workspace3D]
    XCTAssertTrue(embedded.allSatisfy(\.isEmbeddedWorkspacePreview))
    XCTAssertFalse(UIDevSection.overview.isEmbeddedWorkspacePreview)
    XCTAssertFalse(UIDevSection.designKit.isEmbeddedWorkspacePreview)
    XCTAssertFalse(UIDevSection.panels.isEmbeddedWorkspacePreview)
  }

  func testUIDevIsAnExplicitShellWorkspace() {
    XCTAssertEqual(UIDevWorkspaceDescriptor.title, "UI Dev")
    XCTAssertEqual(UIDevWorkspaceDescriptor.shortcutNumber, 6)
    XCTAssertFalse(StudioWorkspaceKind.allCases.map(\.descriptor.title).contains("UI Dev"))
  }

  func testTriadLabNamesEveryInteractiveHandle() {
    XCTAssertEqual(
      UIDevTriadHandle.allCases,
      [.center, .translateX, .translateY, .translateZ, .rotateX, .rotateY, .rotateZ]
    )
    XCTAssertTrue(UIDevTriadHandle.allCases.allSatisfy { !$0.title.isEmpty })
  }
}
