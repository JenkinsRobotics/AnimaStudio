"""Persistent Aether Assembly/Mate/BOM producer contract gates."""

from __future__ import annotations

import copy
import base64
import hashlib
import io
import json
import zipfile
from pathlib import Path

import pytest

from animacore.bridge import CAPABILITIES, Session, handle_request


def rpc(session: Session, method: str, **params):
    response = handle_request(
        session, {"id": f"request-{method}", "method": method, "params": params}
    )
    assert response["ok"], response
    return response["result"]


def mutate(session: Session, handle: str, revision: str, method: str, **params):
    return rpc(
        session,
        method,
        handle=handle,
        expected_revision=revision,
        **params,
    )


def add_part(session: Session, handle: str, revision: str, name: str,
             number: str, mass_kg: float):
    result = mutate(
        session,
        handle,
        revision,
        "add_part_definition",
        part_definition={
            "name": name,
            "part_number": number,
            "mass_kg": mass_kg,
            "source": {"kind": "authored", "label": f"{name}.step"},
            "custom_properties": [{"key": "finish", "value": "natural"}],
        },
    )
    part = next(item for item in result["assembly"]["part_definitions"]
                if item["name"] == name)
    return result, part["id"]


def add_instance(session: Session, handle: str, revision: str, assembly_id: str,
                 part_id: str, name: str, *, grounded: bool = False,
                 position_m=(0.0, 0.0, 0.0)):
    result = mutate(
        session,
        handle,
        revision,
        "add_instance",
        assembly_id=assembly_id,
        instance={
            "parent_assembly_id": assembly_id,
            "definition_kind": "part",
            "definition_id": part_id,
            "name": name,
            "grounded": grounded,
            "rest_transform": {
                "position_m": list(position_m),
                "rotation_quaternion_xyzw": [0, 0, 0, 1],
            },
        },
    )
    instance = next(item for item in result["assembly"]["instances"]
                    if item["name"] == name)
    return result, instance["id"]


def add_connector(session: Session, handle: str, revision: str,
                  assembly_id: str, part_id: str, name: str,
                  *, origin=(0.0, 0.0, 0.0)):
    result = mutate(
        session,
        handle,
        revision,
        "add_connector",
        assembly_id=assembly_id,
        connector={
            "part_definition_id": part_id,
            "name": name,
            "frame_part_local": {
                "origin_m": list(origin),
                # Deliberately non-unit/non-orthogonal: Core normalizes it.
                "primary_axis_xyz": [0, 0, 2],
                "secondary_axis_xyz": [3, 0, 1],
            },
            "provenance": {"kind": "manual", "label": name},
        },
    )
    connector = next(item for item in result["assembly"]["connector_definitions"]
                     if item["name"] == name)
    return result, connector["id"]


def populated_workspace(session: Session):
    described = rpc(session, "new_workspace", name="Drive Module")
    handle = described["handle"]
    assembly_id = described["root_assembly_id"]
    result, base_part = add_part(session, handle, described["revision"],
                                 "Base", "BASE-01", 2.0)
    result, arm_part = add_part(session, handle, result["revision"],
                                "Arm", "ARM-01", 0.5)
    result, base = add_instance(
        session, handle, result["revision"], assembly_id, base_part, "Base:1",
        grounded=True,
    )
    result, arm1 = add_instance(
        session, handle, result["revision"], assembly_id, arm_part, "Arm:1",
        position_m=(0, 0, 1),
    )
    result, arm2 = add_instance(
        session, handle, result["revision"], assembly_id, arm_part, "Arm:2",
        position_m=(0, 0, 2),
    )
    result, base_connector = add_connector(
        session, handle, result["revision"], assembly_id, base_part, "Base axis"
    )
    result, arm_connector = add_connector(
        session, handle, result["revision"], assembly_id, arm_part, "Arm axis"
    )
    return {
        "session": session,
        "handle": handle,
        "assembly_id": assembly_id,
        "revision": result["revision"],
        "base_part": base_part,
        "arm_part": arm_part,
        "base": base,
        "arm1": arm1,
        "arm2": arm2,
        "base_connector": base_connector,
        "arm_connector": arm_connector,
        "result": result,
    }


