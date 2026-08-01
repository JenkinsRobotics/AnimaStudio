import AnimaCAD
import MetalKit
import SwiftUI

enum CADMetalLightingModel {
  static let colorPixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
  static let ambientFloorScale: Float = 0.42
  static let ambientCeilingScale: Float = 1.28

  static func readableNormal(
    _ normal: SIMD3<Float>,
    viewDirection: SIMD3<Float>
  ) -> SIMD3<Float> {
    let safeView =
      simd_length_squared(viewDirection) > 0.000_001
      ? simd_normalize(viewDirection)
      : SIMD3<Float>(0, 0, 1)
    guard simd_length_squared(normal) > 0.000_001 else { return safeView }
    let normalized = simd_normalize(normal)
    return simd_dot(normalized, safeView) < 0 ? -normalized : normalized
  }

  static func ambientLevel(normalY: Float, strength: Float) -> Float {
    let hemisphere = max(0, min(normalY * 0.5 + 0.5, 1))
    return
      strength
      * (ambientFloorScale + (ambientCeilingScale - ambientFloorScale) * hemisphere)
  }

  /// Keeps an imported dielectric black legible in an authoring viewport
  /// without inventing illumination when every light is disabled.
  static func darkMaterialLift(sourceLuminance: Float, lightingEnergy: Float) -> Float {
    let darkness = 1 - smoothstep(0, 0.08, sourceLuminance)
    return darkness * max(0, min(lightingEnergy, 1)) * 0.055
  }

  private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
    let t = max(0, min((value - edge0) / (edge1 - edge0), 1))
    return t * t * (3 - 2 * t)
  }
}

enum CADMetalRendererPolicy {
  static let preferredFramesPerSecond = 60
}

enum CADMetalEdgeStyle {
  static func widthPixels(strength: Float) -> Float {
    guard strength > 0.02 else { return 0 }
    return 0.85 + min(max(strength, 0), 1) * 2.65
  }

  static func offsetsPixels(strength: Float) -> [Float] {
    let width = widthPixels(strength: strength)
    guard width > 0 else { return [] }
    if width < 1.45 { return [0] }
    if width < 2.45 { return [-0.55, 0, 0.55] }
    return [-1.15, -0.575, 0, 0.575, 1.15]
  }

  static func opacity(strength: Float) -> Float {
    guard strength > 0.02 else { return 0 }
    return 0.44 + min(max(strength, 0), 1) * 0.56
  }
}

enum CADMetalRuntimeValidation {
  @MainActor
  static func validateRenderer(device: MTLDevice) throws {
    _ = try MetalRenderer(device: device, sampleCount: 1, onFrame: {})
  }
}

enum CADMetalPartPicker {
  static func partID(
    at point: CGPoint,
    viewportSize: CGSize,
    geometry: CADRenderGeometry,
    viewProjection: simd_float4x4,
    hiddenPartIDs: Set<Int>,
    partTransforms: [CADPartTransformPresentation]
  ) -> Int? {
    guard viewportSize.width > 0, viewportSize.height > 0 else { return nil }
    let ndc = SIMD2<Float>(
      Float(point.x / viewportSize.width) * 2 - 1,
      Float(point.y / viewportSize.height) * 2 - 1)
    let inverseViewProjection = simd_inverse(viewProjection)
    guard
      let rayNear = unproject(SIMD3(ndc.x, ndc.y, 0), inverse: inverseViewProjection),
      let rayFar = unproject(SIMD3(ndc.x, ndc.y, 1), inverse: inverseViewProjection)
    else { return nil }
    let rayDirection = simd_normalize(rayFar - rayNear)
    guard rayDirection.x.isFinite, rayDirection.y.isFinite, rayDirection.z.isFinite else {
      return nil
    }

    let transforms = Dictionary(
      uniqueKeysWithValues: partTransforms.map { (UInt32(clamping: $0.partID), $0.matrix) })
    var localRays:
      [UInt32: (origin: SIMD3<Float>, direction: SIMD3<Float>, transform: simd_float4x4)] = [:]
    var nearestDistance = Float.greatestFiniteMagnitude
    var nearestPartID: Int?

    let triangleCount = geometry.indices.count / 3
    for triangle in 0..<triangleCount {
      let indexOffset = triangle * 3
      let i0 = Int(geometry.indices[indexOffset])
      let i1 = Int(geometry.indices[indexOffset + 1])
      let i2 = Int(geometry.indices[indexOffset + 2])
      guard i0 < geometry.positions.count, i1 < geometry.positions.count,
        i2 < geometry.positions.count, i0 < geometry.partIDs.count
      else { continue }
      let partID = geometry.partIDs[i0]
      guard partID > 0, !hiddenPartIDs.contains(Int(partID)) else { continue }

      let localRay:
        (
          origin: SIMD3<Float>, direction: SIMD3<Float>, transform: simd_float4x4
        )
      if let cached = localRays[partID] {
        localRay = cached
      } else {
        let transform = transforms[partID] ?? matrix_identity_float4x4
        let inverse = simd_inverse(transform)
        let localOrigin = transformedPoint(rayNear, by: inverse)
        let localTarget = transformedPoint(rayNear + rayDirection, by: inverse)
        let direction = simd_normalize(localTarget - localOrigin)
        localRay = (localOrigin, direction, transform)
        localRays[partID] = localRay
      }

      guard
        let distance = intersectionDistance(
          rayOrigin: localRay.origin,
          rayDirection: localRay.direction,
          v0: geometry.positions[i0],
          v1: geometry.positions[i1],
          v2: geometry.positions[i2])
      else { continue }
      let localHit = localRay.origin + localRay.direction * distance
      let worldHit = transformedPoint(localHit, by: localRay.transform)
      let worldDistance = simd_length(worldHit - rayNear)
      if worldDistance < nearestDistance {
        nearestDistance = worldDistance
        nearestPartID = Int(partID)
      }
    }
    return nearestPartID
  }

  private static func unproject(
    _ point: SIMD3<Float>,
    inverse: simd_float4x4
  ) -> SIMD3<Float>? {
    let homogeneous = inverse * SIMD4(point, 1)
    guard abs(homogeneous.w) > 0.000_001 else { return nil }
    let result = SIMD3(homogeneous.x, homogeneous.y, homogeneous.z) / homogeneous.w
    return result.x.isFinite && result.y.isFinite && result.z.isFinite ? result : nil
  }

  private static func transformedPoint(
    _ point: SIMD3<Float>,
    by transform: simd_float4x4
  ) -> SIMD3<Float> {
    let homogeneous = transform * SIMD4(point, 1)
    guard abs(homogeneous.w) > 0.000_001 else {
      return SIMD3(homogeneous.x, homogeneous.y, homogeneous.z)
    }
    return SIMD3(homogeneous.x, homogeneous.y, homogeneous.z) / homogeneous.w
  }

  private static func intersectionDistance(
    rayOrigin: SIMD3<Float>,
    rayDirection: SIMD3<Float>,
    v0: SIMD3<Float>,
    v1: SIMD3<Float>,
    v2: SIMD3<Float>
  ) -> Float? {
    let edge1 = v1 - v0
    let edge2 = v2 - v0
    let perpendicular = simd_cross(rayDirection, edge2)
    let determinant = simd_dot(edge1, perpendicular)
    guard abs(determinant) > 0.000_000_1 else { return nil }
    let inverseDeterminant = 1 / determinant
    let originOffset = rayOrigin - v0
    let u = inverseDeterminant * simd_dot(originOffset, perpendicular)
    guard u >= 0, u <= 1 else { return nil }
    let cross = simd_cross(originOffset, edge1)
    let v = inverseDeterminant * simd_dot(rayDirection, cross)
    guard v >= 0, u + v <= 1 else { return nil }
    let distance = inverseDeterminant * simd_dot(edge2, cross)
    return distance > 0.000_001 ? distance : nil
  }
}

enum CADMetalBoxPicker {
  static func partIDs(
    in selection: CGRect,
    viewportSize: CGSize,
    geometry: CADRenderGeometry,
    viewProjection: simd_float4x4,
    hiddenPartIDs: Set<Int>,
    partTransforms: [CADPartTransformPresentation],
    crossing: Bool
  ) -> Set<Int> {
    guard selection.width > 1, selection.height > 1,
      viewportSize.width > 0, viewportSize.height > 0
    else { return [] }
    let transforms = Dictionary(
      uniqueKeysWithValues: partTransforms.map { (UInt32(clamping: $0.partID), $0.matrix) })
    var boundsByPart: [Int: CGRect] = [:]
    for index in geometry.positions.indices where index < geometry.partIDs.count {
      let rawPartID = geometry.partIDs[index]
      let partID = Int(rawPartID)
      guard partID > 0, !hiddenPartIDs.contains(partID) else { continue }
      let model = transforms[rawPartID] ?? matrix_identity_float4x4
      let clip = viewProjection * model * SIMD4(geometry.positions[index], 1)
      guard abs(clip.w) > 0.000_001 else { continue }
      let ndc = SIMD3(clip.x, clip.y, clip.z) / clip.w
      guard ndc.x.isFinite, ndc.y.isFinite, ndc.z >= 0, ndc.z <= 1 else { continue }
      let point = CGPoint(
        x: (CGFloat(ndc.x) + 1) * 0.5 * viewportSize.width,
        y: (CGFloat(ndc.y) + 1) * 0.5 * viewportSize.height)
      if let existing = boundsByPart[partID] {
        boundsByPart[partID] = existing.union(CGRect(origin: point, size: .zero))
      } else {
        boundsByPart[partID] = CGRect(origin: point, size: .zero)
      }
    }
    return Set(
      boundsByPart.compactMap { partID, bounds in
        let matches =
          crossing
          ? selection.intersects(bounds.insetBy(dx: -1, dy: -1))
          : selection.contains(bounds.insetBy(dx: -0.5, dy: -0.5))
        return matches ? partID : nil
      })
  }
}

