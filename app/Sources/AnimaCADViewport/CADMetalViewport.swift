import AnimaCAD
import MetalKit
import SwiftUI

public struct CADMetalViewport: View {
  public let document: CADGeometryDocument?
  @Bindable public var camera: CADCameraState
  public let theme: CADViewportTheme
  public let isSelected: Bool
  public let hiddenPartIDs: Set<Int>
  public let selectedPartIDs: Set<Int>
  public let groundedPartIDs: Set<Int>
  public let referenceGeometry: CADWorkspaceReferenceGeometry
  public let partTransforms: [CADPartTransformPresentation]
  public let selectedPartOrigin: CADPartOriginPresentation?
  public let onFrame: @MainActor @Sendable () -> Void
  public let onError: @MainActor @Sendable (String) -> Void

  public init(
    document: CADGeometryDocument?,
    camera: CADCameraState,
    theme: CADViewportTheme,
    isSelected: Bool = false,
    hiddenPartIDs: Set<Int> = [],
    selectedPartIDs: Set<Int> = [],
    groundedPartIDs: Set<Int> = [],
    referenceGeometry: CADWorkspaceReferenceGeometry = .init(
      visibility: .init(), modelDiagonalMeters: 1),
    partTransforms: [CADPartTransformPresentation] = [],
    selectedPartOrigin: CADPartOriginPresentation? = nil,
    onFrame: @escaping @MainActor @Sendable () -> Void = {},
    onError: @escaping @MainActor @Sendable (String) -> Void = { _ in }
  ) {
    self.document = document
    self.camera = camera
    self.theme = theme
    self.isSelected = isSelected
    self.hiddenPartIDs = hiddenPartIDs
    self.selectedPartIDs = selectedPartIDs
    self.groundedPartIDs = groundedPartIDs
    self.referenceGeometry = referenceGeometry
    self.partTransforms = partTransforms
    self.selectedPartOrigin = selectedPartOrigin
    self.onFrame = onFrame
    self.onError = onError
  }

