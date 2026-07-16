import RealityKitViewport
import SwiftUI

enum MouseSettingsTab: String, CaseIterable, Identifiable {
  case scroll
  case mouse
  case buttons
  case keyboard
  case exceptions
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .scroll: "Scroll"
    case .mouse: "Mouse"
    case .buttons: "Buttons"
    case .keyboard: "Keyboard"
    case .exceptions: "Exceptions"
    case .settings: "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .scroll: "scroll"
    case .mouse: "computermouse"
    case .buttons: "circle.grid.cross"
    case .keyboard: "keyboard"
    case .exceptions: "exclamationmark.shield"
    case .settings: "gearshape"
    }
  }
}

struct MouseNavigationSettingsView: View {
  @Binding var profile: PreviewNavigationProfile
  @Binding var customRotateDrag: NavigationDragBinding
  @Binding var customPanDrag: NavigationDragBinding
  @Binding var customPreciseZoomDrag: NavigationDragBinding
  @Binding var orbitSpeed: PreviewNavigationSpeed
  @Binding var panSpeed: PreviewNavigationSpeed
  @Binding var zoomSpeed: PreviewNavigationSpeed
  @Binding var reversesWheelZoom: Bool

  @State private var selectedTab = MouseSettingsTab.mouse
  @Environment(\.dismiss) private var dismiss

