import AnimaCoreClient
import AnimaModel
import Foundation
import RealityKitViewport
import Testing

@testable import AnimaStudioUI

struct EngineMateAuthoringTests {
  @Test
  func fastenedDraftMapsFixedAndMovingConnectorFramesWithoutInventingDofs() throws {
    let type = try mateType(
      type: "fastened",
      label: "Fastened",
      dofs: []
    )
    let draft = try EngineMateAuthoring.makeDraft(
      kind: .fastened,
      type: type,
      movingPartName: "arm",
      movingConnector: candidate(
        id: "arm-hole",
        partID: PartID(),
        origin: RigVector3(x: 0.1, y: 0.2, z: 0.3)
      ),
      fixedPartName: "base",
      fixedConnector: candidate(
        id: "base-hole",
        partID: PartID(),
        origin: RigVector3(x: -0.1, y: 0, z: 0.4)
      ),
      existingMateNames: []
    )

    #expect(draft.name == "fastened_1")
    #expect(draft.trackingID == "Fastened 1")
    let document = try #require(draft.document.objectValue)
    #expect(document["type"] == AnimaCoreJSONValue.string("fastened"))
    #expect(document["parent_part"] == AnimaCoreJSONValue.string("base"))
    #expect(document["child_part"] == AnimaCoreJSONValue.string("arm"))
    #expect(document["dofs"] == AnimaCoreJSONValue.array([]))
    let controls = try #require(document["controls"]?.objectValue)
    let connectors = try #require(controls["connectors"]?.objectValue)
    let fixed = try #require(connectors["a"]?.objectValue)
    let moving = try #require(connectors["b"]?.objectValue)
    #expect(fixed["part"] == AnimaCoreJSONValue.string("base"))
    #expect(fixed["feature"] == AnimaCoreJSONValue.string("base-hole"))
    #expect(moving["part"] == AnimaCoreJSONValue.string("arm"))
    #expect(moving["feature"] == AnimaCoreJSONValue.string("arm-hole"))
  }

