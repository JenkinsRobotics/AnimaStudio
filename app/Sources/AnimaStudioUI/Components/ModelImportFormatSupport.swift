import Foundation
import UniformTypeIdentifiers

enum ModelImportFormatSupport {
  static let supportedFileExtensions = ["usd", "usda", "usdc", "usdz", "stl", "obj"]
  static let operatorLabel = "USD · USDA · USDC · USDZ · STL · OBJ"

  static var contentTypes: [UTType] {
    supportedFileExtensions.compactMap { UTType(filenameExtension: $0) }
  }

  static func supports(_ url: URL) -> Bool {
    supportedFileExtensions.contains(url.pathExtension.lowercased())
  }
}
