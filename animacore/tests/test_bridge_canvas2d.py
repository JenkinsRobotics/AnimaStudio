"""Bridge canvas2d.* verbs — the 2D-workspace engine contract."""

from __future__ import annotations

import base64

from animacore.bridge import Session, handle_request


def _req(method, params=None, request_id=1):
    return {"id": request_id, "method": method, "params": params or {}}


_FACE_DTO = {
    "width": 64,
    "height": 64,
    "sources": [{"id": "face", "kind": "procedural", "asset": "simple"}],
    "surfaces": [
        {
            "id": "face",
            "source": "face",
            "drivers": [{"property": "opacity", "source": "fade"}],
        }
    ],
}


def test_describe_lists_kinds_and_faces():
    response = handle_request(Session(), _req("canvas2d.describe"))
    assert response["ok"]
    result = response["result"]
    assert "procedural" in result["source_kinds"]
    assert "image" in result["source_kinds"] and "bitmap" in result["source_kinds"]
    # Pillow is installed in the test env, so the media path is available.
    assert result["media_available"] is True
    assert "simple" in result["faces"]


def test_new_get_evaluate_release_roundtrip():
    session = Session()
    created = handle_request(session, _req("canvas2d.new", {"canvas": _FACE_DTO}))
    handle = created["result"]["handle"]
    assert handle == "canvas1"
    assert created["result"]["canvas"]["surfaces"][0]["id"] == "face"

    got = handle_request(session, _req("canvas2d.get", {"handle": handle}))
    assert got["result"]["canvas"]["width"] == 64

    evaluated = handle_request(
        session,
        _req("canvas2d.evaluate", {"handle": handle, "values": {"fade": 0.5}}),
    )
    states = evaluated["result"]["states"]
    assert states[0]["id"] == "face"
    assert states[0]["opacity"] == 0.5  # the opacity driver applied

    released = handle_request(session, _req("canvas2d.release", {"handle": handle}))
    assert released["result"]["released"] is True


def test_render_frame_returns_png():
    session = Session()
    handle = handle_request(session, _req("canvas2d.new", {"canvas": _FACE_DTO}))["result"]["handle"]
    response = handle_request(
        session, _req("canvas2d.render_frame", {"handle": handle, "time_seconds": 1.0})
    )
    assert response["ok"]
    assert response["result"]["width"] == 64
    png = base64.b64decode(response["result"]["png_base64"])
    assert png[:8] == b"\x89PNG\r\n\x1a\n"  # real PNG signature


def test_matrix_preview_downsamples():
    session = Session()
    handle = handle_request(session, _req("canvas2d.new", {"canvas": _FACE_DTO}))["result"]["handle"]
    response = handle_request(
        session,
        _req("canvas2d.matrix_preview", {"handle": handle, "target": {"width": 16, "height": 16}}),
    )
    rows = response["result"]["rows"]
    assert len(rows) == 16 and len(rows[0]) == 16 and len(rows[0][0]) == 3


def test_unknown_handle_errors():
    response = handle_request(Session(), _req("canvas2d.evaluate", {"handle": "nope"}))
    assert not response["ok"]
    assert response["error"]["code"] == "unknown_handle"


def test_invalid_canvas_dto_is_bad_request():
    response = handle_request(
        Session(),
        _req("canvas2d.new", {"canvas": {"surfaces": [{"id": "s", "source": "missing"}]}}),
    )
    assert not response["ok"]
    assert response["error"]["code"] == "bad_request"


def test_load_from_character_file_and_save():
    from pathlib import Path

    session = Session()
    text = (Path(__file__).resolve().parents[2] / "examples" / "pixel_face_2d.character.anima").read_text()
    loaded = handle_request(session, _req("canvas2d.load", {"text": text}))
    assert loaded["ok"]
    handle = loaded["result"]["handle"]
    assert loaded["result"]["canvas"]["sources"][0]["asset"] == "simple"

    saved = handle_request(session, _req("canvas2d.save", {"handle": handle}))
    assert "canvas2d:" in saved["result"]["yaml"]


def test_load_rig_only_document_reports_no_canvas():
    text = "anima_version: '2.0'\ntype: character\nidentity:\n  name: r\n"
    response = handle_request(Session(), _req("canvas2d.load", {"text": text}))
    assert not response["ok"]
    assert response["error"]["code"] == "no_canvas2d"


def test_incremental_surface_and_source_editing():
    session = Session()
    handle = handle_request(session, _req("canvas2d.new", {"canvas": _FACE_DTO}))["result"]["handle"]

    added = handle_request(
        session,
        _req("canvas2d.add_source", {"handle": handle, "source": {"id": "bg", "kind": "image", "asset": "bg.png"}}),
    )
    assert added["ok"] and len(added["result"]["canvas"]["sources"]) == 2

    surf = handle_request(
        session,
        _req("canvas2d.add_surface", {"handle": handle, "surface": {"id": "bg", "source": "bg", "z": -1}}),
    )
    assert surf["ok"] and len(surf["result"]["canvas"]["surfaces"]) == 2

    updated = handle_request(
        session,
        _req("canvas2d.update_surface", {"handle": handle, "surface": {"id": "bg", "source": "bg", "opacity": 0.5}}),
    )
    bg_surface = next(s for s in updated["result"]["canvas"]["surfaces"] if s["id"] == "bg")
    assert bg_surface["opacity"] == 0.5

    # Removing a source still referenced by a surface must be rejected.
    blocked = handle_request(session, _req("canvas2d.remove_source", {"handle": handle, "source_id": "bg"}))
    assert not blocked["ok"] and blocked["error"]["code"] == "bad_request"

    removed = handle_request(session, _req("canvas2d.remove_surface", {"handle": handle, "surface_id": "bg"}))
    assert removed["ok"] and len(removed["result"]["canvas"]["surfaces"]) == 1


def test_edit_unknown_handle_and_duplicate():
    session = Session()
    handle = handle_request(session, _req("canvas2d.new", {"canvas": _FACE_DTO}))["result"]["handle"]
    missing = handle_request(session, _req("canvas2d.add_surface", {"handle": "nope", "surface": {"id": "x", "source": "face"}}))
    assert missing["error"]["code"] == "unknown_handle"
    dup = handle_request(session, _req("canvas2d.add_surface", {"handle": handle, "surface": {"id": "face", "source": "face"}}))
    assert dup["error"]["code"] == "bad_request"


def test_describe_in_capabilities():
    response = handle_request(Session(), _req("hello", {"protocol_version": 1}))
    assert "canvas2d.evaluate" in response["result"]["capabilities"]
    assert "canvas2d.load" in response["result"]["capabilities"]
