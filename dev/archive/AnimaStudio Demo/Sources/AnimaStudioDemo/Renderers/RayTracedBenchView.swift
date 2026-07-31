// Hardware ray-traced viewport (Apple Silicon, Metal). Builds a primitive
// acceleration structure from the imported STEP mesh and traces primary +
// shadow rays in a compute kernel — true ray-traced contact shadows, shaded
// with the shared theme. Falls back to the Metal raster view if the device
// can't ray trace. Iteration 1: correctness over polish.
import GeomKit
import MetalKit
import SwiftUI
import simd

struct RayTracedBenchView: View {
  let session: BenchSession
  let document: GeometryDocument?

  var body: some View {
    if MTLCreateSystemDefaultDevice()?.supportsRaytracing == true {
      RayTracedCanvas(session: session, document: document)
    } else {
      MetalBenchView(session: session, document: document)   // graceful fallback
    }
  }
}

private struct RayTracedCanvas: NSViewRepresentable {
  let session: BenchSession
  let document: GeometryDocument?

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> MTKView {
    let view = MTKView()
    view.device = MTLCreateSystemDefaultDevice()
    view.colorPixelFormat = .bgra8Unorm
    view.framebufferOnly = false                 // compute writes straight to the drawable
    view.clearColor = MTLClearColorMake(0, 0, 0, 1)
    if let device = view.device, let tracer = try? RayTracer(device: device) {
      context.coordinator.tracer = tracer
      view.delegate = context.coordinator
      tracer.set(document: document)
    }
    return view
  }

  func updateNSView(_ view: MTKView, context: Context) {
    context.coordinator.tracer?.camera = session.camera
    context.coordinator.tracer?.theme = session.theme
    context.coordinator.tracer?.set(document: document)
    view.setNeedsDisplay(view.bounds)
  }

  final class Coordinator: NSObject, MTKViewDelegate {
    var tracer: RayTracer?
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) { tracer?.draw(in: view) }
  }
}

// Uniforms — all float4 so Swift/MSL layouts match exactly (SIMD4 = 16 bytes).
private struct RTUniforms {
  var camPos: SIMD4<Float> = .zero
  var forward: SIMD4<Float> = .zero    // w = tan(halfFov)
  var right: SIMD4<Float> = .zero      // w = aspect
  var up: SIMD4<Float> = .zero
  var keyDir: SIMD4<Float> = .zero
  var keyColor: SIMD4<Float> = .zero
  var fillColor: SIMD4<Float> = .zero
  var background: SIMD4<Float> = .zero
  var dims: SIMD2<UInt32> = .zero
  var pad: SIMD2<UInt32> = .zero
}

final class RayTracer: NSObject, @unchecked Sendable {
  var camera = CADCameraState()
  var theme = BenchTheme.studioBlue

  private let device: MTLDevice
  private let queue: MTLCommandQueue
  private let pipeline: MTLComputePipelineState
  private var accel: MTLAccelerationStructure?
  private var normalsBuffer: MTLBuffer?
  private var colorsBuffer: MTLBuffer?
  private var indexBuffer: MTLBuffer?
  private var indexCount = 0
  private var documentIdentity: UUID?
  private var diagonal: Float = 1

  init(device: MTLDevice) throws {
    self.device = device
    guard let queue = device.makeCommandQueue() else { throw Err.noQueue }
    self.queue = queue
    let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
    guard let fn = library.makeFunction(name: "rtKernel") else { throw Err.noFunction }
    pipeline = try device.makeComputePipelineState(function: fn)
  }

  enum Err: Error { case noQueue, noFunction }

