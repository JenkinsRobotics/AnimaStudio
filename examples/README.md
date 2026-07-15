# examples/ — sample `.anima` files

Hand-written character files that exercise the mechanism rig format
(`dev/docs/roadmap/Character_Format.md`). Every file here must load
through `anima_studio.loader` — the test suite iterates them
end-to-end (load → evaluate → project channels → simulated device).

| File | What it exercises |
|---|---|
| `six_axis_arm.character.anima` | Six revolute joints in a serial chain with per-joint limits — the flagship DOF example |
| `rc_car.character.anima` | Steering driven through a `rack_pinion` relation, an unlimited (continuous) wheel DOF, a mate offset, and a throttle parameter |
| `walle_style.character.anima` | Mixed joint kinds plus face/eye scalars via the generic parameter layer — domain naming lives here, never in core code |

The core model is mechanism-agnostic (see `CONVENTIONS.md`): specific
vocabulary — arms, cars, faces — belongs in these files only.
