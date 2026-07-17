// swift-tools-version: 6.0
// Standalone Swift + Open CASCADE test: OCCT C++ kernel behind a tiny C shim,
// SwiftUI + RealityKit (Metal) front end — the exact architecture Anima Studio
// would use for STEP import / exact geometry.
import PackageDescription

let occtInclude = "-I/opt/homebrew/opt/opencascade/include/opencascade"
let occtLib = "/opt/homebrew/opt/opencascade/lib"
let occtLibs = [
  "TKernel", "TKMath", "TKG2d", "TKG3d", "TKGeomBase", "TKBRep", "TKGeomAlgo",
  "TKTopAlgo", "TKPrim", "TKBO", "TKBool", "TKShHealing", "TKFillet", "TKMesh",
  "TKDESTL", "TKDESTEP", "TKDEOBJ", "TKDE", "TKXSBase",
  "TKCDF", "TKLCAF", "TKVCAF", "TKXCAF",
]

let package = Package(
  name: "OcctSwift",
  platforms: [.macOS(.v15)],
  targets: [
    .target(
      name: "OcctShim",
      cxxSettings: [
        .unsafeFlags([occtInclude, "-std=c++17", "-Wno-deprecated-declarations"])
      ],
      linkerSettings: [
        .unsafeFlags(
          ["-L\(occtLib)", "-Xlinker", "-rpath", "-Xlinker", occtLib]
            + occtLibs.map { "-l\($0)" })
      ]
    ),
    .executableTarget(
      name: "OcctSwiftViewer",
      dependencies: ["OcctShim"]
    ),
    .executableTarget(
      name: "GeomBench",
      dependencies: ["OcctShim"]
    ),
    .executableTarget(
      name: "TestLab"
    ),
  ]
)
