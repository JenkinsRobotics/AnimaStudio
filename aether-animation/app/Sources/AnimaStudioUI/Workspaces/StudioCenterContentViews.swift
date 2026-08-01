import AnimaCoreClient
import AnimaDocument
import AnimaModel
import SwiftUI

/// Applies the shell's live content-safe rectangle without adding visual
/// chrome. Tables, galleries, timelines, and graphs use this; 3D does not.
struct StudioContentSafeCenter<Content: View>: View {
  @Environment(\.studioVisibleZoneInsets) private var insets
  @ViewBuilder let content: Content

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(insets.edgeInsets)
      .animation(.spring(response: 0.24, dampingFraction: 0.9), value: insets)
  }
}

struct StudioRigTableCenterView: View {
  let parts: [AnimaCorePartSummary]
  let mates: [AnimaCoreJointSummary]

  var body: some View {
    VStack(spacing: 0) {
      centerHeader(
        title: "Rig Table",
        detail: "\(parts.count) parts · \(mates.count) mates",
        systemImage: "list.bullet.rectangle"
      )
      rigColumnHeader
      if parts.isEmpty && mates.isEmpty {
        ContentUnavailableView(
          "No rig items yet",
          systemImage: "point.3.connected.trianglepath.dotted",
          description: Text("Import parts, then connect them with mates.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(parts, id: \.name) { part in
              HStack(spacing: 12) {
                Label(part.name, systemImage: "cube")
                  .frame(maxWidth: .infinity, alignment: .leading)
                Text(part.parent ?? "Character origin")
                  .frame(width: 170, alignment: .leading)
                Text(
                  part.model.isEmpty ? "Proxy" : URL(fileURLWithPath: part.model).lastPathComponent
                )
                .lineLimit(1)
                .frame(width: 190, alignment: .leading)
                stateLabel(
                  part.isSuppressed ? "Suppressed" : (part.isGrounded ? "Grounded" : "Active"),
                  systemImage: part.isSuppressed
                    ? "nosign" : (part.isGrounded ? "pin.fill" : "checkmark.circle.fill")
                )
                .frame(width: 105, alignment: .leading)
              }
              .padding(.horizontal, 14)
              .frame(height: 42)
              Divider().padding(.leading, 14)
            }
            ForEach(mates, id: \.selectionKey) { mate in
              HStack(spacing: 12) {
                Label(mate.name, systemImage: "link")
                  .frame(maxWidth: .infinity, alignment: .leading)
                Text([mate.parentPart, mate.childPart].compactMap { $0 }.joined(separator: " → "))
                  .lineLimit(1)
                  .frame(width: 170, alignment: .leading)
                Text(mate.type.capitalized)
                  .frame(width: 190, alignment: .leading)
                stateLabel(
                  mate.isSuppressed ? "Suppressed" : "\(mate.degreesOfFreedom.count) DOF",
                  systemImage: mate.isSuppressed ? "nosign" : "move.3d"
                )
                .frame(width: 105, alignment: .leading)
              }
              .padding(.horizontal, 14)
              .frame(height: 42)
              Divider().padding(.leading, 14)
            }
          }
        }
      }
    }
    .background(StudioPalette.panel)
  }

  private var rigColumnHeader: some View {
    HStack(spacing: 12) {
      Text("ITEM").frame(maxWidth: .infinity, alignment: .leading)
      Text("PARENT / CONNECTION").frame(width: 170, alignment: .leading)
      Text("SOURCE / TYPE").frame(width: 190, alignment: .leading)
      Text("STATE").frame(width: 105, alignment: .leading)
    }
    .font(.caption2.weight(.bold))
    .foregroundStyle(StudioPalette.muted)
    .padding(.horizontal, 14)
    .frame(height: 34)
    .background(StudioPalette.panelInset)
  }
}

struct StudioRigExplodedCenterView: View {
  let parts: [AnimaCorePartSummary]

  var body: some View {
    VStack(spacing: 0) {
      centerHeader(
        title: "Exploded Structure",
        detail: "Presentation-only spacing; character transforms are unchanged",
        systemImage: "square.3.layers.3d"
      )
      if parts.isEmpty {
        ContentUnavailableView(
          "No parts to explode",
          systemImage: "square.3.layers.3d",
          description: Text("Imported rigid parts will be arranged here.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView([.horizontal, .vertical]) {
          HStack(spacing: 38) {
            ForEach(Array(parts.enumerated()), id: \.element.name) { index, part in
              VStack(spacing: 10) {
                ZStack {
                  RoundedRectangle(cornerRadius: 14)
                    .fill(StudioPalette.panelInset)
                  Image(systemName: part.model.isEmpty ? "cube.transparent" : "cube.fill")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(part.isSuppressed ? StudioPalette.muted : StudioPalette.accent)
                }
                .frame(width: 116, height: 104)
                Text(part.name).font(.callout.weight(.semibold)).lineLimit(1)
                Text(part.parent.map { "Parent: \($0)" } ?? "Character origin")
                  .font(.caption2)
                  .foregroundStyle(StudioPalette.muted)
              }
              .offset(y: CGFloat((index % 3) - 1) * 34)
              if index < parts.count - 1 {
                Image(systemName: "arrow.right")
                  .foregroundStyle(StudioPalette.muted)
              }
            }
          }
          .padding(48)
          .frame(minWidth: 700, minHeight: 360)
        }
      }
    }
    .background(StudioPalette.canvas)
  }
}

struct StudioShowTableCenterView: View {
  let scenes: [ProjectSceneReference]
  let clips: [AnimaModel.AnimationClip]

