import AppKit
import Foundation
import GeomBenchCore
import Observation
import UniformTypeIdentifiers
import simd

struct BenchFileRecord: Identifiable, Equatable {
  let id = UUID()
  let url: URL?
  let displayName: String
  let kind: String
  var status: String
}

/// Open CASCADE's XCAF application owns process-global state. Keep transfers
/// off the main actor, but never run two document imports concurrently.
private actor STEPImportQueue {
  static let shared = STEPImportQueue()

  private struct CacheKey: Hashable {
    let path: String
    let size: UInt64
    let modificationDate: Date
  }

  private var documents: [CacheKey: GeometryDocument] = [:]

  func load(_ url: URL) throws -> GeometryDocument {
    let key = cacheKey(for: url)
    if let cached = documents[key] { return cached }
    let document = try GeometryDocument.loadSTEP(url)
    documents[key] = document
    return document
  }

  func loadAssembly(_ urls: [URL]) throws -> GeometryDocument {
    try GeometryDocument.merging(urls.map { try load($0) })
  }

  private func cacheKey(for url: URL) -> CacheKey {
    let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
    return CacheKey(
      path: url.standardizedFileURL.path,
      size: UInt64(max(values?.fileSize ?? 0, 0)),
      modificationDate: values?.contentModificationDate ?? .distantPast)
  }
}

@MainActor @Observable
final class BenchSession {
  private static let themePreferenceKey = "CodexBenchTheme"
  private static let themeConfigurationKey = "CodexBenchThemeConfiguration"
  private static let pipelinePreferenceKey = "CodexBenchPipeline"
  private let defaults: UserDefaults
  private var activeLoadRequestID: UUID?
  private var assemblyFileIDs: [BenchFileRecord.ID] = []
  var benchmarkRunStarted = false
  var pipeline: PipelineID
  var theme: BenchTheme
  var files: [BenchFileRecord] = []
  var selectedFileID: BenchFileRecord.ID?
  var document: GeometryDocument?
  var isModelSelected = false
  var camera = CADCameraState()
  var status = "Open one of your own STEP or STP files to begin."
  var isLoading = false
  var renderRevision = 0
  var benchmarkPulse = 0
  var rendererDiagnostic: String?
  var rendererBackend: String?
  var telemetry = LiveTelemetry()
  var capabilities = CapabilityProbe.all()

  var selectedFile: BenchFileRecord? {
    files.first { $0.id == selectedFileID }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    pipeline = Self.loadPipelinePreference(from: defaults)
    theme = Self.loadThemePreference(from: defaults)
    telemetry.start()
    let arguments = CommandLine.arguments
    let requestedPipeline = arguments.firstIndex(of: "--pipeline").flatMap { index in
      arguments.indices.contains(index + 1) ? Int(arguments[index + 1]) : nil
    }.flatMap(PipelineID.init(rawValue:))
    if let requestedPipeline {
      pipeline = requestedPipeline
      status = emptySelectionMessage(for: requestedPipeline)
    }
    let fileURLs = arguments.indices.compactMap { index -> URL? in
      guard arguments[index] == "--file", arguments.indices.contains(index + 1) else {
        return nil
      }
      return URL(fileURLWithPath: arguments[index + 1])
    }
    if !fileURLs.isEmpty {
      let mergeFiles =
        ProcessInfo.processInfo.environment["CODEX_BENCH_MERGE_FILES"] == "1"
        || arguments.contains("--merge-files")
      importFiles(fileURLs, asAssembly: mergeFiles)
    }
  }

  func presentOpenPanel() {
    guard capability(for: pipeline)?.available == true else {
      status = capability(for: pipeline)?.reason ?? pipeline.detail
      return
    }
    let panel = NSOpenPanel()
    panel.title = pipeline.acceptsSTEP ? "Open STEP assembly" : "Open mesh asset"
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = allowedContentTypes
    guard panel.runModal() == .OK else { return }
    importFiles(panel.urls, asAssembly: panel.urls.count > 1)
  }

  func importFile(_ url: URL) {
    importFiles([url])
  }