  @Test
  func revoluteAndSliderDofsComeFromTheEngineCatalog() throws {
    let revolute = try mateType(
      type: "revolute",
      label: "Revolute",
      dofs: [("rotation", "rotation", "radians", "z")]
    )
    let slider = try mateType(
      type: "prismatic",
      label: "Slider",
      dofs: [("translation", "translation", "meters", "z")]
    )
    let source = candidate(
      id: "moving",
      partID: PartID(),
      origin: RigVector3()
    )
    let target = candidate(
      id: "fixed",
      partID: PartID(),
      origin: RigVector3()
    )

    let revoluteDraft = try EngineMateAuthoring.makeDraft(
      kind: .revolute,
      type: revolute,
      movingPartName: "moving",
      movingConnector: source,
      fixedPartName: "fixed",
      fixedConnector: target,
      existingMateNames: ["revolute_1"]
    )
    let sliderDraft = try EngineMateAuthoring.makeDraft(
      kind: .slider,
      type: slider,
      movingPartName: "moving",
      movingConnector: source,
      fixedPartName: "fixed",
      fixedConnector: target,
      existingMateNames: []
    )

    #expect(revoluteDraft.name == "revolute_2")
    #expect(
      revoluteDraft.document.dofDocuments.first?["kind"]
        == AnimaCoreJSONValue.string("rotation")
    )
    #expect(
      revoluteDraft.document.dofDocuments.first?["axis_vector"]
        == AnimaCoreJSONValue.array([
          AnimaCoreJSONValue.number(0),
          AnimaCoreJSONValue.number(0),
          AnimaCoreJSONValue.number(1),
        ])
    )
    #expect(
      sliderDraft.document.objectValue?["type"]
        == AnimaCoreJSONValue.string("prismatic")
    )
    #expect(
      sliderDraft.document.dofDocuments.first?["kind"]
        == AnimaCoreJSONValue.string("translation")
    )
  }

  @Test
  func allKinematicMatesUseTheTwoConnectorFlow() {
    for kind in MateCreationToolKind.allCases where kind != .width && kind != .tangent {
      #expect(kind.supportsTwoConnectorAuthoring)
    }
    #expect(!MateCreationToolKind.width.supportsTwoConnectorAuthoring)
    #expect(!MateCreationToolKind.tangent.supportsTwoConnectorAuthoring)
  }

  @Test
  func placementOptionsAreWrittenInEngineNativeUnits() throws {
    let type = try mateType(
      type: "fastened",
      label: "Fastened",
      dofs: []
    )
    let draft = try EngineMateAuthoring.makeDraft(
      kind: .fastened,
      type: type,
      movingPartName: "moving",
      movingConnector: candidate(
        id: "moving-edge",
        partID: PartID(),
        origin: RigVector3()
      ),
      fixedPartName: "fixed",
      fixedConnector: candidate(
        id: "fixed-axis",
        partID: PartID(),
        origin: RigVector3()
      ),
      existingMateNames: [],
      options: EngineMatePlacementOptions(
        connectorAFlipped: true,
        connectorBFlipped: false,
        offsetEnabled: true,
        offsetTranslationMillimeters: [10, -20, 30],
        offsetRotationAxis: .y,
        offsetRotationDegrees: 90,
        flipsPrimaryAxis: true,
        secondaryAxisRotationDegrees: 180,
        isSimulationConnection: false
      )
    )

    let document = try #require(draft.document.objectValue)
    let controls = try #require(document["controls"]?.objectValue)
    let connectors = try #require(controls["connectors"]?.objectValue)
    #expect(connectors["a"]?.objectValue?["flipped"] == .bool(true))
    #expect(connectors["b"]?.objectValue?["flipped"] == .bool(false))
    let offset = try #require(controls["offset"]?.objectValue)
    #expect(offset["enabled"] == .bool(true))
    #expect(offset["translation_m"] == .array([.number(0.01), .number(-0.02), .number(0.03)]))
    #expect(offset["rotation_axis"] == .string("y"))
    #expect(abs(try #require(offset["rotation_radians"]?.numberValue) - .pi / 2) < 1e-12)
    #expect(controls["flip_primary_axis"] == .bool(true))
    #expect(controls["secondary_axis_rotation_deg"] == .number(180))
    #expect(controls["simulation_connection"] == .bool(false))
  }

  @Test
  func editDraftConvertsDisplayUnitsAndPreservesUnknownEngineFields() throws {
    let mate = try editableRevoluteMate()
    var edit = EngineMateEditDraft(mate: mate)
    edit.connectorAFlipped = true
    edit.connectorBFlipped = false
    edit.offsetEnabled = true
    edit.offsetTranslationMillimeters = [10, -20, 30]
    edit.offsetRotationAxis = .y
    edit.offsetRotationDegrees = 90
    edit.flipsPrimaryAxis = true
    edit.secondaryAxisRotationDegrees = 45
    edit.isSimulationConnection = false
    edit.degreesOfFreedom[0].minimum = -30
    edit.degreesOfFreedom[0].maximum = 60
    edit.degreesOfFreedom[0].neutral = 15

    let edited = try edit.applying(to: editableRevoluteDocument())
    let joint = try #require(edited.objectValue)
    #expect(joint["description"] == .string("Preserve me"))
    #expect(joint["future_engine_field"] == .string("still here"))
    let controls = try #require(joint["controls"]?.objectValue)
    let connectors = try #require(controls["connectors"]?.objectValue)
    let connectorA = try #require(connectors["a"]?.objectValue)
    let connectorB = try #require(connectors["b"]?.objectValue)
    #expect(connectorA["flipped"] == .bool(true))
    #expect(connectorB["flipped"] == .bool(false))
    let offset = try #require(controls["offset"]?.objectValue)
    #expect(offset["translation_m"] == .array([.number(0.01), .number(-0.02), .number(0.03)]))
    #expect(offset["rotation_axis"] == .string("y"))
    #expect(abs(try #require(offset["rotation_radians"]?.numberValue) - .pi / 2) < 1e-12)
    #expect(controls["flip_primary_axis"] == .bool(true))
    #expect(controls["secondary_axis_rotation_deg"] == .number(45))
    #expect(controls["simulation_connection"] == .bool(false))

    let degreeOfFreedom = try #require(edited.dofDocuments.first)
    #expect(degreeOfFreedom["description"] == .string("Preserve this too"))
    #expect(degreeOfFreedom["axis_vector"] == .array([.number(0), .number(0), .number(1)]))
    #expect(abs(try #require(degreeOfFreedom["min"]?.numberValue) + .pi / 6) < 1e-12)
    #expect(abs(try #require(degreeOfFreedom["max"]?.numberValue) - .pi / 3) < 1e-12)
    #expect(abs(try #require(degreeOfFreedom["neutral"]?.numberValue) - .pi / 12) < 1e-12)
  }

  @Test
  func editDraftRejectsInvertedLimitsBeforeCallingTheEngine() throws {
    var edit = EngineMateEditDraft(mate: try editableRevoluteMate())
    edit.degreesOfFreedom[0].minimum = 40
    edit.degreesOfFreedom[0].maximum = -10

    #expect(edit.validationMessage?.contains("revolute_1.rotation") == true)
    #expect(throws: EngineMateAuthoringError.self) {
      _ = try edit.applying(to: editableRevoluteDocument())
    }
  }

  private func mateType(
    type: String,
    label: String,
    dofs: [(String, String, String, String)]
  ) throws -> AnimaCoreMateTypeSummary {
    let dofJSON = dofs.map { name, kind, unit, axis in
      """
      {"name":"\(name)","kind":"\(kind)","unit":"\(unit)","axis":"\(axis)"}
      """
    }.joined(separator: ",")
    let data = Data(
      """
      {
        "type":"\(type)",
        "label":"\(label)",
        "category":"kinematic",
        "drivable":true,
        "dof_count":\(dofs.count),
        "universal_controls":[
          "connector_a","connector_b","offset","flip_primary_axis",
          "secondary_axis_rotation","simulation_connection"
        ],
        "dofs":[\(dofJSON)]
      }
      """.utf8
    )
    return try JSONDecoder().decode(AnimaCoreMateTypeSummary.self, from: data)
  }

  private func candidate(
    id: String,
    partID: PartID,
    origin: RigVector3
  ) -> MateConnectorCandidate {
    MateConnectorCandidate(
      id: id,
      partID: partID,
      displayName: id,
      featureKind: .faceCenter,
      connector: MateConnectorDefinition(originMeters: origin)
    )
  }

  private func editableRevoluteMate() throws -> AnimaCoreJointSummary {
    try JSONDecoder().decode(
      AnimaCoreJointSummary.self,
      from: Data(
        """
        {
          "id":"Revolute 1",
          "name":"revolute_1",
          "type":"revolute",
          "category":"kinematic",
          "parent_part":"base",
          "child_part":"arm",
          "controls":{
            "connectors":{
              "a":{"part":"base","origin_m":[0,0,0],"primary_axis":[0,0,1],"secondary_axis":[1,0,0],"flipped":false,"feature":"base"},
              "b":{"part":"arm","origin_m":[0,0,0],"primary_axis":[0,0,1],"secondary_axis":[1,0,0],"flipped":true,"feature":"arm"}
            },
            "offset":{"enabled":false,"translation_m":[0,0,0],"rotation_axis":"z","rotation_radians":0},
            "flip_primary_axis":false,
            "secondary_axis_rotation_deg":0,
            "simulation_connection":true
          },
          "dofs":[{"path":"revolute_1.rotation","kind":"rotation","unit":"radians","axis":"z","min":-1.57,"max":1.57,"neutral":0}]
        }
        """.utf8
      )
    )
  }

  private func editableRevoluteDocument() -> AnimaCoreJSONValue {
    .object([
      "id": .string("Revolute 1"),
      "name": .string("revolute_1"),
      "type": .string("revolute"),
      "category": .string("kinematic"),
      "parent_part": .string("base"),
      "child_part": .string("arm"),
      "description": .string("Preserve me"),
      "future_engine_field": .string("still here"),
      "controls": .object([
        "connectors": .object([
          "a": .object([
            "part": .string("base"),
            "flipped": .bool(false),
          ]),
          "b": .object([
            "part": .string("arm"),
            "flipped": .bool(true),
          ]),
        ]),
        "offset": .object([
          "enabled": .bool(false),
          "translation_m": .array([.number(0), .number(0), .number(0)]),
          "rotation_axis": .string("z"),
          "rotation_radians": .number(0),
        ]),
        "flip_primary_axis": .bool(false),
        "secondary_axis_rotation_deg": .number(0),
        "simulation_connection": .bool(true),
      ]),
      "dofs": .array([
        .object([
          "path": .string("revolute_1.rotation"),
          "name": .string("rotation"),
          "kind": .string("rotation"),
          "axis_vector": .array([.number(0), .number(0), .number(1)]),
          "description": .string("Preserve this too"),
          "min": .number(-1.57),
          "max": .number(1.57),
          "neutral": .number(0),
        ])
      ]),
    ])
  }
}

extension AnimaCoreJSONValue {
  fileprivate var objectValue: [String: AnimaCoreJSONValue]? {
    guard case .object(let value) = self else { return nil }
    return value
  }

  fileprivate var dofDocuments: [[String: AnimaCoreJSONValue]] {
    guard let dofs = objectValue?["dofs"],
      case .array(let values) = dofs
    else { return [] }
    return values.compactMap(\.objectValue)
  }

  fileprivate var numberValue: Double? {
    guard case .number(let value) = self else { return nil }
    return value
  }
}
