import AppKit
import SwiftUI

struct RecentProjectCard: View {
  let project: RecentProjectSummary
  var canOpen: Bool { project.canOpen }
  var open: () -> Void = {}
  var remove: (() -> Void)?

  @State private var isHovering = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Group {
        if canOpen {
          Button(action: open) {
            cardContent
          }
          .buttonStyle(.plain)
          .accessibilityLabel(project.displayName)
          .accessibilityValue(accessibilityValue)
        } else {
          cardContent
            .accessibilityElement(children: .combine)
            .accessibilityLabel(project.displayName)
            .accessibilityValue(accessibilityValue)
        }
      }

      if isHovering, let remove {
        removeButton(action: remove)
          .padding(7)
          .transition(.opacity.combined(with: .scale(scale: 0.85)))
      }
    }
    .onHover { isHovering = $0 }
    .animation(.easeOut(duration: 0.12), value: isHovering)
    .contextMenu {
      if let remove {
        Button("Remove from Recents", systemImage: "clock.badge.xmark", role: .destructive) {
          remove()
        }
      }
    }
    .help(
      canOpen
        ? "Open \(project.displayName)"
        : "The project folder must be located again before it can be reopened."
    )
  }

  private func removeButton(action: @escaping () -> Void) -> some View {
    Button(role: .destructive, action: action) {
      Image(systemName: "xmark")
        .font(.caption.weight(.bold))
        .frame(width: 22, height: 22)
        .background(.regularMaterial, in: Circle())
        .overlay {
          Circle().stroke(StudioPalette.border, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .help("Remove \(project.displayName) from Recents")
    .accessibilityLabel("Remove \(project.displayName) from Recents")
  }

  private var cardContent: some View {
    HStack(spacing: 12) {
      RecentProjectThumbnail(project: project)
        .frame(width: 66, height: 66)

      VStack(alignment: .leading, spacing: 5) {
        Text(project.displayName)
          .font(.headline)
          .foregroundStyle(.primary)
          .lineLimit(1)

        Label(formattedLastOpened, systemImage: "clock")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
          .lineLimit(1)

        if let milestoneName = project.milestoneName {
          Text(milestoneName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(StudioPalette.accent)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 8)

      VStack(alignment: .trailing, spacing: 8) {
        Spacer()
        Text(project.revisionLabel)
          .font(.caption2.monospaced().weight(.bold))
          .foregroundStyle(StudioPalette.accent)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(StudioPalette.accent.opacity(0.12), in: Capsule())
          .overlay {
            Capsule().stroke(StudioPalette.accent.opacity(0.32), lineWidth: 1)
          }
      }
    }
    .padding(10)
    .background(
      isHovering ? StudioPalette.panelInset : StudioPalette.panel,
      in: RoundedRectangle(cornerRadius: 12)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          isHovering ? StudioPalette.accent.opacity(0.55) : StudioPalette.border,
          lineWidth: 1
        )
    }
    .contentShape(RoundedRectangle(cornerRadius: 12))
  }

  private var formattedLastOpened: String {
    project.lastOpenedAt.formatted(
      .dateTime
        .month(.abbreviated)
        .day()
        .year()
        .hour()
        .minute()
    )
  }

  private var accessibilityValue: String {
    "Last opened \(formattedLastOpened), revision \(project.revisionNumber)"
  }
}

private struct RecentProjectThumbnail: View {
  let project: RecentProjectSummary

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 9)
        .fill(
          LinearGradient(
            colors: [StudioPalette.canvas, StudioPalette.panel],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      if let image = cachedImage {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .padding(4)
      } else {
        Image(systemName: project.thumbnailKind.systemImage)
          .font(.system(size: 31, weight: .light))
          .foregroundStyle(StudioPalette.semanticPart)
          .rotation3DEffect(.degrees(-12), axis: (x: 1, y: 0, z: 0))
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 9)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .clipped()
  }

  private var cachedImage: NSImage? {
    guard let thumbnailPath = project.thumbnailPath else { return nil }
    return NSImage(contentsOfFile: thumbnailPath)
  }
}
