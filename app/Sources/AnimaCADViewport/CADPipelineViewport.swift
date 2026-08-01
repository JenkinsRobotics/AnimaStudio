import AnimaCAD
import SwiftUI
import simd

public enum CADReferenceGeometry: String, CaseIterable, Codable, Hashable, Sendable {
  case origin
  case frontPlane
  case topPlane
  case rightPlane
}

/// View-only visibility for the fixed assembly frame. This never enters
/// `.character.anima`; it is presentation state shared by every CAD renderer.
public struct CADReferenceGeometryVisibility: Codable, Equatable, Sendable {
  public var showsOrigin: Bool
  public var showsFrontPlane: Bool
  public var showsTopPlane: Bool
  public var showsRightPlane: Bool

  public init(
    showsOrigin: Bool = true,
    showsFrontPlane: Bool = true,
    showsTopPlane: Bool = true,
    showsRightPlane: Bool = true
  ) {
    self.showsOrigin = showsOrigin
    self.showsFrontPlane = showsFrontPlane
    self.showsTopPlane = showsTopPlane
    self.showsRightPlane = showsRightPlane
  }

  public func contains(_ geometry: CADReferenceGeometry) -> Bool {
    switch geometry {
    case .origin: showsOrigin
    case .frontPlane: showsFrontPlane
    case .topPlane: showsTopPlane
    case .rightPlane: showsRightPlane
    }
  }

  public mutating func toggle(_ geometry: CADReferenceGeometry) {
    switch geometry {
    case .origin: showsOrigin.toggle()
    case .frontPlane: showsFrontPlane.toggle()
    case .topPlane: showsTopPlane.toggle()
    case .rightPlane: showsRightPlane.toggle()
    }
  }
}

/// The renderer-neutral draw presentation for the assembly origin and planes.
/// Scale is resolved once from the merged CAD bounds and handed unchanged to
/// Metal and WebGPU.
public struct CADWorkspaceReferenceGeometry: Codable, Equatable, Sendable {
  public let visibility: CADReferenceGeometryVisibility
  public let planeSizeMeters: Float
  public let axisLengthMeters: Float
  public let gridDivisions: Int
  public let showsFloorGrid: Bool
  /// Solid Unreal-style ground plane at Y=0 (independent of the grid so the
  /// panel's None / Grid / Floor / Grid+Floor modes map onto the two bools).
  public let showsSolidFloor: Bool
  public let floorGridSpacingMeters: Float
  public let floorGridExtentMeters: Float
  public let floorGridMajorLineInterval: Int
  public let floorGridOpacity: Float

  public init(
    visibility: CADReferenceGeometryVisibility,
    modelDiagonalMeters: Float,
    gridDivisions: Int = 10,
    showsFloorGrid: Bool = true,
    showsSolidFloor: Bool = false,
    floorGridSpacingMeters: Float = 0.1,
    floorGridExtentMultiplier: Float = 4,
    floorGridMajorLineInterval: Int = 5,
    floorGridOpacity: Float = 0.24
  ) {
    let workingDiagonal = max(modelDiagonalMeters, 0.001)
    let spacing = min(max(floorGridSpacingMeters, 0.000_1), 100)
    let majorInterval = min(max(floorGridMajorLineInterval, 2), 20)
    self.visibility = visibility
    planeSizeMeters = workingDiagonal * 1.25
    axisLengthMeters = workingDiagonal * 0.35
    self.gridDivisions = max(gridDivisions, 2)
    self.showsFloorGrid = showsFloorGrid
    self.showsSolidFloor = showsSolidFloor
    self.floorGridSpacingMeters = spacing
    floorGridExtentMeters = max(
      workingDiagonal * min(max(floorGridExtentMultiplier, 1.5), 20),
      spacing * Float(majorInterval) * 2
    )
    self.floorGridMajorLineInterval = majorInterval
    self.floorGridOpacity = min(max(floorGridOpacity, 0.02), 0.9)
  }
}

/// AnimaCore's renderer-neutral part-in-assembly rest transform. The matrix
/// convention matches `Transform.from_euler_xyz`: R = Rx · Ry · Rz, followed
/// by translation. It is presentation input only; AnimaCore remains the owner
/// of the authored values and mate semantics.
public struct CADPartRestTransform: Codable, Equatable, Sendable {
  public var positionMeters: [Double]
  public var rotationEulerRadians: [Double]

  public init(
    positionMeters: [Double] = [0, 0, 0],
    rotationEulerRadians: [Double] = [0, 0, 0]
  ) {
    self.positionMeters = positionMeters.count == 3 ? positionMeters : [0, 0, 0]
    self.rotationEulerRadians =
      rotationEulerRadians.count == 3 ? rotationEulerRadians : [0, 0, 0]
  }

  public init(matrix: simd_float4x4) {
    positionMeters = [
      Double(matrix.columns.3.x),
      Double(matrix.columns.3.y),
      Double(matrix.columns.3.z),
    ]
    let sineY = min(max(Double(matrix.columns.2.x), -1), 1)
    let y = asin(sineY)
    let cosineY = cos(y)
    let x: Double
    let z: Double
    if abs(cosineY) > 1e-7 {
      x = atan2(
        -Double(matrix.columns.2.y),
        Double(matrix.columns.2.z))
      z = atan2(
        -Double(matrix.columns.1.x),
        Double(matrix.columns.0.x))
    } else {
      x = atan2(
        Double(matrix.columns.1.z),
        Double(matrix.columns.1.y))
      z = 0
    }
    rotationEulerRadians = [x, y, z]
  }

