import RealityKitViewport
import SwiftUI

struct ViewportEnvironmentSettingsView: View {
  @Binding var background: ViewportBackgroundSettings
  @Binding var sectionPlane: ViewportSectionPlane
  @Binding var lightingIntensity: Double
  @Binding var environmentPreset: ViewportEnvironmentPreset
  @Binding var environmentRotationDegrees: Double

  var body: some View {
    Form {
      Section("Background") {
        Picker("Mode", selection: $background.mode) {
          ForEach(ViewportBackgroundMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)

        if background.mode == .preset {
          Picker("Preset", selection: $background.preset) {
            ForEach(PreviewAppearance.allCases) { Text($0.title).tag($0) }
          }
        } else {
          ColorPicker("Color", selection: primaryColor)
          if background.mode == .gradient {
            ColorPicker("Second Color", selection: secondaryColor)
          }
        }
      }

      Section("Studio Environment") {
        Picker("Environment", selection: $environmentPreset) {
          ForEach(ViewportEnvironmentPreset.allCases) { Text($0.title).tag($0) }
        }
        LabeledContent(
          "Intensity", value: lightingIntensity.formatted(.number.precision(.fractionLength(2))))
        Slider(value: $lightingIntensity, in: 0.1...3)
        LabeledContent("Rotation", value: "\(Int(environmentRotationDegrees))°")
        Slider(value: $environmentRotationDegrees, in: 0...360)
      }

      Section("Section View") {
        Toggle("Enable clip plane", isOn: $sectionPlane.isEnabled)
        Picker("Plane Normal", selection: $sectionPlane.axis) {
          ForEach(ViewportSectionAxis.allCases) { Text($0.title).tag($0) }
        }
        LabeledContent(
          "Position",
          value: sectionPlane.positionMeters.formatted(.number.precision(.fractionLength(3))) + " m"
        )
        Slider(value: $sectionPlane.positionMeters, in: -3...3)
      }
    }
    .formStyle(.grouped)
    .frame(width: 360, height: 560)
    .padding(8)
  }

  private var primaryColor: Binding<Color> {
    Binding(
      get: { background.primary.color },
      set: { background.primary = ViewportColor(NSColor($0)) }
    )
  }

  private var secondaryColor: Binding<Color> {
    Binding(
      get: { background.secondary.color },
      set: { background.secondary = ViewportColor(NSColor($0)) }
    )
  }
}
