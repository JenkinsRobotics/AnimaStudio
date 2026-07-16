# Anima Studio macOS app

This directory contains the native macOS authoring app and its reusable local
Swift packages. The repository root also holds a locally built
`Anima Studio.app` for double-click testing; that generated bundle is ignored by
Git.

## Open and run in Xcode

1. Open `AnimaStudio.xcodeproj`.
2. Select the **AnimaStudio** scheme and **My Mac** destination.
3. Press Run (`Command-R`).

Use Xcode's Canvas on
`Sources/AnimaStudioUI/PreviewSupport/StudioPreviewCatalog.swift` to inspect the
home screen, complete workspace, and animation timeline without launching the
whole app. SwiftUI is code-first; Canvas provides live previews and interactive
inspection rather than Interface Builder drag-and-drop storyboards.

The checked-in Xcode project is generated from `project.yml`. After changing
targets, resources, or build settings, run `xcodegen generate` and commit both
the specification and regenerated project.

## Folder structure

```text
app/
├── App/                         thin @main lifecycle, entitlements, resources
├── AppUITests/                  launch-level macOS UI tests
├── Config/                      shared Debug/Release build settings
├── Sources/
│   ├── AnimaModel/              app-side data types and validation
│   ├── AnimaEvaluation/         renderer-independent preview evaluation
│   ├── AnimaDocument/           versioned project-package persistence
│   ├── AnimaStudioUI/           reusable SwiftUI app shell and workspaces
│   ├── AnimaViewport/           renderer-neutral viewport boundary
│   └── RealityKitViewport/      native 3D rendering adapter
├── Tests/                       mirrors the package source modules
├── Scripts/                     repeatable developer packaging commands
├── Package.swift                local package graph and command-line app
├── project.yml                 XcodeGen source of truth
└── AnimaStudio.xcodeproj        generated native application project
```

## Package boundaries

- `AnimaModel` owns the app's in-memory rigs, animation clips, limits,
  projects, and validation.
- `AnimaEvaluation` owns interpolation, mate transform math, and evaluated
  preview frames.
- `AnimaViewport` defines the frame-consumer boundary used by previews.
- `RealityKitViewport` displays evaluated mechanical joint motion.
- `AnimaStudioUI` is the reusable SwiftUI application shell.
- `AnimaStudioApp` is the thin native lifecycle/signing/resources target.

No rendering or hardware framework may be imported by `AnimaModel` or
`AnimaEvaluation`.

## Command-line verification

```bash
cd app
swift test
swift run AnimaStudio
```

To assemble an ad-hoc-signed development app at the repository root:

```bash
./Scripts/build-root-app.sh
open "../Anima Studio.app"
```

The current workspace includes Build/Animate modes, a project tree, USD-family
model import, a RealityKit viewport, inspector, transport, timeline tracks,
keyframe display, scrubbing, and playback. Joint creation/editing and project
persistence are the next product slices.
