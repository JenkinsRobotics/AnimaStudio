import AppKit
import Foundation
import GeomBenchCore

struct PipelineBenchmarkConfiguration: Equatable {
  let outputURL: URL
  let warmupSeconds: Double
  let durationSeconds: Double

  static func parse(arguments: [String]) -> PipelineBenchmarkConfiguration? {
    guard let output = value(after: "--benchmark-output", in: arguments) else { return nil }
    let warmup = value(after: "--benchmark-warmup", in: arguments).flatMap(Double.init) ?? 4
    let duration = value(after: "--benchmark-duration", in: arguments).flatMap(Double.init) ?? 6
    return PipelineBenchmarkConfiguration(
      outputURL: URL(fileURLWithPath: output),
      warmupSeconds: max(warmup, 1), durationSeconds: max(duration, 2))
  }

  private static func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
      return nil
    }
    return arguments[index + 1]
  }
}

struct PipelineBenchmarkResult: Codable {
  let timestamp: Date
  let success: Bool
  let pipelineID: Int
  let pipeline: String
  let pipelineRole: String
  let rendererBackend: String
  let contributor: String
  let sourceFile: String
  let sourceFiles: [String]
  let sourceFileCount: Int
  let sourceBytes: Int
  let faces: Int
  let edges: Int
  let triangles: Int
  let renderVertices: Int
  let renderBatches: Int
  let rigidParts: Int
  let readyWaitMilliseconds: Double
  let reportedLoadMilliseconds: Double?
  let loadMetricScope: String
  let workloadSeconds: Double
  let renderedFrames: Int
  let framesPerSecond: Double
  let mainCPUPercent: Double
  let helperCPUPercent: Double?
  let combinedCPUPercent: Double
  let mainMemoryMegabytes: Double
  let helperMemoryMegabytes: Double?
  let combinedMemoryMegabytes: Double
  let finalStatus: String
  let caveats: [String]
}

@MainActor
extension BenchSession {
  func runAutomatedBenchmarkIfRequested() async {
    guard !benchmarkRunStarted,
      let configuration = PipelineBenchmarkConfiguration.parse(arguments: CommandLine.arguments)
    else { return }
    benchmarkRunStarted = true
    let began = Date()

    do {
      try await waitForBenchmarkReady(timeoutSeconds: 90)
      let measuredReadyWaitMilliseconds = Date().timeIntervalSince(began) * 1_000
      let reportedLoadMilliseconds = benchmarkReportedLoadMilliseconds
      let readyWaitMilliseconds = measuredReadyWaitMilliseconds
      _ = try await driveBenchmarkOrbit(seconds: configuration.warmupSeconds, measure: false)

      telemetry.resetBenchmarkFrames()
      let cpuStart = LiveTelemetry.processCPUSeconds()
      let measuredStart = Date()
      let samples = try await driveBenchmarkOrbit(
        seconds: configuration.durationSeconds, measure: true)
      try await Task.sleep(for: .milliseconds(250))
      let elapsed = max(Date().timeIntervalSince(measuredStart), 0.001)
      let cpuEnd = LiveTelemetry.processCPUSeconds()
      let renderedFrames = telemetry.benchmarkFrameCount
      let mainCPU = max((cpuEnd - cpuStart) / elapsed * 100, 0)
      let mainMemory = samples.mainMemory.average
      let sourceURLs = document?.sourceURLs ?? selectedFile.map { [$0.url].compactMap { $0 } } ?? []
      let sourceBytes = sourceURLs.reduce(into: 0) { total, url in
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        total += (attributes?[.size] as? NSNumber)?.intValue ?? 0
      }

      let result = PipelineBenchmarkResult(
        timestamp: Date(), success: true, pipelineID: pipeline.rawValue,
        pipeline: pipeline.shortName, pipelineRole: pipeline.role.label,
        rendererBackend: rendererBackend ?? pipeline.defaultRendererBackend,
        contributor: pipeline.contributor,
        sourceFile: sourceURLs.first?.path ?? "", sourceFiles: sourceURLs.map(\.path),
        sourceFileCount: sourceURLs.count, sourceBytes: sourceBytes,
        faces: document?.faces.count ?? 0, edges: document?.edges.count ?? 0,
        triangles: document?.triangleCount ?? 0,
        renderVertices: document?.renderGeometry.vertexCount ?? 0,
        renderBatches: document?.renderGeometry.batches.count ?? 0,
        rigidParts: document?.renderGeometry.partCount ?? 0,
        readyWaitMilliseconds: readyWaitMilliseconds,
        reportedLoadMilliseconds: reportedLoadMilliseconds,
        loadMetricScope: pipeline.benchmarkLoadMetricScope,
        workloadSeconds: elapsed, renderedFrames: renderedFrames,
        framesPerSecond: Double(renderedFrames) / elapsed,
        mainCPUPercent: mainCPU, helperCPUPercent: nil,
        combinedCPUPercent: mainCPU,
        mainMemoryMegabytes: mainMemory, helperMemoryMegabytes: nil,
        combinedMemoryMegabytes: mainMemory,
        finalStatus: status, caveats: pipeline.benchmarkCaveats)
      try writeBenchmark(result, to: configuration.outputURL)
      status = "Benchmark complete: \(String(format: "%.1f", result.framesPerSecond)) FPS"
    } catch {
      let sourceURLs = document?.sourceURLs ?? selectedFile.map { [$0.url].compactMap { $0 } } ?? []
      let result = PipelineBenchmarkResult(
        timestamp: Date(), success: false, pipelineID: pipeline.rawValue,
        pipeline: pipeline.shortName, pipelineRole: pipeline.role.label,
        rendererBackend: rendererBackend ?? pipeline.defaultRendererBackend,
        contributor: pipeline.contributor,
        sourceFile: sourceURLs.first?.path ?? "", sourceFiles: sourceURLs.map(\.path),
        sourceFileCount: sourceURLs.count, sourceBytes: 0,
        faces: document?.faces.count ?? 0,
        edges: document?.edges.count ?? 0, triangles: document?.triangleCount ?? 0,
        renderVertices: document?.renderGeometry.vertexCount ?? 0,
        renderBatches: document?.renderGeometry.batches.count ?? 0,
        rigidParts: document?.renderGeometry.partCount ?? 0,
        readyWaitMilliseconds: Date().timeIntervalSince(began) * 1_000,
        reportedLoadMilliseconds: benchmarkReportedLoadMilliseconds,
        loadMetricScope: pipeline.benchmarkLoadMetricScope, workloadSeconds: 0,
        renderedFrames: 0, framesPerSecond: 0, mainCPUPercent: 0,
        helperCPUPercent: nil, combinedCPUPercent: 0,
        mainMemoryMegabytes: LiveTelemetry.currentMemoryMegabytes(),
        helperMemoryMegabytes: nil,
        combinedMemoryMegabytes: LiveTelemetry.currentMemoryMegabytes(),
        finalStatus: "\(status) · \(error.localizedDescription)",
        caveats: pipeline.benchmarkCaveats)
      try? writeBenchmark(result, to: configuration.outputURL)
      status = result.finalStatus
    }

    try? await Task.sleep(for: .milliseconds(500))
    NSApp.terminate(nil)
  }

