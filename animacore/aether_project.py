"""Project operations over the canonical Aether workspace graph."""

import copy
import uuid

from .aether_workspace import AetherWorkspace, AetherWorkspaceError


def new_project(name):
    workspace = AetherWorkspace.new(0, name)
    workspace.workspace_id = str(uuid.uuid4())
    return workspace


def project_projection(workspace):
    return {
        "id": workspace.workspace_id,
        "name": workspace.name,
        "parts": [
            {
                "id": p["id"],
                "name": p["name"],
                "document": p.get("feature_document"),
                "source": p["source"],
            }
            for p in workspace.part_definitions.values()
        ],
        "assemblies": [
            {"id": a["id"], "name": a["name"]} for a in workspace.assemblies.values()
        ],
    }


def edit_project(workspace, action, data):
    name = data.get("name", "Untitled Part")
    if not isinstance(name, str) or not 1 <= len(name.strip()) <= 180:
        raise AetherWorkspaceError(
            "bad_request", "A name of 1–180 characters is required."
        )
    if action == "add_part":
        part = workspace._build_part_definition({"name": name.strip()}, assign=True)
        doc = data.get("document") or {
            "format": "aether-part",
            "formatVersion": 3,
            "units": "millimeter",
            "features": [],
        }
        part["feature_document"] = {
            **copy.deepcopy(doc),
            "documentId": part["id"],
            "name": part["name"],
        }
        workspace.part_definitions[part["id"]] = workspace._build_part_definition(
            part, assign=False
        )
    elif action in ("link_part", "update_link"):
        doc = copy.deepcopy(data["document"])
        previous = (
            workspace.part_definitions.get(data.get("part_id"))
            if action == "update_link"
            else None
        )
        if action == "update_link" and (
            not previous
            or previous["source"]["kind"] != "linked"
            or previous["source"]["asset_ref"].split("@")[0]
            != data["source_ref"].split("@")[0]
        ):
            raise AetherWorkspaceError(
                "bad_request", "Choose a revision of this Part's original source."
            )
        part = workspace._build_part_definition(
            {
                **(previous or {}),
                "name": doc["name"],
                "source": {
                    "kind": "linked",
                    "label": data["source_label"],
                    "asset_ref": data["source_ref"],
                    "status": "read_only",
                },
            },
            assign=previous is None,
        )
        doc["documentId"] = part["id"]
        part["feature_document"] = doc
        workspace.part_definitions[part["id"]] = workspace._build_part_definition(
            part, assign=False
        )
    elif action == "insert_part":
        workspace._add_instance(
            {
                "instance": {
                    "parent_assembly_id": data["assembly_id"],
                    "definition_kind": "part",
                    "definition_id": data["part_id"],
                    "name": name,
                    "rest_transform": {
                        "position_m": [0, 0, 0],
                        "rotation_quaternion_xyzw": [0, 0, 0, 1],
                    },
                    "grounded": True,
                }
            }
        )
    elif action == "save_part":
        part = workspace.part_definitions.get(data.get("part_id"))
        if not part:
            raise AetherWorkspaceError("unknown_entity", "Part not found.")
        if part["source"]["kind"] == "linked":
            raise AetherWorkspaceError(
                "read_only",
                "Linked Parts are pinned snapshots. Edit the source Part instead.",
            )
        doc = data.get("document")
        if not isinstance(doc, dict):
            raise AetherWorkspaceError("bad_request", "Part document required.")
        updated = {
            **part,
            "name": doc.get("name", part["name"]),
            "feature_document": {**copy.deepcopy(doc), "documentId": part["id"]},
        }
        workspace.part_definitions[part["id"]] = workspace._build_part_definition(
            updated, assign=False
        )
    elif action == "add_assembly":
        key = workspace._new_id("assembly")
        workspace.assemblies[key] = {
            "id": key,
            "name": name.strip(),
            "description": None,
        }
    else:
        raise AetherWorkspaceError("bad_request", "Unknown project operation.")
    workspace.revision_number += 1
    return workspace
