import AnimaModel
import AppKit
import Foundation
import RealityKit
import SwiftUI
import os

public struct RobotPreviewView: View {
  /// A part WITH a model source that fails to load is a real error, not a
  /// reason to silently show proxy geometry. Log the specific failure so a
  /// bad import is diagnosable instead of being disguised as an intended box.
  private static let modelLoadLog = Logger(
    subsystem: "studio.anima.AnimaStudio", category: "ModelLoad")

  @State private var transformDragState: TransformDragState?
  @State private var armIKDragState: ArmIKDragState?
  @State private var navigationAction: CADNavigationAction?
  @State private var navigationCommandRevision = 0
  /// Standing sub-object selection shown in the viewport. The workspace
  /// model mirrors it through `onSelectMateCandidate` events and remains
  /// authoritative for the inspector; this local copy drives mesh-feature
  /// overlays without exposing mate snap-point markers outside placement.
  @State private var standingFeature: MateConnectorCandidate?
  @State private var hoveredFeature: MateConnectorCandidate?
  @State private var pointerTarget = ViewportPointerTarget.canvas
  @State private var entityTapRevision = 0
  @State private var lastSelectionPoint: CGPoint?
  @State private var boxSelectionState: BoxSelectionState?
  @State private var sectionDragStartPositionMeters: Double?

  private let rig: CharacterRig
  private let engineResolvedPartPoses: [PartID: EngineResolvedPartPose]
  private let partModelSources: [PartID: PartModelSource]
  private let modelURL: URL?
  private let showsGrid: Bool
  private let projection: PreviewCameraProjection
  private let viewpoint: PreviewCameraViewpoint
  private let cameraCommandRevision: Int
  private let cameraState: PreviewCameraState
  private let navigationProfile: PreviewNavigationProfile
  private let customNavigationMapping: CustomNavigationMapping
  private let navigationSensitivity: PreviewNavigationSensitivity
  private let reversesWheelZoom: Bool
  private let focusedModelPath: ModelEntityPath?
  private let focusedPartID: PartID?
  private let highlightedPartIDs: Set<PartID>
  private let selectionCount: Int
  private let partAppearances: [PartID: PreviewPartAppearance]
  private let focusedPartIsLocked: Bool
  private let mateCandidatePartIDs: Set<PartID>
  private let selectedMateCandidate: MateConnectorCandidate?
  private let armIKTargetPose: EngineResolvedPartPose?
  private let armIKTargetIsUnreachable: Bool
  private let importedHierarchyRootPath: ModelEntityPath?
  private let onSelectModelPath: (ModelEntityPath) -> Void
  private let onSelectPartID: (PartID) -> Void
  private let onSetPartPosition: (PartID, RigVector3) -> Void
  private let onSetPartRotation: (PartID, RigVector3) -> Void
  private let onSetArmIKTargetPose: (EngineResolvedPartPose) -> Void
  private let onSetSectionPosition: (Double) -> Void
  private let onSelectMateCandidate: (ViewportPickEvent) -> Void
  private let rigGuideVisibility: RigGuideVisibility
  private let appearance: PreviewAppearance
  private let renderStyle: ViewportRenderStyle
  private let edgeDisplay: ViewportEdgeDisplay
  private let lightingPreset: ViewportLightingPreset
  private let materialFinish: ViewportMaterialFinish
  private let reflectionMode: ViewportReflectionMode
  private let lightingIntensity: Float
  private let environmentPreset: ViewportEnvironmentPreset
  private let environmentRotationDegrees: Float
  private let renderQuality: ViewportRenderQuality
  private let backgroundSettings: ViewportBackgroundSettings
  private let sectionPlane: ViewportSectionPlane
  private let showsShadows: Bool
  private let fieldOfViewDegrees: Float
  private let onCameraStateChange: (PreviewCameraState) -> Void
  private let onPointerTargetChange: (ViewportPointerTarget) -> Void
  private let onContextMenuRequest: (CGPoint, ViewportPointerTarget) -> Void
  private let onFrameAll: () -> Void
  private let onBoxSelectPartIDs: (Set<PartID>) -> Void

  public init(
    rig: CharacterRig = CharacterRig(joints: []),
    engineResolvedPartPoses: [PartID: EngineResolvedPartPose] = [:],
    partModelSources: [PartID: PartModelSource] = [:],
    modelURL: URL? = nil,
    showsGrid: Bool = true,
    projection: PreviewCameraProjection = .perspective,
    viewpoint: PreviewCameraViewpoint = .home,
    cameraCommandRevision: Int = 0,
    cameraState: PreviewCameraState = PreviewCameraState(),
    navigationProfile: PreviewNavigationProfile = .default,
    customNavigationMapping: CustomNavigationMapping = CustomNavigationMapping(),
    navigationSensitivity: PreviewNavigationSensitivity = PreviewNavigationSensitivity(),
    reversesWheelZoom: Bool = false,
    focusedModelPath: ModelEntityPath? = nil,
    focusedPartID: PartID? = nil,
    highlightedPartIDs: Set<PartID> = [],
    selectionCount: Int = 0,
    partAppearances: [PartID: PreviewPartAppearance] = [:],
    focusedPartIsLocked: Bool = false,
    mateCandidatePartIDs: Set<PartID> = [],
    selectedMateCandidate: MateConnectorCandidate? = nil,
    armIKTargetPose: EngineResolvedPartPose? = nil,
    armIKTargetIsUnreachable: Bool = false,
    importedHierarchyRootPath: ModelEntityPath? = nil,
    rigGuideVisibility: RigGuideVisibility = .hidden,
    appearance: PreviewAppearance = .midnight,
    renderStyle: ViewportRenderStyle = .shaded,
    edgeDisplay: ViewportEdgeDisplay = .mesh,
    lightingPreset: ViewportLightingPreset = .balanced,
    materialFinish: ViewportMaterialFinish = .satin,
    reflectionMode: ViewportReflectionMode = .subtle,
    lightingIntensity: Float = 1,
    environmentPreset: ViewportEnvironmentPreset = .softbox,
    environmentRotationDegrees: Float = 0,
    renderQuality: ViewportRenderQuality = .standard,
    backgroundSettings: ViewportBackgroundSettings = ViewportBackgroundSettings(),
    sectionPlane: ViewportSectionPlane = ViewportSectionPlane(),
    showsShadows: Bool = true,
    fieldOfViewDegrees: Float = 60,
    onSelectModelPath: @escaping (ModelEntityPath) -> Void = { _ in },
    onSelectPartID: @escaping (PartID) -> Void = { _ in },
    onSetPartPosition: @escaping (PartID, RigVector3) -> Void = { _, _ in },
    onSetPartRotation: @escaping (PartID, RigVector3) -> Void = { _, _ in },
    onSetArmIKTargetPose: @escaping (EngineResolvedPartPose) -> Void = { _ in },
    onSetSectionPosition: @escaping (Double) -> Void = { _ in },
    onSelectMateCandidate: @escaping (ViewportPickEvent) -> Void = { _ in },
    onCameraStateChange: @escaping (PreviewCameraState) -> Void = { _ in },
    onPointerTargetChange: @escaping (ViewportPointerTarget) -> Void = { _ in },
    onContextMenuRequest: @escaping (CGPoint, ViewportPointerTarget) -> Void = { _, _ in },
    onFrameAll: @escaping () -> Void = {},
    onBoxSelectPartIDs: @escaping (Set<PartID>) -> Void = { _ in }
  ) {
    self.rig = rig
    self.engineResolvedPartPoses = engineResolvedPartPoses
    self.partModelSources = partModelSources
    self.modelURL = modelURL
    self.showsGrid = showsGrid
    self.projection = projection
    self.viewpoint = viewpoint
    self.cameraCommandRevision = cameraCommandRevision
    self.cameraState = cameraState
    self.navigationProfile = navigationProfile
    self.customNavigationMapping = customNavigationMapping
    self.navigationSensitivity = navigationSensitivity
    self.reversesWheelZoom = reversesWheelZoom
    self.focusedModelPath = focusedModelPath
    self.focusedPartID = focusedPartID
    self.highlightedPartIDs = highlightedPartIDs
    self.selectionCount = selectionCount
    self.partAppearances = partAppearances
    self.focusedPartIsLocked = focusedPartIsLocked
    self.mateCandidatePartIDs = mateCandidatePartIDs
    self.selectedMateCandidate = selectedMateCandidate
    self.armIKTargetPose = armIKTargetPose
    self.armIKTargetIsUnreachable = armIKTargetIsUnreachable
    self.importedHierarchyRootPath = importedHierarchyRootPath
    self.rigGuideVisibility = rigGuideVisibility
    self.appearance = appearance
    self.renderStyle = renderStyle
    self.edgeDisplay = edgeDisplay
    self.lightingPreset = lightingPreset
    self.materialFinish = materialFinish
    self.reflectionMode = reflectionMode
    self.lightingIntensity = min(max(lightingIntensity, 0.1), 3)
    self.environmentPreset = environmentPreset
    self.environmentRotationDegrees = environmentRotationDegrees
    self.renderQuality = renderQuality
    self.backgroundSettings = backgroundSettings
    self.sectionPlane = sectionPlane
    self.showsShadows = showsShadows
    self.fieldOfViewDegrees = min(max(fieldOfViewDegrees, 20), 120)
    self.onSelectModelPath = onSelectModelPath
    self.onSelectPartID = onSelectPartID
    self.onSetPartPosition = onSetPartPosition
    self.onSetPartRotation = onSetPartRotation
    self.onSetArmIKTargetPose = onSetArmIKTargetPose
    self.onSetSectionPosition = onSetSectionPosition
    self.onSelectMateCandidate = onSelectMateCandidate
    self.onCameraStateChange = onCameraStateChange
    self.onPointerTargetChange = onPointerTargetChange
    self.onContextMenuRequest = onContextMenuRequest
    self.onFrameAll = onFrameAll
    self.onBoxSelectPartIDs = onBoxSelectPartIDs
  }

