// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AnimaStudio",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "AnimaStudio", targets: ["AnimaStudioApp"]),
    .library(name: "AnimaCore", targets: ["AnimaCore"]),
    .library(name: "AnimaViewport", targets: ["AnimaViewport"]),
    .library(name: "RealityKitViewport", targets: ["RealityKitViewport"]),
    .library(name: "AnimaStudioUI", targets: ["AnimaStudioUI"]),
  ],
  targets: [
    .target(name: "AnimaCore"),
    .target(
      name: "AnimaViewport",
      dependencies: ["AnimaCore"]
    ),
    .target(
      name: "RealityKitViewport",
      dependencies: ["AnimaCore", "AnimaViewport"]
    ),
    .target(
      name: "AnimaStudioUI",
      dependencies: ["AnimaCore", "RealityKitViewport"]
    ),
    .executableTarget(
      name: "AnimaStudioApp",
      dependencies: ["AnimaStudioUI"],
      path: "App",
      exclude: ["AnimaStudio.entitlements", "Resources"]
    ),
    .testTarget(
      name: "AnimaCoreTests",
      dependencies: ["AnimaCore"]
    ),
    .testTarget(
      name: "RealityKitViewportTests",
      dependencies: ["RealityKitViewport"],
      resources: [.copy("Fixtures")]
    ),
    .testTarget(
      name: "AnimaStudioUIUnitTests",
      dependencies: ["AnimaStudioUI"]
    ),
  ]
)
