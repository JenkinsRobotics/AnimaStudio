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
        .documentTabStrip, .materialEditor, .timelineDesignB,
      ]
    )

    let matrixIDs = Set(UIDevTemplateMatrixCatalog.templates.map(\.id))
    XCTAssertTrue(matrixIDs.contains(.layeredIconList))
    XCTAssertTrue(matrixIDs.contains(.notificationPopup))
    XCTAssertTrue(matrixIDs.contains(.layoutStyleControls))
    XCTAssertTrue(matrixIDs.contains(.compactTabPanel))
    XCTAssertTrue(matrixIDs.contains(.documentTabStrip))
    XCTAssertTrue(matrixIDs.contains(.materialEditor))
    XCTAssertTrue(matrixIDs.contains(.timelineDesignB))

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

  func testMaterialReferencePackHasStableSurfaceVocabulary() throws {
    XCTAssertEqual(
      UIDevMaterialType.allCases,
      [.glossy, .matte, .metallic, .glass, .emissive]
    )
    XCTAssertEqual(
      UIDevMaterialChannel.allCases,
      [.diffuse, .specular, .roughness, .bump, .normal, .displacement]
    )
    XCTAssertTrue(
      UIDevMaterialChannel.allCases.allSatisfy {
        (0...1).contains($0.defaultValue) && !$0.title.isEmpty
      }
    )

    let material = try XCTUnwrap(
      UIDevTemplateMatrixCatalog.templates.first { $0.id == .materialEditor }
    )
    XCTAssertEqual(material.category, .inspectors)
    XCTAssertGreaterThanOrEqual(material.idealWidth, 400)
    XCTAssertGreaterThanOrEqual(material.idealHeight, 600)
  }

  func testTimelineDesignBVariantsShareSortedBoundedKeyframeData() throws {
    XCTAssertEqual(
      UIDevTimelineBVariant.allCases,
      [.dopeSheet, .motionCurves, .waypointLanes]
    )
    XCTAssertGreaterThanOrEqual(UIDevTimelineBSamples.tracks.count, 4)
    XCTAssertTrue(UIDevTimelineBSamples.tracks.allSatisfy { !$0.keyframes.isEmpty })

    var track = UIDevTimelineBTrack(
      name: "Test",
      colorIndex: 0,
      keyframes: [.init(time: 4, value: 0.5), .init(time: 1, value: 0.2)]
    )
    let insertedID = track.insertKeyframe(time: 10, value: -1, duration: 8)

    XCTAssertEqual(track.keyframes.map(\.time), [1, 4, 8])
    XCTAssertEqual(track.keyframes.last?.id, insertedID)
    XCTAssertEqual(track.keyframes.last?.value, 0)

    let source = UIDevTimelineBKeyframe(time: 2, value: 0.75)
    let point = UIDevTimelineBGeometry.normalizedPoint(
      for: source,
      variant: .motionCurves,
      duration: 8
    )
    XCTAssertEqual(point.x, 0.25, accuracy: 0.0001)
    XCTAssertEqual(
      UIDevTimelineBGeometry.value(atNormalizedY: point.y, variant: .motionCurves),
      source.value,
      accuracy: 0.0001
    )

    let descriptor = try XCTUnwrap(
      UIDevTemplateMatrixCatalog.templates.first { $0.id == .timelineDesignB }
    )
    XCTAssertEqual(descriptor.category, .timelines)
    XCTAssertGreaterThanOrEqual(descriptor.idealWidth, 1_000)
  }
}
