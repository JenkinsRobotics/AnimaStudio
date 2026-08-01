import XCTest

@testable import AnimaStudioUI

final class NativeImportPanelTests: XCTestCase {
  func testModelPanelAcceptsTheClosedFormatSetAndMultipleFiles() {
    let configuration = NativeImportPanelConfiguration.models

    XCTAssertEqual(
      configuration.allowedFileExtensions,
      ModelImportFormatSupport.supportedFileExtensions
    )
    XCTAssertEqual(
      configuration.allowedContentTypes.count,
      ModelImportFormatSupport.supportedFileExtensions.count
    )
    XCTAssertTrue(configuration.message.contains(ModelImportFormatSupport.operatorLabel))
    XCTAssertTrue(configuration.message.contains("destination character"))
    XCTAssertTrue(configuration.allowsMultipleSelection)
    XCTAssertEqual(configuration.prompt, "Import")
  }

  func testCharacterPanelAcceptsOneAnimaFile() {
    let configuration = NativeImportPanelConfiguration.animaCharacter

    XCTAssertEqual(configuration.allowedFileExtensions, ["anima"])
    XCTAssertEqual(configuration.allowedContentTypes.count, 1)
    XCTAssertFalse(configuration.allowsMultipleSelection)
    XCTAssertEqual(configuration.prompt, "Import Character")
  }
}
