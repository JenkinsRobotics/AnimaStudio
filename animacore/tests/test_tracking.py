"""Face-tracking vocabulary — the VR-character parameter contract."""

from __future__ import annotations

import pytest

from animacore.canvas2d import Canvas2D, SourceKind, Surface, SurfaceDriver, SurfaceProperty, VisualSource
from animacore.canvas2d import evaluate_surfaces
from animacore.tracking import ARKIT_BLENDSHAPES, FaceTrackingFrame, is_blendshape, namespaced


def test_vocabulary_is_the_52_arkit_blendshapes():
    assert len(ARKIT_BLENDSHAPES) == 52
    assert is_blendshape("jawOpen") and is_blendshape("eyeBlinkLeft")
    assert not is_blendshape("nope")


def test_frame_values_are_namespaced_and_clamped():
    frame = FaceTrackingFrame(blendshapes={"jawOpen": 1.5, "mouthSmileLeft": 0.5}, head_yaw=0.3)
    values = frame.values()
    assert values["face.jawOpen"] == 1.0  # clamped
    assert values["face.mouthSmileLeft"] == 0.5
    assert values["face.headYaw"] == 0.3


def test_unknown_blendshape_rejected():
    with pytest.raises(ValueError):
        FaceTrackingFrame(blendshapes={"jawWiggle": 1.0})


def test_tracking_drives_a_2d_avatar_end_to_end():
    # A VR character = an avatar whose drivers bind to face.* params. Proves the
    # tracking values flow straight into the existing evaluation, no new engine.
    canvas = Canvas2D(
        sources={"face": VisualSource(id="face", kind=SourceKind.PROCEDURAL, asset="simple")},
        surfaces=(
            Surface(
                id="face",
                source="face",
                drivers=(
                    SurfaceDriver(property=SurfaceProperty.OPACITY, source=namespaced("jawOpen")),
                ),
            ),
        ),
    )
    frame = FaceTrackingFrame(blendshapes={"jawOpen": 0.25})
    state = evaluate_surfaces(canvas, frame.values())[0]
    assert state.opacity == 0.25  # the tracked jawOpen drove the avatar
