import Foundation

/// App-only rendering metadata stored beside one canonical character file.
/// Mesh unit interpretation is deliberately absent from `.character.anima`;
/// the engine treats model references as opaque paths.
public struct CharacterEditorMetadata: Codable, Equatable, Sendable {
  public static let currentFormatVersion = "1"

  public var formatVersion: String
  public var modelImports: [String: ModelImportMetadata]

  public init(
    formatVersion: String = Self.currentFormatVersion,
    modelImports: [String: ModelImportMetadata] = [:]
  ) {
    self.formatVersion = formatVersion
    self.modelImports = modelImports
  }

  enum CodingKeys: String, CodingKey {
    case formatVersion = "format_version"
    case modelImports = "model_imports"
  }

  public static func decode(_ data: Data) throws -> Self {
    try JSONDecoder().decode(Self.self, from: data)
  }

  public func encodedData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(self)
    data.append(0x0A)
    return data
  }
}

public struct ModelImportMetadata: Codable, Equatable, Sendable {
  public var unitName: String
  public var unitScaleToMeters: Double

  public init(unitName: String, unitScaleToMeters: Double) {
    self.unitName = unitName
    self.unitScaleToMeters = unitScaleToMeters
  }
}
