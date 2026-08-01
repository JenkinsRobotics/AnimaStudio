import AnimaDocument
import AnimaModel
import RealityKitViewport
import SwiftUI

struct AssetBuilderInspector: View {
  let activeCharacter: ProjectCharacterReference?
  let selectedPart: AssetBuilderPartRow?
  let selectedPartIDs: Set<PartID>
  @Bindable var workspace: StudioWorkspaceModel
  let importProgress: CharacterImportProgress?
  let importErrorMessage: String?
  let importModels: () -> Void
  let dropModels: ([URL]) -> Void

  @State private var isDropTargeted = false
  @Environment(\.studioPanelSurfaceMode) private var panelSurfaceMode

  var body: some View {
    inspectorContent
      .frame(
        minHeight: panelSurfaceMode == .floating ? 620 : nil,
        maxHeight: panelSurfaceMode == .docked ? .infinity : 820
      )
  }

  private var inspectorContent: some View {
    VStack(spacing: 0) {
      // The import section is a header + one button (+ transient progress), so
      // keep it compact and give the reclaimed height to the 3D preview.
      importPanel
        .frame(minHeight: 150, idealHeight: 168)
      Divider()
      previewPanel
        .frame(minHeight: 340, maxHeight: .infinity)
    }
    .background(StudioPalette.panel)
  }

  private var importPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      panelHeader(
        title: "LOAD 3D ASSEMBLY",
        subtitle: activeCharacter.map { "Add models to \($0.displayName)" }
          ?? "Create a character first",
        systemImage: "square.and.arrow.down"
      )

