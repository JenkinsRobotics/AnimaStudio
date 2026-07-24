"""animacore.raster — host-side rasterizer: real media decode -> pixels.

``canvas2d`` evaluates *which* frame each surface shows (renderer-neutral, no
pixels). This package turns that into actual RGBA pixels for the hardware frame
path (and as a reference for the Swift preview renderer): one canonical RGBA8
``FrameBuffer`` + Mochi's proven ``open``/``close``/``next_frame(t)`` decoder
contract, one file per media kind (image / bitmap / sprite / gif / video /
procedural), and a ``CanvasPlayer`` that composites them.

The decoders are ported from Mochi (Apache-2.0) and use Pillow / numpy / imageio,
so this package is an optional-dependency feature (see the ``media`` extra); the
core engine never imports it.
"""

from animacore.raster.base import AdapterRegistry, MediaAdapter
from animacore.raster.frame import RGB, RGBA, FrameBuffer
from animacore.raster.player import CanvasPlayer, render_canvas
from animacore.raster.procedural import FaceRegistry, ProceduralAdapter, ProceduralFace, default_faces
from animacore.raster.registry import default_registry

__all__ = [
    "FrameBuffer",
    "RGB",
    "RGBA",
    "MediaAdapter",
    "AdapterRegistry",
    "default_registry",
    "CanvasPlayer",
    "render_canvas",
    "ProceduralAdapter",
    "ProceduralFace",
    "FaceRegistry",
    "default_faces",
]
