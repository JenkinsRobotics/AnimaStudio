import AnimaModel
import Foundation

/// Renderer-owned geometry source for one engine part.
///
/// The model path and node are authored in `.character.anima`; the unit scale
/// is app-only import metadata for unitless STL/OBJ files.
public struct PartModelSource: Equatable, Sendable {
  public let partID: PartID
  public let fileURL: URL
  public let modelNode: String?
  public let unitScaleToMeters: Double

  public init(
    partID: PartID,
    fileURL: URL,
    modelNode: String? = nil,
    unitScaleToMeters: Double = 1
  ) {
    self.partID = partID
    self.fileURL = fileURL
    self.modelNode = modelNode
    self.unitScaleToMeters = unitScaleToMeters
  }
}
