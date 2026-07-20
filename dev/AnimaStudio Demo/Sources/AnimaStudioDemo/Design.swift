// Design system — the tokens + reusable chrome for the ClaudeUI mockup.
// Dark, technical, restrained (Shapr3D/Codex-bench feel). No real data.
import SwiftUI

enum UI {
  // Theme-aware palette — every token resolves against ThemeState. Reading any
  // of these inside a view body auto-subscribes that view to theme changes.
  private static var dark: Bool { ThemeState.shared.isDark }
  private static func c(_ d: UInt32, _ l: UInt32) -> Color { Color(hex: dark ? d : l) }

  static var bg: Color { c(0x0E1013, 0xF2F4F8) }
  static var panel: Color { c(0x171A20, 0xFFFFFF) }
  static var panelHi: Color { c(0x1E222A, 0xEDF0F5) }
  static var stroke: Color { dark ? .white.opacity(0.07) : .black.opacity(0.08) }
  static var strokeHi: Color { dark ? .white.opacity(0.12) : .black.opacity(0.13) }
  static var text: Color { c(0xE7E9ED, 0x1A1E27) }
  static var text2: Color { c(0x9AA1AB, 0x5B636F) }
  static var text3: Color { c(0x646B76, 0x9BA2AD) }
  static var accent: Color { ThemeState.shared.accent.color(dark: dark) }  // primary / selection
  static var accent2: Color { c(0x36D6C3, 0x11A594) }   // rig / geometry
  static var warn: Color { c(0xFF8A3D, 0xEC6D1F) }      // record / arm
  static var danger: Color { c(0xFF5A5F, 0xE5484D) }
  static var ok: Color { c(0x4CD07A, 0x27B36A) }

  // 3D stage / canvas backgrounds (dark viewport in dark mode, light in light).
  static var stageTop: Color { c(0x20252E, 0xE7ECF3) }
  static var stageBottom: Color { c(0x0C0E12, 0xD2D9E3) }
  static var stageGrid: Color { dark ? .white.opacity(0.04) : .black.opacity(0.06) }
  static var inset: Color { c(0x0F1216, 0xE9ECF1) }     // curve/node editor wells

  // 3D viewport (matches ShaprUI): a soft-shaded metallic part on an airy canvas.
  static var viewportTop: Color { c(0x1E232B, 0xF4F6FA) }
  static var viewportBottom: Color { c(0x0B0D11, 0xE7EBF2) }
  static var partTop: Color { c(0x474E59, 0xFDFDFE) }
  static var partBottom: Color { c(0x262B32, 0xC7CEDA) }
  static var partRim: Color { dark ? .white.opacity(0.16) : .white }
  static var partStroke: Color { dark ? .white.opacity(0.10) : .black.opacity(0.10) }
  static var boreTop: Color { c(0x14171C, 0xAEB6C4) }
  static var boreBottom: Color { c(0x2C323A, 0xE9ECF2) }

  static let radius: CGFloat = 10
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255, opacity: 1)
  }
}

// A titled panel container.
struct Panel<Content: View>: View {
  var title: String? = nil
  var systemImage: String? = nil
  var accessory: AnyView? = nil
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let title {
        HStack(spacing: 7) {
          if let systemImage {
            Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
              .foregroundStyle(UI.text2)
          }
          Text(title.uppercased())
            .font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
            .foregroundStyle(UI.text2)
          Spacer()
          if let accessory { accessory }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        Divider().overlay(UI.stroke)
      }
      content()
    }
    .background(UI.panel)
    .clipShape(RoundedRectangle(cornerRadius: UI.radius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: UI.radius, style: .continuous).stroke(UI.stroke, lineWidth: 1))
  }
}

// A tree/list row (Onshape-style). `controls` adds ShaprUI-style visibility +
// lock toggles on the trailing edge (like the Items panel).
struct Row: View {
  var icon: String
  var label: String
  var detail: String? = nil
  var indent: CGFloat = 0
  var tint: Color = UI.text2
  var selected: Bool = false
  var badge: String? = nil
  var controls: Bool = false

  @State private var hidden = false
  @State private var locked = false

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon).font(.system(size: 12)).foregroundStyle(selected ? UI.accent : tint)
        .frame(width: 16)
      Text(label).font(.system(size: 12.5))
        .foregroundStyle(hidden ? UI.text3 : (selected ? UI.text : UI.text.opacity(0.9)))
      Spacer(minLength: 4)
      if let badge {
        Text(badge).font(.system(size: 9.5, weight: .medium)).foregroundStyle(UI.text3)
          .padding(.horizontal, 6).padding(.vertical, 2)
          .background(UI.panelHi, in: Capsule())
      }
      if let detail {
        Text(detail).font(.system(size: 11)).foregroundStyle(UI.text3)
      }
      if controls {
        Button { locked.toggle() } label: {
          Image(systemName: locked ? "lock.fill" : "lock.open")
            .font(.system(size: 10.5)).foregroundStyle(locked ? UI.accent : UI.text3)
        }.buttonStyle(.plain)
        Button { hidden.toggle() } label: {
          Image(systemName: hidden ? "eye.slash" : "eye")
            .font(.system(size: 10.5)).foregroundStyle(hidden ? UI.text3 : UI.text2)
        }.buttonStyle(.plain)
      }
    }
    .padding(.leading, 10 + indent).padding(.trailing, 10).padding(.vertical, 6)
    .background(selected ? UI.accent.opacity(0.14) : .clear)
    .overlay(alignment: .leading) {
      if selected { Rectangle().fill(UI.accent).frame(width: 2) }
    }
    .contentShape(Rectangle())
  }
}

