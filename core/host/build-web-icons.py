"""Render the selected Core app artwork; never replace it with toolbar glyphs."""

import argparse
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--variant", choices=("fancy", "simple"), default="fancy")
args = parser.parse_args()
output = root / "core/assets/branding/apps"
# Original artwork and earlier browser icons are preserved in sibling archives.
for app in ("studio", "cad", "animation", "ui"):
    vector = output / f"{app}.svg"
    if app != "ui":
        shutil.copyfile(root / f"core/assets/branding/{args.variant}/{app}.svg", vector)
    subprocess.run(
        ["sips", "-s", "format", "png", str(vector), "--out", str(output / f"{app}.png")],
        check=True,
        stdout=subprocess.DEVNULL,
    )
