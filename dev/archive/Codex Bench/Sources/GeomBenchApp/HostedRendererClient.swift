import AppKit
import Foundation
import HostedSurfaceBridge
import IOSurface
import Observation

struct HostedRendererFrame: Equatable, @unchecked Sendable {
  let surface: IOSurfaceRef
  let width: Int
  let height: Int
  let sequence: Int

  static func == (lhs: HostedRendererFrame, rhs: HostedRendererFrame) -> Bool {
    lhs.sequence == rhs.sequence
  }
}

@MainActor @Observable
final class HostedRendererClient: @unchecked Sendable {
  enum State: Equatable {
    case stopped
    case starting
    case loading
    case ready
    case failed(String)

    func label(readyLabel: String, loadingLabel: String) -> String {
      switch self {
      case .stopped: "Select or import one of your own STEP files."
      case .starting: "Starting hosted renderer…"
      case .loading: loadingLabel
      case .ready: readyLabel
      case .failed(let message): message
      }
    }
  }

  let readyLabel: String
  let loadingLabel: String

  private(set) var state: State = .stopped
  private(set) var frame: HostedRendererFrame?
  private(set) var loadMilliseconds: Double?
  private(set) var framesPerSecond: Double = 0
  private(set) var memoryMegabytes: Double = 0
  private(set) var cpuPercent: Double = 0
  private(set) var deliveredFrameCount = 0

  var processIdentifier: pid_t? { process?.isRunning == true ? process?.processIdentifier : nil }

  private var process: Process?
  private var inputHandle: FileHandle?
  private var outputHandle: FileHandle?
  private var errorHandle: FileHandle?
  private var outputBuffer = Data()
  private var errorBuffer = Data()
  private var viewportSize = CGSize(width: 960, height: 640)
  private var nextRequestID = 1
  private var frameSequence = 0
  private var renderPending = false
  private var renderQueued = false
  private var surfaceReceiver: OpaquePointer?
  private var theme = BenchTheme.studioBlue

