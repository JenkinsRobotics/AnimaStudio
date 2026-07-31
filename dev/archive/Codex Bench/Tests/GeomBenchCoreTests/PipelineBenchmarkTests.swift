import Foundation
import GeomBenchCore
import Testing

@testable import GeomBenchApp

@Test func benchmarkConfigurationParsesAndBoundsCommandLineValues() {
  let configuration = PipelineBenchmarkConfiguration.parse(arguments: [
    "GeomBench", "--benchmark-output", "/tmp/result.json", "--benchmark-warmup", "0",
    "--benchmark-duration", "1",
  ])

  #expect(configuration?.outputURL.path == "/tmp/result.json")
  #expect(configuration?.warmupSeconds == 1)
  #expect(configuration?.durationSeconds == 2)
  #expect(PipelineBenchmarkConfiguration.parse(arguments: ["GeomBench"]) == nil)
}

@Test func benchmarkScopeCallsOutWebKitAccounting() {
  #expect(PipelineID.threeJSWebGPU.benchmarkCaveats.contains { $0.contains("WebKit") })
  #expect(PipelineID.openCascadeWebGPU.benchmarkCaveats.contains { $0.contains("WebKit") })
  #expect(
    PipelineID.threeJSWebGPU.benchmarkCaveats.contains { $0.contains("rendererBackend") })
  #expect(PipelineID.allCases.allSatisfy { !$0.benchmarkCaveats.joined().contains("Qt") })
  #expect(PipelineID.allCases.allSatisfy { !$0.shortName.contains("OpenGeometry") })
  #expect(
    PipelineID.occtRealityKit.benchmarkCaveats.contains { $0.contains("display-link") })
}
