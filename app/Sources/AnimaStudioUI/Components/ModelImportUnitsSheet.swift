import AnimaDocument
import SwiftUI

enum ModelImportUnit: String, CaseIterable, Identifiable, Sendable {
  case millimeters
  case centimeters
  case meters

  var id: Self { self }

  var label: String {
    switch self {
    case .millimeters: "Millimeters (mm)"
    case .centimeters: "Centimeters (cm)"
    case .meters: "Meters (m)"
    }
  }

  var scaleToMeters: Double {
    switch self {
    case .millimeters: 0.001
    case .centimeters: 0.01
    case .meters: 1
    }
  }
}

struct ModelImportRequest: Identifiable, Equatable, Sendable {
  let url: URL
  var unit: ModelImportUnit

  var id: URL { url }
  var isUnitless: Bool {
    ["stl", "obj"].contains(url.pathExtension.lowercased())
  }

  static func staged(url: URL) -> Self {
    Self(
      url: url,
      unit: url.pathExtension.lowercased() == "stl" ? .millimeters : .meters
    )
  }

  var partCreationDetail: String {
    switch url.pathExtension.lowercased() {
    case "step", "stp":
      "Open CASCADE assembly nodes become rigid Parts"
    case "usd", "usda", "usdc", "usdz":
      "Renderable nodes become rigid Parts"
    default:
      "File becomes one rigid Part"
    }
  }
}

struct ModelImportStagingPlan: Equatable, Sendable {
  let targetCharacterID: String
  let requests: [ModelImportRequest]
}

struct ModelImportUnitsSheet: View {
  let urls: [URL]
  let characters: [ProjectCharacterReference]
  let isReplacingPart: Bool
  let cancel: () -> Void
  let importModels: (ModelImportStagingPlan) -> Void

  @State private var requests: [ModelImportRequest]
  @State private var targetCharacterID: String

  init(
    urls: [URL],
    characters: [ProjectCharacterReference],
    initialTargetCharacterID: String?,
    isReplacingPart: Bool = false,
    cancel: @escaping () -> Void,
    importModels: @escaping (ModelImportStagingPlan) -> Void
  ) {
    self.urls = urls
    self.characters = characters
    self.isReplacingPart = isReplacingPart
    self.cancel = cancel
    self.importModels = importModels
    _requests = State(
      initialValue: urls.map(ModelImportRequest.staged)
    )
    _targetCharacterID = State(
      initialValue: characters.contains(where: { $0.id == initialTargetCharacterID })
        ? initialTargetCharacterID ?? ""
        : characters.first?.id ?? ""
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label(
        isReplacingPart ? "Replace Character Part" : "Import Character Parts",
        systemImage: "shippingbox.and.arrow.backward"
      )
      .font(.title3.weight(.semibold))

      Text(
        "Review the destination and source files before loading. Imported files are stored as assets inside one character, then represented by rigid Parts that can be positioned and mated in Rig."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      workflowStrip

      destinationSection

      ScrollView {
        VStack(spacing: 8) {
          ForEach($requests) { $request in
            HStack(spacing: 12) {
              Image(systemName: request.isUnitless ? "ruler" : "cube.transparent")
                .foregroundStyle(request.isUnitless ? .orange : StudioPalette.sourceModel)
                .frame(width: 20)
              VStack(alignment: .leading, spacing: 2) {
                Text(request.url.lastPathComponent)
                  .font(.callout.weight(.medium))
                  .lineLimit(1)
                Text(request.partCreationDetail)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text(request.isUnitless ? "Unitless mesh" : "Units embedded in file")
                  .font(.caption2)
                  .foregroundStyle(StudioPalette.muted)
              }
              Spacer()
              if request.isUnitless {
                Picker("Source units", selection: $request.unit) {
                  ForEach(ModelImportUnit.allCases) { unit in
                    Text(unit.label).tag(unit)
                  }
                }
                .labelsHidden()
                .frame(width: 175)
              } else {
                Text("Meters")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
              }
            }
            .padding(10)
            .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
      .frame(maxHeight: 300)

      HStack {
        Label("Initial part frame: Character origin", systemImage: "scope")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Cancel", role: .cancel, action: cancel)
          .keyboardShortcut(.cancelAction)
        Button(importActionTitle) {
          importModels(
            ModelImportStagingPlan(
              targetCharacterID: targetCharacterID,
              requests: requests
            )
          )
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(targetCharacterID.isEmpty || requests.isEmpty)
      }
    }
    .padding(24)
    .frame(width: 620)
  }

  private var workflowStrip: some View {
    HStack(spacing: 8) {
      workflowStep(number: 1, title: "Import Parts", active: true)
      Image(systemName: "chevron.right").foregroundStyle(.tertiary)
      workflowStep(number: 2, title: "Assemble + Mate", active: false)
      Image(systemName: "chevron.right").foregroundStyle(.tertiary)
      workflowStep(number: 3, title: "Animate", active: false)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Workflow step 1 of 3, Import Parts")
  }

  private func workflowStep(number: Int, title: String, active: Bool) -> some View {
    HStack(spacing: 6) {
      Text("\(number)")
        .font(.caption2.bold())
        .frame(width: 19, height: 19)
        .background(active ? StudioPalette.sourceModel : StudioPalette.panelInset, in: Circle())
      Text(title)
        .font(.caption.weight(active ? .semibold : .regular))
    }
    .foregroundStyle(active ? Color.white : StudioPalette.muted)
    .padding(.horizontal, 9)
    .frame(height: 31)
    .background(
      active ? StudioPalette.sourceModel.opacity(0.14) : StudioPalette.panel,
      in: Capsule()
    )
    .overlay(
      Capsule().stroke(active ? StudioPalette.sourceModel.opacity(0.7) : StudioPalette.border))
  }

  private var destinationSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("DESTINATION CHARACTER")
        .font(.caption2.weight(.bold))
        .tracking(0.8)
        .foregroundStyle(StudioPalette.muted)
      HStack(spacing: 10) {
        Image(systemName: "person.crop.rectangle.stack")
          .foregroundStyle(StudioPalette.sourceModel)
        Picker("Character", selection: $targetCharacterID) {
          ForEach(characters) { character in
            Text(character.displayName).tag(character.id)
          }
        }
        .labelsHidden()
        .disabled(isReplacingPart)
        Spacer()
        Text("assets/ → Parts")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      Text(
        isReplacingPart
          ? "Replacement stays assigned to the selected Part in this character."
          : "The source files and generated Parts belong to this character. You can organize and mate them after import."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.border))
  }

  private var importActionTitle: String {
    if isReplacingPart { return "Replace Part" }
    guard let target = characters.first(where: { $0.id == targetCharacterID }) else {
      return "Import Parts"
    }
    return "Add \(requests.count) to \(target.displayName)"
  }
}
