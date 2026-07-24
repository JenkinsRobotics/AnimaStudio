"""Frame hardware outputs — the pixel-stream sibling of ``outputs.OutputAdapter``.

Where a scalar ``OutputAdapter`` mirrors evaluated DOF targets to servos, a
``FrameOutput`` mirrors a rasterized RGB frame to a display or LED matrix. The
engine still owns none of the pixels' *meaning*: a rasterizer (Swift for
preview, a headless one for hardware) composits the evaluated ``SurfaceState``s
into the frame handed here.

This module carries the renderer-neutral **target math** — chiefly the 64x64
LED-matrix downsample — so it is simulatable and testable now, before any panel
exists (the same discipline the servo simulator followed). Stdlib only.

A frame is ``list[list[RGB]]`` — rows top-to-bottom, each an
``(r, g, b)`` int triple 0..255.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Protocol, runtime_checkable

RGB = tuple[int, int, int]
Frame = Sequence[Sequence[RGB]]


@dataclass(frozen=True)
class LedMatrixTarget:
    """A low-resolution RGB matrix (e.g. 64x64) fed by downsampling a canvas.

    ``gamma`` shapes perceived brightness (LEDs are near-linear; >1 darkens
    mids). ``brightness`` is a 0..1 global cap (current/eye-safety headroom).
    """

    width: int = 64
    height: int = 64
    gamma: float = 1.0
    brightness: float = 1.0

    def __post_init__(self) -> None:
        if self.width < 1 or self.height < 1:
            raise ValueError(
                f"matrix size must be >= 1x1, got {self.width}x{self.height}"
            )
        if self.gamma <= 0:
            raise ValueError(f"gamma must be > 0, got {self.gamma}")
        if not 0.0 <= self.brightness <= 1.0:
            raise ValueError(f"brightness must be 0..1, got {self.brightness}")


def _channel(average: float, gamma: float, brightness: float) -> int:
    normalized = min(max(average / 255.0, 0.0), 1.0)
    shaped = normalized**gamma
    value = int(round(shaped * brightness * 255.0))
    return min(max(value, 0), 255)


def downsample_canvas(frame: Frame, target: LedMatrixTarget) -> list[list[RGB]]:
    """Area-average ``frame`` down to ``target`` size, then gamma + brightness.

    Each target cell averages the source pixels covering its footprint (nearest
    pixel when a cell is smaller than one source pixel, i.e. upsampling). Pure
    function — the LED simulation preview and the real matrix stream both call
    this so what you see is what the panel gets.
    """
    source_height = len(frame)
    if source_height == 0:
        raise ValueError("frame must have at least one row")
    source_width = len(frame[0])
    if source_width == 0:
        raise ValueError("frame rows must have at least one pixel")

    result: list[list[RGB]] = []
    for ty in range(target.height):
        row_start = ty * source_height // target.height
        row_end = max(row_start + 1, (ty + 1) * source_height // target.height)
        out_row: list[RGB] = []
        for tx in range(target.width):
            col_start = tx * source_width // target.width
            col_end = max(col_start + 1, (tx + 1) * source_width // target.width)

            red = green = blue = 0
            count = 0
            for sy in range(row_start, min(row_end, source_height)):
                source_row = frame[sy]
                for sx in range(col_start, min(col_end, source_width)):
                    pixel = source_row[sx]
                    red += pixel[0]
                    green += pixel[1]
                    blue += pixel[2]
                    count += 1
            count = max(count, 1)
            out_row.append(
                (
                    _channel(red / count, target.gamma, target.brightness),
                    _channel(green / count, target.gamma, target.brightness),
                    _channel(blue / count, target.gamma, target.brightness),
                )
            )
        result.append(out_row)
    return result


@runtime_checkable
class FrameOutput(Protocol):
    """Lifecycle contract for a frame hardware node (display / LED matrix).

    Mirrors ``outputs.OutputAdapter``: ``open`` → ``send_frame``* →
    ``stop``/``close``. ``send_frame`` takes a rasterized RGB frame at the
    target's native size and a monotonically increasing ``sequence`` id so a
    transport can drop stale frames.
    """

    def open(self) -> None:
        """Open the transport / initialize the panel."""
        ...

    def send_frame(self, frame: Frame, sequence: int) -> None:
        """Present ``frame`` (target-native size)."""
        ...

    def stop(self) -> None:
        """Blank the panel now. Idempotent."""
        ...

    def close(self) -> None:
        """Release the transport (does not imply ``stop``)."""
        ...


class SimulatorFrameOutput:
    """The built-in frame node: keeps the last presented frame in memory.

    First consumer of ``FrameOutput`` (the twin of ``SimulatorOutput``). It lets
    the app/tests preview exactly what a real panel would receive and drive the
    LED simulation without any hardware. ``downsample`` matches a real matrix
    node so preview == hardware.
    """

    def __init__(self, target: LedMatrixTarget | None = None):
        self.target = target
        self.last_frame: list[list[RGB]] | None = None
        self.last_sequence: int = -1
        self.opened = False

    def open(self) -> None:
        self.opened = True

    def send_frame(self, frame: Frame, sequence: int) -> None:
        if not self.opened:
            raise RuntimeError("send_frame before open")
        if self.target is not None:
            self.last_frame = downsample_canvas(frame, self.target)
        else:
            self.last_frame = [list(row) for row in frame]
        self.last_sequence = sequence

    def stop(self) -> None:
        self.last_frame = None

    def close(self) -> None:
        self.opened = False
