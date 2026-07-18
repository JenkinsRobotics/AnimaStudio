// swift-tools-version: 6.0
// Unified Bench — harvests the best of all three demo apps:
//  · Codex: modular architecture + camera model (adds roll/tilt)
//  · Claude: theme system + face/edge selection depth
//  · Gemini: SceneKit engine + clean per-face color packing
// One workspace, one file set, every pipeline switchable, compare then cull.
import PackageDescription

let occtInclude = "-I/opt/homebrew/opt/opencascade/include/opencascade"
let occtLib = "/opt/homebrew/opt/opencascade/lib"
let occtCore = [
  "TKernel", "TKMath", "TKG2d", "TKG3d", "TKGeomBase", "TKBRep", "TKGeomAlgo",
  "TKTopAlgo", "TKPrim", "TKBO", "TKBool", "TKShHealing", "TKFillet", "TKMesh",
  "TKDESTL", "TKDESTEP", "TKDEOBJ", "TKDE", "TKXSBase",
  "TKCDF", "TKLCAF", "TKVCAF", "TKXCAF",
]
let occtViewer = ["TKService", "TKV3d", "TKOpenGl"]
func link(_ libs: [String]) -> [LinkerSetting] {
  [.unsafeFlags(["-L\(occtLib)", "-Xlinker", "-rpath", "-Xlinker", occtLib] + libs.map { "-l\($0)" })]
}

let package = Package(
  name: "UnifiedBench",
  platforms: [.macOS(.v15)],
  dependencies: [.package(path: "../../../app")],
  targets: [
    .target(name: "OcctShim",
      cxxSettings: [.unsafeFlags([occtInclude, "-std=c++17", "-Wno-deprecated-declarations"])],
      linkerSettings: link(occtCore)),
    .target(name: "OcctGLKit",
      cxxSettings: [.unsafeFlags([occtInclude, "-Wno-deprecated-declarations"])],
      linkerSettings: link(occtCore + occtViewer) + [.linkedFramework("Cocoa"), .linkedFramework("OpenGL")]),
    .executableTarget(name: "UnifiedBench",
      dependencies: ["OcctShim", "OcctGLKit", .product(name: "RealityKitViewport", package: "app")]),
  ]
)
