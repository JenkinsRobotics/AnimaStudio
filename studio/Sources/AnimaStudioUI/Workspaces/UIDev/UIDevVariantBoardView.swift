import SwiftUI

struct UIDevVariantBoardView: View {
  @State private var search = ""
  @State private var selectedFamily: UIDevVariantFamily?
  @State private var zoomPercent = 65
  @State private var selectedVariantID: UIDevWindowVariantID?

  private let columnCount = 4

  private var visibleFamilies: [UIDevVariantFamily] {
    if let selectedFamily { return [selectedFamily] }
    return UIDevVariantFamily.allCases
  }

  private var cardWidth: CGFloat {
    250 * CGFloat(zoomPercent) / 65
  }

  private var boardWidth: CGFloat {
    cardWidth * CGFloat(columnCount) + CGFloat(columnCount - 1) * 16
  }

  var body: some View {
    VStack(spacing: 0) {
      boardToolbar
      Divider()
      ScrollView([.horizontal, .vertical]) {
        VStack(alignment: .leading, spacing: 34) {
          boardIntroduction
          ForEach(visibleFamilies) { family in
            let variants = filteredVariants(in: family)
            if !variants.isEmpty {
              familySection(family, variants: variants)
            }
          }
        }
        .padding(26)
        .frame(width: boardWidth, alignment: .topLeading)
      }
      boardFooter
    }
    .background(StudioPalette.canvas)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("UI Dev window variant comparison board")
  }

  private var boardToolbar: some View {
    HStack(spacing: 10) {
      Label("VARIANT BOARD", systemImage: "rectangle.grid.3x2.fill")
        .font(.caption.weight(.bold))
        .tracking(0.9)
        .foregroundStyle(StudioPalette.accent)

      StudioSearchField(prompt: "Search windows and states", text: $search)
        .frame(width: 230)

      Menu {
        Button("All Families") { selectedFamily = nil }
        Divider()
        ForEach(UIDevVariantFamily.allCases) { family in
          Button(family.title) { selectedFamily = family }
        }
      } label: {
        Label(selectedFamily?.title ?? "All Families", systemImage: "line.3.horizontal.decrease")
      }
      .menuStyle(.borderlessButton)
      .frame(minWidth: 150)

      Spacer()

      Button {
        changeZoom(by: -15)
      } label: {
        Image(systemName: "minus")
      }
      .buttonStyle(StudioIconButtonStyle())
      .help("Reduce specimen size")

      Text("\(zoomPercent)%")
        .font(.caption.monospaced().weight(.bold))
        .frame(width: 42)

      Button {
        changeZoom(by: 15)
      } label: {
        Image(systemName: "plus")
      }
      .buttonStyle(StudioIconButtonStyle())
      .help("Increase specimen size")

      Button {
        zoomPercent = 65
      } label: {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
      }
      .buttonStyle(StudioIconButtonStyle())
      .help("Reset board density")
    }
    .padding(.horizontal, 18)
    .frame(height: 52)
    .background(StudioPalette.chrome)
  }

