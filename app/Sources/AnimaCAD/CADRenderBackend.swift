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

  /// Default CAD render engine. Three.js WebGPU is the modern web path and
  /// falls back to WebGL 2 automatically where WebGPU is unavailable.
  public static let defaultBackend: CADRenderBackend = .threeJSWebGPU

  /// Engines offered in the picker. RealityKit is retired as a *CAD* backend
  /// (it fails large STEP assemblies — see Codex Bench 2026-07-19); it is kept
  /// internally only for non-CAD mesh/spatial preview, not selected here.
  public static var selectable: [CADRenderBackend] {
    allCases.filter { $0 != .realityKit }
  }

  /// Coerces a stored/retired backend onto a selectable one, migrating users
  /// off the old RealityKit CAD default.
  public var selectableOrDefault: CADRenderBackend {
    Self.selectable.contains(self) ? self : Self.defaultBackend
  }
}

public enum CADGeometryKernel {
  public static var version: String {
    String(cString: anima_cad_open_cascade_version())
  }
}