  public var matrix: simd_float4x4 {
    let rx = Float(rotationEulerRadians[0])
    let ry = Float(rotationEulerRadians[1])
    let rz = Float(rotationEulerRadians[2])
    let cx = cos(rx)
    let sx = sin(rx)
    let cy = cos(ry)
    let sy = sin(ry)
    let cz = cos(rz)
    let sz = sin(rz)
    let rotationX = simd_float4x4(
      SIMD4(1, 0, 0, 0),
      SIMD4(0, cx, sx, 0),
      SIMD4(0, -sx, cx, 0),
      SIMD4(0, 0, 0, 1))
    let rotationY = simd_float4x4(
      SIMD4(cy, 0, -sy, 0),
      SIMD4(0, 1, 0, 0),
      SIMD4(sy, 0, cy, 0),
      SIMD4(0, 0, 0, 1))
    let rotationZ = simd_float4x4(
      SIMD4(cz, sz, 0, 0),
      SIMD4(-sz, cz, 0, 0),
      SIMD4(0, 0, 1, 0),
      SIMD4(0, 0, 0, 1))
    var result = rotationX * rotationY * rotationZ
    result.columns.3 = SIMD4(
      Float(positionMeters[0]), Float(positionMeters[1]), Float(positionMeters[2]), 1)
    return result
  }

  public func translated(localAxis: CADTransformAxis, distanceMeters: Double)
    -> CADPartRestTransform
  {
    let column = matrix[localAxis.matrixColumn]
    let direction = simd_normalize(
      SIMD3<Double>(Double(column.x), Double(column.y), Double(column.z)))
    var result = self
    result.positionMeters[0] += direction.x * distanceMeters
    result.positionMeters[1] += direction.y * distanceMeters
    result.positionMeters[2] += direction.z * distanceMeters
    return result
  }

  public func rotated(localAxis: CADTransformAxis, angleRadians: Double)
    -> CADPartRestTransform
  {
    var localRotation = [0.0, 0.0, 0.0]
    localRotation[localAxis.rawIndex] = angleRadians
    let delta = CADPartRestTransform(rotationEulerRadians: localRotation).matrix
    return CADPartRestTransform(matrix: matrix * delta)
  }

  public func applyingAssemblyDelta(_ delta: simd_float4x4) -> CADPartRestTransform {
    CADPartRestTransform(matrix: delta * matrix)
  }
}

struct CADPartLocalBounds: Equatable, Sendable {
  var minimum: SIMD3<Float>
  var maximum: SIMD3<Float>

