// swift-tools-version: 6.0
import PackageDescription

let occtPrefix = "/opt/homebrew/opt/opencascade"
let occtInclude = "\(occtPrefix)/include/opencascade"
let occtLibrary = "\(occtPrefix)/lib"
let occtLibraries = [
  "TKernel", "TKMath", "TKG2d", "TKG3d", "TKGeomBase", "TKBRep", "TKGeomAlgo",
  "TKTopAlgo", "TKPrim", "TKMesh", "TKDE", "TKXSBase", "TKDESTEP", "TKCDF",
  "TKLCAF", "TKVCAF", "TKXCAF", "TKService",
]

let package = Package(
  name: "GeomBench",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "GeomBench", targets: ["GeomBenchApp"]),
    .executable(name: "geom-probe", targets: ["GeomBenchProbe"]),
  ],
  targets: [
    .target(
      name: "GeomShim",
      path: "Sources/GeomShim",
      publicHeadersPath: "include",
      cxxSettings: [
        .unsafeFlags(["-I\(occtInclude)", "-std=c++17", "-Wno-deprecated-declarations"])
      ],
      linkerSettings: [
        .unsafeFlags(
          ["-L\(occtLibrary)", "-Xlinker", "-rpath", "-Xlinker", occtLibrary]
            + occtLibraries.map { "-l\($0)" })
      ]
    ),
    .target(
      name: "GeomBenchCore",
      dependencies: ["GeomShim"],
      path: "Sources/GeomBenchCore"
    ),
    .executableTarget(
      name: "GeomBenchApp",
      dependencies: ["GeomBenchCore"],
      path: "Sources/GeomBenchApp",
      exclude: ["HostedRendererClient.swift", "HostedRendererView.swift", "Renderers/README.md"],
      linkerSettings: [.linkedFramework("WebKit")]
    ),
    .executableTarget(
      name: "GeomBenchProbe",
      dependencies: ["GeomBenchCore"],
      path: "Sources/GeomBenchProbe"
    ),
    .testTarget(
      name: "GeomBenchCoreTests",
      dependencies: ["GeomBenchCore", "GeomBenchApp"],
      path: "Tests/GeomBenchCoreTests"
    ),
  ],
  cxxLanguageStandard: .cxx17
)
