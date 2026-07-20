// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CodexUI",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "CodexUI", targets: ["CodexUIApp"])],
  targets: [
    .target(name: "CodexUICore", path: "Sources/CodexUICore"),
    .executableTarget(
      name: "CodexUIApp",
      dependencies: ["CodexUICore"],
      path: "Sources/CodexUIApp"
    ),
    .testTarget(
      name: "CodexUICoreTests",
      dependencies: ["CodexUICore"],
      path: "Tests/CodexUICoreTests"
    ),
  ]
)
