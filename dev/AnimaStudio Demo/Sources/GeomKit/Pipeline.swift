import Foundation

public enum PipelineRole: String, Codable, Sendable, CaseIterable {
  case productionCandidate
  case secondaryAppleRenderer
  case browserRendererCandidate
  case optionalEnvironmentRenderer

  public var label: String {
    switch self {
    case .productionCandidate: "Production candidate"
    case .secondaryAppleRenderer: "Secondary Apple renderer"
    case .browserRendererCandidate: "Browser renderer candidate"
    case .optionalEnvironmentRenderer: "Optional environment renderer"
    }
  }

  public var detail: String {
    switch self {
    case .productionCandidate:
      "Primary native CAD and animatronic viewport candidate."
    case .secondaryAppleRenderer:
      "Retained for Apple scene, spatial, audio, and media integration comparisons."
    case .browserRendererCandidate:
      "Direct modern browser-GPU renderer without a scene-framework dependency."
    case .optionalEnvironmentRenderer:
      "Retained for portable virtual stages and browser-hosted extensions."
    }
  }
}

public enum PipelineID: Int, CaseIterable, Codable, Identifiable, Sendable {
  case occtRealityKit = 1
  case occtMetalKit = 2
  case threeJSWebGPU = 7
  case openCascadeWebGPU = 10

  public var id: Int { rawValue }

  public var shortName: String {
    switch self {
    case .occtRealityKit: "Open CASCADE Technology → Apple RealityKit"
    case .occtMetalKit: "Open CASCADE Technology → Apple MetalKit"
    case .threeJSWebGPU: "Open CASCADE Technology → Three.js → WebGPU"
    case .openCascadeWebGPU: "Open CASCADE Technology → Swift → Raw WebGPU"
    }
  }

  public var contributor: String {
    "Codex"
  }

  public var role: PipelineRole {
    switch self {
    case .occtMetalKit: .productionCandidate
    case .occtRealityKit: .secondaryAppleRenderer
    case .openCascadeWebGPU: .browserRendererCandidate
    case .threeJSWebGPU: .optionalEnvironmentRenderer
    }
  }

  public var comparisonName: String { "\(contributor) · \(shortName)" }

  public var detail: String {
    switch self {
    case .occtRealityKit:
      "Open CASCADE Technology Extended Data Exchange B-Rep extraction, Swift mesh projection, Apple RealityKit scene graph"
    case .occtMetalKit:
      "Open CASCADE Technology Extended Data Exchange B-Rep extraction into contiguous Apple Metal buffers"
    case .threeJSWebGPU:
      "Open CASCADE Technology B-Rep extraction rendered by Three.js WebGPU inside Swift WKWebView, with a reported WebGL 2 fallback"
    case .openCascadeWebGPU:
      "Open CASCADE Technology B-Rep extraction rendered directly with navigator.gpu and WGSL inside Swift WKWebView"
    }
  }

  public var supportedFilenameExtensions: [String] {
    switch self {
    case .occtRealityKit, .occtMetalKit, .threeJSWebGPU, .openCascadeWebGPU:
      ["step", "stp"]
    }
  }

  public var acceptsSTEP: Bool { supportedFilenameExtensions.contains("step") }
  public var preservesBRep: Bool { true }
}

public struct PipelineCapability: Identifiable, Sendable, Equatable {
  public let pipeline: PipelineID
  public let available: Bool
  public let reason: String
  public var id: PipelineID { pipeline }

  public init(pipeline: PipelineID, available: Bool, reason: String) {
    self.pipeline = pipeline
    self.available = available
    self.reason = reason
  }
}

public enum CapabilityProbe {
  public static func all() -> [PipelineCapability] {
    return PipelineID.allCases.map { pipeline in
      switch pipeline {
      case .occtRealityKit, .occtMetalKit, .threeJSWebGPU, .openCascadeWebGPU:
        return PipelineCapability(
          pipeline: pipeline, available: true, reason: "Built into Codex Bench")
      }
    }
  }
}
