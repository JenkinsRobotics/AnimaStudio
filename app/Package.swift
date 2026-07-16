// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AnimaStudio",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "AnimaStudio", targets: ["AnimaStudioApp"]),
    .library(name: "AnimaModel", targets: ["AnimaModel"]),
    .library(name: "AnimaEvaluation", targets: ["AnimaEvaluation"]),
    .library(name: "AnimaDocument", targets: ["AnimaDocument"]),
    .library(name: "AnimaViewport", targets: ["AnimaViewport"]),
    .library(name: "RealityKitViewport", targets: ["RealityKitViewport"]),
    .library(name: "AnimaStudioUI", targets: ["AnimaStudioUI"]),
  ],
  targets: [
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
      name: "RealityKitViewport",
      dependencies: ["AnimaModel", "AnimaEvaluation", "AnimaViewport"]
    ),
    .target(
      name: "AnimaStudioUI",
      dependencies: ["AnimaModel", "AnimaEvaluation", "RealityKitViewport"]
    ),
    .executableTarget(
      name: "AnimaStudioApp",
      dependencies: ["AnimaStudioUI"],
      path: "App",
      exclude: ["AnimaStudio.entitlements", "Resources"]
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
      dependencies: ["AnimaModel", "AnimaEvaluation", "RealityKitViewport"],
      resources: [.copy("Fixtures")]
    ),
    .testTarget(
      name: "AnimaStudioUIUnitTests",
      dependencies: ["AnimaModel", "AnimaEvaluation", "AnimaStudioUI"]
    ),
  ]
)
