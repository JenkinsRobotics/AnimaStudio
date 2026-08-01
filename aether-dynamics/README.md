# Aether Dynamics

The Aether ecosystem's simulation and physics product: kinematic and
dynamic simulation of Aether Core worlds — mechanism motion studies,
load/interference checks, and physical validation of animatronic designs
before hardware exists.

## Ground rules

- **Physics engines are adopted, not written** (MuJoCo/Bullet class),
  behind an Aether Core module that owns what simulation *means* for a
  character/assembly. Same discipline as the OCCT kernel seam.
- Consumes AetherScene entities and AnimaCore mate/DOF semantics — it
  never defines its own copy of either.
- Scaffold only today; work begins when Aether CAD and Aether Animation
  stabilize their shared Core surface.
