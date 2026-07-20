// Node-graph and input widgets ported from CodexUI's kit (PrototypeNodeCard,
// node library, search/stepper inputs, axis gizmo, inspector tabs), restyled
// with our UI.* tokens. Standalone — ready to wire into Nodes/Show/Rig later.
import SwiftUI

// Typed logic node — category subtitle, colored accent, named input/output
// ports, selection + warning states. (CodexUI PrototypeNodeCard.)
struct LogicNode: View {
  let title: String
  let subtitle: String
  let icon: String
  let color: Color
  var inputs: [String] = []
  var outputs: [String] = []
  var selected = false
  var warning = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: icon).font(.system(size: 12)).foregroundStyle(color)
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(UI.text)
          Text(subtitle.uppercased()).font(.system(size: 8, weight: .bold)).tracking(0.5)
            .foregroundStyle(color)
        }
        Spacer(minLength: 6)
        Image(systemName: warning ? "exclamationmark.triangle.fill" : "ellipsis")
          .font(.system(size: 10)).foregroundStyle(warning ? UI.warn : UI.text3)
      }
      .padding(9)
      .background(UI.panelHi)

      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 7) {
          ForEach(inputs, id: \.self) { port in
            HStack(spacing: 5) {
              Circle().fill(UI.text3).frame(width: 6, height: 6)
              Text(port).font(.system(size: 8.5)).foregroundStyle(UI.text3)
            }
          }
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 7) {
          ForEach(outputs, id: \.self) { port in
            HStack(spacing: 5) {
              Text(port).font(.system(size: 8.5)).foregroundStyle(UI.text3)
              Circle().fill(color).frame(width: 6, height: 6)
            }
          }
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(width: 196)
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
      .stroke(selected ? UI.accent : color.opacity(0.35), lineWidth: selected ? 2 : 1))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

// A row in the node library palette — the node types you can add to a graph.
struct NodeLibraryRow: View {
  let title: String
  let category: String
  let icon: String
  let color: Color
  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: icon).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
        .frame(width: 24, height: 24)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.system(size: 11.5)).foregroundStyle(UI.text)
        Text(category.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(0.4)
          .foregroundStyle(UI.text3)
      }
      Spacer(minLength: 6)
      Image(systemName: "plus.circle").font(.system(size: 11)).foregroundStyle(UI.text3)
    }
    .padding(.horizontal, 10).padding(.vertical, 7)
    .contentShape(Rectangle())
  }
}

// Search / filter input.
struct SearchField: View {
  var placeholder = "Filter items"
  @Binding var text: String
  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(UI.text3)
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain).font(.system(size: 11.5)).foregroundStyle(UI.text)
      if !text.isEmpty {
        Button { text = "" } label: {
          Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(UI.text3)
        }.buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 10).padding(.vertical, 7)
    .background(UI.inset, in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(UI.stroke, lineWidth: 1))
  }
}

// Numeric field with −/+ steppers.
struct StepperField: View {
  let label: String
  @Binding var value: Double
  var step: Double = 1
  var unit: String = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.system(size: 9.5)).foregroundStyle(UI.text3)
      HStack(spacing: 0) {
        stepButton("minus") { value -= step }
        Divider().frame(height: 20).overlay(UI.stroke)
        HStack(spacing: 3) {
          Text(String(format: "%.1f", value))
            .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(UI.text)
          if !unit.isEmpty { Text(unit).font(.system(size: 9.5)).foregroundStyle(UI.text3) }
        }
        .frame(maxWidth: .infinity)
        Divider().frame(height: 20).overlay(UI.stroke)
        stepButton("plus") { value += step }
      }
      .background(UI.inset, in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(UI.stroke, lineWidth: 1))
    }
  }

  private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(UI.text2)
        .frame(width: 28, height: 30).contentShape(Rectangle())
    }.buttonStyle(.plain)
  }
}

// Viewport axis orientation gizmo (X/Y/Z indicator).
struct AxisGizmo: View {
  var size: CGFloat = 54
  var body: some View {
    ZStack {
      axis(angle: 0, color: UI.danger, label: "X")
      axis(angle: -90, color: UI.ok, label: "Y")
      axis(angle: 135, color: UI.accent, label: "Z")
      Circle().fill(UI.text3.opacity(0.5)).frame(width: 5, height: 5)
    }
    .frame(width: size, height: size)
  }

  private func axis(angle: Double, color: Color, label: String) -> some View {
    ZStack {
      Rectangle().fill(color).frame(width: 2, height: size * 0.36)
        .offset(y: -size * 0.18)
      Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(color)
        .offset(y: -size * 0.42)
    }
    .rotationEffect(.degrees(angle))
  }
}

// Simple segmented text tabs for inspectors (Properties · Appearance · Output).
struct InspectorTabs: View {
  let tabs: [String]
  @Binding var selection: Int
  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
        Button { selection = i } label: {
          Text(t).font(.system(size: 10.5, weight: selection == i ? .semibold : .regular))
            .foregroundStyle(selection == i ? UI.text : UI.text3)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(selection == i ? UI.panelHi : .clear, in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
      }
    }
    .padding(3)
    .background(UI.inset, in: RoundedRectangle(cornerRadius: 9))
  }
}