  public var body: some View {
    RealityView { content in
      let root = await Self.makeScene(
        rig: rig,
        appearance: appearance,
        renderStyle: renderStyle,
        edgeDisplay: edgeDisplay,
        lightingPreset: lightingPreset,
        materialFinish: materialFinish,
        partAppearances: partAppearances,
        partModelSources: partModelSources,
        reflectionMode: reflectionMode,
        lightingIntensity: lightingIntensity,
        environmentPreset: environmentPreset,
        environmentRotationDegrees: environmentRotationDegrees,
        sectionPlane: sectionPlane,
        showsShadows: showsShadows
      )
      content.renderingEffects.antialiasing =
        renderQuality == .high ? .multisample4X : .none
      content.add(root)
      content.cameraTarget = root.findEntity(named: "previewCameraTarget")

      if partModelSources.isEmpty, let modelURL,
        let importedModel = try? await Entity(contentsOf: modelURL)
      {
        importedModel.name = "importedModel"
        Self.normalizeForPreview(importedModel)
        Self.prepareForSelection(importedModel)
        ViewportRenderStyleApplier.apply(
          renderStyle,
          edgeDisplay: edgeDisplay,
          to: importedModel
        )
        let environmentLight = root.findEntity(
          named: ViewportLightingFactory.environmentLightName
        )
        ViewportLightingFactory.applyEnvironmentReceiver(
          light: environmentLight,
          to: importedModel
        )
        Self.applyShadowParticipation(showsShadows, to: importedModel)
        root.addChild(importedModel)
      }
    } update: { content in
      guard let root = content.entities.first else {
        return
      }
      content.renderingEffects.antialiasing =
        renderQuality == .high ? .multisample4X : .none

      root.findEntity(named: "previewGrid")?.isEnabled = showsGrid
      RigGuideFactory.apply(rigGuideVisibility, to: root)
      Self.applyProjectionIfNeeded(projection, cameraState: cameraState, to: root)
      Self.applyFieldOfViewIfNeeded(fieldOfViewDegrees, to: root)
      if let updatedCameraState = Self.applyCameraCommandIfNeeded(
        revision: cameraCommandRevision,
        viewpoint: viewpoint,
        cameraState: cameraState,
        focusedModelPath: focusedModelPath,
        focusedPartID: focusedPartID,
        to: root
      ) {
        reportCameraState(updatedCameraState)
      }
      Self.applyRig(rig, engineResolvedPartPoses: engineResolvedPartPoses, to: root)
      ArmIKTargetFactory.apply(
        pose: armIKTargetPose,
        isUnreachable: armIKTargetIsUnreachable,
        to: root
      )
      Self.applyPartAppearances(
        partAppearances,
        rig: rig,
        renderStyle: renderStyle,
        to: root
      )
      if let characterRoot = root.findEntity(named: "animaCharacterRoot") {
        ViewportSectionFactory.refreshClippingMaterials(sectionPlane, below: characterRoot)
      }
      if isPlacementActive {
        let primitiveCandidatePartIDs = mateCandidatePartIDs.subtracting(partModelSources.keys)
        MateConnectorMarkerFactory.apply(
          rig: rig,
          visiblePartIDs: primitiveCandidatePartIDs,
          selectedCandidate: selectedMateCandidate,
          style: .placement,
          to: root
        )
      } else {
        MateConnectorMarkerFactory.remove(from: root)
      }
      MeshFeatureOverlayFactory.applyInteraction(
        hovered: hoveredFeature,
        selected: isPlacementActive ? selectedMateCandidate : standingFeature,
        pickScale: Self.meshFeaturePickScale(
          projection: projection,
          cameraState: cameraState
        ),
        to: root
      )
      Self.applySelection(
        focusedPartID,
        highlightedPartIDs: highlightedPartIDs,
        isLocked: focusedPartIsLocked,
        allowsTransformGizmo: !isPlacementActive,
        rig: rig,
        to: root
      )
      if let navigationAction {
        if let updatedCameraState = Self.applyNavigation(
          navigationAction,
          revision: navigationCommandRevision,
          cameraState: cameraState,
          to: root
        ) {
          reportCameraState(updatedCameraState)
          consumeNavigationAction(revision: navigationCommandRevision)
        }
      }
    }
    .realityViewCameraControls(.none)
    .gesture(
      SpatialTapGesture()
        .targetedToAnyEntity()
        .onEnded { value in
          entityTapRevision += 1
          let tappedEntity: Entity = {
            guard NSEvent.modifierFlags.contains(.option) else { return value.entity }
            let initialPart = Self.semanticPartAncestor(from: value.entity)
            return value.entities(at: value.location, in: .local).first { candidate in
              guard candidate !== value.entity else { return false }
              let candidatePart = Self.semanticPartAncestor(from: candidate)
              if let initialPart, let candidatePart {
                return candidatePart !== initialPart
              }
              return candidatePart != nil
                || Self.ancestor(named: "importedModel", from: candidate) != nil
            } ?? value.entity
          }()
          switch SubObjectSelection.outcome(
            forTapOn: Self.tapTarget(for: tappedEntity, rig: rig),
            isPlacementActive: isPlacementActive
          ) {
          case .selectFeature(let candidate):
            if standingFeature?.partID == candidate.partID,
              standingFeature?.id == candidate.id
            {
              standingFeature = nil
              onSelectMateCandidate(.clearFeature)
            } else {
              standingFeature = candidate
              onSelectMateCandidate(.feature(candidate))
            }
          case .forwardToPlacement(let candidate):
            onSelectMateCandidate(.feature(candidate))
          case .selectComponent(let partID):
            standingFeature = nil
            onSelectPartID(partID)
          case .selectImportedNode:
            standingFeature = nil
            guard let importedHierarchyRootPath,
              let importedModel = Self.ancestor(named: "importedModel", from: tappedEntity),
              let path = Self.modelPath(
                for: tappedEntity,
                below: importedModel,
                hierarchyRootPath: importedHierarchyRootPath
              )
            else { return }
            onSelectModelPath(path)
          case .clearAll:
            standingFeature = nil
            onSelectMateCandidate(.clearAll)
          case .ignore:
            break
          }
        }
    )
    .simultaneousGesture(
      DragGesture(minimumDistance: 2)
        .targetedToAnyEntity()
        .onChanged { value in
          guard !focusedPartIsLocked,
            let focusedPartID,
            let handle = TransformGizmoFactory.handle(from: value.entity),
            let part = rig.parts.first(where: { $0.id == focusedPartID }),
            let partEntity = Self.semanticPartAncestor(from: value.entity)
          else { return }

          let dragState: TransformDragState
          if let transformDragState,
            transformDragState.partID == focusedPartID,
            transformDragState.handle == handle
          {
            dragState = transformDragState
          } else {
            dragState = TransformDragState(
              partID: focusedPartID,
              handle: handle,
              startPosition: part.positionMeters,
              startRotation: part.rotationEulerRadians
            )
            transformDragState = dragState
          }

          switch handle {
          case .translate(let axis):
            guard
              let start = value.unproject(value.startLocation, from: .local, to: .scene),
              let current = value.unproject(value.location, from: .local, to: .scene)
            else { return }
            let worldAxis = simd_normalize(
              partEntity.convert(direction: TransformGizmoFactory.vector(for: axis), to: nil)
            )
            let distance = simd_dot(current - start, worldAxis)
            let startPosition = Self.simdPosition(dragState.startPosition)
            onSetPartPosition(
              focusedPartID,
              Self.rigVector(startPosition + worldAxis * distance)
            )
          case .rotate(let axis):
            let angle = Self.rotationAngle(
              for: value.translation,
              axis: axis
            )
            var rotation = dragState.startRotation
            switch axis {
            case .x: rotation.x += angle
            case .y: rotation.y += angle
            case .z: rotation.z += angle
            }
            onSetPartRotation(focusedPartID, rotation)
          }
        }
        .onEnded { _ in
          transformDragState = nil
        }
    )
    .simultaneousGesture(armIKTargetDragGesture)
    .simultaneousGesture(sectionPlaneDragGesture)
    .simultaneousGesture(
      DragGesture(minimumDistance: 4)
        .targetedToAnyEntity()
        .onChanged { value in
          guard !isPlacementActive,
            Self.ancestor(named: Self.emptyClickCatcherName, from: value.entity) != nil
          else {
            return
          }
          let mode = BoxSelectionState.mode(
            start: value.startLocation,
            current: value.location
          )
          boxSelectionState = BoxSelectionState(
            start: value.startLocation,
            current: value.location,
            mode: mode
          )
          lastSelectionPoint = value.location
        }
        .onEnded { value in
          guard !isPlacementActive,
            Self.ancestor(named: Self.emptyClickCatcherName, from: value.entity) != nil
          else {
            return
          }
          let selectionRect = BoxSelectionState.standardizedRect(
            start: value.startLocation,
            current: value.location
          )
          let mode = BoxSelectionState.mode(
            start: value.startLocation,
            current: value.location
          )
          guard let root = Self.ancestor(named: "animaPreviewRoot", from: value.entity) else {
            boxSelectionState = nil
            return
          }
          let selectedIDs = Set(
            rig.parts.compactMap { part -> PartID? in
              guard let partEntity = root.findEntity(named: Self.partEntityName(part.id)) else {
                return nil
              }
              let bounds = partEntity.visualBounds(relativeTo: nil)
              let points = Self.boundingCorners(bounds).compactMap { point in
                value.project(point: point, to: .local)
              }
              guard let projectedBounds = Self.screenBounds(points) else { return nil }
              let isSelected = BoxSelectionState.includes(
                projectedBounds,
                in: selectionRect,
                mode: mode
              )
              return isSelected ? part.id : nil
            })
          boxSelectionState = nil
          onBoxSelectPartIDs(selectedIDs)
        }
    )
    .simultaneousGesture(
      SpatialEventGesture()
        .targetedToAnyEntity()
        .onChanged { value in
          hoveredFeature = MeshFeatureOverlayFactory.candidate(from: value.entity)
          reportPointerTarget(
            SubObjectSelection.pointerTarget(
              for: Self.tapTarget(for: value.entity, rig: rig)
            )
          )
        }
        .onEnded { _ in
          hoveredFeature = nil
        }
    )
    .overlay {
      CADNavigationCapture(
        profile: navigationProfile,
        customMapping: customNavigationMapping,
        sensitivity: navigationSensitivity,
        reversesWheelZoom: reversesWheelZoom
      ) { action in
        navigationAction = action
        navigationCommandRevision += 1
      } onFrameAll: {
        onFrameAll()
      } onContextMenuRequest: { location in
        onContextMenuRequest(location, pointerTarget)
      } onBackgroundClick: { location, _ in
        lastSelectionPoint = location
        let pendingRevision = entityTapRevision
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.035) {
          guard pendingRevision == entityTapRevision, !isPlacementActive else { return }
          standingFeature = nil
          pointerTarget = .canvas
          reportPointerTarget(.canvas)
          onSelectMateCandidate(.clearAll)
        }
      }
      .allowsHitTesting(false)
    }
    .overlay(alignment: .topLeading) {
      if let boxSelectionState {
        BoxSelectionOverlay(state: boxSelectionState)
      }
      if selectionCount > 1, let lastSelectionPoint {
        Text("\(selectionCount) selected")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(.black.opacity(0.78), in: Capsule())
          .offset(x: lastSelectionPoint.x + 12, y: lastSelectionPoint.y + 12)
          .allowsHitTesting(false)
          .accessibilityLabel("\(selectionCount) items selected")
      }
    }
    .overlay {
      ViewportEscapeCapture { isTextInputActive in
        guard
          SubObjectSelection.shouldConsumeEscape(
            hasFeatureSelection: standingFeature != nil,
            isPlacementActive: isPlacementActive,
            isTextInputActive: isTextInputActive
          )
        else { return false }
        standingFeature = nil
        onSelectMateCandidate(.clearFeature)
        return true
      }
      .allowsHitTesting(false)
    }
    .onChange(of: focusedPartID) { _, newFocusedPartID in
      if !SubObjectSelection.featureSurvivesFocusChange(
        standingFeature,
        focusedPartID: newFocusedPartID
      ) {
        standingFeature = nil
      }
    }
    .onChange(of: isPlacementActive) { _, placementActive in
      if placementActive {
        standingFeature = nil
      }
    }
    .onHover { isInside in
      if !isInside {
        hoveredFeature = nil
        reportPointerTarget(.canvas)
      }
    }
    .onDisappear {
      reportPointerTarget(.canvas)
    }
    .background { backgroundSettings.background }
    .id(sceneIdentity)
  }

  /// Mate placement owns the candidate markers whenever the workspace
  /// publishes placement candidates; standing sub-object selection stays
  /// out of the way so the placement flow is never double-handled.
  private var isPlacementActive: Bool {
    !mateCandidatePartIDs.isEmpty || selectedMateCandidate != nil
  }

  private var armIKTargetDragGesture: some Gesture {
    DragGesture(minimumDistance: 2)
      .targetedToAnyEntity()
      .onChanged { value in
        guard let targetPose = armIKTargetPose,
          ArmIKTargetFactory.contains(value.entity),
          let handle = TransformGizmoFactory.handle(from: value.entity),
          let targetEntity = Self.ancestor(named: ArmIKTargetFactory.name, from: value.entity)
        else { return }

        let dragState: ArmIKDragState
        if let armIKDragState, armIKDragState.handle == handle {
          dragState = armIKDragState
        } else {
          dragState = ArmIKDragState(handle: handle, startPose: targetPose)
          armIKDragState = dragState
        }

        let updatedPose: EngineResolvedPartPose?
        switch handle {
        case .translate(let axis):
          guard
            let start = value.unproject(value.startLocation, from: .local, to: .scene),
            let current = value.unproject(value.location, from: .local, to: .scene)
          else { return }
          let worldAxis = simd_normalize(
            targetEntity.convert(direction: TransformGizmoFactory.vector(for: axis), to: nil)
          )
          let distance = simd_dot(current - start, worldAxis)
          let position = dragState.startPose.positionMeters + worldAxis * distance
          updatedPose = EngineResolvedPartPose(
            positionMeters: [Double(position.x), Double(position.y), Double(position.z)],
            orientationImaginaryReal: [
              Double(dragState.startPose.orientationImaginaryReal.x),
              Double(dragState.startPose.orientationImaginaryReal.y),
              Double(dragState.startPose.orientationImaginaryReal.z),
              Double(dragState.startPose.orientationImaginaryReal.w),
            ]
          )
        case .rotate(let axis):
          let angle = Self.rotationAngle(for: value.translation, axis: axis)
          let start = dragState.startPose.realityKitTransform.rotation
          let delta = simd_quatf(
            angle: Float(angle),
            axis: TransformGizmoFactory.vector(for: axis)
          )
          let rotation = simd_normalize(start * delta)
          updatedPose = EngineResolvedPartPose(
            positionMeters: [
              Double(dragState.startPose.positionMeters.x),
              Double(dragState.startPose.positionMeters.y),
              Double(dragState.startPose.positionMeters.z),
            ],
            orientationImaginaryReal: [
              Double(rotation.imag.x), Double(rotation.imag.y),
              Double(rotation.imag.z), Double(rotation.real),
            ]
          )
        }
        if let updatedPose {
          onSetArmIKTargetPose(updatedPose)
        }
      }
      .onEnded { _ in
        armIKDragState = nil
      }
  }

  private var sectionPlaneDragGesture: some Gesture {
    DragGesture(minimumDistance: 2)
      .targetedToAnyEntity()
      .onChanged { value in
        guard sectionPlane.isEnabled, ViewportSectionFactory.contains(value.entity),
          let start = value.unproject(value.startLocation, from: .local, to: .scene),
          let current = value.unproject(value.location, from: .local, to: .scene)
        else { return }
        let initial = sectionDragStartPositionMeters ?? sectionPlane.positionMeters
        sectionDragStartPositionMeters = initial
        let offset = simd_dot(
          current - start,
          ViewportSectionFactory.axisVector(sectionPlane.axis)
        )
        onSetSectionPosition(initial + Double(offset))
      }
      .onEnded { _ in sectionDragStartPositionMeters = nil }
  }

  private var sceneIdentity: String {
    let partIDs = rig.parts.map { $0.id.rawValue.uuidString }.joined(separator: ",")
    let jointIDs = rig.joints.map { $0.id.rawValue }.joined(separator: ",")
    let proxyFillets = partAppearances.map {
      "\($0.key.rawValue.uuidString):\($0.value.proxyFilletRadiusMeters)"
    }.sorted().joined(separator: ",")
    // Only include state that requires rebuilding geometry (which meshes, the
    // part/joint structure, proxy fillet radius). The section plane is applied
    // live every frame by the update: closure (refreshClippingMaterials), so
    // it must NOT be here — otherwise dragging the clip plane re-parses every
    // STL from disk per frame. Other visual style still rebuilds until it is
    // moved into update: too (see the Codex packet).
    return
      "\(modelURL?.absoluteString ?? "none")|\(partModelSources.values.map { "\($0.partID.rawValue):\($0.fileURL.path):\($0.modelNode ?? ""):\($0.unitScaleToMeters):v\($0.assetVersion)" }.sorted().joined(separator: ","))|\(appearance.rawValue)|\(renderStyle.rawValue)|\(edgeDisplay.rawValue)|\(lightingPreset.rawValue)|\(materialFinish.rawValue)|\(reflectionMode.rawValue)|\(lightingIntensity)|\(environmentPreset.rawValue)|\(environmentRotationDegrees)|\(showsShadows)|\(partIDs)|\(jointIDs)|\(proxyFillets)"
  }

  private static func makeScene(
    rig: CharacterRig,
    appearance: PreviewAppearance,
    renderStyle: ViewportRenderStyle,
    edgeDisplay: ViewportEdgeDisplay,
    lightingPreset: ViewportLightingPreset,
    materialFinish: ViewportMaterialFinish,
    partAppearances: [PartID: PreviewPartAppearance],
    partModelSources: [PartID: PartModelSource],
    reflectionMode: ViewportReflectionMode,
    lightingIntensity: Float,
    environmentPreset: ViewportEnvironmentPreset,
    environmentRotationDegrees: Float,
    sectionPlane: ViewportSectionPlane,
    showsShadows: Bool
  ) async -> Entity {
    let root = Entity()
    root.name = "animaPreviewRoot"

    // AnimaCore resolves part-in-character transforms. Keep a distinct
    // character root even while Character-in-World is identity in the Rig
    // workspace, so scene placement never leaks into part authoring.
    let characterRoot = Entity()
    characterRoot.name = "animaCharacterRoot"
    root.addChild(characterRoot)

    root.addChild(makeGrid(appearance: appearance))

    for part in rig.parts {
      var loadedModel: LoadedRealityKitModel?
      if let source = partModelSources[part.id] {
        do {
          loadedModel = try await RealityKitModelLoader.loadWithTopology(
            contentsOf: source.fileURL,
            unitScaleToMeters: source.unitScaleToMeters,
            modelNode: source.modelNode
          )
        } catch {
          Self.modelLoadLog.error(
            """
            Part \(part.displayName, privacy: .public) could not load \
            \(source.fileURL.lastPathComponent, privacy: .public): \
            \(error.localizedDescription, privacy: .public) — showing proxy.
            """
          )
        }
      }
      if let loaded = loadedModel {
        characterRoot.addChild(
          await makeImportedPart(
            part,
            imported: loaded.entity,
            topology: loaded.topology,
            renderStyle: renderStyle,
            edgeDisplay: edgeDisplay,
            appearance: partAppearances[part.id],
            showsShadows: showsShadows
          )
        )
      } else {
        characterRoot.addChild(
          makePart(
            part,
            renderStyle: renderStyle,
            edgeDisplay: edgeDisplay,
            appearance: partAppearances[part.id],
            showsShadows: showsShadows
          )
        )
      }
    }

    for joint in rig.joints {
      guard let childPartID = joint.childPartID,
        let child = characterRoot.findEntity(named: partEntityName(childPartID))
      else { continue }
      let guide = RigGuideFactory.makeRevoluteGuide()
      if let connector = joint.childConnector {
        guide.position = simdPosition(connector.originMeters)
        guide.orientation = MateConnectorMarkerFactory.orientation(connector)
      }
      child.addChild(guide)
    }

    let camera = Entity(components: PerspectiveCameraComponent(fieldOfViewInDegrees: 60))
    camera.name = "previewCamera"
    camera.position = SIMD3<Float>(2.8, 1.8, 3.8)
    camera.look(at: SIMD3<Float>(0, 0.8, 0), from: camera.position, relativeTo: nil)
    camera.addChild(makeEmptyClickCatcher())
    root.addChild(camera)

    let cameraTarget = Entity()
    cameraTarget.name = "previewCameraTarget"
    cameraTarget.position = SIMD3<Float>(0, 0.8, 0)
    root.addChild(cameraTarget)

    for light in ViewportLightingFactory.makeLights(
      preset: lightingPreset,
      baseIntensity: appearance.lightIntensity,
      intensityMultiplier: lightingIntensity,
      showsShadows: showsShadows
    ) {
      root.addChild(light)
    }

    if let environmentLight = await ViewportLightingFactory.makeEnvironmentLight(
      mode: reflectionMode,
      preset: environmentPreset,
      intensityMultiplier: lightingIntensity,
      rotationDegrees: environmentRotationDegrees
    ) {
      root.addChild(environmentLight)
      ViewportLightingFactory.applyEnvironmentReceiver(light: environmentLight, to: root)
    }

    ViewportSectionFactory.apply(sectionPlane, to: characterRoot)

    return root
  }

  private static func makePart(
    _ part: RigPartDefinition,
    renderStyle: ViewportRenderStyle,
    edgeDisplay: ViewportEdgeDisplay,
    appearance: PreviewPartAppearance?,
    showsShadows: Bool
  ) -> Entity {
    let appearance = appearance ?? .defaultAppearance(for: part.primitiveKind)
    let material = ViewportRenderStyleApplier.partMaterial(
      renderStyle,
      finish: appearance.finish,
      baseColor: appearance.nsColor
    )
    let entity: ModelEntity
    switch part.primitiveKind {
    case .box, .mesh:
      // .mesh only reaches makePart when its imported model failed to load
      // (the failure is logged); show a bounding-box placeholder, not silence.
      let size = Float(RigPrimitivePreviewGeometry.boxSizeMeters)
      let filletRadius = Float(appearance.proxyFilletRadiusMeters)
      let mesh: MeshResource =
        if filletRadius > 0 {
          .generateBox(
            width: size,
            height: size,
            depth: size,
            cornerRadius: filletRadius
          )
        } else {
          .generateBox(width: size, height: size, depth: size)
        }
      entity = ModelEntity(
        mesh: mesh,
        materials: [material]
      )
    case .cylinder:
      entity = ModelEntity(
        mesh: .generateCylinder(
          height: Float(RigPrimitivePreviewGeometry.cylinderHeightMeters),
          radius: Float(RigPrimitivePreviewGeometry.cylinderRadiusMeters)
        ),
        materials: [material]
      )
    case .sphere:
      entity = ModelEntity(
        mesh: .generateSphere(radius: Float(RigPrimitivePreviewGeometry.sphereRadiusMeters)),
        materials: [material]
      )
    case .locator:
      entity = ModelEntity(
        mesh: .generateSphere(radius: Float(RigPrimitivePreviewGeometry.locatorRadiusMeters)),
        materials: [material]
      )
    }
    entity.name = partEntityName(part.id)
    entity.isEnabled = appearance.isVisible
    entity.position = simdPosition(part.positionMeters)
    entity.orientation = orientation(part.rotationEulerRadians)
    entity.components.set(OpacityComponent(opacity: Float(appearance.opacity)))
    prepareForSelection(entity)
    entity.components.set(
      GroundingShadowComponent(
        castsShadow: showsShadows,
        receivesShadow: showsShadows
      )
    )
    ViewportRenderStyleApplier.addMeshEdgeOverlayIfNeeded(
      edgeDisplay,
      renderStyle: renderStyle,
      to: entity
    )
    return entity
  }

  private static func makeImportedPart(
    _ part: RigPartDefinition,
    imported: Entity,
    topology: ImportedMeshTopology?,
    renderStyle: ViewportRenderStyle,
    edgeDisplay: ViewportEdgeDisplay,
    appearance: PreviewPartAppearance?,
    showsShadows: Bool
  ) async -> Entity {
    let appearance = appearance ?? .defaultAppearance(for: part.primitiveKind)
    let container = Entity()
    container.name = partEntityName(part.id)
    imported.name = "importedGeometry"
    prepareForSelection(imported, hoverStrength: 0.48)
    ViewportRenderStyleApplier.apply(renderStyle, edgeDisplay: edgeDisplay, to: imported)
    applyShadowParticipation(showsShadows, to: imported)
    container.addChild(imported)
    container.position = simdPosition(part.positionMeters)
    container.orientation = orientation(part.rotationEulerRadians)
    container.isEnabled = appearance.isVisible
    container.components.set(OpacityComponent(opacity: Float(appearance.opacity)))
    applyMaterialOverride(
      appearance,
      renderStyle: renderStyle,
      to: imported
    )
    if let topology {
      imported.addChild(
        await MeshFeatureOverlayFactory.make(partID: part.id, topology: topology)
      )
    }
    return container
  }

  private static func applyPartAppearances(
    _ appearances: [PartID: PreviewPartAppearance],
    rig: CharacterRig,
    renderStyle: ViewportRenderStyle,
    to root: Entity
  ) {
    for part in rig.parts {
      guard let entity = root.findEntity(named: partEntityName(part.id)) else { continue }

      let appearance = appearances[part.id] ?? .defaultAppearance(for: part.primitiveKind)
      entity.isEnabled = appearance.isVisible
      entity.components.set(OpacityComponent(opacity: Float(appearance.opacity)))
      applyMaterialOverride(
        appearance,
        renderStyle: renderStyle,
        to: entity
      )
    }
  }

  private static func applyMaterialOverride(
    _ appearance: PreviewPartAppearance,
    renderStyle: ViewportRenderStyle,
    to root: Entity
  ) {
    var stack = [root]
    while let entity = stack.popLast() {
      if entity.components[MeshFeatureComponent.self] != nil {
        continue
      }
      if var model = entity.components[ModelComponent.self] {
        let count = max(model.materials.count, 1)
        model.materials = Array(
          repeating: ViewportRenderStyleApplier.partMaterial(
            renderStyle,
            finish: appearance.finish,
            baseColor: appearance.nsColor
          ),
          count: count
        )
        entity.components.set(model)
      }
      stack.append(contentsOf: entity.children)
    }
  }

  private func reportCameraState(_ updatedState: PreviewCameraState) {
    guard updatedState != cameraState else { return }
    Task { @MainActor in
      onCameraStateChange(updatedState)
    }
  }

  private func reportPointerTarget(_ updatedTarget: ViewportPointerTarget) {
    guard updatedTarget != pointerTarget else { return }
    pointerTarget = updatedTarget
    onPointerTargetChange(updatedTarget)
  }

  private func consumeNavigationAction(revision: Int) {
    Task { @MainActor in
      guard navigationCommandRevision == revision else { return }
      navigationAction = nil
    }
  }

  private static func applyRig(
    _ rig: CharacterRig,
    engineResolvedPartPoses: [PartID: EngineResolvedPartPose],
    to root: Entity
  ) {
    for part in rig.parts {
      guard let entity = root.findEntity(named: partEntityName(part.id)) else { continue }
      if let pose = engineResolvedPartPoses[part.id] {
        entity.transform = pose.realityKitTransform
      } else {
        entity.position = simdPosition(part.positionMeters)
        entity.orientation = orientation(part.rotationEulerRadians)
      }
    }
  }

  private static func applySelection(
    _ selectedPartID: PartID?,
    highlightedPartIDs: Set<PartID>,
    isLocked: Bool,
    allowsTransformGizmo: Bool,
    rig: CharacterRig,
    to root: Entity
  ) {
    for part in rig.parts {
      guard let entity = root.findEntity(named: partEntityName(part.id)) else { continue }
      let isSelected = part.id == selectedPartID
      let isHighlighted = isSelected || highlightedPartIDs.contains(part.id)
      let highlight = entity.findEntity(named: TransformGizmoFactory.selectionHighlightName)
      let gizmo = entity.findEntity(named: TransformGizmoFactory.gizmoName)

      if isHighlighted {
        if highlight == nil {
          entity.addChild(TransformGizmoFactory.makeSelectionHighlight(for: part.primitiveKind))
        }
        if !isSelected || isLocked || !allowsTransformGizmo {
          gizmo?.removeFromParent()
        } else if gizmo == nil {
          entity.addChild(TransformGizmoFactory.make())
        }
      } else {
        highlight?.removeFromParent()
        gizmo?.removeFromParent()
      }
    }
  }

  static func partEntityName(_ id: PartID) -> String {
    "semanticPart-\(id.rawValue.uuidString)"
  }

  static let emptyClickCatcherName = "viewportEmptyClickCatcher"

  /// An invisible camera-locked collision plane far behind the scene so
  /// clicks that hit no geometry resolve as deliberate empty clicks
  /// (deselection) instead of being silently dropped. It sits well beyond
  /// the maximum zoom-out distance, so it never occludes real content.
  private static func makeEmptyClickCatcher() -> Entity {
    let catcher = Entity()
    catcher.name = emptyClickCatcherName
    catcher.position = SIMD3<Float>(0, 0, -250)
    catcher.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    catcher.components.set(
      CollisionComponent(shapes: [.generateBox(width: 1600, height: 1600, depth: 0.1)])
    )
    return catcher
  }

  /// Classifies what a viewport tap landed on, in priority order: the
  /// empty-click catcher, a feature candidate marker, semantic part
  /// geometry, then the imported source model. Anything unrecognized is
  /// treated as empty so deselection stays consistent.
  static func tapTarget(for entity: Entity, rig: CharacterRig) -> SubObjectTapTarget {
    if ancestor(named: emptyClickCatcherName, from: entity) != nil {
      return .empty
    }
    if let candidate = MateConnectorMarkerFactory.candidate(from: entity, rig: rig) {
      return .feature(candidate)
    }
    if let candidate = MeshFeatureOverlayFactory.candidate(from: entity) {
      return .feature(candidate)
    }
    if let partID = partID(for: entity) {
      return .component(partID)
    }
    if ancestor(named: "importedModel", from: entity) != nil {
      return .importedNode
    }
    return .empty
  }

  private static func simdPosition(_ vector: RigVector3) -> SIMD3<Float> {
    SIMD3<Float>(Float(vector.x), Float(vector.y), Float(vector.z))
  }

  private static func rigVector(_ vector: SIMD3<Float>) -> RigVector3 {
    RigVector3(x: Double(vector.x), y: Double(vector.y), z: Double(vector.z))
  }

  /// Keeps edge/corner hit hulls approximately screen-size-stable as the
  /// operator zooms. Face picking remains exact triangle geometry.
  private static func meshFeaturePickScale(
    projection: PreviewCameraProjection,
    cameraState: PreviewCameraState
  ) -> Float {
    let rawScale: Float =
      switch projection {
      case .perspective:
        cameraState.distance / 4.5
      case .orthographic:
        cameraState.orthographicScale / 2.8
      }
    return min(max(rawScale, 0.35), 8)
  }

  private static func boundingCorners(_ bounds: BoundingBox) -> [SIMD3<Float>] {
    let minimum = bounds.min
    let maximum = bounds.max
    return [
      SIMD3(minimum.x, minimum.y, minimum.z),
      SIMD3(maximum.x, minimum.y, minimum.z),
      SIMD3(minimum.x, maximum.y, minimum.z),
      SIMD3(maximum.x, maximum.y, minimum.z),
      SIMD3(minimum.x, minimum.y, maximum.z),
      SIMD3(maximum.x, minimum.y, maximum.z),
      SIMD3(minimum.x, maximum.y, maximum.z),
      SIMD3(maximum.x, maximum.y, maximum.z),
    ]
  }

  private static func screenBounds(_ points: [CGPoint]) -> CGRect? {
    guard let first = points.first else { return nil }
    return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { bounds, point in
      bounds.union(CGRect(origin: point, size: .zero))
    }
  }

  private static func orientation(_ eulerRadians: RigVector3) -> simd_quatf {
    CharacterSpaceTransform.orientation(rotationEulerRadians: eulerRadians)
  }

  private static func rotationAngle(
    for translation: CGSize,
    axis: JointAxis
  ) -> Double {
    let pixels: CGFloat =
      switch axis {
      case .x: -translation.height
      case .y: translation.width
      case .z: translation.width - translation.height
      }
    return Double(pixels) * 0.01
  }

  private static func applyNavigation(
    _ action: CADNavigationAction,
    revision: Int,
    cameraState: PreviewCameraState,
    to root: Entity
  ) -> PreviewCameraState? {
    let markerName = "previewNavigationCommand-\(revision)"
    guard root.findEntity(named: markerName) == nil,
      let camera = root.findEntity(named: "previewCamera"),
      let cameraTarget = root.findEntity(named: "previewCameraTarget")
    else { return nil }

    for child in Array(root.children)
    where child.name.hasPrefix("previewNavigationCommand-") {
      child.removeFromParent()
    }

    let target = cameraTarget.position
    var offset = camera.position - target
    let distance = max(simd_length(offset), 0.001)

    switch action {
    case .orbit(let deltaX, let deltaY):
      let yaw = atan2(offset.x, offset.z) - Float(deltaX) * 0.008
      let existingPitch = asin(max(min(offset.y / distance, 1), -1))
      let pitch = max(
        min(existingPitch + Float(deltaY) * 0.008, .pi / 2 - 0.02),
        -.pi / 2 + 0.02
      )
      let horizontal = cos(pitch) * distance
      offset = SIMD3<Float>(sin(yaw) * horizontal, sin(pitch) * distance, cos(yaw) * horizontal)
      camera.position = target + offset
    case .pan(let deltaX, let deltaY):
      let forward = simd_normalize(target - camera.position)
      var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
      if simd_length_squared(right) < 0.0001 {
        right = SIMD3<Float>(1, 0, 0)
      } else {
        right = simd_normalize(right)
      }
      let up = simd_normalize(simd_cross(right, forward))
      let scale = max(distance, 0.2) * 0.002
      let shift = (-right * Float(deltaX) + up * Float(deltaY)) * scale
      camera.position += shift
      cameraTarget.position += shift
    case .zoom(let delta), .preciseZoom(let delta):
      let factor = exp(-Float(delta) * 0.139262)
      if var orthographic = camera.components[OrthographicCameraComponent.self] {
        orthographic.scale = min(max(orthographic.scale * factor, 0.05), 100)
        camera.components.set(orthographic)
      } else {
        let newDistance = min(max(distance * factor, 0.15), 100)
        camera.position = target + simd_normalize(offset) * newDistance
      }
    }

    applyCameraOrientation(
      to: camera,
      target: cameraTarget.position,
      rollRadians: cameraState.orientation.rollRadians
    )
    let marker = Entity()
    marker.name = markerName
    root.addChild(marker)
    return captureCameraState(
      camera: camera,
      target: cameraTarget,
      rollRadians: cameraState.orientation.rollRadians
    )
  }

  private static func applyProjectionIfNeeded(
    _ projection: PreviewCameraProjection,
    cameraState: PreviewCameraState,
    to root: Entity
  ) {
    let markerName = "previewProjection-\(projection.rawValue)"
    guard root.findEntity(named: markerName) == nil,
      let camera = root.findEntity(named: "previewCamera")
    else { return }

    for child in Array(root.children)
    where child.name.hasPrefix("previewProjection-") {
      child.removeFromParent()
    }
    for child in Array(root.children)
    where child.name.hasPrefix("previewFieldOfView-") {
      child.removeFromParent()
    }

    switch projection {
    case .perspective:
      camera.components.remove(OrthographicCameraComponent.self)
      camera.components.set(PerspectiveCameraComponent())
    case .orthographic:
      camera.components.remove(PerspectiveCameraComponent.self)
      var component = OrthographicCameraComponent()
      component.scale = cameraState.orthographicScale
      camera.components.set(component)
    }

    let marker = Entity()
    marker.name = markerName
    root.addChild(marker)
  }

  private static func applyFieldOfViewIfNeeded(
    _ fieldOfViewDegrees: Float,
    to root: Entity
  ) {
    let roundedFieldOfView = Int(fieldOfViewDegrees.rounded())
    let markerName = "previewFieldOfView-\(roundedFieldOfView)"
    guard root.findEntity(named: markerName) == nil,
      let camera = root.findEntity(named: "previewCamera"),
      var component = camera.components[PerspectiveCameraComponent.self]
    else { return }

    for child in Array(root.children)
    where child.name.hasPrefix("previewFieldOfView-") {
      child.removeFromParent()
    }
    component.fieldOfViewInDegrees = fieldOfViewDegrees
    camera.components.set(component)

    let marker = Entity()
    marker.name = markerName
    root.addChild(marker)
  }

  private static func applyCameraCommandIfNeeded(
    revision: Int,
    viewpoint: PreviewCameraViewpoint,
    cameraState: PreviewCameraState,
    focusedModelPath: ModelEntityPath?,
    focusedPartID: PartID?,
    to root: Entity
  ) -> PreviewCameraState? {
    let markerName = "previewCameraCommand-\(revision)"
    guard root.findEntity(named: markerName) == nil,
      let camera = root.findEntity(named: "previewCamera")
    else { return nil }

    for child in Array(root.children)
    where child.name.hasPrefix("previewCameraCommand-") {
      child.removeFromParent()
    }

    let defaultTarget = SIMD3<Float>(0, 0.8, 0)
    var target = defaultTarget
    var distance: Float = 4.5

    if viewpoint == .selection {
      let focusedEntity: Entity? = {
        if let focusedPartID {
          return root.findEntity(named: partEntityName(focusedPartID))
        }
        guard let focusedModelPath,
          let importedModel = root.findEntity(named: "importedModel")
        else { return nil }
        return entity(at: focusedModelPath, below: importedModel)
      }()
      if let focusedEntity {
        let bounds = focusedEntity.visualBounds(relativeTo: root)
        target = bounds.center
        distance = max(bounds.extents.x, bounds.extents.y, bounds.extents.z) * 2.5
        distance = max(distance, 0.8)
      }
    }

    switch viewpoint {
    case .home, .selection:
      camera.position = target + SIMD3<Float>(distance * 0.62, distance * 0.22, distance * 0.78)
    case .front:
      camera.position = target + SIMD3<Float>(0, 0, distance)
    case .right:
      camera.position = target + SIMD3<Float>(distance, 0, 0)
    case .top:
      camera.position = target + SIMD3<Float>(0, distance, 0.001)
    case .custom:
      target = cameraState.target.vector
      distance = cameraState.distance
      camera.position = target + cameraState.orientation.direction.vector * distance
    }
    applyCameraOrientation(
      to: camera,
      target: target,
      rollRadians: cameraState.orientation.rollRadians
    )
    root.findEntity(named: "previewCameraTarget")?.position = target

    let marker = Entity()
    marker.name = markerName
    root.addChild(marker)
    guard let cameraTarget = root.findEntity(named: "previewCameraTarget") else { return nil }
    return captureCameraState(
      camera: camera,
      target: cameraTarget,
      rollRadians: cameraState.orientation.rollRadians
    )
  }

  private static func captureCameraState(
    camera: Entity,
    target: Entity,
    rollRadians: Float
  ) -> PreviewCameraState {
    let offset = camera.position - target.position
    let distance = max(simd_length(offset), 0.001)
    let direction = offset / distance
    let orthographicScale = camera.components[OrthographicCameraComponent.self]?.scale ?? 2.8
    return PreviewCameraState(
      orientation: PreviewCameraOrientation(
        direction: PreviewCameraDirection(x: direction.x, y: direction.y, z: direction.z),
        rollRadians: rollRadians
      ),
      target: PreviewCameraPoint(
        x: target.position.x,
        y: target.position.y,
        z: target.position.z
      ),
      distance: distance,
      orthographicScale: orthographicScale
    )
  }

  private static func applyCameraOrientation(
    to camera: Entity,
    target: SIMD3<Float>,
    rollRadians: Float
  ) {
    camera.look(at: target, from: camera.position, relativeTo: nil)
    guard abs(rollRadians) > 0.0001 else { return }
    let localViewAxis = SIMD3<Float>(0, 0, -1)
    camera.orientation *= simd_quatf(angle: rollRadians, axis: localViewAxis)
  }

  private static func entity(
    at path: ModelEntityPath,
    below root: Entity
  ) -> Entity? {
    var entity = root
    for component in path.components.dropFirst() {
      guard component.siblingIndex >= 0,
        component.siblingIndex < entity.children.count
      else { return nil }
      entity = entity.children[component.siblingIndex]
    }
    return entity
  }

  private static func prepareForSelection(
    _ entity: Entity,
    hoverStrength: Float = 1.35
  ) {
    entity.generateCollisionShapes(recursive: true)
    addInputTargets(to: entity)
    addHoverEffects(to: entity, strength: hoverStrength)
  }

  private static func applyShadowParticipation(_ enabled: Bool, to root: Entity) {
    var stack = [root]
    while let entity = stack.popLast() {
      if entity.components[ModelComponent.self] != nil {
        entity.components.set(
          GroundingShadowComponent(castsShadow: enabled, receivesShadow: enabled)
        )
      }
      stack.append(contentsOf: entity.children)
    }
  }

  private static func addInputTargets(to entity: Entity) {
    entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    for child in entity.children {
      addInputTargets(to: child)
    }
  }

  private static func addHoverEffects(to entity: Entity, strength: Float) {
    if entity.components[ModelComponent.self] != nil {
      entity.components.set(
        HoverEffectComponent(
          .highlight(.init(color: .systemCyan, strength: strength))
        )
      )
    }
    for child in entity.children {
      addHoverEffects(to: child, strength: strength)
    }
  }

  private static func modelPath(
    for selectedEntity: Entity,
    below importedRoot: Entity,
    hierarchyRootPath: ModelEntityPath
  ) -> ModelEntityPath? {
    guard let rootComponent = hierarchyRootPath.components.first else { return nil }

    var components: [ModelEntityPathComponent] = []
    var current = selectedEntity
    while current != importedRoot {
      guard let parent = current.parent,
        let siblingIndex = parent.children.firstIndex(of: current)
      else { return nil }
      components.append(
        ModelEntityPathComponent(name: current.name, siblingIndex: siblingIndex)
      )
      current = parent
    }

    return ModelEntityPath(components: [rootComponent] + components.reversed())
  }

  private static func ancestor(named name: String, from entity: Entity) -> Entity? {
    var candidate: Entity? = entity
    while let current = candidate {
      if current.name == name {
        return current
      }
      candidate = current.parent
    }
    return nil
  }

  private static func semanticPartAncestor(from entity: Entity) -> Entity? {
    var candidate: Entity? = entity
    while let current = candidate {
      if current.name.hasPrefix("semanticPart-") {
        return current
      }
      candidate = current.parent
    }
    return nil
  }

  private static func partID(for entity: Entity) -> PartID? {
    guard let partEntity = semanticPartAncestor(from: entity) else { return nil }
    let rawValue = String(partEntity.name.dropFirst("semanticPart-".count))
    guard let uuid = UUID(uuidString: rawValue) else { return nil }
    return PartID(rawValue: uuid)
  }

  private static func makeGrid(appearance: PreviewAppearance) -> Entity {
    let grid = Entity()
    grid.name = "previewGrid"

    let minorMaterial = SimpleMaterial(color: appearance.minorGridColor, isMetallic: false)
    let majorMaterial = SimpleMaterial(color: appearance.majorGridColor, isMetallic: false)
    let extent: Float = 10
    let spacing: Float = 0.5

    for index in -10...10 {
      let isMajor = index.isMultiple(of: 5)
      let thickness: Float = isMajor ? 0.012 : 0.004
      let material = isMajor ? majorMaterial : minorMaterial
      let offset = Float(index) * spacing

      let xLine = ModelEntity(
        mesh: .generateBox(width: extent, height: 0.002, depth: thickness),
        materials: [material]
      )
      xLine.position.z = offset
      grid.addChild(xLine)

      let zLine = ModelEntity(
        mesh: .generateBox(width: thickness, height: 0.002, depth: extent),
        materials: [material]
      )
      zLine.position.x = offset
      grid.addChild(zLine)
    }

    return grid
  }

  private static func normalizeForPreview(_ entity: Entity) {
    let bounds = entity.visualBounds(relativeTo: entity)
    let largestExtent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
    guard largestExtent.isFinite, largestExtent > 0 else { return }

    let scale = 1.6 / largestExtent
    entity.scale = SIMD3<Float>(repeating: scale)
    entity.position = SIMD3<Float>(
      -bounds.center.x * scale,
      0.8 - (bounds.center.y * scale),
      -bounds.center.z * scale
    )
  }
}

