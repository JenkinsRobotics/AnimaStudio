import AnimaCADViewport
import Foundation
import Testing

@testable import AnimaStudioUI

@Test func coordinatedCADPresetWritesItsWholeEnvironmentAndClearsColorOverrides() throws {
  let suiteName = "CADThemePreferencesTests-\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }

  defaults.set("#123456", forKey: StudioPreferenceKey.cadBackgroundColorHex)
  defaults.set("#654321", forKey: StudioPreferenceKey.cadEdgeColorHex)
  CADThemePreferences.applyPreset(named: CADViewportTheme.onshape.name, to: defaults)

  let theme = CADViewportTheme.onshape
  #expect(defaults.string(forKey: StudioPreferenceKey.cadThemeName) == theme.name)
  #expect(
    defaults.double(forKey: StudioPreferenceKey.cadEdgeStrength)
      == Double(theme.edgeStrength))
  #expect(
    defaults.double(forKey: StudioPreferenceKey.cadAmbientStrength)
      == Double(theme.ambientStrength))
  #expect(
    defaults.double(forKey: StudioPreferenceKey.cadShadowStrength)
      == Double(theme.shadowStrength))
  #expect(defaults.double(forKey: StudioPreferenceKey.cadRoughness) == Double(theme.roughness))
  #expect(defaults.double(forKey: StudioPreferenceKey.cadMetallic) == Double(theme.metallic))
  #expect(
    defaults.double(forKey: StudioPreferenceKey.cadKeyLightIntensity)
      == Double(theme.key.intensity))
  #expect(
    defaults.double(forKey: StudioPreferenceKey.cadFillLightIntensity)
      == Double(theme.fill.intensity))
  #expect(
    defaults.double(forKey: StudioPreferenceKey.cadRimLightIntensity)
      == Double(theme.rim.intensity))
  #expect(defaults.object(forKey: StudioPreferenceKey.cadBackgroundColorHex) == nil)
  #expect(defaults.object(forKey: StudioPreferenceKey.cadEdgeColorHex) == nil)
}
