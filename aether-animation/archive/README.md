# Archived: the Swift native track

Archived 2026-08-01 per Jonathan — Aether Animation is being rebuilt as a
React web app (`../web/`) on `@aether/ui` and the animacore HTTP bridge;
a native Swift shell remains a possible future option.

- `swift-app/` — the full Anima Studio SwiftUI application as it stood at
  archive time (378 XCTest + 68 Swift Testing green; workspaces:
  Assets/Rig/Animate/Show/Hardware/2D/UIDev; behavior reference for the
  web rebuild).
- `AetherKit/` — its native engine seam (AetherKernel OCCT bridge +
  AetherViewport contracts, incl. the engine-owned in-world tool
  geometry). The `swift-app` package resolves it at `../AetherKit`, so the
  pair builds in place if ever revived.

Not maintained: CI no longer builds this tree, and repo-root-relative
test fixtures (PartModelSourceReloadTests) now sit one directory deeper
than the paths they compute. Treat as a snapshot, not a live target.
