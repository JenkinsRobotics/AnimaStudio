// Live inspector for an authored mate. `MateInspector` is the reusable widget
// (bindable — the UI Kit renders it with a sample mate); `MateInspectorHost`
// binds it to the real rig state.
import SwiftUI

struct MateInspector: View {
  @Binding var mate: Mate
  var parentName: String
  var childName: String
  var onDelete: () -> Void = {}

  private var range: ClosedRange<Double> {
    let lo = Swift.min(mate.minValue, mate.maxValue)
    let hi = Swift.max(mate.minValue, mate.maxValue)
    return lo < hi ? lo...hi : lo...(lo + 1)
  }

  var body: some View {
    PanelCard(title: mate.name, subtitle: mate.type.label, icon: mate.type.icon, tint: UI.accent) {
      VStack(alignment: .leading, spacing: 11) {
        PropertyField(label: "Parent", value: parentName)
        PropertyField(label: "Child", value: childName)

        HStack {
          Text("Axis").font(.system(size: 9.5)).foregroundStyle(UI.text3)
          Spacer()
          Picker("", selection: $mate.axis) {
            ForEach(MateAxis.allCases) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented).labelsHidden().frame(width: 118)
        }

        if mate.type.isDriven {
          Divider().overlay(UI.stroke)
          LabeledSlider(label: "Value", value: $mate.value, range: range, unit: mate.type.unit)
          HStack(spacing: 8) {
            StepperField(label: "Min", value: $mate.minValue, step: 5, unit: mate.type.unit)
            StepperField(label: "Max", value: $mate.maxValue, step: 5, unit: mate.type.unit)
          }
        } else {
          Text("\(mate.type.label) mates have no driven axis.")
            .font(.system(size: 9.5)).foregroundStyle(UI.text3)
        }

        Divider().overlay(UI.stroke)
        Button(action: onDelete) {
          HStack(spacing: 6) { Image(systemName: "trash"); Text("Delete mate") }
            .font(.system(size: 11.5, weight: .medium)).foregroundStyle(UI.danger)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(UI.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
      }
      .padding(12)
    }
  }
}

struct MateInspectorHost: View {
  @Bindable private var rig = RigModel.shared

  var body: some View {
    if let index = rig.mates.firstIndex(where: { $0.id == rig.selectedMateID }) {
      let mate = rig.mates[index]
      MateInspector(
        mate: $rig.mates[index],
        parentName: rig.partName(mate.parent),
        childName: rig.partName(mate.child),
        onDelete: { rig.removeMate(mate.id) })
    }
  }
}
