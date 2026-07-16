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
}
