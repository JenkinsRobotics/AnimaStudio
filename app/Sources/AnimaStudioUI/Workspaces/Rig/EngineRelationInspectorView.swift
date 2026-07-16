import AnimaCoreClient
import SwiftUI

struct EngineRelationInspectorView: View {
  let relation: AnimaCoreRelationSummary
  let relationType: AnimaCoreRelationTypeSummary?

  private var label: String {
    relationType?.label
      ?? relation.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
  }

  private var fieldTitle: String {
    relationType.map { RelationEditorPresentation(type: $0).fieldTitle }
      ?? "Relation value"
  }

  var body: some View {
    Section("Advanced Relation") {
      Label(label, systemImage: relation.kind.systemImage)
        .foregroundStyle(StudioPalette.joint)
      LabeledContent("Driver", value: relation.driver)
      LabeledContent("Driven", value: relation.driven)
      if let relationType {
        LabeledContent(
          "Compatibility",
          value: RelationEditorPresentation(type: relationType).compatibilitySummary
        )
      }
    }

    Section("Relationship") {
      StudioReadoutRow(
        title: fieldTitle,
        value: relation.ratioFieldValue.formatted(.number.precision(.fractionLength(3))),
        unit: relationType?.ratioField.unit == "ratio" ? nil : relationType?.ratioField.unit
      )
      LabeledContent("Reverse direction", value: relation.isReversed ? "On" : "Off")
      StudioReadoutRow(
        title: "Signed ratio",
        value: relation.ratio.formatted(.number.precision(.fractionLength(6))),
        unit: nativeUnit
      )
      StudioReadoutRow(
        title: "Driven offset",
        value: relation.offset.formatted(.number.precision(.fractionLength(6))),
        unit: relationType?.drivenKind == .translation ? "m" : "rad"
      )
    }

    if !relation.display.isEmpty {
      Section("Reference Geometry") {
        ForEach(relation.display.keys.sorted(), id: \.self) { key in
          LabeledContent(
            key.replacingOccurrences(of: "_", with: " ").capitalized,
            value: relation.display[key, default: 0].formatted(
              .number.precision(.fractionLength(3))
            )
          )
        }
      }
    }

    Section("Engine Contract") {
      Label("Evaluated by AnimaCore", systemImage: "checkmark.shield.fill")
        .foregroundStyle(StudioPalette.hardware)
      Text(
        "The two coupled mate components are highlighted in the viewport. Ratio sign, dependency ordering, motion, and limit violations remain engine-owned."
      )
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
    }
  }

  private var nativeUnit: String? {
    guard let relationType else { return nil }
    return switch (relationType.driverKind, relationType.drivenKind) {
    case (.rotation, .translation): "m/rad"
    default: nil
    }
  }
}