def mate_payload(kind: str, name: str, endpoint_a: tuple[str, str],
                 endpoint_b: tuple[str, str], *, minimum=None, maximum=None):
    dofs = []
    if kind == "revolute":
        dofs = [{
            "name": "rotation",
            "value_rad": 0.0,
            "neutral_rad": 0.0,
            "limit_min_rad": minimum,
            "limit_max_rad": maximum,
        }]
    elif kind == "prismatic":
        dofs = [{
            "name": "translation",
            "value_m": 0.0,
            "neutral_m": 0.0,
            "limit_min_m": minimum,
            "limit_max_m": maximum,
        }]
    return {
        "name": name,
        "type_id": kind,
        "endpoint_a": {
            "instance_id": endpoint_a[0],
            "connector_definition_id": endpoint_a[1],
        },
        "endpoint_b": {
            "instance_id": endpoint_b[0],
            "connector_definition_id": endpoint_b[1],
        },
        "dofs": dofs,
        "controls": [],
    }


def test_workspace_verbs_are_advertised():
    required = {
        "new_workspace", "load_workspace", "save_workspace",
        "describe_workspace", "describe_assembly", "project_bom",
        "solve_assembly", "add_instance", "add_connector", "set_dof_value",
    }
    assert required <= set(CAPABILITIES)


def test_stable_ids_ordering_and_connector_normalization():
    state = populated_workspace(Session())
    projection = rpc(
        state["session"], "describe_assembly", handle=state["handle"],
        assembly_id=state["assembly_id"],
    )
    assert projection["schema_version"] == 1
    assert [item["id"] for item in projection["part_definitions"]] == sorted(
        item["id"] for item in projection["part_definitions"]
    )
    assert len(projection["part_definitions"]) == 2
    assert len(projection["instances"]) == 3
    assert len(projection["connector_definitions"]) == 2
    connector = projection["connector_definitions"][0]["frame_part_local"]
    primary = connector["primary_axis_xyz"]
    secondary = connector["secondary_axis_xyz"]
    assert sum(value * value for value in primary) == pytest.approx(1.0)
    assert sum(value * value for value in secondary) == pytest.approx(1.0)
    assert sum(a * b for a, b in zip(primary, secondary)) == pytest.approx(0.0)


@pytest.mark.parametrize("kind", ["fastened", "revolute", "prismatic"])
def test_preview_is_non_mutating_and_commit_increments_once(kind):
    state = populated_workspace(Session())
    mate = mate_payload(
        kind, kind.title(),
        (state["base"], state["base_connector"]),
        (state["arm1"], state["arm_connector"]),
        minimum=-1.0 if kind != "fastened" else None,
        maximum=1.0 if kind != "fastened" else None,
    )
    preview = rpc(
        state["session"], "preview_mate", handle=state["handle"],
        assembly_id=state["assembly_id"], mate=mate,
    )
    assert preview["revision"] == state["revision"]
    assert preview["solution"]["revision"] == state["revision"]
    unchanged = rpc(
        state["session"], "describe_assembly", handle=state["handle"],
        assembly_id=state["assembly_id"],
    )
    assert unchanged["revision"] == state["revision"]
    assert unchanged["mates"] == []

    committed = mutate(
        state["session"], state["handle"], state["revision"], "add_mate",
        assembly_id=state["assembly_id"], mate=mate,
    )
    assert int(committed["revision"]) == int(state["revision"]) + 1
    assert committed["assembly"]["revision"] == committed["revision"]
    assert committed["solution"]["revision"] == committed["revision"]
    assert committed["bom"]["revision"] == committed["revision"]
    assert committed["assembly"]["mates"][0]["type_id"] == kind


