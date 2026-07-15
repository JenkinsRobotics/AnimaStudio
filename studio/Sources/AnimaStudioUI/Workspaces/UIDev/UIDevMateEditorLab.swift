import SwiftUI

struct UIDevMateEditorLab: View {
  @State private var selectedKind = MateCreationToolKind.slider
  @State private var showsOffset = true
  @State private var showsLimits = true
  @State private var isSimulationConnection = false
  @State private var offsetXMillimeters = 0.0
  @State private var offsetYMillimeters = 0.0
  @State private var offsetZMillimeters = 0.0
  @State private var rotationAngleDegrees = 0.0

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(minimum: 300), alignment: .top),
        GridItem(.flexible(minimum: 300), alignment: .top),
      ],
      alignment: .leading,
      spacing: 16
    ) {
      editorPreview
      tuningControls
      designRules
    }
  }

  private var editorPreview: some View {
    VStack(alignment: .leading, spacing: 12) {
      StudioSectionHeader(
        title: "Live Mate panel",
        detail: "Switch type and Offset to compare the compact and expanded states."
      )
      Divider()
      UIDevMateEditorPanel(
        selectedKind: $selectedKind,
        showsOffset: $showsOffset,
        showsLimits: $showsLimits,
        isSimulationConnection: $isSimulationConnection,
        offsetXMillimeters: $offsetXMillimeters,
        offsetYMillimeters: $offsetYMillimeters,
        offsetZMillimeters: $offsetZMillimeters,
        rotationAngleDegrees: $rotationAngleDegrees
      )
      .frame(maxWidth: 350)
      .frame(maxWidth: .infinity)
    }
    .studioCardSurface()
  }

  private var tuningControls: some View {
    VStack(alignment: .leading, spacing: 14) {
      StudioSectionHeader(
        title: "Lab controls",
        detail: "Tune state and density here before binding the panel to mate data."
      )
      Divider()
      VStack(alignment: .leading, spacing: 6) {
        StudioFieldLabel(title: "Mate Type")
        Picker("Mate Type", selection: $selectedKind) {
          ForEach(MateCreationToolKind.allCases) { kind in
            Text(kind.title).tag(kind)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      Toggle("Show Offset controls", isOn: $showsOffset)
      Toggle("Show Limits controls", isOn: $showsLimits)
        .disabled(!selectedKind.supportsLimits)
      Toggle("Simulation connection", isOn: $isSimulationConnection)
      StudioReadoutRow(title: "Degrees of Freedom", value: selectedKind.dofSummary)
      Text(selectedKind.motionSummary)
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .studioCardSurface()
  }

  private var designRules: some View {
    VStack(alignment: .leading, spacing: 12) {
      StudioSectionHeader(
        title: "Interaction rules",
        detail: "The panel stays dense without hiding state or units."
      )
      Divider()
      rule("One primary decision row", "Accept and Cancel remain fixed in the header.")
      rule("Progressive disclosure", "Offset fields exist only while Offset is enabled.")
      rule("Type-owned motion", "Limits expose only the freedoms allowed by the selected mate.")
      rule("Connector first", "The connector picker is the initial focused control.")
      rule("Explicit units", "Distance uses mm and rotation uses degrees in the operator UI.")
    }
    .studioCardSurface()
  }

  private func rule(_ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(StudioPalette.semanticPart)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
    }
  }
}

private struct UIDevMateEditorPanel: View {
  @Binding var selectedKind: MateCreationToolKind
  @Binding var showsOffset: Bool
  @Binding var showsLimits: Bool
  @Binding var isSimulationConnection: Bool
  @Binding var offsetXMillimeters: Double
  @Binding var offsetYMillimeters: Double
  @Binding var offsetZMillimeters: Double
  @Binding var rotationAngleDegrees: Double

  @State private var facesToConnect = ""
  @State private var offsetRotationAxis = MateEditorAxis.x
  @State private var minimumLimits: [MateEditorDegreeOfFreedom: String] = [:]
  @State private var maximumLimits: [MateEditorDegreeOfFreedom: String] = [:]

  var body: some View {
    VStack(spacing: 0) {
      kindStrip
      Divider()
      decisionHeader
      Divider()
      VStack(alignment: .leading, spacing: 9) {
        typePicker
        connectorPicker
        Toggle("Offset", isOn: $showsOffset)
          .toggleStyle(.checkbox)
        if showsOffset {
          offsetControls
        }
        limitsControls
        Toggle("Simulation connection", isOn: $isSimulationConnection)
          .toggleStyle(.checkbox)
        if isSimulationConnection {
          TextField("Faces to connect", text: $facesToConnect)
            .textFieldStyle(.roundedBorder)
        }
        actionFooter
      }
      .padding(10)
    }
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.32), radius: 10, y: 4)
    .onChange(of: selectedKind) { _, kind in
      if let firstAxis = kind.offsetRotationAxes.first,
        !kind.offsetRotationAxes.contains(offsetRotationAxis)
      {
        offsetRotationAxis = firstAxis
      }
    }
  }

  private var kindStrip: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 5) {
        ForEach(MateCreationToolKind.allCases) { kind in
          Button(kind.title, systemImage: kind.systemImage) {
            selectedKind = kind
          }
          .labelStyle(.iconOnly)
          .buttonStyle(StudioIconButtonStyle(isSelected: selectedKind == kind))
          .help(kind.title)
          .accessibilityLabel("\(kind.title) mate")
        }
      }
      .padding(7)
    }
    .scrollIndicators(.hidden)
    .background(StudioPalette.chrome)
  }

  private var decisionHeader: some View {
    HStack(spacing: 8) {
      Text("\(selectedKind.title) 1")
        .font(.callout.weight(.bold))
        .foregroundStyle(StudioPalette.joint)
      Spacer()
      Button("Accept Mate", systemImage: "checkmark") {}
        .labelStyle(.iconOnly)
        .buttonStyle(StudioIconButtonStyle(isSelected: true))
        .help("Accept mate")
      Button("Cancel Mate", systemImage: "xmark") {}
        .labelStyle(.iconOnly)
        .buttonStyle(StudioIconButtonStyle())
        .foregroundStyle(.red)
        .help("Cancel mate")
    }
    .padding(.leading, 10)
    .padding(.trailing, 7)
    .frame(height: 38)
    .background(StudioPalette.panelInset)
  }

  private var typePicker: some View {
    Menu {
      ForEach(MateCreationToolKind.allCases) { kind in
        Button {
          selectedKind = kind
        } label: {
          if selectedKind == kind {
            Label(kind.title, systemImage: "checkmark")
          } else {
            Text(kind.title)
          }
        }
      }
    } label: {
      HStack(spacing: 7) {
        Image(systemName: selectedKind.systemImage)
          .foregroundStyle(StudioPalette.joint)
        Text(selectedKind.title)
        Spacer(minLength: 8)
        Image(systemName: "chevron.down")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.horizontal, 9)
      .frame(height: StudioMetrics.fieldHeight)
      .background(StudioPalette.field)
      .overlay {
        RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Mate type")
    .accessibilityValue(selectedKind.title)
  }

  private var connectorPicker: some View {
    Button {
    } label: {
      HStack {
        Text("Mate connectors")
          .font(.callout)
        Spacer()
        Image(systemName: "scope")
      }
      .padding(.horizontal, 9)
      .frame(height: 32)
      .background(StudioPalette.field)
      .overlay {
        RoundedRectangle(cornerRadius: 4)
          .stroke(StudioPalette.accent, lineWidth: 1.5)
      }
    }
    .buttonStyle(.plain)
    .help("Select the two part-local mate connectors")
  }

  private var offsetControls: some View {
    VStack(spacing: 7) {
      ForEach(selectedKind.offsetTranslationAxes) { axis in
        MateAxisValueRow(
          axis: axis.rawValue,
          color: axis.color,
          value: offsetBinding(for: axis),
          unit: "mm"
        )
      }
      if !selectedKind.offsetRotationAxes.isEmpty {
        Picker("Rotation axis", selection: $offsetRotationAxis) {
          ForEach(selectedKind.offsetRotationAxes) { axis in
            Text("Rotate about \(axis.rawValue)").tag(axis)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        MateAxisValueRow(
          axis: "∠",
          color: StudioPalette.joint,
          value: $rotationAngleDegrees,
          unit: "deg"
        )
      }
    }
    .padding(.leading, 2)
  }

  @ViewBuilder
  private var limitsControls: some View {
    if selectedKind.supportsLimits {
      Toggle("Limits", isOn: $showsLimits)
        .toggleStyle(.checkbox)
      if showsLimits {
        VStack(spacing: 7) {
          ForEach(selectedKind.editorDegreesOfFreedom) { freedom in
            MateLimitValueRow(
              freedom: freedom,
              bound: .minimum,
              value: limitBinding(for: freedom, values: $minimumLimits)
            )
            MateLimitValueRow(
              freedom: freedom,
              bound: .maximum,
              value: limitBinding(for: freedom, values: $maximumLimits)
            )
          }
        }
        .padding(.leading, 2)
      }
    } else {
      HStack(spacing: 7) {
        Image(systemName: "lock.fill")
          .foregroundStyle(StudioPalette.joint)
        Text("Fastened removes all motion; there are no limits to configure.")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.vertical, 3)
    }
  }

  private func offsetBinding(for axis: MateEditorAxis) -> Binding<Double> {
    switch axis {
    case .x: $offsetXMillimeters
    case .y: $offsetYMillimeters
    case .z: $offsetZMillimeters
    }
  }

  private func limitBinding(
    for freedom: MateEditorDegreeOfFreedom,
    values: Binding<[MateEditorDegreeOfFreedom: String]>
  ) -> Binding<String> {
    Binding(
      get: { values.wrappedValue[freedom, default: ""] },
      set: { values.wrappedValue[freedom] = $0 }
    )
  }

  private var actionFooter: some View {
    HStack(spacing: 7) {
      actionIcon(
        "Flip connector",
        systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
      actionIcon("Reorient axes", systemImage: "rotate.3d")
      actionIcon("Preview motion", systemImage: "play.fill")
      Button("Solve") {}
        .buttonStyle(
          StudioButtonStyle(role: .secondary, density: .compact, expandsHorizontally: false)
        )
      Spacer()
      actionIcon("Mate help", systemImage: "questionmark.circle")
    }
  }

  private func actionIcon(_ title: String, systemImage: String) -> some View {
    Button(title, systemImage: systemImage) {}
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle())
      .help(title)
  }
}

private enum MateLimitBound {
  case minimum
  case maximum

  var placeholder: String {
    switch self {
    case .minimum: "No minimum"
    case .maximum: "No maximum"
    }
  }

  var symbol: String {
    switch self {
    case .minimum: "greaterthanorequalto"
    case .maximum: "lessthanorequalto"
    }
  }
}

private struct MateLimitValueRow: View {
  let freedom: MateEditorDegreeOfFreedom
  let bound: MateLimitBound
  @Binding var value: String

  var body: some View {
    HStack(spacing: 5) {
      Text(freedom.axis.rawValue)
        .font(.caption.weight(.bold))
        .foregroundStyle(freedom.axis.color)
      Image(systemName: bound.symbol)
        .font(.caption2)
        .foregroundStyle(freedom.axis.color)
        .frame(width: 11)
      TextField(bound.placeholder, text: $value)
        .textFieldStyle(.plain)
        .font(.system(.caption, design: .monospaced))
        .multilineTextAlignment(.trailing)
      Text(freedom.unitLabel)
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 28, alignment: .trailing)
    }
    .padding(.horizontal, 5)
    .frame(height: 26)
    .overlay(alignment: .bottom) {
      Divider()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(freedom.title) \(bound.placeholder.lowercased())")
  }
}

extension MateEditorAxis {
  fileprivate var color: Color {
    switch self {
    case .x: .red
    case .y: .green
    case .z: .blue
    }
  }
}

private struct MateAxisValueRow: View {
  let axis: String
  let color: Color
  @Binding var value: Double
  let unit: String

  var body: some View {
    HStack(spacing: 6) {
      Text(axis)
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .frame(width: 16, alignment: .leading)
      TextField(axis, value: $value, format: .number.precision(.fractionLength(0...2)))
        .labelsHidden()
        .textFieldStyle(.plain)
        .font(.system(.caption, design: .monospaced))
        .multilineTextAlignment(.trailing)
      Text(unit)
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 28, alignment: .trailing)
    }
    .padding(.horizontal, 5)
    .frame(height: 26)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}
