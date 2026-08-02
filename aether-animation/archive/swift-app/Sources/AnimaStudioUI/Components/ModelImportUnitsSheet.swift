import AnimaDocument
import SwiftUI

enum ModelImportUnit: String, CaseIterable, Identifiable, Sendable {
  case millimeters
  case centimeters
  case inches
  case meters

  var id: Self { self }

  var label: String {
    switch self {
    case .millimeters: "Millimeters (mm)"
    case .centimeters: "Centimeters (cm)"
    case .inches: "Inches (in)"
    case .meters: "Meters (m)"
    }
  }

  var scaleToMeters: Double {
    switch self {
    case .millimeters: 0.001
    case .centimeters: 0.01
    case .inches: 0.0254
    case .meters: 1
    }
  }

  /// Best-effort length unit read from a STEP file's `LENGTH_UNIT` declaration.
  /// ponytail: scans the first 256 KB of text; compressed/binary STEP returns
  /// nil and the caller defaults to millimeters.
  static func detectedSTEPUnit(at url: URL) -> ModelImportUnit? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    guard let data = try? handle.read(upToCount: 262_144) else { return nil }
    let text = (String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1))?
      .uppercased()
    guard let text else { return nil }
    // Conversion-based inch units are unambiguous; check before the SI base
    // (an inch STEP also declares .MILLI. .METRE. as the conversion base).
    if text.contains("'INCH'") || text.contains(".INCH.") { return .inches }
    if text.contains(".CENTI."), text.contains(".METRE.") { return .centimeters }
    if text.contains(".MILLI."), text.contains(".METRE.") { return .millimeters }
    if text.contains(".METRE.") { return .meters }
    return nil
  }
}

struct ModelImportRequest: Identifiable, Equatable, Sendable {
  let url: URL
  var unit: ModelImportUnit

  var id: URL { url }
  var isUnitless: Bool {
    ["stl", "obj"].contains(url.pathExtension.lowercased())
  }
  var isCAD: Bool {
    ["step", "stp"].contains(url.pathExtension.lowercased())
  }
  var allowsUnitSelection: Bool { isUnitless || isCAD }

  /// Units offered for this file. CAD parts are mm/cm/inch — no real CAD part
  /// is authored in meters — while a unitless mesh offers the full set.
  var availableUnits: [ModelImportUnit] {
    isCAD ? [.millimeters, .centimeters, .inches] : ModelImportUnit.allCases
  }

  var unitDescription: String {
    if isCAD { return "Units read from STEP (adjustable)" }
    if isUnitless { return "Unitless mesh" }
    return "Units embedded in file"
  }

  static func staged(url: URL, defaults: UserDefaults = .standard) -> Self {
    let preferredUnit =
      ModelImportUnit(
        rawValue: defaults.string(forKey: StudioPreferenceKey.projectDefaultImportUnit) ?? ""
      ) ?? .millimeters
    let ext = url.pathExtension.lowercased()
    let unit: ModelImportUnit
    if ["stl", "obj"].contains(ext) {
      unit = preferredUnit
    } else if ["step", "stp"].contains(ext) {
      // Auto-select from the file; meters is not offered for CAD, so fall back
      // to millimeters (the STEP default) when detection is ambiguous.
      let detected = ModelImportUnit.detectedSTEPUnit(at: url) ?? .millimeters
      unit = detected == .meters ? .millimeters : detected
    } else {
      unit = .meters
    }
    return Self(url: url, unit: unit)
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
  let importMode: AssetImportMode
}

struct ModelImportUnitsSheet: View {
  let urls: [URL]
  let characters: [ProjectCharacterReference]
  let canCopyIntoProject: Bool
  let isReplacingPart: Bool
  let cancel: () -> Void
  let importModels: (ModelImportStagingPlan) -> Void

  @State private var requests: [ModelImportRequest]
  @State private var targetCharacterID: String
  @State private var importMode: AssetImportMode

  init(
    urls: [URL],
    characters: [ProjectCharacterReference],
    initialTargetCharacterID: String?,
    canCopyIntoProject: Bool = true,
    isReplacingPart: Bool = false,
    cancel: @escaping () -> Void,
    importModels: @escaping (ModelImportStagingPlan) -> Void
  ) {
    self.urls = urls
    self.characters = characters
    self.canCopyIntoProject = canCopyIntoProject
    self.isReplacingPart = isReplacingPart
    self.cancel = cancel
    self.importModels = importModels
    _requests = State(
      initialValue: urls.map { ModelImportRequest.staged(url: $0) }
    )
    _targetCharacterID = State(
      initialValue: characters.contains(where: { $0.id == initialTargetCharacterID })
        ? initialTargetCharacterID ?? ""
        : characters.first?.id ?? ""
    )
    _importMode = State(initialValue: canCopyIntoProject ? .copyIntoProject : .referenceInPlace)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label(
        isReplacingPart ? "Replace Character Part" : "Import Character Parts",
        systemImage: "shippingbox.and.arrow.backward"
      )
      .font(.title3.weight(.semibold))

      Text(
        "Review the destination and source files before loading. Studio copies each model into one Character without moving or changing the original, then creates rigid Parts that can be positioned and mated in Rig."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      workflowStrip

      destinationSection

      storageSection

      ScrollView {
        VStack(spacing: 8) {
          ForEach($requests) { $request in
            HStack(spacing: 12) {
              Image(systemName: request.allowsUnitSelection ? "ruler" : "cube.transparent")
                .foregroundStyle(request.allowsUnitSelection ? .orange : StudioPalette.sourceModel)
                .frame(width: 20)
              VStack(alignment: .leading, spacing: 2) {
                Text(request.url.lastPathComponent)
                  .font(.callout.weight(.medium))
                  .lineLimit(1)
                Text(request.partCreationDetail)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text(request.unitDescription)
                  .font(.caption2)
                  .foregroundStyle(StudioPalette.muted)
              }
              Spacer()
              if request.allowsUnitSelection {
                Picker("Source units", selection: $request.unit) {
                  ForEach(request.availableUnits) { unit in
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
              requests: requests,
              importMode: canCopyIntoProject ? importMode : .referenceInPlace
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

  private var storageSection: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("FILE STORAGE")
        .font(.caption2.weight(.bold))
        .tracking(0.8)
        .foregroundStyle(StudioPalette.muted)
      Picker("File storage", selection: $importMode) {
        Text("Copy into Project").tag(AssetImportMode.copyIntoProject)
        Text("Reference in Place").tag(AssetImportMode.referenceInPlace)
      }
      .pickerStyle(.segmented)
      .disabled(!canCopyIntoProject)

      Label(storageExplanation, systemImage: storageIcon)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.border))
  }

  private var storageExplanation: String {
    guard canCopyIntoProject else {
      return
        "No project is open, so Studio must reference the original file. Create or open a project to make a portable copy."
    }
    switch importMode {
    case .copyIntoProject:
      return
        "Recommended. Studio copies the source into assets/models/ for a portable Pack-and-Go project. The original stays untouched."
    case .referenceInPlace:
      return
        "Studio bookmarks the original file. This saves disk space, but the project will need relinking if the source moves."
    }
  }

  private var storageIcon: String {
    importMode == .copyIntoProject ? "doc.on.doc" : "link"
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
        Label("Project asset", systemImage: "folder.badge.gearshape")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      Text(
        isReplacingPart
          ? "The replacement stays assigned to the selected Part and retains its stable asset identity."
          : "The model becomes a Part of this Character; its file storage is selected below."
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
