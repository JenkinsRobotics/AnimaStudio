"""Portable CAD document metadata. Geometry remains in the authored feature graph."""

import copy
import json
import math
from pathlib import Path
from .aether_workspace import AetherWorkspace

UNITS = json.loads(
    (Path(__file__).resolve().parents[1] / "core/assets/cad/units.json").read_text()
)


def text(value, limit=10000, required=False):
    if (
        not isinstance(value, str)
        or len(value) > limit
        or (required and not value.strip())
    ):
        raise ValueError(f"Use {'1–' if required else '0–'}{limit} characters.")
    return value.strip() if required else value


def defaults():
    return {
        "description": "",
        "revisionManaged": True,
        "workspaceName": "Main",
        "workspaceDescription": "",
        "units": {k: {"unit": v["default"], "decimals": 3} for k, v in UNITS.items()},
    }


class CADDocument:
    def __init__(self, content):
        self.workspace = None
        if content.startswith(b"PK"):
            self.workspace = AetherWorkspace.from_bytes(content)
            self.part = None
            raw = self.workspace.document_settings
        else:
            self.part = json.loads(content)
            if not isinstance(self.part, dict) or self.part.get("format") not in (
                "aether-part",
                "open-cad-part",
            ):
                raise ValueError("These settings require a native Aether CAD document.")
            raw = self.part.get("document_settings", {})
        if not isinstance(raw, dict):
            raise ValueError("Invalid document settings.")
        self.settings = {**defaults(), **copy.deepcopy(raw)}
        self.settings["units"] = {
            **defaults()["units"],
            **self.settings.get("units", {}),
        }

    def bytes(self):
        if self.workspace:
            self.workspace.document_settings = self.settings
            return self.workspace.to_bytes()[0]
        self.part["document_settings"] = self.settings
        return json.dumps(self.part, ensure_ascii=False, allow_nan=False).encode()

    def items(self):
        result = [
            {
                "id": "workspace",
                "kind": "workspace",
                "name": self.settings["workspaceName"],
                "description": self.settings["workspaceDescription"],
                "category": "Workspace",
            }
        ]
        if self.workspace:
            for kind, mapping in [
                ("part", self.workspace.part_definitions),
                ("assembly", self.workspace.assemblies),
            ]:
                for key, item in mapping.items():
                    result.append(
                        {
                            "id": key,
                            "kind": kind,
                            "name": item["name"],
                            "description": item.get("description") or "",
                            "category": next(
                                (
                                    p["value"]
                                    for p in item.get("custom_properties", [])
                                    if p["key"] == "category"
                                ),
                                kind.title(),
                            ),
                            "readOnly": item.get("source", {}).get("kind") == "linked",
                        }
                    )
                    if kind == "part" and item.get("feature_document"):
                        result.extend(
                            [
                                {
                                    **body,
                                    "readOnly": item.get("source", {}).get("kind")
                                    == "linked",
                                }
                                for body in self.bodies(item["feature_document"], key)
                            ]
                        )
        else:
            result.append(
                {
                    "id": "part",
                    "kind": "part",
                    "name": self.part["name"],
                    "description": self.part.get("description", ""),
                    "category": self.part.get("category", "Part"),
                }
            )
            result.extend(self.bodies(self.part, "part"))
        return result

    @staticmethod
    def bodies(doc, parent):
        result = []
        first = True
        for feature in doc.get("features", []):
            if (
                feature.get("type") not in ("revolve", "extrude")
                or feature.get("operation") != "new"
            ):
                continue
            key = (
                feature.get("bodyId")
                or f"{doc['documentId']}:body-{'1' if first else feature['id']}"
            )
            first = False
            props = doc.get("bodyProperties", {}).get(key, {})
            result.append(
                {
                    "id": f"{parent}/body/{key}",
                    "kind": "body",
                    "name": props.get("name", f"Body {len(result) + 1}"),
                    "description": props.get("description", ""),
                    "category": props.get("category", "Body"),
                }
            )
        return result

    def upgrade_documents(self):
        docs = (
            {"part": self.part}
            if self.part
            else {
                key: p.get("feature_document")
                for key, p in self.workspace.part_definitions.items()
                if p.get("source", {}).get("kind") != "linked"
            }
        )
        return {
            key: doc
            for key, doc in docs.items()
            if doc
            and (
                doc.get("formatVersion", 1) < 3 or doc.get("format") == "open-cad-part"
            )
        }

    def projection(self):
        settings = copy.deepcopy(self.settings)
        if self.workspace:
            for key, part in self.workspace.part_definitions.items():
                if part.get("mass_kg") is not None:
                    settings.setdefault("itemQuantities", {}).setdefault(key, {})[
                        "mass"
                    ] = part["mass_kg"]
        return {
            "settings": settings,
            "items": self.items(),
            "unitCatalog": UNITS,
            "featureVersion": 3,
            "upgradeNeeded": bool(self.upgrade_documents()),
            "upgradeDocuments": self.upgrade_documents(),
            "deleted": [
                {"id": k, "name": v["value"]["name"], "kind": v["kind"]}
                for k, v in self.settings.get("deletedItems", {}).items()
            ],
        }

    def edit(self, operation, data):
        if operation == "details":
            self.settings["description"] = text(data.get("description", ""))
            if not isinstance(data.get("revisionManaged"), bool):
                raise ValueError("Choose whether named revision management is enabled.")
            self.settings["revisionManaged"] = data["revisionManaged"]
        elif operation == "units":
            values = data.get("units")
            if not isinstance(values, dict) or set(values) != set(UNITS):
                raise ValueError("Supply each unit family.")
            for key, value in values.items():
                if (
                    not isinstance(value, dict)
                    or value.get("unit") not in UNITS[key]["options"]
                    or type(value.get("decimals")) is not int
                    or not 0 <= value["decimals"] <= 8
                ):
                    raise ValueError(f"Choose a valid {key} unit and 0–8 decimals.")
            self.settings["units"] = copy.deepcopy(values)
        elif operation == "rename":
            name = text(data.get("name"), 180, True)
            if self.workspace:
                self.workspace.name = name
            else:
                self.part["name"] = name
        elif operation == "properties":
            self.properties(data)
        elif operation in ("delete_item", "restore_item"):
            self.recycle(operation, data)
        elif operation == "upgrade":
            supplied = data.get("upgraded_documents", {})
            if not isinstance(supplied, dict):
                raise ValueError("Supply Core-migrated feature documents.")
            for key, old in self.upgrade_documents().items():
                updated = supplied.get(key)
                if (
                    not isinstance(updated, dict)
                    or updated.get("format") != "aether-part"
                    or updated.get("formatVersion") != 3
                    or updated.get("documentId") != old.get("documentId")
                    or not isinstance(updated.get("features"), list)
                ):
                    raise ValueError(
                        "Run the Aether Core feature migration before updating this workspace."
                    )
                old.clear()
                old.update(copy.deepcopy(updated))
        else:
            raise ValueError("Unknown CAD settings operation.")

    def properties(self, data):
        key = data.get("item_id")
        name = text(data.get("name"), 180, True)
        description = text(data.get("description", ""))
        category = text(data.get("category", ""), 120)
        quantities = data.get("quantities", {})
        if not isinstance(quantities, dict) or any(
            k not in UNITS
            or isinstance(v, bool)
            or not isinstance(v, (int, float))
            or not math.isfinite(v)
            for k, v in quantities.items()
        ):
            raise ValueError(
                "Engineering properties require finite quantities in supported families."
            )
        self.settings.setdefault("itemQuantities", {})[key] = copy.deepcopy(quantities)

        if key == "workspace":
            self.settings.update(workspaceName=name, workspaceDescription=description)
            return
        body = "/body/" in str(key)
        parent, _, body_id = str(key).partition("/body/")
        if self.workspace:
            target = self.workspace.part_definitions.get(
                parent
            ) or self.workspace.assemblies.get(parent)
            if not target:
                raise ValueError("Item not found.")
            if target.get("source", {}).get("kind") == "linked":
                raise ValueError("Edit linked Part properties in its source document.")
            if not body and parent in self.workspace.part_definitions:
                mass = quantities.get("mass")
                if mass is not None and mass < 0:
                    raise ValueError("Mass must be non-negative.")
                target["mass_kg"] = mass
                self.settings["itemQuantities"][key].pop("mass", None)
            doc = target.get("feature_document")
        else:
            if parent != "part":
                raise ValueError("Item not found.")
            target = doc = self.part
        if body:
            if not doc or not any(i["id"] == key for i in self.bodies(doc, parent)):
                raise ValueError("Body not found.")
            previous = doc.setdefault("bodyProperties", {}).get(
                body_id, {"visible": True}
            )
            doc["bodyProperties"][body_id] = {
                **previous,
                "name": name,
                "description": description,
                "category": category,
            }
        else:
            target.update(name=name, description=description)
            if self.workspace:
                # Assemblies have a canonical description; category is fixed by their type.
                if parent in self.workspace.part_definitions:
                    target["custom_properties"] = [
                        p
                        for p in target.get("custom_properties", [])
                        if p["key"] != "category"
                    ] + [{"key": "category", "value": category}]
                if doc:
                    doc["name"] = name
            else:
                target["category"] = category

    def recycle(self, operation, data):
        if not self.workspace:
            raise ValueError(
                "Deleted workspaces are Part/Assembly tabs inside a project document."
            )
        key = data.get("item_id")
        trash = self.settings.setdefault("deletedItems", {})
        if operation == "restore_item":
            if key not in trash:
                raise ValueError("Deleted item not found.")
            item = trash[key]
            mapping = (
                self.workspace.part_definitions
                if item["kind"] == "part"
                else self.workspace.assemblies
            )
            if key in mapping:
                raise ValueError("An item already uses this identity.")
            mapping[key] = copy.deepcopy(item["value"])
            del trash[key]
            return
        kind = "part" if key in self.workspace.part_definitions else "assembly"
        mapping = (
            self.workspace.part_definitions
            if kind == "part"
            else self.workspace.assemblies
        )
        if key not in mapping:
            raise ValueError("Item not found.")
        if len(mapping) == 1 and kind == "assembly":
            raise ValueError("Keep at least one Assembly in the project.")
        if any(
            i["definition_id"] == key or i["parent_assembly_id"] == key
            for i in self.workspace.instances.values()
        ):
            raise ValueError(
                "Remove dependent Assembly instances before deleting this workspace."
            )
        if any(
            c["part_definition_id"] == key
            for c in self.workspace.connector_definitions.values()
        ):
            raise ValueError(
                "Remove dependent connectors before deleting this workspace."
            )
        trash[key] = {"kind": kind, "value": mapping.pop(key)}
