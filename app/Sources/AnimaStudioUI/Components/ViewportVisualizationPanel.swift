import AnimaModel
import RealityKitViewport
import SwiftUI

enum ViewportVisualizationTab: String, CaseIterable, Identifiable, Sendable {
  case material
  case environment

  var id: Self { self }
  var title: String { rawValue.capitalized }
}

enum VisualizationMaterialCategory: String, CaseIterable, Identifiable, Sendable {
  case plastic
  case metal
  case glass

  var id: Self { self }
  var title: String { rawValue.capitalized }
}

struct VisualizationMaterialPreset: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let family: String
  let category: VisualizationMaterialCategory
  let hexRGB: String
  let finish: ViewportMaterialFinish
  let opacity: Double

  var appearance: PreviewPartAppearance {
    PreviewPartAppearance(
      hexRGB: hexRGB,
      opacity: opacity,
      finish: finish
    ) ?? .defaultAppearance(for: .mesh)
  }

  func matches(_ query: String) -> Bool {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else { return true }
    return [name, family, category.title, finish.title, hexRGB]
      .contains { $0.lowercased().contains(normalized) }
  }
}

enum VisualizationMaterialCatalog {
  static let presets: [VisualizationMaterialPreset] = [
    .init(
      id: "plastic-glossy-abs-red", name: "ABS", family: "Glossy",
      category: .plastic, hexRGB: "#D52C35", finish: .glossy, opacity: 1),
    .init(
      id: "plastic-matte-abs-red", name: "ABS", family: "Matte",
      category: .plastic, hexRGB: "#BE2630", finish: .matte, opacity: 1),
    .init(
      id: "plastic-satin-white", name: "Engineering Plastic", family: "Satin",
      category: .plastic, hexRGB: "#E7E9EC", finish: .satin, opacity: 1),
    .init(
      id: "plastic-utility-black", name: "Utility Plastic", family: "Matte",
      category: .plastic, hexRGB: "#24272B", finish: .matte, opacity: 1),
    .init(
      id: "metal-brushed-aluminum", name: "Aluminum", family: "Brushed",
      category: .metal, hexRGB: "#AEB5BB", finish: .metallic, opacity: 1),
    .init(
      id: "metal-polished-steel", name: "Steel", family: "Polished",
      category: .metal, hexRGB: "#727A82", finish: .metallic, opacity: 1),
    .init(
      id: "metal-anodized-blue", name: "Anodized Aluminum", family: "Satin",
      category: .metal, hexRGB: "#356F9F", finish: .metallic, opacity: 1),
    .init(
      id: "metal-brass", name: "Brass", family: "Polished",
      category: .metal, hexRGB: "#B79445", finish: .metallic, opacity: 1),
    .init(
      id: "glass-clear-thin", name: "Clear Glass - Thin", family: "Glossy",
      category: .glass, hexRGB: "#F5FAFF", finish: .glossy, opacity: 0.18),
    .init(
      id: "glass-smoked", name: "Smoked Glass", family: "Glossy",
      category: .glass, hexRGB: "#56616C", finish: .glossy, opacity: 0.38),
    .init(
      id: "glass-frosted", name: "Frosted Glass", family: "Matte",
      category: .glass, hexRGB: "#C7D3DC", finish: .matte, opacity: 0.58),
  ]

  static func presets(
    in category: VisualizationMaterialCategory,
    matching query: String = ""
  ) -> [VisualizationMaterialPreset] {
    presets.filter { $0.category == category && $0.matches(query) }
  }
}

enum VisualizationEnvironmentPresetID: String, CaseIterable, Identifiable, Sendable {
  case defaultStudio
  case transparent
  case coloredMood
  case gradientMood
  case blackAndWhiteStage

  var id: String { rawValue }
}

struct VisualizationEnvironmentPreset: Identifiable, Equatable, Sendable {
  let id: VisualizationEnvironmentPresetID
  let name: String
  let colorLabel: String?
  let background: ViewportBackgroundSettings
  let environment: ViewportEnvironmentPreset
  let intensity: Double
  let rotationDegrees: Double
}

