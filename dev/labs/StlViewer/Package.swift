// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "StlViewer",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(path: "../../../app")
  ],
  targets: [
    .executableTarget(
      name: "StlViewer",
      dependencies: [
        .product(name: "RealityKitViewport", package: "app")
      ]
    )
  ]
)
