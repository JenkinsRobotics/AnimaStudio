"""The media-adapter seam — Mochi's proven ``open``/``close``/``next_frame``.

Ported from Mochi's `AnimationAdapter` Protocol (Apache-2.0). An adapter is a
*stateful* decoder: ``open`` prepares an asset at a target size, ``next_frame(t)``
renders the frame for elapsed time ``t`` (``None`` when a one-shot clip ends),
``close`` releases resources. One adapter class per source kind; the registry
maps ``SourceKind`` to a factory so the compositor never branches on media type.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Protocol, runtime_checkable

from animacore.canvas2d import SourceKind
from animacore.raster.frame import FrameBuffer

__all__ = ["MediaAdapter", "AdapterFactory", "AdapterRegistry"]


@runtime_checkable
class MediaAdapter(Protocol):
    """A stateful asset -> frame decoder (open once, stream, close)."""

    def open(self, asset_path: str, *, width: int, height: int, params: dict) -> None:
        """Prepare to render ``asset_path`` at ``width`` x ``height``."""
        ...

    def close(self) -> None:
        """Release decoded resources. Idempotent."""
        ...

    def next_frame(self, t: float) -> FrameBuffer | None:
        """Render the frame for elapsed time ``t`` (s). ``None`` = clip done."""
        ...


AdapterFactory = Callable[[], MediaAdapter]


class AdapterRegistry:
    """Maps each ``SourceKind`` to a factory producing a fresh adapter."""

    def __init__(self) -> None:
        self._factories: dict[SourceKind, AdapterFactory] = {}

    def register(self, kind: SourceKind, factory: AdapterFactory) -> AdapterFactory:
        self._factories[kind] = factory
        return factory

    def create(self, kind: SourceKind) -> MediaAdapter:
        try:
            factory = self._factories[kind]
        except KeyError:
            raise KeyError(
                f"no media adapter registered for source kind {kind!r}"
            ) from None
        return factory()

    def __contains__(self, kind: SourceKind) -> bool:
        return kind in self._factories

    def kinds(self) -> tuple[SourceKind, ...]:
        return tuple(self._factories)
