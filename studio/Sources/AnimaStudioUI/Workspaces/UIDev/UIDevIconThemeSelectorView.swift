import Foundation
import SwiftUI

enum UIDevIconThemePalette: String, CaseIterable, Identifiable, Sendable {
  case light
  case dark
  case graphite
  case midnight
  case neon

  var id: Self { self }

  var title: String {
    switch self {
    case .light: "Light"
    case .dark: "Dark"
    case .graphite: "Graphite"
    case .midnight: "Midnight"
    case .neon: "Neon"
    }
  }

  var systemImage: String {
    switch self {
    case .light: "sun.max.fill"
    case .dark: "moon.fill"
    case .graphite: "circle.lefthalf.filled"
    case .midnight: "moon.stars.fill"
    case .neon: "bolt.fill"
    }
  }

  var palette: UIDevIconThemePaletteSpec {
    switch self {
    case .light:
      UIDevIconThemePaletteSpec(
        canvas: token(0.94, 0.95, 0.97), dock: token(0.98, 0.98, 0.99),
        tile: token(0.89, 0.91, 0.94), menu: token(1, 1, 1),
        accent: token(0.04, 0.39, 0.88), foreground: token(0.08, 0.10, 0.14),
        selectedForeground: token(1, 1, 1), muted: token(0.35, 0.38, 0.44),
        border: token(0.68, 0.71, 0.76)
      )
    case .dark:
      UIDevIconThemePaletteSpec(
        canvas: token(0.075, 0.08, 0.095), dock: token(0.12, 0.125, 0.145),
        tile: token(0.17, 0.18, 0.205), menu: token(0.105, 0.11, 0.13),
        accent: token(0.08, 0.44, 0.94), foreground: token(0.94, 0.95, 0.98),
        selectedForeground: token(1, 1, 1), muted: token(0.60, 0.63, 0.70),
        border: token(0.28, 0.30, 0.35)
      )
    case .graphite:
      UIDevIconThemePaletteSpec(
        canvas: token(0.055, 0.06, 0.065), dock: token(0.105, 0.11, 0.115),
        tile: token(0.14, 0.145, 0.15), menu: token(0.08, 0.085, 0.09),
        accent: token(0.02, 0.36, 0.84), foreground: token(0.90, 0.91, 0.93),
        selectedForeground: token(1, 1, 1), muted: token(0.48, 0.50, 0.54),
        border: token(0.22, 0.23, 0.25)
      )
    case .midnight:
      UIDevIconThemePaletteSpec(
        canvas: token(0.018, 0.028, 0.065), dock: token(0.035, 0.055, 0.12),
        tile: token(0.065, 0.09, 0.17), menu: token(0.025, 0.04, 0.09),
        accent: token(0.28, 0.36, 1), foreground: token(0.90, 0.93, 1),
        selectedForeground: token(1, 1, 1), muted: token(0.50, 0.58, 0.76),
        border: token(0.16, 0.22, 0.42)
      )
    case .neon:
      UIDevIconThemePaletteSpec(
        canvas: token(0.015, 0.018, 0.025), dock: token(0.04, 0.05, 0.065),
        tile: token(0.065, 0.075, 0.095), menu: token(0.025, 0.03, 0.04),
        accent: token(0.05, 0.90, 0.78), foreground: token(0.88, 1, 0.97),
        selectedForeground: token(0.01, 0.04, 0.04), muted: token(0.48, 0.67, 0.66),
        border: token(0.18, 0.46, 0.42)
      )
    }
  }

  var colorScheme: ColorScheme {
    self == .light ? .light : .dark
  }

  private func token(
    _ red: Double,
    _ green: Double,
    _ blue: Double,
    _ opacity: Double = 1
  ) -> StudioColorToken {
    StudioColorToken(red: red, green: green, blue: blue, opacity: opacity)
  }
}

