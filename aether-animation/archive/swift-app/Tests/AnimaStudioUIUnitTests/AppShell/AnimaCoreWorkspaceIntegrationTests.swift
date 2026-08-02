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
  func groundedPartRejectsRestTransformEdits() async throws {
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
    let characterURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "grounded-\(UUID().uuidString).character.anima")
    try """
    anima_version: "2.0"
    type: character
    identity:
      name: grounded_test
      display_name: Grounded Test
    parts:
      base:
        grounded: true
        position_m: [0.1, 0.2, 0.3]
    """.write(to: characterURL, atomically: true, encoding: .utf8)
    defer {
      try? FileManager.default.removeItem(at: characterURL)
    }

    await workspace.importAnimaCharacter(from: characterURL)
    let partID = try #require(workspace.partID(forEngineName: "base"))
    #expect(!workspace.isPartRestTransformEditable(partID))

    workspace.setPartPosition(id: partID, to: RigVector3(x: 9, y: 9, z: 9))

    let projected = try #require(workspace.project.rig.parts.first { $0.id == partID })
    #expect(projected.positionMeters == RigVector3(x: 0.1, y: 0.2, z: 0.3))
  }

  @Test
  func deletingPartsRoundTripsThroughTheCanonicalEngine() async throws {
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
    await workspace.importAnimaCharacter(
      from: repositoryRoot.appendingPathComponent("examples/rc_car.character.anima")
    )

    try await workspace.deleteEngineParts(named: ["front_axle"])

    #expect(!workspace.engineParts.contains { $0.name == "front_axle" })
    #expect(!workspace.engineMates.contains { $0.name == "steering" })
    #expect(workspace.engineRelations.isEmpty)
    let serialized = try await workspace.serializedCharacterText()
    let reloaded = try await client.loadCharacter(text: serialized)
    #expect(!reloaded.rig.parts.contains { $0.name == "front_axle" })
    #expect(!reloaded.rig.joints.contains { $0.name == "steering" })
    #expect(reloaded.rig.relations.isEmpty)
    #expect(!reloaded.rig.outputs.contains { $0.targetPath == "steering.rotation" })

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
    let upperArmID = try #require(first.partID(forEngineName: "upper_arm"))
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
    first.selection = [.part(upperArmID)]
    let childGroupID = first.createComponentGroup(named: "Arm Assembly")
    #expect(first.nestComponentGroup(childGroupID, in: groupID))
    await first.toggleComponentGroupGrounded(groupID)
    #expect(
      first.componentIDs(inGroupIncludingDescendants: groupID)
        .allSatisfy { first.enginePart(for: $0)?.isGrounded == true })
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
    let reopenedParent = try #require(
      reopened.componentGroups.first { $0.displayName == "Base Assembly" })
    let reopenedChild = try #require(
      reopened.componentGroups.first { $0.displayName == "Arm Assembly" })
    #expect(reopenedParent.isLocked)
    #expect(reopenedChild.parentGroupID == reopenedParent.id)
    #expect(reopened.rootComponentGroups.map(\.id) == [reopenedParent.id])
    let reopenedGroupID = reopenedParent.id
    #expect(
      reopened.componentIDs(inGroupIncludingDescendants: reopenedGroupID)
        .allSatisfy { reopened.enginePart(for: $0)?.isGrounded == true })

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
    let availableDrivenOptions = workspace.relationDOFOptions(
      kind: .translation,
      availableAsDriven: true
    )
    #expect(driverOptions.contains { $0.path == "steering.rotation" })
    #expect(drivenOptions.map(\.path) == ["rack.travel"])
    #expect(availableDrivenOptions.isEmpty)

    await workspace.shutdownAnimaCore()
  }

  @Test
  func relationAuthoringCreatesEditsPersistsSuppressesAndDeletesThroughEngine() async throws {
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
    let characterURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "relation-authoring-\(UUID().uuidString).character.anima"
    )
    try """
    anima_version: "2.0"
    type: character
    identity:
      name: relation_authoring
      display_name: Relation Authoring
    parts:
      base: { grounded: true }
      driver: { parent: base }
      driven: { parent: driver }
    joints:
      driver_joint:
        type: revolute
        parent: base
        child: driver
        dofs:
          rotation:
            neutral_deg: 0
            axis: [0, 0, 1]
      driven_joint:
        type: revolute
        parent: driver
        child: driven
        dofs:
          rotation:
            neutral_deg: 0
            axis: [0, 0, 1]
    clips:
      motion:
        duration_s: 1
        tracks:
          - time: 0
            values: { driver_joint.rotation: 0 }
          - time: 1
            values: { driver_joint.rotation: 10 }
    """.write(to: characterURL, atomically: true, encoding: .utf8)
    defer {
      try? FileManager.default.removeItem(at: characterURL)
      Task { await workspace.shutdownAnimaCore() }
    }

    await workspace.importAnimaCharacter(from: characterURL)
    let gearType = try #require(workspace.engineRelationTypes.first { $0.kind == .gear })
    var draft = RelationDraft(type: gearType)
    draft.driverPath = "driver_joint.rotation"
    draft.drivenPath = "driven_joint.rotation"
    draft.ratioFieldValue = 2
    draft.offsetFieldValue = 5

    let created = try await workspace.createEngineRelation(from: draft)

    #expect(workspace.relationDraft == nil)
    #expect(workspace.selection == [.relation(created.id)])
    #expect(created.ratio == 2)
    #expect(abs(created.offset - 5 * .pi / 180) < 0.000_001)
    #expect(
      abs(
        (workspace.evaluatedFrame.jointAnglesRadians["driven_joint.rotation"] ?? 0)
          - 25 * .pi / 180
      ) < 0.000_001
    )

    var edit = RelationDraft(relation: created, type: gearType)
    edit.ratioFieldValue = 3
    edit.offsetFieldValue = 10
    edit.isReversed = true
    let updated = try await workspace.updateEngineRelation(created, with: edit)
    #expect(updated.ratio == -3)
    #expect(abs(updated.offset - 10 * .pi / 180) < 0.000_001)
    #expect(workspace.selection == [.relation(updated.id)])

    let serialized = try await workspace.serializedCharacterText()
    let reloaded = try await client.loadCharacter(text: serialized)
    let persisted = try #require(reloaded.rig.relations.first)
    #expect(persisted.kind == .gear)
    #expect(persisted.ratio == -3)
    #expect(abs(persisted.offset - 10 * .pi / 180) < 0.000_001)

    await workspace.toggleRelationSuppressed(updated)
    let suppressed = try #require(workspace.engineRelations.first)
    #expect(suppressed.isSuppressed)

    await workspace.deleteEngineRelation(suppressed)
    #expect(workspace.engineRelations.isEmpty)
    #expect(workspace.selectedEngineRelation == nil)
  }

  @Test
  func twoConnectorPlacementCreatesCanonicalFastenedMateAndResolvedPose() async throws {
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
    let characterURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "mate-authoring-\(UUID().uuidString).character.anima"
    )
    try """
    anima_version: "2.0"
    type: character
    identity:
      name: mate_authoring
      display_name: Mate Authoring
    parts:
      base:
        grounded: true
        position_m: [1.0, 0.0, 0.0]
      arm: {}
    """.write(to: characterURL, atomically: true, encoding: .utf8)
    defer {
      try? FileManager.default.removeItem(at: characterURL)
      Task { await workspace.shutdownAnimaCore() }
    }

    await workspace.importAnimaCharacter(from: characterURL)
    let base = try #require(workspace.partID(forEngineName: "base"))
    let arm = try #require(workspace.partID(forEngineName: "arm"))
    #expect(workspace.canCreateMate(.fastened))
    #expect(workspace.canCreateMate(.revolute))
    #expect(workspace.canCreateMate(.slider))

    workspace.beginMatePlacement(.fastened)
    workspace.selectMateConnector(
      MateConnectorCandidate(
        id: "arm-origin",
        partID: arm,
        displayName: "Arm Origin",
        featureKind: .origin,
        connector: MateConnectorDefinition()
      )
    )
    workspace.selectMateConnector(
      MateConnectorCandidate(
        id: "base-origin",
        partID: base,
        displayName: "Base Origin",
        featureKind: .origin,
        connector: MateConnectorDefinition()
      )
    )
    #expect(workspace.matePlacement?.targetCandidate?.partID == base)
    for _ in 0..<80 {
      if workspace.matePlacement?.isPreviewing == false { break }
      try await Task.sleep(for: .milliseconds(25))
    }
    #expect(workspace.engineMates.isEmpty)
    #expect(workspace.engineResolvedPartPoses[arm]?.positionMeters.x == 1)

    var previewOptions = EngineMatePlacementOptions()
    previewOptions.offsetEnabled = true
    previewOptions.offsetTranslationMillimeters = [250, 0, 0]
    previewOptions.flipsPrimaryAxis = true
    workspace.updateMatePlacementOptions(previewOptions)
    for _ in 0..<80 {
      if workspace.matePlacement?.isPreviewing == false { break }
      try await Task.sleep(for: .milliseconds(25))
    }
    #expect(workspace.engineMates.isEmpty)
    #expect(workspace.engineResolvedPartPoses[arm]?.positionMeters.x == 1.25)

    workspace.cancelMatePlacement()
    #expect(workspace.engineResolvedPartPoses[arm]?.positionMeters.x == 0)
    #expect(workspace.engineMates.isEmpty)

    workspace.beginMatePlacement(.fastened)
    workspace.selectMateConnector(
      MateConnectorCandidate(
        id: "arm-origin",
        partID: arm,
        displayName: "Arm Origin",
        featureKind: .origin,
        connector: MateConnectorDefinition()
      )
    )
    workspace.selectMateConnector(
      MateConnectorCandidate(
        id: "base-origin",
        partID: base,
        displayName: "Base Origin",
        featureKind: .origin,
        connector: MateConnectorDefinition()
      )
    )
    for _ in 0..<80 {
      if workspace.matePlacement?.isPreviewing == false { break }
      try await Task.sleep(for: .milliseconds(25))
    }
    workspace.confirmMatePlacement()

    for _ in 0..<80 {
      if !workspace.engineMates.isEmpty { break }
      try await Task.sleep(for: .milliseconds(25))
    }

    let mate = try #require(workspace.engineMates.first)
    #expect(mate.type == "fastened")
    #expect(mate.parentPart == "base")
    #expect(mate.childPart == "arm")
    #expect(mate.controls?.connectors.a?.feature == "base-origin")
    #expect(mate.controls?.connectors.b?.feature == "arm-origin")
    #expect(workspace.matePlacement == nil)
    #expect(workspace.selection == [.joint(JointID(rawValue: mate.selectionKey))])
    #expect(workspace.engineResolvedPartPoses[arm]?.positionMeters.x == 1)

    var edit = EngineMateEditDraft(mate: mate)
    edit.offsetEnabled = true
    edit.offsetTranslationMillimeters = [250, 0, 0]
    edit.flipsPrimaryAxis = true
    edit.isSimulationConnection = false
    let updated = try await workspace.updateEngineMate(mate, with: edit)
    #expect(updated.id == mate.id)
    #expect(updated.controls?.offset.isEnabled == true)
    #expect(updated.controls?.offset.translationMeters == [0.25, 0, 0])
    #expect(updated.controls?.flipsPrimaryAxis == true)
    #expect(updated.controls?.isSimulationConnection == false)
    #expect(workspace.selection == [.joint(JointID(rawValue: mate.selectionKey))])
    #expect(workspace.engineResolvedPartPoses[arm]?.positionMeters.x == 1.25)

    let saved = try await workspace.serializedCharacterText()
    let reopened = try await client.loadCharacter(text: saved)
    #expect(reopened.rig.joints.map(\.name) == ["fastened_1"])
    #expect(reopened.rig.joints.first?.id == "Fastened 1")
    #expect(reopened.rig.joints.first?.controls?.offset.translationMeters == [0.25, 0, 0])
    try await client.release(handle: reopened.handle)
    await workspace.shutdownAnimaCore()
  }

  @Test
  func outputMappingEditsRoundTripThroughCanonicalEngine() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    let workspace = StudioWorkspaceModel(
      startupWorkspace: .hardware,
      animaCoreClient: client,
      resolvesDefaultAnimaCoreClient: false
    )
    await workspace.importAnimaCharacter(
      from: repositoryRoot.appendingPathComponent(
        "examples/six_axis_arm.character.anima"
      )
    )

    let original = try #require(
      workspace.engineOutputs.first { $0.targetPath == "base_yaw.rotation" }
    )
    let target = try #require(
      workspace.hardwareOutputTargets.first { $0.path == original.targetPath }
    )
    var draft = HardwareOutputMappingDraft(mapping: original, target: target)
    draft.channel = 6
    draft.valueAtZero = 160
    draft.valueAtOne = -160

    let saved = try await workspace.saveOutputMapping(
      draft,
      originalChannel: original.channel
    )

    #expect(saved.channel == 6)
    #expect(abs(saved.valueAtZero - (160 * .pi / 180)) < 1e-12)
    #expect(abs(saved.valueAtOne - (-160 * .pi / 180)) < 1e-12)
    #expect(!workspace.engineOutputs.contains { $0.channel == original.channel })

    let canonicalText = try await workspace.serializedCharacterText()
    let reopened = try await client.loadCharacter(text: canonicalText)
    let reopenedMapping = try #require(
      reopened.rig.outputs.first { $0.channel == 6 }
    )
    #expect(reopenedMapping.targetPath == "base_yaw.rotation")
    #expect(reopenedMapping.valueAtZero > reopenedMapping.valueAtOne)
    try await client.release(handle: reopened.handle)

    try await workspace.removeOutputMapping(channel: 6)
    #expect(workspace.engineOutputs.count == 5)
    #expect(!workspace.engineOutputs.contains { $0.targetPath == "base_yaw.rotation" })
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

  @Test
  func draggedPartTransformSurvivesPlayheadRefresh() async throws {
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
    let characterURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "drag-transform-\(UUID().uuidString).character.anima"
    )
    try """
    anima_version: "2.0"
    type: character
    identity:
      name: drag_transform
      display_name: Drag Transform
    parts:
      chassis: {}
      wheel: {}
    """.write(to: characterURL, atomically: true, encoding: .utf8)
    defer {
      try? FileManager.default.removeItem(at: characterURL)
      Task { await workspace.shutdownAnimaCore() }
    }

    await workspace.importAnimaCharacter(from: characterURL)
    let wheel = try #require(workspace.partID(forEngineName: "wheel"))

    // The viewport drag path: guarded setter writes the rest transform.
    workspace.setPartPosition(id: wheel, to: RigVector3(x: 0.4, y: 0, z: 0.25))
    await workspace.flushPendingEnginePartTransformPush()

    // Any later playhead refresh re-resolves poses from the live engine
    // handle. The dragged position must survive it — this is the regression
    // where parts snapped back after a drag.
    await workspace.refreshAnimaCoreFrameAtPlayhead()

    let pose = try #require(workspace.engineResolvedPartPoses[wheel])
    #expect(abs(pose.positionMeters.x - 0.4) < 0.000_1)
    #expect(abs(pose.positionMeters.z - 0.25) < 0.000_1)
    let part = try #require(workspace.project.rig.parts.first { $0.id == wheel })
    #expect(abs(part.positionMeters.x - 0.4) < 0.000_1)
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