      Button(action: importModels) {
        VStack(spacing: 9) {
          if let importProgress {
            ProgressView(value: importProgress.fractionCompleted)
              .progressViewStyle(.linear)
            Text("Loading \(importProgress.currentFilename)")
              .font(.callout.weight(.semibold))
              .lineLimit(1)
            Text("\(importProgress.completedFiles) of \(importProgress.totalFiles) complete")
              .font(.caption2)
              .foregroundStyle(.secondary)
          } else {
            Image(systemName: "square.and.arrow.down.on.square")
              .font(.title2)
              .foregroundStyle(StudioPalette.sourceModel)
            Text("Drop model files here")
              .font(.callout.weight(.semibold))
            Text("or click to choose files")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 105)
        .background(
          isDropTargeted ? StudioPalette.sourceModel.opacity(0.16) : StudioPalette.field,
          in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 10)
            .stroke(
              isDropTargeted ? StudioPalette.sourceModel : StudioPalette.border,
              style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [6, 4])
            )
        }
      }
      .buttonStyle(.plain)
      .disabled(activeCharacter == nil || importProgress != nil)
      .dropDestination(for: URL.self) { urls, _ in
        guard activeCharacter != nil, !urls.isEmpty else { return false }
        dropModels(urls)
        return true
      } isTargeted: {
        isDropTargeted = $0
      }

      HStack {
        Text(ModelImportFormatSupport.operatorLabel)
          .font(.caption2.weight(.bold))
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Label("Units prompted", systemImage: "ruler")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if let importErrorMessage {
        Label(importErrorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .lineLimit(3)
      }
    }
    .padding(14)
  }

  /// A STEP-backed character already has a live CAD 3D environment in the
  /// 3D Modeling workspace. Mounting a second RealityKit scene beside it
  /// duplicates rendering work and interfered with direct manipulation, so
  /// the preview stays off for CAD assemblies (operator decision 2026-07-31).
  private var characterIsSTEPBacked: Bool {
    workspace.enginePartModelSources.values.contains {
      ["step", "stp"].contains($0.fileURL.pathExtension.lowercased())
    }
  }

  private var previewPanel: some View {
    VStack(spacing: 0) {
      panelHeader(
        title: "PREVIEW",
        subtitle: previewSubtitle,
        systemImage: "viewfinder"
      )
      .padding(14)

      Divider()

      if characterIsSTEPBacked {
        ContentUnavailableView {
          Label("CAD assembly", systemImage: "cube.transparent")
        } description: {
          Text(
            "This character renders live in the 3D Modeling workspace. The RealityKit preview is disabled for CAD assemblies."
          )
        }
        .frame(minHeight: 220)
      } else {
        stagePreview
      }
    }
  }

  private var stagePreview: some View {
    ZStack(alignment: .bottomLeading) {
        RobotPreviewView(
          rig: workspace.project.rig,
          engineResolvedPartPoses: workspace.engineResolvedPartPoses,
          partModelSources: workspace.enginePartModelSources,
          showsGrid: workspace.showsPreviewGrid,
          viewpoint: previewViewpoint,
          cameraCommandRevision: previewCameraCommandRevision,
          cameraState: previewCameraState,
          focusedPartID: selectedPart?.id,
          highlightedPartIDs: selectedPartIDs,
          selectionCount: selectedPartIDs.count,
          partAppearances: previewAppearances,
          rigGuideVisibility: .hidden,
          appearance: .graphite,
          renderStyle: .shadedWithEdges,
          onSelectPartID: { id in workspace.selectPart(id: id, extendingSelection: false) }
        )

        if let selectedPart {
          HStack(spacing: 7) {
            Image(systemName: statusIcon(selectedPart.state))
            Text(selectedPart.name).lineLimit(1)
            Spacer(minLength: 4)
            Text(selectedPart.state.label)
              .foregroundStyle(.secondary)
          }
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 10)
          .frame(height: 30)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
          .padding(10)
        }
      }
  }

  private var previewSubtitle: String {
    if selectedPartIDs.count > 1 { return "\(selectedPartIDs.count) parts selected" }
    return selectedPart?.name ?? activeCharacter?.displayName ?? "Nothing selected"
  }

  private func panelHeader(title: String, subtitle: String, systemImage: String) -> some View {
    HStack(spacing: 9) {
      Image(systemName: systemImage)
        .foregroundStyle(StudioPalette.sourceModel)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.caption2.weight(.bold)).tracking(0.8)
        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer()
    }
  }

  private var previewAppearances: [PartID: PreviewPartAppearance] {
    Dictionary(
      uniqueKeysWithValues: workspace.project.rig.parts.compactMap { part in
        guard var appearance = workspace.componentAppearance(for: part.id) else { return nil }
        // Isolate the selection: when something is selected the preview shows
        // only those parts; with nothing selected it shows the whole character.
        appearance.isVisible = selectedPartIDs.isEmpty || selectedPartIDs.contains(part.id)
        return (part.id, appearance)
      }
    )
  }

  private var previewCameraState: PreviewCameraState {
    guard let selectedPart,
      let pose = workspace.engineResolvedPartPoses[selectedPart.id]
    else { return PreviewCameraState() }
    let position = pose.positionMeters
    return PreviewCameraState(
      target: PreviewCameraPoint(x: position.x, y: position.y, z: position.z),
      distance: 2.2,
      orthographicScale: 1.6
    )
  }

  /// Auto-zoom the preview to the selected part/assembly, or frame the whole
  /// character when nothing is selected. Both viewpoints fit the subject's
  /// bounding sphere (see RobotPreviewView), so any-scale parts fill the panel.
  private var previewViewpoint: PreviewCameraViewpoint {
    selectedPart == nil ? .home : .selection
  }

  /// Re-issues the framing command whenever the previewed subject changes; the
  /// command applies once per revision, so it must vary with the selection.
  private var previewCameraCommandRevision: Int {
    var hasher = Hasher()
    hasher.combine(selectedPart?.id)
    hasher.combine(selectedPartIDs.count)
    return hasher.finalize()
  }

  private func statusIcon(_ state: AssetBuilderPartState) -> String {
    switch state {
    case .ready: "checkmark.circle.fill"
    case .grounded: "pin.fill"
    case .suppressed: "eye.slash.fill"
    case .proxy: "cube"
    case .disconnected: "link.slash"
    }
  }
}
