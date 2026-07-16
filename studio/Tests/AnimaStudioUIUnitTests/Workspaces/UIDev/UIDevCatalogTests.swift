import XCTest

@testable import AnimaStudioUI

final class UIDevCatalogTests: XCTestCase {
  func testGallerySectionsHaveStableReadablePresentation() {
    XCTAssertEqual(
      UIDevSection.allCases,
      [
        .overview, .templateMatrix, .referenceWidgets, .designKit, .navigator, .inspector,
        .timeline, .workspace3D, .buttons, .inputs, .menus, .panels, .mateEditor,
        .triadManipulator, .dialogs, .popovers, .tokens,
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
    XCTAssertFalse(UIDevSection.templateMatrix.isEmbeddedWorkspacePreview)
    XCTAssertFalse(UIDevSection.referenceWidgets.isEmbeddedWorkspacePreview)
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

  func testTemplateMatrixCoversEveryCategoryWithStableUniqueTemplates() {
    let templates = UIDevTemplateMatrixCatalog.templates

    XCTAssertEqual(Set(templates.map(\.id)).count, templates.count)
    XCTAssertEqual(Set(templates.map(\.id)), Set(UIDevTemplateID.allCases))
    XCTAssertTrue(templates.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    XCTAssertTrue(templates.allSatisfy { $0.idealWidth > 0 && $0.idealHeight > 0 })

    for category in UIDevTemplateCategory.allCases {
      XCTAssertFalse(UIDevTemplateMatrixCatalog.templates(in: category).isEmpty)
    }
  }

  func testRecentProjectsTemplateIsAProductionSizedStartSurface() throws {
    let recentProjects = try XCTUnwrap(
      UIDevTemplateMatrixCatalog.templates.first { $0.id == .recentProjects }
    )

    XCTAssertEqual(recentProjects.category, .windowsAndWorkspaces)
    XCTAssertGreaterThanOrEqual(recentProjects.idealWidth, 400)
    XCTAssertGreaterThanOrEqual(recentProjects.idealHeight, 220)
  }

  func testReferenceWidgetPackHasStableKindsAndMatrixEntries() {
    XCTAssertEqual(
      UIDevReferenceWidgetKind.allCases,
      [
        .layeredIconList, .notificationPopup, .layoutStyleControls, .compactTabPanel,
        .documentTabStrip,
      ]
    )

    let matrixIDs = Set(UIDevTemplateMatrixCatalog.templates.map(\.id))
    XCTAssertTrue(matrixIDs.contains(.layeredIconList))
    XCTAssertTrue(matrixIDs.contains(.notificationPopup))
    XCTAssertTrue(matrixIDs.contains(.layoutStyleControls))
    XCTAssertTrue(matrixIDs.contains(.compactTabPanel))
    XCTAssertTrue(matrixIDs.contains(.documentTabStrip))

    for widget in UIDevReferenceWidgetKind.allCases {
      XCTAssertFalse(widget.title.isEmpty)
      XCTAssertFalse(widget.detail.isEmpty)
      XCTAssertGreaterThan(widget.idealSize.width, 0)
      XCTAssertGreaterThan(widget.idealSize.height, 0)
    }
  }

  func testTabReferencePackHasReadableDefaultsAndProductionProportions() throws {
    XCTAssertEqual(UIDevPreviewTheme.allCases, [.light, .dark])
    XCTAssertEqual(
      UIDevDocumentTab.samples.map(\.title),
      ["db1_addresses", "db1_archive", "db1_books", "db1_urgent"]
    )

    let compact = try XCTUnwrap(
      UIDevTemplateMatrixCatalog.templates.first { $0.id == .compactTabPanel }
    )
    let documents = try XCTUnwrap(
      UIDevTemplateMatrixCatalog.templates.first { $0.id == .documentTabStrip }
    )

    XCTAssertEqual(compact.category, .controls)
    XCTAssertEqual(documents.category, .windowsAndWorkspaces)
    XCTAssertGreaterThan(documents.idealWidth, compact.idealWidth)
    XCTAssertLessThan(documents.idealHeight, compact.idealHeight)
  }
}
