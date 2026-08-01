// swift-tools-version: 6.0

import PackageDescription

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
    .library(name: "AnimaCADViewport", targets: ["AnimaCADViewport"]),
    .library(name: "RealityKitViewport", targets: ["RealityKitViewport"]),
    .library(name: "AnimaStudioUI", targets: ["AnimaStudioUI"]),
  ],
  dependencies: [
    // The extracted engine: AetherKernel (OCCT seam) + AetherViewport
    // (renderer-neutral contracts). See aether-core/README.md.
    .package(name: "AetherKit", path: "../AetherKit")
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
      name: "AnimaCADViewport",
      dependencies: [
        .product(name: "AetherKernel", package: "AetherKit"),
        .product(name: "AetherViewport", package: "AetherKit"),
      ],
      linkerSettings: [.linkedFramework("WebKit")]
    ),
    .target(
      name: "RealityKitViewport",
      dependencies: [
        "AnimaModel", "AnimaEvaluation", "AnimaViewport",
        .product(name: "AetherKernel", package: "AetherKit"),
      ]
    ),
    .target(
      name: "AnimaStudioUI",
      dependencies: [
        "AnimaCoreClient", "AnimaDocument", "AnimaModel", "AnimaEvaluation",
        "AnimaCADViewport", "RealityKitViewport",
        .product(name: "AetherKernel", package: "AetherKit"),
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
      dependencies: [
        "AnimaModel", "AnimaEvaluation", "RealityKitViewport",
        .product(name: "AetherKernel", package: "AetherKit"),
      ],
      resources: [.copy("Fixtures")]
    ),
    .testTarget(
      name: "AnimaCADTests",
      dependencies: [
        "AnimaCADViewport",
        .product(name: "AetherKernel", package: "AetherKit"),
      ]
    ),
    .testTarget(
      name: "AnimaStudioUIUnitTests",
      dependencies: ["AnimaDocument", "AnimaModel", "AnimaEvaluation", "AnimaStudioUI"]
    ),
  ],
  cxxLanguageStandard: .cxx17
)
