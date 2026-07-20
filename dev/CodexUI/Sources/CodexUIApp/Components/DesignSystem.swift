import CodexUICore
import SwiftUI

enum WorkspacePanelPresentation: Equatable {
  case docked
  case floating
}

private struct WorkspacePanelPresentationKey: EnvironmentKey {
  static let defaultValue = WorkspacePanelPresentation.docked
}

private struct FloatingWidgetDragEnabledKey: EnvironmentKey {
  static let defaultValue = false
}

private struct FloatingWidgetWorkspaceSizeKey: EnvironmentKey {
  static let defaultValue = CGSize.zero
}

let floatingWidgetCoordinateSpaceName = "CodexUIFloatingWorkspace"

private struct FloatingWidgetFramePreferenceKey: PreferenceKey {
  static let defaultValue = CGRect.zero

  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

extension EnvironmentValues {
  var workspacePanelPresentation: WorkspacePanelPresentation {
    get { self[WorkspacePanelPresentationKey.self] }
    set { self[WorkspacePanelPresentationKey.self] = newValue }
  }

  var floatingWidgetDragEnabled: Bool {
    get { self[FloatingWidgetDragEnabledKey.self] }
    set { self[FloatingWidgetDragEnabledKey.self] = newValue }
  }

  var floatingWidgetWorkspaceSize: CGSize {
    get { self[FloatingWidgetWorkspaceSizeKey.self] }
    set { self[FloatingWidgetWorkspaceSizeKey.self] = newValue }
  }
}

struct PrototypePanel<Content: View>: View {
  @Environment(\.prototypeTheme) private var theme
  @Environment(\.workspacePanelPresentation) private var presentation
  @Environment(\.floatingWidgetDragEnabled) private var floatingWidgetDragEnabled
  @Environment(\.floatingWidgetWorkspaceSize) private var floatingWidgetWorkspaceSize
  let title: String
  let subtitle: String?
  let icon: String?
  let minimumContentHeight: CGFloat?
  @ViewBuilder let content: Content
  @State private var floatingOffset = CGSize.zero
  @State private var measuredFrame = CGRect.zero
  @State private var dragStartFrame: CGRect?
  @State private var dragOriginOffset = CGSize.zero
  @State private var isDragging = false

  init(
    _ title: String, subtitle: String? = nil, icon: String? = nil,
    minimumContentHeight: CGFloat? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.minimumContentHeight = minimumContentHeight
    self.content = content()
  }

  var body: some View {
    let floating = presentation == .floating
    let draggable = floating && floatingWidgetDragEnabled
    let radius =
      floating
      ? PrototypeDesignMetrics.floatingPanelRadius : PrototypeDesignMetrics.panelRadius

    VStack(spacing: 0) {
      panelHeader(floating: floating, draggable: draggable)
      Divider().overlay(theme.line)
      content
        .frame(minHeight: minimumContentHeight, alignment: .top)
    }
    .foregroundStyle(theme.primaryText)
    .background(
      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(panelFill(floating: floating))
    )
    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .stroke(floating ? theme.strongLine : theme.line, lineWidth: 1)
    )
    .shadow(
      color: .black.opacity(floating ? (isDragging ? 0.12 : 0.18) : 0),
      radius: floating ? (isDragging ? 7 : 14) : 0,
      y: floating ? (isDragging ? 2 : 6) : 0
    )
    .background {
      if draggable {
        GeometryReader { proxy in
          Color.clear.preference(
            key: FloatingWidgetFramePreferenceKey.self,
            value: proxy.frame(in: .named(floatingWidgetCoordinateSpaceName))
          )
        }
      }
    }
    .onPreferenceChange(FloatingWidgetFramePreferenceKey.self) { frame in
      if !isDragging, !frame.isEmpty {
        measuredFrame = frame
      }
    }
    .offset(x: draggable ? floatingOffset.width : 0, y: draggable ? floatingOffset.height : 0)
    .zIndex(isDragging ? 50 : 0)
    .transaction { transaction in
      if isDragging {
        transaction.animation = nil
        transaction.disablesAnimations = true
      }
    }
    .onChange(of: presentation) { _, value in
      if value == .docked {
        floatingOffset = .zero
        measuredFrame = .zero
        dragStartFrame = nil
        isDragging = false
      }
    }
  }

  private func panelFill(floating: Bool) -> AnyShapeStyle {
    if !floating { return AnyShapeStyle(theme.panel) }
    // Backdrop materials are expensive to recompute while moving. Use an
    // opaque theme surface during the gesture, then restore material at rest.
    return isDragging ? AnyShapeStyle(theme.raised) : AnyShapeStyle(.regularMaterial)
  }

  private func panelHeader(floating: Bool, draggable: Bool) -> some View {
    HStack(spacing: 7) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(theme.secondaryText)
          .frame(width: 16)
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(title.uppercased())
          .font(.system(size: 10.5, weight: .semibold))
          .tracking(0.6)
          .foregroundStyle(theme.primaryText)
        if let subtitle {
          Text(subtitle.uppercased())
            .font(.system(size: 8.5, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(theme.tertiaryText)
        }
      }
      Spacer()
      Image(systemName: draggable ? "line.3.horizontal" : "ellipsis")
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(draggable ? theme.accent : theme.secondaryText)
        .frame(width: 24, height: 22)
        .background(
          draggable ? theme.accent.opacity(0.10) : .clear,
          in: RoundedRectangle(cornerRadius: 6))
    }
    .padding(.horizontal, PrototypeDesignMetrics.panelHorizontalPadding)
    .frame(height: subtitle == nil ? 42 : 50)
    .background(theme.raised.opacity(floating ? 0.34 : 0.52))
    .contentShape(Rectangle())
    .gesture(widgetDrag, including: draggable ? .all : .none)
    .help(draggable ? "Drag to reposition this context widget" : "")
  }

