# CodexUI

CodexUI is an isolated native SwiftUI walkthrough exploring what a modern CAD
animatronic authoring application could look like. It combines the workspace
clarity of Onshape and Shapr3D, the animatronic workflow breadth of Bottango,
and the diagnostic visual language developed in Codex Bench.

It is intentionally **presentation-only**:

- no AnimaCore process or protocol;
- no Anima Studio models, documents, or renderer packages;
- no filesystem mutation beyond its own build output;
- no hardware, playback, or model-import behavior presented as operational.

The walkthrough contains seven selectable workspaces: Assets, Rig, Animate,
Show, Hardware, Nodes, and UI Kit. Each keeps the same application chrome but
changes its ribbon and panel content for the operator's current job. A shared
canvas-first layout now presents the left browser, right inspector, and top
tool ribbon from one source each: every region can dock into the workspace,
float inside the app window, or hide and restore. Studio, Classic, and Canvas
presets make the panel behavior easy to compare, and the native Settings window
exposes the same controls.

```bash
cd dev/CodexUI
swift test
./scripts/make-app.sh
./scripts/launch.sh
```

The clickable result is `dev/CodexUI/CodexUI.app`.

## UI Kit coverage rule

Every reusable UI asset used by CodexUI must also appear as a reviewable
specimen in the UI Kit workspace. Register new shared components in
`UIKitAssetCatalog`; its deterministic coverage test prevents duplicate or
unnamed entries, while the gallery makes the component visible across themes.
