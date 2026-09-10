import base64
import pytest
from core.host.state import Problem
from core.host.tests.test_library import create
from animacore.aether_workspace import AetherWorkspace

pytest_plugins = ["core.host.tests.test_library"]


def test_history_restore_retains_future_and_current_permissions(library):
    host, _, _, _, call = library
    f = create(call)
    call("save", {"id": f["id"], "expected_revision": 1, "data_base64": "bmV3"})
    call("version", {"id": f["id"], "expected_revision": 2, "name": "Design review"})
    call("restore", {"id": f["id"], "expected_revision": 2, "revision": 1})
    assert (
        call("read", {"id": f["id"]})["data_base64"]
        == base64.b64encode(b"original").decode()
    )
    assert (
        call("read_revision", {"id": f["id"], "revision": 2})["data_base64"] == "bmV3"
    )
    history = call("history", {"id": f["id"]})
    assert [r["revision"] for r in history["revisions"]] == [3, 2, 1]
    assert history["versions"][0]["revision"] == 2
    assert (
        host.store.db.execute("SELECT count(*) FROM library_blobs").fetchone()[0] == 2
    )
    with pytest.raises(Problem):
        call("read_revision", {"id": f["id"], "revision": 1}, who=1)
    with pytest.raises(Problem) as err:
        call("restore", {"id": f["id"], "expected_revision": 2, "revision": 1})
    assert err.value.status == 409


def test_project_parts_assemblies_roundtrip_and_restore(library):
    _, _, _, _, call = library
    f = call("project_create", {"name": "Wheel project"})
    p = call("project_read", {"id": f["id"]})["project"]
    assert len(p["parts"]) == len(p["assemblies"]) == 1
    first = p["parts"][0]
    assert first["document"]["documentId"] == first["id"]
    call(
        "project_edit",
        {
            "id": f["id"],
            "expected_revision": 1,
            "operation": "add_part",
            "name": "Axle",
        },
    )
    p = call(
        "project_edit",
        {
            "id": f["id"],
            "expected_revision": 2,
            "operation": "add_assembly",
            "name": "Wheel assembly",
        },
    )["project"]
    assert len(p["parts"]) == len(p["assemblies"]) == 2
    assert p["parts"][0] == first
    archive = base64.b64decode(call("read", {"id": f["id"]})["data_base64"])
    reopened = AetherWorkspace.from_bytes(archive)
    assert len(reopened.part_definitions) == 2
    call("restore", {"id": f["id"], "expected_revision": 3, "revision": 1})
    assert len(call("project_read", {"id": f["id"]})["project"]["parts"]) == 1
    assert (
        len(call("project_read", {"id": f["id"], "revision": 3})["project"]["parts"])
        == 2
    )
    with pytest.raises(Problem):
        call(
            "project_edit",
            {"id": f["id"], "expected_revision": 4, "operation": "add_part"},
            who=1,
        )


def test_linked_part_pins_revision_and_export_retains_snapshot(library):
    import json

    _, _, _, _, call = library
    doc = {
        "format": "aether-part",
        "formatVersion": 3,
        "documentId": "source",
        "name": "Wheel",
        "units": "millimeter",
        "features": [],
    }
    source = create(
        call,
        name="Wheel.acpart",
        data_base64=base64.b64encode(json.dumps(doc).encode()).decode(),
    )
    project = call("project_create", {"name": "Linked wheel"})
    linked = call(
        "project_edit",
        {
            "id": project["id"],
            "expected_revision": 1,
            "operation": "link_part",
            "source_id": source["id"],
            "source_revision": 1,
        },
    )["project"]
    part = linked["parts"][-1]
    assert part["source"]["asset_ref"].endswith("@1")
    call(
        "save",
        {
            "id": source["id"],
            "expected_revision": 1,
            "data_base64": base64.b64encode(
                json.dumps({**doc, "name": "Changed source"}).encode()
            ).decode(),
        },
    )
    assert (
        call("project_read", {"id": project["id"]})["project"]["parts"][-1]["document"][
            "name"
        ]
        == "Wheel"
    )
    with pytest.raises(Problem):
        call(
            "project_edit",
            {
                "id": project["id"],
                "expected_revision": 2,
                "operation": "save_part",
                "part_id": part["id"],
                "document": doc,
            },
        )
    assembly = linked["assemblies"][0]
    call(
        "project_edit",
        {
            "id": project["id"],
            "expected_revision": 2,
            "operation": "insert_part",
            "part_id": part["id"],
            "assembly_id": assembly["id"],
            "name": "Wheel instance",
        },
    )
    archive = AetherWorkspace.from_bytes(
        base64.b64decode(call("read", {"id": project["id"]})["data_base64"])
    )
    assert next(iter(archive.instances.values()))["definition_id"] == part["id"]
    assert archive.part_definitions[part["id"]]["feature_document"]["name"] == "Wheel"


def test_standalone_assembly_uses_same_container_and_explicit_link_update(library):
    import json

    _, _, _, _, call = library
    assembly = call(
        "project_create", {"name": "Independent assembly", "packaging": "assembly"}
    )
    assert assembly["name"].endswith(".acasm")
    assert not call("project_read", {"id": assembly["id"]})["project"]["parts"]
    doc = {
        "format": "aether-part",
        "formatVersion": 3,
        "documentId": "standalone",
        "name": "Original",
        "units": "millimeter",
        "features": [],
    }
    source = create(
        call,
        name="Original.acpart",
        data_base64=base64.b64encode(json.dumps(doc).encode()).decode(),
    )
    linked = call(
        "project_edit",
        {
            "id": assembly["id"],
            "expected_revision": 1,
            "operation": "link_part",
            "source_id": source["id"],
            "source_revision": 1,
        },
    )["project"]["parts"][0]
    call(
        "save",
        {
            "id": source["id"],
            "expected_revision": 1,
            "data_base64": base64.b64encode(
                json.dumps({**doc, "name": "Updated"}).encode()
            ).decode(),
        },
    )
    updated = call(
        "project_edit",
        {
            "id": assembly["id"],
            "expected_revision": 2,
            "operation": "update_link",
            "part_id": linked["id"],
            "source_id": source["id"],
            "source_revision": 2,
        },
    )["project"]["parts"][0]
    assert updated["id"] == linked["id"]
    assert updated["document"]["name"] == "Updated"
    assert updated["source"]["asset_ref"].endswith("@2")
    old = call("project_read", {"id": assembly["id"], "revision": 2})["project"][
        "parts"
    ][0]
    assert old["document"]["name"] == "Original"
