import AnimaCADShim
import Foundation

/// The four renderer paths retained after the Codex Bench comparison.
/// All consume the same Open CASCADE/XDE geometry document, so changing the
/// backend never changes imported topology or project data.
public enum CADRenderBackend: String, CaseIterable, Codable, Identifiable, Sendable {
  case metalKit = "open-cascade-metal-kit"
  case realityKit = "open-cascade-reality-kit"
  case threeJSWebGPU = "open-cascade-three-js-web-gpu"
  case rawWebGPU = "open-cascade-raw-web-gpu"

  public var id: Self { self }

  public var title: String {
    switch self {
    case .metalKit: "Open CASCADE → MetalKit"
    case .realityKit: "Open CASCADE → RealityKit"
    case .threeJSWebGPU: "Open CASCADE → Three.js WebGPU"
    case .rawWebGPU: "Open CASCADE → Raw WebGPU"
    }
  }

  public var role: String {
    switch self {
    case .metalKit: "Primary CAD renderer"
    case .realityKit: "Spatial, media, and interaction renderer"
    case .threeJSWebGPU: "Optional virtual-stage renderer"
    case .rawWebGPU: "Experimental browser-GPU renderer"
    }
  }

  public var detail: String {
    switch self {
    case .metalKit:
      "Retained native GPU buffers, exact B-Rep edge pass, and per-part transform slots."
    case .realityKit:
      "Apple scene graph used by Studio's current selection, gizmo, audio, video, and spatial tools."
    case .threeJSWebGPU:
      "Three.js WebGPURenderer in Apple WebKit, with an explicitly reported WebGL 2 fallback."
    case .rawWebGPU:
      "Direct navigator.gpu/WGSL diagnostic path without a JavaScript scene framework."
    }
  }

  public var isPreferredSTEPVisualization: Bool { self == .metalKit }
  public var supportsNativeStudioInteraction: Bool { self == .realityKit }
}

public enum CADGeometryKernel {
  public static var version: String {
    String(cString: anima_cad_open_cascade_version())
  }
}