  private var customMapping: CustomNavigationMapping {
    CustomNavigationMapping(
      rotateDrag: customRotateDrag,
      panDrag: customPanDrag,
      preciseZoomDrag: customPreciseZoomDrag
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().overlay(StudioPalette.border)
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch selectedTab {
          case .mouse:
            mousePage
          case .scroll:
            scrollPage
          case .buttons:
            buttonsPage
          case .keyboard:
            keyboardPage
          case .exceptions:
            unavailablePage(
              title: "Application Exceptions",
              detail:
                "Per-application mouse overrides are planned for a future input-driver integration.",
              systemImage: "exclamationmark.shield"
            )
          case .settings:
            settingsPage
          }
        }
        .padding(18)
      }
    }
    .frame(width: 620, height: 650)
    .background(StudioPalette.canvas)
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    VStack(spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Mouse & Navigation")
            .font(.headline)
          Text("Viewport-only preferences · saved on this Mac")
            .font(.caption2)
            .foregroundStyle(StudioPalette.muted)
        }
        Spacer()
        Button("Close", systemImage: "xmark") { dismiss() }
          .labelStyle(.iconOnly)
          .buttonStyle(StudioIconButtonStyle())
      }

      HStack(spacing: 4) {
        ForEach(MouseSettingsTab.allCases) { tab in
          Button {
            selectedTab = tab
          } label: {
            VStack(spacing: 4) {
              Image(systemName: tab.systemImage)
                .font(.system(size: 16, weight: .medium))
              Text(tab.title)
                .font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 45)
          }
          .buttonStyle(.plain)
          .foregroundStyle(selectedTab == tab ? .white : StudioPalette.muted)
          .background(
            selectedTab == tab ? StudioPalette.accent.opacity(0.82) : StudioPalette.panelInset,
            in: RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
          )
          .overlay {
            RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
              .stroke(StudioPalette.border, lineWidth: 1)
          }
          .accessibilityLabel("\(tab.title) settings")
        }
      }
    }
    .padding(14)
    .background(StudioPalette.chrome)
  }

  private var mousePage: some View {
    VStack(alignment: .leading, spacing: 16) {
      settingsSection(
        title: "Navigation Profile",
        detail: "Choose a familiar CAD convention, then fine-tune its response.",
        systemImage: "computermouse"
      ) {
        Picker("Navigation Profile", selection: $profile) {
          ForEach(PreviewNavigationProfile.allCases) { profile in
            Text(profile.displayName).tag(profile)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        MouseControlDiagram(profile: profile, customMapping: customMapping)
          .padding(12)
          .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 10))
      }

      sensitivitySection
    }
  }

  private var scrollPage: some View {
    settingsSection(
      title: "Scroll Wheel",
      detail: "A standard wheel notch changes camera distance by about 13% at Standard speed.",
      systemImage: "scroll"
    ) {
      sensitivitySlider("Zoom speed", selection: $zoomSpeed, systemImage: "plus.magnifyingglass")
      Toggle("Reverse wheel zoom direction", isOn: $reversesWheelZoom)
        .toggleStyle(.switch)
      Text("Trackpad scroll remains pan; pinch always zooms and is not reversed.")
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private var buttonsPage: some View {
    VStack(alignment: .leading, spacing: 16) {
      settingsSection(
        title: "Button Map",
        detail: profile == .custom
          ? "Each custom chord owns one action; conflicts are swapped automatically."
          : "Preset mappings are read-only. Choose Custom to rebind them.",
        systemImage: "circle.grid.cross"
      ) {
        bindingPicker("Orbit / tilt", selection: $customRotateDrag)
        bindingPicker("Pan", selection: $customPanDrag)
        bindingPicker("Precise zoom", selection: $customPreciseZoomDrag)
      }
      .disabled(profile != .custom)

      if profile != .custom {
        Button("Switch to Custom") { profile = .custom }
          .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: false))
      }
    }
  }

  private var keyboardPage: some View {
    settingsSection(
      title: "Modifier Keys",
      detail: "These modifiers are part of the selected CAD profile.",
      systemImage: "keyboard"
    ) {
      mappingReadout("Option", detail: optionKeyDetail)
      mappingReadout("Shift", detail: shiftKeyDetail)
      mappingReadout("Escape", detail: "Clear feature selection, then component selection")
    }
  }

  private var settingsPage: some View {
    settingsSection(
      title: "Navigation Defaults",
      detail: "Reset only viewport input preferences. Project files are never changed.",
      systemImage: "gearshape"
    ) {
      Button("Restore Default Navigation Settings", systemImage: "arrow.counterclockwise") {
        profile = .default
        customRotateDrag = .rightMouse
        customPanDrag = .middleMouse
        customPreciseZoomDrag = .shiftMiddleMouse
        orbitSpeed = .standard
        panSpeed = .standard
        zoomSpeed = .reduced
        reversesWheelZoom = false
      }
      .buttonStyle(StudioButtonStyle(role: .secondary))
    }
  }

  private var sensitivitySection: some View {
    settingsSection(
      title: "Motion Response",
      detail: "Tune each camera movement independently without changing its button mapping.",
      systemImage: "gauge.with.dots.needle.33percent"
    ) {
      sensitivitySlider("Orbit speed", selection: $orbitSpeed, systemImage: "rotate.3d")
      sensitivitySlider("Pan speed", selection: $panSpeed, systemImage: "move.3d")
      sensitivitySlider("Zoom speed", selection: $zoomSpeed, systemImage: "plus.magnifyingglass")
      Toggle("Reverse wheel zoom direction", isOn: $reversesWheelZoom)
        .toggleStyle(.switch)
    }
  }

  private var optionKeyDetail: String {
    switch profile {
    case .default, .solidWorks: "Option + middle drag pans"
    case .onshape: "Option + click selects through transparent geometry"
    case .fusion360: "No preset Option action"
    case .custom: "Available in the custom button bindings"
    }
  }

  private var shiftKeyDetail: String {
    switch profile {
    case .default, .solidWorks: "Shift + middle drag performs precise zoom"
    case .onshape: "Adds to keyboard-assisted selection"
    case .fusion360: "Shift + middle drag orbits"
    case .custom: "Available in the custom button bindings"
    }
  }

  private func settingsSection<Content: View>(
    title: String,
    detail: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 13) {
      StudioSectionHeader(title: title, detail: detail, systemImage: systemImage)
      content()
    }
    .studioCardSurface()
  }

  private func bindingPicker(
    _ title: String,
    selection: Binding<NavigationDragBinding>
  ) -> some View {
    HStack {
      Text(title)
        .font(.callout)
      Spacer()
      Picker(title, selection: selection) {
        ForEach(NavigationDragBinding.allCases) { binding in
          Text(binding.title).tag(binding)
        }
      }
      .labelsHidden()
      .frame(width: 255)
    }
  }

  private func sensitivitySlider(
    _ title: String,
    selection: Binding<PreviewNavigationSpeed>,
    systemImage: String
  ) -> some View {
    let index = Binding<Double>(
      get: { Double(PreviewNavigationSpeed.allCases.firstIndex(of: selection.wrappedValue) ?? 2) },
      set: { value in
        let resolvedIndex = min(
          max(Int(value.rounded()), 0), PreviewNavigationSpeed.allCases.count - 1)
        selection.wrappedValue = PreviewNavigationSpeed.allCases[resolvedIndex]
      }
    )
    return VStack(spacing: 5) {
      HStack {
        Label(title, systemImage: systemImage)
        Spacer()
        Text(selection.wrappedValue.title)
          .font(.caption.monospacedDigit())
          .foregroundStyle(StudioPalette.muted)
      }
      Slider(value: index, in: 0...4, step: 1)
        .accessibilityLabel(title)
        .accessibilityValue(selection.wrappedValue.title)
    }
  }

  private func mappingReadout(_ title: String, detail: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(.callout.weight(.semibold))
        .frame(width: 74, alignment: .leading)
      Text(detail)
        .font(.callout)
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private func unavailablePage(title: String, detail: String, systemImage: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 34))
        .foregroundStyle(StudioPalette.muted)
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.callout)
        .foregroundStyle(StudioPalette.muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 360)
      Text("Coming later")
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(StudioPalette.panelInset, in: Capsule())
    }
    .frame(maxWidth: .infinity, minHeight: 360)
    .studioCardSurface()
  }
}
