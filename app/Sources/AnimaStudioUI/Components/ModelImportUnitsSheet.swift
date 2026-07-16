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
}

struct ModelImportUnitsSheet: View {
  let urls: [URL]
  let cancel: () -> Void
  let importModels: ([ModelImportRequest]) -> Void

  @State private var requests: [ModelImportRequest]

  init(
    urls: [URL],
    cancel: @escaping () -> Void,
    importModels: @escaping ([ModelImportRequest]) -> Void
  ) {
    self.urls = urls
    self.cancel = cancel
    self.importModels = importModels
    _requests = State(
      initialValue: urls.map { url in
        ModelImportRequest(
          url: url,
          unit: url.pathExtension.lowercased() == "stl" ? .millimeters : .meters
        )
      }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label("Model Units", systemImage: "ruler")
        .font(.title3.weight(.semibold))

      Text(
        "Review the files before loading. STL and OBJ do not declare physical units, so choose the units used when each file was exported. Anima converts geometry to meters."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

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
                Text(request.isUnitless ? "Unitless mesh" : "Units embedded in file")
                  .font(.caption)
                  .foregroundStyle(.secondary)
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
        Spacer()
        Button("Cancel", role: .cancel, action: cancel)
          .keyboardShortcut(.cancelAction)
        Button("Import \(requests.count) File\(requests.count == 1 ? "" : "s")") {
          importModels(requests)
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(width: 560)
  }
}
