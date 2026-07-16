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

struct ModelImportUnitsSheet: View {
  let filename: String
  let defaultUnit: ModelImportUnit
  let cancel: () -> Void
  let importModel: (ModelImportUnit) -> Void

  @State private var selectedUnit: ModelImportUnit

  init(
    filename: String,
    defaultUnit: ModelImportUnit,
    cancel: @escaping () -> Void,
    importModel: @escaping (ModelImportUnit) -> Void
  ) {
    self.filename = filename
    self.defaultUnit = defaultUnit
    self.cancel = cancel
    self.importModel = importModel
    _selectedUnit = State(initialValue: defaultUnit)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label("Model Units", systemImage: "ruler")
        .font(.title3.weight(.semibold))

      Text(
        "STL and OBJ files do not declare physical units. Choose the units used when \(filename) was exported. Anima converts geometry to meters."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      Picker("Source units", selection: $selectedUnit) {
        ForEach(ModelImportUnit.allCases) { unit in
          Text(unit.label).tag(unit)
        }
      }
      .pickerStyle(.radioGroup)

      HStack {
        Text("Scale to meters")
          .foregroundStyle(.secondary)
        Spacer()
        Text(selectedUnit.scaleToMeters.formatted(.number.precision(.fractionLength(3...6))))
          .monospacedDigit()
      }
      .font(.caption)

      HStack {
        Spacer()
        Button("Cancel", role: .cancel, action: cancel)
          .keyboardShortcut(.cancelAction)
        Button("Import") { importModel(selectedUnit) }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(width: 430)
  }
}
