// Quick scene/environment controls for the viewport's bottom tray — theme,
// engine, background, key light, and color preservation without opening Settings.
// All bound to the shared RenderState so every renderer updates live.
import SwiftUI

struct EnvironmentPanel: View {
  @Bindable private var render = RenderState.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("ENVIRONMENT").font(.system(size: 10, weight: .semibold)).tracking(0.6)
        .foregroundStyle(UI.text3)

      row("Theme") {
        Menu(render.theme.name) {
          ForEach(BenchTheme.all) { t in
            Button(t.name) { render.theme = .named(t.name) }
          }
        }
        .menuStyle(.borderlessButton).fixedSize()
      }

      row("Engine") {
        Menu(render.engine.rawValue) {
          ForEach(RenderEngine.allCases) { e in
            Button(e.available ? e.rawValue : "\(e.rawValue) (unavailable)") { render.engine = e }
              .disabled(!e.available)
          }
        }
        .menuStyle(.borderlessButton).fixedSize()
      }

      Divider().overlay(UI.stroke)

      row("Background") {
        ColorPicker("", selection: bg, supportsOpacity: false).labelsHidden()
      }

      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text("Key light").font(.system(size: 11)).foregroundStyle(UI.text2)
          Spacer()
          Text("\(Int(render.theme.key.intensity))")
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(UI.text3)
        }
        Slider(value: Binding(
          get: { Double(render.theme.key.intensity) },
          set: { render.theme.key.intensity = Float($0) }), in: 0...6000)
      }

      Toggle(isOn: preserve) {
        Text("Keep STEP colors").font(.system(size: 11)).foregroundStyle(UI.text2)
      }
      .toggleStyle(.switch).controlSize(.mini)
    }
    .padding(14).frame(width: 244)
  }

  private func row<T: View>(_ label: String, @ViewBuilder _ control: () -> T) -> some View {
    HStack {
      Text(label).font(.system(size: 11)).foregroundStyle(UI.text2)
      Spacer()
      control()
    }
  }

  private var bg: Binding<Color> {
    Binding(
      get: {
        let v = render.theme.background
        return Color(red: Double(v.x), green: Double(v.y), blue: Double(v.z))
      },
      set: {
        let n = NSColor($0).usingColorSpace(.sRGB) ?? .black
        render.theme.background = SIMD3(Float(n.redComponent), Float(n.greenComponent), Float(n.blueComponent))
      })
  }

  private var preserve: Binding<Bool> {
    Binding(get: { render.theme.overrideColor == nil },
      set: { render.theme.overrideColor = $0 ? nil : render.theme.neutralColor })
  }
}
