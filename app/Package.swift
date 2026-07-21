// swift-tools-version: 6.0

import PackageDescription

let openCascadePrefix = "/opt/homebrew/opt/opencascade"
let openCascadeInclude = "\(openCascadePrefix)/include/opencascade"
let openCascadeLibrary = "\(openCascadePrefix)/lib"
let openCascadeLibraries = [
  "TKernel", "TKMath", "TKG2d", "TKG3d", "TKGeomBase", "TKBRep", "TKGeomAlgo",
  "TKTopAlgo", "TKPrim", "TKMesh", "TKDE", "TKXSBase", "TKDESTEP", "TKCDF",
  "TKLCAF", "TKVCAF", "TKXCAF", "TKService",
]

let package = Package(
  name: "AnimaStudio",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "AnimaStudio", targets: ["AnimaStudioApp"]),
    .library(name: "AnimaCoreClient", targets: ["AnimaCoreClient"]),
    .library(name: "AnimaModel", targets: ["AnimaModel"]),
    .library(name: "AnimaEvaluation", targets: ["AnimaEvaluation"]),
    .library(name: "AnimaDocument", targets: ["AnimaDocument"]),
    .library(name: "AnimaViewport", targets: ["AnimaViewport"]),
    .library(name: "AnimaCAD", targets: ["AnimaCAD"]),
    .library(name: "AnimaCADViewport", targets: ["AnimaCADViewport"]),
    .library(name: "RealityKitViewport", targets: ["RealityKitViewport"]),
    .library(name: "AnimaStudioUI", targets: ["AnimaStudioUI"]),
  ],
  targets: [
    .target(name: "AnimaCoreClient"),
    .target(name: "AnimaModel"),
    .target(
      name: "AnimaEvaluation",
      dependencies: ["AnimaModel"]
    ),
    .target(
      name: "AnimaDocument",
      dependencies: ["AnimaModel"]
    ),
    .target(
      name: "AnimaViewport",
      dependencies: ["AnimaEvaluation"]
    ),
    .target(
      name: "AnimaCADShim",
      path: "Sources/AnimaCADShim",
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
      name: "AnimaCAD",
      dependencies: ["AnimaCADShim"]
    ),
    .target(
      name: "AnimaCADViewport",
      dependencies: ["AnimaCAD"],
      linkerSettings: [.linkedFramework("WebKit")]
    ),
    .target(
      name: "RealityKitViewport",
      dependencies: ["AnimaModel", "AnimaEvaluation", "AnimaViewport", "AnimaCAD"]
    ),
    .target(
      name: "AnimaStudioUI",
      dependencies: [
        "AnimaCoreClient", "AnimaDocument", "AnimaModel", "AnimaEvaluation",
        "AnimaCAD", "AnimaCADViewport", "RealityKitViewport",
      ]
    ),
    .executableTarget(
      name: "AnimaStudioApp",
      dependencies: ["AnimaStudioUI"],
      path: "App",
      exclude: ["AnimaCoreHelper.entitlements", "AnimaStudio.entitlements", "Resources", "Shaders"]
    ),
    .testTarget(
      name: "AnimaCoreClientTests",
      dependencies: ["AnimaCoreClient"]
    ),
    .testTarget(
      name: "AnimaModelTests",
      dependencies: ["AnimaModel"]
    ),
    .testTarget(
      name: "AnimaEvaluationTests",
      dependencies: ["AnimaModel", "AnimaEvaluation"]
    ),
    .testTarget(
      name: "AnimaDocumentTests",
      dependencies: ["AnimaModel", "AnimaDocument"]
    ),
    .testTarget(
      name: "RealityKitViewportTests",
      dependencies: ["AnimaModel", "AnimaEvaluation", "AnimaCAD", "RealityKitViewport"],
      resources: [.copy("Fixtures")]
    ),
    .testTarget(
      name: "AnimaCADTests",
      dependencies: ["AnimaCAD", "AnimaCADViewport"]
    ),
    .testTarget(
      name: "AnimaStudioUIUnitTests",
      dependencies: ["AnimaDocument", "AnimaModel", "AnimaEvaluation", "AnimaStudioUI"]
    ),
  ],
  cxxLanguageStandard: .cxx17
)
