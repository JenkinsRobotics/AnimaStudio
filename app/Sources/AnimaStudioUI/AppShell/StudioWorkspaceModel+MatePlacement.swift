import AnimaCADViewport
import AnimaCoreClient
import AnimaModel
import Foundation
import RealityKitViewport
import simd

/// The mate-placement session: tool arming, two connector picks, the
/// live AnimaCore preview snap, refinement options, and the canonical
/// add_mate commit.
/// Behavior-preserving extraction from StudioWorkspaceModel (2026-07-31).
extension StudioWorkspaceModel {

  func canCreateMate(_ kind: MateCreationToolKind) -> Bool {
    guard kind.supportsTwoConnectorAuthoring, canCreateRevoluteJoint else { return false }
    if animaCoreHandle != nil {
      return engineMateTypes.contains { $0.type == kind.engineTypeID }
    }
    return kind.hasLocalDraftAuthoringAction
  }

  func beginMatePlacement(_ kind: MateCreationToolKind) {
    guard canCreateMate(kind) else { return }
    if matePlacement != nil {
      restoreCommittedPoseAfterMatePreview()
    }
    let connectedChildren = connectedMateChildPartIDs
    let preferredPartID = selectedPartID.flatMap { partID in
      !connectedChildren.contains(partID) && !isComponentLocked(partID) ? partID : nil
    }
    storedSelectedFeature = nil
    matePreviewRequestRevision += 1
    matePreviewBaselinePartPoses = engineResolvedPartPoses
    matePlacement = MatePlacementSession(kind: kind, preferredPartID: preferredPartID)
    isPlaying = false
    showsCreationPalette = false
  }

  func beginRevoluteMatePlacement() {
    beginMatePlacement(.revolute)
  }

  func cancelMatePlacement() {
    restoreCommittedPoseAfterMatePreview()
    matePreviewBaselinePartPoses = nil
    matePlacement = nil
  }

  /// Handles feature-pick events from the standing viewport interaction.
  /// During mate placement, feature picks forward to the placement flow
  /// unchanged and empty clicks are ignored, so placement keeps its
  /// existing two-click semantics. Feature selection is allowed on locked
  /// components: locks guard edits, and inspecting a feature edits nothing.
  func selectMateConnector(_ event: ViewportPickEvent) {
    switch event {
    case .feature(let candidate):
      if matePlacement != nil {
        selectMateConnector(candidate)
        return
      }
      guard project.rig.parts.contains(where: { $0.id == candidate.partID }) else { return }
      storedSelectedFeature = candidate
      selection = [.part(candidate.partID)]
    case .clearFeature:
      storedSelectedFeature = nil
    case .clearAll:
      guard matePlacement == nil else { return }
      clearSelection()
    }
  }

  func selectMateConnector(_ candidate: MateConnectorCandidate) {
    guard var placement = matePlacement,
      !isComponentLocked(candidate.partID)
    else { return }

    if placement.sourceCandidate == nil {
      guard mateCandidatePartIDs.contains(candidate.partID) else { return }
      placement.sourceCandidate = candidate
      matePlacement = placement
      selection = [.part(candidate.partID)]
      return
    }

    guard let source = placement.sourceCandidate,
      source.partID != candidate.partID,
      mateCandidatePartIDs.contains(candidate.partID)
    else { return }

    placement.targetCandidate = candidate
    placement.previewErrorMessage = nil
    matePlacement = placement
    selection = [.part(source.partID), .part(candidate.partID)]
    requestMatePlacementPreview()
  }

  func updateMatePlacementOptions(_ options: EngineMatePlacementOptions) {
    guard var placement = matePlacement, !placement.isSubmitting else { return }
    placement.options = options
    placement.previewErrorMessage = nil
    matePlacement = placement
    requestMatePlacementPreview()
  }

  func restoreCommittedPoseAfterMatePreview() {
    matePreviewRequestRevision += 1
    if let matePreviewBaselinePartPoses {
      engineResolvedPartPoses = matePreviewBaselinePartPoses
    }
  }

