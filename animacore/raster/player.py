"""CanvasPlayer — drives the real media adapters and composites the surfaces.

This is the host-side rasterizer for the hardware frame path (and a reference for
the Swift preview renderer). ``canvas2d.evaluate_surfaces`` resolves *where* each
surface goes (transform, opacity, visibility, z, and the sprite frame index); the
player opens one stateful adapter per surface, pulls a real decoded frame from
each via ``next_frame(t)``, and alpha-composites them back-to-front with Pillow.

It is stateful on purpose — Mochi's decoders decode once at ``open`` (a GIF caches
all its frames) and stream, so the player holds them open across time. Feed the
result's ``to_rgb_rows()`` to ``frame_output.downsample_canvas`` for a matrix.
"""

from __future__ import annotations

from collections.abc import Mapping

from PIL import Image

from animacore.canvas2d import Canvas2D, Surface, SurfaceState, VisualSource, evaluate_surfaces
from animacore.raster.base import AdapterRegistry, MediaAdapter
from animacore.raster.frame import RGB, FrameBuffer
from animacore.raster.registry import default_registry

__all__ = ["CanvasPlayer", "render_canvas", "params_for_source"]


def params_for_source(source: VisualSource, surface: Surface) -> dict:
    """Adapter params derived from the source/surface (the integration glue)."""
    if source.kind.value in ("gif", "video"):
        return {"loop": source.loop}
    if source.kind.value == "sprite":
        return {"columns": source.columns, "rows": source.rows, "index": 0}
    return {}


class CanvasPlayer:
    """Opens an adapter per surface and composites a frame on demand."""

    def __init__(
        self,
        canvas: Canvas2D,
        registry: AdapterRegistry | None = None,
        background: RGB = (0, 0, 0),
    ) -> None:
        self.canvas = canvas
        self.registry = registry if registry is not None else default_registry()
        self.background = background
        self._adapters: dict[str, MediaAdapter] = {}

    def open(self) -> CanvasPlayer:
        for surface in self.canvas.surfaces:
            source = self.canvas.sources[surface.source]
            adapter = self.registry.create(source.kind)
            box_w = max(1, round(surface.width * self.canvas.width))
            box_h = max(1, round(surface.height * self.canvas.height))
            adapter.open(
                source.asset,
                width=box_w,
                height=box_h,
                params=params_for_source(source, surface),
            )
            self._adapters[surface.id] = adapter
        return self

    def frame(
        self, values: Mapping[str, float] | None = None, time_seconds: float = 0.0
    ) -> FrameBuffer:
        resolved = dict(values or {})
        states = evaluate_surfaces(self.canvas, resolved, time_seconds)
        canvas_img = Image.new(
            "RGBA", (self.canvas.width, self.canvas.height), (*self.background, 255)
        )
        for state in states:  # back-to-front by z
            if not state.visible or state.opacity <= 0.0:
                continue
            image = self._surface_image(state, resolved, time_seconds)
            if image is None:
                continue
            canvas_img.alpha_composite(
                image,
                (round(state.x * self.canvas.width), round(state.y * self.canvas.height)),
            )
        return FrameBuffer.from_pil(canvas_img)

    def close(self) -> None:
        for adapter in self._adapters.values():
            adapter.close()
        self._adapters.clear()

    def __enter__(self) -> CanvasPlayer:
        return self.open()

    def __exit__(self, *exc: object) -> None:
        self.close()

    # ── internals ─────────────────────────────────────────────────────

    def _surface_image(
        self, state: SurfaceState, values: Mapping[str, float], time_seconds: float
    ):  # -> PIL.Image.Image | None
        adapter = self._adapters[state.id]
        # Live drive: sprites walk to the resolved frame; procedural faces read
        # the current evaluated value stream. Duck-typed so the core Protocol
        # stays open/close/next_frame.
        if hasattr(adapter, "set_index"):
            adapter.set_index(state.frame_index)
        if hasattr(adapter, "set_params"):
            adapter.set_params(values)
        frame = adapter.next_frame(time_seconds)
        if frame is None:
            return None
        image = frame.to_pil()
        box_w = max(1, round(state.width * self.canvas.width))
        box_h = max(1, round(state.height * self.canvas.height))
        if (image.width, image.height) != (box_w, box_h):
            image = image.resize((box_w, box_h), Image.BILINEAR)
        if state.opacity < 1.0:
            faded = image.getchannel("A").point(lambda a: int(a * state.opacity))
            image = image.copy()
            image.putalpha(faded)
        return image


def render_canvas(
    canvas: Canvas2D,
    values: Mapping[str, float] | None = None,
    time_seconds: float = 0.0,
    registry: AdapterRegistry | None = None,
    background: RGB = (0, 0, 0),
) -> FrameBuffer:
    """One-shot convenience: open a player, composite one frame, close.

    For streaming playback keep a ``CanvasPlayer`` open across frames so stateful
    decoders (GIF/video) are not reopened every frame.
    """
    with CanvasPlayer(canvas, registry, background) as player:
        return player.frame(values, time_seconds)
