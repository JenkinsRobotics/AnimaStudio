import AnimaCoreClient
import AnimaDocument
import Foundation
import RealityKitViewport
import XCTest

@testable import AnimaStudioUI

/// Regression: an engine reload (suppress toggle, mate edit, re-evaluation)
/// must keep the viewport's imported meshes. Previously `loadAnimaCharacter`
/// wiped `enginePartModelSources` and only a separate `configurePartModelSources`
/// call repopulated it, so any reload dropped every part to a primitive proxy.
@MainActor
final class PartModelSourceReloadTests: XCTestCase {
  func testReloadRetainsImportedModelSources() async throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repoRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repoRoot
      )
    )
    defer { Task { await client.shutdown() } }

    let charURL = repoRoot.appendingPathComponent("examples/pan_tilt_head.character.anima")
    let text = try String(contentsOf: charURL, encoding: .utf8)
    let assetsDir = charURL.deletingLastPathComponent()

    let workspace = StudioWorkspaceModel(
      animaCoreClient: client,
      resolvesDefaultAnimaCoreClient: false
    )
    try await workspace.loadSerializedCharacter(text: text)
    workspace.configurePartModelSources(
      characterDirectoryURL: assetsDir,
      editorMetadata: CharacterEditorMetadata()
    )

    let initial = workspace.enginePartModelSources.count
    XCTAssertGreaterThan(initial, 0, "model refs should produce render sources")
    // Every render part with a model ref must resolve to a source.
    let hits = workspace.project.rig.parts.filter {
      workspace.enginePartModelSources[$0.id] != nil
    }.count
    XCTAssertEqual(hits, initial)

    // Any subsequent engine reload must preserve the sources.
    try await workspace.loadSerializedCharacter(text: text)
    XCTAssertEqual(
      workspace.enginePartModelSources.count, initial,
      "reload dropped imported meshes back to proxies"
    )
  }
}
