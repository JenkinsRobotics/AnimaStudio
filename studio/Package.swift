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
    .executableTarget(
      name: "AnimaStudioApp",
      dependencies: ["AnimaCore", "RealityKitViewport"]
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
      name: "AnimaStudioAppTests",
      dependencies: ["AnimaStudioApp"]
    ),
  ]
)
