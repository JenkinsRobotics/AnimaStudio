import Foundation
import UniformTypeIdentifiers

enum ModelImportFormatSupport {
  /// STEP is intentionally first: it is Studio's preferred CAD assembly
  /// source and is read with the Open CASCADE/XDE pipeline.
  static let supportedFileExtensions = [
    "step", "stp", "usd", "usda", "usdc", "usdz", "stl", "obj",
  ]
  static let operatorLabel = "STEP · STP · USD · USDA · USDC · USDZ · STL · OBJ"

  static var contentTypes: [UTType] {
    supportedFileExtensions.compactMap { UTType(filenameExtension: $0) }
  }

  static func supports(_ url: URL) -> Bool {
    supportedFileExtensions.contains(url.pathExtension.lowercased())
  }
}
