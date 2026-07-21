import AppKit
import UniformTypeIdentifiers

struct NativeImportPanelConfiguration: Equatable {
  let title: String
  let message: String
  let prompt: String
  let allowedFileExtensions: [String]
  let allowsMultipleSelection: Bool

  static let models = NativeImportPanelConfiguration(
    title: "Import 3D Models",
    message:
      "Choose \(ModelImportFormatSupport.operatorLabel) files. You will confirm the destination character before loading.",
    prompt: "Import",
    allowedFileExtensions: ModelImportFormatSupport.supportedFileExtensions,
    allowsMultipleSelection: true
  )

  static let animaCharacter = NativeImportPanelConfiguration(
    title: "Import Anima Character",
    message: "Choose a canonical .character.anima file to load through AnimaCore.",
    prompt: "Import Character",
    allowedFileExtensions: ["anima"],
    allowsMultipleSelection: false
  )

  var allowedContentTypes: [UTType] {
    allowedFileExtensions.map { fileExtension in
      UTType(filenameExtension: fileExtension)
        ?? UTType(importedAs: "org.animastudio.import.\(fileExtension)")
    }
  }
}

@MainActor
enum NativeImportPanel {
  static func chooseFiles(
    configuration: NativeImportPanelConfiguration
  ) -> [URL]? {
    let panel = NSOpenPanel()
    panel.title = configuration.title
    panel.message = configuration.message
    panel.prompt = configuration.prompt
    panel.allowedContentTypes = configuration.allowedContentTypes
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = configuration.allowsMultipleSelection
    panel.resolvesAliases = true

    guard panel.runModal() == .OK else { return nil }
    return panel.urls
  }
}