  var body: some View {
    VStack(spacing: 0) {
      centerHeader(
        title: "Show Documents",
        detail: "Scenes and character animation clips",
        systemImage: "list.bullet.rectangle"
      )
      HStack(spacing: 12) {
        Text("NAME").frame(maxWidth: .infinity, alignment: .leading)
        Text("KIND").frame(width: 130, alignment: .leading)
        Text("FILE / DURATION").frame(width: 220, alignment: .leading)
        Text("STATE").frame(width: 100, alignment: .leading)
      }
      .font(.caption2.weight(.bold))
      .foregroundStyle(StudioPalette.muted)
      .padding(.horizontal, 14)
      .frame(height: 34)
      .background(StudioPalette.panelInset)

      if scenes.isEmpty && clips.isEmpty {
        ContentUnavailableView(
          "No show documents yet",
          systemImage: "sparkles.rectangle.stack",
          description: Text("Scenes and animation clips will appear in this table.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(scenes) { scene in
              showRow(
                name: scene.displayName,
                kind: "Scene",
                detail: scene.filename,
                state: "Saved",
                systemImage: "sparkles.rectangle.stack"
              )
            }
            ForEach(clips, id: \.name) { clip in
              showRow(
                name: clip.name,
                kind: "Animation",
                detail:
                  "\(clip.durationSeconds.formatted(.number.precision(.fractionLength(2)))) s",
                state: "Character",
                systemImage: "waveform.path.ecg"
              )
            }
          }
        }
      }
    }
    .background(StudioPalette.panel)
  }

  private func showRow(
    name: String,
    kind: String,
    detail: String,
    state: String,
    systemImage: String
  ) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Label(name, systemImage: systemImage).frame(maxWidth: .infinity, alignment: .leading)
        Text(kind).frame(width: 130, alignment: .leading)
        Text(detail).lineLimit(1).frame(width: 220, alignment: .leading)
        Text(state).frame(width: 100, alignment: .leading)
      }
      .font(.callout)
      .padding(.horizontal, 14)
      .frame(height: 42)
      Divider().padding(.leading, 14)
    }
  }
}

struct StudioServoTimelineCenterView: View {
  @Bindable var workspace: StudioWorkspaceModel

  private var degreesOfFreedom: [(mate: AnimaCoreJointSummary, dof: AnimaCoreDOFSummary)] {
    workspace.engineMates.flatMap { mate in
      mate.degreesOfFreedom.map { (mate, $0) }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      centerHeader(
        title: "Servo Timeline",
        detail: "Engine DOF preview · physical output remains offline",
        systemImage: "slider.horizontal.3"
      )
      if degreesOfFreedom.isEmpty {
        ContentUnavailableView(
          "No drivable channels yet",
          systemImage: "slider.horizontal.3",
          description: Text("Add a mate with a degree of freedom to create a servo track.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(degreesOfFreedom, id: \.dof.path) { entry in
              servoRow(mate: entry.mate, dof: entry.dof)
              Divider().padding(.leading, 190)
            }
          }
        }
      }
    }
    .background(StudioPalette.panel)
  }

  private func servoRow(mate: AnimaCoreJointSummary, dof: AnimaCoreDOFSummary) -> some View {
    let value =
      workspace.evaluatedFrame.jointAnglesRadians[
        AnimaModel.JointID(rawValue: dof.path)
      ] ?? dof.neutral
    let minimum = dof.minimum ?? (dof.kind == .rotation ? -.pi : -0.1)
    let maximum = max(dof.maximum ?? (dof.kind == .rotation ? .pi : 0.1), minimum + 0.000_001)
    let fraction = min(max((value - minimum) / (maximum - minimum), 0), 1)

    return HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(mate.name).font(.callout.weight(.semibold))
        Text(dof.path).font(.caption2).foregroundStyle(StudioPalette.muted).lineLimit(1)
      }
      .frame(width: 176, alignment: .leading)

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(StudioPalette.panelInset).frame(height: 8)
          Capsule().fill(StudioPalette.accent).frame(
            width: geometry.size.width * fraction, height: 8)
          Circle().fill(.white).frame(width: 14, height: 14)
            .offset(x: max(0, geometry.size.width * fraction - 7))
        }
        .frame(maxHeight: .infinity)
      }
      .frame(height: 22)

      Text(displayValue(value, dof: dof))
        .font(.caption.monospacedDigit())
        .frame(width: 84, alignment: .trailing)
      Text("OFFLINE")
        .font(.caption2.weight(.bold))
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 62)
    }
    .padding(.horizontal, 14)
    .frame(height: 52)
  }

  private func displayValue(_ value: Double, dof: AnimaCoreDOFSummary) -> String {
    switch dof.unit {
    case .radians: "\((value * 180 / .pi).formatted(.number.precision(.fractionLength(1))))°"
    case .meters: "\((value * 1_000).formatted(.number.precision(.fractionLength(1)))) mm"
    }
  }
}

private func centerHeader(title: String, detail: String, systemImage: String) -> some View {
  HStack(spacing: 10) {
    Label(title, systemImage: systemImage)
      .font(.headline)
    Text(detail)
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
    Spacer()
  }
  .padding(.horizontal, 14)
  .frame(height: 46)
  .background(StudioPalette.chrome)
}

private func stateLabel(_ title: String, systemImage: String) -> some View {
  Label(title, systemImage: systemImage)
    .font(.caption)
    .foregroundStyle(StudioPalette.muted)
}
