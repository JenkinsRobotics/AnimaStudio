import Foundation
import GeomBenchCore
import Testing

@testable import GeomBenchApp

@Test func customRendererThemeRoundTripsThroughPreferencesPayload() throws {
  var theme = BenchTheme.onshape
  theme.background = [0.08, 0.10, 0.14]
  theme.overrideColor = [0.3, 0.5, 0.8, 1]
  theme.roughness = 0.27
  theme.edgeStrength = 0.82
  theme.key.color = [1.0, 0.82, 0.64]
  theme.key.intensity = 4_650

  let encoded = try JSONEncoder().encode(theme)
  let decoded = try JSONDecoder().decode(BenchTheme.self, from: encoded)

  #expect(decoded == theme)
  #expect(decoded.isCustomized)
}

@Test func uneditedThemePresetIsNotMarkedCustom() {
  #expect(!BenchTheme.studioBlue.isCustomized)
  #expect(!BenchTheme.midnight.isCustomized)
}

@MainActor @Test func rendererAndCustomThemePersistAcrossSessions() {
  let suiteName = "CodexBenchSettingsTests.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defer { defaults.removePersistentDomain(forName: suiteName) }

  let first = BenchSession(defaults: defaults)
  first.switchPipeline(.threeJSWebGPU)
  first.setTheme(.onshape)
  first.updateTheme {
    $0.edgeStrength = 0.91
    $0.fill.intensity = 3_250
  }

  let reopened = BenchSession(defaults: defaults)
  #expect(reopened.pipeline == .threeJSWebGPU)
  #expect(reopened.theme.name == BenchTheme.onshape.name)
  #expect(reopened.theme.edgeStrength == 0.91)
  #expect(reopened.theme.fill.intensity == 3_250)
  #expect(reopened.theme.isCustomized)
}

@MainActor @Test func retiredPipelinePreferencesFallBackToRealityKit() {
  for rawValue in [3, 4, 5, 6, 8, 9] {
    let suiteName = "CodexBenchRetiredPipelineTests.\(rawValue).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(rawValue, forKey: "CodexBenchPipeline")
    let reopened = BenchSession(defaults: defaults)

    #expect(reopened.pipeline == .occtRealityKit)
  }
}

@MainActor @Test func switchingRendererReusesTheImportedGeometryDocument() throws {
  let suiteName = "CodexBenchReuseTests.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defer { defaults.removePersistentDomain(forName: suiteName) }
  let session = BenchSession(defaults: defaults)
  let document = try GeometryDocument.demo()
  session.document = document

  session.switchPipeline(.occtMetalKit)

  #expect(session.pipeline == .occtMetalKit)
  #expect(session.document?.identity == document.identity)
  #expect(session.status.hasPrefix("Reusing one Open CASCADE import"))
}