  func importFiles(_ urls: [URL], asAssembly: Bool = false) {
    var firstRecord: BenchFileRecord?
    var importedRecords: [BenchFileRecord] = []
    for url in urls {
      let normalizedURL = url.standardizedFileURL
      if let existing = files.first(where: { $0.url?.standardizedFileURL == normalizedURL }) {
        if firstRecord == nil { firstRecord = existing }
        importedRecords.append(existing)
        continue
      }
      let record = BenchFileRecord(
        url: normalizedURL, displayName: normalizedURL.lastPathComponent,
        kind: normalizedURL.pathExtension.uppercased(), status: "Not loaded")
      files.append(record)
      importedRecords.append(record)
      if firstRecord == nil { firstRecord = record }
    }
    guard let firstRecord else { return }
    selectedFileID = firstRecord.id
    if asAssembly, importedRecords.count > 1 {
      loadAssembly(importedRecords)
    } else {
      assemblyFileIDs = []
      load(firstRecord)
    }
  }

  func select(_ record: BenchFileRecord) {
    // SwiftUI reports the programmatic selection of the assembly's first row.
    // Do not collapse that combined document back to a single-file load.
    if assemblyFileIDs.count > 1, record.id == assemblyFileIDs.first,
      selectedFileID == record.id
    {
      return
    }
    assemblyFileIDs = []
    selectedFileID = record.id
    load(record)
  }

  func switchPipeline(_ value: PipelineID) {
    pipeline = value
    rendererDiagnostic = nil
    rendererBackend = nil
    defaults.set(value.rawValue, forKey: Self.pipelinePreferenceKey)
    status = capability(for: value)?.reason ?? value.detail
    guard capability(for: value)?.available == true else { return }
    if let document {
      telemetry.overrideLoadMilliseconds = document.metrics.totalMilliseconds
      status =
        "Reusing one Open CASCADE import · \(document.faces.count) faces · \(document.triangleCount) triangles"
      return
    }
    let assemblyRecords = assemblyFileIDs.compactMap { id in files.first { $0.id == id } }
    if assemblyRecords.count > 1 {
      loadAssembly(assemblyRecords)
    } else if let selectedFile {
      load(selectedFile)
    } else {
      status = emptySelectionMessage(for: value)
    }
  }

  func setTheme(_ value: BenchTheme) {
    guard theme != value else { return }
    theme = value
    persistTheme()
    notifyThemeChanged()
    status = "Theme: \(value.name)"
  }

  func updateTheme(_ update: (inout BenchTheme) -> Void) {
    var value = theme
    update(&value)
    guard value != theme else { return }
    theme = value
    persistTheme()
    notifyThemeChanged()
    status = "Appearance: \(value.name) · Custom"
  }

  func resetTheme() {
    setTheme(BenchTheme.named(theme.name))
  }

  func load(_ record: BenchFileRecord) {
    guard capability(for: pipeline)?.available == true else {
      status = capability(for: pipeline)?.reason ?? pipeline.detail
      return
    }
    guard let url = record.url else {
      status = emptySelectionMessage(for: pipeline)
      return
    }
    guard pipeline.supportedFilenameExtensions.contains(url.pathExtension.lowercased()) else {
      status = "This pipeline benchmarks STEP B-Rep. Choose a .step or .stp file."
      return
    }
    isLoading = true
    status = "Reading STEP through Open CASCADE Technology Extended Data Exchange…"
    let requestID = UUID()
    activeLoadRequestID = requestID
    let securityAccess = url.startAccessingSecurityScopedResource()
    Task {
      defer { if securityAccess { url.stopAccessingSecurityScopedResource() } }
      do {
        let loaded = try await STEPImportQueue.shared.load(url)
        setRecordStatus(record.id, "Ready")
        guard activeLoadRequestID == requestID, selectedFileID == record.id else { return }
        document = loaded
        frame(document: loaded)
        status =
          "\(loaded.nodes.count) nodes · \(loaded.faces.count) faces · \(loaded.triangleCount) triangles"
        renderRevision += 1
      } catch {
        setRecordStatus(record.id, "Failed")
        guard activeLoadRequestID == requestID, selectedFileID == record.id else { return }
        status = error.localizedDescription
      }
      if activeLoadRequestID == requestID { isLoading = false }
    }
  }

