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

  public init(
    visibility: CADReferenceGeometryVisibility,
    modelDiagonalMeters: Float,
    gridDivisions: Int = 10
  ) {
    let workingDiagonal = max(modelDiagonalMeters, 0.001)
    self.visibility = visibility
    planeSizeMeters = workingDiagonal * 1.25
    axisLengthMeters = workingDiagonal * 0.35
    self.gridDivisions = max(gridDivisions, 2)
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
    var result = self
    result.rotationEulerRadians[localAxis.rawIndex] += angleRadians
    return result
  }

  public func applyingAssemblyDelta(_ delta: simd_float4x4) -> CADPartRestTransform {
    CADPartRestTransform(matrix: delta * matrix)
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

public struct CADNormalizedViewportPoint: Codable, Equatable, Sendable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
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

/// Production host for the four Codex Bench pipelines. It imports every STEP
/// source once through Open CASCADE, then switches only the renderer consumer.
public struct CADPipelineViewport: View {
  public let sourceURLs: [URL]
  public let backend: CADRenderBackend
  public let theme: CADViewportTheme
  public let showsTelemetry: Bool
  public let isSelected: Bool
  /// Unit view direction (target→camera, Y-up) the shared ViewCube requests.
  public let viewDirection: [Double]?
  public let cameraCommandRevision: Int
  /// STEP source files whose parts are hidden / selected in the assembly tree.
  /// The pipeline maps each file to its assembly-node range, so per-part hide
  /// and select work without knowing PartIDs.
  public let hiddenSourceURLs: Set<URL>
  public let selectedSourceURLs: Set<URL>
  public let groundedSourceURLs: Set<URL>
  public let primarySelectedSourceURL: URL?
  public let partRestTransformsBySourceURL: [URL: CADPartRestTransform]
  public let primarySelectionTransformOverride: CADPartRestTransform?
  public let primarySelectionTransformLabel: String
  public let primaryPartTransformIsEditable: Bool
  public let referenceGeometryVisibility: CADReferenceGeometryVisibility
  public let onSourceTriangleCountsChange: ([URL: Int]) -> Void
  /// Reports the live view direction so the ViewCube tracks CAD orbits.
  public let onCameraDirection: @MainActor @Sendable ([Double]) -> Void
  /// A part clicked in the viewport, mapped back to its STEP file (nil = empty
  /// click → clear). The caller maps the file to a PartID and selects it.
  public let onPickPart: @MainActor @Sendable (URL?, Bool) -> Void
  public let onSetPrimaryPartRestTransform: @MainActor @Sendable (CADPartRestTransform) -> Void

  @State private var document: CADGeometryDocument?
  @State private var camera = CADCameraState()
  @State private var telemetry = CADLiveTelemetry()
  @State private var status = "Waiting for STEP geometry"
  @State private var errorMessage: String?
  @State private var partIDRangesByURL: [URL: Range<Int>] = [:]
  @State private var webProjectedSelectedOrigin: CADNormalizedViewportPoint?

  public init(
    sourceURLs: [URL],
    backend: CADRenderBackend,
    theme: CADViewportTheme,
    showsTelemetry: Bool = false,
    isSelected: Bool = false,
    viewDirection: [Double]? = nil,
    cameraCommandRevision: Int = 0,
    hiddenSourceURLs: Set<URL> = [],
    selectedSourceURLs: Set<URL> = [],
    groundedSourceURLs: Set<URL> = [],
    primarySelectedSourceURL: URL? = nil,
    partRestTransformsBySourceURL: [URL: CADPartRestTransform] = [:],
    primarySelectionTransformOverride: CADPartRestTransform? = nil,
    primarySelectionTransformLabel: String = "Part origin",
    primaryPartTransformIsEditable: Bool = false,
    referenceGeometryVisibility: CADReferenceGeometryVisibility = .init(),
    onSourceTriangleCountsChange: @escaping ([URL: Int]) -> Void = { _ in },
    onCameraDirection: @escaping @MainActor @Sendable ([Double]) -> Void = { _ in },
    onPickPart: @escaping @MainActor @Sendable (URL?, Bool) -> Void = { _, _ in },
    onSetPrimaryPartRestTransform:
      @escaping @MainActor @Sendable (CADPartRestTransform) -> Void = { _ in }
  ) {
    self.sourceURLs = sourceURLs
    self.backend = backend
    self.theme = theme
    self.showsTelemetry = showsTelemetry
    self.isSelected = isSelected
    self.viewDirection = viewDirection
    self.cameraCommandRevision = cameraCommandRevision
    self.hiddenSourceURLs = hiddenSourceURLs
    self.selectedSourceURLs = selectedSourceURLs
    self.groundedSourceURLs = groundedSourceURLs
    self.primarySelectedSourceURL = primarySelectedSourceURL
    self.partRestTransformsBySourceURL = partRestTransformsBySourceURL
    self.primarySelectionTransformOverride = primarySelectionTransformOverride
    self.primarySelectionTransformLabel = primarySelectionTransformLabel
    self.primaryPartTransformIsEditable = primaryPartTransformIsEditable
    self.referenceGeometryVisibility = referenceGeometryVisibility
    self.onSourceTriangleCountsChange = onSourceTriangleCountsChange
    self.onCameraDirection = onCameraDirection
    self.onPickPart = onPickPart
    self.onSetPrimaryPartRestTransform = onSetPrimaryPartRestTransform
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
      modelDiagonalMeters: document?.renderGeometry.bounds.diagonal ?? 1
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

  private var selectedPartOrigin: CADPartOriginPresentation? {
    if let primarySelectionTransformOverride {
      return CADPartOriginPresentation(
        transform: primarySelectionTransformOverride,
        axisLengthMeters: workspaceReferenceGeometry.axisLengthMeters * 0.72)
    }
    guard let sourceURL = primarySelectedSourceURL?.standardizedFileURL,
      let range = partIDRangesByURL[sourceURL],
      let firstNode = range.first,
      let transform = partTransforms[firstNode + 1]
    else { return nil }
    return CADPartOriginPresentation(
      matrix: transform,
      axisLengthMeters: workspaceReferenceGeometry.axisLengthMeters * 0.72)
  }

  private var selectedPartRestTransform: CADPartRestTransform? {
    if let primarySelectionTransformOverride {
      return primarySelectionTransformOverride
    }
    guard let sourceURL = primarySelectedSourceURL?.standardizedFileURL else { return nil }
    return partRestTransformsBySourceURL[sourceURL]
  }

  private var partTransformPresentations: [CADPartTransformPresentation] {
    partTransforms.keys.sorted().compactMap { partID in
      partTransforms[partID].map {
        CADPartTransformPresentation(partID: partID, matrix: $0)
      }
    }
  }

  public var body: some View {
    GeometryReader { geometry in
      ZStack {
        renderer
        if let selectedPartRestTransform,
          let anchor = selectedOriginAnchor(in: geometry.size)
        {
          CADTransformGizmoOverlay(
            transform: selectedPartRestTransform,
            label: primarySelectionTransformLabel,
            isEnabled: primaryPartTransformIsEditable,
            metersPerPoint: Double(
              max(document?.renderGeometry.bounds.diagonal ?? 1, 0.001) * 0.0015),
            onChange: onSetPrimaryPartRestTransform
          )
          .position(anchor)
        }
        if document == nil {
          ContentUnavailableView {
            Label(
              errorMessage == nil ? "Loading STEP" : "STEP Could Not Load",
              systemImage: errorMessage == nil ? "gearshape.2" : "exclamationmark.triangle")
          } description: {
            Text(
              errorMessage ?? "Open CASCADE is reading hierarchy, colors, faces, and feature edges."
            )
          }
        }
        if showsTelemetry, let document {
          telemetry(document)
        }
      }
    }
    .task(id: sourceSignature) { await loadSources() }
    .onAppear { telemetry.start() }
    .onDisappear { telemetry.stop() }
    .onChange(of: viewDirection ?? []) { _, direction in
      applyViewDirectionToMetalCamera(direction)
    }
    .onChange(of: selectedPartOrigin) { _, _ in
      if backend != .metalKit {
        webProjectedSelectedOrigin = nil
      }
    }
  }

  private func selectedOriginAnchor(in size: CGSize) -> CGPoint? {
    let projected: CADNormalizedViewportPoint?
    if backend == .metalKit, let selectedPartOrigin {
      let aspect = Float(max(size.width, 1) / max(size.height, 1))
      let viewProjection = CADViewportProjection.viewProjection(
        cameraPosition: camera.position,
        cameraTarget: camera.target,
        cameraUp: camera.upVector,
        cameraDistance: camera.distance,
        modelDiagonalMeters: document?.renderGeometry.bounds.diagonal ?? 1,
        aspect: aspect)
      let origin = selectedPartOrigin.matrix.columns.3
      projected = CADViewportProjection.project(
        worldPosition: SIMD3(origin.x, origin.y, origin.z),
        viewProjection: viewProjection)
    } else {
      projected = webProjectedSelectedOrigin
    }
    guard let projected else { return nil }
    return CGPoint(
      x: projected.x * size.width,
      y: projected.y * size.height)
  }

  /// Snap the native Metal camera to a ViewCube direction. WebGPU applies the
  /// direction in JS (see CADWebGPUViewport); this covers the Metal backend.
  private func applyViewDirectionToMetalCamera(_ direction: [Double]) {
    guard backend == .metalKit, direction.count == 3 else { return }
    let dy = Float(max(-1, min(1, direction[1])))
    camera.pitch = -asin(dy)
    camera.yaw = atan2(Float(direction[0]), Float(direction[2]))
    camera.rollRadians = 0
  }

  @ViewBuilder
  private var renderer: some View {
    switch backend {
    case .metalKit:
      CADMetalViewport(
        document: document, camera: camera, theme: theme, isSelected: isSelected,
        hiddenPartIDs: partIDs(for: hiddenSourceURLs),
        selectedPartIDs: partIDs(for: selectedSourceURLs),
        groundedPartIDs: partIDs(for: groundedSourceURLs),
        referenceGeometry: workspaceReferenceGeometry,
        partTransforms: partTransformPresentations,
        selectedPartOrigin: selectedPartOrigin,
        onFrame: recordFrame,
        onError: { errorMessage = $0 })
    case .realityKit:
      CADRealityKitViewport(
        document: document, camera: camera, theme: theme, isSelected: isSelected,
        onFrame: recordFrame)
    case .threeJSWebGPU, .rawWebGPU:
      CADWebGPUViewport(
        backend: backend, document: document, theme: theme,
        viewDirection: viewDirection,
        cameraCommandRevision: cameraCommandRevision,
        hiddenPartIDs: partIDs(for: hiddenSourceURLs),
        selectedPartIDs: partIDs(for: selectedSourceURLs),
        groundedPartIDs: partIDs(for: groundedSourceURLs),
        referenceGeometry: workspaceReferenceGeometry,
        partTransforms: partTransformPresentations,
        selectedPartOrigin: selectedPartOrigin,
        onStatus: { status = $0 },
        onFrameCount: telemetry.recordFrames,
        onCameraDirection: onCameraDirection,
        onSelectedOriginScreenPosition: { webProjectedSelectedOrigin = $0 },
        onPick: { partID, extend in onPickPart(sourceURL(forPartID: partID), extend) })
    }
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
    .padding(14)
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
    errorMessage = nil
    onSourceTriangleCountsChange([:])
    let urls = sourceURLs.filter { ["step", "stp"].contains($0.pathExtension.lowercased()) }
    guard !urls.isEmpty else {
      errorMessage = "The selected CAD backend needs at least one STEP or STP source."
      return
    }
    do {
      let imported = try await Task.detached(priority: .userInitiated) {
        try urls.map { try CADGeometryDocument.loadSTEP($0) }
      }.value
      var counts: [URL: Int] = [:]
      for (url, sourceDocument) in zip(urls, imported) {
        counts[url.standardizedFileURL] = sourceDocument.triangleCount
      }
      onSourceTriangleCountsChange(counts)
      // Record each source's assembly-node range in merge order (merging appends
      // nodes per document in this same order), so per-part hide/select can map
      // a STEP file to its CAD partIDs.
      var rangesByURL: [URL: Range<Int>] = [:]
      var nodeOffset = 0
      for (url, sourceDocument) in zip(urls, imported) {
        let count = sourceDocument.nodes.count
        rangesByURL[url.standardizedFileURL] = nodeOffset..<(nodeOffset + count)
        nodeOffset += count
      }
      partIDRangesByURL = rangesByURL
      let merged = try CADGeometryDocument.merging(imported)
      document = merged
      camera.frame(bounds: merged.renderGeometry.bounds)
      status = "Loaded \(urls.count) STEP source\(urls.count == 1 ? "" : "s")"
    } catch {
      errorMessage = error.localizedDescription
      status = "STEP import failed"
    }
  }

  @MainActor private func recordFrame() { telemetry.recordFrames() }
}