  private var widgetDrag: some Gesture {
    DragGesture(minimumDistance: 2, coordinateSpace: .named(floatingWidgetCoordinateSpaceName))
      .onChanged { value in
        if !isDragging {
          isDragging = true
          dragOriginOffset = floatingOffset
          dragStartFrame = measuredFrame
        }
        guard let dragStartFrame else { return }
        let translation = FloatingWidgetPlacement.constrainedTranslation(
          startingFrame: dragStartFrame,
          translation: value.translation,
          workspaceSize: floatingWidgetWorkspaceSize
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
          floatingOffset = CGSize(
            width: dragOriginOffset.width + translation.width,
            height: dragOriginOffset.height + translation.height
          )
        }
      }
      .onEnded { _ in
        isDragging = false
        dragStartFrame = nil
      }
  }
}

struct LabelPill: View {
  @Environment(\.prototypeTheme) private var theme
  let text: String
  var color: Color? = nil

  var body: some View {
    Text(text)
      .font(.system(size: 8.5, weight: .semibold))
      .tracking(0.5)
      .foregroundStyle(color ?? theme.secondaryText)
      .padding(.horizontal, 7).padding(.vertical, 3)
      .background((color ?? theme.secondaryText).opacity(0.12), in: Capsule())
      .overlay(Capsule().stroke((color ?? theme.secondaryText).opacity(0.22)))
  }
}

struct PrototypeRow: View {
  @Environment(\.prototypeTheme) private var theme
  let icon: String
  let title: String
  var detail = ""
  var level = 0
  var selected = false
  var statusColor: Color? = nil
  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 8) {
      Color.clear.frame(width: CGFloat(level * 13), height: 1)
      Image(systemName: icon)
        .font(.system(size: 12))
        .frame(width: 16)
        .foregroundStyle(selected ? theme.accent : theme.iconText)
      Text(title).font(.system(size: 12.5, weight: selected ? .semibold : .regular)).lineLimit(1)
      Spacer()
      if !detail.isEmpty {
        Text(detail).font(.system(size: 10, design: .rounded)).foregroundStyle(theme.tertiaryText)
      }
      if let statusColor {
        Circle().fill(statusColor).frame(width: 6, height: 6)
      }
    }
    .padding(.leading, 10)
    .padding(.trailing, 10)
    .frame(height: 31)
    .foregroundStyle(selected ? theme.primaryText : theme.primaryText.opacity(0.90))
    .background(
      selected ? theme.accent.opacity(0.14) : (isHovered ? theme.controlHover : .clear)
    )
    .overlay(alignment: .leading) {
      if selected { Rectangle().fill(theme.accent).frame(width: 2) }
    }
    .contentShape(Rectangle())
    .onHover { isHovered = $0 }
    .animation(.easeOut(duration: 0.12), value: isHovered)
  }
}

struct MetricCard: View {
  @Environment(\.prototypeTheme) private var theme
  let title: String
  let value: String
  let caption: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(
          theme.secondaryText)
        Spacer()
        Circle().fill(color).frame(width: 7, height: 7)
      }
      Text(value).font(.system(size: 21, weight: .semibold, design: .rounded))
      Text(caption).font(.system(size: 9)).foregroundStyle(theme.secondaryText)
    }
    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    .background(
      theme.panel,
      in: RoundedRectangle(cornerRadius: PrototypeDesignMetrics.floatingPanelRadius)
    )
    .overlay(
      RoundedRectangle(cornerRadius: PrototypeDesignMetrics.floatingPanelRadius)
        .stroke(theme.line))
  }
}

struct PropertyField: View {
  @Environment(\.prototypeTheme) private var theme
  let label: String
  let value: String
  var unit = ""

  var body: some View {
    HStack(spacing: 8) {
      Text(label).font(.system(size: 11.5)).foregroundStyle(theme.secondaryText)
      Spacer()
      Text(value).font(.system(size: 12, design: .monospaced))
      if !unit.isEmpty {
        Text(unit).font(.system(size: 10)).foregroundStyle(theme.tertiaryText)
      }
    }
    .padding(.horizontal, 8).frame(height: 29)
    .background(theme.raised, in: RoundedRectangle(cornerRadius: 6))
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.line))
  }
}

struct ChromeIconButtonStyle: ButtonStyle {
  @Environment(\.prototypeTheme) private var theme
  var active = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(active ? theme.accent : theme.iconText)
      .frame(
        width: CGFloat(WorkspaceHeaderMetrics.controlWidth),
        height: CGFloat(WorkspaceHeaderMetrics.controlHeight)
      )
      .background(
        active ? theme.accent.opacity(0.14) : theme.panel,
        in: RoundedRectangle(cornerRadius: 6)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(active ? theme.accent.opacity(0.40) : theme.line, lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.92 : 1)
      .brightness(configuration.isPressed ? 0.08 : 0)
      .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
  }
}
