// swift-tools-version: 6.0
// GeomBench — modular benchmarking workspace for six CAD pipeline configs.
// OcctShim is the "GeomShim" C++ bridging layer (STEPCAFControl + XCAF colors
// + face/edge topology into flat C arrays). OcctGLKit hosts OCCT's built-in
// GL viewer in an NSView for the SwiftUI-wrapped Pipeline 3.
import PackageDescription

let occtInclude = "-I/opt/homebrew/opt/opencascade/include/opencascade"
let occtLib = "/opt/homebrew/opt/opencascade/lib"
let occtCoreLibs = [
  "TKernel", "TKMath", "TKG2d", "TKG3d", "TKGeomBase", "TKBRep", "TKGeomAlgo",
  "TKTopAlgo", "TKPrim", "TKBO", "TKBool", "TKShHealing", "TKFillet", "TKMesh",
  "TKDESTL", "TKDESTEP", "TKDEOBJ", "TKDE", "TKXSBase",
  "TKCDF", "TKLCAF", "TKVCAF", "TKXCAF",
]
let occtViewerLibs = ["TKService", "TKV3d", "TKOpenGl"]

func occtLinker(_ libs: [String]) -> [LinkerSetting] {
  [
    .unsafeFlags(
      ["-L\(occtLib)", "-Xlinker", "-rpath", "-Xlinker", occtLib]
        + libs.map { "-l\($0)" })
  ]
}

let package = Package(
  name: "OcctSwift",
  platforms: [.macOS(.v15)],
  dependencies: [
    // For Pipeline 6 (ModelIO baseline) we reuse the production loader.
    .package(path: "../../../app")
  ],
  targets: [
    .target(
      name: "OcctShim",
      cxxSettings: [
        .unsafeFlags([occtInclude, "-std=c++17", "-Wno-deprecated-declarations"])
      ],
      linkerSettings: occtLinker(occtCoreLibs)
    ),
    .target(
      name: "OcctGLKit",
      cxxSettings: [
        .unsafeFlags([occtInclude, "-Wno-deprecated-declarations"])
      ],
      linkerSettings: occtLinker(occtCoreLibs + occtViewerLibs) + [
        .linkedFramework("Cocoa"), .linkedFramework("OpenGL"),
      ]
    ),
    .executableTarget(
      name: "GeomBench",
      dependencies: [
        "OcctShim",
        "OcctGLKit",
        .product(name: "RealityKitViewport", package: "app"),
      ]
    ),
    .executableTarget(
      name: "OcctSwiftViewer",
      dependencies: ["OcctShim"]
    ),
  ]
)
