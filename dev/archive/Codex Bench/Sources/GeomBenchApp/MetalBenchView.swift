import GeomBenchCore
import MetalKit
import SwiftUI

struct MetalBenchView: View {
  @Bindable var session: BenchSession
  let document: GeometryDocument?

  var body: some View {
    ZStack {
      MetalCanvas(
        document: document, camera: session.camera, theme: session.theme,
        isSelected: session.isModelSelected
      ) {
        session.tickFrame()
      } onError: { message in
        session.rendererDiagnostic = message
        session.status = "Metal renderer unavailable: \(message)"
      }
      CADInputOverlay(
        orbit: { dx, dy in session.camera.orbit(deltaX: dx, deltaY: dy) },
        pan: { dx, dy, height in session.camera.pan(deltaX: dx, deltaY: dy, viewportHeight: height)
        },
        roll: { delta in session.camera.roll(deltaX: delta) },
        zoom: { delta in session.camera.zoom(scrollDelta: delta) },
        select: { session.toggleModelSelection() })
    }
  }
}

private struct MetalCanvas: NSViewRepresentable {
  let document: GeometryDocument?
  let camera: CADCameraState
  let theme: BenchTheme
  let isSelected: Bool
  let onFrame: @MainActor @Sendable () -> Void
  let onError: @MainActor @Sendable (String) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onFrame: onFrame, onError: onError) }

  func makeNSView(context: Context) -> MTKView {
    let view = MTKView()
    view.device = MTLCreateSystemDefaultDevice()
    // Theme values and STEP/XDE face colors arrive as display-referred sRGB.
    // Using an sRGB attachment here gamma-encoded those values a second time.
    view.colorPixelFormat = .bgra8Unorm
    view.depthStencilPixelFormat = .depth32Float
    view.clearColor = theme.clearColor
    view.preferredFramesPerSecond = 120
    view.enableSetNeedsDisplay = false
    view.isPaused = false
    context.coordinator.attach(view)
    context.coordinator.renderer?.set(document: document)
    context.coordinator.renderer?.camera = camera
    context.coordinator.renderer?.theme = theme
    context.coordinator.renderer?.isSelected = isSelected
    return view
  }

  func updateNSView(_ view: MTKView, context: Context) {
    view.clearColor = theme.clearColor
    context.coordinator.renderer?.camera = camera
    context.coordinator.renderer?.theme = theme
    context.coordinator.renderer?.isSelected = isSelected
    context.coordinator.renderer?.set(document: document)
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
        let value = try MetalRenderer(device: device, onFrame: onFrame)
        renderer = value
        view.delegate = value
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
      position: SIMD3<Float>, normal: SIMD3<Float>, color: SIMD4<UInt8>, partID: UInt32,
      faceID: UInt32
    ) {
      var packedPosition = MTLPackedFloat3()
      packedPosition.x = position.x
      packedPosition.y = position.y
      packedPosition.z = position.z
      var packedNormal = MTLPackedFloat3()
      packedNormal.x = normal.x
      packedNormal.y = normal.y
      packedNormal.z = normal.z
      self.position = packedPosition
      self.normal = packedNormal
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
  var camera = CADCameraState()
  var theme = BenchTheme.studioBlue
  var isSelected = false
  private var vertexBuffer: MTLBuffer?
  private var indexBuffer: MTLBuffer?
  private var indexCount = 0
  private var edgeVertexBuffer: MTLBuffer?
  private var edgeVertexCount = 0
  private var partTransformBuffer: MTLBuffer?
  private var documentIdentity: UUID?
  private var geometryDiagonal: Float = 1
  private let uniformStride: Int
  private var uniformFrameIndex = 0
  private let inFlightSemaphore = DispatchSemaphore(value: 3)

  init(device: MTLDevice, onFrame: @escaping @MainActor @Sendable () -> Void) throws {
    self.device = device
    self.onFrame = onFrame
    guard let queue = device.makeCommandQueue() else { throw MetalRendererError.noQueue }
    commandQueue = queue
    uniformStride = (MemoryLayout<Uniforms>.stride + 255) & ~255
    guard
      let uniformBuffer = device.makeBuffer(
        length: uniformStride * 3, options: .storageModeShared)
    else { throw MetalRendererError.noBuffer }
    self.uniformBuffer = uniformBuffer
    let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "benchVertex")
    descriptor.fragmentFunction = library.makeFunction(name: "benchFragment")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    descriptor.depthAttachmentPixelFormat = .depth32Float
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    let edgeDescriptor = MTLRenderPipelineDescriptor()
    edgeDescriptor.vertexFunction = library.makeFunction(name: "benchVertex")
    edgeDescriptor.fragmentFunction = library.makeFunction(name: "edgeFragment")
    edgeDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    edgeDescriptor.depthAttachmentPixelFormat = .depth32Float
    edgePipeline = try device.makeRenderPipelineState(descriptor: edgeDescriptor)
    let depthDescriptor = MTLDepthStencilDescriptor()
    depthDescriptor.depthCompareFunction = .less
    depthDescriptor.isDepthWriteEnabled = true
    guard let depth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
      throw MetalRendererError.noDepthState
    }
    depthState = depth
    let edgeDepthDescriptor = MTLDepthStencilDescriptor()
    edgeDepthDescriptor.depthCompareFunction = .lessEqual
    edgeDepthDescriptor.isDepthWriteEnabled = false
    guard let edgeDepth = device.makeDepthStencilState(descriptor: edgeDepthDescriptor) else {
      throw MetalRendererError.noDepthState
    }
    edgeDepthState = edgeDepth
  }

  func set(document: GeometryDocument?) {
    guard document?.identity != documentIdentity else { return }
    documentIdentity = document?.identity
    guard let document else {
      vertexBuffer = nil
      indexBuffer = nil
      indexCount = 0
      edgeVertexBuffer = nil
      edgeVertexCount = 0
      partTransformBuffer = nil
      geometryDiagonal = 1
      return
    }
    let geometry = document.renderGeometry
    let vertices = geometry.positions.indices.map { index in
      Vertex(
        position: geometry.positions[index], normal: geometry.normals[index],
        color: geometry.colors[index], partID: geometry.partIDs[index],
        faceID: geometry.faceIDs[index])
    }
    vertexBuffer = makePrivateBuffer(vertices)
    indexBuffer = makePrivateBuffer(geometry.indices)
    indexCount = geometry.indices.count
    geometryDiagonal = max(geometry.bounds.diagonal, 0.001)

    // Index zero represents geometry without an assembly node. Each real node
    // receives a stable slot so animation can update this compact buffer rather
    // than rebuilding vertex data. Imported coordinates are currently already
    // located by Open CASCADE, therefore the initial transforms are identity.
    let partTransforms = Array(
      repeating: matrix_identity_float4x4, count: max(document.nodes.count + 1, 1))
    partTransformBuffer = makePrivateBuffer(partTransforms)

    var edgeVertices: [Vertex] = []
    edgeVertices.reserveCapacity(geometry.edgePositions.count)
    for point in geometry.edgePositions {
      edgeVertices.append(
        Vertex(
          position: point, normal: .zero, color: SIMD4<UInt8>(repeating: 255), partID: 0,
          faceID: UInt32.max))
    }
    edgeVertexBuffer = makePrivateBuffer(edgeVertices)
    edgeVertexCount = edgeVertices.count
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor,
      let commandBuffer = commandQueue.makeCommandBuffer()
    else { return }
    inFlightSemaphore.wait()
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
      inFlightSemaphore.signal()
      return
    }
    commandBuffer.addCompletedHandler { [inFlightSemaphore] _ in inFlightSemaphore.signal() }
    encoder.setRenderPipelineState(pipeline)
    encoder.setDepthStencilState(depthState)
    if let vertexBuffer, let indexBuffer, let partTransformBuffer, indexCount > 0 {
      encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
      let aspect = Float(max(view.drawableSize.width, 1) / max(view.drawableSize.height, 1))
      let radius = max(geometryDiagonal * 0.5, 0.001)
      let near = max(radius * 0.0001, 0.000_01)
      let far = max(camera.distance + radius * 4, radius * 8)
      var uniforms = Uniforms(
        viewProjection: perspective(fovY: 45 * .pi / 180, aspect: aspect, near: near, far: far)
          * lookAt(eye: camera.position, center: camera.target, up: camera.upVector),
        cameraPosition: SIMD4(camera.position, 1),
        keyDirection: lightDirection(theme.key),
        keyColor: SIMD4(theme.key.color, 1),
        fillDirection: lightDirection(theme.fill),
        fillColor: SIMD4(theme.fill.color, 1),
        rimDirection: lightDirection(theme.rim),
        rimColor: SIMD4(theme.rim.color, 1),
        material: SIMD4(
          theme.roughness, theme.metallic, isSelected ? 1 : 0,
          theme.overrideColor == nil ? 0 : 1),
        edgeColor: SIMD4(isSelected ? theme.edgeSelectionColor : theme.edgeColor, 0.92),
        selectionColor: SIMD4(theme.selectionColor, 1),
        overrideColor: theme.overrideColor ?? SIMD4<Float>(repeating: 0))
      let uniformOffset = uniformFrameIndex * uniformStride
      withUnsafeBytes(of: &uniforms) { source in
        uniformBuffer.contents().advanced(by: uniformOffset).copyMemory(
          from: source.baseAddress!, byteCount: source.count)
      }
      uniformFrameIndex = (uniformFrameIndex + 1) % 3
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
        encoder.setVertexBuffer(uniformBuffer, offset: uniformOffset, index: 1)
        encoder.setVertexBuffer(partTransformBuffer, offset: 0, index: 2)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgeVertexCount)
      }
    }
    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
    DispatchQueue.main.async { [onFrame] in onFrame() }
  }

  /// Static CAD buffers live in GPU-private storage. A shared staging buffer
  /// performs the one-time upload; command-queue ordering guarantees later
  /// render passes observe the completed copy without blocking the main actor.
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
      SIMD4(x.x, y.x, z.x, 0), SIMD4(x.y, y.y, z.y, 0), SIMD4(x.z, y.z, z.z, 0),
      SIMD4(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1))
  }

  private func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let y = 1 / tan(fovY * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return simd_float4x4(
      SIMD4(x, 0, 0, 0), SIMD4(0, y, 0, 0), SIMD4(0, 0, z, -1),
      SIMD4(0, 0, z * near, 0))
  }

  private func lightDirection(_ light: BenchTheme.Light) -> SIMD4<Float> {
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
    vertex Varying benchVertex(uint id [[vertex_id]], device const Vertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]], device const float4x4 *partTransforms [[buffer(2)]]) {
      Vertex v = vertices[id]; float4x4 transform = partTransforms[v.partID];
      float4 world = transform * float4(float3(v.position), 1.0);
      float3x3 normalTransform = float3x3(transform[0].xyz, transform[1].xyz, transform[2].xyz);
      Varying o; o.world = world.xyz; o.position = u.viewProjection * world;
      o.normal = normalize(normalTransform * float3(v.normal));
      o.color = float4(v.color) / 255.0; return o;
    }
    fragment float4 benchFragment(Varying in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
      float3 n = normalize(in.normal); float3 view = normalize(u.cameraPosition.xyz - in.world);
      float key = max(dot(n, normalize(u.keyDirection.xyz)), 0.0) * u.keyDirection.w;
      float fill = max(dot(n, normalize(u.fillDirection.xyz)), 0.0) * u.fillDirection.w;
      float rim = pow(1.0 - max(dot(n, view), 0.0), 3.0) * u.rimDirection.w;
      float hemisphere = mix(0.18, 0.34, n.y * 0.5 + 0.5);
      float3 lighting = float3(hemisphere) + u.keyColor.rgb * key + u.fillColor.rgb * fill * 0.62;
      float3 halfVector = normalize(normalize(u.keyDirection.xyz) + view);
      float exponent = mix(96.0, 8.0, clamp(u.material.x, 0.0, 1.0));
      float highlight = pow(max(dot(n, halfVector), 0.0), exponent) * (0.12 + (1.0-u.material.x)*0.42);
      float4 sourceColor = u.material.w > 0.5 ? u.overrideColor : in.color;
      float3 specularColor = mix(float3(1.0), sourceColor.rgb, clamp(u.material.y, 0.0, 1.0));
      float3 baseColor = mix(sourceColor.rgb, u.selectionColor.rgb, u.material.z * 0.38);
      float3 color = baseColor * lighting + specularColor * highlight + u.rimColor.rgb * rim * 0.22;
      return float4(color, sourceColor.a);
    }
    fragment float4 edgeFragment(Varying in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
      return u.edgeColor;
    }
    """
}

extension BenchTheme {
  fileprivate var clearColor: MTLClearColor {
    MTLClearColor(
      red: Double(background.x), green: Double(background.y), blue: Double(background.z), alpha: 1)
  }
}

private enum MetalRendererError: Error { case noQueue, noDepthState, noBuffer }
