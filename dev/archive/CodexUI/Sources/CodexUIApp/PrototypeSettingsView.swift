import CodexUICore
import SwiftUI

struct PrototypeSettingsView: View {
  @Bindable var model: PrototypeModel

  var body: some View {
    TabView {
      appearance
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
      layout
        .tabItem { Label("Workspace", systemImage: "rectangle.3.group") }
      behavior
        .tabItem { Label("Behavior", systemImage: "cursorarrow.motionlines") }
    }
    .frame(width: 520, height: 330)
    .preferredColorScheme(model.theme.preferredColorScheme)
  }

  private var appearance: some View {
    Form {
      Section("Application theme") {
        Picker("Theme", selection: $model.theme) {
          ForEach(PrototypeTheme.allCases) { theme in
            Text(theme.rawValue).tag(theme)
          }
        }
        .pickerStyle(.menu)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 8) {
          ForEach(PrototypeTheme.allCases) { theme in
            Button {
              model.theme = theme
            } label: {
              VStack(spacing: 5) {
                ZStack {
                  RoundedRectangle(cornerRadius: 7).fill(theme.panel)
                  Circle().fill(theme.accent).frame(width: 16, height: 16)
                }
                .frame(height: 34)
                .overlay(
                  RoundedRectangle(cornerRadius: 7)
                    .stroke(model.theme == theme ? theme.accent : theme.line, lineWidth: 1.5)
                )
                Text(theme.rawValue.replacingOccurrences(of: "Studio ", with: ""))
                  .font(.system(size: 8.5, weight: model.theme == theme ? .semibold : .regular))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
            .buttonStyle(.plain)
          }
        }

        HStack(spacing: 12) {
          themeSwatch("Canvas", model.theme.canvas)
          themeSwatch("Panel", model.theme.panel)
          themeSwatch("Raised", model.theme.raised)
          themeSwatch("Accent", model.theme.accent)
        }
      }

      Section("Design intent") {
        Text(
          "AnimaStudio Demo surfaces and typography, restrained strokes, and selectable accent families. Color remains reserved for state, selection, and action."
        )
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding(4)
  }

  private var layout: some View {
    Form {
      Section("Layout preset") {
        Picker(
          "Preset",
          selection: Binding(
            get: { model.detectedLayoutPreset ?? .studio },
            set: { model.applyLayoutPreset($0) }
          )
        ) {
          ForEach(WorkspaceLayoutPreset.allCases) { preset in
            Text(preset.label).tag(preset)
          }
        }
        .pickerStyle(.segmented)

        placementRow("Left browser", selection: $model.leftPanelPlacement)
        placementRow("Right inspector", selection: $model.rightPanelPlacement)
        placementRow("Tool ribbon", selection: $model.ribbonPlacement)
        Picker("Floating ribbon edge", selection: $model.floatingRibbonEdge) {
          ForEach(FloatingRibbonEdge.allCases) { edge in
            Text(edge.label).tag(edge)
          }
        }
      }

      Section("Workspace tabs") {
        Picker("Text labels", selection: $model.workspaceTabLabelMode) {
          ForEach(WorkspaceTabLabelMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }
        Text(
          "Automatic shows every label when there is room and only the selected workspace label in compact windows."
        )
        .foregroundStyle(.secondary)
      }

      Section {
        Text(
          "Floating panels stay constrained to the CodexUI window. Docking places them back into the workspace flow."
        )
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding(4)
  }

  private var behavior: some View {
    Form {
      Section("Prototype behavior") {
        Toggle("Show guided walkthrough", isOn: $model.showsTour)
        Toggle("Show viewport performance HUD", isOn: $model.showsViewportPerformanceHUD)
        Toggle("Preview playback", isOn: $model.previewActive)
        Toggle("Master Live presentation", isOn: $model.masterLive)
      }
      Section("Scope") {
        LabeledContent("Engine", value: "Not connected")
        LabeledContent("Filesystem", value: "No mutations")
        LabeledContent("Hardware", value: "Presentation only")
      }
    }
    .formStyle(.grouped)
    .padding(4)
  }

  private func placementRow(_ title: String, selection: Binding<PanelPlacement>) -> some View {
    Picker(title, selection: selection) {
      ForEach(PanelPlacement.allCases) { placement in
        Text(placement.label).tag(placement)
      }
    }
  }

  private func themeSwatch(_ label: String, _ color: Color) -> some View {
    VStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 6).fill(color).frame(height: 35)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.primary.opacity(0.15)))
      Text(label).font(.caption2).foregroundStyle(.secondary)
    }
  }
}
