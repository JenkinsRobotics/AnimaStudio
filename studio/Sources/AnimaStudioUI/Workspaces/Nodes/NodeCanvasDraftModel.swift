import Foundation

/// UI-only graph vocabulary used by the Nodes workspace prototype.
///
/// This is intentionally not a second scene model. The eventual N2 graph model
/// will compile to and load from `.scene.anima`; this draft only gives the
/// authoring surface honest, testable interaction state while that contract is
/// being completed.
enum NodeCanvasDraftFamily: String, CaseIterable, Identifiable, Sendable {
  case flow
  case performance
  case timing
  case events
  case inputs
  case voiceAI
  case outputs

  var id: Self { self }

  var title: String {
    switch self {
    case .flow: "Flow"
    case .performance: "Performance"
    case .timing: "Timing & Gates"
    case .events: "Events & Data"
    case .inputs: "Inputs"
    case .voiceAI: "Voice & AI"
    case .outputs: "Outputs"
    }
  }
}

enum NodeCanvasDraftKind: String, CaseIterable, Identifiable, Sendable {
  case start
  case end
  case sequence
  case parallel
  case branch
  case loop
  case clip
  case pose
  case wait
  case waitForEvent
  case emitEvent
  case setVariable
  case audio
  case textInput
  case microphoneInput
  case eventInput
  case hardwareInput
  case speechToText
  case llmPrompt
  case memory
  case toolCall
  case textToSpeech
  case audioOutput
  case motionOutput
  case eventOutput
  case screen
  case ledOutput
  case hardwareOutput
  case aiBehavior

  var id: Self { self }

  var title: String {
    switch self {
    case .start: "Start"
    case .end: "End"
    case .sequence: "Sequence"
    case .parallel: "Parallel"
    case .branch: "Branch"
    case .loop: "Loop"
    case .clip: "Animation Clip"
    case .pose: "Pose"
    case .wait: "Wait"
    case .waitForEvent: "Wait for Event"
    case .emitEvent: "Emit Event"
    case .setVariable: "Set Variable"
    case .audio: "Audio Clip"
    case .textInput: "Text Input"
    case .microphoneInput: "Microphone Input"
    case .eventInput: "Event Input"
    case .hardwareInput: "Hardware Input"
    case .speechToText: "Speech to Text (STT)"
    case .llmPrompt: "LLM Prompt"
    case .memory: "Conversation Memory"
    case .toolCall: "Tool Call"
    case .textToSpeech: "Text to Speech (TTS)"
    case .audioOutput: "Audio Output"
    case .motionOutput: "Motion Output"
    case .eventOutput: "Event Output"
    case .screen: "Screen Output"
    case .ledOutput: "LED Output"
    case .hardwareOutput: "Hardware Output"
    case .aiBehavior: "AI Behavior"
    }
  }

  var family: NodeCanvasDraftFamily {
    switch self {
    case .start, .end, .sequence, .parallel, .branch, .loop: .flow
    case .clip, .pose: .performance
    case .wait, .waitForEvent: .timing
    case .emitEvent, .setVariable: .events
    case .textInput, .microphoneInput, .eventInput, .hardwareInput: .inputs
    case .speechToText, .llmPrompt, .memory, .toolCall, .textToSpeech, .aiBehavior: .voiceAI
    case .audio, .audioOutput, .motionOutput, .eventOutput, .screen, .ledOutput,
      .hardwareOutput:
      .outputs
    }
  }