  private func waitForBenchmarkReady(timeoutSeconds: Double) async throws {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
      if let rendererDiagnostic {
        throw PipelineBenchmarkError.loadFailed(rendererDiagnostic)
      }
      if selectedFile?.status == "Failed" {
        throw PipelineBenchmarkError.loadFailed(status)
      }
      switch pipeline {
      case .threeJSWebGPU:
        if document != nil, status.hasPrefix("Three.js "), status.contains("uploaded") { return }
      case .openCascadeWebGPU:
        if document != nil, status.hasPrefix("Raw WebGPU:"), status.contains("uploaded") { return }
      default:
        if document != nil, !isLoading { return }
      }
      try await Task.sleep(for: .milliseconds(100))
    }
    throw PipelineBenchmarkError.timeout(pipeline.shortName)
  }

  private func driveBenchmarkOrbit(
    seconds: Double, measure: Bool
  ) async throws -> BenchmarkSamples {
    let ticks = max(Int(seconds * 60), 1)
    var samples = BenchmarkSamples()
    for tick in 0..<ticks {
      benchmarkPulse &+= 1
      camera.orbit(deltaX: 1.2, deltaY: 0.18)
      if measure, tick % 60 == 59 {
        samples.mainMemory.append(LiveTelemetry.currentMemoryMegabytes())
      }
      try await Task.sleep(for: .nanoseconds(16_666_667))
    }
    if measure, samples.mainMemory.isEmpty {
      samples.mainMemory.append(LiveTelemetry.currentMemoryMegabytes())
    }
    return samples
  }

  private var benchmarkReportedLoadMilliseconds: Double? {
    if let value = telemetry.overrideLoadMilliseconds, value > 0 {
      return value
    }
    return nil
  }

  private func writeBenchmark(_ result: PipelineBenchmarkResult, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(result).write(to: url, options: .atomic)
  }
}

private struct BenchmarkSamples {
  var mainMemory: [Double] = []
}

extension Array where Element == Double {
  fileprivate var average: Double { isEmpty ? 0 : reduce(0, +) / Double(count) }
}

private enum PipelineBenchmarkError: LocalizedError {
  case loadFailed(String)
  case timeout(String)

  var errorDescription: String? {
    switch self {
    case .loadFailed(let message): "Pipeline load failed: \(message)"
    case .timeout(let pipeline): "Timed out waiting for \(pipeline) to become ready."
    }
  }
}

extension PipelineID {
  var benchmarkLoadMetricScope: String {
    switch self {
    case .occtRealityKit, .occtMetalKit:
      "Open CASCADE read + XDE transfer + triangulation"
    case .threeJSWebGPU: "Three.js buffer upload after shared Open CASCADE import"
    case .openCascadeWebGPU: "Raw WebGPU buffer upload after shared Open CASCADE import"
    }
  }

  var benchmarkCaveats: [String] {
    var values = [
      "FPS uses the same 60 Hz scripted orbit workload and counts delivered renderer frames.",
      "CPU may exceed 100% when multiple cores are active.",
    ]
    if self == .threeJSWebGPU || self == .openCascadeWebGPU {
      values.append("Main-process memory excludes system-managed WebKit content/GPU processes.")
    }
    if self == .threeJSWebGPU {
      values.append(
        "rendererBackend records whether Three.js selected WebGPU or its WebGL 2 fallback."
      )
    }
    if self == .occtRealityKit {
      values.append(
        "RealityKit does not expose presented-frame callbacks; FPS counts display-link opportunities."
      )
      values.append(
        "Large-assembly B-Rep edges remain in the shared model but are omitted from RealityKit's public material path."
      )
    }
    return values
  }
}

extension PipelineID {
  fileprivate var defaultRendererBackend: String {
    switch self {
    case .occtRealityKit: "RealityKit / Metal"
    case .occtMetalKit: "Metal"
    case .threeJSWebGPU: "WebGPU probe pending"
    case .openCascadeWebGPU: "Raw WebGPU probe pending"
    }
  }
}
