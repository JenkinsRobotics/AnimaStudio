// Visualization browser (Shapr3D idiom): Material / Environment tabs with sphere
// previews. Picking a material drives the shared theme's surface + colour;
// picking an environment drives the viewport background — so it's live, not art.
import AppKit
import SwiftUI

struct StudioMaterial: Identifiable, Equatable {
  var id: String { "\(category)/\(finish) \(name)" }
  let name: String
  let category: String
  let finish: String            // "Glossy" | "Matte"
  let color: SIMD3<Float>
  var roughness: Float { finish == "Glossy" ? 0.18 : 0.75 }
  var metallic: Float { category == "Metal" ? 0.9 : 0.0 }
  var hex: String {
    String(format: "#%02X%02X%02X",
      Int(color.x * 255), Int(color.y * 255), Int(color.z * 255))
  }
}

struct StudioEnvironment: Identifiable, Equatable {
  var id: String { name }
  let name: String
  let background: SIMD3<Float>
  var swatchIsCheckered = false
}

enum VisualizationCatalog {
  static let materials: [StudioMaterial] = [
    .init(name: "ABS", category: "Plastic", finish: "Glossy", color: [0.90, 0.13, 0.15]),
    .init(name: "ABS", category: "Plastic", finish: "Matte", color: [0.85, 0.15, 0.17]),
    .init(name: "Nylon", category: "Plastic", finish: "Matte", color: [0.16, 0.16, 0.17]),
    .init(name: "Carbon", category: "Plastic", finish: "Glossy", color: [0.08, 0.08, 0.09]),
    .init(name: "Aluminium", category: "Metal", finish: "Glossy", color: [0.78, 0.79, 0.82]),
    .init(name: "Anodised", category: "Metal", finish: "Matte", color: [0.35, 0.40, 0.48]),
    .init(name: "Brass", category: "Metal", finish: "Glossy", color: [0.83, 0.68, 0.32]),
    .init(name: "Steel", category: "Metal", finish: "Matte", color: [0.55, 0.57, 0.60]),
    .init(name: "Clear Glass — Thin", category: "Glass", finish: "Glossy", color: [1, 1, 1]),
  ]

  static let environments: [StudioEnvironment] = [
    .init(name: "Default", background: [0.16, 0.17, 0.19]),
    .init(name: "Transparent", background: [0.55, 0.55, 0.57], swatchIsCheckered: true),
    .init(name: "Colored Mood", background: [0.0, 0.65, 1.0]),
    .init(name: "Gradient Mood", background: [0.95, 0.95, 0.95]),
    .init(name: "Black and White Stage", background: [1, 1, 1]),
  ]

  static var categories: [String] {
    var seen: [String] = []
    for material in materials where !seen.contains(material.category) { seen.append(material.category) }
    return seen
  }
}

/// Sphere preview with the Shapr3D diagonal band.
struct MaterialSphere: View {
  var color: SIMD3<Float>
  var glossy: Bool
  var size: CGFloat = 54
  var checkered = false

  var body: some View {
    ZStack {
      if checkered { CheckerPattern().clipShape(Circle()) }
      Circle()
        .fill(RadialGradient(
          colors: [
            Color.white.opacity(glossy ? 0.95 : 0.42),
            base,
            base.opacity(0.55),
            Color.black.opacity(0.55),
          ],
          center: UnitPoint(x: 0.34, y: 0.26),
          startRadius: glossy ? 1 : 4,
          endRadius: size * (glossy ? 0.62 : 0.95)))
      // diagonal band, as in the reference swatches
      Rectangle().fill(Color.black.opacity(0.30))
        .frame(width: size * 1.5, height: size * 0.075)
        .rotationEffect(.degrees(-38))
        .clipShape(Circle().size(width: size, height: size))
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
  }

  private var base: Color { Color(red: Double(color.x), green: Double(color.y), blue: Double(color.z)) }
}

private struct CheckerPattern: View {
  var body: some View {
    Canvas { context, size in
      let step: CGFloat = 7
      var row = 0
      var y: CGFloat = 0
      while y < size.height {
        var column = 0
        var x: CGFloat = 0
        while x < size.width {
          if (row + column).isMultiple(of: 2) {
            context.fill(Path(CGRect(x: x, y: y, width: step, height: step)),
              with: .color(.white.opacity(0.85)))
          }
          x += step
          column += 1
        }
        y += step
        row += 1
      }
    }
    .background(Color.gray.opacity(0.35))
  }
}

struct VisualizationPanel: View {
  @Bindable private var render = RenderState.shared
  @State private var tab = 0
  @State private var search = ""
  @State private var used: [StudioMaterial] = Array(VisualizationCatalog.materials.prefix(3))
  @State private var environment = "Default"

  private var results: [StudioMaterial] {
    search.isEmpty ? VisualizationCatalog.materials
      : VisualizationCatalog.materials.filter {
        $0.name.localizedCaseInsensitiveContains(search)
          || $0.category.localizedCaseInsensitiveContains(search)
      }
  }