  var systemImage: String {
    switch self {
    case .start: "play.fill"
    case .end: "stop.fill"
    case .sequence: "arrow.right.to.line.compact"
    case .parallel: "arrow.triangle.branch"
    case .branch: "arrow.triangle.swap"
    case .loop: "repeat"
    case .clip: "figure.walk.motion"
    case .pose: "figure.stand"
    case .wait: "timer"
    case .waitForEvent: "hourglass"
    case .emitEvent: "bolt.circle"
    case .setVariable: "equal.circle"
    case .audio: "waveform"
    case .textInput: "text.cursor"
    case .microphoneInput: "mic"
    case .eventInput: "bolt.horizontal.circle"
    case .hardwareInput: "switch.2"
    case .speechToText: "captions.bubble"
    case .llmPrompt: "brain.head.profile"
    case .memory: "books.vertical"
    case .toolCall: "wrench.and.screwdriver"
    case .textToSpeech: "speaker.wave.2"
    case .audioOutput: "speaker.wave.2"
    case .motionOutput: "figure.walk.motion"
    case .eventOutput: "bolt.circle"
    case .screen: "display"
    case .ledOutput: "circle.grid.3x3"
    case .hardwareOutput: "cable.connector"
    case .aiBehavior: "brain.head.profile"
    }
  }

  var inputPorts: [String] {
    switch self {
    case .start: []
    case .branch: ["FLOW", "CONDITION"]
    case .loop: ["FLOW", "COUNT"]
    case .setVariable: ["FLOW", "VALUE"]
    case .textInput, .microphoneInput, .eventInput, .hardwareInput: []
    case .speechToText: ["AUDIO"]
    case .llmPrompt: ["TEXT", "CONTEXT"]
    case .memory: ["TEXT"]
    case .toolCall: ["FLOW", "REQUEST"]
    case .textToSpeech: ["TEXT"]
    case .audioOutput: ["FLOW", "AUDIO"]
    case .motionOutput: ["FLOW", "MOTION"]
    case .eventOutput: ["FLOW", "EVENT"]
    case .screen: ["FLOW", "CONTENT"]
    case .ledOutput: ["FLOW", "COLOR"]
    case .hardwareOutput: ["FLOW", "VALUE"]
    case .aiBehavior: ["FLOW", "CONTEXT"]
    default: ["FLOW"]
    }
  }

  var outputPorts: [String] {
    switch self {
    case .end: []
    case .parallel: ["A", "B"]
    case .branch: ["TRUE", "FALSE"]
    case .loop: ["BODY", "DONE"]
    case .audio: ["FLOW", "AUDIO"]
    case .textInput: ["TEXT"]
    case .microphoneInput: ["AUDIO"]
    case .eventInput: ["EVENT"]
    case .hardwareInput: ["VALUE"]
    case .speechToText: ["TEXT"]
    case .llmPrompt: ["TEXT"]
    case .memory: ["CONTEXT"]
    case .toolCall: ["FLOW", "RESULT"]
    case .textToSpeech: ["AUDIO"]
    case .aiBehavior: ["FLOW", "ACTION"]
    default: ["FLOW"]
    }
  }

  var isRuntimeAvailable: Bool {
    switch family {
    case .flow, .performance, .timing, .events:
      true
    case .inputs, .voiceAI, .outputs:
      false
    }
  }

  var availabilityDetail: String {
    if isRuntimeAvailable {
      return "Scene v1 action"
    }
    return switch self {
    case .textInput: "Concept: operator text or plugin-provided text input"
    case .microphoneInput: "Concept: live microphone audio stream"
    case .eventInput: "Concept: scene, network, MIDI, or OSC event input"
    case .hardwareInput: "Concept: sensor, button, or controller input"
    case .speechToText: "Concept: speech-to-text provider required"
    case .llmPrompt: "Concept: optional LLM provider required"
    case .memory: "Concept: optional conversation-memory provider required"
    case .toolCall: "Concept: approved tool or plugin contract required"
    case .textToSpeech: "Concept: text-to-speech provider required"
    case .audio, .audioOutput: "Concept: scene audio runtime required"
    case .motionOutput: "Concept: scene-to-animation binding required"
    case .eventOutput: "Concept: external event adapter required"
    case .screen: "Concept: screen output runtime required"
    case .ledOutput: "Concept: LED output runtime required"
    case .hardwareOutput: "Concept: safely armed hardware mapping required"
    case .aiBehavior: "Concept: optional AI behavior provider required"
    default: "Available"
    }
  }
}