enum VisualizationEnvironmentCatalog {
  static let presets: [VisualizationEnvironmentPreset] = [
    .init(
      id: .defaultStudio,
      name: "Default",
      colorLabel: nil,
      background: .init(mode: .preset, preset: .graphite),
      environment: .softbox,
      intensity: 1,
      rotationDegrees: 0
    ),
    .init(
      id: .transparent,
      name: "Transparent",
      colorLabel: nil,
      background: .init(mode: .transparent, preset: .graphite),
      environment: .softbox,
      intensity: 1,
      rotationDegrees: 0
    ),
    .init(
      id: .coloredMood,
      name: "Colored Mood",
      colorLabel: "#00A7FF",
      background: .init(
        mode: .solid,
        preset: .graphite,
        primary: .init(red: 0, green: 0.655, blue: 1)
      ),
      environment: .rim,
      intensity: 1.15,
      rotationDegrees: 22
    ),
    .init(
      id: .gradientMood,
      name: "Gradient Mood",
      colorLabel: "#F2F2F2",
      background: .init(
        mode: .gradient,
        preset: .cadLight,
        primary: .init(red: 0.95, green: 0.95, blue: 0.95),
        secondary: .init(red: 0.68, green: 0.71, blue: 0.75)
      ),
      environment: .softbox,
      intensity: 1.1,
      rotationDegrees: 0
    ),
    .init(
      id: .blackAndWhiteStage,
      name: "Black and White Stage",
      colorLabel: nil,
      background: .init(
        mode: .gradient,
        preset: .cadLight,
        primary: .init(red: 0.94, green: 0.94, blue: 0.94),
        secondary: .init(red: 0.055, green: 0.06, blue: 0.07)
      ),
      environment: .rim,
      intensity: 1.35,
      rotationDegrees: 315
    ),
  ]

  static func matching(
    background: ViewportBackgroundSettings,
    environment: ViewportEnvironmentPreset,
    intensity: Double,
    rotationDegrees: Double
  ) -> VisualizationEnvironmentPreset? {
    presets.first {
      $0.background == background
        && $0.environment == environment
        && abs($0.intensity - intensity) < 0.001
        && abs($0.rotationDegrees - rotationDegrees) < 0.001
    }
  }
}

struct VisualizationUsedMaterial: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let appearance: PreviewPartAppearance
  let assignmentCount: Int
}

struct ViewportVisualizationControl: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var lightingIntensity: Double
  @Binding var environmentPreset: ViewportEnvironmentPreset
  @Binding var environmentRotationDegrees: Double

  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented.toggle()
    } label: {
      HStack(spacing: 8) {
        VisualizationColorWheelIcon()
          .frame(width: 20, height: 20)
        Text("Visualization")
          .font(.callout.weight(.semibold))
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
      .overlay {
        RoundedRectangle(cornerRadius: 9)
          .stroke(isPresented ? StudioPalette.accent : StudioPalette.border, lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.18), radius: 7, y: 3)
    }
    .buttonStyle(.plain)
    .help("Materials and environment")
    .accessibilityLabel("Visualization")
    .accessibilityValue(isPresented ? "Open" : "Closed")
    .popover(isPresented: $isPresented, arrowEdge: .leading) {
      ViewportVisualizationPanel(
        workspace: workspace,
        lightingIntensity: $lightingIntensity,
        environmentPreset: $environmentPreset,
        environmentRotationDegrees: $environmentRotationDegrees
      )
    }
  }
}

struct VisualizationColorWheelIcon: View {
  var body: some View {
    Circle()
      .fill(
        AngularGradient(
          colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
          center: .center
        )
      )
      .overlay {
        Circle()
          .fill(
            RadialGradient(
              colors: [.white.opacity(0.88), .white.opacity(0.02)],
              center: .center,
              startRadius: 0,
              endRadius: 11
            )
          )
      }
      .overlay { Circle().stroke(.white.opacity(0.72), lineWidth: 0.7) }
      .accessibilityHidden(true)
  }
}

