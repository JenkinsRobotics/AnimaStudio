import Testing

@testable import GeomBenchApp

@Test func consolidatedThemeCatalogContainsAllTenLooks() {
  #expect(BenchTheme.all.count == 10)
  #expect(Set(BenchTheme.all.map(\.name)).count == 10)
  #expect(BenchTheme.named("Onshape") == .onshape)
  #expect(BenchTheme.named("Midnight Glow") == .midnight)
}

@Test func cadApplicationThemesCanOverrideImportedColorWithoutChangingSourceData() {
  let imported = SIMD4<Float>(0.1, 0.2, 0.3, 1)
  #expect(BenchTheme.studioBlue.displayColor(for: imported) == imported)
  #expect(BenchTheme.onshape.displayColor(for: imported) == BenchTheme.onshape.overrideColor)
  #expect(BenchTheme.clay.edgeStrength == 0)
  #expect(BenchTheme.blueprint.edgeStrength == 1)
}