struct UIDevIconThemePaletteSpec: Equatable, Sendable {
  let canvas: StudioColorToken
  let dock: StudioColorToken
  let tile: StudioColorToken
  let menu: StudioColorToken
  let accent: StudioColorToken
  let foreground: StudioColorToken
  let selectedForeground: StudioColorToken
  let muted: StudioColorToken
  let border: StudioColorToken
}

enum UIDevIconSelectorItem: String, CaseIterable, Identifiable, Sendable {
  case rig
  case nodes
  case viewport
  case show

  var id: Self { self }

  var title: String {
    switch self {
    case .rig: "Rig"
    case .nodes: "Nodes"
    case .viewport: "3D View"
    case .show: "Show"
    }
  }

  var systemImage: String {
    switch self {
    case .rig: "triangle"
    case .nodes: "point.3.connected.trianglepath.dotted"
    case .viewport: "cube"
    case .show: "rectangle.3.group"
    }
  }
}

struct UIDevIconThemeSelectorView: View {
  @State private var theme = UIDevIconThemePalette.graphite
  @State private var selection = UIDevIconSelectorItem.nodes
  @State private var hoveredItem: UIDevIconSelectorItem?
  @State private var statusMessage = "Nodes selected · Graphite theme"

  private var palette: UIDevIconThemePaletteSpec { theme.palette }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      themePicker

      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 16) {
          themedStage
          paletteInspector
            .frame(width: 220)
        }
        VStack(alignment: .leading, spacing: 14) {
          themedStage
          paletteInspector
        }
      }

      Label(statusMessage, systemImage: "cursorarrow.motionlines")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(18)
    .background(StudioPalette.canvas)
  }

  private var themePicker: some View {
    HStack(alignment: .center, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text("ICON SELECTOR · THEME LAB")
          .font(.caption2.weight(.bold))
          .tracking(1.1)
          .foregroundStyle(StudioPalette.accent)
        Text("Compare the complete widget treatment before app-wide adoption.")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer(minLength: 12)
      Picker("Preview theme", selection: $theme) {
        ForEach(UIDevIconThemePalette.allCases) { option in
          Label(option.title, systemImage: option.systemImage).tag(option)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(maxWidth: 510)
      .onChange(of: theme) { _, newTheme in
        statusMessage = "\(selection.title) selected · \(newTheme.title) theme"
      }
    }
  }

  private var themedStage: some View {
    ZStack {
      palette.canvas.color

      Canvas { context, size in
        var lines = Path()
        let spacing: CGFloat = 22
        for x in stride(from: 0, through: size.width, by: spacing) {
          lines.move(to: CGPoint(x: x, y: 0))
          lines.addLine(to: CGPoint(x: x, y: size.height))
        }
        context.stroke(lines, with: .color(palette.border.color.opacity(0.16)), lineWidth: 0.5)
      }

      VStack(spacing: 20) {
        iconDock
        contextMenuPreview
      }
      .padding(28)
    }
    .environment(\.colorScheme, theme.colorScheme)
    .frame(maxWidth: .infinity, minHeight: 390)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(palette.border.color, lineWidth: 1)
    }
  }

  private var iconDock: some View {
    HStack(spacing: 10) {
      ForEach(UIDevIconSelectorItem.allCases) { item in
        Button {
          selection = item
          statusMessage = "\(item.title) selected · \(theme.title) theme"
        } label: {
          VStack(spacing: 6) {
            Image(systemName: item.systemImage)
              .font(.system(size: 29, weight: .medium))
            Text(item.title)
              .font(.system(size: 9, weight: .bold))
              .lineLimit(1)
          }
          .foregroundStyle(
            selection == item ? palette.selectedForeground.color : palette.muted.color
          )
          .frame(width: 72, height: 72)
          .background(
            selection == item
              ? AnyShapeStyle(
                LinearGradient(
                  colors: [palette.accent.color, palette.accent.color.opacity(0.72)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              : AnyShapeStyle(
                hoveredItem == item ? palette.tile.color.opacity(1.18) : palette.tile.color
              ),
            in: RoundedRectangle(cornerRadius: 17)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 17)
              .stroke(
                selection == item ? palette.accent.color : palette.border.color,
                lineWidth: selection == item ? 1.5 : 1
              )
          }
          .shadow(
            color: selection == item ? palette.accent.color.opacity(0.32) : .black.opacity(0.22),
            radius: selection == item ? 10 : 5,
            y: 4
          )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
          hoveredItem = isHovered ? item : nil
        }
        .help(item.title)
        .contextMenu {
          Button("Edit", systemImage: "pencil") {
            statusMessage = "Edit \(item.title)"
          }
          Button("Duplicate", systemImage: "square.on.square") {
            statusMessage = "Duplicate \(item.title)"
          }
          Divider()
          Button("Delete", systemImage: "trash", role: .destructive) {
            statusMessage = "Delete \(item.title) · prototype only"
          }
        }
      }
    }
    .padding(16)
    .background(palette.dock.color, in: RoundedRectangle(cornerRadius: 25))
    .overlay {
      RoundedRectangle(cornerRadius: 25)
        .stroke(palette.border.color, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
  }

  private var contextMenuPreview: some View {
    VStack(spacing: 0) {
      themedMenuRow("Edit", image: "pencil", shortcut: "⌘D")
      Divider().overlay(palette.border.color)
      themedMenuRow("Duplicate", image: "square.on.square", shortcut: "⌘⇧D")
      Divider().overlay(palette.border.color)
      themedMenuRow("Delete", image: "trash", shortcut: "⌫", isDestructive: true)
    }
    .frame(width: 178)
    .background(palette.menu.color, in: RoundedRectangle(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(palette.border.color, lineWidth: 1) }
    .shadow(color: .black.opacity(0.36), radius: 12, y: 6)
  }

  private func themedMenuRow(
    _ title: String,
    image: String,
    shortcut: String,
    isDestructive: Bool = false
  ) -> some View {
    Button {
      statusMessage = "\(title) \(selection.title) · prototype only"
    } label: {
      HStack(spacing: 8) {
        Image(systemName: image).frame(width: 14)
        Text(title)
        Spacer()
        Text(shortcut).foregroundStyle(palette.muted.color)
      }
      .font(.caption)
      .foregroundStyle(isDestructive ? Color.red : palette.foreground.color)
      .padding(.horizontal, 10)
      .frame(height: 32)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var paletteInspector: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(theme.title, systemImage: theme.systemImage)
          .font(.callout.weight(.bold))
        Spacer()
        Text("PREVIEW")
          .font(.system(size: 8, weight: .bold, design: .monospaced))
          .foregroundStyle(StudioPalette.muted)
      }

      ForEach(paletteRows, id: \.0) { name, token in
        HStack(spacing: 9) {
          RoundedRectangle(cornerRadius: 5)
            .fill(token.color)
            .frame(width: 28, height: 22)
            .overlay { RoundedRectangle(cornerRadius: 5).stroke(StudioPalette.border) }
          Text(name).font(.caption)
          Spacer()
          Text(hex(token))
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(StudioPalette.muted)
        }
      }

      Divider()

      Text(
        "Local specimen only. Applying a theme to the whole app remains a separate reviewed change."
      )
      .font(.caption2)
      .foregroundStyle(StudioPalette.muted)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private var paletteRows: [(String, StudioColorToken)] {
    [
      ("Canvas", palette.canvas), ("Dock", palette.dock), ("Tile", palette.tile),
      ("Menu", palette.menu), ("Accent", palette.accent), ("Text", palette.foreground),
    ]
  }

  private func hex(_ token: StudioColorToken) -> String {
    let red = Int((token.red * 255).rounded())
    let green = Int((token.green * 255).rounded())
    let blue = Int((token.blue * 255).rounded())
    return String(format: "#%02X%02X%02X", red, green, blue)
  }
}