  init(
    readyLabel: String = "Hosted Qt 6 and Open CASCADE Technology renderer",
    loadingLabel: String = "Loading Open CASCADE Technology model…"
  ) {
    self.readyLabel = readyLabel
    self.loadingLabel = loadingLabel
    _ = NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.stop() }
    }
  }

  func start(executableURL: URL, sourceURL: URL, extraArguments: [String] = []) {
    stop()
    state = .starting

    let process = Process()
    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
    process.executableURL = executableURL
    let serviceName =
      "com.animastudio.codexbench.\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString)"
    guard let receiver = serviceName.withCString({ GBHostedSurfaceReceiverCreate($0) }) else {
      state = .failed("Could not create the hosted surface receiver.")
      return
    }
    surfaceReceiver = receiver
    process.arguments = ["--hosted", "--surface-service", serviceName] + extraArguments
    process.standardInput = input
    process.standardOutput = output
    process.standardError = error
    process.environment = ProcessInfo.processInfo.environment.merging([
      "QT_MAC_DISABLE_FOREGROUND_APPLICATION_TRANSFORM": "1"
    ]) { _, hosted in hosted }

    output.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      Task { @MainActor in self?.consumeOutput(data) }
    }
    error.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      Task { @MainActor in self?.consumeError(data) }
    }
    process.terminationHandler = { [weak self] process in
      Task { @MainActor in
        guard let self, self.process === process else { return }
        self.process = nil
        self.inputHandle = nil
        if let surfaceReceiver = self.surfaceReceiver {
          GBHostedSurfaceReceiverDestroy(surfaceReceiver)
          self.surfaceReceiver = nil
        }
        if case .failed = self.state { return }
        let detail = String(data: self.errorBuffer, encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = detail.flatMap { $0.isEmpty ? nil : String($0.suffix(600)) }
        self.state = .failed(
          "Hosted renderer exited (status \(process.terminationStatus))."
            + (suffix.map { " \($0)" } ?? ""))
      }
    }

    do {
      try process.run()
      self.process = process
      inputHandle = input.fileHandleForWriting
      outputHandle = output.fileHandleForReading
      errorHandle = error.fileHandleForReading
      sendTheme()
      if ["step", "stp"].contains(sourceURL.pathExtension.lowercased()) {
        state = .loading
        send(verb: "load", fields: ["path": sourceURL.path])
      } else {
        stop()
        state = .failed("Select or import one of your own STEP files.")
      }
    } catch {
      GBHostedSurfaceReceiverDestroy(receiver)
      surfaceReceiver = nil
      state = .failed("Could not start hosted renderer: \(error.localizedDescription)")
    }
  }

  func stop() {
    outputHandle?.readabilityHandler = nil
    errorHandle?.readabilityHandler = nil
    if let process, process.isRunning {
      send(verb: "shutdown")
      process.terminate()
    }
    process = nil
    inputHandle = nil
    outputHandle = nil
    errorHandle = nil
    outputBuffer.removeAll(keepingCapacity: false)
    errorBuffer.removeAll(keepingCapacity: false)
    frame = nil
    if let surfaceReceiver {
      GBHostedSurfaceReceiverDestroy(surfaceReceiver)
      self.surfaceReceiver = nil
    }
    renderPending = false
    renderQueued = false
    state = .stopped
  }

  func load(sourceURL: URL) {
    guard process?.isRunning == true else { return }
    guard ["step", "stp"].contains(sourceURL.pathExtension.lowercased()) else {
      state = .failed("Select or import one of your own STEP files.")
      return
    }
    state = .loading
    frame = nil
    send(verb: "load", fields: ["path": sourceURL.path])
  }

  func setViewportSize(_ size: CGSize) {
    let width = max(Int(size.width.rounded()), 64)
    let height = max(Int(size.height.rounded()), 64)
    let next = CGSize(width: width, height: height)
    guard next != viewportSize else { return }
    viewportSize = next
    requestFrame()
  }

  func orbit(deltaX: Float, deltaY: Float) {
    command("orbit", x: deltaX, y: deltaY)
  }

  func pan(deltaX: Float, deltaY: Float) {
    command("pan", x: deltaX, y: deltaY)
  }

  func roll(deltaX: Float) {
    command("roll", x: deltaX, y: 0)
  }

  func zoom(scrollDelta: Float) {
    command("zoom", x: scrollDelta, y: 0)
  }

  func fit() {
    send(verb: "fit")
  }

  func setTheme(_ theme: BenchTheme) {
    self.theme = theme
    sendTheme()
  }

  private func command(_ verb: String, x: Float, y: Float) {
    send(verb: verb, fields: ["x": Double(x), "y": Double(y)])
  }

  private func sendTheme() {
    guard process?.isRunning == true else { return }
    let display = theme.overrideColor ?? theme.neutralColor
    let neutral = SIMD3(display.x, display.y, display.z)
    let edge = theme.edgeStrength > 0.02 ? theme.edgeColor : theme.background
    var fields: [String: Any] = [
      "roughness": Double(theme.roughness), "metallic": Double(theme.metallic),
      "keyIntensity": Double(theme.key.intensity / 4_000),
      "fillIntensity": Double(theme.fill.intensity / 4_000),
      "rimIntensity": Double(theme.rim.intensity / 4_000),
      "edgeStrength": Double(theme.edgeStrength),
    ]
    if let override = theme.overrideColor {
      fields["overrideRed"] = Double(override.x)
      fields["overrideGreen"] = Double(override.y)
      fields["overrideBlue"] = Double(override.z)
      fields["overrideAlpha"] = Double(override.w)
      fields["hasOverride"] = true
    } else {
      fields["hasOverride"] = false
    }
    add(theme.background, prefix: "background", to: &fields)
    add(neutral, prefix: "neutral", to: &fields)
    add(edge, prefix: "edge", to: &fields)
    add(theme.selectionColor, prefix: "selection", to: &fields)
    add(theme.key.color, prefix: "key", to: &fields)
    add(theme.fill.color, prefix: "fill", to: &fields)
    add(theme.rim.color, prefix: "rim", to: &fields)
    send(
      verb: "theme",
      fields: fields)
  }

  private func add(_ color: SIMD3<Float>, prefix: String, to fields: inout [String: Any]) {
    fields["\(prefix)Red"] = Double(color.x)
    fields["\(prefix)Green"] = Double(color.y)
    fields["\(prefix)Blue"] = Double(color.z)
  }

  private func requestFrame() {
    guard process?.isRunning == true, state == .ready else { return }
    if renderPending {
      renderQueued = true
      return
    }
    renderPending = true
    send(
      verb: "render",
      fields: ["width": Int(viewportSize.width), "height": Int(viewportSize.height)])
  }

  private func send(verb: String, fields: [String: Any] = [:]) {
    guard let inputHandle else { return }
    var object = fields
    object["id"] = nextRequestID
    object["verb"] = verb
    nextRequestID += 1
    guard JSONSerialization.isValidJSONObject(object),
      let data = try? JSONSerialization.data(withJSONObject: object),
      var line = String(data: data, encoding: .utf8)
    else { return }
    line.append("\n")
    do {
      try inputHandle.write(contentsOf: Data(line.utf8))
    } catch {
      state = .failed("Hosted renderer command failed: \(error.localizedDescription)")
    }
  }

  private func consumeOutput(_ data: Data) {
    outputBuffer.append(data)
    while let newline = outputBuffer.firstIndex(of: 0x0A) {
      let line = outputBuffer.prefix(upTo: newline)
      outputBuffer.removeSubrange(...newline)
      guard !line.isEmpty,
        let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
      else { continue }
      handle(object)
    }
  }

  private func consumeError(_ data: Data) {
    errorBuffer.append(data)
    guard errorBuffer.count < 16_384 else {
      errorBuffer.removeFirst(errorBuffer.count - 8_192)
      return
    }
  }

  private func handle(_ object: [String: Any]) {
    if let error = object["error"] as? String {
      renderPending = false
      state = .failed(error)
      return
    }
    guard let event = object["event"] as? String else { return }
    switch event {
    case "ready":
      break
    case "loaded":
      loadMilliseconds = object["load_ms"] as? Double
      state = .ready
      requestFrame()
    case "camera":
      state = .ready
      requestFrame()
    case "frame":
      renderPending = false
      guard let surfaceReceiver else {
        state = .failed("Hosted surface receiver is unavailable.")
        return
      }
      var width: UInt32 = 0
      var height: UInt32 = 0
      var sequence: UInt32 = 0
      guard
        let surface = GBHostedSurfaceReceiverCopyNext(
          surfaceReceiver, 1_000, &width, &height, &sequence)
      else {
        state = .failed("Hosted renderer returned an invalid frame.")
        return
      }
      frameSequence += 1
      deliveredFrameCount += 1
      frame = HostedRendererFrame(
        surface: surface, width: Int(width), height: Int(height), sequence: frameSequence)
      loadMilliseconds = object["load_ms"] as? Double ?? loadMilliseconds
      framesPerSecond = object["fps"] as? Double ?? framesPerSecond
      memoryMegabytes = object["memory_mb"] as? Double ?? memoryMegabytes
      cpuPercent = object["cpu_percent"] as? Double ?? cpuPercent
      state = .ready
      if renderQueued {
        renderQueued = false
        requestFrame()
      }
    default:
      break
    }
  }
}