  func set(document: GeometryDocument?) {
    guard document?.identity != documentIdentity else { return }
    documentIdentity = document?.identity
    guard let document else { accel = nil; indexCount = 0; return }
    let g = document.renderGeometry
    guard !g.positions.isEmpty, !g.indices.isEmpty else { accel = nil; indexCount = 0; return }
    diagonal = max(g.bounds.diagonal, 0.001)

    let posBuffer = device.makeBuffer(
      bytes: g.positions, length: g.positions.count * MemoryLayout<SIMD3<Float>>.stride)!
    indexBuffer = device.makeBuffer(
      bytes: g.indices, length: g.indices.count * MemoryLayout<UInt32>.stride)
    indexCount = g.indices.count
    normalsBuffer = device.makeBuffer(
      bytes: g.normals, length: g.normals.count * MemoryLayout<SIMD3<Float>>.stride)
    colorsBuffer = device.makeBuffer(
      bytes: g.colors, length: g.colors.count * MemoryLayout<SIMD4<UInt8>>.stride)

    let geo = MTLAccelerationStructureTriangleGeometryDescriptor()
    geo.vertexBuffer = posBuffer
    geo.vertexStride = MemoryLayout<SIMD3<Float>>.stride
    geo.vertexFormat = .float3
    geo.indexBuffer = indexBuffer
    geo.indexType = .uint32
    geo.triangleCount = indexCount / 3
    let desc = MTLPrimitiveAccelerationStructureDescriptor()
    desc.geometryDescriptors = [geo]

    let sizes = device.accelerationStructureSizes(descriptor: desc)
    guard let structure = device.makeAccelerationStructure(size: sizes.accelerationStructureSize),
      let scratch = device.makeBuffer(length: max(sizes.buildScratchBufferSize, 1), options: .storageModePrivate),
      let cb = queue.makeCommandBuffer(),
      let enc = cb.makeAccelerationStructureCommandEncoder()
    else { accel = nil; return }
    enc.build(accelerationStructure: structure, descriptor: desc, scratchBuffer: scratch, scratchBufferOffset: 0)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()
    accel = structure
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable, let cb = queue.makeCommandBuffer() else { return }
    let width = Int(view.drawableSize.width), height = Int(view.drawableSize.height)
    guard width > 0, height > 0 else { return }

    // Background fill so a miss (or no geometry) shows the theme color, not black.
    var u = RTUniforms()
    let bg = theme.background
    u.background = SIMD4(bg.x, bg.y, bg.z, 1)
    let fwd = simd_normalize(camera.target - camera.position)
    let right = simd_normalize(simd_cross(fwd, camera.upVector))
    let up = simd_cross(right, fwd)
    u.camPos = SIMD4(camera.position, 1)
    u.forward = SIMD4(fwd, tan(22.5 * .pi / 180))
    u.right = SIMD4(right, Float(width) / Float(max(height, 1)))
    u.up = SIMD4(up, 0)
    u.keyDir = SIMD4(simd_normalize(theme.key.directionFrom), 0)
    u.keyColor = SIMD4(theme.key.color * (theme.key.intensity / 3000), 1)
    u.fillColor = SIMD4(theme.fill.color * (theme.fill.intensity / 3000), 1)
    u.dims = SIMD2(UInt32(width), UInt32(height))

    guard let enc = cb.makeComputeCommandEncoder() else { return }
    enc.setComputePipelineState(pipeline)
    enc.setTexture(drawable.texture, index: 0)
    enc.setBytes(&u, length: MemoryLayout<RTUniforms>.stride, index: 0)
    if let accel { enc.setAccelerationStructure(accel, bufferIndex: 1) }
    enc.setBuffer(normalsBuffer, offset: 0, index: 2)
    enc.setBuffer(colorsBuffer, offset: 0, index: 3)
    enc.setBuffer(indexBuffer, offset: 0, index: 4)
    let w = pipeline.threadExecutionWidth
    let h = max(pipeline.maxTotalThreadsPerThreadgroup / w, 1)
    enc.dispatchThreads(
      MTLSize(width: width, height: height, depth: 1),
      threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1))
    enc.endEncoding()
    cb.present(drawable)
    cb.commit()
  }

  static let shaderSource = """
  #include <metal_stdlib>
  #include <metal_raytracing>
  using namespace metal;
  using namespace raytracing;

  struct RTUniforms {
    float4 camPos;
    float4 forward;   // w = tanHalfFov
    float4 right;     // w = aspect
    float4 up;
    float4 keyDir;
    float4 keyColor;
    float4 fillColor;
    float4 background;
    uint2 dims;
    uint2 pad;
  };

  kernel void rtKernel(
      texture2d<float, access::write> out [[texture(0)]],
      constant RTUniforms &u [[buffer(0)]],
      primitive_acceleration_structure accel [[buffer(1)]],
      device const float3 *normals [[buffer(2)]],
      device const uchar4 *colors [[buffer(3)]],
      device const uint *indices [[buffer(4)]],
      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= u.dims.x || gid.y >= u.dims.y) return;
    float2 px = (float2(gid) + 0.5) / float2(u.dims);
    float2 ndc = float2(px.x * 2.0 - 1.0, 1.0 - px.y * 2.0);
    float3 dir = normalize(u.forward.xyz
      + ndc.x * u.forward.w * u.right.w * u.right.xyz
      + ndc.y * u.forward.w * u.up.xyz);

    ray r;
    r.origin = u.camPos.xyz;
    r.direction = dir;
    r.min_distance = 0.0005;
    r.max_distance = 1e4;

    intersector<triangle_data> isect;
    isect.assume_geometry_type(geometry_type::triangle);
    auto hit = isect.intersect(r, accel);

    float3 color = u.background.xyz;
    if (hit.type == intersection_type::triangle) {
      uint p = hit.primitive_id;
      uint i0 = indices[p * 3], i1 = indices[p * 3 + 1], i2 = indices[p * 3 + 2];
      float2 bc = hit.triangle_barycentric_coord;
      float3 n = normalize(normals[i0] * (1.0 - bc.x - bc.y) + normals[i1] * bc.x + normals[i2] * bc.y);
      float3 albedo = float3(colors[i0].xyz) / 255.0;
      float3 hitPos = r.origin + r.direction * hit.distance;

      // Ray-traced shadow toward the key light.
      float3 L = normalize(u.keyDir.xyz);
      ray sray;
      sray.origin = hitPos + n * 0.002;
      sray.direction = L;
      sray.min_distance = 0.001;
      sray.max_distance = 1e4;
      auto shadowHit = isect.intersect(sray, accel);
      float shadow = (shadowHit.type == intersection_type::triangle) ? 0.25 : 1.0;

      float ndl = max(dot(n, L), 0.0);
      float3 lit = albedo * (u.keyColor.xyz * ndl * shadow + u.fillColor.xyz * 0.35 + 0.12);
      color = lit;
    }
    out.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
  }
  """
}
