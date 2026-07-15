"""Output adapter extension point: evaluated channel frames → a backend.

The contract that ``output_adapter`` extension contributions implement
(``dev/docs/roadmap/Extensions.md``; bundles load via
``anima_studio.extensions``) and that the built-in ``SimulatorOutput``
ships as the first consumer. An adapter carries normalized 0..1 channel
frames — exactly what ``rig.project_channels`` produces and
``wire.encode_frm`` encodes — to one device or protocol backend.

Nervous-system rule: adapters consume evaluated targets only. No rig
semantics, no timeline knowledge, no authoring state; hardware/vendor
channel detail lives behind this seam, never in the animation model.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Protocol, runtime_checkable

from anima_studio.sim import SimulatedDevice
from anima_studio.wire import (
    Err,
    Hello,
    WireError,
    encode_cfg,
    encode_en,
    encode_frm,
    encode_hello,
    encode_stop,
    parse_reply,
)


@dataclass(frozen=True)
class ChannelConfig:
    """One output channel's hardware configuration.

    Field names and units mirror ``wire.encode_cfg`` exactly: pulse
    widths in microseconds, ``neutral`` normalized 0..1, ``failsafe_ms``
    in milliseconds (``None`` keeps the device default). Range and
    consistency validation stays in ``wire.encode_cfg`` — one copy of
    that truth; this dataclass is only the host-side carrier handed to
    ``OutputAdapter.open``.
    """

    channel: int
    pin: int
    min_us: int
    max_us: int
    invert: bool = False
    neutral: float | None = None
    failsafe_ms: int | None = None


@runtime_checkable
class OutputAdapter(Protocol):
    """Lifecycle contract every output adapter implements.

    Constructor keyword arguments carry adapter-specific transport
    config (host, port, serial device, ...); an extension manifest's
    ``config:`` mapping is passed through as those kwargs. The
    lifecycle is ``open`` → ``send_frame``* → ``stop``/``close``.
    """

    def open(self, channel_configs: Sequence[ChannelConfig]) -> None:
        """Open the transport and configure (and arm) every channel."""
        ...

    def send_frame(
        self, targets: Mapping[int, float], duration_ms: int
    ) -> None:
        """Move each channel to its normalized 0..1 target over
        ``duration_ms`` (0 = jump immediately)."""
        ...

    def stop(self) -> None:
        """E-stop: disable every output now. Idempotent."""
        ...

    def close(self) -> None:
        """Release the transport. Does not imply ``stop``; a device
        losing its host is the failsafe's job, not close semantics."""
        ...


class SimulatorOutput:
    """The built-in adapter: wire lines into an in-process device.

    First consumer of the ``OutputAdapter`` point. It wraps — never
    reimplements — ``sim.SimulatedDevice``: every call encodes wire
    protocol lines via ``anima_studio.wire`` and feeds them through
    ``receive_line``, so the adapter exercises the same protocol path a
    hardware transport would. The wrapped ``device`` stays public so
    callers/tests can assert servo state and drive the simulated clock
    with ``device.tick(now_ms)``.
    """

    def __init__(self, device: SimulatedDevice | None = None):
        self.device = device if device is not None else SimulatedDevice()

    def open(self, channel_configs: Sequence[ChannelConfig]) -> None:
        """Handshake, then configure and arm every given channel."""
        reply = parse_reply(self.device.receive_line(encode_hello()))
        if not isinstance(reply, Hello):
            raise WireError(f"handshake failed: expected ANIMA, got {reply!r}")
        for config in channel_configs:
            self._send(
                encode_cfg(
                    config.channel,
                    pin=config.pin,
                    min_us=config.min_us,
                    max_us=config.max_us,
                    invert=config.invert,
                    neutral=config.neutral,
                    failsafe_ms=config.failsafe_ms,
                )
            )
            self._send(encode_en(config.channel, True))

    def send_frame(
        self, targets: Mapping[int, float], duration_ms: int
    ) -> None:
        self._send(encode_frm(duration_ms, targets))

    def stop(self) -> None:
        self._send(encode_stop())

    def close(self) -> None:
        """No transport to release: the device lives in-process."""

    def _send(self, line: str) -> None:
        reply = parse_reply(self.device.receive_line(line))
        if isinstance(reply, Err):
            raise WireError(
                f"simulated device rejected {line!r}: "
                f"ERR,{reply.code},{reply.message}"
            )