public struct CADMetalViewport: View {
  public let document: CADGeometryDocument?
  @Bindable public var camera: CADCameraState
  public let theme: CADViewportTheme
  public let navigation: CADViewportNavigationConfiguration
  public let isSelected: Bool
  public let hiddenPartIDs: Set<Int>
  public let selectedPartIDs: Set<Int>
  public let groundedPartIDs: Set<Int>
  public let referenceGeometry: CADWorkspaceReferenceGeometry
  public let partTransforms: [CADPartTransformPresentation]
  public let partAppearances: [CADPartAppearancePresentation]
  public let selectedPartOrigin: CADPartOriginPresentation?
  public let mateConnectorPickingEnabled: Bool
  public let onFrame: @MainActor @Sendable () -> Void
  public let onError: @MainActor @Sendable (String) -> Void
  public let onPick: @MainActor @Sendable (Int, Bool) -> Void
  public let onBoxPick: @MainActor @Sendable (Set<Int>, Bool) -> Void
  public let onContextMenu: @MainActor @Sendable (Int?, CGPoint, CGSize) -> Void
  public let onPickFeature: @MainActor @Sendable (CADViewportFeaturePick?) -> Void
  public let onBeginDirectPartDrag: @MainActor @Sendable (Int) -> Bool
  public let onUpdateDirectPartDrag: @MainActor @Sendable (CGSize, CGSize) -> Void
  public let onEndDirectPartDrag: @MainActor @Sendable () -> Void

  @State private var hoveredFeature: CADViewportFeaturePick?
  @State private var lockedFeature: CADViewportFeaturePick?
  @State private var selectedFeatures: [CADViewportFeaturePick] = []

  public init(
    document: CADGeometryDocument?,
    camera: CADCameraState,
    theme: CADViewportTheme,
    navigation: CADViewportNavigationConfiguration = .onshape,
    isSelected: Bool = false,
    hiddenPartIDs: Set<Int> = [],
    selectedPartIDs: Set<Int> = [],
    groundedPartIDs: Set<Int> = [],
    referenceGeometry: CADWorkspaceReferenceGeometry = .init(
      visibility: .init(), modelDiagonalMeters: 1),
    partTransforms: [CADPartTransformPresentation] = [],
    partAppearances: [CADPartAppearancePresentation] = [],
    selectedPartOrigin: CADPartOriginPresentation? = nil,
    mateConnectorPickingEnabled: Bool = false,
    onFrame: @escaping @MainActor @Sendable () -> Void = {},
    onError: @escaping @MainActor @Sendable (String) -> Void = { _ in },
    onPick: @escaping @MainActor @Sendable (Int, Bool) -> Void = { _, _ in },
    onBoxPick: @escaping @MainActor @Sendable (Set<Int>, Bool) -> Void = { _, _ in },
    onContextMenu:
      @escaping @MainActor @Sendable (Int?, CGPoint, CGSize) -> Void = { _, _, _ in },
    onPickFeature:
      @escaping @MainActor @Sendable (CADViewportFeaturePick?) -> Void = { _ in },
    onBeginDirectPartDrag: @escaping @MainActor @Sendable (Int) -> Bool = { _ in false },
    onUpdateDirectPartDrag:
      @escaping @MainActor @Sendable (CGSize, CGSize) -> Void = { _, _ in },
    onEndDirectPartDrag: @escaping @MainActor @Sendable () -> Void = {}
  ) {
    self.document = document
    self.camera = camera
    self.theme = theme
    self.navigation = navigation
    self.isSelected = isSelected
    self.hiddenPartIDs = hiddenPartIDs
    self.selectedPartIDs = selectedPartIDs
    self.groundedPartIDs = groundedPartIDs
    self.referenceGeometry = referenceGeometry
    self.partTransforms = partTransforms
    self.partAppearances = partAppearances
    self.selectedPartOrigin = selectedPartOrigin
    self.mateConnectorPickingEnabled = mateConnectorPickingEnabled
    self.onFrame = onFrame
    self.onError = onError
    self.onPick = onPick
    self.onBoxPick = onBoxPick
    self.onContextMenu = onContextMenu
    self.onPickFeature = onPickFeature
    self.onBeginDirectPartDrag = onBeginDirectPartDrag
    self.onUpdateDirectPartDrag = onUpdateDirectPartDrag
    self.onEndDirectPartDrag = onEndDirectPartDrag
  }

  public var body: some View {
    ZStack {
      MetalCanvas(
        document: document, camera: camera, theme: theme,
        isSelected: isSelected, hiddenPartIDs: hiddenPartIDs, selectedPartIDs: selectedPartIDs,
        groundedPartIDs: groundedPartIDs,
        referenceGeometry: referenceGeometry,
        partTransforms: partTransforms,
        partAppearances: partAppearances,
        selectedPartOrigin: selectedPartOrigin,
        connectorMarkers: liveConnectorMarkers,
        onFrame: onFrame, onError: onError)
      CADMouseInputOverlay(
        navigation: navigation,
        orbit: camera.orbit,
        pan: camera.pan,
        roll: camera.roll,
        zoom: camera.zoom,
        frameAll: {
          guard let document else { return }
          camera.frame(bounds: document.renderGeometry.bounds)
        },
        select: { point, viewportSize, extendsSelection in
          guard let document else {
            onPick(0, extendsSelection)
            return
          }
          let viewProjection = CADViewportProjection.viewProjection(
            cameraPosition: camera.position,
            cameraTarget: camera.target,
            cameraUp: camera.upVector,
            cameraDistance: camera.distance,
            modelDiagonalMeters: document.renderGeometry.bounds.diagonal,
            aspect: Float(max(viewportSize.width, 1) / max(viewportSize.height, 1)))
          if mateConnectorPickingEnabled {
            let feature =
              lockedFeature
              ?? CADMetalFeaturePicker.feature(
                at: point, viewportSize: viewportSize, document: document,
                viewProjection: viewProjection, hiddenPartIDs: hiddenPartIDs,
                partTransforms: partTransforms)
            if let feature {
              if let existing = selectedFeatures.firstIndex(where: {
                $0.partID == feature.partID
              }) {
                selectedFeatures[existing] = feature
              } else {
                selectedFeatures.append(feature)
              }
              if selectedFeatures.count > 2 {
                selectedFeatures.removeFirst(selectedFeatures.count - 2)
              }
            }
            onPickFeature(feature)
          } else {
            let partID = pickedPartID(
              at: point,
              viewportSize: viewportSize,
              document: document,
              viewProjection: viewProjection)
            onPick(partID ?? 0, extendsSelection)
          }
        },
        boxSelect: { selection, viewportSize, crossing, extendsSelection in
          guard !mateConnectorPickingEnabled, let document else { return }
          let viewProjection = viewProjection(for: document, viewportSize: viewportSize)
          onBoxPick(
            CADMetalBoxPicker.partIDs(
              in: selection,
              viewportSize: viewportSize,
              geometry: document.renderGeometry,
              viewProjection: viewProjection,
              hiddenPartIDs: hiddenPartIDs,
              partTransforms: partTransforms,
              crossing: crossing),
            extendsSelection)
        },
        contextMenu: { point, viewportSize in
          guard let document else {
            onContextMenu(nil, point, viewportSize)
            return
          }
          onContextMenu(
            pickedPartID(
              at: point,
              viewportSize: viewportSize,
              document: document,
              viewProjection: viewProjection(for: document, viewportSize: viewportSize)),
            point,
            viewportSize)
        },
        hover: { point, viewportSize, locksFeature in
          guard mateConnectorPickingEnabled, let document, let point else {
            hoveredFeature = nil
            lockedFeature = nil
            return
          }
          let viewProjection = CADViewportProjection.viewProjection(
            cameraPosition: camera.position,
            cameraTarget: camera.target,
            cameraUp: camera.upVector,
            cameraDistance: camera.distance,
            modelDiagonalMeters: document.renderGeometry.bounds.diagonal,
            aspect: Float(max(viewportSize.width, 1) / max(viewportSize.height, 1)))
          let inferred = CADMetalFeaturePicker.feature(
            at: point, viewportSize: viewportSize, document: document,
            viewProjection: viewProjection, hiddenPartIDs: hiddenPartIDs,
            partTransforms: partTransforms)
          if locksFeature {
            if lockedFeature == nil { lockedFeature = inferred }
            hoveredFeature = lockedFeature
          } else {
            lockedFeature = nil
            hoveredFeature = inferred
          }
        },
        beginDirectManipulation: { point, viewportSize in
          guard !mateConnectorPickingEnabled, let document else { return false }
          let viewProjection = viewProjection(for: document, viewportSize: viewportSize)
          guard
            let partID = pickedPartID(
              at: point,
              viewportSize: viewportSize,
              document: document,
              viewProjection: viewProjection)
          else { return false }
          return onBeginDirectPartDrag(partID)
        },
        updateDirectManipulation: onUpdateDirectPartDrag,
        endDirectManipulation: onEndDirectPartDrag)

      if mateConnectorPickingEnabled {
        GeometryReader { geometry in
          ForEach(Array(selectedFeatures.enumerated()), id: \.offset) { _, feature in
            CADMateFeatureMarker(feature: feature, isSelected: true)
              .position(
                x: feature.screenPoint.x * geometry.size.width,
                y: feature.screenPoint.y * geometry.size.height)
          }
          if let hoveredFeature {
            CADMateFeatureMarker(feature: hoveredFeature, isSelected: false)
              .position(
                x: hoveredFeature.screenPoint.x * geometry.size.width,
                y: hoveredFeature.screenPoint.y * geometry.size.height)
          }
        }
        .allowsHitTesting(false)
      }
    }
    .onChange(of: mateConnectorPickingEnabled) { _, enabled in
      if !enabled {
        hoveredFeature = nil
        lockedFeature = nil
        selectedFeatures.removeAll()
      }
    }
  }

