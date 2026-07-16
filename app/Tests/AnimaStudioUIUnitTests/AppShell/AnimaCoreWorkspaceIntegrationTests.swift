import AnimaCoreClient
import AnimaModel
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

  @Test
  func fastenedMateAppearsByStableIDAndDrivesInspectorPresentation() async throws {
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
    let characterURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).character.anima")
    defer { try? FileManager.default.removeItem(at: characterURL) }
    try fastenedCharacterText.write(to: characterURL, atomically: true, encoding: .utf8)

    await workspace.importAnimaCharacter(from: characterURL)

    #expect(
      workspace.animaCoreState
        == .loaded(characterName: "Fastened Fixture", engineVersion: "0.1.0")
    )
    #expect(
      Set(workspace.engineMateTypes.map(\.type)).isSuperset(
        of: [
          "fastened", "parallel", "prismatic", "revolute",
          "cylindrical", "pin_slot", "planar", "ball",
        ]
      )
    )
    #expect(workspace.engineMates.count == 1)
    #expect(workspace.project.rig.joints.isEmpty)
    #expect(!workspace.isRigEmpty)

    workspace.selection = [.joint(JointID(rawValue: "Fastened 33"))]
    let mate = try #require(workspace.selectedEngineMate)
    let presentation = EngineMateInspectorPresentation(
      mate: mate,
      mateType: workspace.engineMateType(for: mate)
    )
    #expect(mate.id == "Fastened 33")
    #expect(mate.degreesOfFreedom.isEmpty)
    #expect(presentation.typeLabel == "Fastened")
    #expect(presentation.degreeOfFreedomSummary == "0 available")
    #expect(presentation.offsetMillimeters == [1, 2, 3])
    #expect(abs(presentation.offsetRotationDegrees - 15) < 1e-12)

    await workspace.shutdownAnimaCore()
  }

  private var fastenedCharacterText: String {
    """
    anima_version: "2.0"
    type: character
    identity: { name: fastened_fixture, display_name: "Fastened Fixture" }
    parts:
      base: {}
      lid: { parent: base }
    joints:
      fixed_lid:
        type: fastened
        id: "Fastened 33"
        parent: base
        child: lid
        connectors:
          a:
            part: base
            origin_m: [0.0, 0.0, 0.025]
            primary_axis: [0.0, 0.0, 1.0]
            secondary_axis: [1.0, 0.0, 0.0]
            feature: "base/top_face"
          b:
            part: lid
            origin_m: [0.0, 0.0, -0.004]
            primary_axis: [0.0, 0.0, 1.0]
            secondary_axis: [1.0, 0.0, 0.0]
            flipped: true
            feature: "lid/bottom_face"
        offset:
          enabled: true
          translation_m: [0.001, 0.002, 0.003]
          rotate_about: x
          angle_deg: 15
        flip_primary_axis: true
        secondary_axis_rotation_deg: 90
        simulation_connection: false
    """
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