  private var boardIntroduction: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Window families and their states")
          .font(.title2.weight(.bold))
        Text(
          "A wide comparison surface for reviewing related variants together. The existing Template Matrix and every focused interaction lab remain unchanged."
        )
        .font(.callout)
        .foregroundStyle(StudioPalette.muted)
        .fixedSize(horizontal: false, vertical: true)
      }
      Spacer()
      boardMetric("\(UIDevVariantBoardCatalog.variants.count)", "VARIANTS")
      boardMetric("\(UIDevVariantFamily.allCases.count)", "FAMILIES")
    }
    .padding(18)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 13))
    .overlay {
      RoundedRectangle(cornerRadius: 13)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private var boardFooter: some View {
    HStack(spacing: 14) {
      Label("Click a specimen to focus its comparison border", systemImage: "cursorarrow.click")
      Label(
        "Search and family filters never remove catalog entries",
        systemImage: "line.3.horizontal.decrease")
      Spacer()
      Text("PAGE · COMPONENT VARIANTS")
        .font(.caption2.monospaced().weight(.bold))
        .foregroundStyle(StudioPalette.accent)
    }
    .font(.caption2)
    .foregroundStyle(StudioPalette.muted)
    .padding(.horizontal, 16)
    .frame(height: 34)
    .background(StudioPalette.chrome)
  }

  private func familySection(
    _ family: UIDevVariantFamily,
    variants: [UIDevWindowVariantDescriptor]
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Image(systemName: family.systemImage)
          .foregroundStyle(StudioPalette.accent)
        Text(family.title)
          .font(.title3.weight(.bold))
        Text(family.detail)
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Text("\(variants.count) VARIANTS")
          .font(.caption2.monospaced().weight(.bold))
          .foregroundStyle(StudioPalette.muted)
      }

      LazyVGrid(
        columns: Array(
          repeating: GridItem(.fixed(cardWidth), spacing: 16, alignment: .top),
          count: columnCount
        ),
        alignment: .leading,
        spacing: 16
      ) {
        ForEach(variants) { descriptor in
          variantCard(descriptor)
        }
      }
    }
  }

  private func variantCard(_ descriptor: UIDevWindowVariantDescriptor) -> some View {
    let isSelected = selectedVariantID == descriptor.id

    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: descriptor.systemImage)
          .foregroundStyle(StudioPalette.accent)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 1) {
          Text(descriptor.title)
            .font(.caption.weight(.bold))
          Text(descriptor.stateLabel)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(StudioPalette.accent)
        }
        Spacer(minLength: 4)
        Text(descriptor.idealSizeLabel)
          .font(.system(size: 8, weight: .medium, design: .monospaced))
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(9)
      .background(StudioPalette.chrome)

      Divider()

      UIDevVariantBoardSpecimenView(id: descriptor.id, cardWidth: cardWidth)
        .frame(maxWidth: .infinity, minHeight: previewHeight(for: descriptor))
        .padding(9)
        .background(StudioPalette.panelInset.opacity(0.42))

      Divider()

      Text(descriptor.detail)
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
        .lineLimit(2)
        .padding(9)
    }
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(
          isSelected ? StudioPalette.accent : StudioPalette.border,
          style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: isSelected ? [6, 4] : [])
        )
    }
    .shadow(color: .black.opacity(isSelected ? 0.30 : 0.16), radius: isSelected ? 9 : 5, y: 3)
    .contentShape(Rectangle())
    .onTapGesture {
      selectedVariantID = isSelected ? nil : descriptor.id
    }
  }

  private func boardMetric(_ value: String, _ label: String) -> some View {
    VStack(spacing: 2) {
      Text(value).font(.title3.monospaced().weight(.bold))
      Text(label).font(.system(size: 8, weight: .bold, design: .monospaced))
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(10)
    .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 8))
  }

  private func filteredVariants(
    in family: UIDevVariantFamily
  ) -> [UIDevWindowVariantDescriptor] {
    let candidates = UIDevVariantBoardCatalog.variants(in: family)
    guard !search.isEmpty else { return candidates }
    return candidates.filter {
      $0.title.localizedCaseInsensitiveContains(search)
        || $0.detail.localizedCaseInsensitiveContains(search)
        || $0.stateLabel.localizedCaseInsensitiveContains(search)
    }
  }

  private func previewHeight(for descriptor: UIDevWindowVariantDescriptor) -> CGFloat {
    let aspectRatio = CGFloat(descriptor.idealWidth) / CGFloat(descriptor.idealHeight)
    return min(max(cardWidth / max(aspectRatio, 0.2), 118), 390)
  }

  private func changeZoom(by delta: Int) {
    zoomPercent = min(max(zoomPercent + delta, 50), 110)
  }
}