  /// The selected and hovered mate features as real in-scene triads.
  private var liveConnectorMarkers: [CADConnectorMarker] {
    guard mateConnectorPickingEnabled else { return [] }
    var markers = selectedFeatures.map { feature in
      CADConnectorMarker(
        partID: feature.partID,
        origin: SIMD3<Float>(feature.positionMeters),
        xAxis: SIMD3<Float>(feature.secondaryAxis),
        zAxis: SIMD3<Float>(feature.primaryAxis),
        isSelected: true)
    }
    if let hoveredFeature {
      markers.append(
        CADConnectorMarker(
          partID: hoveredFeature.partID,
          origin: SIMD3<Float>(hoveredFeature.positionMeters),
          xAxis: SIMD3<Float>(hoveredFeature.secondaryAxis),
          zAxis: SIMD3<Float>(hoveredFeature.primaryAxis),
          isSelected: false))
    }
    return markers
  }

  private func viewProjection(
    for document: CADGeometryDocument,
    viewportSize: CGSize
  ) -> simd_float4x4 {
    CADViewportProjection.viewProjection(
      cameraPosition: camera.position,
      cameraTarget: camera.target,
      cameraUp: camera.upVector,
      cameraDistance: camera.distance,
      modelDiagonalMeters: document.renderGeometry.bounds.diagonal,
      aspect: Float(max(viewportSize.width, 1) / max(viewportSize.height, 1)))
  }

  private func pickedPartID(
    at point: CGPoint,
    viewportSize: CGSize,
    document: CADGeometryDocument,
    viewProjection: simd_float4x4
  ) -> Int? {
    CADMetalPartPicker.partID(
      at: point,
      viewportSize: viewportSize,
      geometry: document.renderGeometry,
      viewProjection: viewProjection,
      hiddenPartIDs: hiddenPartIDs,
      partTransforms: partTransforms)
  }
}

private struct CADMateFeatureMarker: View {
  let feature: CADViewportFeaturePick
  let isSelected: Bool

  private var title: String {
    switch feature.kind {
    case .face: "Face center"
    case .edge: "Edge midpoint"
    case .vertex: "Vertex"
    case .axis: "Cylindrical axis"
    }
  }

  var body: some View {
    VStack(spacing: 4) {
      // The triad itself is real world-space geometry drawn by the
      // renderer; this overlay carries only the ring and the label.
      ZStack {
        Circle()
          .fill((isSelected ? Color.purple : Color.orange).opacity(0.18))
          .frame(width: 25, height: 25)
        Circle()
          .stroke(isSelected ? Color.purple : Color.orange, lineWidth: 2)
          .frame(width: 13, height: 13)
      }
      .frame(width: 38, height: 38)
      Text(title)
        .font(.system(size: 9, weight: .semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: Capsule())
    }
  }
}

/// A mate-connector frame drawn as real world-space triad geometry. The
/// origin/axes are part-local; the renderer applies the part's transform so
/// the triad stays glued to its component through drags and camera moves.
struct CADConnectorMarker: Equatable {
  var partID: Int
  var origin: SIMD3<Float>
  var xAxis: SIMD3<Float>
  var zAxis: SIMD3<Float>
  var isSelected: Bool
}

private struct MetalCanvas: NSViewRepresentable {
  let document: CADGeometryDocument?
  let camera: CADCameraState
  let theme: CADViewportTheme
  let isSelected: Bool
  let hiddenPartIDs: Set<Int>
  let selectedPartIDs: Set<Int>
  let groundedPartIDs: Set<Int>
  let referenceGeometry: CADWorkspaceReferenceGeometry
  let partTransforms: [CADPartTransformPresentation]
  let partAppearances: [CADPartAppearancePresentation]
  let selectedPartOrigin: CADPartOriginPresentation?
  let connectorMarkers: [CADConnectorMarker]
  let onFrame: @MainActor @Sendable () -> Void
  let onError: @MainActor @Sendable (String) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onFrame: onFrame, onError: onError) }

  func makeNSView(context: Context) -> MTKView {
    let view = MTKView()
    view.device = MTLCreateSystemDefaultDevice()
    view.colorPixelFormat = CADMetalLightingModel.colorPixelFormat
    view.depthStencilPixelFormat = .depth32Float
    if view.device?.supportsTextureSampleCount(4) == true {
      view.sampleCount = 4
    }
    // The authoring contract targets a stable display-synchronized 60 Hz.
    // Asking for 120 Hz doubled shadow/edge work without improving a 60 Hz
    // display and made the viewport less responsive on dense assemblies.
    view.preferredFramesPerSecond = CADMetalRendererPolicy.preferredFramesPerSecond
    view.enableSetNeedsDisplay = false
    view.isPaused = false
    context.coordinator.attach(view)
    update(view, coordinator: context.coordinator)
    return view
  }

  func updateNSView(_ view: MTKView, context: Context) {
    update(view, coordinator: context.coordinator)
  }

  private func update(_ view: MTKView, coordinator: Coordinator) {
    view.clearColor = theme.clearColor
    coordinator.renderer?.camera = camera
    coordinator.renderer?.theme = theme
    coordinator.renderer?.isSelected = isSelected
    coordinator.renderer?.set(document: document)
    coordinator.renderer?.setPartState(
      hidden: hiddenPartIDs, selected: selectedPartIDs, grounded: groundedPartIDs)
    coordinator.renderer?.set(referenceGeometry: referenceGeometry)
    coordinator.renderer?.set(partTransforms: partTransforms)
    coordinator.renderer?.set(partAppearances: partAppearances)
    coordinator.renderer?.set(selectedPartOrigin: selectedPartOrigin)
    coordinator.renderer?.set(connectorMarkers: connectorMarkers)
  }

  @MainActor final class Coordinator {
    var renderer: MetalRenderer?
    let onFrame: @MainActor @Sendable () -> Void
    let onError: @MainActor @Sendable (String) -> Void

    init(
      onFrame: @escaping @MainActor @Sendable () -> Void,
      onError: @escaping @MainActor @Sendable (String) -> Void
    ) {
      self.onFrame = onFrame
      self.onError = onError
    }

    func attach(_ view: MTKView) {
      guard let device = view.device else { return }
      do {
        let renderer = try MetalRenderer(
          device: device,
          sampleCount: view.sampleCount,
          onFrame: onFrame)
        self.renderer = renderer
        view.delegate = renderer
      } catch {
        onError(error.localizedDescription)
      }
    }
  }
}

private final class MetalRenderer: NSObject, MTKViewDelegate, @unchecked Sendable {
  struct Vertex {
    var position: MTLPackedFloat3
    var normal: MTLPackedFloat3
    var color: SIMD4<UInt8>
    var partID: UInt32
    var faceID: UInt32

    init(
      position: SIMD3<Float>, normal: SIMD3<Float>, color: SIMD4<UInt8>,
      partID: UInt32, faceID: UInt32
    ) {
      var p = MTLPackedFloat3()
      p.x = position.x
      p.y = position.y
      p.z = position.z
      var n = MTLPackedFloat3()
      n.x = normal.x
      n.y = normal.y
      n.z = normal.z
      self.position = p
      self.normal = n
      self.color = color
      self.partID = partID
      self.faceID = faceID
    }
  }

  struct Uniforms {
    var viewProjection: simd_float4x4
    var lightViewProjection: simd_float4x4
    var cameraPosition: SIMD4<Float>
    var keyDirection: SIMD4<Float>
    var keyColor: SIMD4<Float>
    var fillDirection: SIMD4<Float>
    var fillColor: SIMD4<Float>
    var rimDirection: SIMD4<Float>
    var rimColor: SIMD4<Float>
    var material: SIMD4<Float>
    var edgeColor: SIMD4<Float>
    var selectionColor: SIMD4<Float>
    var overrideColor: SIMD4<Float>
    /// ambient strength, shadow strength, shadow bias, shadow-map size
    var lighting: SIMD4<Float>
    var floorColor: SIMD4<Float>
  }

  /// Two-stop vertical background gradient, delivered by `setFragmentBytes`.
  struct BackgroundGradient {
    var top: SIMD4<Float>
    var bottom: SIMD4<Float>
  }

  struct EdgePresentation {
    var viewportSize: SIMD2<Float>
    var offsetPixels: Float
    var opacity: Float
  }

  struct ShadowUniforms {
    var lightViewProjection: simd_float4x4
  }

  struct PartAppearance {
    var color: SIMD4<Float>
    /// roughness, metallic, reserved, hasOverride
    var material: SIMD4<Float>
  }

