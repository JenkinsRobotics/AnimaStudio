// swift-tools-version: 6.0

import PackageDescription

// AetherKernel adopts the supported Open CASCADE build; Aether Core owns
// this seam (see aether-core/README.md — OCCT is adopted, never rebuilt).
let openCascadePrefix = "/opt/homebrew/opt/opencascade"
let openCascadeInclude = "\(openCascadePrefix)/include/opencascade"
let openCascadeLibrary = "\(openCascadePrefix)/lib"
let openCascadeLibraries = [
  "TKernel", "TKMath", "TKG2d", "TKG3d", "TKGeomBase", "TKBRep", "TKGeomAlgo",
  "TKTopAlgo", "TKPrim", "TKMesh", "TKDE", "TKXSBase", "TKDESTEP", "TKCDF",
  "TKLCAF", "TKVCAF", "TKXCAF", "TKService",
]

let package = Package(
  name: "AetherKit",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "AetherKernel", targets: ["AetherKernel"]),
    .library(name: "AetherViewport", targets: ["AetherViewport"]),
  ],
  targets: [
    .target(
      name: "AetherKernelShim",
      path: "Sources/AetherKernelShim",
      publicHeadersPath: "include",
      cxxSettings: [
        .unsafeFlags([
          "-I\(openCascadeInclude)", "-std=c++17", "-Wno-deprecated-declarations",
        ])
      ],
      linkerSettings: [
        .unsafeFlags(
          [
            "-L\(openCascadeLibrary)",
            "-Xlinker", "-rpath", "-Xlinker", openCascadeLibrary,
            "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
          ] + openCascadeLibraries.map { "-l\($0)" })
      ]
    ),
    .target(
      name: "AetherKernel",
      dependencies: ["AetherKernelShim"]
    ),
    .target(
      name: "AetherViewport",
      dependencies: ["AetherKernel"]
    ),
    .testTarget(
      name: "AetherCoreTests",
      dependencies: ["AetherKernel", "AetherViewport"]
    ),
  ],
  cxxLanguageStandard: .cxx17
)