def test_tree_solve_relations_units_limits_suppression_and_bom():
    state = populated_workspace(Session())
    first = mate_payload(
        "revolute", "Shoulder",
        (state["base"], state["base_connector"]),
        (state["arm1"], state["arm_connector"]),
        minimum=-1.0, maximum=1.0,
    )
    result = mutate(
        state["session"], state["handle"], state["revision"], "add_mate",
        assembly_id=state["assembly_id"], mate=first,
    )
    second = mate_payload(
        "revolute", "Elbow",
        (state["arm1"], state["arm_connector"]),
        (state["arm2"], state["arm_connector"]),
        minimum=-0.5, maximum=0.5,
    )
    result = mutate(
        state["session"], state["handle"], result["revision"], "add_mate",
        assembly_id=state["assembly_id"], mate=second,
    )
    shoulder, elbow = result["assembly"]["mates"]
    shoulder_dof = shoulder["dofs"][0]["id"]
    elbow_dof = elbow["dofs"][0]["id"]
    result = mutate(
        state["session"], state["handle"], result["revision"], "add_relation",
        assembly_id=state["assembly_id"],
        relation={
            "kind": "gear", "driver_dof_id": shoulder_dof,
            "driven_dof_id": elbow_dof, "ratio": -2.0,
            "offset_rad": 0.1, "reversed": True,
        },
    )
    result = mutate(
        state["session"], state["handle"], result["revision"], "set_dof_value",
        assembly_id=state["assembly_id"], dof_id=shoulder_dof, value_rad=0.4,
    )
    values = {item["dof_id"]: item for item in result["solution"]["dof_values"]}
    assert values[shoulder_dof] == {
        "dof_id": shoulder_dof, "value_rad": 0.4, "value_m": None
    }
    assert values[elbow_dof]["value_rad"] == pytest.approx(-0.7)
    assert result["solution"]["limit_violations"][0]["dof_id"] == elbow_dof
    assert result["assembly"]["mates"][1]["dofs"][0]["state"] == "dependent"
    assert result["solution"]["remaining_free_dof_count"] == 1

    flat = rpc(
        state["session"], "project_bom", handle=state["handle"],
        assembly_id=state["assembly_id"], mode="flattened",
    )
    assert [(row["name"], row["quantity"]) for row in flat["rows"]] == [
        ("Base", 1), ("Arm", 2)
    ]
    assert flat["total_mass_kg"] == pytest.approx(3.0)
    result = mutate(
        state["session"], state["handle"], result["revision"],
        "set_instance_suppressed", assembly_id=state["assembly_id"],
        instance_id=state["arm2"], suppressed=True,
    )
    assert [(row["name"], row["quantity"]) for row in result["bom"]["rows"]] == [
        ("Base", 1), ("Arm", 1)
    ]
    solved_ids = {
        item["instance_id"] for item in result["solution"]["instance_world_transforms"]
    }
    assert state["arm2"] not in solved_ids


