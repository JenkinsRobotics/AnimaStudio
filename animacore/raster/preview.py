"""Headless preview/export — render a Canvas2D to files with no UI.

The "media player" you can use today: turn any canvas (any media method) into a
PNG (one frame), an animated GIF (a time range), an LED-matrix simulator image
(blocky nearest-neighbour upscale of the downsampled frame), or an ASCII dump.
Backs the app's 2D preview through the bridge, and runs standalone::

    python -m animacore.raster.preview face --gif face.gif
    python -m animacore.raster.preview face --ascii
    python -m animacore.raster.preview media clip.gif --matrix 64x64 --png panel.png
"""

from __future__ import annotations

from collections.abc import Callable, Mapping

from animacore.canvas2d import Canvas2D, SourceKind, Surface, VisualSource
from animacore.frame_output import LedMatrixTarget, downsample_canvas
from animacore.raster.player import CanvasPlayer

__all__ = [
    "render_png",
    "render_gif",
    "render_matrix_png",
    "ascii_preview",
    "face_canvas",
    "media_canvas",
]

Values = Mapping[str, float] | Callable[[float], Mapping[str, float]] | None
_ASCII_RAMP = " .:-=+*#%@"


def _values_at(values: Values, t: float) -> Mapping[str, float] | None:
    return values(t) if callable(values) else values


def render_png(
    canvas: Canvas2D, path, values: Mapping[str, float] | None = None, time_seconds: float = 0.0
) -> str:
    """Render one composited frame to a PNG."""
    with CanvasPlayer(canvas) as player:
        frame = player.frame(values, time_seconds)
    frame.to_pil().convert("RGB").save(path)
    return str(path)


def render_gif(
    canvas: Canvas2D,
    path,
    *,
    duration_seconds: float = 2.0,
    fps: float = 12.0,
    values: Values = None,
) -> str:
    """Render a time range to an animated GIF (``values`` may be a fn of time)."""
    from PIL import Image

    count = max(1, int(duration_seconds * fps))
    step = 1.0 / fps
    frames: list[Image.Image] = []
    with CanvasPlayer(canvas) as player:
        for i in range(count):
            t = i * step
            frames.append(player.frame(_values_at(values, t), t).to_pil().convert("RGB"))
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=int(1000.0 / fps),
        loop=0,
    )
    return str(path)


def render_matrix_png(
    canvas: Canvas2D,
    path,
    *,
    target: LedMatrixTarget | None = None,
    values: Mapping[str, float] | None = None,
    time_seconds: float = 0.0,
    scale: int = 16,
) -> str:
    """Render the LED-matrix simulation (downsample, then blocky upscale) to PNG."""
    from PIL import Image

    target = target or LedMatrixTarget()
    with CanvasPlayer(canvas) as player:
        frame = player.frame(values, time_seconds)
    rows = downsample_canvas(frame.to_rgb_rows(), target)
    small = Image.new("RGB", (target.width, target.height))
    small.putdata([pixel for row in rows for pixel in row])
    small.resize((target.width * scale, target.height * scale), Image.NEAREST).save(path)
    return str(path)


def ascii_preview(
    canvas: Canvas2D,
    *,
    values: Mapping[str, float] | None = None,
    time_seconds: float = 0.0,
    cols: int = 48,
    rows: int = 24,
) -> str:
    """A terminal preview of the composited frame (brightness ramp)."""
    with CanvasPlayer(canvas) as player:
        frame = player.frame(values, time_seconds)
    matrix = downsample_canvas(frame.to_rgb_rows(), LedMatrixTarget(cols, rows))
    return "\n".join(
        "".join(_ASCII_RAMP[min(9, (r + g + b) // 3 * 10 // 256)] for (r, g, b) in row)
        for row in matrix
    )


# ── canvas builders ───────────────────────────────────────────────────


def face_canvas(width: int = 128, height: int = 128, face: str = "simple") -> Canvas2D:
    """A canvas showing one procedural face (the default preview subject)."""
    return Canvas2D(
        width=width,
        height=height,
        sources={"face": VisualSource(id="face", kind=SourceKind.PROCEDURAL, asset=face)},
        surfaces=(Surface(id="face", source="face"),),
    )


_KIND_BY_SUFFIX = {
    ".png": SourceKind.IMAGE,
    ".jpg": SourceKind.IMAGE,
    ".jpeg": SourceKind.IMAGE,
    ".webp": SourceKind.IMAGE,
    ".bmp": SourceKind.IMAGE,
    ".gif": SourceKind.GIF,
    ".apng": SourceKind.GIF,
    ".mp4": SourceKind.VIDEO,
    ".mov": SourceKind.VIDEO,
    ".mkv": SourceKind.VIDEO,
    ".webm": SourceKind.VIDEO,
    ".json": SourceKind.BITMAP,
}


def media_canvas(asset: str, width: int = 128, height: int = 128) -> Canvas2D:
    """A full-canvas surface showing one media asset (kind inferred from suffix)."""
    from pathlib import Path

    kind = _KIND_BY_SUFFIX.get(Path(asset).suffix.lower(), SourceKind.IMAGE)
    return Canvas2D(
        width=width,
        height=height,
        sources={"media": VisualSource(id="media", kind=kind, asset=asset)},
        surfaces=(Surface(id="media", source="media"),),
    )


# ── CLI ───────────────────────────────────────────────────────────────


def _main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(prog="animacore.raster.preview", description=__doc__)
    parser.add_argument("subject", choices=["face", "media"])
    parser.add_argument("asset", nargs="?", help="asset path (for 'media')")
    parser.add_argument("--png", help="write one frame to this PNG")
    parser.add_argument("--gif", help="write an animated GIF here")
    parser.add_argument("--matrix", help="LED-matrix sim as WxH, e.g. 64x64")
    parser.add_argument("--ascii", action="store_true", help="print a terminal preview")
    parser.add_argument("--seconds", type=float, default=2.0)
    parser.add_argument("--fps", type=float, default=12.0)
    args = parser.parse_args(argv)

    if args.subject == "media":
        if not args.asset:
            parser.error("'media' needs an asset path")
        canvas = media_canvas(args.asset)
    else:
        canvas = face_canvas()

    talking = {"mouth_open": 0.8, "mouth_curve": 0.4}
    if args.matrix:
        w, _, h = args.matrix.partition("x")
        target = LedMatrixTarget(int(w), int(h or w))
        out = args.png or "matrix.png"
        print(render_matrix_png(canvas, out, target=target, values=talking, time_seconds=1.0))
    if args.gif:
        print(render_gif(canvas, args.gif, duration_seconds=args.seconds, fps=args.fps, values=talking))
    if args.png and not args.matrix:
        print(render_png(canvas, args.png, values=talking, time_seconds=1.0))
    if args.ascii or not (args.png or args.gif or args.matrix):
        print(ascii_preview(canvas, values=talking, time_seconds=1.0))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