enum NodeCanvasDraftEdgeKind: String, Sendable {
  case flow
  case data
}

struct NodeCanvasDraftNode: Identifiable, Equatable, Sendable {
  let id: UUID
  var kind: NodeCanvasDraftKind
  var title: String
  var subtitle: String
  var position: CGPoint
  var properties: [String: String]

  init(
    id: UUID = UUID(),
    kind: NodeCanvasDraftKind,
    title: String? = nil,
    subtitle: String = "",
    position: CGPoint,
    properties: [String: String] = [:]
  ) {
    self.id = id
    self.kind = kind
    self.title = title ?? kind.title
    self.subtitle = subtitle
    self.position = position
    self.properties = properties
  }
}

struct NodeCanvasDraftEdge: Identifiable, Equatable, Sendable {
  let id: UUID
  let sourceNodeID: UUID
  let targetNodeID: UUID
  let sourcePort: String
  let targetPort: String
  let kind: NodeCanvasDraftEdgeKind

  init(
    id: UUID = UUID(),
    sourceNodeID: UUID,
    targetNodeID: UUID,
    sourcePort: String = "FLOW",
    targetPort: String = "FLOW",
    kind: NodeCanvasDraftEdgeKind = .flow
  ) {
    self.id = id
    self.sourceNodeID = sourceNodeID
    self.targetNodeID = targetNodeID
    self.sourcePort = sourcePort
    self.targetPort = targetPort
    self.kind = kind
  }
}

struct NodeCanvasDraftGraph: Equatable, Sendable {
  var nodes: [NodeCanvasDraftNode]
  var edges: [NodeCanvasDraftEdge]

  mutating func addNode(kind: NodeCanvasDraftKind, position: CGPoint) -> UUID {
    let sequence = nodes.count(where: { $0.kind == kind }) + 1
    let node = NodeCanvasDraftNode(
      kind: kind,
      title: sequence == 1 ? kind.title : "\(kind.title) \(sequence)",
      subtitle: kind.availabilityDetail,
      position: position,
      properties: Self.defaultProperties(for: kind)
    )
    nodes.append(node)
    return node.id
  }

  mutating func moveNode(id: UUID, to position: CGPoint) {
    guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
    nodes[index].position = CGPoint(
      x: min(max(position.x, 120), 1_280),
      y: min(max(position.y, 90), 720)
    )
  }

  mutating func removeNode(id: UUID) {
    nodes.removeAll { $0.id == id }
    edges.removeAll { $0.sourceNodeID == id || $0.targetNodeID == id }
  }

  var validationMessages: [String] {
    var messages: [String] = []
    let nodeIDs = Set(nodes.map(\.id))
    if nodes.count(where: { $0.kind == .start }) != 1 {
      messages.append("A graph needs exactly one Start node.")
    }
    if nodes.count(where: { $0.kind == .end }) != 1 {
      messages.append("A graph needs exactly one End node.")
    }
    if edges.contains(where: {
      !nodeIDs.contains($0.sourceNodeID) || !nodeIDs.contains($0.targetNodeID)
    }) {
      messages.append("One or more connections reference a missing node.")
    }
    if nodes.contains(where: { !$0.kind.isRuntimeAvailable }) {
      messages.append("Concept nodes cannot execute until their runtime providers ship.")
    }
    return messages
  }

