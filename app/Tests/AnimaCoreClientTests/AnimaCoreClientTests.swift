import AnimaCoreClient
import Foundation
import Testing

@Suite(.serialized)
struct AnimaCoreClientTests {
  @Test
  func liveBridgeHandshakeLoadEvaluateReleaseAndShutdown() async throws {
    let repositoryRoot = try repositoryRootURL()
    let python = repositoryRoot.appendingPathComponent(".venv/bin/python")
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: python,
        repositoryRootURL: repositoryRoot
      )
    )

    let hello = try await client.start()
    #expect(hello.engine == "animacore")
    #expect(hello.protocolVersion == 1)
    #expect(hello.capabilities.contains("evaluate"))
    #expect(hello.capabilities.contains("resolve_pose"))
    #expect(hello.capabilities.contains("mate_types"))
    #expect(hello.capabilities.contains("relation_types"))
    #expect(hello.capabilities.contains("serialize_character"))
    #expect(hello.capabilities.contains("forward_kinematics"))
    #expect(hello.capabilities.contains("solve_ik"))

    let mateCatalog = try await client.mateTypes()
    #expect(
      Set(mateCatalog.mateTypes.map(\.type))
        == Set(
          [
            "fastened", "parallel", "prismatic", "revolute",
            "cylindrical", "pin_slot", "planar", "ball", "width", "tangent",
          ]
        )
    )
    let fastenedType = try #require(
      mateCatalog.mateTypes.first { $0.type == "fastened" }
    )
    #expect(fastenedType.label == "Fastened")
    #expect(fastenedType.category == .kinematic)
    #expect(fastenedType.isDrivable)
    #expect(fastenedType.degreeOfFreedomCount == 0)
    #expect(fastenedType.degreesOfFreedom.isEmpty)
    #expect(
      fastenedType.universalControls == [
        "connector_a",
        "connector_b",
        "offset",
        "flip_primary_axis",
        "secondary_axis_rotation",
        "simulation_connection",
      ]
    )

    let relationCatalog = try await client.relationTypes()
    #expect(
      relationCatalog.relationTypes.map(\.kind)
        == [.gear, .rackPinion, .screw, .linear]
    )
    let rackPinionType = try #require(
      relationCatalog.relationTypes.first { $0.kind == .rackPinion }
    )
    #expect(rackPinionType.label == "Rack and pinion")
    #expect(rackPinionType.driverKind == .rotation)
    #expect(rackPinionType.drivenKind == .translation)
    #expect(rackPinionType.ratioField.key == "distance_per_revolution")
    #expect(rackPinionType.ratioField.unit == "mm")
    #expect(rackPinionType.supportsReverse)

    let characterURL =
      repositoryRoot
      .appendingPathComponent("examples/six_axis_arm.character.anima")
    let text = try String(contentsOf: characterURL, encoding: .utf8)
    let loaded = try await client.loadCharacter(text: text)
    #expect(loaded.handle == "rig1")
    #expect(loaded.rig.identity.name == "six_axis_arm")
    #expect(loaded.rig.joints.count == 6)
    #expect(loaded.rig.parts.first?.model == "")
    let baseYaw = try #require(loaded.rig.joints.first)
    let baseYawControls = try #require(baseYaw.controls)
    #expect(baseYaw.id == "Revolute 1")
    #expect(baseYaw.parentPart == "base")
    #expect(baseYaw.childPart == "shoulder")
    #expect(baseYaw.category == .kinematic)
    #expect(baseYaw.degreesOfFreedom.first?.axis == .z)
    #expect(baseYawControls.connectors.a?.feature == "base/top_face")
    #expect(baseYawControls.offset.translationMeters == [0, 0, 0.012])
    #expect(baseYawControls.offset.rotationAxis == .z)
    #expect(abs(baseYawControls.offset.rotationRadians - .pi / 120) < 1e-12)
    guard case .object(let rigDocument) = loaded.rigDocument else {
      Issue.record("load_character.rig must remain a full-fidelity object")
      return
    }
    #expect(rigDocument["clips"] != nil)
    #expect(rigDocument["outputs"] != nil)

    let serialized = try await client.serializeCharacter(rig: loaded.rigDocument)
    #expect(serialized.text.contains("six_axis_arm"))
    let reloaded = try await client.loadCharacter(text: serialized.text)
    #expect(reloaded.rig.identity == loaded.rig.identity)
    #expect(reloaded.rig.parts == loaded.rig.parts)
    #expect(reloaded.rig.joints.map(\.id) == loaded.rig.joints.map(\.id))
    let reserialized = try await client.serializeCharacter(rig: reloaded.rigDocument)
    #expect(reserialized.text.contains("base_yaw.rotation"))

    let rigWithAsset = try AnimaCoreRigDocumentEditor.assigningModel(
      "assets/base.stl",
      toPartNamed: "base",
      in: loaded.rigDocument
    )
    let assetText = try await client.serializeCharacter(rig: rigWithAsset).text
    let assetReloaded = try await client.loadCharacter(text: assetText)
    #expect(assetReloaded.rig.parts.first { $0.name == "base" }?.model == "assets/base.stl")

    let positioned = try AnimaCoreRigDocumentEditor.settingPartTransform(
      named: "base",
      positionMeters: [0.125, -0.25, 0.5],
      rotationEulerRadians: [0.1, -0.2, 0.3],
      in: loaded.rigDocument
    )
    let stateful = try AnimaCoreRigDocumentEditor.settingPartState(
      named: "base",
      suppressed: true,
      grounded: true,
      in: positioned
    )
    let stateText = try await client.serializeCharacter(rig: stateful).text
    let stateReloaded = try await client.loadCharacter(text: stateText)
    let persistedBase = try #require(stateReloaded.rig.parts.first { $0.name == "base" })
    #expect(persistedBase.positionMeters == [0.125, -0.25, 0.5])
    #expect(
      zip(persistedBase.rotationEulerRadians, [0.1, -0.2, 0.3])
        .allSatisfy { abs($0 - $1) < 1e-12 }
    )
    #expect(persistedBase.isSuppressed)
    #expect(persistedBase.isGrounded)

    let emptyText = try await client.serializeCharacter(
      rig: AnimaCoreRigDocumentEditor.emptyCharacter(
        name: "new_character",
        displayName: "New Character"
      )
    ).text
    let emptyReloaded = try await client.loadCharacter(text: emptyText)
    #expect(emptyReloaded.rig.identity.name == "new_character")
    #expect(emptyReloaded.rig.parts.isEmpty)
    let emptyEvaluation = try await client.evaluate(handle: emptyReloaded.handle)
    let emptyPose = try await client.resolvePose(handle: emptyReloaded.handle)
    #expect(emptyEvaluation.degreesOfFreedom.isEmpty)
    #expect(emptyPose.parts.isEmpty)

    let evaluation = try await client.evaluate(
      handle: loaded.handle,
      clip: "pick",
      timeSeconds: 1
    )
    #expect(evaluation.degreesOfFreedom["base_yaw.rotation"] == .pi / 3)
    #expect(evaluation.channelsByIndex.keys.sorted() == [0, 1, 2, 3, 4, 5])
    #expect(evaluation.limitViolations.isEmpty)

    let resolvedPose = try await client.resolvePose(
      handle: loaded.handle,
      clip: "pick",
      timeSeconds: 1
    )
    #expect(Set(resolvedPose.parts.keys) == Set(loaded.rig.parts.map(\.name)))
    #expect(resolvedPose.parts["base"]?.position == [0, 0, 0])
    #expect(resolvedPose.parts["base"]?.orientation == [0, 0, 0, 1])

    try await client.release(handle: loaded.handle)
    try await client.release(handle: reloaded.handle)
    try await client.release(handle: assetReloaded.handle)
    try await client.release(handle: stateReloaded.handle)
    try await client.release(handle: emptyReloaded.handle)
    await client.shutdown()
  }

  @Test
  func articulatedArmDecodesAndRunsForwardAndInverseKinematics() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    defer { Task { await client.shutdown() } }
    let text = try String(
      contentsOf: repositoryRoot.appendingPathComponent(
        "examples/six_axis_arm_dh.character.anima"
      ),
      encoding: .utf8
    )

    let loaded = try await client.loadCharacter(text: text)
    let chain = try #require(loaded.rig.kinematicChain)
    #expect(chain.name == "arm")
    #expect(chain.joints.count == 6)
    #expect(chain.joints.allSatisfy { $0.jointType == .revolute })
    #expect(chain.joints[1].neutral == -.pi / 3)
    #expect(chain.toolPart == "gripper")

    let seed = Dictionary(uniqueKeysWithValues: chain.joints.map { ($0.name, $0.neutral) })
    let forward = try await client.forwardKinematics(
      handle: loaded.handle,
      jointValues: seed
    )
    #expect(forward.linkFrames.count == chain.joints.count)
    #expect(forward.toolPose.position.count == 3)
    #expect(forward.toolPose.orientation.count == 4)

    let inverse = try await client.solveInverseKinematics(
      handle: loaded.handle,
      targetPose: forward.toolPose,
      seed: seed
    )
    #expect(inverse.reached)
    #expect(inverse.jointValues.keys.sorted() == seed.keys.sorted())
    #expect(inverse.positionErrorMeters < 0.001)
    #expect(inverse.orientationErrorRadians < 0.01)

    try await client.release(handle: loaded.handle)
  }

  @Test
  func rigDocumentEditorAddsAndAssignsSafePartModelReferences() throws {
    let source: AnimaCoreJSONValue = .object([
      "identity": .object(["name": .string("assembly")]),
      "parts": .array([
        .object([
          "name": .string("base"),
          "parent": .null,
          "model": .string(""),
          "model_node": .null,
          "description": .string(""),
        ])
      ]),
      "joints": .array([]),
      "parameters": .array([]),
      "clips": .array([]),
      "outputs": .array([]),
      "relations": .array([]),
    ])

    let assigned = try AnimaCoreRigDocumentEditor.assigningModel(
      "assets/base.stl",
      toPartNamed: "base",
      in: source
    )
    let addition = try AnimaCoreRigDocumentEditor.addingPart(
      suggestedName: "Pan/Tilt Head",
      model: "assets/head.usdz",
      modelNode: "Robot/Head",
      to: assigned
    )

    #expect(addition.partName == "pan_tilt_head")
    guard case .object(let root) = addition.document,
      case .array(let parts) = root["parts"]
    else {
      Issue.record("Edited rig must retain a parts array")
      return
    }
    #expect(parts.count == 2)
    guard case .object(let base) = parts[0], case .object(let head) = parts[1] else {
      Issue.record("Every edited part must remain an object")
      return
    }
    #expect(base["model"] == .string("assets/base.stl"))
    #expect(head["model"] == .string("assets/head.usdz"))
    #expect(head["model_node"] == .string("Robot/Head"))
  }

  @Test
  func rigDocumentEditorBuildsEmptyRigidPartsCharacterDTO() {
    let document = AnimaCoreRigDocumentEditor.emptyCharacter(
      name: "walle",
      displayName: "WALL-E"
    )
    guard case .object(let root) = document,
      case .object(let identity) = root["identity"],
      case .array(let parts) = root["parts"]
    else {
      Issue.record("Empty character must be a full engine rig DTO")
      return
    }
    #expect(identity["name"] == .string("walle"))
    #expect(identity["display_name"] == .string("WALL-E"))
    #expect(parts.isEmpty)
    #expect(root["joints"] == .array([]))
    #expect(root["clips"] == .array([]))
  }

  @Test
  func rigDocumentEditorRejectsEscapingAndAbsoluteModelPaths() {
    let source: AnimaCoreJSONValue = .object(["parts": .array([])])
    for unsafe in ["../head.stl", "/tmp/head.stl", "assets/../head.stl"] {
      #expect(throws: AnimaCoreRigDocumentEditingError.self) {
        _ = try AnimaCoreRigDocumentEditor.addingPart(
          suggestedName: "head",
          model: unsafe,
          to: source
        )
      }
    }
  }

  @Test
  func loadedCharacterCarriesEngineDescribedRelations() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    defer { Task { await client.shutdown() } }

    let text = try String(
      contentsOf: repositoryRoot.appendingPathComponent(
        "examples/rc_car.character.anima"),
      encoding: .utf8
    )
    let loaded = try await client.loadCharacter(text: text)
    let relation = try #require(loaded.rig.relations.first)

    #expect(relation.kind == .rackPinion)
    #expect(relation.driver == "steering.rotation")
    #expect(relation.driven == "rack.travel")
    #expect(relation.ratio == 0.02)
    #expect(!relation.isReversed)
    #expect(relation.magnitude == 0.02)
    #expect(abs(relation.ratioFieldValue - 125.663_706) < 0.000_001)
    #expect(relation.display == ["pinion_diameter_mm": 40])
  }

  @Test
  func fastenedMateUsesStableIdentityAndUniversalControls() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    defer { Task { await client.shutdown() } }

    let text = """
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

    let loaded = try await client.loadCharacter(text: text)
    let mate = try #require(loaded.rig.joints.first)
    let controls = try #require(mate.controls)
    #expect(mate.id == "Fastened 33")
    #expect(mate.selectionKey == "Fastened 33")
    #expect(mate.name == "fixed_lid")
    #expect(mate.type == "fastened")
    #expect(mate.category == .kinematic)
    #expect(mate.degreesOfFreedom.isEmpty)
    #expect(controls.connectors.a?.part == "base")
    #expect(controls.connectors.b?.isFlipped == true)
    #expect(controls.offset.translationMeters == [0.001, 0.002, 0.003])
    #expect(controls.offset.rotationAxis == .x)
    #expect(abs(controls.offset.rotationRadians - .pi / 12) < 1e-12)
    #expect(controls.flipsPrimaryAxis)
    #expect(controls.secondaryAxisRotationDegrees == 90)
    #expect(!controls.isSimulationConnection)
  }

  @Test
  func geometryMateDescriptorsKeepWidthAndTangentDistinct() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    defer { Task { await client.shutdown() } }

    let text = try String(
      contentsOf: repositoryRoot.appendingPathComponent(
        "examples/geometry_mates_demo.character.anima"),
      encoding: .utf8
    )
    let catalog = try await client.mateTypes()
    let loaded = try await client.loadCharacter(text: text)
    let widthType = try #require(catalog.mateTypes.first { $0.type == "width" })
    let tangentType = try #require(catalog.mateTypes.first { $0.type == "tangent" })
    let width = try #require(loaded.rig.joints.first { $0.type == "width" })
    let tangent = try #require(loaded.rig.joints.first { $0.type == "tangent" })

    #expect(widthType.category == .geometryConstraint)
    #expect(!widthType.isDrivable)
    #expect(!widthType.universalControls.contains("offset"))
    #expect(width.controls != nil)
    #expect(width.tangent == nil)
    #expect(width.degreesOfFreedom.isEmpty)

    #expect(tangentType.category == .geometryConstraint)
    #expect(!tangentType.isDrivable)
    #expect(tangent.controls == nil)
    #expect(tangent.tangent?.selectionA.isEmpty == false)
    #expect(tangent.tangent?.selectionB.isEmpty == false)
    #expect(tangent.tangent?.propagatesAcrossTangentFaces == true)
    #expect(tangent.degreesOfFreedom.isEmpty)
  }

  @Test
  func formatErrorPreservesEnginePath() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    defer { Task { await client.shutdown() } }

    let broken = """
      anima_version: "2.0"
      type: character
      identity: { name: broken }
      parts: { a: {}, b: { parent: a } }
      joints:
        bad:
          type: not_a_joint
          parent: a
          child: b
          dofs: {}
      """

    do {
      _ = try await client.loadCharacter(text: broken)
      Issue.record("Expected the engine to reject the invalid mate type")
    } catch let AnimaCoreClientError.remote(error) {
      #expect(error.code == "format_error")
      #expect(error.path == "joints.bad.type")
      #expect(error.errorDescription?.contains("joints.bad.type") == true)
    }
  }

  @Test
  func launchResolverFindsRepositoryVirtualEnvironment() throws {
    let appDirectory = try repositoryRootURL().appendingPathComponent("app")
    let configuration = try AnimaCoreLaunchConfiguration.resolved(
      environment: [:],
      currentDirectoryURL: appDirectory,
      bundleURL: appDirectory
    )

    #expect(configuration.executableURL.lastPathComponent == "python")
    #expect(configuration.arguments == ["-m", "animacore.bridge"])
    #expect(configuration.currentDirectoryURL == appDirectory.deletingLastPathComponent())
  }

  @Test
  func launchResolverPrefersBundledPythonRuntime() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bundle = temporaryRoot.appendingPathComponent("Anima Studio.app", isDirectory: true)
    let helper = bundle.appendingPathComponent("Contents/Helpers/animacore-python")
    let pythonHome =
      bundle.appendingPathComponent("Contents/Frameworks/Python.framework/Versions/Current")
    let pythonPath = bundle.appendingPathComponent("Contents/Resources/AnimaCorePython")
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    try FileManager.default.createDirectory(
      at: helper.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: pythonHome, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: pythonPath, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/sh"), to: helper)

    let configuration = try AnimaCoreLaunchConfiguration.resolved(
      environment: ["ANIMA_TEST": "yes"],
      currentDirectoryURL: temporaryRoot,
      bundleURL: bundle
    )

    #expect(configuration.executableURL == helper)
    #expect(configuration.arguments == ["-m", "animacore.bridge"])
    #expect(configuration.currentDirectoryURL?.path == pythonPath.path)
    #expect(configuration.environment?["PYTHONHOME"] == pythonHome.path)
    #expect(configuration.environment?["PYTHONPATH"] == pythonPath.path)
    #expect(configuration.environment?["PYTHONNOUSERSITE"] == "1")
    #expect(configuration.environment?["ANIMA_TEST"] == "yes")
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
