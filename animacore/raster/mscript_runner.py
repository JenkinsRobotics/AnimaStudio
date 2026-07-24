"""Play an Mscript command stream into rendered frames.

The runner that makes the ported Mscript engine *do* something: it steps the
script's clock, and when a ``MEDIA`` command fires it opens the media adapter for
that asset (kind inferred from the extension) and streams its frames. This is the
create-side headless play; the hardware/middleware plays the same command stream
on a real panel. Needs the ``media`` extra (Pillow/imageio).
"""

from __future__ import annotations

from pathlib import Path

from animacore.asset_props import kind_for_asset
from animacore.canvas2d import SourceKind
from animacore.raster.base import AdapterRegistry, MediaAdapter
from animacore.raster.frame import FrameBuffer
from animacore.raster.mscript import MscriptScript
from animacore.raster.registry import default_registry

__all__ = ["MscriptRunner", "render_mscript"]


class MscriptRunner:
    """Drive a ``MscriptScript`` and render the active media at each moment."""

    def __init__(
        self,
        script: MscriptScript,
        registry: AdapterRegistry | None = None,
        width: int = 128,
        height: int = 128,
    ) -> None:
        self._script = script
        self._registry = registry if registry is not None else default_registry()
        self._width = max(1, width)
        self._height = max(1, height)
        self._adapter: MediaAdapter | None = None
        self._active_start = 0.0
        self._active_asset: str | None = None

    def frame_at(self, t: float) -> FrameBuffer | None:
        """Advance the script to ``t`` and render the active media's frame."""
        for command in self._script.update(t):
            if command.name == "MEDIA":
                asset = command.args.get("asset_path")
                if asset:
                    self._switch(str(asset), t)
        if self._adapter is None:
            return None
        return self._adapter.next_frame(t - self._active_start)

    def close(self) -> None:
        if self._adapter is not None:
            self._adapter.close()
            self._adapter = None

    def __enter__(self) -> MscriptRunner:
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    def _switch(self, asset: str, t: float) -> None:
        if asset == self._active_asset:
            return
        if self._adapter is not None:
            self._adapter.close()
        kind = kind_for_asset(asset)
        adapter = self._registry.create(kind)
        params = {"loop": True} if kind in (SourceKind.GIF, SourceKind.VIDEO) else {}
        adapter.open(asset, width=self._width, height=self._height, params=params)
        self._adapter = adapter
        self._active_asset = asset
        self._active_start = t


def render_mscript(
    script_path: str | Path,
    *,
    until: float,
    fps: float = 12.0,
    width: int = 128,
    height: int = 128,
    registry: AdapterRegistry | None = None,
) -> list[FrameBuffer]:
    """Play a ``.mscript`` from 0..``until`` seconds into a list of frames."""
    script = MscriptScript(str(script_path))
    step = 1.0 / fps
    frames: list[FrameBuffer] = []
    with MscriptRunner(script, registry, width, height) as runner:
        count = max(1, int(until * fps))
        for i in range(count):
            frame = runner.frame_at(i * step)
            if frame is not None:
                frames.append(frame)
    return frames