  func loadAssembly(_ records: [BenchFileRecord]) {
    guard capability(for: pipeline)?.available == true else {
      status = capability(for: pipeline)?.reason ?? pipeline.detail
      return
    }
    let urls = records.compactMap(\.url)
    guard urls.count == records.count, urls.count > 1 else {
      if let first = records.first { load(first) }
      return
    }
    guard
      urls.allSatisfy({
        pipeline.supportedFilenameExtensions.contains(
          $0.pathExtension.lowercased())
      })
    else {
      status = "This assembly benchmark accepts only STEP or STP files."
      return
    }

    assemblyFileIDs = records.map(\.id)
    selectedFileID = records.first?.id
    isLoading = true
    status = "Reading \(urls.count) STEP parts through Open CASCADE Technology…"
    let requestID = UUID()
    activeLoadRequestID = requestID
    let accessedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
    Task {
      defer {
        for url in accessedURLs { url.stopAccessingSecurityScopedResource() }
      }
      do {
        let loaded = try await STEPImportQueue.shared.loadAssembly(urls)
        for record in records { setRecordStatus(record.id, "Ready") }
        guard activeLoadRequestID == requestID, assemblyFileIDs == records.map(\.id) else {
          return
        }
        document = loaded
        frame(document: loaded)
        status =
          "\(urls.count) parts · \(loaded.faces.count) faces · \(loaded.triangleCount) triangles"
        renderRevision += 1
      } catch {
        for record in records { setRecordStatus(record.id, "Failed") }
        guard activeLoadRequestID == requestID else { return }
        status = error.localizedDescription
      }
      if activeLoadRequestID == requestID { isLoading = false }
    }
  }

  func remove(_ record: BenchFileRecord) {
    files.removeAll { $0.id == record.id }
    if selectedFileID == record.id {
      selectedFileID = files.first?.id
      document = nil
      status = "Removed from benchmark workspace; the source file was not deleted."
      if let first = files.first { load(first) }
    }
  }

  func fitView() {
    if let document { frame(document: document) }
    renderRevision += 1
  }

  func tickFrame() { telemetry.recordFrames() }

  func tickFrames(_ count: Int) { telemetry.recordFrames(count) }

  func toggleModelSelection() {
    isModelSelected.toggle()
    renderRevision += 1
  }

  private var allowedContentTypes: [UTType] {
    pipeline.supportedFilenameExtensions.compactMap { UTType(filenameExtension: $0) }
  }

  private func frame(document: GeometryDocument) {
    let geometry = document.renderGeometry
    guard !geometry.positions.isEmpty else { return }
    camera.target = geometry.bounds.center
    camera.distance = max(geometry.bounds.diagonal * 1.6, 0.05)
    telemetry.overrideLoadMilliseconds = document.metrics.totalMilliseconds
  }

  private func setRecordStatus(_ id: BenchFileRecord.ID?, _ status: String) {
    guard let id, let index = files.firstIndex(where: { $0.id == id }) else { return }
    files[index].status = status
  }

  private func persistTheme() {
    defaults.set(theme.name, forKey: Self.themePreferenceKey)
    if let data = try? JSONEncoder().encode(theme) {
      defaults.set(data, forKey: Self.themeConfigurationKey)
    }
  }

  private func notifyThemeChanged() {
    renderRevision += 1
  }

  private static func loadPipelinePreference(from defaults: UserDefaults) -> PipelineID {
    guard defaults.object(forKey: pipelinePreferenceKey) != nil,
      let value = PipelineID(rawValue: defaults.integer(forKey: pipelinePreferenceKey))
    else { return .occtRealityKit }
    return value
  }

  private static func loadThemePreference(from defaults: UserDefaults) -> BenchTheme {
    if let data = defaults.data(forKey: themeConfigurationKey),
      let value = try? JSONDecoder().decode(BenchTheme.self, from: data),
      BenchTheme.all.contains(where: { $0.name == value.name })
    {
      return value
    }
    return BenchTheme.named(defaults.string(forKey: themePreferenceKey))
  }

  func capability(for pipeline: PipelineID) -> PipelineCapability? {
    capabilities.first { $0.pipeline == pipeline }
  }

  private func emptySelectionMessage(for pipeline: PipelineID) -> String {
    if capability(for: pipeline)?.available == false {
      return capability(for: pipeline)?.reason ?? pipeline.detail
    }
    return "Select or import one of your own STEP or STP files for Pipeline \(pipeline.rawValue)."
  }
}