private struct ViewportVisualizationPanel: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var lightingIntensity: Double
  @Binding var environmentPreset: ViewportEnvironmentPreset
  @Binding var environmentRotationDegrees: Double

  @State private var selectedTab = ViewportVisualizationTab.material

  var body: some View {
    VStack(spacing: 0) {
      Picker("Visualization", selection: $selectedTab) {
        ForEach(ViewportVisualizationTab.allCases) { tab in
          Text(tab.title).tag(tab)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .padding(12)

      Divider()

      switch selectedTab {
      case .material:
        VisualizationMaterialBrowser(
          selectedPartName: selectedPart?.displayName,
          usedMaterials: usedMaterials,
          applyPreset: apply,
          applyUsedMaterial: apply
        )
      case .environment:
        VisualizationEnvironmentBrowser(
          background: backgroundBinding,
          sectionPlane: sectionPlaneBinding,
          lightingIntensity: $lightingIntensity,
          environmentPreset: $environmentPreset,
          environmentRotationDegrees: $environmentRotationDegrees
        )
      }
    }
    .frame(width: 360, height: 650)
    .background(StudioPalette.panel)
  }

  private var selectedPart: RigPartDefinition? {
    guard let selectedPartID = workspace.selectedPartID else { return nil }
    return workspace.project.rig.parts.first { $0.id == selectedPartID }
  }

  private var usedMaterials: [VisualizationUsedMaterial] {
    let grouped = Dictionary(grouping: workspace.project.rig.parts) { part in
      let appearance =
        workspace.componentAppearance(for: part.id)
        ?? .defaultAppearance(for: part.primitiveKind)
      return "\(appearance.finish.rawValue)|\(appearance.hexRGB)|\(appearance.opacity)"
    }
    return grouped.compactMap { key, parts in
      guard let first = parts.first,
        let appearance = workspace.componentAppearance(for: first.id)
      else { return nil }
      return VisualizationUsedMaterial(
        id: key,
        name: parts.count == 1 ? first.displayName : "\(appearance.finish.title) Material",
        appearance: appearance,
        assignmentCount: parts.count
      )
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private var backgroundBinding: Binding<ViewportBackgroundSettings> {
    Binding(
      get: { workspace.viewportBackground },
      set: { settings in workspace.setViewportBackground(settings) }
    )
  }

  private var sectionPlaneBinding: Binding<ViewportSectionPlane> {
    Binding(
      get: { workspace.viewportSectionPlane },
      set: { section in workspace.setViewportSectionPlane(section) }
    )
  }

  private func apply(_ preset: VisualizationMaterialPreset) {
    apply(preset.appearance)
  }

  private func apply(_ source: PreviewPartAppearance) {
    guard let part = selectedPart,
      var appearance = workspace.componentAppearance(for: part.id)
    else { return }
    appearance.red = source.red
    appearance.green = source.green
    appearance.blue = source.blue
    appearance.opacity = source.opacity
    appearance.finish = source.finish
    workspace.setComponentAppearance(id: part.id, to: appearance)
  }
}

struct VisualizationEnvironmentBrowser: View {
  @Binding var background: ViewportBackgroundSettings
  @Binding var sectionPlane: ViewportSectionPlane
  @Binding var lightingIntensity: Double
  @Binding var environmentPreset: ViewportEnvironmentPreset
  @Binding var environmentRotationDegrees: Double

  @State private var showsAdvancedSettings = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Studio")
          .font(.callout.weight(.semibold))
        Spacer()
        Button {
          showsAdvancedSettings.toggle()
        } label: {
          Label("Detailed environment settings", systemImage: "slider.horizontal.3")
            .labelStyle(.iconOnly)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(StudioPalette.muted)
        .help("Detailed environment settings")
      }
      .padding(.horizontal, 12)
      .padding(.top, 12)
      .padding(.bottom, 8)

      ScrollView {
        LazyVStack(spacing: 6) {
          ForEach(VisualizationEnvironmentCatalog.presets) { preset in
            environmentCard(preset)
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
      }
    }
    .popover(isPresented: $showsAdvancedSettings, arrowEdge: .trailing) {
      ViewportEnvironmentSettingsView(
        background: $background,
        sectionPlane: $sectionPlane,
        lightingIntensity: $lightingIntensity,
        environmentPreset: $environmentPreset,
        environmentRotationDegrees: $environmentRotationDegrees
      )
    }
  }

  private var selectedPresetID: VisualizationEnvironmentPresetID? {
    VisualizationEnvironmentCatalog.matching(
      background: background,
      environment: environmentPreset,
      intensity: lightingIntensity,
      rotationDegrees: environmentRotationDegrees
    )?.id
  }

  private func environmentCard(_ preset: VisualizationEnvironmentPreset) -> some View {
    let isSelected = selectedPresetID == preset.id
    return Button {
      apply(preset)
    } label: {
      ZStack(alignment: .bottomLeading) {
        EnvironmentCardBackground(settings: preset.background)

        VStack(spacing: 0) {
          Spacer(minLength: 8)
          ZStack(alignment: .bottom) {
            Ellipse()
              .fill(.black.opacity(preset.id == .transparent ? 0.18 : 0.28))
              .frame(width: 66, height: 15)
              .blur(radius: 1)
            MaterialSphere(
              appearance: PreviewPartAppearance(
                hexRGB: "#B4B7BA",
                finish: .metallic
              ) ?? .defaultAppearance(for: .mesh)
            )
            .frame(width: 88, height: 88)
            .offset(y: -5)
          }
          .frame(height: 102)

          HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 4) {
                Text(preset.name)
                  .font(.caption.weight(.semibold))
                if isSelected {
                  Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(StudioPalette.accent)
                }
              }
              if let colorLabel = preset.colorLabel {
                HStack(spacing: 4) {
                  Circle()
                    .fill(preset.background.primary.color)
                    .frame(width: 7, height: 7)
                  Text(colorLabel)
                    .font(.caption2.monospaced())
                }
                .foregroundStyle(StudioPalette.muted)
              }
            }
            Spacer()
            if isSelected {
              Image(systemName: "gearshape.fill")
                .font(.caption)
                .foregroundStyle(StudioPalette.muted)
            }
          }
          .padding(.horizontal, 10)
          .padding(.bottom, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.ultraThinMaterial)
        }
      }
      .frame(height: 154)
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .overlay {
        RoundedRectangle(cornerRadius: 7)
          .stroke(
            isSelected ? StudioPalette.accent : StudioPalette.border, lineWidth: isSelected ? 2 : 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
    .help("Use (preset.name) environment")
    .accessibilityLabel(preset.name)
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
  }

  private func apply(_ preset: VisualizationEnvironmentPreset) {
    background = preset.background
    environmentPreset = preset.environment
    lightingIntensity = preset.intensity
    environmentRotationDegrees = preset.rotationDegrees
  }
}

private struct EnvironmentCardBackground: View {
  let settings: ViewportBackgroundSettings

  @ViewBuilder var body: some View {
    switch settings.mode {
    case .transparent:
      CheckerboardBackground()
    default:
      settings.background
    }
  }
}

private struct CheckerboardBackground: View {
  var body: some View {
    Canvas { context, size in
      let tile: CGFloat = 12
      let columns = Int(ceil(size.width / tile))
      let rows = Int(ceil(size.height / tile))
      for row in 0..<rows {
        for column in 0..<columns {
          let tone =
            (row + column).isMultiple(of: 2)
            ? Color.white.opacity(0.88)
            : Color.gray.opacity(0.28)
          context.fill(
            Path(
              CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)),
            with: .color(tone)
          )
        }
      }
    }
    .background(Color.white.opacity(0.7))
  }
}

struct VisualizationMaterialBrowser: View {
  let selectedPartName: String?
  let usedMaterials: [VisualizationUsedMaterial]
  let applyPreset: (VisualizationMaterialPreset) -> Void
  let applyUsedMaterial: (PreviewPartAppearance) -> Void

  @State private var searchText = ""
  @State private var expandedCategories = Set(VisualizationMaterialCategory.allCases)

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(StudioPalette.muted)
        TextField("Search Materials", text: $searchText)
          .textFieldStyle(.plain)
      }
      .padding(.horizontal, 9)
      .frame(height: 30)
      .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 7))
      .overlay { RoundedRectangle(cornerRadius: 7).stroke(StudioPalette.border) }
      .padding(12)

      if let selectedPartName {
        Label("Applying to \(selectedPartName)", systemImage: "scope")
          .font(.caption)
          .foregroundStyle(StudioPalette.accent)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
      } else {
        Label("Select a part to apply a material", systemImage: "cursorarrow.click")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          usedMaterialsSection

          ForEach(VisualizationMaterialCategory.allCases) { category in
            categorySection(category)
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
      }
    }
  }

  @ViewBuilder
  private var usedMaterialsSection: some View {
    let filtered = usedMaterials.filter { material in
      searchText.isEmpty
        || material.name.localizedCaseInsensitiveContains(searchText)
        || material.appearance.hexRGB.localizedCaseInsensitiveContains(searchText)
        || material.appearance.finish.title.localizedCaseInsensitiveContains(searchText)
    }
    if !filtered.isEmpty {
      VStack(alignment: .leading, spacing: 7) {
        Text("Used Materials (\(usedMaterials.count))")
          .font(.callout.weight(.semibold))

        VStack(spacing: 0) {
          ForEach(Array(filtered.enumerated()), id: \.element.id) { index, material in
            Button {
              applyUsedMaterial(material.appearance)
            } label: {
              HStack(spacing: 10) {
                MaterialSphere(appearance: material.appearance)
                  .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                  Text(material.appearance.finish.title)
                    .font(.caption2)
                    .foregroundStyle(StudioPalette.muted)
                  Text(material.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                  HStack(spacing: 5) {
                    Circle()
                      .fill(material.appearance.color)
                      .frame(width: 8, height: 8)
                    Text(material.appearance.hexRGB)
                      .font(.caption2.monospaced())
                    if material.assignmentCount > 1 {
                      Text("×\(material.assignmentCount)")
                        .font(.caption2.monospaced())
                    }
                  }
                  .foregroundStyle(StudioPalette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundStyle(StudioPalette.muted)
              }
              .padding(8)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(selectedPartName == nil)

            if index < filtered.count - 1 { Divider().padding(.leading, 62) }
          }
        }
        .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 8))
      }

      Divider()
    }
  }

  @ViewBuilder
  private func categorySection(_ category: VisualizationMaterialCategory) -> some View {
    let presets = VisualizationMaterialCatalog.presets(in: category, matching: searchText)
    if !presets.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Button {
          if expandedCategories.contains(category) {
            expandedCategories.remove(category)
          } else {
            expandedCategories.insert(category)
          }
        } label: {
          HStack {
            Text(category.title)
              .font(.callout.weight(.semibold))
            Spacer()
            Image(
              systemName: expandedCategories.contains(category)
                ? "chevron.down" : "chevron.right"
            )
            .font(.caption)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if expandedCategories.contains(category) {
          LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible())],
            spacing: 6
          ) {
            ForEach(presets) { preset in
              Button {
                applyPreset(preset)
              } label: {
                VStack(alignment: .leading, spacing: 3) {
                  MaterialSphere(appearance: preset.appearance)
                    .frame(maxWidth: .infinity)
                    .frame(height: 112)
                  Text(preset.family)
                    .font(.caption2)
                    .foregroundStyle(StudioPalette.muted)
                  Text(preset.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                }
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                  RoundedRectangle(cornerRadius: 7)
                    .stroke(StudioPalette.border.opacity(0.85), lineWidth: 1)
                }
              }
              .buttonStyle(.plain)
              .disabled(selectedPartName == nil)
              .opacity(selectedPartName == nil ? 0.68 : 1)
              .help("Apply \(preset.family) \(preset.name)")
            }
          }
        }
      }
    }
  }
}

