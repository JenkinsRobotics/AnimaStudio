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

  static let images = NativeImportPanelConfiguration(
    title: "Import Images",
    message: "Choose image files (PNG, JPEG, GIF, WebP, etc.).",
    prompt: "Import",
    allowedFileExtensions: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic"],
    allowsMultipleSelection: true
  )

  static let audio = NativeImportPanelConfiguration(
    title: "Import Audio",
    message: "Choose audio files (WAV, AIFF, MP3, M4A, etc.).",
    prompt: "Import",
    allowedFileExtensions: ["wav", "aiff", "aif", "mp3", "m4a", "aac", "caf", "flac"],
    allowsMultipleSelection: true
  )

  static let video = NativeImportPanelConfiguration(
    title: "Import Video",
    message: "Choose video files (MP4, MOV, M4V, etc.).",
    prompt: "Import",
    allowedFileExtensions: ["mp4", "mov", "m4v", "avi", "mkv", "webm"],
    allowsMultipleSelection: true
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
