import Foundation

public enum AssemblyNodeKind: String, Codable, Sendable {
  case part
  case group
  case assembly
}

/// A renderer-neutral reference stored in a reusable `.animasm` document.
/// Part names are the stable bridge-facing identity; model fields are copied
/// along so an assembly can recreate missing Parts when its assets are present.
public struct AssemblyNodeReference: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var name: String
  public var kind: AssemblyNodeKind
  public var partName: String?
  public var modelReference: String?
  public var modelNode: String?
  public var children: [AssemblyNodeReference]

  public init(
    id: UUID = UUID(),
    name: String,
    kind: AssemblyNodeKind,
    partName: String? = nil,
    modelReference: String? = nil,
    modelNode: String? = nil,
    children: [AssemblyNodeReference] = []
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.partName = partName
    self.modelReference = modelReference
    self.modelNode = modelNode
    self.children = children
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case kind
    case partName = "part_name"
    case modelReference = "model_reference"
    case modelNode = "model_node"
    case children
  }
}

/// A first-class, versioned reusable assembly stored at
/// `assets/assemblies/<name>.animasm`.
public struct AnimaAssemblyDocument: Identifiable, Codable, Equatable, Sendable {
  public static let currentFormatVersion = "1"
  public static let supportedFormatVersions = [currentFormatVersion]

  public var formatVersion: String
  public var id: UUID
  public var name: String
  public var nodes: [AssemblyNodeReference]

  public init(
    formatVersion: String = Self.currentFormatVersion,
    id: UUID = UUID(),
    name: String,
    nodes: [AssemblyNodeReference]
  ) {
    self.formatVersion = formatVersion
    self.id = id
    self.name = name
    self.nodes = nodes
  }

  enum CodingKeys: String, CodingKey {
    case formatVersion = "format_version"
    case id
    case name
    case nodes
  }

  public static func decode(_ data: Data) throws -> Self {
    let decoder = JSONDecoder()
    if let probe = try? decoder.decode(VersionProbe.self, from: data),
      let formatVersion = probe.formatVersion
    {
      guard supportedFormatVersions.contains(formatVersion) else {
        throw AnimaDocumentError.unsupportedVersion(
          found: formatVersion,
          supported: supportedFormatVersions
        )
      }
      return try decoder.decode(Self.self, from: data)
    }

    // Migration for the demo's original `{version:1,name,nodes}` assembly
    // files. UI-only fields are discarded; names and hierarchy survive.
    let legacy = try decoder.decode(LegacyAssemblyDocument.self, from: data)
    return Self(
      name: legacy.name,
      nodes: legacy.nodes.map(AssemblyNodeReference.init(legacy:))
    )
  }

  public func encodedData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(self)
    data.append(0x0A)
    return data
  }

  private struct VersionProbe: Decodable {
    var formatVersion: String?

    enum CodingKeys: String, CodingKey {
      case formatVersion = "format_version"
    }
  }

  fileprivate struct LegacyAssemblyDocument: Decodable {
    var name: String
    var nodes: [LegacyNode]
  }

  fileprivate struct LegacyNode: Decodable {
    var id: UUID?
    var name: String
    var isFolder: Bool?
    var children: [LegacyNode]?
    var payload: UUID?
  }
}

extension AssemblyNodeReference {
  fileprivate init(legacy: AnimaAssemblyDocument.LegacyNode) {
    let children = (legacy.children ?? []).map(Self.init(legacy:))
    self.init(
      id: legacy.id ?? UUID(),
      name: legacy.name,
      kind: legacy.isFolder == true || !children.isEmpty ? .group : .part,
      partName: legacy.isFolder == true || !children.isEmpty ? nil : legacy.name,
      children: children
    )
  }
}

public struct AssemblyDocumentSummary: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var name: String
  public var url: URL
  public var nodeCount: Int

  public init(id: UUID, name: String, url: URL, nodeCount: Int) {
    self.id = id
    self.name = name
    self.url = url
    self.nodeCount = nodeCount
  }
}
