import AnimaCAD
import MetalKit
import SwiftUI

public struct CADMetalViewport: View {
  public let document: CADGeometryDocument?
  @Bindable public var camera: CADCameraState
  public let theme: CADViewportTheme
  public let isSelected: Bool
  public let onFrame: @MainActor @Sendable () -> Void
  public let onError: @MainActor @Sendable (String) -> Void

  public init(
    document: CADGeometryDocument?,
    camera: CADCameraState,
    theme: CADViewportTheme,
    isSelected: Bool = false,
    onFrame: @escaping @MainActor @Sendable () -> Void = {},
    onError: @escaping @MainActor @Sendable (String) -> Void = { _ in }
  ) {
    self.document = document
    self.camera = camera
    self.theme = theme
    self.isSelected = isSelected
    self.onFrame = onFrame
    self.onError = onError
  }

  public var body: some View {
    ZStack {
      MetalCanvas(
        document: document, camera: camera, theme: theme,
        isSelected: isSelected, onFrame: onFrame, onError: onError)
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

  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  let pipeline: MTLRenderPipelineState
  let edgePipeline: MTLRenderPipelineState
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
    partTransformBuffer = makePrivateBuffer(
      Array(repeating: matrix_identity_float4x4, count: max(document.nodes.count + 1, 1)))
    edgeVertexBuffer = makePrivateBuffer(
      geometry.edgePositions.map {
        Vertex(
          position: $0, normal: .zero, color: SIMD4<UInt8>(repeating: 255),
          partID: 0, faceID: .max)
      })
    edgeVertexCount = geometry.edgePositions.count
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
    if let vertexBuffer, let indexBuffer, let partTransformBuffer, indexCount > 0 {
      let aspect = Float(max(view.drawableSize.width, 1) / max(view.drawableSize.height, 1))
      let radius = max(geometryDiagonal * 0.5, 0.001)
      var uniforms = Uniforms(
        viewProjection: perspective(
          fovY: 45 * .pi / 180, aspect: aspect,
          near: max(radius * 0.0001, 0.000_01),
          far: max(camera.distance + radius * 4, radius * 8))
          * lookAt(eye: camera.position, center: camera.target, up: camera.upVector),
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

  private func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let z = simd_normalize(eye - center)
    let x = simd_normalize(simd_cross(up, z))
    let y = simd_cross(z, x)
    return simd_float4x4(
      SIMD4(x.x, y.x, z.x, 0), SIMD4(x.y, y.y, z.y, 0),
      SIMD4(x.z, y.z, z.z, 0), SIMD4(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1))
  }

  private func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let y = 1 / tan(fovY * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return simd_float4x4(
      SIMD4(x, 0, 0, 0), SIMD4(0, y, 0, 0),
      SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0))
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
    struct Varying { float4 position [[position]]; float3 normal; float3 world; float4 color; };
    vertex Varying cadVertex(uint id [[vertex_id]], device const Vertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]], device const float4x4 *partTransforms [[buffer(2)]]) {
      Vertex v = vertices[id]; float4x4 transform = partTransforms[v.partID];
      float4 world = transform * float4(float3(v.position), 1.0);
      float3x3 normalTransform = float3x3(transform[0].xyz, transform[1].xyz, transform[2].xyz);
      Varying o; o.world = world.xyz; o.position = u.viewProjection * world;
      o.normal = normalize(normalTransform * float3(v.normal)); o.color = float4(v.color) / 255.0; return o;
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
      float3 base = mix(source.rgb, u.selectionColor.rgb, u.material.z * 0.38);
      float3 specular = mix(float3(1.0), source.rgb, clamp(u.material.y, 0.0, 1.0));
      return float4(base * lighting + specular * highlight + u.rimColor.rgb * rim * 0.22, source.a);
    }
    fragment float4 cadEdgeFragment(Varying in [[stage_in]], constant Uniforms &u [[buffer(1)]]) { return u.edgeColor; }
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
