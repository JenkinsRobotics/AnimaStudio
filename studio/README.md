# Anima Studio macOS app

This directory contains the planned native macOS authoring app's first working
foundation.

## Package boundaries

- `AnimaCore` owns renderer-independent rigs, animation clips, interpolation,
  limits, and evaluated frames.
- `AnimaViewport` defines the frame-consumer boundary used by previews.
- `RealityKitViewport` displays evaluated mechanical joint motion.
- `AnimaStudioApp` is the SwiftUI application shell.

No rendering or hardware framework may be imported by `AnimaCore`.

## Run

```bash
cd studio
swift test
swift run AnimaStudio
```

The current workspace includes Build/Animate modes, a project tree, USD-family
model import, a RealityKit viewport, inspector, transport, timeline tracks,
keyframe display, scrubbing, and playback. Joint creation/editing and project
persistence are the next product slices.