def test_stale_revision_is_atomic():
    state = populated_workspace(Session())
    before = rpc(
        state["session"], "describe_assembly", handle=state["handle"],
        assembly_id=state["assembly_id"],
    )
    response = handle_request(
        state["session"],
        {
            "id": "stale",
            "method": "set_instance_grounded",
            "params": {
                "handle": state["handle"], "expected_revision": "0",
                "assembly_id": state["assembly_id"],
                "instance_id": state["arm1"], "grounded": True,
            },
        },
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "revision_conflict"
    after = rpc(
        state["session"], "describe_assembly", handle=state["handle"],
        assembly_id=state["assembly_id"],
    )
    assert after == before


def test_save_release_reopen_is_deterministic(tmp_path: Path):
    session = Session()
    state = populated_workspace(session)
    mate = mate_payload(
        "prismatic", "Travel",
        (state["base"], state["base_connector"]),
        (state["arm1"], state["arm_connector"]),
        minimum=-0.25, maximum=0.25,
    )
    result = mutate(
        session, state["handle"], state["revision"], "add_mate",
        assembly_id=state["assembly_id"], mate=mate,
    )
    before_workspace = rpc(session, "describe_workspace", handle=state["handle"])
    before_projection = rpc(
        session, "describe_assembly", handle=state["handle"],
        assembly_id=state["assembly_id"],
    )
    before_solution = rpc(
        session, "solve_assembly", handle=state["handle"],
        assembly_id=state["assembly_id"],
    )
    before_boms = [
        rpc(session, "project_bom", handle=state["handle"],
            assembly_id=state["assembly_id"], mode=mode)
        for mode in ("hierarchical", "flattened")
    ]
    first = tmp_path / "drive.aether"
    second = tmp_path / "drive-copy.aether"
    rpc(
        session, "save_workspace", handle=state["handle"],
        expected_revision=result["revision"], path=str(first),
    )
    rpc(
        session, "save_workspace", handle=state["handle"],
        expected_revision=result["revision"], path=str(second),
    )
    assert first.read_bytes() == second.read_bytes()
    assert hashlib.sha256(first.read_bytes()).hexdigest() == hashlib.sha256(
        second.read_bytes()
    ).hexdigest()
    rpc(session, "release", handle=state["handle"])
    loaded = rpc(session, "load_workspace", path=str(first))
    assert loaded["graph_sha256"] == before_workspace["graph_sha256"]
    reopened_projection = rpc(
        session, "describe_assembly", handle=loaded["handle"],
        assembly_id=state["assembly_id"],
    )
    reopened_solution = rpc(
        session, "solve_assembly", handle=loaded["handle"],
        assembly_id=state["assembly_id"],
    )
    reopened_boms = [
        rpc(session, "project_bom", handle=loaded["handle"],
            assembly_id=state["assembly_id"], mode=mode)
        for mode in ("hierarchical", "flattened")
    ]
    assert reopened_projection == before_projection
    assert reopened_solution == before_solution
    assert reopened_boms == before_boms


def test_browser_byte_save_and_open_use_the_canonical_container():
    session = Session()
    state = populated_workspace(session)
    saved = rpc(
        session,
        "save_workspace",
        handle=state["handle"],
        expected_revision=state["revision"],
        return_data=True,
    )
    archive_bytes = base64.b64decode(saved["data_base64"], validate=True)
    with zipfile.ZipFile(io.BytesIO(archive_bytes), "r") as archive:
        assert archive.namelist() == ["manifest.json", "state/graph.json"]

    rpc(session, "release", handle=state["handle"])
    reopened = rpc(
        session,
        "load_workspace",
        data_base64=saved["data_base64"],
    )
    assert reopened["workspace_id"] == "workspace-0001"
    assert reopened["revision"] == state["revision"]
    assert reopened["graph_sha256"] == saved["graph_sha256"]


def test_browser_open_rejects_malformed_base64_without_replacing_state():
    session = Session()
    state = populated_workspace(session)
    response = handle_request(
        session,
        {
            "id": "bad-bytes",
            "method": "load_workspace",
            "params": {"data_base64": "not base64!"},
        },
    )
    assert response["ok"] is False
    assert response["error"] == {
        "code": "bad_request",
        "message": "'data_base64' is not valid base64",
        "path": "data_base64",
    }
    assert rpc(session, "describe_workspace", handle=state["handle"])[
        "workspace_id"
    ] == "workspace-0001"


def test_disposable_cache_does_not_change_semantic_graph(tmp_path: Path):
    session = Session()
    state = populated_workspace(session)
    clean = tmp_path / "clean.aether"
    cached = tmp_path / "cached.aether"
    saved = rpc(session, "save_workspace", handle=state["handle"], path=str(clean))
    with zipfile.ZipFile(clean, "r") as source, zipfile.ZipFile(cached, "w") as target:
        for info in source.infolist():
            target.writestr(info, source.read(info.filename))
        target.writestr("cache/kernel/broken.brep", b"not-a-brep")
    loaded = rpc(session, "load_workspace", path=str(cached))
    assert loaded["graph_sha256"] == saved["graph_sha256"]
    projection = rpc(
        session, "describe_assembly", handle=loaded["handle"],
        assembly_id=state["assembly_id"],
    )
    assert [issue["code"] for issue in projection["issues"]] == ["cache_ignored"]


def test_unknown_graph_version_does_not_replace_open_state(tmp_path: Path):
    session = Session()
    state = populated_workspace(session)
    good = tmp_path / "good.aether"
    bad = tmp_path / "bad.aether"
    rpc(session, "save_workspace", handle=state["handle"], path=str(good))
    with zipfile.ZipFile(good, "r") as source:
        manifest = json.loads(source.read("manifest.json"))
        graph = json.loads(source.read("state/graph.json"))
    graph["schema_version"] = 999
    graph_bytes = (json.dumps(graph, sort_keys=True, separators=(",", ":")) + "\n").encode()
    manifest["graph_sha256"] = hashlib.sha256(graph_bytes).hexdigest()
    with zipfile.ZipFile(bad, "w") as target:
        target.writestr("manifest.json", json.dumps(manifest))
        target.writestr("state/graph.json", graph_bytes)
    response = handle_request(
        session, {"id": "bad", "method": "load_workspace", "params": {"path": str(bad)}}
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "format_error"
    # Existing handle and semantic graph are untouched by the failed load.
    described = rpc(session, "describe_workspace", handle=state["handle"])
    assert described["workspace_id"] == "workspace-0001"


def test_wrong_dof_unit_family_is_atomic():
    state = populated_workspace(Session())
    mate = mate_payload(
        "revolute", "Shoulder",
        (state["base"], state["base_connector"]),
        (state["arm1"], state["arm_connector"]), minimum=-1, maximum=1,
    )
    result = mutate(
        state["session"], state["handle"], state["revision"], "add_mate",
        assembly_id=state["assembly_id"], mate=mate,
    )
    before = copy.deepcopy(result["assembly"])
    dof_id = before["mates"][0]["dofs"][0]["id"]
    response = handle_request(
        state["session"],
        {
            "id": "wrong-unit", "method": "set_dof_value",
            "params": {
                "handle": state["handle"], "expected_revision": result["revision"],
                "assembly_id": state["assembly_id"], "dof_id": dof_id,
                "value_m": 0.2,
            },
        },
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "validation_error"
    after = rpc(
        state["session"], "describe_assembly", handle=state["handle"],
        assembly_id=state["assembly_id"],
    )
    assert after == before


def test_failed_mutation_leaves_state_untouched():
    """A rejected mutation must not advance the revision.

    Regression: mutate() swapped the draft in before validating the target,
    so a failed call bumped the revision and the client's natural retry hit a
    spurious revision_conflict.
    """
    state = populated_workspace(Session())
    session, handle = state["session"], state["handle"]
    before = rpc(session, "describe_workspace", handle=handle)
    response = handle_request(
        session,
        {
            "id": "request-bad-assembly",
            "method": "set_dof_value",
            "params": {
                "handle": handle,
                "expected_revision": state["revision"],
                "assembly_id": "no-such-assembly",
                "dof_id": "missing-dof",
                "value_rad": 0.5,
            },
        },
    )
    assert not response["ok"]
    after = rpc(session, "describe_workspace", handle=handle)
    assert after == before
    # The same call with the unchanged revision must still be accepted.
    assert rpc(session, "describe_assembly", handle=handle,
               assembly_id=state["assembly_id"])["revision"] == before["revision"]


def test_limit_violation_surfaces_in_issues_and_diagnostic_ids_resolve():
    """Projection issues must carry the diagnostics the solve reports.

    Regression: the issue filter excluded exactly the diagnostics the solve
    had just produced, so `issues` was always empty while `diagnostic_ids`
    referenced entries that existed nowhere.
    """
    state = populated_workspace(Session())
    session, handle = state["session"], state["handle"]
    mate = mate_payload(
        "revolute", "Shoulder",
        (state["base"], state["base_connector"]),
        (state["arm1"], state["arm_connector"]),
        minimum=-1.0, maximum=1.0,
    )
    result = mutate(session, handle, state["revision"], "add_mate",
                    assembly_id=state["assembly_id"], mate=mate)
    dof_id = result["assembly"]["mates"][0]["dofs"][0]["id"]
    result = mutate(session, handle, result["revision"], "set_dof_value",
                    assembly_id=state["assembly_id"], dof_id=dof_id, value_rad=2.0)

    issues = result["assembly"]["issues"]
    violations = [issue for issue in issues if issue["code"] == "limit_violation"]
    assert violations, issues
    assert dof_id in violations[0]["entity_ids"]
    # Every id the solution reports resolves to a real issue entry.
    published = {issue["id"] for issue in issues}
    assert set(result["solution"]["diagnostic_ids"]) <= published


def test_bom_parent_links_never_dangle():
    """Rows may only point at parents that are themselves in the BOM.

    Regression: suppressing a parent removed its row but left children
    referencing `instance:<suppressed-id>`.
    """
    state = populated_workspace(Session())
    session, handle = state["session"], state["handle"]
    result = mutate(session, handle, state["revision"], "move_instance",
                    assembly_id=state["assembly_id"],
                    instance_id=state["arm1"], parent_instance_id=state["base"])
    rows = result["bom"]["rows"]
    assert any(row["parent_row_id"] == f"instance:{state['base']}" for row in rows), rows

    result = mutate(session, handle, result["revision"], "set_instance_suppressed",
                    assembly_id=state["assembly_id"],
                    instance_id=state["base"], suppressed=True)
    rows = result["bom"]["rows"]
    present = {row["row_id"] for row in rows}
    for row in rows:
        assert row["parent_row_id"] is None or row["parent_row_id"] in present, row


def test_a_second_child_cannot_hide_a_mate_cycle():
    """The cycle guard must see every edge, not one per parent.

    Regression: the walk was keyed by parent instance, so a parent with two
    children kept only its last edge and a back edge behind that second child
    was accepted. arm2 -> arm1 plus arm1 -> arm2 is a cycle; adding
    arm2 -> arm3 in between used to hide it.
    """
    state = populated_workspace(Session())
    session, handle, assembly_id = state["session"], state["handle"], state["assembly_id"]
    result, arm3 = add_instance(
        session, handle, state["revision"], assembly_id, state["arm_part"],
        "Arm:3", position_m=(0, 0, 3),
    )
    for name, parent, child in (
        ("Elbow", state["arm2"], state["arm1"]),
        ("Wrist", state["arm2"], arm3),
    ):
        result = mutate(
            session, handle, result["revision"], "add_mate",
            assembly_id=assembly_id,
            mate=mate_payload("revolute", name,
                              (parent, state["arm_connector"]),
                              (child, state["arm_connector"])),
        )
    revision_before = result["revision"]
    response = handle_request(session, {
        "id": "request-add_mate", "method": "add_mate",
        "params": {
            "handle": handle, "expected_revision": revision_before,
            "assembly_id": assembly_id,
            "mate": mate_payload("revolute", "Back edge",
                                 (state["arm1"], state["arm_connector"]),
                                 (state["arm2"], state["arm_connector"])),
        },
    })
    assert not response["ok"], response
    assert response["error"]["message"] == "mate graph contains a cycle"
    # Rejected before mutation: the graph and revision are untouched.
    after = rpc(session, "describe_workspace", handle=handle)
    assert after["revision"] == revision_before
    assert len(rpc(session, "describe_assembly", handle=handle,
                   assembly_id=assembly_id)["mates"]) == 2


def test_unresolved_mates_project_failed_not_satisfied():
    """A mate the solver could not place must not read "satisfied".

    Regression: `solve_state` was only suppressed|warning|satisfied, so a
    mate the solve left in its `pending` list — reporting
    `status: "unconverged"` and naming those mates in a diagnostic — showed
    as green in the projection while its instance never moved. The verbs
    reject a cycle up front, so this pins the projection itself: state that
    arrives any other way must still be described truthfully.
    """
    state = populated_workspace(Session())
    session, handle, assembly_id = state["session"], state["handle"], state["assembly_id"]
    result = mutate(
        session, handle, state["revision"], "add_mate",
        assembly_id=assembly_id,
        mate=mate_payload("revolute", "Shoulder",
                          (state["base"], state["base_connector"]),
                          (state["arm1"], state["arm_connector"])),
    )
    # A solvable mate reads satisfied, so "failed" is not the new default.
    assert result["solution"]["status"] == "solved"
    assert result["assembly"]["mates"][0]["solve_state"] == "satisfied"

    workspace = session._workspaces[handle]
    shoulder = next(iter(workspace.mates.values()))
    # arm1 <-> arm2 with neither grounded: the tree walk can seed neither, so
    # both mates stay in `pending` and the solve reports unconverged.
    forward = copy.deepcopy(shoulder)
    forward["id"], forward["name"] = "mate-cycle-a", "Elbow"
    forward["endpoint_a"] = {"instance_id": state["arm1"],
                             "connector_definition_id": state["arm_connector"]}
    forward["endpoint_b"] = {"instance_id": state["arm2"],
                             "connector_definition_id": state["arm_connector"]}
    backward = copy.deepcopy(forward)
    backward["id"], backward["name"] = "mate-cycle-b", "Wrist"
    backward["endpoint_a"], backward["endpoint_b"] = forward["endpoint_b"], forward["endpoint_a"]
    for index, item in enumerate((forward, backward)):
        for dof_index, dof in enumerate(item["dofs"]):
            dof["id"] = f"dof-cycle-{index}-{dof_index}"
    workspace.mates = {item["id"]: item for item in (forward, backward)}

    solution = workspace.solve(assembly_id)
    assert solution["status"] == "unconverged"
    projection = workspace.projection(assembly_id)
    states = [mate["solve_state"] for mate in projection["mates"]]
    assert states == ["failed", "failed"], projection["mates"]
    published = {issue["id"] for issue in projection["issues"]}
    for mate in projection["mates"]:
        assert mate["diagnostic_ids"], mate
        assert set(mate["diagnostic_ids"]) <= published


def test_instance_parent_cycles_are_rejected():
    """Parenting an instance inside its own subtree would orphan the tree.

    Regression: the check only rejected a self-parent, so A→B→A was accepted,
    both instances dropped out of root_instance_ids, and the cycle survived
    save/reload.
    """
    state = populated_workspace(Session())
    session, handle = state["session"], state["handle"]
    result = mutate(session, handle, state["revision"], "move_instance",
                    assembly_id=state["assembly_id"],
                    instance_id=state["arm1"], parent_instance_id=state["base"])
    response = handle_request(
        session,
        {
            "id": "request-cycle",
            "method": "move_instance",
            "params": {
                "handle": handle,
                "expected_revision": result["revision"],
                "assembly_id": state["assembly_id"],
                "instance_id": state["base"],
                "parent_instance_id": state["arm1"],
            },
        },
    )
    assert not response["ok"]
    assert response["error"]["path"] == "parent_instance_id"
    # The rejection left the tree intact at the unchanged revision.
    projection = rpc(session, "describe_assembly", handle=handle,
                     assembly_id=state["assembly_id"])
    assert projection["revision"] == result["revision"]
    base = next(item for item in projection["instances"] if item["id"] == state["base"])
    assert base["parent_instance_id"] is None