// Small labeled field for inspectors.
struct Field: View {
  var label: String
  var value: String
  var unit: String? = nil
  var body: some View {
    HStack {
      Text(label).font(.system(size: 11.5)).foregroundStyle(UI.text2)
      Spacer()
      HStack(spacing: 4) {
        Text(value).font(.system(size: 12, design: .monospaced)).foregroundStyle(UI.text)
        if let unit { Text(unit).font(.system(size: 10)).foregroundStyle(UI.text3) }
      }
      .padding(.horizontal, 8).padding(.vertical, 4)
      .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 6))
    }
  }
}

// A stylized 3D-viewport placeholder (gradient stage + faux part + triad).
struct ViewportMock: View {
  var showGizmo = false
  var selected = true                    // draw the selection highlight
  var onTapPart: (() -> Void)? = nil     // click the part to select
  var onTapCanvas: (() -> Void)? = nil   // click empty space to deselect
  @State private var showRadial = false
  var body: some View {
    ZStack {
      LinearGradient(colors: [UI.viewportTop, UI.viewportBottom], startPoint: .top, endPoint: .bottom)
        .contentShape(Rectangle())
        .onTapGesture { onTapCanvas?() }
      PerspectiveGrid()
      // Machined part — soft-shaded metallic block with a bore, selection glow,
      // and a highlighted face (the Shapr3D product-render look).
      ZStack {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(LinearGradient(colors: [UI.partTop, UI.partBottom], startPoint: .top, endPoint: .bottom))
          .frame(width: 234, height: 162)
          .overlay(RoundedRectangle(cornerRadius: 24).stroke(UI.partRim, lineWidth: 1.5).blur(radius: 0.5))
          .overlay(RoundedRectangle(cornerRadius: 24).stroke(UI.partStroke, lineWidth: 1))
        Circle().fill(LinearGradient(colors: [UI.boreTop, UI.boreBottom], startPoint: .top, endPoint: .bottom))
          .frame(width: 56, height: 56)
          .overlay(Circle().stroke(UI.partStroke, lineWidth: 1))
          .offset(x: 52, y: -7)
        if selected {
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(UI.accent, lineWidth: 2.5).frame(width: 234, height: 162)
            .shadow(color: UI.accent.opacity(0.5), radius: 10)
          RoundedRectangle(cornerRadius: 8).fill(UI.accent.opacity(0.16))
            .frame(width: 82, height: 134).offset(x: -70)
        }
        if showGizmo && selected {
          ZStack {
            gizmoArrow(color: UI.danger, angle: 0)
            gizmoArrow(color: UI.ok, angle: -90)
            gizmoArrow(color: UI.accent, angle: 135)
          }
        }
      }
      .frame(width: 234, height: 162)
      .contentShape(Rectangle())
      .onTapGesture { onTapPart?() }
      .rotation3DEffect(.degrees(14), axis: (x: 1, y: 0, z: 0))
      .rotation3DEffect(.degrees(-20), axis: (x: 0, y: 1, z: 0))
      .shadow(color: .black.opacity(0.16), radius: 40, y: 30)
    }
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showRadial.toggle() }
    }
    .overlay {
      if showRadial {
        RadialMenu(onDismiss: { withAnimation(.spring(response: 0.3)) { showRadial = false } })
          .transition(.scale(scale: 0.85).combined(with: .opacity))
      }
    }
  }
  func gizmoArrow(color: Color, angle: Double) -> some View {
    Rectangle().fill(color).frame(width: 3, height: 54)
      .overlay(alignment: .top) { Triangle().fill(color).frame(width: 11, height: 11).offset(y: -8) }
      .rotationEffect(.degrees(angle))
  }
}

// Shapr3D-style perspective ground grid — lines converge toward the horizon.
// Shared by the concept ViewportMock and the real PartViewport.
struct PerspectiveGrid: View {
  var body: some View {
    GeometryReader { geo in
      Path { p in
        let cx = geo.size.width / 2, cy = geo.size.height * 0.60
        for i in -9...9 {
          let x = cx + CGFloat(i) * 54
          p.move(to: CGPoint(x: cx + CGFloat(i) * 18, y: cy))
          p.addLine(to: CGPoint(x: x, y: geo.size.height))
        }
        for j in 0...8 {
          let y = cy + CGFloat(j * j) * 3.6
          p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y))
        }
      }.stroke(UI.stageGrid, lineWidth: 1)
    }
    .allowsHitTesting(false)
  }
}

struct Triangle: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
    p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
    p.closeSubpath(); return p
  }
}

// Pill button used in toolbars / palettes.
struct Pill: View {
  var icon: String? = nil
  var label: String
  var active = false
  var tint: Color = UI.accent
  var body: some View {
    HStack(spacing: 6) {
      if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
      Text(label).font(.system(size: 12, weight: .medium))
    }
    .foregroundStyle(active ? .white : UI.text2)
    .padding(.horizontal, 12).padding(.vertical, 7)
    .background(active ? tint : UI.panelHi, in: Capsule())
    .overlay(Capsule().stroke(active ? .clear : UI.stroke, lineWidth: 1))
  }
}
