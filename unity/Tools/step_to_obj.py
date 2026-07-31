"""STEP → per-part OBJ converter for the AnimaStudio Unity front-end.

Tessellates a STEP file (OCCT via `cascadio`) and writes one OBJ per solid
so each becomes an assemblable part. Geometry only — no rig semantics here;
parts enter the character through the engine's `add_part` verb.

Usage:
    python unity/Tools/step_to_obj.py input.step output_dir [--scale 1.0]

cascadio already converts STEP units to glTF metres, so --scale defaults to
1.0; use it only for files whose declared units are wrong.

Each part's mesh is written in its own STEP component frame and its assembly
placement is reported as an engine rest transform (`position_m` metres +
`rotation_euler_rad` intrinsic XYZ, the `.character.anima` convention) — so a
part added via the engine's `add_part` verb lands where the CAD assembly put
it, and mates rotate about the component origin rather than the assembly
origin. A placement with scale/shear falls back to baking the transform into
the vertices.

Prints a JSON report on stdout (the Unity app parses this):
    {"parts": [{"name": "...", "obj": "/abs/path.obj", "triangles": N,
                "position_m": [x,y,z], "rotation_euler_rad": [x,y,z]}, ...]}

Requires: pip install cascadio trimesh  (repo extra: `.[cad]`).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

try:
    import cascadio
    import numpy as np
    import trimesh
    from trimesh import transformations as tf
except ImportError as error:  # pragma: no cover - environment guard
    print(json.dumps({"error": f"missing dependency: {error.name}; "
                      "run: .venv/bin/pip install cascadio trimesh"}))
    sys.exit(2)


def safe_name(raw: str, taken: set[str]) -> str:
    name = re.sub(r"[^A-Za-z0-9_-]+", "_", raw).strip("_") or "part"
    base = name
    for i in range(2, 10_000):
        if name not in taken:
            break
        name = f"{base}_{i}"
    taken.add(name)
    return name


def convert(step_path: Path, out_dir: Path, scale: float) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".glb", delete=False) as tmp:
        glb_path = Path(tmp.name)
    try:
        cascadio.step_to_glb(str(step_path), str(glb_path))
        scene = trimesh.load(str(glb_path), force="scene")
    finally:
        glb_path.unlink(missing_ok=True)

    parts = []
    taken: set[str] = set()
    for node_name in scene.graph.nodes_geometry:
        transform, geometry_name = scene.graph[node_name]
        mesh = scene.geometry[geometry_name].copy()
        if not isinstance(mesh, trimesh.Trimesh) or mesh.faces.size == 0:
            continue
        rotation = np.asarray(transform)[:3, :3]
        rigid = np.allclose(rotation @ rotation.T, np.eye(3), atol=1e-6)
        if rigid:
            position = (np.asarray(transform)[:3, 3] * scale).tolist()
            euler = list(tf.euler_from_matrix(transform, axes="rxyz"))
        else:
            mesh.apply_transform(transform)  # scale/shear: bake instead
            position = [0.0, 0.0, 0.0]
            euler = [0.0, 0.0, 0.0]
        mesh.apply_scale(scale)
        name = safe_name(str(node_name) or geometry_name, taken)
        obj_path = out_dir / f"{name}.obj"
        obj_path.write_text(
            trimesh.exchange.obj.export_obj(mesh, include_texture=False)
        )
        parts.append({
            "name": name,
            "obj": str(obj_path),
            "triangles": int(mesh.faces.shape[0]),
            "position_m": position,
            "rotation_euler_rad": euler,
        })
    return {"parts": parts}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("step", type=Path)
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("--scale", type=float, default=1.0,
                        help="extra unit scale (default 1.0; cascadio already emits metres)")
    args = parser.parse_args()
    if not args.step.exists():
        print(json.dumps({"error": f"not found: {args.step}"}))
        return 1
    report = convert(args.step, args.out_dir, args.scale)
    if not report["parts"]:
        report["error"] = "no solid geometry found in STEP"
    print(json.dumps(report))
    return 0 if report["parts"] else 1


if __name__ == "__main__":
    sys.exit(main())
