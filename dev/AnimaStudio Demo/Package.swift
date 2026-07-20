// swift-tools-version: 6.0
// AnimaStudio Demo — the ClaudeUI walkthrough graduated into a functional app.
//   AnimaStudioDemo  = SwiftUI shell (was ClaudeUI)
//   GeomKit          = Codex Bench's backend design: GeometryDocument (Open
//                      CASCADE import), CameraState, Pipeline catalog, Telemetry
//   GeomShim         = the C-ABI Open CASCADE bridge
// Swift 5 language mode so the SwiftUI base compiles unchanged.
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
  name: "AnimaStudioDemo",
  platforms: [.macOS(.v15)],
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
    .target(name: "GeomKit", dependencies: ["GeomShim"], path: "Sources/GeomKit"),
    .executableTarget(
      name: "AnimaStudioDemo", dependencies: ["GeomKit"], path: "Sources/AnimaStudioDemo",
      linkerSettings: [.linkedFramework("WebKit")]),
  ],
  swiftLanguageModes: [.v5],
  cxxLanguageStandard: .cxx17
)