private struct TransformDragState {
  let partID: PartID
  let handle: TransformHandleKind
  let startPosition: RigVector3
  let startRotation: RigVector3
}

private struct ArmIKDragState {
  let handle: TransformHandleKind
  let startPose: EngineResolvedPartPose
}

enum BoxSelectionMode: Equatable {
  case window
  case crossing
}

struct BoxSelectionState {
  let start: CGPoint
  let current: CGPoint
  let mode: BoxSelectionMode

  var rect: CGRect {
    Self.standardizedRect(start: start, current: current)
  }

  static func standardizedRect(start: CGPoint, current: CGPoint) -> CGRect {
    CGRect(
      x: min(start.x, current.x),
      y: min(start.y, current.y),
      width: abs(current.x - start.x),
      height: abs(current.y - start.y)
    )
  }

  static func mode(start: CGPoint, current: CGPoint) -> BoxSelectionMode {
    current.x >= start.x ? .window : .crossing
  }

  static func includes(
    _ projectedBounds: CGRect,
    in selectionRect: CGRect,
    mode: BoxSelectionMode
  ) -> Bool {
    switch mode {
    case .window:
      selectionRect.contains(projectedBounds)
    case .crossing:
      selectionRect.intersects(projectedBounds)
    }
  }
}

private struct BoxSelectionOverlay: View {
  let state: BoxSelectionState

  var body: some View {
    let color: Color = state.mode == .window ? .blue : .yellow
    Rectangle()
      .fill(color.opacity(0.12))
      .overlay {
        Rectangle()
          .stroke(
            color.opacity(0.95),
            style: StrokeStyle(
              lineWidth: 1.3,
              dash: state.mode == .crossing ? [6, 4] : []
            )
          )
      }
      .frame(width: state.rect.width, height: state.rect.height)
      .offset(x: state.rect.minX, y: state.rect.minY)
      .allowsHitTesting(false)
      .accessibilityLabel(
        state.mode == .window ? "Window selection" : "Crossing selection"
      )
  }
}