  static let sample: NodeCanvasDraftGraph = {
    let start = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    let greet = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    let parallel = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    let wait = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
    let event = UUID(uuidString: "00000000-0000-0000-0000-000000000105")!
    let end = UUID(uuidString: "00000000-0000-0000-0000-000000000106")!

    return NodeCanvasDraftGraph(
      nodes: [
        NodeCanvasDraftNode(
          id: start, kind: .start, subtitle: "Scene entry", position: CGPoint(x: 170, y: 330)
        ),
        NodeCanvasDraftNode(
          id: greet, kind: .clip, title: "Greeting Motion", subtitle: "clip · greet",
          position: CGPoint(x: 410, y: 250),
          properties: ["Clip": "greet", "Speed": "1.0×", "Loop": "Off"]
        ),
        NodeCanvasDraftNode(
          id: parallel, kind: .parallel, subtitle: "Run together",
          position: CGPoint(x: 680, y: 330)
        ),
        NodeCanvasDraftNode(
          id: wait, kind: .wait, title: "Hold Pose", subtitle: "1.5 seconds",
          position: CGPoint(x: 930, y: 220), properties: ["Duration": "1.5 s"]
        ),
        NodeCanvasDraftNode(
          id: event, kind: .emitEvent, title: "Lights On", subtitle: "event · lights_on",
          position: CGPoint(x: 930, y: 440), properties: ["Event": "lights_on"]
        ),
        NodeCanvasDraftNode(
          id: end, kind: .end, subtitle: "Scene complete", position: CGPoint(x: 1_180, y: 330)
        ),
      ],
      edges: [
        NodeCanvasDraftEdge(sourceNodeID: start, targetNodeID: greet),
        NodeCanvasDraftEdge(sourceNodeID: greet, targetNodeID: parallel),
        NodeCanvasDraftEdge(sourceNodeID: parallel, targetNodeID: wait, sourcePort: "A"),
        NodeCanvasDraftEdge(sourceNodeID: parallel, targetNodeID: event, sourcePort: "B"),
        NodeCanvasDraftEdge(sourceNodeID: wait, targetNodeID: end),
        NodeCanvasDraftEdge(sourceNodeID: event, targetNodeID: end),
      ]
    )
  }()

  private static func defaultProperties(for kind: NodeCanvasDraftKind) -> [String: String] {
    switch kind {
    case .clip: ["Clip": "Choose clip", "Speed": "1.0×", "Loop": "Off"]
    case .pose: ["Duration": "0.5 s", "Targets": "0"]
    case .wait: ["Duration": "1.0 s"]
    case .waitForEvent: ["Event": "event_name", "Timeout": "None"]
    case .emitEvent: ["Event": "event_name"]
    case .setVariable: ["Variable": "name", "Value": "0"]
    case .loop: ["Count": "2"]
    case .branch: ["Condition": "variable == value"]
    case .audio: ["Asset": "Choose audio", "Volume": "100%"]
    case .textInput: ["Label": "Operator text", "Default": ""]
    case .microphoneInput: ["Device": "System default", "Mode": "Streaming"]
    case .eventInput: ["Source": "Scene event", "Name": "event_name"]
    case .hardwareInput: ["Device": "Choose device", "Channel": "0"]
    case .speechToText: ["Provider": "Choose provider", "Language": "Auto"]
    case .llmPrompt: ["Model": "Choose model", "System": "Character behavior"]
    case .memory: ["Scope": "Scene", "History": "12 turns"]
    case .toolCall: ["Tool": "Choose approved tool", "Timeout": "10 s"]
    case .textToSpeech: ["Provider": "Choose provider", "Voice": "Choose voice"]
    case .audioOutput: ["Device": "System default", "Volume": "100%"]
    case .motionOutput: ["Character": "Active character", "Blend": "100%"]
    case .eventOutput: ["Adapter": "Scene event", "Name": "event_name"]
    case .screen: ["Target": "Choose screen", "Content": "TEXT"]
    case .ledOutput: ["Target": "Choose matrix", "Brightness": "100%"]
    case .hardwareOutput: ["Mapping": "Choose output", "Safety": "Disarmed"]
    case .aiBehavior: ["Goal": "Describe behavior", "Policy": "Approval required"]
    case .start, .end, .sequence, .parallel: [:]
    }
  }
}
