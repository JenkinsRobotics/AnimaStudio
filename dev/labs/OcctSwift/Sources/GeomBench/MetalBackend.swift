// PIPELINE 2 — OCCT shim -> Swift -> custom MetalKit renderer.
// No scene graph: the shim's flat vertex/normal/color/index arrays go into
// raw MTLBuffers and one hand-written render pipeline. Absolute control,
// zero RealityKit involvement.
import MetalKit
import SwiftUI
import simd

private let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
  float4x4 viewProjection;
  float3 cameraPosition;
};

struct VertexOut {
  float4 position [[position]];
  float3 worldPosition;
  float3 normal;
  float3 color;
};

vertex VertexOut vertexMain(
    uint vid [[vertex_id]],
    device const packed_float3 *positions [[buffer(0)]],
    device const packed_float3 *normals [[buffer(1)]],
    device const packed_float3 *colors [[buffer(2)]],
    constant Uniforms &uniforms [[buffer(3)]]) {
  VertexOut out;
  float3 p = float3(positions[vid]);
  out.position = uniforms.viewProjection * float4(p, 1.0);
  out.worldPosition = p;
  out.normal = float3(normals[vid]);
  out.color = float3(colors[vid]);
  return out;
}

fragment float4 fragmentMain(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(3)]]) {
  float3 n = normalize(in.normal);
  float3 toCamera = normalize(uniforms.cameraPosition - in.worldPosition);
  if (dot(n, toCamera) < 0.0) { n = -n; }  // shade back faces sanely
  float3 key = normalize(float3(0.5, 0.9, 0.6));
  float3 fill = normalize(float3(-0.7, 0.3, 0.4));
  float diffuse = max(dot(n, key), 0.0) * 0.75 + max(dot(n, fill), 0.0) * 0.3;
  float3 halfway = normalize(key + toCamera);
  float specular = pow(max(dot(n, halfway), 0.0), 48.0) * 0.35;
  float3 shaded = in.color * (0.18 + diffuse) + float3(specular);
  return float4(shaded, 1.0);
}
"""

struct MetalUniforms {
  var viewProjection: simd_float4x4
  var cameraPosition: SIMD3<Float>
}

@MainActor
final class MetalMeshBuffers {
  let positions: MTLBuffer
  let normals: MTLBuffer
  let colors: MTLBuffer
  let indices: MTLBuffer
  let indexCount: Int

  init?(device: MTLDevice, mesh: GpuMeshData) {
    guard !mesh.indices.isEmpty,
      let positionBuffer = device.makeBuffer(
        bytes: mesh.positions, length: mesh.positions.count * 4),
      let normalBuffer = device.makeBuffer(
        bytes: mesh.normals, length: mesh.normals.count * 4),
      let colorBuffer = device.makeBuffer(
        bytes: mesh.colors, length: mesh.colors.count * 4),
      let indexBuffer = device.makeBuffer(
        bytes: mesh.indices, length: mesh.indices.count * 4)
    else { return nil }
    positions = positionBuffer
    normals = normalBuffer
    colors = colorBuffer
    indices = indexBuffer
    indexCount = mesh.indices.count
  }
}

@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
  let model: BenchModel
  let device: MTLDevice
  let queue: MTLCommandQueue
  var pipeline: MTLRenderPipelineState?
  var depthState: MTLDepthStencilState?
  var meshes: [MetalMeshBuffers] = []
  var builtRevision = -1

  init?(model: BenchModel) {
    guard let device = MTLCreateSystemDefaultDevice(),
      let queue = device.makeCommandQueue()
    else { return nil }
    self.model = model
    self.device = device
    self.queue = queue
    super.init()
    do {
      let library = try device.makeLibrary(source: shaderSource, options: nil)
      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
      descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
      descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
      descriptor.depthAttachmentPixelFormat = .depth32Float
      pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    } catch {
      print("Metal pipeline error: \(error)")
      return nil
    }
    let depthDescriptor = MTLDepthStencilDescriptor()
    depthDescriptor.depthCompareFunction = .less
    depthDescriptor.isDepthWriteEnabled = true
    depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
  }

  nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  nonisolated func draw(in view: MTKView) {
    MainActor.assumeIsolated {
      drawOnMain(in: view)
    }
  }

  private func drawOnMain(in view: MTKView) {
    if builtRevision != model.gpuRevision {
      meshes = model.gpuMeshes.compactMap { MetalMeshBuffers(device: device, mesh: $0) }
      builtRevision = model.gpuRevision
    }
    guard let pipeline, let depthState,
      let descriptor = view.currentRenderPassDescriptor,
      let drawable = view.currentDrawable,
      let commands = queue.makeCommandBuffer(),
      let encoder = commands.makeRenderCommandEncoder(descriptor: descriptor)
    else { return }

    let aspect = Float(view.drawableSize.width / max(view.drawableSize.height, 1))
    let projection = perspectiveMatrix(fovYRadians: 0.9, aspect: aspect, near: 0.005, far: 50)
    let viewMatrix = lookAtMatrix(
      eye: model.cameraPosition, center: model.cameraTarget, up: SIMD3<Float>(0, 1, 0))
    var uniforms = MetalUniforms(
      viewProjection: projection * viewMatrix, cameraPosition: model.cameraPosition)

    encoder.setRenderPipelineState(pipeline)
    encoder.setDepthStencilState(depthState)
    for mesh in meshes {
      encoder.setVertexBuffer(mesh.positions, offset: 0, index: 0)
      encoder.setVertexBuffer(mesh.normals, offset: 0, index: 1)
      encoder.setVertexBuffer(mesh.colors, offset: 0, index: 2)
      encoder.setVertexBytes(&uniforms, length: MemoryLayout<MetalUniforms>.stride, index: 3)
      encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MetalUniforms>.stride, index: 3)
      encoder.drawIndexedPrimitives(
        type: .triangle, indexCount: mesh.indexCount, indexType: .uint32,
        indexBuffer: mesh.indices, indexBufferOffset: 0)
    }
    encoder.endEncoding()
    commands.present(drawable)
    commands.commit()
    model.frameCount += 1
  }
}

func perspectiveMatrix(fovYRadians: Float, aspect: Float, near: Float, far: Float)
  -> simd_float4x4
{
  let y = 1 / tan(fovYRadians * 0.5)
  let x = y / aspect
  let z = far / (near - far)
  return simd_float4x4(
    SIMD4<Float>(x, 0, 0, 0),
    SIMD4<Float>(0, y, 0, 0),
    SIMD4<Float>(0, 0, z, -1),
    SIMD4<Float>(0, 0, z * near, 0))
}

func lookAtMatrix(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>)
  -> simd_float4x4
{
  let forward = simd_normalize(center - eye)
  let right = simd_normalize(simd_cross(forward, up))
  let realUp = simd_cross(right, forward)
  let translation = SIMD3<Float>(
    -simd_dot(right, eye), -simd_dot(realUp, eye), simd_dot(forward, eye))
  return simd_float4x4(
    SIMD4<Float>(right.x, realUp.x, -forward.x, 0),
    SIMD4<Float>(right.y, realUp.y, -forward.y, 0),
    SIMD4<Float>(right.z, realUp.z, -forward.z, 0),
    SIMD4<Float>(translation.x, translation.y, translation.z, 1))
}

struct MetalViewport: NSViewRepresentable {
  let model: BenchModel

  func makeCoordinator() -> MetalRenderer? {
    MetalRenderer(model: model)
  }

  func makeNSView(context: Context) -> MTKView {
    let view = MTKView()
    view.device = context.coordinator?.device
    view.delegate = context.coordinator
    view.depthStencilPixelFormat = .depth32Float
    view.clearColor = MTLClearColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
    view.preferredFramesPerSecond = 120
    return view
  }

  func updateNSView(_ view: MTKView, context: Context) {
    let bg = model.theme.background
    view.clearColor = MTLClearColor(
      red: Double(bg.x), green: Double(bg.y), blue: Double(bg.z), alpha: 1)
  }
}