  var corners: [SIMD3<Float>] {
    [
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
}

/// Keeps the transform manipulator centered on the geometry the operator
/// actually selected. Local bounds are cached once per imported renderer Part;
/// subsequent selection/drag updates transform only eight corners per Part.
enum CADSelectionGizmoPlacement {
  static func localBoundsByPartID(
    geometry: CADRenderGeometry
  ) -> [Int: CADPartLocalBounds] {
    var result: [Int: CADPartLocalBounds] = [:]
    for index in geometry.positions.indices where index < geometry.partIDs.count {
      let partID = Int(geometry.partIDs[index])
      guard partID > 0 else { continue }
      let position = geometry.positions[index]
      if let current = result[partID] {
        result[partID] = CADPartLocalBounds(
          minimum: simd_min(current.minimum, position),
          maximum: simd_max(current.maximum, position))
      } else {
        result[partID] = CADPartLocalBounds(minimum: position, maximum: position)
      }
    }
    return result
  }

  static func centeredTransform(
    subjectTransform: CADPartRestTransform,
    selectedPartIDs: Set<Int>,
    localBoundsByPartID: [Int: CADPartLocalBounds],
    partTransforms: [Int: simd_float4x4]
  ) -> CADPartRestTransform {
    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    var hasGeometry = false

    for partID in selectedPartIDs {
      guard let bounds = localBoundsByPartID[partID] else { continue }
      let transform = partTransforms[partID] ?? matrix_identity_float4x4
      for corner in bounds.corners {
        let transformed = transform * SIMD4(corner, 1)
        let worldPosition = SIMD3(transformed.x, transformed.y, transformed.z)
        minimum = simd_min(minimum, worldPosition)
        maximum = simd_max(maximum, worldPosition)
        hasGeometry = true
      }
    }

    guard hasGeometry else { return subjectTransform }
    var centered = subjectTransform.matrix
    centered.columns.3 = SIMD4((minimum + maximum) * 0.5, 1)
    return CADPartRestTransform(matrix: centered)
  }

  /// Converts an absolute manipulator edit back to the semantic Part/group
  /// origin. The center offset stays rigid in subject-local coordinates, so
  /// rotations happen around the visual selection center without changing the
  /// canonical meaning of the stored origin.
  static func subjectTransform(
    for gizmoTransform: CADPartRestTransform,
    currentGizmoTransform: CADPartRestTransform,
    currentSubjectTransform: CADPartRestTransform
  ) -> CADPartRestTransform {
    let subjectToGizmo =
      simd_inverse(currentSubjectTransform.matrix) * currentGizmoTransform.matrix
    return CADPartRestTransform(
      matrix: gizmoTransform.matrix * simd_inverse(subjectToGizmo))
  }
}

public enum CADTransformAxis: String, CaseIterable, Codable, Hashable, Sendable {
  case x
  case y
  case z

  fileprivate var rawIndex: Int {
    switch self {
    case .x: 0
    case .y: 1
    case .z: 2
    }
  }

  fileprivate var matrixColumn: Int { rawIndex }
}

/// One selected part's local frame, already resolved in assembly coordinates.
/// Column-major storage travels unchanged to Metal and Three.js.
public struct CADPartOriginPresentation: Codable, Equatable, Sendable {
  public let matrixColumnMajor: [Float]
  public let axisLengthMeters: Float

  public init(transform: CADPartRestTransform, axisLengthMeters: Float) {
    self.init(matrix: transform.matrix, axisLengthMeters: axisLengthMeters)
  }

  public init(matrix: simd_float4x4, axisLengthMeters: Float) {
    self.init(
      matrixColumnMajor: [
        matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
        matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
        matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
        matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w,
      ],
      axisLengthMeters: axisLengthMeters)
  }

  public init(matrixColumnMajor: [Float], axisLengthMeters: Float) {
    self.matrixColumnMajor =
      matrixColumnMajor.count == 16
      ? matrixColumnMajor
      : [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]
    self.axisLengthMeters = max(axisLengthMeters, 0.000_25)
  }

  public var matrix: simd_float4x4 {
    guard matrixColumnMajor.count == 16 else { return matrix_identity_float4x4 }
    return simd_float4x4(
      SIMD4(
        matrixColumnMajor[0], matrixColumnMajor[1], matrixColumnMajor[2],
        matrixColumnMajor[3]),
      SIMD4(
        matrixColumnMajor[4], matrixColumnMajor[5], matrixColumnMajor[6],
        matrixColumnMajor[7]),
      SIMD4(
        matrixColumnMajor[8], matrixColumnMajor[9], matrixColumnMajor[10],
        matrixColumnMajor[11]),
      SIMD4(
        matrixColumnMajor[12], matrixColumnMajor[13], matrixColumnMajor[14],
        matrixColumnMajor[15]))
  }
}

/// One GPU part-transform entry, using the same node+1 ID and column-major
/// matrix on Metal and Three.js.
public struct CADPartTransformPresentation: Codable, Equatable, Sendable {
  public let partID: Int
  public let matrixColumnMajor: [Float]

  public init(partID: Int, matrix: simd_float4x4) {
    self.partID = partID
    matrixColumnMajor =
      CADPartOriginPresentation(
        matrix: matrix, axisLengthMeters: 1
      ).matrixColumnMajor
  }

  public var matrix: simd_float4x4 {
    CADPartOriginPresentation(
      matrixColumnMajor: matrixColumnMajor,
      axisLengthMeters: 1
    ).matrix
  }
}

/// Renderer-facing, view-only material override for one CAD assembly node.
///
/// The app expands its semantic Part appearance metadata to the same node+1
/// IDs used by transforms and selection. This presentation never enters the
/// AnimaCore rig: color/material/opacity remain editor metadata.
public struct CADPartAppearancePresentation: Codable, Equatable, Sendable {
  public let partID: Int
  public let color: SIMD4<Float>
  public let roughness: Float
  public let metallic: Float

  public init(
    partID: Int,
    color: SIMD4<Float>,
    roughness: Float,
    metallic: Float
  ) {
    self.partID = partID
    self.color = SIMD4(
      color.x.clamped(to: 0...1),
      color.y.clamped(to: 0...1),
      color.z.clamped(to: 0...1),
      color.w.clamped(to: 0...1))
    self.roughness = roughness.clamped(to: 0...1)
    self.metallic = metallic.clamped(to: 0...1)
  }
}

extension Float {
  fileprivate func clamped(to range: ClosedRange<Float>) -> Float {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

public struct CADNormalizedViewportPoint: Codable, Equatable, Sendable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

/// The selected Part's local orthogonal frame after projection through the
/// active renderer camera. The origin and three axis endpoints use normalized
/// top-left viewport coordinates, so one manipulator implementation can serve
/// native Metal and Three.js/WebGPU without inventing screen-space axes.
public struct CADProjectedLocalFrame: Codable, Equatable, Sendable {
  public let origin: CADNormalizedViewportPoint
  public let xAxis: CADNormalizedViewportPoint
  public let yAxis: CADNormalizedViewportPoint
  public let zAxis: CADNormalizedViewportPoint

  public init(
    origin: CADNormalizedViewportPoint,
    xAxis: CADNormalizedViewportPoint,
    yAxis: CADNormalizedViewportPoint,
    zAxis: CADNormalizedViewportPoint
  ) {
    self.origin = origin
    self.xAxis = xAxis
    self.yAxis = yAxis
    self.zAxis = zAxis
  }

  public init?(
    localFrame: simd_float4x4,
    axisLengthMeters: Float,
    viewProjection: simd_float4x4
  ) {
    let originWorld = SIMD3(
      localFrame.columns.3.x,
      localFrame.columns.3.y,
      localFrame.columns.3.z)
    let xWorld =
      originWorld
      + SIMD3(localFrame.columns.0.x, localFrame.columns.0.y, localFrame.columns.0.z)
      * axisLengthMeters
    let yWorld =
      originWorld
      + SIMD3(localFrame.columns.1.x, localFrame.columns.1.y, localFrame.columns.1.z)
      * axisLengthMeters
    let zWorld =
      originWorld
      + SIMD3(localFrame.columns.2.x, localFrame.columns.2.y, localFrame.columns.2.z)
      * axisLengthMeters
    guard
      let origin = Self.projectUnclipped(originWorld, viewProjection: viewProjection),
      let xAxis = Self.projectUnclipped(xWorld, viewProjection: viewProjection),
      let yAxis = Self.projectUnclipped(yWorld, viewProjection: viewProjection),
      let zAxis = Self.projectUnclipped(zWorld, viewProjection: viewProjection)
    else { return nil }
    self.init(origin: origin, xAxis: xAxis, yAxis: yAxis, zAxis: zAxis)
  }

  private static func projectUnclipped(
    _ worldPosition: SIMD3<Float>,
    viewProjection: simd_float4x4
  ) -> CADNormalizedViewportPoint? {
    let clip = viewProjection * SIMD4(worldPosition, 1)
    guard clip.w > 0.000_001 else { return nil }
    let inverseW = 1 / clip.w
    let x = Double((clip.x * inverseW + 1) * 0.5)
    let y = Double((1 - clip.y * inverseW) * 0.5)
    guard x.isFinite, y.isFinite else { return nil }
    return CADNormalizedViewportPoint(x: x, y: y)
  }
}

/// Shared world-to-screen projection used by the native renderer and the
/// renderer-independent transform gizmo. Three.js reports the same normalized
/// top-left coordinate after applying its own camera matrices.
public enum CADViewportProjection {
  public static func viewProjection(
    cameraPosition: SIMD3<Float>,
    cameraTarget: SIMD3<Float>,
    cameraUp: SIMD3<Float>,
    cameraDistance: Float,
    modelDiagonalMeters: Float,
    aspect: Float
  ) -> simd_float4x4 {
    let radius = max(modelDiagonalMeters * 0.5, 0.001)
    return perspective(
      fovY: 45 * .pi / 180,
      aspect: max(aspect, 0.000_1),
      near: max(radius * 0.0001, 0.000_01),
      far: max(cameraDistance + radius * 4, radius * 8))
      * lookAt(eye: cameraPosition, center: cameraTarget, up: cameraUp)
  }

  public static func project(
    worldPosition: SIMD3<Float>,
    viewProjection: simd_float4x4
  ) -> CADNormalizedViewportPoint? {
    let clip = viewProjection * SIMD4(worldPosition, 1)
    guard clip.w > 0.000_001 else { return nil }
    let inverseW = 1 / clip.w
    let ndc = SIMD3(clip.x * inverseW, clip.y * inverseW, clip.z * inverseW)
    guard ndc.x >= -1, ndc.x <= 1, ndc.y >= -1, ndc.y <= 1,
      ndc.z >= 0, ndc.z <= 1
    else { return nil }
    return CADNormalizedViewportPoint(
      x: Double((ndc.x + 1) * 0.5),
      y: Double((1 - ndc.y) * 0.5))
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

  private static func perspective(
    fovY: Float,
    aspect: Float,
    near: Float,
    far: Float
  ) -> simd_float4x4 {
    let y = 1 / tan(fovY * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return simd_float4x4(
      SIMD4(x, 0, 0, 0),
      SIMD4(0, y, 0, 0),
      SIMD4(0, 0, z, -1),
      SIMD4(0, 0, z * near, 0))
  }
}

struct CADSourceLoadBatch: Sendable {
  let document: CADGeometryDocument?
  let partIDRangesByURL: [URL: Range<Int>]
  let triangleCountsByURL: [URL: Int]
  let failuresByURL: [URL: String]

  static func importing(
    _ sourceURLs: [URL],
    loader: @Sendable (URL) throws -> CADGeometryDocument = {
      try CADGeometryDocument.loadSTEP($0)
    }
  ) -> Self {
    var imported: [(url: URL, document: CADGeometryDocument)] = []
    var failures: [URL: String] = [:]

    for sourceURL in sourceURLs {
      let standardizedURL = sourceURL.standardizedFileURL
      do {
        imported.append((standardizedURL, try loader(sourceURL)))
      } catch {
        failures[standardizedURL] = error.localizedDescription
      }
    }

    var rangesByURL: [URL: Range<Int>] = [:]
    var countsByURL: [URL: Int] = [:]
    var nodeOffset = 0
    for source in imported {
      countsByURL[source.url] = source.document.triangleCount
      let count = source.document.nodes.count
      rangesByURL[source.url] = nodeOffset..<(nodeOffset + count)
      nodeOffset += count
    }

    let mergedDocument: CADGeometryDocument?
    if imported.isEmpty {
      mergedDocument = nil
    } else {
      do {
        mergedDocument = try CADGeometryDocument.merging(imported.map(\.document))
      } catch {
        mergedDocument = nil
        for source in imported {
          failures[source.url] =
            "The imported geometry could not be combined: \(error.localizedDescription)"
        }
        rangesByURL.removeAll()
        countsByURL.removeAll()
      }
    }

    return Self(
      document: mergedDocument,
      partIDRangesByURL: rangesByURL,
      triangleCountsByURL: countsByURL,
      failuresByURL: failures
    )
  }
}

/// Production host for the four Codex Bench pipelines. It imports every STEP
/// source through Open CASCADE, keeps every successful source available when
/// another source fails, then switches only the renderer consumer.
public struct CADPipelineViewport: View {
  public let sourceURLs: [URL]
  public let backend: CADRenderBackend
  public let theme: CADViewportTheme
  public let navigation: CADViewportNavigationConfiguration
  public let showsTelemetry: Bool
  public let telemetryTrailingPadding: CGFloat
  public let telemetryBottomPadding: CGFloat
  public let isSelected: Bool
  /// View direction and optional roll `[x, y, z, roll]` the shared ViewCube
  /// requests. The direction is target→camera in the fixed world frame.
  public let viewDirection: [Double]?
  public let cameraCommandRevision: Int
  /// STEP source files whose parts are hidden / selected in the assembly tree.
  /// The pipeline maps each file to its assembly-node range, so per-part hide
  /// and select work without knowing PartIDs.
  public let hiddenSourceURLs: Set<URL>
  public let selectedSourceURLs: Set<URL>
  public let groundedSourceURLs: Set<URL>
  public let editableSourceURLs: Set<URL>
  public let primarySelectedSourceURL: URL?
  public let partRestTransformsBySourceURL: [URL: CADPartRestTransform]
  public let partAppearancesBySourceURL: [URL: CADPartAppearancePresentation]
  public let primarySelectionTransformOverride: CADPartRestTransform?
  public let primarySelectionTransformLabel: String
  public let primaryPartTransformIsEditable: Bool
  public let referenceGeometryVisibility: CADReferenceGeometryVisibility
  public let showsFloorGrid: Bool
  public let showsSolidFloor: Bool
  public let floorGridSpacingMeters: Float
  public let floorGridExtentMultiplier: Float
  public let floorGridMajorLineInterval: Int
  public let floorGridOpacity: Float
  /// Enables exact B-Rep feature inference for mate connector placement.
  public let mateConnectorPickingEnabled: Bool
  /// Reports real completed/presented renderer frames and process diagnostics.
  /// This is not the AnimaCore animation playhead or evaluation timestamp.
  public let onPerformanceUpdate: @MainActor @Sendable (CADViewportPerformanceSnapshot) -> Void
  public let onSourceTriangleCountsChange: ([URL: Int]) -> Void
  /// Reports only source-level failures. The owning document maps these URLs
  /// back to semantic Parts and presents recovery in its tree/table instead of
  /// replacing the entire CAD viewport with an error screen.
  public let onSourceLoadFailuresChange: ([URL: String]) -> Void
  /// Reports the live world-relative camera orientation so the ViewCube tracks
  /// CAD orbit and roll without owning a second camera.
  public let onCameraOrientation: @MainActor @Sendable (CADCameraOrientationPresentation) -> Void
  /// A part clicked in the viewport, mapped back to its STEP file (nil = empty
  /// click → clear). The caller maps the file to a PartID and selects it.
  public let onPickPart: @MainActor @Sendable (URL?, Bool) -> Void
  public let onBoxPickParts: @MainActor @Sendable (Set<URL>, Bool) -> Void
  public let onContextMenuPart: @MainActor @Sendable (URL?, CGPoint) -> Void
  public let onPickMateFeature: @MainActor @Sendable (CADViewportFeaturePick?, URL?) -> Void
  public let onSetPrimaryPartRestTransform: @MainActor @Sendable (CADPartRestTransform) -> Void
  public let onSetPartRestTransform: @MainActor @Sendable (URL, CADPartRestTransform) -> Void

  @State private var document: CADGeometryDocument?
  @State private var camera = CADCameraState()
  @State private var telemetry = CADLiveTelemetry()
  @State private var status = "Waiting for STEP geometry"
  @State private var isLoading = true
  @State private var partIDRangesByURL: [URL: Range<Int>] = [:]
  @State private var localBoundsByPartID: [Int: CADPartLocalBounds] = [:]
  @State private var webProjectedSelectedFrame: CADProjectedLocalFrame?
  @State private var directPartDragStart: CADPartRestTransform?
  @State private var directPartDragSourceURL: URL?

  public init(
    sourceURLs: [URL],
    backend: CADRenderBackend,
    theme: CADViewportTheme,
    navigation: CADViewportNavigationConfiguration = .onshape,
    showsTelemetry: Bool = false,
    telemetryTrailingPadding: CGFloat = 14,
    telemetryBottomPadding: CGFloat = 14,
    isSelected: Bool = false,
    viewDirection: [Double]? = nil,
    cameraCommandRevision: Int = 0,
    hiddenSourceURLs: Set<URL> = [],
    selectedSourceURLs: Set<URL> = [],
    groundedSourceURLs: Set<URL> = [],
    editableSourceURLs: Set<URL> = [],
    primarySelectedSourceURL: URL? = nil,
    partRestTransformsBySourceURL: [URL: CADPartRestTransform] = [:],
    partAppearancesBySourceURL: [URL: CADPartAppearancePresentation] = [:],
    primarySelectionTransformOverride: CADPartRestTransform? = nil,
    primarySelectionTransformLabel: String = "Part origin",
    primaryPartTransformIsEditable: Bool = false,
    referenceGeometryVisibility: CADReferenceGeometryVisibility = .init(),
    showsFloorGrid: Bool = true,
    showsSolidFloor: Bool = false,
    floorGridSpacingMeters: Float = 0.1,
    floorGridExtentMultiplier: Float = 4,
    floorGridMajorLineInterval: Int = 5,
    floorGridOpacity: Float = 0.24,
    mateConnectorPickingEnabled: Bool = false,
    onPerformanceUpdate:
      @escaping @MainActor @Sendable (CADViewportPerformanceSnapshot) -> Void = { _ in },
    onSourceTriangleCountsChange: @escaping ([URL: Int]) -> Void = { _ in },
    onSourceLoadFailuresChange: @escaping ([URL: String]) -> Void = { _ in },
    onCameraOrientation:
      @escaping @MainActor @Sendable (CADCameraOrientationPresentation) -> Void = { _ in },
    onPickPart: @escaping @MainActor @Sendable (URL?, Bool) -> Void = { _, _ in },
    onBoxPickParts:
      @escaping @MainActor @Sendable (Set<URL>, Bool) -> Void = { _, _ in },
    onContextMenuPart:
      @escaping @MainActor @Sendable (URL?, CGPoint) -> Void = { _, _ in },
    onPickMateFeature:
      @escaping @MainActor @Sendable (CADViewportFeaturePick?, URL?) -> Void = { _, _ in },
    onSetPrimaryPartRestTransform:
      @escaping @MainActor @Sendable (CADPartRestTransform) -> Void = { _ in },
    onSetPartRestTransform:
      @escaping @MainActor @Sendable (URL, CADPartRestTransform) -> Void = { _, _ in }
  ) {
    self.sourceURLs = sourceURLs
    self.backend = backend
    self.theme = theme
    self.navigation = navigation
    self.showsTelemetry = showsTelemetry
    self.telemetryTrailingPadding = telemetryTrailingPadding
    self.telemetryBottomPadding = telemetryBottomPadding
    self.isSelected = isSelected
    self.viewDirection = viewDirection
    self.cameraCommandRevision = cameraCommandRevision
    self.hiddenSourceURLs = hiddenSourceURLs
    self.selectedSourceURLs = selectedSourceURLs
    self.groundedSourceURLs = groundedSourceURLs
    self.editableSourceURLs = editableSourceURLs
    self.primarySelectedSourceURL = primarySelectedSourceURL
    self.partRestTransformsBySourceURL = partRestTransformsBySourceURL
    self.partAppearancesBySourceURL = partAppearancesBySourceURL
    self.primarySelectionTransformOverride = primarySelectionTransformOverride
    self.primarySelectionTransformLabel = primarySelectionTransformLabel
    self.primaryPartTransformIsEditable = primaryPartTransformIsEditable
    self.referenceGeometryVisibility = referenceGeometryVisibility
    self.showsFloorGrid = showsFloorGrid
    self.showsSolidFloor = showsSolidFloor
    self.floorGridSpacingMeters = floorGridSpacingMeters
    self.floorGridExtentMultiplier = floorGridExtentMultiplier
    self.floorGridMajorLineInterval = floorGridMajorLineInterval
    self.floorGridOpacity = floorGridOpacity
    self.mateConnectorPickingEnabled = mateConnectorPickingEnabled
    self.onPerformanceUpdate = onPerformanceUpdate
    self.onSourceTriangleCountsChange = onSourceTriangleCountsChange
    self.onSourceLoadFailuresChange = onSourceLoadFailuresChange
    self.onCameraOrientation = onCameraOrientation
    self.onPickPart = onPickPart
    self.onBoxPickParts = onBoxPickParts
    self.onContextMenuPart = onContextMenuPart
    self.onPickMateFeature = onPickMateFeature
    self.onSetPrimaryPartRestTransform = onSetPrimaryPartRestTransform
    self.onSetPartRestTransform = onSetPartRestTransform
  }

  /// CAD partIDs (assemblyNode + 1) for the given source files.
  private func partIDs(for urls: Set<URL>) -> Set<Int> {
    var ids: Set<Int> = []
    for url in urls {
      guard let range = partIDRangesByURL[url.standardizedFileURL] else { continue }
      for node in range { ids.insert(node + 1) }
    }
    return ids
  }

  /// Reverse of `partIDs(for:)`: the STEP file a picked partID belongs to.
  private func sourceURL(forPartID partID: Int) -> URL? {
    guard partID > 0 else { return nil }
    let node = partID - 1
    return partIDRangesByURL.first { $0.value.contains(node) }?.key
  }

  private var workspaceReferenceGeometry: CADWorkspaceReferenceGeometry {
    CADWorkspaceReferenceGeometry(
      visibility: referenceGeometryVisibility,
      modelDiagonalMeters: document?.renderGeometry.bounds.diagonal ?? 1,
      showsFloorGrid: showsFloorGrid,
      showsSolidFloor: showsSolidFloor,
      floorGridSpacingMeters: floorGridSpacingMeters,
      floorGridExtentMultiplier: floorGridExtentMultiplier,
      floorGridMajorLineInterval: floorGridMajorLineInterval,
      floorGridOpacity: floorGridOpacity
    )
  }

  /// The complete node-part transform map is expanded once from the shared
  /// source→part mapping. Task 3 will hand this same map to both mesh adapters;
  /// Task 2 consumes its primary entry for the selected local frame.
  private var partTransforms: [Int: simd_float4x4] {
    var result: [Int: simd_float4x4] = [:]
    for (sourceURL, transform) in partRestTransformsBySourceURL {
      guard let range = partIDRangesByURL[sourceURL.standardizedFileURL] else { continue }
      for node in range {
        result[node + 1] = transform.matrix
      }
    }
    return result
  }

  private var selectedSubjectTransform: CADPartRestTransform? {
    if let primarySelectionTransformOverride { return primarySelectionTransformOverride }
    guard let sourceURL = primarySelectedSourceURL?.standardizedFileURL else { return nil }
    return partRestTransformsBySourceURL[sourceURL]
  }

  /// Screen→world conversion for gizmo handle drags at the selected subject's
  /// camera depth, matching the render projection — the previous
  /// model-diagonal constant ignored zoom, so the part moved at a different
  /// rate than the cursor and the gizmo felt disconnected from the model.
  private func gizmoMetersPerPoint(viewportSize: CGSize) -> Double {
    guard let subject = selectedSubjectTransform else { return 0.001 }
    let origin = SIMD3<Float>(
      Float(subject.positionMeters[0]),
      Float(subject.positionMeters[1]),
      Float(subject.positionMeters[2]))
    let forwardValue = camera.target - camera.position
    guard simd_length(forwardValue) > 0.000_001 else { return 0.001 }
    let forward = simd_normalize(forwardValue)
    let depth = max(Double(simd_dot(origin - camera.position, forward)), 0.001)
    let verticalFieldOfViewRadians = 45.0 * .pi / 180
    return 2 * depth * tan(verticalFieldOfViewRadians * 0.5)
      / max(Double(viewportSize.height), 1)
  }

  private var selectedGizmoTransform: CADPartRestTransform? {
    guard let subjectTransform = selectedSubjectTransform else { return nil }
    return CADSelectionGizmoPlacement.centeredTransform(
      subjectTransform: subjectTransform,
      selectedPartIDs: partIDs(for: selectedSourceURLs),
      localBoundsByPartID: localBoundsByPartID,
      partTransforms: partTransforms)
  }

  private var selectedPartOrigin: CADPartOriginPresentation? {
    guard let selectedGizmoTransform else { return nil }
    return CADPartOriginPresentation(
      transform: selectedGizmoTransform,
      axisLengthMeters: workspaceReferenceGeometry.axisLengthMeters * 0.72)
  }

  private func setSelectedGizmoTransform(_ transform: CADPartRestTransform) {
    guard let currentSubjectTransform = selectedSubjectTransform,
      let currentGizmoTransform = selectedGizmoTransform
    else { return }
    onSetPrimaryPartRestTransform(
      CADSelectionGizmoPlacement.subjectTransform(
        for: transform,
        currentGizmoTransform: currentGizmoTransform,
        currentSubjectTransform: currentSubjectTransform))
  }

  private var partTransformPresentations: [CADPartTransformPresentation] {
    partTransforms.keys.sorted().compactMap { partID in
      partTransforms[partID].map {
        CADPartTransformPresentation(partID: partID, matrix: $0)
      }
    }
  }

  private var partAppearancePresentations: [CADPartAppearancePresentation] {
    var presentations: [CADPartAppearancePresentation] = []
    for (sourceURL, appearance) in partAppearancesBySourceURL {
      guard let range = partIDRangesByURL[sourceURL.standardizedFileURL] else { continue }
      presentations.append(
        contentsOf: range.map {
          CADPartAppearancePresentation(
            partID: $0 + 1,
            color: appearance.color,
            roughness: appearance.roughness,
            metallic: appearance.metallic)
        })
    }
    return presentations.sorted { $0.partID < $1.partID }
  }

  public var body: some View {
    GeometryReader { geometry in
      ZStack {
        renderer
        if let selectedGizmoTransform,
          let projectedFrame = selectedGizmoProjection(in: geometry.size)
        {
          CADTransformGizmoOverlay(
            transform: selectedGizmoTransform,
            projectedFrame: projectedFrame,
            viewportSize: geometry.size,
            label: primarySelectionTransformLabel,
            isEnabled: primaryPartTransformIsEditable,
            metersPerPoint: gizmoMetersPerPoint(viewportSize: geometry.size),
            onChange: setSelectedGizmoTransform
          )
          .position(
            x: projectedFrame.origin.x * geometry.size.width,
            y: projectedFrame.origin.y * geometry.size.height)
        }
        if isLoading {
          ContentUnavailableView {
            Label(
              "Loading STEP",
              systemImage: "gearshape.2")
          } description: {
            Text(
              "Open CASCADE is reading hierarchy, colors, faces, and feature edges."
            )
          }
        }
        if showsTelemetry, let document {
          telemetry(document)
        }
      }
      .coordinateSpace(name: CADGizmoInteraction.viewportCoordinateSpace)
    }
    .task(id: sourceSignature) { await loadSources() }
    .onAppear {
      applyRequestedOrientationToNativeCamera()
      reportNativeCameraOrientation()
      telemetry.start(onSample: onPerformanceUpdate)
    }
    .onDisappear { telemetry.stop() }
    .onChange(of: cameraCommandRevision) { _, _ in
      applyRequestedOrientationToNativeCamera()
    }
    .onChange(of: camera.orientationPresentation) { _, _ in
      reportNativeCameraOrientation()
    }
    .onChange(of: selectedPartOrigin == nil) { _, originIsMissing in
      if backend != .metalKit, originIsMissing {
        webProjectedSelectedFrame = nil
      }
    }
    .onChange(of: backend) { _, _ in
      webProjectedSelectedFrame = nil
      applyRequestedOrientationToNativeCamera()
      reportNativeCameraOrientation()
    }
  }

  private func selectedGizmoProjection(in size: CGSize) -> CADProjectedLocalFrame? {
    if backend == .metalKit, let selectedPartOrigin {
      let aspect = Float(max(size.width, 1) / max(size.height, 1))
      let viewProjection = CADViewportProjection.viewProjection(
        cameraPosition: camera.position,
        cameraTarget: camera.target,
        cameraUp: camera.upVector,
        cameraDistance: camera.distance,
        modelDiagonalMeters: document?.renderGeometry.bounds.diagonal ?? 1,
        aspect: aspect)
      return CADProjectedLocalFrame(
        localFrame: selectedPartOrigin.matrix,
        axisLengthMeters: selectedPartOrigin.axisLengthMeters,
        viewProjection: viewProjection)
    }
    return webProjectedSelectedFrame
  }

  /// Apply only explicit ViewCube/navigation commands. Live renderer reports
  /// do not increment `cameraCommandRevision`, so they cannot echo back and
  /// fight a pointer orbit.
  private func applyRequestedOrientationToNativeCamera() {
    guard backend == .metalKit || backend == .realityKit,
      let direction = viewDirection,
      direction.count >= 3
    else { return }
    camera.set(
      orientation: CADCameraOrientationPresentation(
        direction: SIMD3(
          Float(direction[0]),
          Float(direction[1]),
          Float(direction[2])
        ),
        rollRadians: direction.count >= 4 ? Float(direction[3]) : 0
      )
    )
  }

  private func reportNativeCameraOrientation() {
    guard backend == .metalKit || backend == .realityKit else { return }
    onCameraOrientation(camera.orientationPresentation)
  }

  @ViewBuilder
  private var renderer: some View {
    switch backend {
    case .metalKit:
      CADMetalViewport(
        document: document, camera: camera, theme: theme, navigation: navigation,
        isSelected: isSelected,
        hiddenPartIDs: partIDs(for: hiddenSourceURLs),
        selectedPartIDs: partIDs(for: selectedSourceURLs),
        groundedPartIDs: partIDs(for: groundedSourceURLs),
        referenceGeometry: workspaceReferenceGeometry,
        partTransforms: partTransformPresentations,
        partAppearances: partAppearancePresentations,
        selectedPartOrigin: selectedPartOrigin,
        mateConnectorPickingEnabled: mateConnectorPickingEnabled,
        onFrame: recordFrame,
        onError: { status = "Renderer unavailable: \($0)" },
        onPick: { partID, extend in onPickPart(sourceURL(forPartID: partID), extend) },
        onBoxPick: { partIDs, extend in
          onBoxPickParts(Set(partIDs.compactMap(sourceURL(forPartID:))), extend)
        },
        onContextMenu: { partID, point, viewportSize in
          onContextMenuPart(
            partID.flatMap(sourceURL(forPartID:)),
            CGPoint(x: point.x, y: viewportSize.height - point.y))
        },
        onPickFeature: { feature in
          onPickMateFeature(feature, feature.flatMap { sourceURL(forPartID: $0.partID) })
        },
        onBeginDirectPartDrag: beginDirectPartDrag,
        onUpdateDirectPartDrag: updateDirectPartDrag,
        onEndDirectPartDrag: endDirectPartDrag)
    case .realityKit:
      CADRealityKitViewport(
        document: document, camera: camera, theme: theme, navigation: navigation,
        isSelected: isSelected,
        onFrame: recordFrame)
    case .threeJSWebGPU, .rawWebGPU:
      CADWebGPUViewport(
        backend: backend, document: document, theme: theme, navigation: navigation,
        viewDirection: viewDirection,
        cameraCommandRevision: cameraCommandRevision,
        hiddenPartIDs: partIDs(for: hiddenSourceURLs),
        selectedPartIDs: partIDs(for: selectedSourceURLs),
        groundedPartIDs: partIDs(for: groundedSourceURLs),
        referenceGeometry: workspaceReferenceGeometry,
        partTransforms: partTransformPresentations,
        partAppearances: partAppearancePresentations,
        selectedPartOrigin: selectedPartOrigin,
        onStatus: { status = $0 },
        onFrameCount: { count, intervalSeconds in
          telemetry.recordFrames(count, intervalSeconds: intervalSeconds)
        },
        onCameraOrientation: { orientation in
          camera.set(orientation: orientation)
          onCameraOrientation(orientation)
        },
        onSelectedGizmoProjection: { webProjectedSelectedFrame = $0 },
        onPick: { partID, extend in onPickPart(sourceURL(forPartID: partID), extend) },
        onBoxPick: { partIDs, extend in
          onBoxPickParts(Set(partIDs.compactMap(sourceURL(forPartID:))), extend)
        },
        onContextMenu: { partID, point in
          onContextMenuPart(partID.flatMap(sourceURL(forPartID:)), point)
        },
        onBeginDirectPartDrag: beginDirectPartDrag,
        onUpdateDirectPartDrag: updateDirectPartDrag,
        onEndDirectPartDrag: endDirectPartDrag)
    }
  }

  private func beginDirectPartDrag(_ partID: Int) -> Bool {
    guard let sourceURL = sourceURL(forPartID: partID)?.standardizedFileURL else {
      return false
    }
    // Every hit selects, even when that component is locked or constrained and
    // cannot be directly repositioned.
    onPickPart(sourceURL, false)
    guard
      editableSourceURLs.contains(sourceURL),
      let start = partRestTransformsBySourceURL[sourceURL]
    else { return false }
    // Mouse-down selects the hit component before its transform starts
    // moving. Plain left-drag is therefore a single select-and-place gesture.
    directPartDragStart = start
    directPartDragSourceURL = sourceURL
    return true
  }

  private func updateDirectPartDrag(_ translation: CGSize, _ viewportSize: CGSize) {
    guard let start = directPartDragStart, let sourceURL = directPartDragSourceURL else {
      return
    }
    onSetPartRestTransform(
      sourceURL,
      CADDirectManipulation.translated(
        start,
        screenTranslation: translation,
        viewportHeightPoints: viewportSize.height,
        cameraPosition: camera.position,
        cameraTarget: camera.target,
        cameraUp: camera.upVector))
  }

  private func endDirectPartDrag() {
    directPartDragStart = nil
    directPartDragSourceURL = nil
  }

  private func telemetry(_ document: CADGeometryDocument) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      metric("PIPELINE", backend.title)
      metric("ROLE", backend.role)
      metric("LOAD", String(format: "%.1f ms", document.metrics.totalMilliseconds))
      metric("FPS", String(format: "%.1f", telemetry.framesPerSecond))
      metric("CPU", String(format: "%.1f %%", telemetry.cpuPercent))
      metric("MEMORY", String(format: "%.1f MB", telemetry.memoryMegabytes))
      metric("GPU", gpuLabel)
      metric("FACES", "\(document.faces.count)")
      metric("EDGES", "\(document.edges.count)")
      metric("TRIS", "\(document.triangleCount)")
      metric("KERNEL", "Open CASCADE \(CADGeometryKernel.version)")
      Text(status)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .padding(.top, 3)
      if backend == .threeJSWebGPU || backend == .rawWebGPU {
        Text("CPU/memory exclude WebKit helper processes")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .font(.system(.caption, design: .monospaced))
    .padding(12)
    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12)))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    .padding(.trailing, telemetryTrailingPadding)
    .padding(.bottom, telemetryBottomPadding)
    .allowsHitTesting(false)
  }

  private func metric(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label).foregroundStyle(.secondary).frame(width: 62, alignment: .leading)
      Text(value).foregroundStyle(.primary)
    }
  }

  private var gpuLabel: String {
    switch backend {
    case .metalKit: "Apple Metal"
    case .realityKit: "RealityKit / Apple Metal"
    case .threeJSWebGPU: "Three.js via Apple WebKit"
    case .rawWebGPU: "WebGPU/WGSL via Apple WebKit"
    }
  }

  private var sourceSignature: String {
    sourceURLs.map { url in
      let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
      let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
      let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
      return "\(url.standardizedFileURL.path)|\(modified)|\(size)"
    }.sorted().joined(separator: "||")
  }

  @MainActor
  private func loadSources() async {
    document = nil
    isLoading = true
    partIDRangesByURL = [:]
    localBoundsByPartID = [:]
    onSourceTriangleCountsChange([:])
    onSourceLoadFailuresChange([:])
    let urls = sourceURLs.filter { ["step", "stp"].contains($0.pathExtension.lowercased()) }
    guard !urls.isEmpty else {
      isLoading = false
      status = "No STEP sources"
      return
    }
    let batch = await Task.detached(priority: .userInitiated) {
      CADSourceLoadBatch.importing(urls)
    }.value
    guard !Task.isCancelled else { return }

    partIDRangesByURL = batch.partIDRangesByURL
    onSourceTriangleCountsChange(batch.triangleCountsByURL)
    onSourceLoadFailuresChange(batch.failuresByURL)
    document = batch.document
    if let merged = batch.document {
      localBoundsByPartID = CADSelectionGizmoPlacement.localBoundsByPartID(
        geometry: merged.renderGeometry)
      camera.frame(bounds: merged.renderGeometry.bounds)
    }
    let loadedCount = batch.triangleCountsByURL.count
    let failedCount = batch.failuresByURL.count
    if failedCount == 0 {
      status = "Loaded \(loadedCount) STEP source\(loadedCount == 1 ? "" : "s")"
    } else {
      status =
        "Loaded \(loadedCount) source\(loadedCount == 1 ? "" : "s"); "
        + "\(failedCount) need\(failedCount == 1 ? "s" : "") relinking"
    }
    isLoading = false
  }

  @MainActor private func recordFrame() { telemetry.recordFrames() }
}