  struct ReferenceVertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
  }

  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  let pipeline: MTLRenderPipelineState
  let edgePipeline: MTLRenderPipelineState
  let referencePipeline: MTLRenderPipelineState
  let shadowPipeline: MTLRenderPipelineState
  let backgroundPipeline: MTLRenderPipelineState
  let floorPipeline: MTLRenderPipelineState
  let depthState: MTLDepthStencilState
  let edgeDepthState: MTLDepthStencilState
  let shadowDepthState: MTLDepthStencilState
  let backgroundDepthState: MTLDepthStencilState
  let shadowTexture: MTLTexture
  let shadowSampler: MTLSamplerState
  let onFrame: @MainActor @Sendable () -> Void
  let uniformBuffer: MTLBuffer
  var camera: CADCameraState
  var theme = CADViewportTheme.defaultTheme {
    didSet {
      if oldValue.key.directionFrom != theme.key.directionFrom
        || (oldValue.shadowStrength > 0.02) != (theme.shadowStrength > 0.02)
      {
        shadowNeedsUpdate = true
      }
    }
  }
  var isSelected = false
  private var vertexBuffer: MTLBuffer?
  private var indexBuffer: MTLBuffer?
  private var edgeVertexBuffer: MTLBuffer?
  private var partTransformBuffer: MTLBuffer?
  private var partTransforms: [CADPartTransformPresentation] = []
  private var partStateBuffer: MTLBuffer?
  private var partAppearanceBuffer: MTLBuffer?
  private var partAppearances: [CADPartAppearancePresentation] = []
  private var hiddenPartIDs: Set<Int> = []
  private var selectedPartIDs: Set<Int> = []
  private var groundedPartIDs: Set<Int> = []
  private var referenceBuffers: [CADReferenceGeometry: MTLBuffer] = [:]
  private var referenceVertexCounts: [CADReferenceGeometry: Int] = [:]
  private var floorGridBuffer: MTLBuffer?
  private var floorGridVertexCount = 0
  private var floorPlaneBuffer: MTLBuffer?
  private var floorPlaneVertexCount = 0
  private var connectorMarkers: [CADConnectorMarker] = []
  private var connectorMarkerBuffer: MTLBuffer?
  private var connectorMarkerVertexCount = 0
  /// While transforms stream (drag), the shadow pass waits for this host
  /// time so the depth pre-pass does not re-render the assembly per tick.
  private var shadowSettleHostTime: CFTimeInterval = 0
  private var selectedPartOriginBuffer: MTLBuffer?
  private var selectedPartOriginVertexCount = 0
  private var selectedPartOrigin: CADPartOriginPresentation?
  private var referenceGeometry = CADWorkspaceReferenceGeometry(
    visibility: .init(), modelDiagonalMeters: 1)
  private var partSlotCount = 0
  private var indexCount = 0
  private var edgeVertexCount = 0
  private var documentIdentity: UUID?
  private var geometryDiagonal: Float = 1
  private var geometryCenter = SIMD3<Float>.zero
  private let uniformStride: Int
  private var uniformFrameIndex = 0
  private var shadowNeedsUpdate = true
  private let inFlightSemaphore = DispatchSemaphore(value: 3)

  @MainActor
  init(
    device: MTLDevice,
    sampleCount: Int,
    onFrame: @escaping @MainActor @Sendable () -> Void
  ) throws {
    self.device = device
    self.onFrame = onFrame
    camera = CADCameraState()
    guard let queue = device.makeCommandQueue() else { throw MetalRendererError.noQueue }
    commandQueue = queue
    uniformStride = (MemoryLayout<Uniforms>.stride + 255) & ~255
    guard
      let uniformBuffer = device.makeBuffer(length: uniformStride * 3, options: .storageModeShared)
    else { throw MetalRendererError.noBuffer }
    self.uniformBuffer = uniformBuffer
    let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "cadVertex")
    descriptor.fragmentFunction = library.makeFunction(name: "cadFragment")
    descriptor.colorAttachments[0].pixelFormat = CADMetalLightingModel.colorPixelFormat
    descriptor.depthAttachmentPixelFormat = .depth32Float
    descriptor.rasterSampleCount = sampleCount
    descriptor.colorAttachments[0].isBlendingEnabled = true
    descriptor.colorAttachments[0].rgbBlendOperation = .add
    descriptor.colorAttachments[0].alphaBlendOperation = .add
    descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    let edgeDescriptor = MTLRenderPipelineDescriptor()
    edgeDescriptor.vertexFunction = library.makeFunction(name: "cadEdgeVertex")
    edgeDescriptor.fragmentFunction = library.makeFunction(name: "cadEdgeFragment")
    edgeDescriptor.colorAttachments[0].pixelFormat = CADMetalLightingModel.colorPixelFormat
    edgeDescriptor.depthAttachmentPixelFormat = .depth32Float
    edgeDescriptor.rasterSampleCount = sampleCount
    edgeDescriptor.colorAttachments[0].isBlendingEnabled = true
    edgeDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    edgeDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    edgeDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    edgeDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    edgePipeline = try device.makeRenderPipelineState(descriptor: edgeDescriptor)
    let referenceDescriptor = MTLRenderPipelineDescriptor()
    referenceDescriptor.vertexFunction = library.makeFunction(name: "referenceVertex")
    referenceDescriptor.fragmentFunction = library.makeFunction(name: "referenceFragment")
    referenceDescriptor.colorAttachments[0].pixelFormat = CADMetalLightingModel.colorPixelFormat
    referenceDescriptor.depthAttachmentPixelFormat = .depth32Float
    referenceDescriptor.rasterSampleCount = sampleCount
    referenceDescriptor.colorAttachments[0].isBlendingEnabled = true
    referenceDescriptor.colorAttachments[0].rgbBlendOperation = .add
    referenceDescriptor.colorAttachments[0].alphaBlendOperation = .add
    referenceDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    referenceDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
    referenceDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    referenceDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    referencePipeline = try device.makeRenderPipelineState(descriptor: referenceDescriptor)
    let shadowDescriptor = MTLRenderPipelineDescriptor()
    shadowDescriptor.vertexFunction = library.makeFunction(name: "cadShadowVertex")
    shadowDescriptor.depthAttachmentPixelFormat = .depth32Float
    shadowPipeline = try device.makeRenderPipelineState(descriptor: shadowDescriptor)
    let backgroundDescriptor = MTLRenderPipelineDescriptor()
    backgroundDescriptor.vertexFunction = library.makeFunction(name: "backgroundVertex")
    backgroundDescriptor.fragmentFunction = library.makeFunction(name: "backgroundFragment")
    backgroundDescriptor.colorAttachments[0].pixelFormat = CADMetalLightingModel.colorPixelFormat
    backgroundDescriptor.depthAttachmentPixelFormat = .depth32Float
    backgroundDescriptor.rasterSampleCount = sampleCount
    backgroundPipeline = try device.makeRenderPipelineState(descriptor: backgroundDescriptor)
    let floorDescriptor = MTLRenderPipelineDescriptor()
    floorDescriptor.vertexFunction = library.makeFunction(name: "floorVertex")
    floorDescriptor.fragmentFunction = library.makeFunction(name: "floorFragment")
    floorDescriptor.colorAttachments[0].pixelFormat = CADMetalLightingModel.colorPixelFormat
    floorDescriptor.depthAttachmentPixelFormat = .depth32Float
    floorDescriptor.rasterSampleCount = sampleCount
    floorPipeline = try device.makeRenderPipelineState(descriptor: floorDescriptor)
    let depth = MTLDepthStencilDescriptor()
    depth.depthCompareFunction = .less
    depth.isDepthWriteEnabled = true
    guard let depthState = device.makeDepthStencilState(descriptor: depth) else {
      throw MetalRendererError.noDepthState
    }
    self.depthState = depthState
    let edgeDepth = MTLDepthStencilDescriptor()
    edgeDepth.depthCompareFunction = .lessEqual
    edgeDepth.isDepthWriteEnabled = false
    guard let edgeDepthState = device.makeDepthStencilState(descriptor: edgeDepth) else {
      throw MetalRendererError.noDepthState
    }
    self.edgeDepthState = edgeDepthState
    let shadowDepth = MTLDepthStencilDescriptor()
    shadowDepth.depthCompareFunction = .less
    shadowDepth.isDepthWriteEnabled = true
    guard let shadowDepthState = device.makeDepthStencilState(descriptor: shadowDepth) else {
      throw MetalRendererError.noDepthState
    }
    self.shadowDepthState = shadowDepthState
    let backgroundDepth = MTLDepthStencilDescriptor()
    backgroundDepth.depthCompareFunction = .always
    backgroundDepth.isDepthWriteEnabled = false
    guard let backgroundDepthState = device.makeDepthStencilState(descriptor: backgroundDepth)
    else { throw MetalRendererError.noDepthState }
    self.backgroundDepthState = backgroundDepthState

    let shadowTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .depth32Float,
      width: 2_048,
      height: 2_048,
      mipmapped: false)
    shadowTextureDescriptor.storageMode = .private
    shadowTextureDescriptor.usage = [.renderTarget, .shaderRead]
    guard let shadowTexture = device.makeTexture(descriptor: shadowTextureDescriptor) else {
      throw MetalRendererError.noBuffer
    }
    shadowTexture.label = "CAD soft-shadow depth"
    self.shadowTexture = shadowTexture

    let shadowSamplerDescriptor = MTLSamplerDescriptor()
    shadowSamplerDescriptor.minFilter = .linear
    shadowSamplerDescriptor.magFilter = .linear
    shadowSamplerDescriptor.sAddressMode = .clampToEdge
    shadowSamplerDescriptor.tAddressMode = .clampToEdge
    shadowSamplerDescriptor.compareFunction = .lessEqual
    guard let shadowSampler = device.makeSamplerState(descriptor: shadowSamplerDescriptor) else {
      throw MetalRendererError.noBuffer
    }
    self.shadowSampler = shadowSampler
  }

  func set(document: CADGeometryDocument?) {
    guard document?.identity != documentIdentity else { return }
    documentIdentity = document?.identity
    shadowNeedsUpdate = true
    guard let document else {
      vertexBuffer = nil
      indexBuffer = nil
      edgeVertexBuffer = nil
      partTransformBuffer = nil
      partStateBuffer = nil
      partAppearanceBuffer = nil
      referenceBuffers.removeAll()
      referenceVertexCounts.removeAll()
      floorGridBuffer = nil
      floorGridVertexCount = 0
      selectedPartOriginBuffer = nil
      selectedPartOriginVertexCount = 0
      partSlotCount = 0
      indexCount = 0
      edgeVertexCount = 0
      geometryCenter = .zero
      return
    }
    let geometry = document.renderGeometry
    let vertices = geometry.positions.indices.map {
      Vertex(
        position: geometry.positions[$0], normal: geometry.normals[$0],
        color: geometry.colors[$0], partID: geometry.partIDs[$0], faceID: geometry.faceIDs[$0])
    }
    vertexBuffer = makePrivateBuffer(vertices)
    indexBuffer = makePrivateBuffer(geometry.indices)
    indexCount = geometry.indices.count
    geometryDiagonal = max(geometry.bounds.diagonal, 0.001)
    geometryCenter = geometry.bounds.center
    partSlotCount = max(document.nodes.count + 1, 1)
    partTransformBuffer = device.makeBuffer(
      length: partSlotCount * MemoryLayout<simd_float4x4>.stride,
      options: .storageModeShared)
    writePartTransforms()
    // Shared (CPU-writable) so per-part hide/select updates without a rebuild.
    // Default all-zero = every part visible and unselected.
    partStateBuffer = device.makeBuffer(
      length: partSlotCount * MemoryLayout<UInt32>.stride, options: .storageModeShared)
    partAppearanceBuffer = device.makeBuffer(
      length: partSlotCount * MemoryLayout<PartAppearance>.stride, options: .storageModeShared)
    writePartAppearances()
    edgeVertexBuffer = makePrivateBuffer(
      geometry.edgePositions.indices.map {
        Vertex(
          position: geometry.edgePositions[$0], normal: .zero,
          color: SIMD4<UInt8>(repeating: 255),
          partID: geometry.edgePartIDs[$0], faceID: .max)
      })
    edgeVertexCount = geometry.edgePositions.count
    rebuildReferenceBuffers()
    rebuildSelectedPartOriginBuffer()
  }

  /// Update per-part hide/select flags (CAD partIDs = assemblyNode + 1). Writes
  /// the shared buffer in place; no geometry rebuild. ponytail: single shared
  /// buffer (not triple-buffered) — a rare write/read overlap costs one stale
  /// frame, acceptable for click-driven state.
  func setPartState(hidden: Set<Int>, selected: Set<Int>, grounded: Set<Int>) {
    guard
      hidden != hiddenPartIDs
        || selected != selectedPartIDs
        || grounded != groundedPartIDs
    else { return }
    if hidden != hiddenPartIDs {
      shadowNeedsUpdate = true
    }
    hiddenPartIDs = hidden
    selectedPartIDs = selected
    groundedPartIDs = grounded
    guard let partStateBuffer, partSlotCount > 0 else { return }
    let pointer = partStateBuffer.contents().bindMemory(to: UInt32.self, capacity: partSlotCount)
    for slot in 0..<partSlotCount {
      var flags: UInt32 = 0
      if hidden.contains(slot) { flags |= 1 }
      if selected.contains(slot) { flags |= 2 }
      if grounded.contains(slot) { flags |= 4 }
      pointer[slot] = flags
    }
  }

  func set(partTransforms: [CADPartTransformPresentation]) {
    guard self.partTransforms != partTransforms else { return }
    self.partTransforms = partTransforms
    // Shadows settle after the interaction: re-rendering the 2048px shadow
    // depth pass for the full assembly on every drag tick collapsed the
    // frame rate, and a briefly stale contact shadow is imperceptible.
    shadowNeedsUpdate = true
    shadowSettleHostTime = CACurrentMediaTime() + 0.15
    writePartTransforms()
  }

  func set(partAppearances: [CADPartAppearancePresentation]) {
    guard self.partAppearances != partAppearances else { return }
    self.partAppearances = partAppearances
    writePartAppearances()
  }

  /// Mate-connector frames are REAL world-space geometry, not screen decals:
  /// triad lines built in the part's local frame and carried by its transform
  /// so they track drags, camera moves, and zoom exactly like the model.
  func set(connectorMarkers: [CADConnectorMarker]) {
    guard self.connectorMarkers != connectorMarkers else { return }
    self.connectorMarkers = connectorMarkers
    rebuildConnectorMarkerBuffer()
  }

  private func rebuildConnectorMarkerBuffer() {
    guard !connectorMarkers.isEmpty else {
      connectorMarkerBuffer = nil
      connectorMarkerVertexCount = 0
      return
    }
    let axisLength = max(geometryDiagonal, 0.001) * 0.045
    let transformsByPartID = Dictionary(
      uniqueKeysWithValues: partTransforms.map { ($0.partID, $0.matrix) })
    var vertices: [ReferenceVertex] = []
    for marker in connectorMarkers {
      let transform = transformsByPartID[marker.partID] ?? matrix_identity_float4x4
      func world(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let p = transform * SIMD4(v, 1)
        return SIMD3(p.x, p.y, p.z)
      }
      func rotated(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let p = transform * SIMD4(v, 0)
        return SIMD3(p.x, p.y, p.z)
      }
      let origin = world(marker.origin)
      var z = rotated(marker.zAxis)
      if simd_length_squared(z) < 0.000_001 { z = SIMD3(0, 0, 1) }
      z = simd_normalize(z)
      var x = rotated(marker.xAxis)
      x -= z * simd_dot(x, z)
      if simd_length_squared(x) < 0.000_001 {
        x = abs(z.y) < 0.9 ? simd_cross(SIMD3(0, 1, 0), z) : simd_cross(SIMD3(1, 0, 0), z)
      }
      x = simd_normalize(x)
      let y = simd_cross(z, x)
      let emphasis: Float = marker.isSelected ? 1.3 : 1
      appendReferenceLine(
        from: origin, to: origin + x * axisLength * emphasis,
        color: SIMD4(0.95, 0.26, 0.21, 1), into: &vertices)
      appendReferenceLine(
        from: origin, to: origin + y * axisLength * emphasis,
        color: SIMD4(0.30, 0.85, 0.39, 1), into: &vertices)
      appendReferenceLine(
        from: origin, to: origin + z * axisLength * 1.4 * emphasis,
        color: SIMD4(0.25, 0.55, 1.0, 1), into: &vertices)
    }
    connectorMarkerBuffer = makePrivateBuffer(vertices)
    connectorMarkerVertexCount = vertices.count
  }

  private func writePartAppearances() {
    guard let partAppearanceBuffer, partSlotCount > 0 else { return }
    let pointer = partAppearanceBuffer.contents().bindMemory(
      to: PartAppearance.self, capacity: partSlotCount)
    for slot in 0..<partSlotCount {
      pointer[slot] = PartAppearance(color: .zero, material: .zero)
    }
    for appearance in partAppearances
    where appearance.partID >= 0 && appearance.partID < partSlotCount {
      pointer[appearance.partID] = PartAppearance(
        color: appearance.color,
        material: SIMD4(appearance.roughness, appearance.metallic, 0, 1))
    }
  }

  private func writePartTransforms() {
    guard let partTransformBuffer, partSlotCount > 0 else { return }
    let pointer = partTransformBuffer.contents().bindMemory(
      to: simd_float4x4.self, capacity: partSlotCount)
    for slot in 0..<partSlotCount {
      pointer[slot] = matrix_identity_float4x4
    }
    for presentation in partTransforms
    where presentation.partID >= 0 && presentation.partID < partSlotCount {
      pointer[presentation.partID] = presentation.matrix
    }
  }

  func set(referenceGeometry: CADWorkspaceReferenceGeometry) {
    guard self.referenceGeometry != referenceGeometry else { return }
    self.referenceGeometry = referenceGeometry
    rebuildReferenceBuffers()
  }

  func set(selectedPartOrigin: CADPartOriginPresentation?) {
    guard self.selectedPartOrigin != selectedPartOrigin else { return }
    self.selectedPartOrigin = selectedPartOrigin
    rebuildSelectedPartOriginBuffer()
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let pass = view.currentRenderPassDescriptor,
      let commandBuffer = commandQueue.makeCommandBuffer()
    else { return }
    inFlightSemaphore.wait()
    commandBuffer.addCompletedHandler { [inFlightSemaphore, onFrame] _ in
      inFlightSemaphore.signal()
      Task { @MainActor in onFrame() }
    }

    let lightViewProjection = shadowViewProjection()
    if shadowNeedsUpdate,
      CACurrentMediaTime() >= shadowSettleHostTime,
      theme.shadowStrength > 0.02,
      let vertexBuffer,
      let indexBuffer,
      let partTransformBuffer,
      let partStateBuffer,
      indexCount > 0
    {
      let shadowPass = MTLRenderPassDescriptor()
      shadowPass.depthAttachment.texture = shadowTexture
      shadowPass.depthAttachment.loadAction = .clear
      shadowPass.depthAttachment.storeAction = .store
      shadowPass.depthAttachment.clearDepth = 1
      if let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowPass) {
        var shadowUniforms = ShadowUniforms(lightViewProjection: lightViewProjection)
        shadowEncoder.label = "CAD soft contact shadows"
        shadowEncoder.setRenderPipelineState(shadowPipeline)
        shadowEncoder.setDepthStencilState(shadowDepthState)
        shadowEncoder.setDepthBias(0.0008, slopeScale: 1.5, clamp: 0.01)
        shadowEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        shadowEncoder.setVertexBytes(
          &shadowUniforms, length: MemoryLayout<ShadowUniforms>.stride, index: 1)
        shadowEncoder.setVertexBuffer(partTransformBuffer, offset: 0, index: 2)
        shadowEncoder.setVertexBuffer(partStateBuffer, offset: 0, index: 3)
        shadowEncoder.drawIndexedPrimitives(
          type: .triangle,
          indexCount: indexCount,
          indexType: .uint32,
          indexBuffer: indexBuffer,
          indexBufferOffset: 0)
        shadowEncoder.endEncoding()
        shadowNeedsUpdate = false
      }
    }

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
      inFlightSemaphore.signal()
      return
    }
    if let bottom = theme.backgroundBottom {
      var gradient = BackgroundGradient(
        top: SIMD4(theme.background, 1), bottom: SIMD4(bottom, 1))
      encoder.setRenderPipelineState(backgroundPipeline)
      encoder.setDepthStencilState(backgroundDepthState)
      encoder.setFragmentBytes(
        &gradient, length: MemoryLayout<BackgroundGradient>.stride, index: 0)
      encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
    if let vertexBuffer, let indexBuffer, let partTransformBuffer, let partStateBuffer,
      let partAppearanceBuffer, indexCount > 0
    {
      let aspect = Float(max(view.drawableSize.width, 1) / max(view.drawableSize.height, 1))
      var uniforms = Uniforms(
        viewProjection: CADViewportProjection.viewProjection(
          cameraPosition: camera.position,
          cameraTarget: camera.target,
          cameraUp: camera.upVector,
          cameraDistance: camera.distance,
          modelDiagonalMeters: geometryDiagonal,
          aspect: aspect),
        lightViewProjection: lightViewProjection,
        cameraPosition: SIMD4(camera.position, 1),
        keyDirection: lightDirection(theme.key), keyColor: SIMD4(theme.key.color, 1),
        fillDirection: lightDirection(theme.fill), fillColor: SIMD4(theme.fill.color, 1),
        rimDirection: lightDirection(theme.rim), rimColor: SIMD4(theme.rim.color, 1),
        material: SIMD4(
          theme.roughness, theme.metallic, isSelected ? 1 : 0, theme.overrideColor == nil ? 0 : 1),
        edgeColor: SIMD4(isSelected ? theme.edgeSelectionColor : theme.edgeColor, 1),
        selectionColor: SIMD4(theme.selectionColor, 1),
        overrideColor: theme.overrideColor ?? .zero,
        lighting: SIMD4(
          theme.ambientStrength,
          theme.shadowStrength,
          0.0007,
          Float(shadowTexture.width)),
        floorColor: SIMD4(theme.floorColor, 1))
      let uniformOffset = uniformFrameIndex * uniformStride
      withUnsafeBytes(of: &uniforms) {
        uniformBuffer.contents().advanced(by: uniformOffset).copyMemory(
          from: $0.baseAddress!, byteCount: $0.count)
      }
      uniformFrameIndex = (uniformFrameIndex + 1) % 3
      encoder.setRenderPipelineState(pipeline)
      encoder.setDepthStencilState(depthState)
      encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
      encoder.setVertexBuffer(uniformBuffer, offset: uniformOffset, index: 1)
      encoder.setVertexBuffer(partTransformBuffer, offset: 0, index: 2)
      encoder.setVertexBuffer(partStateBuffer, offset: 0, index: 3)
      encoder.setVertexBuffer(partAppearanceBuffer, offset: 0, index: 4)
      // `cadFragment`/`cadEdgeFragment` read Uniforms at buffer(1) in the
      // FRAGMENT stage too (lighting, shadow, selection). Without this bind the
      // fragment stage reads undefined memory: lighting intermittently arrives
      // as zeros (solid-black parts) and Metal API validation aborts the app.
      encoder.setFragmentBuffer(uniformBuffer, offset: uniformOffset, index: 1)
      encoder.setFragmentTexture(shadowTexture, index: 0)
      encoder.setFragmentSamplerState(shadowSampler, index: 0)
      encoder.drawIndexedPrimitives(
        type: .triangle, indexCount: indexCount, indexType: .uint32,
        indexBuffer: indexBuffer, indexBufferOffset: 0)
      if referenceGeometry.showsSolidFloor, let floorPlaneBuffer, floorPlaneVertexCount > 0 {
        // Uniforms stay bound at vertex/fragment buffer(1); the shadow map and
        // sampler stay at fragment texture/sampler 0 from the pass above.
        encoder.setRenderPipelineState(floorPipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBuffer(floorPlaneBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(
          type: .triangle, vertexStart: 0, vertexCount: floorPlaneVertexCount)
      }
      if let edgeVertexBuffer, edgeVertexCount > 0, theme.edgeStrength > 0.02 {
        encoder.setRenderPipelineState(edgePipeline)
        encoder.setDepthStencilState(edgeDepthState)
        encoder.setDepthBias(-1, slopeScale: -1, clamp: 0)
        encoder.setVertexBuffer(edgeVertexBuffer, offset: 0, index: 0)
        for offset in CADMetalEdgeStyle.offsetsPixels(strength: theme.edgeStrength) {
          var edgePresentation = EdgePresentation(
            viewportSize: SIMD2(
              Float(max(view.drawableSize.width, 1)),
              Float(max(view.drawableSize.height, 1))),
            offsetPixels: offset,
            opacity: CADMetalEdgeStyle.opacity(strength: theme.edgeStrength))
          encoder.setVertexBytes(
            &edgePresentation,
            length: MemoryLayout<EdgePresentation>.stride,
            index: 5)
          encoder.setFragmentBytes(
            &edgePresentation,
            length: MemoryLayout<EdgePresentation>.stride,
            index: 5)
          encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgeVertexCount)
        }
      }
      encoder.setRenderPipelineState(referencePipeline)
      encoder.setDepthStencilState(edgeDepthState)
      encoder.setDepthBias(0, slopeScale: 0, clamp: 0)
      encoder.setVertexBuffer(uniformBuffer, offset: uniformOffset, index: 1)
      if referenceGeometry.showsFloorGrid,
        let floorGridBuffer,
        floorGridVertexCount > 0
      {
        encoder.setVertexBuffer(floorGridBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(
          type: .line, vertexStart: 0, vertexCount: floorGridVertexCount)
      }
      for geometry in CADReferenceGeometry.allCases
      where referenceGeometry.visibility.contains(geometry) {
        guard let buffer = referenceBuffers[geometry],
          let count = referenceVertexCounts[geometry],
          count > 0
        else { continue }
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: count)
      }
      if let selectedPartOriginBuffer, selectedPartOriginVertexCount > 0 {
        encoder.setVertexBuffer(selectedPartOriginBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(
          type: .line, vertexStart: 0, vertexCount: selectedPartOriginVertexCount)
      }
      if let connectorMarkerBuffer, connectorMarkerVertexCount > 0 {
        encoder.setVertexBuffer(connectorMarkerBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(
          type: .line, vertexStart: 0, vertexCount: connectorMarkerVertexCount)
      }
    }
    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  private func makePrivateBuffer<Element>(_ values: [Element]) -> MTLBuffer? {
    values.withUnsafeBytes { bytes in
      guard let base = bytes.baseAddress, !bytes.isEmpty else { return nil }
      guard
        let staging = device.makeBuffer(
          bytes: base, length: bytes.count, options: .storageModeShared),
        let destination = device.makeBuffer(length: bytes.count, options: .storageModePrivate),
        let commandBuffer = commandQueue.makeCommandBuffer(),
        let blit = commandBuffer.makeBlitCommandEncoder()
      else {
        return device.makeBuffer(bytes: base, length: bytes.count, options: .storageModeShared)
      }
      blit.copy(
        from: staging, sourceOffset: 0, to: destination, destinationOffset: 0, size: bytes.count)
      blit.endEncoding()
      commandBuffer.commit()
      return destination
    }
  }

  private func rebuildReferenceBuffers() {
    guard documentIdentity != nil else {
      referenceBuffers.removeAll()
      referenceVertexCounts.removeAll()
      floorGridBuffer = nil
      floorGridVertexCount = 0
      return
    }
    var buffers: [CADReferenceGeometry: MTLBuffer] = [:]
    var counts: [CADReferenceGeometry: Int] = [:]
    for geometry in CADReferenceGeometry.allCases {
      let vertices = referenceVertices(for: geometry)
      if let buffer = makePrivateBuffer(vertices) {
        buffers[geometry] = buffer
        counts[geometry] = vertices.count
      }
    }
    referenceBuffers = buffers
    referenceVertexCounts = counts
    let gridVertices = floorGridVertices()
    floorGridBuffer = makePrivateBuffer(gridVertices)
    floorGridVertexCount = gridVertices.count
    let planeVertices = floorPlaneVertices()
    floorPlaneBuffer = makePrivateBuffer(planeVertices)
    floorPlaneVertexCount = planeVertices.count
  }

  /// Two triangles at Y=0 covering the same extent as the floor grid. Color
  /// is unused — `floorFragment` shades from the theme's floor color and the
  /// shared shadow map, so a theme change needs no buffer rebuild.
  private func floorPlaneVertices() -> [ReferenceVertex] {
    let halfExtent = max(
      referenceGeometry.floorGridExtentMeters * 0.5,
      referenceGeometry.floorGridSpacingMeters)
    let corners = [
      SIMD3<Float>(-halfExtent, 0, -halfExtent),
      SIMD3<Float>(halfExtent, 0, -halfExtent),
      SIMD3<Float>(halfExtent, 0, halfExtent),
      SIMD3<Float>(-halfExtent, 0, halfExtent),
    ]
    let unused = SIMD4<Float>(0, 0, 0, 1)
    return [0, 1, 2, 0, 2, 3].map {
      ReferenceVertex(position: SIMD4(corners[$0], 1), color: unused)
    }
  }

  private func rebuildSelectedPartOriginBuffer() {
    guard documentIdentity != nil, let selectedPartOrigin else {
      selectedPartOriginBuffer = nil
      selectedPartOriginVertexCount = 0
      return
    }
    let transform = selectedPartOrigin.matrix
    let length = selectedPartOrigin.axisLengthMeters
    let origin = transform * SIMD4<Float>(0, 0, 0, 1)
    let axes: [(SIMD4<Float>, SIMD4<Float>)] = [
      (transform * SIMD4<Float>(length, 0, 0, 1), SIMD4(1, 0.22, 0.24, 1)),
      (transform * SIMD4<Float>(0, length, 0, 1), SIMD4(0.2, 1, 0.36, 1)),
      (transform * SIMD4<Float>(0, 0, length, 1), SIMD4(0.2, 0.52, 1, 1)),
    ]
    let vertices = axes.flatMap { endpoint, color in
      [
        ReferenceVertex(position: origin, color: color),
        ReferenceVertex(position: endpoint, color: color),
      ]
    }
    selectedPartOriginBuffer = makePrivateBuffer(vertices)
    selectedPartOriginVertexCount = vertices.count
  }

  private func referenceVertices(for geometry: CADReferenceGeometry) -> [ReferenceVertex] {
    let red = SIMD4<Float>(0.95, 0.24, 0.28, 1)
    let green = SIMD4<Float>(0.22, 0.80, 0.38, 1)
    let blue = SIMD4<Float>(0.24, 0.50, 1, 1)
    if geometry == .origin {
      let length = referenceGeometry.axisLengthMeters
      return [
        ReferenceVertex(position: SIMD4(0, 0, 0, 1), color: red),
        ReferenceVertex(position: SIMD4(length, 0, 0, 1), color: red),
        ReferenceVertex(position: SIMD4(0, 0, 0, 1), color: green),
        ReferenceVertex(position: SIMD4(0, length, 0, 1), color: green),
        ReferenceVertex(position: SIMD4(0, 0, 0, 1), color: blue),
        ReferenceVertex(position: SIMD4(0, 0, length, 1), color: blue),
      ]
    }

    let basis: (SIMD3<Float>, SIMD3<Float>, SIMD4<Float>) =
      switch geometry {
      case .frontPlane: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), blue)
      case .topPlane: (SIMD3(1, 0, 0), SIMD3(0, 0, 1), green)
      case .rightPlane: (SIMD3(0, 1, 0), SIMD3(0, 0, 1), red)
      case .origin: fatalError("Origin handled above")
      }
    let half = referenceGeometry.planeSizeMeters * 0.5
    let divisions = referenceGeometry.gridDivisions
    let color = SIMD4(basis.2.x, basis.2.y, basis.2.z, 0.24)
    var vertices: [ReferenceVertex] = []
    vertices.reserveCapacity((divisions + 1) * 4)
    for index in 0...divisions {
      let coordinate = -half + (Float(index) / Float(divisions)) * half * 2
      appendReferenceLine(
        from: basis.0 * coordinate - basis.1 * half,
        to: basis.0 * coordinate + basis.1 * half,
        color: color,
        into: &vertices)
      appendReferenceLine(
        from: basis.1 * coordinate - basis.0 * half,
        to: basis.1 * coordinate + basis.0 * half,
        color: color,
        into: &vertices)
    }
    return vertices
  }

  /// A world-space XZ floor grid shared with the RealityKit preview and
  /// Three.js/WebGPU presentation. It is deliberately separate from the
  /// semantic Top Plane: the floor is a display aid, while Top Plane is a
  /// selectable assembly reference frame.
  private func floorGridVertices() -> [ReferenceVertex] {
    let requestedSpacing = max(referenceGeometry.floorGridSpacingMeters, 0.000_1)
    let halfExtent = max(referenceGeometry.floorGridExtentMeters * 0.5, requestedSpacing)
    let requestedLines = Int(ceil(halfExtent / requestedSpacing))
    let lineCount = min(max(requestedLines, 1), 240)
    let spacing = halfExtent / Float(lineCount)
    let majorInterval = max(referenceGeometry.floorGridMajorLineInterval, 2)
    let opacity = referenceGeometry.floorGridOpacity
    let minor = SIMD4<Float>(0.47, 0.53, 0.60, opacity * 0.52)
    let major = SIMD4<Float>(0.36, 0.43, 0.51, opacity)
    let xAxis = SIMD4<Float>(0.95, 0.24, 0.28, min(opacity * 1.35, 0.95))
    let zAxis = SIMD4<Float>(0.24, 0.50, 1, min(opacity * 1.35, 0.95))
    var vertices: [ReferenceVertex] = []
    vertices.reserveCapacity((lineCount * 2 + 1) * 4)
    for index in -lineCount...lineCount {
      let coordinate = Float(index) * spacing
      let isMajor = index.isMultiple(of: majorInterval)
      appendReferenceLine(
        from: SIMD3(-halfExtent, 0, coordinate),
        to: SIMD3(halfExtent, 0, coordinate),
        color: index == 0 ? xAxis : (isMajor ? major : minor),
        into: &vertices)
      appendReferenceLine(
        from: SIMD3(coordinate, 0, -halfExtent),
        to: SIMD3(coordinate, 0, halfExtent),
        color: index == 0 ? zAxis : (isMajor ? major : minor),
        into: &vertices)
    }
    return vertices
  }

  private func appendReferenceLine(
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    color: SIMD4<Float>,
    into vertices: inout [ReferenceVertex]
  ) {
    vertices.append(ReferenceVertex(position: SIMD4(start, 1), color: color))
    vertices.append(ReferenceVertex(position: SIMD4(end, 1), color: color))
  }

  private func lightDirection(_ light: CADViewportTheme.Light) -> SIMD4<Float> {
    SIMD4(simd_normalize(light.directionFrom), light.intensity / 4_000)
  }

  private func shadowViewProjection() -> simd_float4x4 {
    let direction =
      simd_length_squared(theme.key.directionFrom) > 0.000_001
      ? simd_normalize(theme.key.directionFrom)
      : SIMD3<Float>(0.35, 1, 0.65)
    let radius = max(geometryDiagonal * 0.72, 0.001)
    let eye = geometryCenter + direction * radius * 3
    let preferredUp =
      abs(simd_dot(direction, SIMD3<Float>(0, 1, 0))) > 0.96
      ? SIMD3<Float>(1, 0, 0)
      : SIMD3<Float>(0, 1, 0)
    return Self.orthographic(
      left: -radius,
      right: radius,
      bottom: -radius,
      top: radius,
      near: max(radius * 0.05, 0.000_01),
      far: radius * 7)
      * Self.lookAt(eye: eye, center: geometryCenter, up: preferredUp)
  }

  private static func lookAt(
    eye: SIMD3<Float>,
    center: SIMD3<Float>,
    up: SIMD3<Float>
  ) -> simd_float4x4 {
    let z = simd_normalize(eye - center)
    let x = simd_normalize(simd_cross(up, z))
    let y = simd_cross(z, x)
    return simd_float4x4(
      SIMD4(x.x, y.x, z.x, 0),
      SIMD4(x.y, y.y, z.y, 0),
      SIMD4(x.z, y.z, z.z, 0),
      SIMD4(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1))
  }

  private static func orthographic(
    left: Float,
    right: Float,
    bottom: Float,
    top: Float,
    near: Float,
    far: Float
  ) -> simd_float4x4 {
    simd_float4x4(
      SIMD4(2 / (right - left), 0, 0, 0),
      SIMD4(0, 2 / (top - bottom), 0, 0),
      SIMD4(0, 0, 1 / (near - far), 0),
      SIMD4(
        -(right + left) / (right - left),
        -(top + bottom) / (top - bottom),
        near / (near - far),
        1))
  }

  private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct Vertex { packed_float3 position; packed_float3 normal; uchar4 color; uint partID; uint faceID; };
    struct Uniforms { float4x4 viewProjection; float4x4 lightViewProjection;
      float4 cameraPosition; float4 keyDirection;
      float4 keyColor; float4 fillDirection; float4 fillColor; float4 rimDirection; float4 rimColor;
      float4 material; float4 edgeColor; float4 selectionColor; float4 overrideColor;
      float4 lighting; float4 floorColor; };
    struct EdgePresentation { float2 viewportSize; float offsetPixels; float opacity; };
    struct ShadowUniforms { float4x4 lightViewProjection; };
    struct PartAppearance { float4 color; float4 material; };
    struct Varying { float4 position [[position]]; float3 normal; float3 world; float4 color;
      float4 partColor; float4 partMaterial; float selected; float grounded; };
    // Per-part state, indexed by partID: bit 0 = hidden, bit 1 = selected, bit 2 = grounded.
    vertex Varying cadVertex(uint id [[vertex_id]], device const Vertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]], device const float4x4 *partTransforms [[buffer(2)]], device const uint *partState [[buffer(3)]], device const PartAppearance *partAppearances [[buffer(4)]]) {
      Vertex v = vertices[id]; float4x4 transform = partTransforms[v.partID];
      uint state = partState[v.partID]; PartAppearance appearance = partAppearances[v.partID];
      Varying o;
      if (state & 1u) { o.position = float4(2.0, 2.0, 2.0, 1.0); o.normal = float3(0); o.world = float3(0); o.color = float4(0); o.partColor = float4(0); o.partMaterial = float4(0); o.selected = 0.0; o.grounded = 0.0; return o; }
      float4 world = transform * float4(float3(v.position), 1.0);
      float3x3 normalTransform = float3x3(transform[0].xyz, transform[1].xyz, transform[2].xyz);
      o.world = world.xyz; o.position = u.viewProjection * world;
      o.normal = normalize(normalTransform * float3(v.normal)); o.color = float4(v.color) / 255.0;
      o.partColor = appearance.color; o.partMaterial = appearance.material;
      o.selected = (state & 2u) ? 1.0 : 0.0; o.grounded = (state & 4u) ? 1.0 : 0.0; return o;
    }
    struct ShadowVarying { float4 position [[position]]; };
    vertex ShadowVarying cadShadowVertex(
      uint id [[vertex_id]],
      device const Vertex *vertices [[buffer(0)]],
      constant ShadowUniforms &u [[buffer(1)]],
      device const float4x4 *partTransforms [[buffer(2)]],
      device const uint *partState [[buffer(3)]]
    ) {
      Vertex v = vertices[id];
      ShadowVarying o;
      if (partState[v.partID] & 1u) {
        o.position = float4(2.0, 2.0, 2.0, 1.0);
        return o;
      }
      o.position = u.lightViewProjection * partTransforms[v.partID] * float4(float3(v.position), 1);
      return o;
    }
    vertex Varying cadEdgeVertex(
      uint id [[vertex_id]],
      device const Vertex *vertices [[buffer(0)]],
      constant Uniforms &u [[buffer(1)]],
      device const float4x4 *partTransforms [[buffer(2)]],
      device const uint *partState [[buffer(3)]],
      device const PartAppearance *partAppearances [[buffer(4)]],
      constant EdgePresentation &edge [[buffer(5)]]
    ) {
      Vertex v = vertices[id];
      Vertex pair = vertices[id ^ 1u];
      float4x4 transform = partTransforms[v.partID];
      uint state = partState[v.partID];
      PartAppearance appearance = partAppearances[v.partID];
      Varying o;
      if (state & 1u) {
        o.position = float4(2.0, 2.0, 2.0, 1.0);
        o.normal = float3(0); o.world = float3(0); o.color = float4(0);
        o.partColor = float4(0); o.partMaterial = float4(0);
        o.selected = 0; o.grounded = 0; return o;
      }
      float4 world = transform * float4(float3(v.position), 1);
      float4 pairWorld = transform * float4(float3(pair.position), 1);
      float4 clip = u.viewProjection * world;
      float4 pairClip = u.viewProjection * pairWorld;
      float2 viewport = max(edge.viewportSize, float2(1));
      float2 a = clip.xy / max(abs(clip.w), 0.000001);
      float2 b = pairClip.xy / max(abs(pairClip.w), 0.000001);
      float2 direction = (b - a) * viewport;
      float directionLength = length(direction);
      float2 perpendicular = directionLength > 0.0001
        ? float2(-direction.y, direction.x) / directionLength
        : float2(0, 1);
      clip.xy += perpendicular * edge.offsetPixels * 2.0 / viewport * clip.w;
      o.position = clip; o.world = world.xyz; o.normal = float3(0);
      o.color = float4(v.color) / 255.0; o.partColor = appearance.color;
      o.partMaterial = appearance.material;
      o.selected = (state & 2u) ? 1.0 : 0.0;
      o.grounded = (state & 4u) ? 1.0 : 0.0;
      return o;
    }
    fragment float4 cadFragment(
      Varying in [[stage_in]],
      constant Uniforms &u [[buffer(1)]],
      depth2d<float> shadowMap [[texture(0)]],
      sampler shadowSampler [[sampler(0)]]
    ) {
      float3 view = normalize(u.cameraPosition.xyz - in.world);
      float normalLengthSquared = dot(in.normal, in.normal);
      float3 n = normalLengthSquared > 0.000001 ? normalize(in.normal) : view;
      n = faceforward(n, -view, n);
      float key = max(dot(n, normalize(u.keyDirection.xyz)), 0.0) * u.keyDirection.w;
      float fill = max(dot(n, normalize(u.fillDirection.xyz)), 0.0) * u.fillDirection.w;
      float rim = pow(1.0 - max(dot(n, view), 0.0), 3.0) * u.rimDirection.w;
      float4 shadowClip = u.lightViewProjection * float4(in.world, 1);
      float3 shadowNDC = shadowClip.xyz / max(abs(shadowClip.w), 0.000001);
      float2 shadowUV = float2(shadowNDC.x * 0.5 + 0.5, 0.5 - shadowNDC.y * 0.5);
      float shadowVisibility = 1.0;
      if (all(shadowUV >= 0.0) && all(shadowUV <= 1.0) && shadowNDC.z >= 0.0 && shadowNDC.z <= 1.0) {
        float texel = 1.0 / max(u.lighting.w, 1.0);
        shadowVisibility = 0.0;
        for (int y = -1; y <= 1; ++y) {
          for (int x = -1; x <= 1; ++x) {
            shadowVisibility += shadowMap.sample_compare(
              shadowSampler,
              shadowUV + float2(x, y) * texel,
              shadowNDC.z - u.lighting.z);
          }
        }
        shadowVisibility /= 9.0;
      }
      float shadow = mix(1.0, shadowVisibility, clamp(u.lighting.y, 0.0, 1.0));
      float hemisphere = mix(0.42, 1.28, clamp(n.y * 0.5 + 0.5, 0.0, 1.0));
      float3 lighting = float3(u.lighting.x * hemisphere)
        + u.keyColor.rgb * key * shadow
        + u.fillColor.rgb * fill * 0.48;
      float hasPartAppearance = in.partMaterial.w;
      float roughness = mix(u.material.x, in.partMaterial.x, hasPartAppearance);
      float metallic = mix(u.material.y, in.partMaterial.y, hasPartAppearance);
      float3 halfVector = normalize(normalize(u.keyDirection.xyz) + view);
      float highlight = pow(max(dot(n, halfVector), 0.0), mix(96.0, 8.0, clamp(roughness, 0.0, 1.0))) * (0.12 + (1.0-roughness)*0.42);
      float4 themeSource = u.material.w > 0.5 ? u.overrideColor : in.color;
      float4 source = mix(themeSource, in.partColor, hasPartAppearance);
      float sel = max(u.material.z, in.selected);
      float3 base = source.rgb;
      // CAD editors must keep a source-black dielectric readable. This is a
      // small light-driven reflectance floor, not emissive fill: it vanishes
      // when ambient/key/fill/rim are all zero.
      float sourceLuminance = dot(source.rgb, float3(0.2126, 0.7152, 0.0722));
      float lightingEnergy = clamp(
        u.lighting.x + key * shadow + fill * 0.48 + rim * 0.22,
        0.0,
        1.0);
      float darkness = 1.0 - smoothstep(0.0, 0.08, sourceLuminance);
      float darkMaterialLift = darkness * lightingEnergy * 0.055;
      base = max(base, float3(darkMaterialLift));
      base = mix(base, float3(0.20, 0.62, 0.94), in.grounded * 0.36);
      float3 specular = mix(float3(1.0), source.rgb, clamp(metallic, 0.0, 1.0));
      // The highlight belongs to the key light. Keeping it independent made a
      // supposedly disabled lighting rig continue to illuminate the model.
      float keyHighlight = min(key * shadow, 1.0);
      float3 shaded = base * lighting
        + specular * highlight * keyHighlight
        + u.rimColor.rgb * rim * 0.22;
      shaded = mix(shaded, u.selectionColor.rgb, sel * 0.76);
      return float4(shaded, source.a);
    }
    fragment float4 cadEdgeFragment(
      Varying in [[stage_in]],
      constant Uniforms &u [[buffer(1)]],
      constant EdgePresentation &edge [[buffer(5)]]
    ) {
      float4 color = mix(u.edgeColor, u.selectionColor, in.selected);
      color.a *= edge.opacity;
      return color;
    }
    struct ReferenceVertex { float4 position; float4 color; };
    struct ReferenceVarying { float4 position [[position]]; float4 color; };
    vertex ReferenceVarying referenceVertex(uint id [[vertex_id]], device const ReferenceVertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
      ReferenceVarying o; ReferenceVertex v = vertices[id];
      o.position = u.viewProjection * v.position; o.color = v.color; return o;
    }
    fragment float4 referenceFragment(ReferenceVarying in [[stage_in]]) { return in.color; }
    struct BackgroundGradient { float4 top; float4 bottom; };
    struct BackgroundVarying { float4 position [[position]]; float t; };
    vertex BackgroundVarying backgroundVertex(uint id [[vertex_id]]) {
      // Fullscreen triangle; t = 0 at the top of the viewport, 1 at the bottom.
      float2 corners[3] = { float2(-1, 3), float2(-1, -1), float2(3, -1) };
      BackgroundVarying o;
      o.position = float4(corners[id], 1.0, 1.0);
      o.t = 1.0 - (corners[id].y * 0.5 + 0.5);
      return o;
    }
    fragment float4 backgroundFragment(
      BackgroundVarying in [[stage_in]],
      constant BackgroundGradient &gradient [[buffer(0)]]
    ) {
      return mix(gradient.top, gradient.bottom, clamp(in.t, 0.0, 1.0));
    }
    vertex ReferenceVarying floorVertex(
      uint id [[vertex_id]],
      device const ReferenceVertex *vertices [[buffer(0)]],
      constant Uniforms &u [[buffer(1)]]
    ) {
      ReferenceVarying o; ReferenceVertex v = vertices[id];
      o.position = u.viewProjection * v.position;
      o.color = v.position; // world position, for shadow projection
      return o;
    }
    fragment float4 floorFragment(
      ReferenceVarying in [[stage_in]],
      constant Uniforms &u [[buffer(1)]],
      depth2d<float> shadowMap [[texture(0)]],
      sampler shadowSampler [[sampler(0)]]
    ) {
      float3 world = in.color.xyz;
      float4 shadowClip = u.lightViewProjection * float4(world, 1);
      float3 shadowNDC = shadowClip.xyz / max(abs(shadowClip.w), 0.000001);
      float2 shadowUV = float2(shadowNDC.x * 0.5 + 0.5, 0.5 - shadowNDC.y * 0.5);
      float shadowVisibility = 1.0;
      if (all(shadowUV >= 0.0) && all(shadowUV <= 1.0) && shadowNDC.z >= 0.0 && shadowNDC.z <= 1.0) {
        float texel = 1.0 / max(u.lighting.w, 1.0);
        shadowVisibility = 0.0;
        for (int y = -1; y <= 1; ++y) {
          for (int x = -1; x <= 1; ++x) {
            shadowVisibility += shadowMap.sample_compare(
              shadowSampler,
              shadowUV + float2(x, y) * texel,
              shadowNDC.z - u.lighting.z);
          }
        }
        shadowVisibility /= 9.0;
      }
      float shadow = mix(1.0, shadowVisibility, clamp(u.lighting.y, 0.0, 1.0));
      // Upward-facing matte plane: ceiling-hemisphere ambient plus key diffuse.
      float key = max(u.keyDirection.y, 0.0) * u.keyDirection.w;
      float3 lighting = float3(u.lighting.x * 1.28) + u.keyColor.rgb * key * shadow;
      return float4(u.floorColor.rgb * lighting, 1.0);
    }
    """
}

extension CADViewportTheme {
  fileprivate var clearColor: MTLClearColor {
    MTLClearColor(
      red: Double(background.x), green: Double(background.y), blue: Double(background.z), alpha: 1)
  }
}

private enum MetalRendererError: LocalizedError {
  case noQueue, noDepthState, noBuffer
  var errorDescription: String? {
    "The Metal CAD renderer could not allocate required GPU resources."
  }
}
