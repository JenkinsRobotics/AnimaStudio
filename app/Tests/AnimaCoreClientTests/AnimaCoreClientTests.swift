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
    #expect(hello.capabilities.contains("preview_mate"))
    #expect(hello.capabilities.contains("add_mate"))
    #expect(hello.capabilities.contains("update_mate"))
    #expect(hello.capabilities.contains("remove_mate"))
    #expect(hello.capabilities.contains("relation_types"))
    #expect(hello.capabilities.contains("add_relation"))
    #expect(hello.capabilities.contains("update_relation"))
    #expect(hello.capabilities.contains("remove_relation"))
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
    let baseYawOutput = try #require(
      loaded.rig.outputs.first { $0.targetPath == "base_yaw.rotation" }
    )
    #expect(abs(baseYawOutput.valueAtZero - (-170 * .pi / 180)) < 1e-12)
    #expect(abs(baseYawOutput.valueAtOne - (170 * .pi / 180)) < 1e-12)
    let invertedShoulderOutput = try #require(
      loaded.rig.outputs.first { $0.targetPath == "shoulder_pitch.rotation" }
    )
    #expect(invertedShoulderOutput.valueAtZero > invertedShoulderOutput.valueAtOne)

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

    let mateAuthoring = try await client.loadCharacter(
      text: """
        anima_version: "2.0"
        type: character
        identity:
          name: bridge_mate_authoring
          display_name: Bridge Mate Authoring
        parts:
          base:
            grounded: true
          arm: {}
          tool: {}
        """
    )
    let fastened = AnimaCoreJSONValue.object([
      "id": .string("Fastened 1"),
      "name": .string("fastened_1"),
      "type": .string("fastened"),
      "parent_part": .string("base"),
      "child_part": .string("arm"),
      "dofs": .array([]),
    ])
    let previewedMate = try await client.previewMate(
      handle: mateAuthoring.handle,
      joint: fastened
    )
    #expect(previewedMate.parts["base"]?.position == [0, 0, 0])
    #expect(previewedMate.parts["arm"]?.position == [0, 0, 0])
    // The preview did not mutate the handle: this first add still succeeds.
    let addedMate = try await client.addMate(
      handle: mateAuthoring.handle,
      joint: fastened
    )
    #expect(addedMate.handle == mateAuthoring.handle)
    #expect(addedMate.rig.joints.map(\.name) == ["fastened_1"])
    #expect(addedMate.rig.joints.first?.id == "Fastened 1")
    guard case .object(let addedRigDocument) = addedMate.rigDocument else {
      Issue.record("add_mate must return a full-fidelity rig document")
      return
    }
    #expect(addedRigDocument["joints"] != nil)

    let revolute = AnimaCoreJSONValue.object([
      "id": .string("Fastened 1"),
      "name": .string("fastened_1"),
      "type": .string("revolute"),
      "parent_part": .string("base"),
      "child_part": .string("arm"),
      "dofs": .array([
        .object([
          "name": .string("rotation"),
          "kind": .string("rotation"),
          "neutral": .number(0),
          "axis_vector": .array([.number(0), .number(0), .number(1)]),
        ])
      ]),
    ])
    let updatedMate = try await client.updateMate(
      handle: mateAuthoring.handle,
      joint: revolute
    )
    #expect(updatedMate.rig.joints.first?.type == "revolute")
    #expect(updatedMate.rig.joints.first?.degreesOfFreedom.first?.axis == .z)
    let mutationEvaluation = try await client.evaluate(handle: mateAuthoring.handle)
    #expect(mutationEvaluation.degreesOfFreedom["fastened_1.rotation"] == 0)

    let toolJoint = AnimaCoreJSONValue.object([
      "id": .string("Revolute 2"),
      "name": .string("tool_joint"),
      "type": .string("revolute"),
      "parent_part": .string("arm"),
      "child_part": .string("tool"),
      "dofs": .array([
        .object([
          "name": .string("rotation"),
          "kind": .string("rotation"),
          "neutral": .number(0),
          "axis_vector": .array([.number(0), .number(0), .number(1)]),
        ])
      ]),
    ])
    _ = try await client.addMate(handle: mateAuthoring.handle, joint: toolJoint)

    let gear = AnimaCoreJSONValue.object([
      "kind": .string("gear"),
      "driver": .string("fastened_1.rotation"),
      "driven": .string("tool_joint.rotation"),
      "ratio": .number(-2),
      "offset": .number(0.1),
      "display": .object([
        "driver_teeth": .number(12),
        "driven_teeth": .number(24),
      ]),
    ])
    let addedRelation = try await client.addRelation(
      handle: mateAuthoring.handle,
      relation: gear
    )
    let createdGear = try #require(addedRelation.rig.relations.first)
    #expect(createdGear.kind == .gear)
    #expect(createdGear.driver == "fastened_1.rotation")
    #expect(createdGear.driven == "tool_joint.rotation")
    #expect(createdGear.ratio == -2)
    #expect(createdGear.offset == 0.1)
    #expect(createdGear.display == ["driver_teeth": 12, "driven_teeth": 24])

    guard case .object(var updatedGearObject) = gear else {
      Issue.record("Relation fixture must be an object")
      return
    }
    updatedGearObject["ratio"] = .number(3)
    updatedGearObject["offset"] = .number(-0.2)
    let updatedRelation = try await client.updateRelation(
      handle: mateAuthoring.handle,
      relation: .object(updatedGearObject)
    )
    let editedGear = try #require(updatedRelation.rig.relations.first)
    #expect(editedGear.ratio == 3)
    #expect(editedGear.offset == -0.2)

    let removedRelation = try await client.removeRelation(
      handle: mateAuthoring.handle,
      driven: "tool_joint.rotation"
    )
    #expect(removedRelation.rig.relations.isEmpty)

    let removedMate = try await client.removeMate(
      handle: mateAuthoring.handle,
      name: "fastened_1"
    )
    #expect(removedMate.rig.joints.map(\.name) == ["tool_joint"])

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
    try await client.release(handle: mateAuthoring.handle)
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
  func rigDocumentEditorRemovesPartsAndDependentSemantics() throws {
    let source: AnimaCoreJSONValue = .object([
      "identity": .object(["name": .string("assembly")]),
      "parts": .array([
        .object(["name": .string("base"), "parent": .null]),
        .object(["name": .string("arm"), "parent": .string("base")]),
        .object(["name": .string("tool"), "parent": .string("arm")]),
      ]),
      "joints": .array([
        .object([
          "name": .string("arm_joint"),
          "parent_part": .string("base"),
          "child_part": .string("arm"),
          "dofs": .array([.object(["path": .string("arm_joint.rotation")])]),
        ])
      ]),
      "parameters": .array([]),
      "clips": .array([
        .object([
          "name": .string("move"),
          "keyframes": .array([
            .object([
              "time_s": .number(0),
              "values": .object([
                "arm_joint.rotation": .number(1),
                "expression": .number(0.5),
              ]),
            ])
          ]),
        ])
      ]),
      "outputs": .array([
        .object(["dof_path": .string("arm_joint.rotation"), "channel": .number(1)])
      ]),
      "relations": .array([
        .object([
          "kind": .string("gear"),
          "driver": .string("arm_joint.rotation"),
          "driven": .string("other.rotation"),
        ])
      ]),
    ])

    let edited = try AnimaCoreRigDocumentEditor.removingParts(named: ["arm"], from: source)
    guard case .object(let root) = edited,
      case .array(let parts) = root["parts"],
      case .array(let joints) = root["joints"],
      case .array(let outputs) = root["outputs"],
      case .array(let relations) = root["relations"],
      case .array(let clips) = root["clips"],
      case .object(let clip) = clips.first,
      case .array(let keyframes) = clip["keyframes"],
      case .object(let keyframe) = keyframes.first,
      case .object(let values) = keyframe["values"]
    else {
      Issue.record("Removal must retain a valid full-fidelity rig DTO")
      return
    }
    #expect(parts.count == 2)
    #expect(joints.isEmpty)
    #expect(outputs.isEmpty)
    #expect(relations.isEmpty)
    #expect(values == ["expression": .number(0.5)])
    guard let lastPart = parts.last, case .object(let tool) = lastPart else {
      Issue.record("Remaining tool part must be an object")
      return
    }
    #expect(tool["parent"] == .null)
  }

  @Test
  func rigDocumentEditorRemovesMatesRelationsAndTheirDependentValues() throws {
    let source: AnimaCoreJSONValue = .object([
      "parts": .array([]),
      "joints": .array([
        .object([
          "id": .string("Revolute 1"),
          "name": .string("head_pan"),
          "dofs": .array([.object(["path": .string("head_pan.rotation")])]),
        ]),
        .object(["name": .string("jaw")]),
      ]),
      "relations": .array([
        .object([
          "kind": .string("gear"),
          "driver": .string("head_pan.rotation"),
          "driven": .string("jaw.rotation"),
        ]),
        .object([
          "kind": .string("linear"),
          "driver": .string("slider.travel"),
          "driven": .string("lift.travel"),
        ]),
      ]),
      "outputs": .array([
        .object(["dof_path": .string("head_pan.rotation")]),
        .object(["dof_path": .string("jaw.rotation")]),
      ]),
      "clips": .array([
        .object([
          "keyframes": .array([
            .object([
              "values": .object([
                "head_pan.rotation": .number(0.5),
                "jaw.rotation": .number(0.2),
              ])
            ])
          ])
        ])
      ]),
    ])

    let withoutMate = try AnimaCoreRigDocumentEditor.removingJoint(
      identifiedBy: "Revolute 1",
      from: source
    )
    guard case .object(let mateRoot) = withoutMate,
      case .array(let joints) = mateRoot["joints"],
      case .array(let outputs) = mateRoot["outputs"],
      case .array(let relations) = mateRoot["relations"],
      case .array(let clips) = mateRoot["clips"],
      case .object(let clip) = clips.first,
      case .array(let keyframes) = clip["keyframes"],
      case .object(let keyframe) = keyframes.first,
      case .object(let values) = keyframe["values"]
    else {
      Issue.record("Mate deletion must preserve the remaining full-fidelity DTO")
      return
    }
    #expect(joints.count == 1)
    #expect(outputs.count == 1)
    #expect(relations.count == 1)
    #expect(values == ["jaw.rotation": .number(0.2)])

    let retainedRelation = try AnimaCoreRigDocumentEditor.relationDocument(
      kind: .linear,
      driver: "slider.travel",
      driven: "lift.travel",
      from: withoutMate
    )
    #expect(
      retainedRelation
        == .object([
          "kind": .string("linear"),
          "driver": .string("slider.travel"),
          "driven": .string("lift.travel"),
        ])
    )
    #expect(
      throws: AnimaCoreRigDocumentEditingError.unknownRelation(
        "gear:missing.rotation->missing.travel"
      )
    ) {
      _ = try AnimaCoreRigDocumentEditor.relationDocument(
        kind: .gear,
        driver: "missing.rotation",
        driven: "missing.travel",
        from: withoutMate
      )
    }

    let retainedJaw = try AnimaCoreRigDocumentEditor.jointDocument(
      identifiedBy: "jaw",
      from: source
    )
    #expect(retainedJaw == .object(["name": .string("jaw")]))
    #expect(throws: AnimaCoreRigDocumentEditingError.unknownJoint("missing")) {
      _ = try AnimaCoreRigDocumentEditor.jointDocument(
        identifiedBy: "missing",
        from: source
      )
    }

    let withoutRelation = try AnimaCoreRigDocumentEditor.removingRelation(
      kind: .linear,
      driver: "slider.travel",
      driven: "lift.travel",
      from: withoutMate
    )
    guard case .object(let relationRoot) = withoutRelation,
      case .array(let remainingRelations) = relationRoot["relations"]
    else {
      Issue.record("Relation deletion must retain a relation array")
      return
    }
    #expect(remainingRelations.isEmpty)
  }

  @Test
  func rigDocumentEditorAddsEditsSortsAndRemovesOutputMappings() throws {
    let source: AnimaCoreJSONValue = .object([
      "parts": .array([]),
      "outputs": .array([
        .object([
          "dof_path": .string("jaw.rotation"),
          "channel": .number(2),
          "value_at_zero": .number(-0.5),
          "value_at_one": .number(0.5),
          "future_field": .string("old"),
        ])
      ]),
    ])

    let added = try AnimaCoreRigDocumentEditor.settingOutputMapping(
      originalChannel: nil,
      targetPath: "head.rotation",
      channel: 0,
      valueAtZero: -1,
      valueAtOne: 1,
      in: source
    )
    let edited = try AnimaCoreRigDocumentEditor.settingOutputMapping(
      originalChannel: 2,
      targetPath: "jaw.rotation",
      channel: 3,
      valueAtZero: 0.75,
      valueAtOne: -0.75,
      in: added
    )
    guard case .object(let root) = edited,
      case .array(let outputs) = root["outputs"],
      case .object(let first) = outputs.first,
      case .object(let second) = outputs.last
    else {
      Issue.record("Output editing must retain an object array")
      return
    }
    #expect(first["channel"] == .number(0))
    #expect(first["dof_path"] == .string("head.rotation"))
    #expect(second["channel"] == .number(3))
    #expect(second["value_at_zero"] == .number(0.75))
    #expect(second["value_at_one"] == .number(-0.75))
    #expect(second["future_field"] == .string("old"))

    #expect(
      throws: AnimaCoreRigDocumentEditingError.duplicateOutputChannel(0)
    ) {
      try AnimaCoreRigDocumentEditor.settingOutputMapping(
        originalChannel: 3,
        targetPath: "jaw.rotation",
        channel: 0,
        valueAtZero: -1,
        valueAtOne: 1,
        in: edited
      )
    }

    let removed = try AnimaCoreRigDocumentEditor.removingOutput(
      channel: 0,
      from: edited
    )
    guard case .object(let removedRoot) = removed,
      case .array(let remaining) = removedRoot["outputs"]
    else {
      Issue.record("Output removal must retain the outputs array")
      return
    }
    #expect(remaining.count == 1)
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
