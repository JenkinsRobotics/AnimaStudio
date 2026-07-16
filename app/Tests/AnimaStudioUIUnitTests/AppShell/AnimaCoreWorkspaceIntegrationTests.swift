import AnimaCoreClient
import Foundation
import Testing

@testable import AnimaStudioUI

@Suite(.serialized)
@MainActor
struct AnimaCoreWorkspaceIntegrationTests {
  @Test
  func engineEvaluationBecomesTheFrameConsumedByTheViewport() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    let workspace = StudioWorkspaceModel(
      animaCoreClient: client,
      resolvesDefaultAnimaCoreClient: false
    )
    let characterURL =
      repositoryRoot
      .appendingPathComponent("examples/six_axis_arm.character.anima")

    await workspace.importAnimaCharacter(from: characterURL)

    #expect(
      workspace.animaCoreState
        == .loaded(characterName: "Six-axis arm", engineVersion: "0.1.0")
    )
    #expect(workspace.project.name == "Six-axis arm")
    #expect(workspace.project.rig.joints.count == 6)
    #expect(workspace.engineEvaluationTimeSeconds == 1)
    #expect(
      workspace.evaluatedFrame.jointAnglesRadians["base_yaw.rotation"]
        == .pi / 3
    )

    await workspace.shutdownAnimaCore()
  }

  private func repositoryRootURL() throws -> URL {
    var candidate = URL(fileURLWithPath: #filePath)
    for _ in 0..<8 {
      candidate.deleteLastPathComponent()
      if FileManager.default.fileExists(
        atPath: candidate.appendingPathComponent("animacore/bridge.py").path
      ) {
        return candidate
      }
    }
    throw AnimaCoreClientError.helperNotFound
  }
}
