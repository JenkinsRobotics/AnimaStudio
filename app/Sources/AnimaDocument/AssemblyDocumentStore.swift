import Foundation

public struct AssemblyDocumentStore: Sendable {
  public init() {}

  @discardableResult
  public func save(
    _ document: AnimaAssemblyDocument,
    in projectURL: URL
  ) throws -> URL {
    try AnimaDocumentStore.ensureProjectDirectories(at: projectURL)
    let filename = Self.safeFilename(document.name) + ".animasm"
    let url =
      projectURL
      .appendingPathComponent(
        ProjectAssetFolder.assemblies.relativeDirectoryPath, isDirectory: true
      )
      .appendingPathComponent(filename)
    do {
      try document.encodedData().write(to: url, options: .atomic)
    } catch let error as AnimaDocumentError {
      throw error
    } catch {
      throw AnimaDocumentError.writeFailed(path: url.path, detail: error.localizedDescription)
    }
    return url
  }

  public func load(from url: URL) throws -> AnimaAssemblyDocument {
    do {
      return try AnimaAssemblyDocument.decode(Data(contentsOf: url))
    } catch let error as AnimaDocumentError {
      throw error
    } catch {
      throw AnimaDocumentError.corruptManifest(path: url.path, detail: error.localizedDescription)
    }
  }

  public func list(in projectURL: URL) throws -> [AssemblyDocumentSummary] {
    try AnimaDocumentStore.ensureProjectDirectories(at: projectURL)
    let directory = projectURL.appendingPathComponent(
      ProjectAssetFolder.assemblies.relativeDirectoryPath,
      isDirectory: true
    )
    let urls = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    return
      try urls
      .filter { $0.pathExtension.lowercased() == "animasm" }
      .map { url in
        let document = try load(from: url)
        return AssemblyDocumentSummary(
          id: document.id,
          name: document.name,
          url: url,
          nodeCount: Self.recursiveNodeCount(document.nodes)
        )
      }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private static func safeFilename(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let sanitized = (trimmed.isEmpty ? "Assembly" : trimmed)
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
    return sanitized == "." || sanitized == ".." ? "Assembly" : sanitized
  }

  private static func recursiveNodeCount(_ nodes: [AssemblyNodeReference]) -> Int {
    nodes.reduce(0) { $0 + 1 + recursiveNodeCount($1.children) }
  }
}