  public var body: some View {
    ZStack {
      MetalCanvas(
        document: document, camera: camera, theme: theme,
        isSelected: isSelected, hiddenPartIDs: hiddenPartIDs, selectedPartIDs: selectedPartIDs,
        groundedPartIDs: groundedPartIDs,
        referenceGeometry: referenceGeometry,
        partTransforms: partTransforms,
        selectedPartOrigin: selectedPartOrigin,
        onFrame: onFrame, onError: onError)
      CADMouseInputOverlay(
        orbit: camera.orbit,
        pan: camera.pan,
        roll: camera.roll,
        zoom: camera.zoom,
        select: {})
    }
  }
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
  let selectedPartOrigin: CADPartOriginPresentation?
  let onFrame: @MainActor @Sendable () -> Void
  let onError: @MainActor @Sendable (String) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onFrame: onFrame, onError: onError) }

  func makeNSView(context: Context) -> MTKView {
    let view = MTKView()
    view.device = MTLCreateSystemDefaultDevice()
    view.colorPixelFormat = .bgra8Unorm
    view.depthStencilPixelFormat = .depth32Float
    view.preferredFramesPerSecond = 120
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
    coordinator.renderer?.set(selectedPartOrigin: selectedPartOrigin)
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
        let renderer = try MetalRenderer(device: device, onFrame: onFrame)
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
  let depthState: MTLDepthStencilState
  let edgeDepthState: MTLDepthStencilState
  let onFrame: @MainActor @Sendable () -> Void
  let uniformBuffer: MTLBuffer
  var camera: CADCameraState
  var theme = CADViewportTheme.studioBlue
  var isSelected = false
  private var vertexBuffer: MTLBuffer?
  private var indexBuffer: MTLBuffer?
  private var edgeVertexBuffer: MTLBuffer?
  private var partTransformBuffer: MTLBuffer?
  private var partTransforms: [CADPartTransformPresentation] = []
  private var partStateBuffer: MTLBuffer?
  private var referenceBuffers: [CADReferenceGeometry: MTLBuffer] = [:]
  private var referenceVertexCounts: [CADReferenceGeometry: Int] = [:]
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
  private let uniformStride: Int
  private var uniformFrameIndex = 0
  private let inFlightSemaphore = DispatchSemaphore(value: 3)

  @MainActor
  init(device: MTLDevice, onFrame: @escaping @MainActor @Sendable () -> Void) throws {
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
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    descriptor.depthAttachmentPixelFormat = .depth32Float
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    let edgeDescriptor = MTLRenderPipelineDescriptor()
    edgeDescriptor.vertexFunction = library.makeFunction(name: "cadVertex")
    edgeDescriptor.fragmentFunction = library.makeFunction(name: "cadEdgeFragment")
    edgeDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    edgeDescriptor.depthAttachmentPixelFormat = .depth32Float
    edgePipeline = try device.makeRenderPipelineState(descriptor: edgeDescriptor)
    let referenceDescriptor = MTLRenderPipelineDescriptor()
    referenceDescriptor.vertexFunction = library.makeFunction(name: "referenceVertex")
    referenceDescriptor.fragmentFunction = library.makeFunction(name: "referenceFragment")
    referenceDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    referenceDescriptor.depthAttachmentPixelFormat = .depth32Float
    referenceDescriptor.colorAttachments[0].isBlendingEnabled = true
    referenceDescriptor.colorAttachments[0].rgbBlendOperation = .add
    referenceDescriptor.colorAttachments[0].alphaBlendOperation = .add
    referenceDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    referenceDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
    referenceDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    referenceDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    referencePipeline = try device.makeRenderPipelineState(descriptor: referenceDescriptor)
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
  }

  func set(document: CADGeometryDocument?) {
    guard document?.identity != documentIdentity else { return }
    documentIdentity = document?.identity
    guard let document else {
      vertexBuffer = nil
      indexBuffer = nil
      edgeVertexBuffer = nil
      partTransformBuffer = nil
      partStateBuffer = nil
      referenceBuffers.removeAll()
      referenceVertexCounts.removeAll()
      selectedPartOriginBuffer = nil
      selectedPartOriginVertexCount = 0
      partSlotCount = 0
      indexCount = 0
      edgeVertexCount = 0
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
    partSlotCount = max(document.nodes.count + 1, 1)
    partTransformBuffer = device.makeBuffer(
      length: partSlotCount * MemoryLayout<simd_float4x4>.stride,
      options: .storageModeShared)
    writePartTransforms()
    // Shared (CPU-writable) so per-part hide/select updates without a rebuild.
    // Default all-zero = every part visible and unselected.
    partStateBuffer = device.makeBuffer(
      length: partSlotCount * MemoryLayout<UInt32>.stride, options: .storageModeShared)
    edgeVertexBuffer = makePrivateBuffer(
      geometry.edgePositions.map {
        Vertex(
          position: $0, normal: .zero, color: SIMD4<UInt8>(repeating: 255),
          partID: 0, faceID: .max)
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
    writePartTransforms()
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
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
      inFlightSemaphore.signal()
      return
    }
    commandBuffer.addCompletedHandler { [inFlightSemaphore] _ in inFlightSemaphore.signal() }
    if let vertexBuffer, let indexBuffer, let partTransformBuffer, let partStateBuffer,
      indexCount > 0
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
        cameraPosition: SIMD4(camera.position, 1),
        keyDirection: lightDirection(theme.key), keyColor: SIMD4(theme.key.color, 1),
        fillDirection: lightDirection(theme.fill), fillColor: SIMD4(theme.fill.color, 1),
        rimDirection: lightDirection(theme.rim), rimColor: SIMD4(theme.rim.color, 1),
        material: SIMD4(
          theme.roughness, theme.metallic, isSelected ? 1 : 0, theme.overrideColor == nil ? 0 : 1),
        edgeColor: SIMD4(isSelected ? theme.edgeSelectionColor : theme.edgeColor, 0.92),
        selectionColor: SIMD4(theme.selectionColor, 1),
        overrideColor: theme.overrideColor ?? .zero)
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
      encoder.drawIndexedPrimitives(
        type: .triangle, indexCount: indexCount, indexType: .uint32,
        indexBuffer: indexBuffer, indexBufferOffset: 0)
      if let edgeVertexBuffer, edgeVertexCount > 0, theme.edgeStrength > 0.02 {
        encoder.setRenderPipelineState(edgePipeline)
        encoder.setDepthStencilState(edgeDepthState)
        encoder.setDepthBias(-1, slopeScale: -1, clamp: 0)
        encoder.setVertexBuffer(edgeVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgeVertexCount)
      }
      encoder.setRenderPipelineState(referencePipeline)
      encoder.setDepthStencilState(edgeDepthState)
      encoder.setDepthBias(0, slopeScale: 0, clamp: 0)
      encoder.setVertexBuffer(uniformBuffer, offset: uniformOffset, index: 1)
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
    }
    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
    DispatchQueue.main.async { [onFrame] in onFrame() }
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

  private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct Vertex { packed_float3 position; packed_float3 normal; uchar4 color; uint partID; uint faceID; };
    struct Uniforms { float4x4 viewProjection; float4 cameraPosition; float4 keyDirection;
      float4 keyColor; float4 fillDirection; float4 fillColor; float4 rimDirection; float4 rimColor;
      float4 material; float4 edgeColor; float4 selectionColor; float4 overrideColor; };
    struct Varying { float4 position [[position]]; float3 normal; float3 world; float4 color; float selected; float grounded; };
    // Per-part state, indexed by partID: bit 0 = hidden, bit 1 = selected, bit 2 = grounded.
    vertex Varying cadVertex(uint id [[vertex_id]], device const Vertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]], device const float4x4 *partTransforms [[buffer(2)]], device const uint *partState [[buffer(3)]]) {
      Vertex v = vertices[id]; float4x4 transform = partTransforms[v.partID];
      uint state = partState[v.partID];
      Varying o;
      if (state & 1u) { o.position = float4(2.0, 2.0, 2.0, 1.0); o.normal = float3(0); o.world = float3(0); o.color = float4(0); o.selected = 0.0; o.grounded = 0.0; return o; }
      float4 world = transform * float4(float3(v.position), 1.0);
      float3x3 normalTransform = float3x3(transform[0].xyz, transform[1].xyz, transform[2].xyz);
      o.world = world.xyz; o.position = u.viewProjection * world;
      o.normal = normalize(normalTransform * float3(v.normal)); o.color = float4(v.color) / 255.0;
      o.selected = (state & 2u) ? 1.0 : 0.0; o.grounded = (state & 4u) ? 1.0 : 0.0; return o;
    }
    fragment float4 cadFragment(Varying in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
      float3 n = normalize(in.normal); float3 view = normalize(u.cameraPosition.xyz - in.world);
      float key = max(dot(n, normalize(u.keyDirection.xyz)), 0.0) * u.keyDirection.w;
      float fill = max(dot(n, normalize(u.fillDirection.xyz)), 0.0) * u.fillDirection.w;
      float rim = pow(1.0 - max(dot(n, view), 0.0), 3.0) * u.rimDirection.w;
      float3 lighting = float3(mix(0.18, 0.34, n.y * 0.5 + 0.5)) + u.keyColor.rgb * key + u.fillColor.rgb * fill * 0.62;
      float3 halfVector = normalize(normalize(u.keyDirection.xyz) + view);
      float highlight = pow(max(dot(n, halfVector), 0.0), mix(96.0, 8.0, clamp(u.material.x, 0.0, 1.0))) * (0.12 + (1.0-u.material.x)*0.42);
      float4 source = u.material.w > 0.5 ? u.overrideColor : in.color;
      float sel = max(u.material.z, in.selected);
      float3 base = mix(source.rgb, u.selectionColor.rgb, sel * 0.42);
      base = mix(base, float3(0.20, 0.62, 0.94), in.grounded * 0.36);
      float3 specular = mix(float3(1.0), source.rgb, clamp(u.material.y, 0.0, 1.0));
      return float4(base * lighting + specular * highlight + u.rimColor.rgb * rim * 0.22, source.a);
    }
    fragment float4 cadEdgeFragment(Varying in [[stage_in]], constant Uniforms &u [[buffer(1)]]) { return u.edgeColor; }
    struct ReferenceVertex { float4 position; float4 color; };
    struct ReferenceVarying { float4 position [[position]]; float4 color; };
    vertex ReferenceVarying referenceVertex(uint id [[vertex_id]], device const ReferenceVertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
      ReferenceVarying o; ReferenceVertex v = vertices[id];
      o.position = u.viewProjection * v.position; o.color = v.color; return o;
    }
    fragment float4 referenceFragment(ReferenceVarying in [[stage_in]]) { return in.color; }
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
