import XCTest

@testable import AnimaStudioUI

final class NodeCanvasDraftModelTests: XCTestCase {
  func testSampleGraphHasStableStructuredEntryExitAndConnections() {
    let graph = NodeCanvasDraftGraph.sample
    let nodeIDs = Set(graph.nodes.map(\.id))

    XCTAssertEqual(graph.nodes.count(where: { $0.kind == .start }), 1)
    XCTAssertEqual(graph.nodes.count(where: { $0.kind == .end }), 1)
    XCTAssertEqual(graph.nodes.count, 6)
    XCTAssertEqual(graph.edges.count, 6)
    XCTAssertTrue(
      graph.edges.allSatisfy {
        nodeIDs.contains($0.sourceNodeID) && nodeIDs.contains($0.targetNodeID)
      }
    )
    XCTAssertTrue(graph.validationMessages.isEmpty)
  }

  func testAddingMovingAndRemovingNodeKeepsDraftGraphConsistent() throws {
    var graph = NodeCanvasDraftGraph.sample
    let nodeID = graph.addNode(kind: .wait, position: CGPoint(x: 500, y: 400))

    XCTAssertEqual(graph.nodes.last?.title, "Wait 2")
    graph.moveNode(id: nodeID, to: CGPoint(x: -50, y: 2_000))
    let movedNode = try XCTUnwrap(graph.nodes.first { $0.id == nodeID })
    XCTAssertEqual(movedNode.position, CGPoint(x: 120, y: 720))

    let startID = try XCTUnwrap(graph.nodes.first { $0.kind == .start }?.id)
    graph.edges.append(NodeCanvasDraftEdge(sourceNodeID: startID, targetNodeID: nodeID))
    graph.removeNode(id: nodeID)

    XCTAssertFalse(graph.nodes.contains { $0.id == nodeID })
    XCTAssertFalse(
      graph.edges.contains { $0.sourceNodeID == nodeID || $0.targetNodeID == nodeID }
    )
  }

  func testInputVoiceAIAndOutputConceptsHaveTypedPortsButNoRuntime() {
    XCTAssertEqual(
      NodeCanvasDraftKind.allCases.filter { $0.family == .inputs },
      [.textInput, .microphoneInput, .eventInput, .hardwareInput]
    )
    XCTAssertEqual(
      NodeCanvasDraftKind.allCases.filter { $0.family == .voiceAI },
      [.speechToText, .llmPrompt, .memory, .toolCall, .textToSpeech, .aiBehavior]
    )
    XCTAssertEqual(NodeCanvasDraftKind.speechToText.inputPorts, ["AUDIO"])
    XCTAssertEqual(NodeCanvasDraftKind.speechToText.outputPorts, ["TEXT"])
    XCTAssertEqual(NodeCanvasDraftKind.llmPrompt.inputPorts, ["TEXT", "CONTEXT"])
    XCTAssertEqual(NodeCanvasDraftKind.textToSpeech.outputPorts, ["AUDIO"])

    let conceptKinds = NodeCanvasDraftKind.allCases.filter { !$0.isRuntimeAvailable }
    XCTAssertTrue(conceptKinds.allSatisfy { !$0.availabilityDetail.isEmpty })

    var graph = NodeCanvasDraftGraph.sample
    graph.nodes.append(
      NodeCanvasDraftNode(kind: .llmPrompt, position: CGPoint(x: 500, y: 500))
    )
    XCTAssertTrue(
      graph.validationMessages.contains(
        "Concept nodes cannot execute until their runtime providers ship."
      )
    )
  }

  func testStructuredRobotLogicConceptsExposeTypedPortsAndManualSyntax() throws {
    XCTAssertEqual(
      NodeCanvasDraftKind.allCases.filter { $0.family == .programLogic },
      [.branch, .ifGuard, .select, .loop, .callSubroutine, .jumpLegacy, .labelLegacy]
    )
    XCTAssertEqual(
      NodeCanvasDraftKind.allCases.filter { $0.family == .conditions },
      [.logicAnd, .logicOr, .logicXor, .logicNot]
    )
    XCTAssertEqual(
      NodeCanvasDraftKind.allCases.filter { $0.family == .dataIO },
      [.readInput, .writeOutput, .numericRegister, .flag, .positionRegister]
    )
    XCTAssertEqual(
      NodeCanvasDraftKind.allCases.filter { $0.family == .background },
      [.backgroundMonitor, .endScene]
    )

    XCTAssertEqual(NodeCanvasDraftKind.select.inputPorts, ["FLOW", "VALUE"])
    XCTAssertEqual(NodeCanvasDraftKind.select.outputPorts, ["CASE 1", "CASE 2", "DEFAULT"])
    XCTAssertEqual(NodeCanvasDraftKind.waitUntil.outputPorts, ["FLOW", "TIMEOUT"])
    XCTAssertEqual(NodeCanvasDraftKind.logicXor.inputPorts, ["A", "B"])
    XCTAssertEqual(NodeCanvasDraftKind.logicXor.outputPorts, ["CONDITION"])
    XCTAssertTrue(NodeCanvasDraftKind.jumpLegacy.isPermanentlyUnsupported)
    XCTAssertTrue(NodeCanvasDraftKind.labelLegacy.isPermanentlyUnsupported)

    var graph = NodeCanvasDraftGraph.sample
    let registerID = graph.addNode(kind: .numericRegister, position: CGPoint(x: 500, y: 400))
    let selectID = graph.addNode(kind: .select, position: CGPoint(x: 700, y: 400))
    _ = graph.addNode(kind: .jumpLegacy, position: CGPoint(x: 900, y: 400))

    let register = try XCTUnwrap(graph.nodes.first { $0.id == registerID })
    let select = try XCTUnwrap(graph.nodes.first { $0.id == selectID })
    XCTAssertEqual(register.properties["Mode"], "Read / Write")
    XCTAssertEqual(select.properties["Manual Syntax"], "select:")
    XCTAssertTrue(
      graph.validationMessages.contains(
        "JMP and LBL are import references only; use Loop, SELECT, or CALL."
      )
    )
  }
}
