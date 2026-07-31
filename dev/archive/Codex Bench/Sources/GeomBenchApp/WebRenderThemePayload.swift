import Foundation

/// Renderer-neutral projection of `BenchTheme` for browser-hosted GPU paths.
/// Keeping this outside either renderer prevents the raw and Three.js routes
/// from depending on one another.
struct WebRenderThemePayload: Encodable {
  struct LightPayload: Encodable {
    let color: [Float]
    let direction: [Float]
    let intensity: Float

    init(_ light: BenchTheme.Light) {
      color = [light.color.x, light.color.y, light.color.z]
      direction = [light.directionFrom.x, light.directionFrom.y, light.directionFrom.z]
      intensity = light.intensity / 4_000
    }
  }

  let background: [Float]
  let edge: [Float]
  let selection: [Float]
  let roughness: Float
  let metallic: Float
  let edgeStrength: Float
  let overrideColor: [Float]?
  let key: LightPayload
  let fill: LightPayload
  let rim: LightPayload

  init(theme: BenchTheme) {
    background = [theme.background.x, theme.background.y, theme.background.z]
    edge = [theme.edgeColor.x, theme.edgeColor.y, theme.edgeColor.z]
    selection = [theme.selectionColor.x, theme.selectionColor.y, theme.selectionColor.z]
    roughness = theme.roughness
    metallic = theme.metallic
    edgeStrength = theme.edgeStrength
    overrideColor = theme.overrideColor.map { [$0.x, $0.y, $0.z, $0.w] }
    key = LightPayload(theme.key)
    fill = LightPayload(theme.fill)
    rim = LightPayload(theme.rim)
  }
}