  /// Requests a canonical, non-mutating AnimaCore solve for the two selected
  /// connector frames. Rapid option edits may queue actor calls, but revision
  /// gating ensures only the newest result can reach the viewport.
  func requestMatePlacementPreview() {
    guard animaCoreClient != nil, animaCoreHandle != nil,
      var placement = matePlacement,
      placement.sourceCandidate != nil,
      placement.targetCandidate != nil,
      !placement.isSubmitting
    else { return }
    placement.isPreviewing = true
    placement.previewErrorMessage = nil
    matePlacement = placement
    matePreviewRequestRevision += 1
    let revision = matePreviewRequestRevision
    Task {
      await previewEngineMate(placement, revision: revision)
    }
  }

  /// Maps a renderer topology pick onto the canonical engine Part projection.
  /// Exact geometry inference remains renderer-side; the resulting frame is
  /// sent unchanged to AnimaCore when the operator confirms the mate.
  func selectCADMateFeature(
    _ feature: CADViewportFeaturePick,
    sourceURL: URL?
  ) {
    guard matePlacement != nil else { return }
    let standardizedSource = sourceURL?.standardizedFileURL
    let sourceMatches = enginePartModelSources.filter { _, source in
      standardizedSource == nil || source.fileURL.standardizedFileURL == standardizedSource
    }
    // TEMP mate-mapping diagnostics (remove after the regression is fixed).
    StudioDiagLog.append(
      "MATE-DIAG pick partID=\(feature.partID) node=\(feature.nodeName) "
        + "sourceURL=\(standardizedSource?.path ?? "nil") "
        + "engineSources=\(enginePartModelSources.count) matches=\(sourceMatches.count) "
        + "selected=\(selectedPartID.map(String.init(describing:)) ?? "nil")")
    for (partID, source) in enginePartModelSources.prefix(3) {
      StudioDiagLog.append(
        "MATE-DIAG engine part=\(partID) url=\(source.fileURL.standardizedFileURL.path)")
    }
    let exactNodeMatches = sourceMatches.filter { _, source in
      guard let modelNode = source.modelNode else { return false }
      return modelNode == feature.nodeName
        || modelNode.split(separator: "/").last.map(String.init) == feature.nodeName
    }
    let resolvedPartID: PartID? = {
      if exactNodeMatches.count == 1 { return exactNodeMatches.first?.key }
      // The operator's tree selection disambiguates parts that share one
      // source file (instanced geometry) before the single-match shortcut.
      if let selectedPartID, sourceMatches[selectedPartID] != nil { return selectedPartID }
      if sourceMatches.count == 1 { return sourceMatches.first?.key }
      return nil
    }()
    guard let partID = resolvedPartID else {
      animaCoreErrorMessage =
        "That CAD feature could not be mapped to one character Part. Select the Part in the tree, then pick the feature again."
      return
    }
    let kind: MateConnectorFeatureKind =
      switch feature.kind {
      case .face: .faceCenter
      case .edge: .edgeMidpoint
      case .vertex: .corner
      case .axis: .axis
      }
    let label: String =
      switch feature.kind {
      case .face: "Face center"
      case .edge: "Edge midpoint"
      case .vertex: "Vertex"
      case .axis: "Cylindrical axis"
      }
    selectMateConnector(
      MateConnectorCandidate(
        id: "cad-\(feature.kind.rawValue)-\(feature.topologyID)",
        partID: partID,
        displayName: "\(feature.nodeName) · \(label)",
        featureKind: kind,
        connector: MateConnectorDefinition(
          originMeters: RigVector3(
            x: feature.positionMeters.x,
            y: feature.positionMeters.y,
            z: feature.positionMeters.z
          ),
          primaryAxis: RigVector3(
            x: feature.primaryAxis.x,
            y: feature.primaryAxis.y,
            z: feature.primaryAxis.z
          ),
          secondaryAxis: RigVector3(
            x: feature.secondaryAxis.x,
            y: feature.secondaryAxis.y,
            z: feature.secondaryAxis.z
          )
        )
      )
    )
  }