  var body: some View {
    VStack(spacing: 12) {
      Picker("", selection: $tab) {
        Text("Material").tag(0)
        Text("Environment").tag(1)
      }
      .pickerStyle(.segmented).labelsHidden()

      if tab == 0 { materialTab } else { environmentTab }
    }
    .padding(14)
    .frame(width: 300, height: 430)
  }

  // MARK: - Material

  private var materialTab: some View {
    VStack(alignment: .leading, spacing: 10) {
      SearchField(placeholder: "Search Materials", text: $search)
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          if search.isEmpty, !used.isEmpty {
            Text("Used Materials (\(used.count))")
              .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(UI.text)
            VStack(spacing: 6) { ForEach(used) { usedRow($0) } }
          }
          ForEach(VisualizationCatalog.categories, id: \.self) { category in
            let items = results.filter { $0.category == category }
            if !items.isEmpty {
              Text(category).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(UI.text)
              LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8) {
                ForEach(items) { swatch($0) }
              }
            }
          }
        }
      }
    }
  }

  private func usedRow(_ material: StudioMaterial) -> some View {
    Button { apply(material) } label: {
      HStack(spacing: 10) {
        MaterialSphere(color: material.color, glossy: material.finish == "Glossy", size: 38)
        VStack(alignment: .leading, spacing: 1) {
          Text(material.finish).font(.system(size: 9.5)).foregroundStyle(UI.text3)
          Text(material.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(UI.text)
          HStack(spacing: 4) {
            Circle().fill(swatchColor(material)).frame(width: 7, height: 7)
            Text(material.hex).font(.system(size: 9, design: .monospaced)).foregroundStyle(UI.text3)
          }
        }
        Spacer(minLength: 4)
        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(UI.text3)
      }
      .padding(8)
      .background(UI.panel, in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(UI.stroke, lineWidth: 1))
    }.buttonStyle(.plain)
  }

  private func swatch(_ material: StudioMaterial) -> some View {
    Button { apply(material) } label: {
      VStack(alignment: .leading, spacing: 6) {
        MaterialSphere(color: material.color, glossy: material.finish == "Glossy", size: 74)
          .frame(maxWidth: .infinity)
        Text(material.finish).font(.system(size: 9)).foregroundStyle(UI.text3)
        Text(material.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(UI.text)
      }
      .padding(8)
      .background(UI.panelHi.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10)
        .stroke(isActive(material) ? UI.accent : UI.stroke, lineWidth: isActive(material) ? 2 : 1))
    }.buttonStyle(.plain)
  }

  // MARK: - Environment

  private var environmentTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text("Studio").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(UI.text)
        ForEach(VisualizationCatalog.environments) { item in
          Button { apply(item) } label: {
            HStack(spacing: 12) {
              MaterialSphere(color: [0.72, 0.73, 0.76], glossy: true, size: 46,
                checkered: item.swatchIsCheckered)
              VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                  Text(item.name).font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(UI.text)
                  if environment == item.name {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 9))
                      .foregroundStyle(UI.accent)
                  }
                }
                Text(hex(item.background)).font(.system(size: 9, design: .monospaced))
                  .foregroundStyle(UI.text3)
              }
              Spacer(minLength: 4)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(environment == item.name ? UI.accent.opacity(0.14) : UI.panel,
              in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
              .stroke(environment == item.name ? UI.accent : UI.stroke, lineWidth: 1))
          }.buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: - Apply to the live theme

  private func apply(_ material: StudioMaterial) {
    withAnimation(.easeInOut(duration: 0.15)) {
      render.theme.overrideColor = SIMD4(material.color.x, material.color.y, material.color.z, 1)
      render.theme.roughness = material.roughness
      render.theme.metallic = material.metallic
    }
    used.removeAll { $0.id == material.id }
    used.insert(material, at: 0)
    used = Array(used.prefix(3))
  }

  private func apply(_ item: StudioEnvironment) {
    withAnimation(.easeInOut(duration: 0.15)) {
      render.theme.background = item.background
      environment = item.name
    }
  }

  private func isActive(_ material: StudioMaterial) -> Bool {
    guard let override = render.theme.overrideColor else { return false }
    return abs(override.x - material.color.x) < 0.01 && abs(override.y - material.color.y) < 0.01
      && abs(override.z - material.color.z) < 0.01
      && abs(render.theme.roughness - material.roughness) < 0.01
  }

  private func swatchColor(_ material: StudioMaterial) -> Color {
    Color(red: Double(material.color.x), green: Double(material.color.y),
      blue: Double(material.color.z))
  }

  private func hex(_ c: SIMD3<Float>) -> String {
    String(format: "#%02X%02X%02X", Int(c.x * 255), Int(c.y * 255), Int(c.z * 255))
  }
}

/// The rainbow Visualization button from the reference.
struct VisualizationIcon: View {
  var size: CGFloat = 22
  var body: some View {
    Circle()
      .fill(AngularGradient(
        colors: [.purple, .blue, .cyan, .green, .yellow, .orange, .red, .purple],
        center: .center))
      .frame(width: size, height: size)
      .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
  }
}