struct MaterialSphere: View {
  let appearance: PreviewPartAppearance

  var body: some View {
    GeometryReader { proxy in
      let diameter = min(proxy.size.width, proxy.size.height)
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [
                appearance.color.opacity(0.98),
                appearance.color.opacity(max(appearance.opacity, 0.22)),
                Color(
                  red: appearance.red * 0.34,
                  green: appearance.green * 0.34,
                  blue: appearance.blue * 0.34
                )
                .opacity(max(appearance.opacity, 0.32)),
              ],
              center: UnitPoint(x: 0.34, y: 0.28),
              startRadius: 1,
              endRadius: diameter * 0.62
            )
          )
        Circle()
          .fill(
            RadialGradient(
              colors: [.white.opacity(highlightOpacity), .clear],
              center: UnitPoint(x: 0.3, y: 0.22),
              startRadius: 0,
              endRadius: diameter * 0.34
            )
          )
        Rectangle()
          .fill(.black.opacity(0.28))
          .frame(width: diameter * 1.28, height: max(2, diameter * 0.045))
          .rotationEffect(.degrees(-42))
          .mask(Circle())
      }
      .frame(width: diameter, height: diameter)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
      .shadow(color: .black.opacity(0.26), radius: 5, y: 3)
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }

  private var highlightOpacity: Double {
    switch appearance.finish {
    case .matte: 0.22
    case .satin: 0.38
    case .glossy: 0.78
    case .metallic: 0.62
    }
  }
}

extension PreviewPartAppearance {
  fileprivate var color: Color { Color(red: red, green: green, blue: blue).opacity(opacity) }
}
