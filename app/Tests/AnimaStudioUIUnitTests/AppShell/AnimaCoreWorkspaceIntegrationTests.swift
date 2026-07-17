import AnimaCoreClient
import AnimaDocument
import AnimaModel
import Foundation
import RealityKitViewport
import Testing

@testable import AnimaStudioUI

@Suite(.serialized)
@MainActor
struct AnimaCoreWorkspaceIntegrationTests {
  @Test
  func engineSerializedCharacterSavesAndReopensThroughPlainProjectFolder() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    defer { Task { await client.shutdown() } }
    let sourceText = try String(
      contentsOf: repositoryRoot.appendingPathComponent(
        "examples/six_axis_arm.character.anima"
      ),
      encoding: .utf8
    )
    let loaded = try await client.loadCharacter(text: sourceText)
    let canonicalText = try await client.serializeCharacter(rig: loaded.rigDocument).text
    let character = ProjectCharacterReference(
      folderName: loaded.rig.identity.name,
      displayName: loaded.rig.identity.displayName
    )
    let projectURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("AnimaProjectRoundTrip-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }
    var document = ProjectLifecycle.makeEmptyDocument(name: "Robot Cell")
    document.characters = [character]
    document.editorState.activeCharacterFolderName = character.folderName
    let store = AnimaDocumentStore(bookmarkStyle: .plain)
    _ = try store.save(
      document,
      to: projectURL,
      fileWrites: [
        ProjectFileWrite(relativePath: character.characterPath, text: canonicalText)
      ]
    )

    let reopenedDocument = try store.load(from: projectURL)
    let reopenedCharacter = try #require(reopenedDocument.activeCharacter)
    let reopenedText = try String(
      contentsOf: projectURL.appendingPathComponent(reopenedCharacter.characterPath),
      encoding: .utf8
    )
    let engineReload = try await client.loadCharacter(text: reopenedText)

    #expect(reopenedDocument.displayName == "Robot Cell")
    #expect(engineReload.rig.identity == loaded.rig.identity)
    #expect(engineReload.rig.joints.map(\.id) == loaded.rig.joints.map(\.id))
  }

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
    #expect(workspace.project.rig.parts.count == 7)
    #expect(workspace.project.rig.joints.isEmpty)
    #expect(workspace.engineResolvedPartPoses.count == 7)
    #expect(workspace.engineEvaluationTimeSeconds == 1)
    #expect(workspace.hasSerializableCharacter)
    #expect(workspace.currentCharacterReference?.folderName == "six_axis_arm")
    let serialized = try await workspace.serializedCharacterText()
    #expect(serialized.contains("six_axis_arm"))
    #expect(
      workspace.evaluatedFrame.jointAnglesRadians["base_yaw.rotation"]
        == .pi / 3
    )

    await workspace.shutdownAnimaCore()
  }

  @Test
  func articulatedArmJogAndIKStayEngineDriven() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    let workspace = StudioWorkspaceModel(
      startupWorkspace: .rig,
      animaCoreClient: client,
      resolvesDefaultAnimaCoreClient: false
    )
    await workspace.importAnimaCharacter(
      from: repositoryRoot.appendingPathComponent(
        "examples/six_axis_arm_dh.character.anima"
      )
    )

    let chain = try #require(workspace.engineKinematicChain)
    let initialTool = try #require(workspace.armToolPose)
    #expect(chain.joints.count == 6)
    #expect(workspace.armJointValues.keys.count == 6)
    #expect(workspace.armIKTargetPose == initialTool)

    await workspace.jogArmJoint(named: "j1", to: 0.25)
    #expect(abs((workspace.armJointValues["j1"] ?? 0) - 0.25) < 1e-9)
    let joggedTool = try #require(workspace.armToolPose)
    #expect(joggedTool != initialTool)

    await workspace.solveArmIK(target: joggedTool)
    guard case .reached = workspace.armIKReachState else {
      Issue.record("IK must reach the currently rendered tool pose")
      await workspace.shutdownAnimaCore()
      return
    }
    #expect(workspace.armIKTargetPose == workspace.armToolPose)

    await workspace.shutdownAnimaCore()
  }

  @Test
  func semanticAndEditorStateSaveTogetherAndReopenInTheirOwningFiles() async throws {
    let repositoryRoot = try repositoryRootURL()
    let sourceURL = repositoryRoot.appendingPathComponent(
      "examples/six_axis_arm.character.anima"
    )
    let firstClient = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    let first = StudioWorkspaceModel(
      animaCoreClient: firstClient,
      resolvesDefaultAnimaCoreClient: false
    )
    await first.importAnimaCharacter(from: sourceURL)
    let baseID = try #require(first.partID(forEngineName: "base"))
    let shoulderID = try #require(first.partID(forEngineName: "shoulder"))
    first.setPartPosition(id: baseID, to: RigVector3(x: 0.125, y: -0.25, z: 0.5))
    first.setComponentAppearance(
      id: baseID,
      to: PreviewPartAppearance(
        red: 0.2,
        green: 0.4,
        blue: 0.8,
        opacity: 0.75,
        isVisible: false,
        finish: .metallic,
        proxyFilletRadiusMeters: 0.014
      )
    )
    first.selection = [.part(baseID), .part(shoulderID)]
    let groupID = first.createComponentGroup(named: "Base Assembly")
    first.toggleComponentGroupLock(groupID)
    let character = try #require(first.currentCharacterReference)
    let canonicalText = try await first.serializedCharacterText()
    let editorMetadata = first.characterEditorMetadata(
      applyingTo: CharacterEditorMetadata()
    )
    let projectURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("AnimaObjectStateRoundTrip-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }
    var document = ProjectLifecycle.makeEmptyDocument(name: "Robot Cell")
    document.characters = [character]
    document.editorState.activeCharacterFolderName = character.folderName
    let store = AnimaDocumentStore(bookmarkStyle: .plain)
    _ = try store.save(
      document,
      to: projectURL,
      fileWrites: [
        ProjectFileWrite(relativePath: character.characterPath, text: canonicalText),
        ProjectFileWrite(
          relativePath: character.editorPath, data: try editorMetadata.encodedData()),
      ]
    )
    await first.shutdownAnimaCore()

    let secondClient = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    let reopened = StudioWorkspaceModel(
      animaCoreClient: secondClient,
      resolvesDefaultAnimaCoreClient: false
    )
    let reopenedCanonicalText = try String(
      contentsOf: projectURL.appendingPathComponent(character.characterPath),
      encoding: .utf8
    )
    try await reopened.loadSerializedCharacter(text: reopenedCanonicalText)
    let reopenedMetadata = try CharacterEditorMetadata.decode(
      Data(contentsOf: projectURL.appendingPathComponent(character.editorPath))
    )
    reopened.applyCharacterEditorMetadata(reopenedMetadata)

    let reopenedBase = try #require(reopened.engineParts.first { $0.name == "base" })
    #expect(reopenedBase.positionMeters == [0.125, -0.25, 0.5])
    let reopenedBaseID = try #require(reopened.partID(forEngineName: "base"))
    let appearance = try #require(reopened.componentAppearance(for: reopenedBaseID))
    #expect(appearance.finish == .metallic)
    #expect(!appearance.isVisible)
    #expect(appearance.proxyFilletRadiusMeters == 0.014)
    #expect(reopened.componentGroups.first?.displayName == "Base Assembly")
    #expect(reopened.componentGroups.first?.isLocked == true)

    await reopened.shutdownAnimaCore()
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
      Set(workspace.engineMateTypes.map(\.type))
        == Set(
          [
            "fastened", "parallel", "prismatic", "revolute",
            "cylindrical", "pin_slot", "planar", "ball", "width", "tangent",
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
    #expect(presentation.categoryLabel == "Kinematic")
    #expect(presentation.isDrivable)
    #expect(presentation.zeroDOFTitle == "Fully bonded")
    #expect(presentation.offsetMillimeters == [1, 2, 3])
    #expect(abs(presentation.offsetRotationDegrees - 15) < 1e-12)

    await workspace.shutdownAnimaCore()
  }

  @Test
  func geometryMatesUseNonDrivableInspectorPresentations() async throws {
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
    let characterURL = repositoryRoot.appendingPathComponent(
      "examples/geometry_mates_demo.character.anima")

    await workspace.importAnimaCharacter(from: characterURL)

    let width = try #require(workspace.engineMates.first { $0.type == "width" })
    let tangent = try #require(workspace.engineMates.first { $0.type == "tangent" })
    let widthPresentation = EngineMateInspectorPresentation(
      mate: width,
      mateType: workspace.engineMateType(for: width)
    )
    let tangentPresentation = EngineMateInspectorPresentation(
      mate: tangent,
      mateType: workspace.engineMateType(for: tangent)
    )

    #expect(widthPresentation.categoryLabel == "Geometry constraint")
    #expect(!widthPresentation.isDrivable)
    #expect(widthPresentation.zeroDOFTitle == "Width constraint")
    #expect(tangentPresentation.zeroDOFTitle == "Tangent constraint")
    #expect(tangent.controls == nil)
    #expect(tangent.tangent != nil)

    await workspace.shutdownAnimaCore()
  }

  @Test
  func relationsPopulateCatalogNavigatorAndCoupledViewportHighlights() async throws {
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
    let characterURL = repositoryRoot.appendingPathComponent(
      "examples/rc_car.character.anima")

    await workspace.importAnimaCharacter(from: characterURL)

    #expect(workspace.engineRelationTypes.map(\.kind) == [.gear, .rackPinion, .screw, .linear])
    let relation = try #require(workspace.engineRelations.first)
    #expect(relation.kind == .rackPinion)
    #expect(abs(relation.ratioFieldValue - 125.663_706) < 0.000_001)

    workspace.selection = [.relation(relation.id)]
    #expect(workspace.selectedEngineRelation?.id == relation.id)
    let highlightedNames = Set(
      workspace.project.rig.parts.compactMap { part in
        workspace.viewportHighlightedPartIDs.contains(part.id) ? part.displayName : nil
      }
    )
    #expect(highlightedNames == ["front_axle", "steering_rack"])

    let driverOptions = workspace.relationDOFOptions(kind: .rotation)
    let drivenOptions = workspace.relationDOFOptions(kind: .translation)
    #expect(driverOptions.contains { $0.path == "steering.rotation" })
    #expect(drivenOptions.map(\.path) == ["rack.travel"])

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
