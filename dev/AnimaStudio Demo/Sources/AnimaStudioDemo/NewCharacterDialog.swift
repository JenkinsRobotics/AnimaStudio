// New Character sheet — mirrors the AnimaStudio dialog: a project-local
// Character you can later publish to the Character Library for reuse.
import Foundation
import SwiftUI

enum CharacterKind: String, CaseIterable, Identifiable {
  case threeD, twoD
  var id: String { rawValue }
  var title: String { self == .threeD ? "3D Character" : "2D (Live2D-style)" }
  var detail: String {
    self == .threeD
      ? "An assembly of rigid model parts connected with mates."
      : "Layered 2D character authoring — coming later."
  }
  var icon: String { self == .threeD ? "cube" : "square.3.layers.3d" }
  var available: Bool { self == .threeD }
}

struct NewCharacterDialog: View {
  var onCreate: (String) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var kind: CharacterKind = .threeD

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "person.crop.square.filled.and.at.rectangle")
          .font(.system(size: 17)).foregroundStyle(UI.accent)
          .frame(width: 34, height: 34)
          .background(UI.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 3) {
          Text("New Character").font(.system(size: 15, weight: .semibold))
          Text("Creates a project-local Character. Publish it to the Character Library to reuse it.")
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("NAME").font(.system(size: 9.5, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
        TextField("Character name", text: $name)
          .textFieldStyle(.roundedBorder).controlSize(.large)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("CHARACTER TYPE").font(.system(size: 9.5, weight: .bold)).tracking(0.6)
          .foregroundStyle(.secondary)
        ForEach(CharacterKind.allCases) { option in kindRow(option) }
      }

      HStack(alignment: .top, spacing: 7) {
        Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.secondary)
        Text("The current 3D pipeline is for rigid parts and mates. Skinned meshes and skeletons are not supported yet.")
          .font(.system(size: 10.5)).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack {
        Spacer()
        Button("Cancel") { dismiss() }
        Button("Create") {
          onCreate(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Character" : name)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(20)
    .frame(width: 470)
  }

  private func kindRow(_ option: CharacterKind) -> some View {
    Button { if option.available { kind = option } } label: {
      HStack(spacing: 12) {
        Image(systemName: option.icon).font(.system(size: 15))
          .foregroundStyle(option.available ? UI.accent : .secondary)
          .frame(width: 26)
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 7) {
            Text(option.title).font(.system(size: 12.5, weight: .semibold))
              .foregroundStyle(option.available ? .primary : .secondary)
            if !option.available { Badge(text: "coming later", tint: UI.text3) }
          }
          Text(option.detail).font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
        Spacer(minLength: 4)
        Image(systemName: kind == option ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(kind == option ? UI.accent : .secondary)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(kind == option ? UI.accent.opacity(0.12) : Color.primary.opacity(0.04),
        in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10)
        .stroke(kind == option ? UI.accent : Color.primary.opacity(0.10), lineWidth: 1))
    }
    .buttonStyle(.plain)
    .disabled(!option.available)
    .opacity(option.available ? 1 : 0.55)
  }
}

/// Characters published for reuse across projects.
@MainActor
enum CharacterLibrary {
  static var url: URL {
    StudioProject.defaultRoot.appendingPathComponent("Character Library", isDirectory: true)
  }

  @discardableResult
  static func publish(_ character: Character) throws -> URL {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let file = url.appendingPathComponent("\(character.name).animachar")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(character).write(to: file, options: .atomic)
    return file
  }

  static func list() -> [URL] {
    (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil))?
      .filter { $0.pathExtension == "animachar" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
      ?? []
  }

  static func load(_ file: URL) throws -> Character {
    try JSONDecoder().decode(Character.self, from: Data(contentsOf: file))
  }
}