  func previewEngineMate(
    _ placement: MatePlacementSession,
    revision: Int
  ) async {
    guard let source = placement.sourceCandidate,
      let target = placement.targetCandidate
    else { return }
    guard let animaCoreClient, let handle = animaCoreHandle else {
      guard revision == matePreviewRequestRevision,
        var current = matePlacement
      else { return }
      current.isPreviewing = false
      matePlacement = current
      return
    }
    guard
      let movingPartName = enginePartName(for: source.partID),
      let fixedPartName = enginePartName(for: target.partID)
    else {
      finishMatePreview(
        revision: revision,
        errorMessage: EngineMateAuthoringError.missingPartMapping.localizedDescription
      )
      return
    }
    guard
      let type = engineMateTypes.first(where: {
        $0.type == placement.kind.engineTypeID
      })
    else {
      finishMatePreview(
        revision: revision,
        errorMessage: EngineMateAuthoringError.typeUnavailable(
          placement.kind.title
        ).localizedDescription
      )
      return
    }

    do {
      let draft = try EngineMateAuthoring.makeDraft(
        kind: placement.kind,
        type: type,
        movingPartName: movingPartName,
        movingConnector: source,
        fixedPartName: fixedPartName,
        fixedConnector: target,
        existingMateNames: Set(engineMates.map(\.name)),
        options: placement.options
      )
      let pose = try await animaCoreClient.previewMate(
        handle: handle,
        joint: draft.document,
        clip: engineClipName,
        timeSeconds: playheadSeconds
      )
      guard revision == matePreviewRequestRevision,
        handle == animaCoreHandle,
        var current = matePlacement
      else { return }
      engineResolvedPartPoses = Self.previewPoses(
        from: pose,
        partIDsByEngineName: enginePartIDsByName
      )
      current.isPreviewing = false
      current.previewErrorMessage = nil
      matePlacement = current
    } catch is CancellationError {
      return
    } catch {
      finishMatePreview(
        revision: revision,
        errorMessage: error.localizedDescription
      )
    }
  }

  func finishMatePreview(
    revision: Int,
    errorMessage: String
  ) {
    guard revision == matePreviewRequestRevision,
      var current = matePlacement
    else { return }
    if let matePreviewBaselinePartPoses {
      engineResolvedPartPoses = matePreviewBaselinePartPoses
    }
    current.isPreviewing = false
    current.previewErrorMessage = errorMessage
    matePlacement = current
  }

  func authorEngineMate(
    kind: MateCreationToolKind,
    movingConnector: MateConnectorCandidate,
    fixedConnector: MateConnectorCandidate,
    options: EngineMatePlacementOptions = .init()
  ) async {
    guard let animaCoreClient, let handle = animaCoreHandle,
      let movingPartName = enginePartName(for: movingConnector.partID),
      let fixedPartName = enginePartName(for: fixedConnector.partID)
    else {
      animaCoreErrorMessage = EngineMateAuthoringError.missingPartMapping.localizedDescription
      if var placement = matePlacement {
        placement.isSubmitting = false
        matePlacement = placement
      }
      return
    }
    guard let type = engineMateTypes.first(where: { $0.type == kind.engineTypeID }) else {
      animaCoreErrorMessage =
        EngineMateAuthoringError.typeUnavailable(kind.title).localizedDescription
      if var placement = matePlacement {
        placement.isSubmitting = false
        matePlacement = placement
      }
      return
    }

    do {
      let draft = try EngineMateAuthoring.makeDraft(
        kind: kind,
        type: type,
        movingPartName: movingPartName,
        movingConnector: movingConnector,
        fixedPartName: fixedPartName,
        fixedConnector: fixedConnector,
        existingMateNames: Set(engineMates.map(\.name)),
        options: options
      )
      let mutated = try await animaCoreClient.addMate(
        handle: handle,
        joint: draft.document
      )
      guard handle == animaCoreHandle, mutated.handle == handle else { return }

      engineRigDocument = mutated.rigDocument
      engineRigIdentity = mutated.rig.identity
      engineParts = mutated.rig.parts
      engineMates = mutated.rig.joints
      engineRelations = mutated.rig.relations
      engineParameters = mutated.rig.parameters
      engineOutputs = mutated.rig.outputs
      engineKinematicChain = mutated.rig.kinematicChain
      matePreviewBaselinePartPoses = nil
      matePlacement = nil
      if let mate = engineMates.first(where: { $0.name == draft.name }) {
        selection = [.joint(JointID(rawValue: mate.selectionKey))]
      }
      documentEditRevision += 1
      animaCoreErrorMessage = nil
      await refreshAnimaCoreFrameAtPlayhead()
    } catch {
      if var placement = matePlacement {
        placement.isSubmitting = false
        matePlacement = placement
      }
      animaCoreErrorMessage = error.localizedDescription
    }
  }
}
