import Foundation

public enum AnimaCoreClientError: Error, Equatable, Sendable {
  case helperNotFound
  case launchFailed(String)
  case disconnected(String)
  case invalidResponse(String)
  case remote(AnimaCoreRemoteError)
}

extension AnimaCoreClientError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .helperNotFound:
      "AnimaCore helper was not found. Build the bundled helper or set "
        + "ANIMACORE_HELPER_EXECUTABLE."
    case .launchFailed(let detail):
      "AnimaCore could not start: \(detail)"
    case .disconnected(let detail):
      "AnimaCore disconnected: \(detail)"
    case .invalidResponse(let detail):
      "AnimaCore returned an invalid response: \(detail)"
    case .remote(let error):
      error.errorDescription
    }
  }
}

public actor AnimaCoreClient {
  public static let protocolVersion = 1

  private let configuration: AnimaCoreLaunchConfiguration
  private var process: Process?
  private var inputHandle: FileHandle?
  private var outputHandle: FileHandle?
  private var nextRequestID = 1
  private var cachedHello: AnimaCoreHello?

  public init(configuration: AnimaCoreLaunchConfiguration) {
    self.configuration = configuration
  }

  public init() throws {
    self.configuration = try .resolved()
  }

  deinit {
    if let process, process.isRunning {
      process.terminate()
    }
  }

  @discardableResult
  public func start() async throws -> AnimaCoreHello {
    if let cachedHello { return cachedHello }
    try launchIfNeeded()
    let hello: AnimaCoreHello = try request(
      method: "hello",
      params: HelloParameters(
        client: "AnimaStudio",
        protocolVersion: Self.protocolVersion
      )
    )
    cachedHello = hello
    return hello
  }

  public func loadCharacter(text: String) async throws -> AnimaCoreCharacterLoad {
    _ = try await start()
    return try request(
      method: "load_character",
      params: TextParameters(text: text)
    )
  }

  public func validateCharacter(text: String) async throws -> AnimaCoreValidation {
    _ = try await start()
    return try request(
      method: "validate_character",
      params: TextParameters(text: text)
    )
  }

  /// Asks the canonical engine to validate and author `.character.anima` YAML.
  public func serializeCharacter(
    rig: AnimaCoreJSONValue
  ) async throws -> AnimaCoreSerializedText {
    _ = try await start()
    return try request(
      method: "serialize_character",
      params: RigParameters(rig: rig)
    )
  }

  public func mateTypes() async throws -> AnimaCoreMateTypeCatalog {
    _ = try await start()
    return try request(
      method: "mate_types",
      params: EmptyParameters()
    )
  }

  /// Resolves a candidate mate at the requested frame without mutating the
  /// canonical rig held by `handle`. The returned transforms use the same
  /// engine path as `resolve_pose`; only `addMate` commits the candidate.
  public func previewMate(
    handle: String,
    joint: AnimaCoreJSONValue,
    clip: String? = nil,
    timeSeconds: Double = 0
  ) async throws -> AnimaCoreResolvedPose {
    _ = try await start()
    return try request(
      method: "preview_mate",
      params: MatePreviewParameters(
        handle: handle,
        joint: joint,
        clip: clip,
        timeSeconds: timeSeconds
      )
    )
  }

  /// Adds one mate to the canonical rig held by `handle`.
  ///
  /// `joint` is the same full-fidelity DTO shape returned in
  /// `load_character.rig.joints`. AnimaCore validates the complete rig,
  /// mutates the handle only when valid, and returns the refreshed rig DTO.
  public func addMate(
    handle: String,
    joint: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad {
    _ = try await start()
    return try request(
      method: "add_mate",
      params: MateMutationParameters(handle: handle, joint: joint)
    )
  }

  /// Replaces an existing mate, keyed by the mate's editable `name`.
  public func updateMate(
    handle: String,
    joint: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad {
    _ = try await start()
    return try request(
      method: "update_mate",
      params: MateMutationParameters(handle: handle, joint: joint)
    )
  }

  /// Replaces one part's canonical fields in the rig held by `handle` —
  /// the viewport-drag path for a FREE part's rest transform. The part
  /// document is the full entry (including `name`) from the rig DTO.
  public func updatePart(
    handle: String,
    part: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad {
    _ = try await start()
    return try request(
      method: "update_part",
      params: PartMutationParameters(handle: handle, part: part)
    )
  }

  /// Removes an existing mate from the canonical rig held by `handle`.
  public func removeMate(
    handle: String,
    name: String
  ) async throws -> AnimaCoreCharacterLoad {
    _ = try await start()
    return try request(
      method: "remove_mate",
      params: RemoveMateParameters(handle: handle, name: name)
    )
  }

  public func relationTypes() async throws -> AnimaCoreRelationTypeCatalog {
    _ = try await start()
    return try request(
      method: "relation_types",
      params: EmptyParameters()
    )
  }

  /// Adds one advanced relation to the canonical rig held by `handle`.
  public func addRelation(
    handle: String,
    relation: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad {
    _ = try await start()
    return try request(
      method: "add_relation",
      params: RelationMutationParameters(handle: handle, relation: relation)
    )
  }

  /// Replaces an existing relation, keyed by its unique driven DOF path.
  public func updateRelation(
    handle: String,
    relation: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad {
    _ = try await start()
    return try request(
      method: "update_relation",
      params: RelationMutationParameters(handle: handle, relation: relation)
    )
  }

  /// Removes the relation that drives `driven`.
  public func removeRelation(
    handle: String,
    driven: String
  ) async throws -> AnimaCoreCharacterLoad {
    _ = try await start()
    return try request(
      method: "remove_relation",
      params: RemoveRelationParameters(handle: handle, driven: driven)
    )
  }

  // Canvas2D (2D character): build a canvas and rasterize frames for the 2D
  // workspace preview. `canvas` is the DTO shape from `animacore.canvas2d_io`;
  // `render_frame` needs the engine's optional `media` extra (Pillow) and
  // otherwise returns a `media_unavailable` remote error.
  public func canvas2DNew(
    canvas: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCanvasHandle {
    _ = try await start()
    return try request(
      method: "canvas2d.new",
      params: Canvas2DNewParameters(canvas: canvas)
    )
  }

  public func canvas2DRenderFrame(
    handle: String,
    values: [String: Double] = [:],
    timeSeconds: Double = 0
  ) async throws -> AnimaCoreRenderedFrame {
    _ = try await start()
    return try request(
      method: "canvas2d.render_frame",
      params: Canvas2DRenderParameters(
        handle: handle,
        values: values,
        timeSeconds: timeSeconds
      )
    )
  }

  public func evaluate(
    handle: String,
    clip: String? = nil,
    timeSeconds: Double = 0
  ) async throws -> AnimaCoreEvaluation {
    _ = try await start()
    return try request(
      method: "evaluate",
      params: EvaluationParameters(
        handle: handle,
        clip: clip,
        timeSeconds: timeSeconds
      )
    )
  }

  public func resolvePose(
    handle: String,
    clip: String? = nil,
    timeSeconds: Double = 0
  ) async throws -> AnimaCoreResolvedPose {
    _ = try await start()
    return try request(
      method: "resolve_pose",
      params: EvaluationParameters(
        handle: handle,
        clip: clip,
        timeSeconds: timeSeconds
      )
    )
  }

  public func forwardKinematics(
    handle: String,
    jointValues: [String: Double]
  ) async throws -> AnimaCoreForwardKinematicsResult {
    _ = try await start()
    return try request(
      method: "forward_kinematics",
      params: ForwardKinematicsParameters(handle: handle, jointValues: jointValues)
    )
  }

  public func solveInverseKinematics(
    handle: String,
    targetPose: AnimaCoreTransformPose,
    seed: [String: Double]
  ) async throws -> AnimaCoreInverseKinematicsResult {
    _ = try await start()
    return try request(
      method: "solve_ik",
      params: InverseKinematicsParameters(handle: handle, targetPose: targetPose, seed: seed)
    )
  }

  public func release(handle: String) async throws {
    guard process != nil else { return }
    let _: EmptyResult = try request(
      method: "release",
      params: HandleParameters(handle: handle)
    )
  }

  public func shutdown() async {
    guard process != nil else { return }
    do {
      let _: EmptyResult = try request(
        method: "shutdown",
        params: EmptyParameters()
      )
    } catch {
      // Teardown remains best-effort; the hardware layer owns safety state.
    }
    inputHandle?.closeFile()
    inputHandle = nil
    outputHandle = nil
    process = nil
    cachedHello = nil
  }

  private func launchIfNeeded() throws {
    guard process == nil else { return }

    let process = Process()
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.executableURL = configuration.executableURL
    process.arguments = configuration.arguments
    process.currentDirectoryURL = configuration.currentDirectoryURL
    process.environment = configuration.environment
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
      try process.run()
    } catch {
      throw AnimaCoreClientError.launchFailed(error.localizedDescription)
    }

    self.process = process
    self.inputHandle = inputPipe.fileHandleForWriting
    self.outputHandle = outputPipe.fileHandleForReading
  }

  private func request<Parameters: Encodable, Result: Decodable>(
    method: String,
    params: Parameters
  ) throws -> Result {
    guard let inputHandle, outputHandle != nil else {
      throw AnimaCoreClientError.disconnected("the helper is not running")
    }

    let requestID = nextRequestID
    nextRequestID += 1
    let request = RequestEnvelope(id: requestID, method: method, params: params)
    var data: Data
    do {
      data = try JSONEncoder().encode(request)
      data.append(0x0A)
    } catch {
      throw AnimaCoreClientError.invalidResponse(
        "could not encode \(method): \(error.localizedDescription)"
      )
    }

    do {
      try inputHandle.write(contentsOf: data)
    } catch {
      throw AnimaCoreClientError.disconnected(error.localizedDescription)
    }
    let responseData = try readResponseLine()

    let response: ResponseEnvelope<Result>
    do {
      response = try JSONDecoder().decode(ResponseEnvelope<Result>.self, from: responseData)
    } catch {
      throw AnimaCoreClientError.invalidResponse(error.localizedDescription)
    }
    guard response.id == requestID else {
      throw AnimaCoreClientError.invalidResponse(
        "expected response \(requestID), received \(String(describing: response.id))"
      )
    }
    if let error = response.error {
      throw AnimaCoreClientError.remote(error)
    }
    guard response.ok, let result = response.result else {
      throw AnimaCoreClientError.invalidResponse("missing result for \(method)")
    }
    return result
  }

  /// The bridge currently processes stdin sequentially. Keeping one blocking
  /// read inside this actor therefore gives us deterministic request ordering
  /// without introducing a second dispatcher before a concurrent caller exists.
  private func readResponseLine() throws -> Data {
    guard let outputHandle else {
      throw AnimaCoreClientError.disconnected("the response stream is unavailable")
    }
    var line = Data()
    while true {
      guard let byte = try outputHandle.read(upToCount: 1), !byte.isEmpty else {
        process = nil
        inputHandle = nil
        self.outputHandle = nil
        cachedHello = nil
        throw AnimaCoreClientError.disconnected("the response stream closed")
      }
      if byte[byte.startIndex] == 0x0A {
        guard !line.isEmpty else { continue }
        return line
      }
      line.append(byte)
    }
  }
}

public protocol AnimaCoreServing: Actor {
  func start() async throws -> AnimaCoreHello
  func loadCharacter(text: String) async throws -> AnimaCoreCharacterLoad
  func validateCharacter(text: String) async throws -> AnimaCoreValidation
  func serializeCharacter(rig: AnimaCoreJSONValue) async throws -> AnimaCoreSerializedText
  func mateTypes() async throws -> AnimaCoreMateTypeCatalog
  func previewMate(
    handle: String,
    joint: AnimaCoreJSONValue,
    clip: String?,
    timeSeconds: Double
  ) async throws -> AnimaCoreResolvedPose
  func addMate(
    handle: String,
    joint: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad
  func updateMate(
    handle: String,
    joint: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad
  func removeMate(
    handle: String,
    name: String
  ) async throws -> AnimaCoreCharacterLoad
  func updatePart(
    handle: String,
    part: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad
  func relationTypes() async throws -> AnimaCoreRelationTypeCatalog
  func addRelation(
    handle: String,
    relation: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad
  func updateRelation(
    handle: String,
    relation: AnimaCoreJSONValue
  ) async throws -> AnimaCoreCharacterLoad
  func removeRelation(
    handle: String,
    driven: String
  ) async throws -> AnimaCoreCharacterLoad
  func evaluate(
    handle: String,
    clip: String?,
    timeSeconds: Double
  ) async throws -> AnimaCoreEvaluation
  func resolvePose(
    handle: String,
    clip: String?,
    timeSeconds: Double
  ) async throws -> AnimaCoreResolvedPose
  func forwardKinematics(
    handle: String,
    jointValues: [String: Double]
  ) async throws -> AnimaCoreForwardKinematicsResult
  func solveInverseKinematics(
    handle: String,
    targetPose: AnimaCoreTransformPose,
    seed: [String: Double]
  ) async throws -> AnimaCoreInverseKinematicsResult
  func release(handle: String) async throws
  func shutdown() async
}

extension AnimaCoreClient: AnimaCoreServing {}

private struct RequestEnvelope<Parameters: Encodable>: Encodable {
  let id: Int
  let method: String
  let params: Parameters
}

private struct ResponseEnvelope<Result: Decodable>: Decodable {
  let id: Int?
  let ok: Bool
  let result: Result?
  let error: AnimaCoreRemoteError?
}

private struct HelloParameters: Encodable {
  let client: String
  let protocolVersion: Int

  enum CodingKeys: String, CodingKey {
    case client
    case protocolVersion = "protocol_version"
  }
}

private struct TextParameters: Encodable {
  let text: String
}

private struct HandleParameters: Encodable {
  let handle: String
}

private struct RigParameters: Encodable {
  let rig: AnimaCoreJSONValue
}

private struct MateMutationParameters: Encodable {
  let handle: String
  let joint: AnimaCoreJSONValue
}

private struct MatePreviewParameters: Encodable {
  let handle: String
  let joint: AnimaCoreJSONValue
  let clip: String?
  let timeSeconds: Double

  enum CodingKeys: String, CodingKey {
    case handle
    case joint
    case clip
    case timeSeconds = "time_s"
  }
}

private struct RemoveMateParameters: Encodable {
  let handle: String
  let name: String
}

private struct PartMutationParameters: Encodable {
  let handle: String
  let part: AnimaCoreJSONValue
}

private struct RelationMutationParameters: Encodable {
  let handle: String
  let relation: AnimaCoreJSONValue
}

private struct RemoveRelationParameters: Encodable {
  let handle: String
  let driven: String
}

private struct EvaluationParameters: Encodable {
  let handle: String
  let clip: String?
  let timeSeconds: Double

  enum CodingKeys: String, CodingKey {
    case handle
    case clip
    case timeSeconds = "time_s"
  }
}

private struct EmptyParameters: Encodable {}
private struct EmptyResult: Decodable {}

private struct ForwardKinematicsParameters: Encodable {
  let handle: String
  let jointValues: [String: Double]

  enum CodingKeys: String, CodingKey {
    case handle
    case jointValues = "joint_values"
  }
}

private struct InverseKinematicsParameters: Encodable {
  let handle: String
  let targetPose: AnimaCoreTransformPose
  let seed: [String: Double]

  enum CodingKeys: String, CodingKey {
    case handle, seed
    case targetPose = "target_pose"
  }
}

private struct Canvas2DNewParameters: Encodable {
  let canvas: AnimaCoreJSONValue
}

private struct Canvas2DRenderParameters: Encodable {
  let handle: String
  let values: [String: Double]
  let timeSeconds: Double

  enum CodingKeys: String, CodingKey {
    case handle, values
    case timeSeconds = "time_seconds"
  }
}

public struct AnimaCoreCanvasHandle: Decodable, Sendable {
  public let handle: String
}

public struct AnimaCoreRenderedFrame: Decodable, Sendable {
  public let width: Int
  public let height: Int
  public let pngBase64: String

  enum CodingKeys: String, CodingKey {
    case width, height
    case pngBase64 = "png_base64"
  }
}
