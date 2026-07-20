# ClaudeUI — CAD-animatronic design walkthrough

A **UI-only** reference mockup for what an Anima-Studio-class app *could* look
like. No engine, no persistence, no AnimaStudio dependency — pure SwiftUI so we
can react to the layout before wiring anything real.

References: Onshape (rig tree + mate menu), Shapr3D (restraint, floating
panels), Bottango (timeline + live servo/arm), Codex-bench chrome.

## Run

```bash
open dev/labs/apps/ClaudeUI.app
# or rebuild:  cd dev/labs/ClaudeUI && swift run
```

## The walkthrough (top-bar pipeline)

1. **Assets** — import tree, viewport, part inspector + import telemetry.
2. **Rig** — mate palette + Onshape-style DOF/limits inspector, gizmo.
3. **Animate** — Bottango-style dope sheet, curve editor, transport.
4. **Show** — scene list + trigger→clip→output node graph + media bindings.
5. **Hardware** — live servo channels, arm/disarm, µs calibration.

Click the hex logo (top-left) for the **Home** launch screen.

Everything is faux data — buttons style-change but don't compute. This is a
design surface to argue about, not a build.
