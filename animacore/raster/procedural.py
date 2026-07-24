"""Procedural surfaces — the parametric face primitive (L4, no asset).

The MathScript idea, ported from Mochi (`animation/adapters/math_adapter.py`,
Apache-2.0): a face is a tiny function that *draws* from parameters each frame —
infinite expression + viseme states from one source, native-res for an LED
matrix. Unlike Mochi's ``MathAdapter`` we do **not** dynamically ``importlib`` an
arbitrary Python file (that adapter's own docstring flags it as an arbitrary-code
risk); faces are registered Python objects, addressed by a source's ``asset``.

A procedural face reads the same evaluated parameter stream (``values``) the rig
produces — the compositor pushes the live values in via ``set_params`` each
frame, so "happy" is just a set of parameter values, not a special concept.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Protocol, runtime_checkable

from animacore.raster.frame import FrameBuffer


@runtime_checkable
class ProceduralFace(Protocol):
    """Draws a face at ``width`` x ``height`` from ``params`` and a clock."""

    def render(
        self,
        width: int,
        height: int,
        time_seconds: float,
        params: Mapping[str, float],
    ) -> FrameBuffer: ...


class FaceRegistry:
    """Names -> procedural faces, addressed by a source's ``asset``."""

    def __init__(self) -> None:
        self._by_name: dict[str, ProceduralFace] = {}

    def register(self, name: str, face: ProceduralFace) -> ProceduralFace:
        self._by_name[name] = face
        return face

    def get(self, name: str) -> ProceduralFace:
        try:
            return self._by_name[name]
        except KeyError:
            raise KeyError(f"no procedural face registered as {name!r}") from None

    def names(self) -> tuple[str, ...]:
        return tuple(self._by_name)


class ProceduralAdapter:
    """Media adapter that renders a named procedural face each frame.

    ``open`` selects the face; ``set_params`` receives the live evaluated value
    stream from the compositor; ``next_frame(t)`` draws it. Never returns None —
    a procedural face loops forever until ``close``.
    """

    def __init__(self, faces: FaceRegistry) -> None:
        self._faces = faces
        self._face: ProceduralFace | None = None
        self._width = 0
        self._height = 0
        self._params: dict[str, float] = {}

    def open(self, asset_path: str, *, width: int, height: int, params: dict) -> None:
        self._face = self._faces.get(asset_path)
        self._width = max(1, int(width))
        self._height = max(1, int(height))
        self._params = dict(params or {})

    def set_params(self, values: Mapping[str, float]) -> None:
        """Push the current evaluated value stream (called per frame)."""
        self._params = dict(values or {})

    def close(self) -> None:
        self._face = None

    def next_frame(self, t: float) -> FrameBuffer | None:
        if self._face is None:
            return None
        return self._face.render(self._width, self._height, t, self._params)


def default_faces() -> FaceRegistry:
    """The built-in face library (``"simple"`` today)."""
    from animacore.raster.faces.simple_face import SimpleFace

    registry = FaceRegistry()
    registry.register("simple", SimpleFace())
    return registry
