"""Canonical Aether CAD Assembly workspace state and persistence.

This module owns the first persistent ``.aether`` semantic vertical slice:
Part definitions, Assembly instances, Part-owned connector definitions,
kinematic mates/DOF, relations, deterministic tree solving, and derived BOM
projections.  It contains no renderer or HTTP concerns; ``animacore.bridge``
is only a transport adapter around these values.

The disposable read DTOs and command envelopes are frozen in
``dev/docs/roadmap/Aether_CAD_Assembly_Projection.md``.  The ZIP container is
defined in ``dev/docs/roadmap/Aether_Workspace_Format.md``.
"""

from __future__ import annotations

import copy
import hashlib
import io
import json
import math
import os
import tempfile
import zipfile
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Any, Iterable

from animacore.mates import DofKind, JOINT_TYPE_DOF_TEMPLATES, JointType
from animacore.rig import RELATION_KIND_DOF_KINDS, RelationKind

FORMAT_NAME = "aether-workspace"
FORMAT_VERSION = 1
GRAPH_SCHEMA_VERSION = 1
PROJECTION_SCHEMA_VERSION = 1
_ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
_EPSILON = 1e-12

Transform = dict[str, list[float]]


class AetherWorkspaceError(Exception):
    """A stable bridge-facing workspace error."""

    def __init__(self, code: str, message: str, path: str | None = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.path = path


def _identity_transform() -> Transform:
    return {
        "position_m": [0.0, 0.0, 0.0],
        "rotation_quaternion_xyzw": [0.0, 0.0, 0.0, 1.0],
    }


def _number(value: object, path: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise AetherWorkspaceError("bad_request", "expected a finite number", path)
    result = float(value)
    if not math.isfinite(result):
        raise AetherWorkspaceError("bad_request", "expected a finite number", path)
    return result


def _optional_number(value: object, path: str) -> float | None:
    return None if value is None else _number(value, path)


def _string(value: object, path: str, *, nonempty: bool = True) -> str:
    if not isinstance(value, str) or (nonempty and not value):
        detail = "a non-empty string" if nonempty else "a string"
        raise AetherWorkspaceError("bad_request", f"expected {detail}", path)
    return value


def _boolean(value: object, path: str) -> bool:
    if not isinstance(value, bool):
        raise AetherWorkspaceError("bad_request", "expected a boolean", path)
    return value


def _field_boolean(value: dict[str, Any], key: str, default: bool, path: str) -> bool:
    return default if key not in value else _boolean(value[key], f"{path}.{key}")


def _vec(value: object, size: int, path: str) -> list[float]:
    if not isinstance(value, (list, tuple)) or len(value) != size:
        raise AetherWorkspaceError(
            "bad_request", f"expected an array of {size} finite numbers", path
        )
    return [_number(component, f"{path}[{index}]") for index, component in enumerate(value)]


def _normalize(vector: Iterable[float], path: str) -> list[float]:
    result = [float(component) for component in vector]
    length = math.sqrt(sum(component * component for component in result))
    if length <= _EPSILON:
        raise AetherWorkspaceError("validation_error", "axis must not be zero", path)
    return [component / length for component in result]


def _dot(left: Iterable[float], right: Iterable[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def _cross(left: list[float], right: list[float]) -> list[float]:
    return [
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    ]


def _normalized_connector_frame(value: object, path: str) -> dict[str, list[float]]:
    if not isinstance(value, dict):
        raise AetherWorkspaceError("bad_request", "expected an object", path)
    origin = _vec(value.get("origin_m", [0.0, 0.0, 0.0]), 3, f"{path}.origin_m")
    primary = _normalize(
        _vec(value.get("primary_axis_xyz", [0.0, 0.0, 1.0]), 3,
             f"{path}.primary_axis_xyz"),
        f"{path}.primary_axis_xyz",
    )
    secondary_input = _vec(
        value.get("secondary_axis_xyz", [1.0, 0.0, 0.0]),
        3,
        f"{path}.secondary_axis_xyz",
    )
    # Gram-Schmidt gives one deterministic orthonormal right-handed frame.
    secondary = [
        component - _dot(secondary_input, primary) * axis
        for component, axis in zip(secondary_input, primary)
    ]
    secondary = _normalize(secondary, f"{path}.secondary_axis_xyz")
    if math.sqrt(sum(component * component for component in _cross(primary, secondary))) <= _EPSILON:
        raise AetherWorkspaceError(
            "validation_error", "connector axes must not be parallel", path
        )
    return {
        "origin_m": origin,
        "primary_axis_xyz": primary,
        "secondary_axis_xyz": secondary,
    }


def _normalized_quaternion(value: object, path: str) -> list[float]:
    quaternion = _vec(value, 4, path)
    result = _normalize(quaternion, path)
    # q and -q describe the same orientation. Pick one canonical sign.
    for component in reversed(result):
        if abs(component) > _EPSILON:
            if component < 0:
                result = [-entry for entry in result]
            break
    return result


def _normalized_transform(value: object, path: str) -> Transform:
    if value is None:
        return _identity_transform()
    if not isinstance(value, dict):
        raise AetherWorkspaceError("bad_request", "expected an object", path)
    return {
        "position_m": _vec(value.get("position_m", [0.0, 0.0, 0.0]), 3,
                           f"{path}.position_m"),
        "rotation_quaternion_xyzw": _normalized_quaternion(
            value.get("rotation_quaternion_xyzw", [0.0, 0.0, 0.0, 1.0]),
            f"{path}.rotation_quaternion_xyzw",
        ),
    }


def _quaternion_multiply(left: list[float], right: list[float]) -> list[float]:
    lx, ly, lz, lw = left
    rx, ry, rz, rw = right
    return _normalized_quaternion(
        [
            lw * rx + lx * rw + ly * rz - lz * ry,
            lw * ry - lx * rz + ly * rw + lz * rx,
            lw * rz + lx * ry - ly * rx + lz * rw,
            lw * rw - lx * rx - ly * ry - lz * rz,
        ],
        "quaternion",
    )


def _quaternion_conjugate(value: list[float]) -> list[float]:
    return [-value[0], -value[1], -value[2], value[3]]


def _rotate_vector(quaternion: list[float], vector: list[float]) -> list[float]:
    x, y, z, w = quaternion
    vx, vy, vz = vector
    tx = 2.0 * (y * vz - z * vy)
    ty = 2.0 * (z * vx - x * vz)
    tz = 2.0 * (x * vy - y * vx)
    return [
        vx + w * tx + (y * tz - z * ty),
        vy + w * ty + (z * tx - x * tz),
        vz + w * tz + (x * ty - y * tx),
    ]


def _compose(left: Transform, right: Transform) -> Transform:
    rotated = _rotate_vector(left["rotation_quaternion_xyzw"], right["position_m"])
    return {
        "position_m": [a + b for a, b in zip(left["position_m"], rotated)],
        "rotation_quaternion_xyzw": _quaternion_multiply(
            left["rotation_quaternion_xyzw"], right["rotation_quaternion_xyzw"]
        ),
    }


def _inverse(value: Transform) -> Transform:
    rotation = _quaternion_conjugate(value["rotation_quaternion_xyzw"])
    position = _rotate_vector(rotation, [-entry for entry in value["position_m"]])
    return {"position_m": position, "rotation_quaternion_xyzw": rotation}


def _quaternion_from_basis(primary_z: list[float], secondary_x: list[float]) -> list[float]:
    x_axis = secondary_x
    z_axis = primary_z
    y_axis = _normalize(_cross(z_axis, x_axis), "connector.frame")
    # Columns are the local X, Y, Z axes.
    m00, m10, m20 = x_axis
    m01, m11, m21 = y_axis
    m02, m12, m22 = z_axis
    trace = m00 + m11 + m22
    if trace > 0.0:
        scale = math.sqrt(trace + 1.0) * 2.0
        result = [(m21 - m12) / scale, (m02 - m20) / scale,
                  (m10 - m01) / scale, 0.25 * scale]
    elif m00 > m11 and m00 > m22:
        scale = math.sqrt(1.0 + m00 - m11 - m22) * 2.0
        result = [0.25 * scale, (m01 + m10) / scale,
                  (m02 + m20) / scale, (m21 - m12) / scale]
    elif m11 > m22:
        scale = math.sqrt(1.0 + m11 - m00 - m22) * 2.0
        result = [(m01 + m10) / scale, 0.25 * scale,
                  (m12 + m21) / scale, (m02 - m20) / scale]
    else:
        scale = math.sqrt(1.0 + m22 - m00 - m11) * 2.0
        result = [(m02 + m20) / scale, (m12 + m21) / scale,
                  0.25 * scale, (m10 - m01) / scale]
    return _normalized_quaternion(result, "connector.frame.rotation")


def _frame_transform(frame: dict[str, list[float]]) -> Transform:
    return {
        "position_m": list(frame["origin_m"]),
        "rotation_quaternion_xyzw": _quaternion_from_basis(
            frame["primary_axis_xyz"], frame["secondary_axis_xyz"]
        ),
    }


def _axis_rotation(axis: str, angle_rad: float) -> Transform:
    vector = {"x": [1.0, 0.0, 0.0], "y": [0.0, 1.0, 0.0], "z": [0.0, 0.0, 1.0]}[axis]
    half = angle_rad / 2.0
    sine = math.sin(half)
    return {
        "position_m": [0.0, 0.0, 0.0],
        "rotation_quaternion_xyzw": [
            vector[0] * sine, vector[1] * sine, vector[2] * sine, math.cos(half)
        ],
    }


def _axis_translation(axis: str, distance_m: float) -> Transform:
    vector = {"x": [1.0, 0.0, 0.0], "y": [0.0, 1.0, 0.0], "z": [0.0, 0.0, 1.0]}[axis]
    return {
        "position_m": [component * distance_m for component in vector],
        "rotation_quaternion_xyzw": [0.0, 0.0, 0.0, 1.0],
    }


def _canonical_json(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"),
                       ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")


def _safe_zip_names(names: Iterable[str]) -> None:
    seen: set[str] = set()
    for name in names:
        path = PurePosixPath(name)
        if name in seen or path.is_absolute() or ".." in path.parts or "" in path.parts:
            raise AetherWorkspaceError(
                "format_error", f"unsafe or duplicate ZIP entry {name!r}", name
            )
        seen.add(name)


def _write_zip_entry(archive: zipfile.ZipFile, name: str, data: bytes) -> None:
    info = zipfile.ZipInfo(name, date_time=_ZIP_TIMESTAMP)
    info.compress_type = zipfile.ZIP_STORED
    info.external_attr = 0o100644 << 16
    archive.writestr(info, data)


@dataclass
class AetherWorkspace:
    workspace_id: str
    name: str
    revision_number: int = 1
    id_counter: int = 0
    document_settings: dict[str, Any] = field(default_factory=dict)
    part_definitions: dict[str, dict[str, Any]] = field(default_factory=dict)
    assemblies: dict[str, dict[str, Any]] = field(default_factory=dict)
    instances: dict[str, dict[str, Any]] = field(default_factory=dict)
    connector_definitions: dict[str, dict[str, Any]] = field(default_factory=dict)
    mates: dict[str, dict[str, Any]] = field(default_factory=dict)
    relations: dict[str, dict[str, Any]] = field(default_factory=dict)
    configurations: dict[str, dict[str, Any]] = field(default_factory=dict)
    issues: list[dict[str, Any]] = field(default_factory=list)

    @classmethod
    def new(cls, ordinal: int, name: str = "Untitled Workspace") -> "AetherWorkspace":
        workspace = cls(workspace_id=f"workspace-{ordinal:04d}", name=name)
        assembly_id = workspace._new_id("assembly")
        workspace.assemblies[assembly_id] = {
            "id": assembly_id,
            "name": "Main Assembly",
            "description": None,
        }
        configuration_id = workspace._new_id("configuration")
        workspace.configurations[configuration_id] = {
            "id": configuration_id,
            "name": "Default",
            "active": True,
            "suppressed_instance_ids": [],
            "overridden_dof_ids": [],
        }
        return workspace

    @property
    def revision(self) -> str:
        return str(self.revision_number)

    @property
    def root_assembly_id(self) -> str:
        if not self.assemblies:
            raise AetherWorkspaceError("format_error", "workspace has no Assembly")
        return sorted(self.assemblies)[0]

    def _new_id(self, kind: str) -> str:
        self.id_counter += 1
        return f"{kind}-{self.id_counter:06d}"

    def clone(self) -> "AetherWorkspace":
        return copy.deepcopy(self)

    def graph(self) -> dict[str, Any]:
        return {
            "schema_version": GRAPH_SCHEMA_VERSION,
            "document_settings": copy.deepcopy(self.document_settings),
            "workspace_id": self.workspace_id,
            "name": self.name,
            "revision": self.revision,
            "id_counter": self.id_counter,
            "part_definitions": self._ordered(self.part_definitions),
            "assemblies": self._ordered(self.assemblies),
            "instances": self._ordered(self.instances),
            "connector_definitions": self._ordered(self.connector_definitions),
            "mates": self._ordered(self.mates),
            "relations": self._ordered(self.relations),
            "configurations": self._ordered(self.configurations),
        }

    @staticmethod
    def _ordered(mapping: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
        return [copy.deepcopy(mapping[key]) for key in sorted(mapping)]

    def semantic_hash(self) -> str:
        return hashlib.sha256(_canonical_json(self.graph())).hexdigest()

    def describe_workspace(self, handle: str) -> dict[str, Any]:
        return {
            "schema_version": 1,
            "handle": handle,
            "workspace_id": self.workspace_id,
            "name": self.name,
            "revision": self.revision,
            "graph_sha256": self.semantic_hash(),
            "root_assembly_id": self.root_assembly_id,
            "assembly_ids": sorted(self.assemblies),
        }

    def _require_assembly(self, assembly_id: str) -> dict[str, Any]:
        assembly = self.assemblies.get(assembly_id)
        if assembly is None:
            raise AetherWorkspaceError(
                "unknown_entity", f"no Assembly {assembly_id!r}", "assembly_id"
            )
        return assembly

    def _diagnostic(self, code: str, message: str, entity_ids: list[str],
                    *, severity: str = "error", field_path: str | None = None,
                    recoverable: bool = True) -> dict[str, Any]:
        digest = hashlib.sha256(
            _canonical_json([code, message, sorted(entity_ids), field_path])
        ).hexdigest()[:16]
        return {
            "id": f"diagnostic-{digest}",
            "severity": severity,
            "code": code,
            "message": message,
            "entity_ids": sorted(entity_ids),
            "field_path": field_path,
            "recoverable": recoverable,
        }

    def projection(self, assembly_id: str) -> dict[str, Any]:
        assembly = self._require_assembly(assembly_id)
        solution = self.solve(assembly_id)
        solved = {
            item["instance_id"]: item["transform"]
            for item in solution["instance_world_transforms"]
        }
        instances = []
        for item in self._assembly_instances(assembly_id):
            definition = self.part_definitions.get(item["definition_id"])
            source_status = (
                definition["source"]["status"] if definition is not None else "missing"
            )
            entry = copy.deepcopy(item)
            entry["solved_world_transform"] = copy.deepcopy(
                solved.get(item["id"], item["rest_transform"])
            )
            entry["source_status"] = source_status
            instances.append(entry)
        root_ids = sorted(
            item["id"] for item in instances if item["parent_instance_id"] is None
        )
        assembly_entries = []
        for item in self._ordered(self.assemblies):
            entry = copy.deepcopy(item)
            entry["root_instance_ids"] = (
                root_ids if item["id"] == assembly_id else sorted(
                    instance["id"] for instance in self.instances.values()
                    if instance["parent_assembly_id"] == item["id"]
                    and instance["parent_instance_id"] is None
                )
            )
            assembly_entries.append(entry)
        issues = self._current_issues(assembly_id, solution)
        return {
            "schema_version": PROJECTION_SCHEMA_VERSION,
            "workspace_id": self.workspace_id,
            "revision": self.revision,
            "assembly_id": assembly["id"],
            "capabilities": {
                "can_edit_instances": True,
                "can_edit_connectors": True,
                "supported_mate_type_ids": [
                    JointType.FASTENED.value,
                    JointType.REVOLUTE.value,
                    JointType.PRISMATIC.value,
                ],
                "can_edit_relations": True,
                "can_solve_tree": True,
                "can_solve_loops": False,
                "can_edit_nested_assemblies": False,
                "can_project_bom": True,
                "can_save_workspace": True,
                "unavailable_reasons": [
                    {
                        "capability_id": "can_solve_loops",
                        "reason": "Assembly v1 solves deterministic mate trees only.",
                    },
                    {
                        "capability_id": "can_edit_nested_assemblies",
                        "reason": "Nested Assembly editing is not in the v1 producer.",
                    },
                ],
            },
            "assemblies": assembly_entries,
            "part_definitions": self._ordered(self.part_definitions),
            "instances": instances,
            "connector_definitions": self._ordered(self.connector_definitions),
            "mates": [
                self._mate_projection(item, solution)
                for item in self._ordered(self.mates)
            ],
            "relations": self._ordered(self.relations),
            "configurations": self._ordered(self.configurations),
            "issues": issues,
        }

    def _assembly_instances(self, assembly_id: str) -> list[dict[str, Any]]:
        return [
            copy.deepcopy(self.instances[key])
            for key in sorted(self.instances)
            if self.instances[key]["parent_assembly_id"] == assembly_id
        ]

    def _configuration_suppressed_instance_ids(self) -> set[str]:
        return {
            instance_id
            for configuration in self.configurations.values()
            if configuration["active"]
            for instance_id in configuration["suppressed_instance_ids"]
        }

    def _mate_projection(
        self, mate: dict[str, Any], solution: dict[str, Any]
    ) -> dict[str, Any]:
        result = copy.deepcopy(mate)
        effective_suppression = mate["suppressed"] or any(
            endpoint["instance_id"] in self._configuration_suppressed_instance_ids()
            or self.instances[endpoint["instance_id"]]["suppressed"]
            for endpoint in (mate["endpoint_a"], mate["endpoint_b"])
        )
        result["dofs"] = [
            self._dof_projection(dof, mate, effective_suppression)
            for dof in mate["dofs"]
        ]
        violation_ids = {
            item["dof_id"] for item in solution["limit_violations"]
        }
        mate_violation_ids = [
            self._diagnostic(
                "limit_violation",
                f"DOF {dof['id']} is outside its authored limits.",
                [dof["id"]],
                field_path="dof.value",
            )["id"]
            for dof in mate["dofs"]
            if dof["id"] in violation_ids
        ]
        result["solve_state"] = (
            "suppressed" if effective_suppression
            else "warning" if mate_violation_ids
            else "satisfied"
        )
        result["diagnostic_ids"] = sorted(mate_violation_ids)
        return result

    def _dof_projection(
        self, dof: dict[str, Any], mate: dict[str, Any],
        effective_suppression: bool = False,
    ) -> dict[str, Any]:
        result = copy.deepcopy(dof)
        driven_ids = {
            relation["driven_dof_id"] for relation in self.relations.values()
            if not relation["suppressed"]
        }
        if mate["suppressed"] or effective_suppression:
            result["state"] = "suppressed"
        elif dof["id"] in driven_ids:
            result["state"] = "dependent"
        else:
            result["state"] = "free"
        return result

    def _current_issues(self, assembly_id: str,
                        solution: dict[str, Any]) -> list[dict[str, Any]]:
        relevant = [copy.deepcopy(issue) for issue in self.issues]
        relevant_ids = set(solution["diagnostic_ids"])
        relevant.extend(
            self._diagnostic(
                "limit_violation",
                f"DOF {violation['dof_id']} is outside its authored limits.",
                [violation["dof_id"]],
                field_path="dof.value",
            )
            for violation in solution["limit_violations"]
            if self._diagnostic(
                "limit_violation",
                f"DOF {violation['dof_id']} is outside its authored limits.",
                [violation["dof_id"]],
                field_path="dof.value",
            )["id"] not in relevant_ids
        )
        return sorted(relevant, key=lambda item: item["id"])

    def solve(self, assembly_id: str, *, candidate_mate: dict[str, Any] | None = None,
              revision: str | None = None) -> dict[str, Any]:
        self._require_assembly(assembly_id)
        mates = [copy.deepcopy(self.mates[key]) for key in sorted(self.mates)]
        if candidate_mate is not None:
            mates.append(copy.deepcopy(candidate_mate))
            mates.sort(key=lambda item: item["id"])
        configuration_suppressed = self._configuration_suppressed_instance_ids()
        active_instances = {
            item["id"]: item for item in self._assembly_instances(assembly_id)
            if not item["suppressed"] and item["id"] not in configuration_suppressed
        }
        effective_mates = [
            mate for mate in mates
            if not mate["suppressed"]
            and mate["endpoint_a"]["instance_id"] in active_instances
            and mate["endpoint_b"]["instance_id"] in active_instances
        ]
        dof_values = self._resolved_dof_values(effective_mates)
        transforms: dict[str, Transform] = {}
        incoming = {
            mate["endpoint_b"]["instance_id"]
            for mate in effective_mates
        }
        for instance_id, item in active_instances.items():
            if item["grounded"] or instance_id not in incoming:
                transforms[instance_id] = copy.deepcopy(item["rest_transform"])
        pending = list(effective_mates)
        for _ in range(len(pending) + 1):
            remaining = []
            progressed = False
            for mate in pending:
                endpoint_a = mate["endpoint_a"]["instance_id"]
                endpoint_b = mate["endpoint_b"]["instance_id"]
                if endpoint_a not in active_instances or endpoint_b not in active_instances:
                    continue
                if active_instances[endpoint_b]["grounded"]:
                    continue
                if endpoint_a not in transforms:
                    remaining.append(mate)
                    continue
                transforms[endpoint_b] = self._solve_child_transform(
                    transforms[endpoint_a], mate, dof_values
                )
                progressed = True
            pending = remaining
            if not progressed:
                break
        for instance_id, item in active_instances.items():
            transforms.setdefault(instance_id, copy.deepcopy(item["rest_transform"]))

        violations = self._limit_violations(effective_mates, dof_values)
        diagnostics = [
            self._diagnostic(
                "limit_violation",
                f"DOF {violation['dof_id']} is outside its authored limits.",
                [violation["dof_id"]],
                field_path="dof.value",
            )
            for violation in violations
        ]
        unconverged = bool(pending)
        if unconverged:
            diagnostics.append(
                self._diagnostic(
                    "solve_unconverged",
                    "The Assembly mate graph could not be resolved as a tree.",
                    [mate["id"] for mate in pending],
                    severity="warning",
                )
            )
        free_count = sum(
            1 for mate in effective_mates for dof in mate["dofs"]
            if not any(
                relation["driven_dof_id"] == dof["id"] and not relation["suppressed"]
                for relation in self.relations.values()
            )
        )
        free_count += 6 * sum(
            1 for instance_id, item in active_instances.items()
            if not item["grounded"] and instance_id not in incoming
        )
        return {
            "status": "unconverged" if unconverged else "solved",
            "revision": revision or self.revision,
            "instance_world_transforms": [
                {"instance_id": key, "transform": transforms[key]}
                for key in sorted(transforms)
            ],
            "dof_values": [
                {
                    "dof_id": dof_id,
                    "value_rad": value if kind == DofKind.ROTATION.value else None,
                    "value_m": value if kind == DofKind.TRANSLATION.value else None,
                }
                for dof_id, (kind, value) in sorted(dof_values.items())
            ],
            "remaining_free_dof_count": free_count,
            "residual": None if unconverged else 0.0,
            "iterations": len(effective_mates) if effective_mates else 0,
            "limit_violations": violations,
            "diagnostic_ids": sorted(item["id"] for item in diagnostics),
        }

    def _resolved_dof_values(self, mates: list[dict[str, Any]]) -> dict[str, tuple[str, float]]:
        values: dict[str, tuple[str, float]] = {}
        for mate in mates:
            if mate["suppressed"]:
                continue
            for dof in mate["dofs"]:
                kind = dof["kind"]
                value = dof["value_rad"] if kind == DofKind.ROTATION.value else dof["value_m"]
                values[dof["id"]] = (kind, float(value))
        pending = [relation for relation in self._ordered(self.relations)
                   if not relation["suppressed"]]
        for _ in range(len(pending) + 1):
            remaining = []
            progressed = False
            for relation in pending:
                driver = values.get(relation["driver_dof_id"])
                driven = values.get(relation["driven_dof_id"])
                if driver is None or driven is None:
                    remaining.append(relation)
                    continue
                offset = relation["offset_rad"] if driven[0] == DofKind.ROTATION.value else relation["offset_m"]
                values[relation["driven_dof_id"]] = (
                    driven[0], relation["ratio"] * driver[1] + float(offset or 0.0)
                )
                progressed = True
            pending = remaining
            if not progressed:
                break
        return values

    def _solve_child_transform(self, parent_world: Transform, mate: dict[str, Any],
                               values: dict[str, tuple[str, float]]) -> Transform:
        connector_a = self.connector_definitions[
            mate["endpoint_a"]["connector_definition_id"]
        ]
        connector_b = self.connector_definitions[
            mate["endpoint_b"]["connector_definition_id"]
        ]
        relative = _identity_transform()
        template = JOINT_TYPE_DOF_TEMPLATES[JointType(mate["type_id"])]
        for dof, (_, kind, axis) in zip(mate["dofs"], template):
            value = values[dof["id"]][1]
            motion = (
                _axis_rotation(axis, value)
                if kind is DofKind.ROTATION
                else _axis_translation(axis, value)
            )
            relative = _compose(relative, motion)
        return _compose(
            _compose(
                _compose(parent_world, _frame_transform(connector_a["frame_part_local"])),
                relative,
            ),
            _inverse(_frame_transform(connector_b["frame_part_local"])),
        )

    def _limit_violations(self, mates: list[dict[str, Any]],
                          values: dict[str, tuple[str, float]]) -> list[dict[str, Any]]:
        result = []
        for mate in mates:
            if mate["suppressed"]:
                continue
            for dof in mate["dofs"]:
                kind, value = values[dof["id"]]
                suffix = "rad" if kind == DofKind.ROTATION.value else "m"
                minimum = dof[f"limit_min_{suffix}"]
                maximum = dof[f"limit_max_{suffix}"]
                if minimum is None or maximum is None or minimum <= value <= maximum:
                    continue
                result.append({
                    "dof_id": dof["id"],
                    "value_rad": value if suffix == "rad" else None,
                    "value_m": value if suffix == "m" else None,
                    "limit_min_rad": minimum if suffix == "rad" else None,
                    "limit_max_rad": maximum if suffix == "rad" else None,
                    "limit_min_m": minimum if suffix == "m" else None,
                    "limit_max_m": maximum if suffix == "m" else None,
                })
        return sorted(result, key=lambda item: item["dof_id"])

    def bom(self, assembly_id: str, mode: str = "hierarchical") -> dict[str, Any]:
        self._require_assembly(assembly_id)
        if mode not in {"hierarchical", "flattened"}:
            raise AetherWorkspaceError(
                "bad_request", "mode must be 'hierarchical' or 'flattened'", "mode"
            )
        instances = [
            item for item in self._assembly_instances(assembly_id)
            if not item["suppressed"]
            and item["id"] not in self._configuration_suppressed_instance_ids()
            and item["definition_kind"] == "part"
        ]
        if mode == "flattened":
            grouped: dict[str, list[dict[str, Any]]] = {}
            for item in instances:
                grouped.setdefault(item["definition_id"], []).append(item)
            rows = [
                self._bom_row(
                    f"flat:{part_id}", None, part_id, len(grouped[part_id])
                )
                for part_id in sorted(grouped)
            ]
        else:
            rows = [
                self._bom_row(
                    f"instance:{item['id']}",
                    f"instance:{item['parent_instance_id']}"
                    if item["parent_instance_id"] in self.instances else None,
                    item["definition_id"],
                    1,
                )
                for item in instances
            ]
        masses = [row["extended_mass_kg"] for row in rows]
        total_mass = sum(masses) if all(value is not None for value in masses) else None
        return {
            "schema_version": PROJECTION_SCHEMA_VERSION,
            "assembly_id": assembly_id,
            "revision": self.revision,
            "mode": mode,
            "rows": rows,
            "total_mass_kg": total_mass,
            "diagnostic_ids": [],
        }

    def _bom_row(self, row_id: str, parent_row_id: str | None,
                 part_id: str, quantity: int) -> dict[str, Any]:
        part = self.part_definitions[part_id]
        mass = part["mass_kg"]
        return {
            "row_id": row_id,
            "parent_row_id": parent_row_id,
            "part_definition_id": part_id,
            "quantity": quantity,
            "part_number": part["part_number"],
            "name": part["name"],
            "description": part["description"],
            "material_name": None,
            "unit_mass_kg": mass,
            "extended_mass_kg": mass * quantity if mass is not None else None,
            "source_label": part["source"]["label"],
            "custom_properties": copy.deepcopy(part["custom_properties"]),
        }

    def preview_mate(self, assembly_id: str, value: object) -> dict[str, Any]:
        candidate = self._build_mate(value, assign=True, preview=True)
        self._validate_mate_tree(candidate)
        solution = self.solve(assembly_id, candidate_mate=candidate)
        return {
            "revision": self.revision,
            "solution": solution,
            "diagnostics": [
                issue for issue in self._current_issues(assembly_id, solution)
                if issue["id"] in solution["diagnostic_ids"]
            ],
        }

    def mutate(self, method: str, params: dict[str, Any],
               expected_revision: str, handle: str) -> dict[str, Any]:
        if expected_revision != self.revision:
            raise AetherWorkspaceError(
                "revision_conflict",
                f"expected revision {expected_revision!r}, current revision is {self.revision!r}",
                "expected_revision",
            )
        draft = self.clone()
        draft._apply(method, params)
        draft.revision_number += 1
        self.__dict__.update(draft.__dict__)
        assembly_id = _string(params.get("assembly_id", self.root_assembly_id), "assembly_id")
        return self.mutation_result(handle, assembly_id)

    def mutation_result(self, handle: str, assembly_id: str,
                        *, bom_mode: str = "hierarchical") -> dict[str, Any]:
        return {
            "handle": handle,
            "revision": self.revision,
            "assembly": self.projection(assembly_id),
            "solution": self.solve(assembly_id),
            "bom": self.bom(assembly_id, bom_mode),
        }

    def _apply(self, method: str, params: dict[str, Any]) -> None:
        handlers = {
            "add_part_definition": self._add_part_definition,
            "update_part_definition": self._update_part_definition,
            "remove_part_definition": self._remove_part_definition,
            "add_instance": self._add_instance,
            "update_instance": self._update_instance,
            "remove_instance": self._remove_instance,
            "move_instance": self._move_instance,
            "set_instance_grounded": self._set_instance_grounded,
            "set_instance_suppressed": self._set_instance_suppressed,
            "add_connector": self._add_connector,
            "update_connector": self._update_connector,
            "remove_connector": self._remove_connector,
            "add_mate": self._add_mate,
            "update_mate": self._update_mate,
            "remove_mate": self._remove_mate,
            "add_relation": self._add_relation,
            "update_relation": self._update_relation,
            "remove_relation": self._remove_relation,
            "set_dof_value": self._set_dof_value,
        }
        handler = handlers.get(method)
        if handler is None:
            raise AetherWorkspaceError("bad_request", f"unknown Assembly mutation {method!r}")
        handler(params)

    def _add_part_definition(self, params: dict[str, Any]) -> None:
        value = params.get("part_definition")
        part = self._build_part_definition(value, assign=True)
        self.part_definitions[part["id"]] = part

    def _update_part_definition(self, params: dict[str, Any]) -> None:
        value = params.get("part_definition")
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "part_definition")
        part_id = _string(value.get("id"), "part_definition.id")
        if part_id not in self.part_definitions:
            raise AetherWorkspaceError("unknown_entity", f"no Part definition {part_id!r}")
        part = self._build_part_definition(value, assign=False)
        self.part_definitions[part_id] = part

    def _remove_part_definition(self, params: dict[str, Any]) -> None:
        part_id = _string(params.get("part_definition_id"), "part_definition_id")
        if any(item["definition_id"] == part_id for item in self.instances.values()):
            raise AetherWorkspaceError(
                "dependency_conflict", "Part definition is still instanced", "part_definition_id"
            )
        if any(item["part_definition_id"] == part_id for item in self.connector_definitions.values()):
            raise AetherWorkspaceError(
                "dependency_conflict", "Part definition still owns connectors", "part_definition_id"
            )
        if self.part_definitions.pop(part_id, None) is None:
            raise AetherWorkspaceError("unknown_entity", f"no Part definition {part_id!r}")

    def _build_part_definition(self, value: object, *, assign: bool) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "part_definition")
        part_id = self._new_id("part") if assign else _string(value.get("id"), "part_definition.id")
        source = value.get("source", {})
        if not isinstance(source, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "part_definition.source")
        kind = source.get("kind", "authored")
        status = source.get("status", "resolved")
        if kind not in {"authored", "packed", "linked", "imported"}:
            raise AetherWorkspaceError("bad_request", "unsupported source kind", "part_definition.source.kind")
        if status not in {"resolved", "missing", "stale", "read_only"}:
            raise AetherWorkspaceError("bad_request", "unsupported source status", "part_definition.source.status")
        properties = value.get("custom_properties", [])
        if not isinstance(properties, list):
            raise AetherWorkspaceError("bad_request", "expected an array", "part_definition.custom_properties")
        normalized_properties = []
        for index, item in enumerate(properties):
            if not isinstance(item, dict):
                raise AetherWorkspaceError("bad_request", "expected an object", f"part_definition.custom_properties[{index}]")
            normalized_properties.append({
                "key": _string(item.get("key"), f"part_definition.custom_properties[{index}].key"),
                "value": _string(item.get("value"), f"part_definition.custom_properties[{index}].value", nonempty=False),
            })
        normalized_properties.sort(key=lambda item: (item["key"], item["value"]))
        name = _string(value.get("name"), "part_definition.name")
        mass_kg = _optional_number(value.get("mass_kg"), "part_definition.mass_kg")
        if mass_kg is not None and mass_kg < 0:
            raise AetherWorkspaceError(
                "validation_error", "mass_kg must be non-negative",
                "part_definition.mass_kg",
            )
        result = {
            "id": part_id,
            "name": name,
            "part_number": self._nullable_string(value.get("part_number"), "part_definition.part_number"),
            "description": self._nullable_string(value.get("description"), "part_definition.description"),
            "material_id": self._nullable_string(value.get("material_id"), "part_definition.material_id"),
            "mass_kg": mass_kg,
            "source": {
                "kind": kind,
                "label": _string(source.get("label", name), "part_definition.source.label"),
                "asset_ref": self._nullable_string(source.get("asset_ref"), "part_definition.source.asset_ref"),
                "status": status,
            },
            "custom_properties": normalized_properties,
        }

        if "feature_document" in value:
            document = value["feature_document"]
            if not isinstance(document, dict) or document.get("format") != "aether-part" or document.get("formatVersion") not in (2, 3) or document.get("documentId") != part_id or not isinstance(document.get("features"), list):
                raise AetherWorkspaceError("format_error", "invalid authored Part projection", "part_definition.feature_document")
            # Geometry validation/evaluation is owned by the canonical CAD Core kernel.
            # The project graph retains this projection once, under its Part definition.
            result["feature_document"] = copy.deepcopy(document)
        return result

    @staticmethod
    def _nullable_string(value: object, path: str) -> str | None:
        return None if value is None else _string(value, path, nonempty=False)

    def _add_instance(self, params: dict[str, Any]) -> None:
        instance = self._build_instance(params.get("instance"), assign=True)
        self.instances[instance["id"]] = instance

    def _update_instance(self, params: dict[str, Any]) -> None:
        value = params.get("instance")
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "instance")
        instance_id = _string(value.get("id"), "instance.id")
        if instance_id not in self.instances:
            raise AetherWorkspaceError("unknown_entity", f"no instance {instance_id!r}")
        self.instances[instance_id] = self._build_instance(value, assign=False)

    def _build_instance(self, value: object, *, assign: bool) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "instance")
        instance_id = self._new_id("instance") if assign else _string(value.get("id"), "instance.id")
        assembly_id = _string(value.get("parent_assembly_id", self.root_assembly_id), "instance.parent_assembly_id")
        self._require_assembly(assembly_id)
        definition_kind = value.get("definition_kind", "part")
        if definition_kind != "part":
            raise AetherWorkspaceError(
                "unsupported_capability", "Assembly v1 accepts Part instances only", "instance.definition_kind"
            )
        definition_id = _string(value.get("definition_id"), "instance.definition_id")
        if definition_id not in self.part_definitions:
            raise AetherWorkspaceError("unknown_entity", f"no Part definition {definition_id!r}", "instance.definition_id")
        parent_id = value.get("parent_instance_id")
        if parent_id is not None:
            parent_id = _string(parent_id, "instance.parent_instance_id")
            if parent_id not in self.instances or parent_id == instance_id:
                raise AetherWorkspaceError("unknown_entity", "invalid parent instance", "instance.parent_instance_id")
        return {
            "id": instance_id,
            "parent_assembly_id": assembly_id,
            "definition_kind": "part",
            "definition_id": definition_id,
            "name": _string(value.get("name"), "instance.name"),
            "parent_instance_id": parent_id,
            "rest_transform": _normalized_transform(value.get("rest_transform"), "instance.rest_transform"),
            "grounded": _field_boolean(value, "grounded", False, "instance"),
            "suppressed": _field_boolean(value, "suppressed", False, "instance"),
            "visible": _field_boolean(value, "visible", True, "instance"),
        }

    def _remove_instance(self, params: dict[str, Any]) -> None:
        instance_id = _string(params.get("instance_id"), "instance_id")
        if any(
            endpoint["instance_id"] == instance_id
            for mate in self.mates.values()
            for endpoint in (mate["endpoint_a"], mate["endpoint_b"])
        ):
            raise AetherWorkspaceError("dependency_conflict", "instance is still mated", "instance_id")
        if any(item["parent_instance_id"] == instance_id for item in self.instances.values()):
            raise AetherWorkspaceError("dependency_conflict", "instance still has children", "instance_id")
        if self.instances.pop(instance_id, None) is None:
            raise AetherWorkspaceError("unknown_entity", f"no instance {instance_id!r}")

    def _move_instance(self, params: dict[str, Any]) -> None:
        instance = self._instance(params)
        parent_id = params.get("parent_instance_id")
        if parent_id is not None:
            parent_id = _string(parent_id, "parent_instance_id")
            if parent_id not in self.instances or parent_id == instance["id"]:
                raise AetherWorkspaceError("unknown_entity", "invalid parent instance", "parent_instance_id")
        instance["parent_instance_id"] = parent_id

    def _set_instance_grounded(self, params: dict[str, Any]) -> None:
        self._instance(params)["grounded"] = _boolean(params.get("grounded"), "grounded")

    def _set_instance_suppressed(self, params: dict[str, Any]) -> None:
        self._instance(params)["suppressed"] = _boolean(params.get("suppressed"), "suppressed")

    def _instance(self, params: dict[str, Any]) -> dict[str, Any]:
        instance_id = _string(params.get("instance_id"), "instance_id")
        instance = self.instances.get(instance_id)
        if instance is None:
            raise AetherWorkspaceError("unknown_entity", f"no instance {instance_id!r}", "instance_id")
        return instance

    def _add_connector(self, params: dict[str, Any]) -> None:
        connector = self._build_connector(params.get("connector"), assign=True)
        self.connector_definitions[connector["id"]] = connector

    def _update_connector(self, params: dict[str, Any]) -> None:
        value = params.get("connector")
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "connector")
        connector_id = _string(value.get("id"), "connector.id")
        if connector_id not in self.connector_definitions:
            raise AetherWorkspaceError("unknown_entity", f"no connector {connector_id!r}")
        self.connector_definitions[connector_id] = self._build_connector(value, assign=False)

    def _build_connector(self, value: object, *, assign: bool) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "connector")
        connector_id = self._new_id("connector") if assign else _string(value.get("id"), "connector.id")
        part_id = _string(value.get("part_definition_id"), "connector.part_definition_id")
        if part_id not in self.part_definitions:
            raise AetherWorkspaceError("unknown_entity", f"no Part definition {part_id!r}", "connector.part_definition_id")
        provenance = value.get("provenance", {})
        if not isinstance(provenance, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "connector.provenance")
        kind = provenance.get("kind", "manual")
        if kind not in {"face", "edge", "vertex", "datum", "manual"}:
            raise AetherWorkspaceError("bad_request", "unsupported provenance kind", "connector.provenance.kind")
        return {
            "id": connector_id,
            "part_definition_id": part_id,
            "name": _string(value.get("name"), "connector.name"),
            "frame_part_local": _normalized_connector_frame(
                value.get("frame_part_local", {}), "connector.frame_part_local"
            ),
            "provenance": {
                "kind": kind,
                "stable_feature_id": self._nullable_string(
                    provenance.get("stable_feature_id"), "connector.provenance.stable_feature_id"
                ),
                "label": self._nullable_string(provenance.get("label"), "connector.provenance.label"),
            },
            "suppressed": _field_boolean(value, "suppressed", False, "connector"),
        }

    def _remove_connector(self, params: dict[str, Any]) -> None:
        connector_id = _string(params.get("connector_id"), "connector_id")
        if any(
            endpoint["connector_definition_id"] == connector_id
            for mate in self.mates.values()
            for endpoint in (mate["endpoint_a"], mate["endpoint_b"])
        ):
            raise AetherWorkspaceError("dependency_conflict", "connector is still mated", "connector_id")
        if self.connector_definitions.pop(connector_id, None) is None:
            raise AetherWorkspaceError("unknown_entity", f"no connector {connector_id!r}")

    def _add_mate(self, params: dict[str, Any]) -> None:
        mate = self._build_mate(params.get("mate"), assign=True)
        self._validate_mate_tree(mate)
        self.mates[mate["id"]] = mate

    def _update_mate(self, params: dict[str, Any]) -> None:
        value = params.get("mate")
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "mate")
        mate_id = _string(value.get("id"), "mate.id")
        old = self.mates.pop(mate_id, None)
        if old is None:
            raise AetherWorkspaceError("unknown_entity", f"no mate {mate_id!r}")
        try:
            mate = self._build_mate(value, assign=False, existing=old)
            self._validate_mate_tree(mate)
        except Exception:
            self.mates[mate_id] = old
            raise
        self.mates[mate_id] = mate

    def _build_mate(self, value: object, *, assign: bool,
                    preview: bool = False,
                    existing: dict[str, Any] | None = None) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "mate")
        mate_id = (
            f"preview-mate-{self.id_counter + 1:06d}" if preview
            else self._new_id("mate") if assign
            else _string(value.get("id"), "mate.id")
        )
        type_id = value.get("type_id", value.get("type"))
        if type_id not in {JointType.FASTENED.value, JointType.REVOLUTE.value, JointType.PRISMATIC.value}:
            raise AetherWorkspaceError("unsupported_capability", "unsupported Assembly v1 mate type", "mate.type_id")
        endpoint_a = self._endpoint(value.get("endpoint_a"), "mate.endpoint_a")
        endpoint_b = self._endpoint(value.get("endpoint_b"), "mate.endpoint_b")
        if endpoint_a["instance_id"] == endpoint_b["instance_id"]:
            raise AetherWorkspaceError("validation_error", "a mate cannot connect an instance to itself", "mate.endpoint_b")
        requested_dofs = value.get("dofs", [])
        if not isinstance(requested_dofs, list):
            raise AetherWorkspaceError("bad_request", "expected an array", "mate.dofs")
        old_by_name = {item["name"]: item for item in (existing or {}).get("dofs", [])}
        dofs = []
        template = JOINT_TYPE_DOF_TEMPLATES[JointType(type_id)]
        if requested_dofs and len(requested_dofs) != len(template):
            raise AetherWorkspaceError("validation_error", "mate DOF count does not match its type", "mate.dofs")
        for index, (default_name, kind, _axis) in enumerate(template):
            request = requested_dofs[index] if requested_dofs else {}
            if not isinstance(request, dict):
                raise AetherWorkspaceError("bad_request", "expected an object", f"mate.dofs[{index}]")
            name = _string(request.get("name", default_name), f"mate.dofs[{index}].name")
            old = old_by_name.get(name)
            dof_id = old["id"] if old is not None else (
                f"preview-dof-{self.id_counter + index + 1:06d}" if preview else self._new_id("dof")
            )
            suffix = "rad" if kind is DofKind.ROTATION else "m"
            other = "m" if suffix == "rad" else "rad"
            value_native = _number(request.get(f"value_{suffix}", request.get(f"neutral_{suffix}", 0.0)), f"mate.dofs[{index}].value_{suffix}")
            neutral = _number(request.get(f"neutral_{suffix}", 0.0), f"mate.dofs[{index}].neutral_{suffix}")
            minimum = _optional_number(request.get(f"limit_min_{suffix}"), f"mate.dofs[{index}].limit_min_{suffix}")
            maximum = _optional_number(request.get(f"limit_max_{suffix}"), f"mate.dofs[{index}].limit_max_{suffix}")
            if (minimum is None) != (maximum is None) or (
                minimum is not None and maximum is not None and minimum >= maximum
            ):
                raise AetherWorkspaceError("validation_error", "limits require min < max or both null", f"mate.dofs[{index}]")
            if request.get(f"value_{other}") is not None:
                raise AetherWorkspaceError("validation_error", "DOF populated the wrong unit family", f"mate.dofs[{index}].value_{other}")
            dofs.append({
                "id": dof_id,
                "name": name,
                "kind": kind.value,
                "value_rad": value_native if suffix == "rad" else None,
                "value_m": value_native if suffix == "m" else None,
                "neutral_rad": neutral if suffix == "rad" else None,
                "neutral_m": neutral if suffix == "m" else None,
                "limit_min_rad": minimum if suffix == "rad" else None,
                "limit_max_rad": maximum if suffix == "rad" else None,
                "limit_min_m": minimum if suffix == "m" else None,
                "limit_max_m": maximum if suffix == "m" else None,
            })
        controls = value.get("controls", [])
        if not isinstance(controls, list):
            raise AetherWorkspaceError("bad_request", "expected an array", "mate.controls")
        normalized_controls = []
        for index, control in enumerate(controls):
            if not isinstance(control, dict):
                raise AetherWorkspaceError("bad_request", "expected an object", f"mate.controls[{index}]")
            scalar = control.get("value")
            if isinstance(scalar, (dict, list)) or scalar is None:
                raise AetherWorkspaceError("bad_request", "expected a scalar", f"mate.controls[{index}].value")
            if isinstance(scalar, float) and not math.isfinite(scalar):
                raise AetherWorkspaceError("bad_request", "expected a finite scalar", f"mate.controls[{index}].value")
            normalized_controls.append({
                "key": _string(control.get("key"), f"mate.controls[{index}].key"),
                "value": scalar,
            })
        normalized_controls.sort(key=lambda item: item["key"])
        return {
            "id": mate_id,
            "name": _string(value.get("name", type_id.title()), "mate.name"),
            "type_id": type_id,
            "endpoint_a": endpoint_a,
            "endpoint_b": endpoint_b,
            "dofs": dofs,
            "controls": normalized_controls,
            "suppressed": _field_boolean(value, "suppressed", False, "mate"),
        }

    def _endpoint(self, value: object, path: str) -> dict[str, str]:
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", path)
        instance_id = _string(value.get("instance_id"), f"{path}.instance_id")
        connector_id = _string(value.get("connector_definition_id"), f"{path}.connector_definition_id")
        instance = self.instances.get(instance_id)
        connector = self.connector_definitions.get(connector_id)
        if instance is None:
            raise AetherWorkspaceError("unknown_entity", f"no instance {instance_id!r}", f"{path}.instance_id")
        if connector is None:
            raise AetherWorkspaceError("unknown_entity", f"no connector {connector_id!r}", f"{path}.connector_definition_id")
        if connector["part_definition_id"] != instance["definition_id"]:
            raise AetherWorkspaceError("validation_error", "connector is not owned by the endpoint instance's Part definition", path)
        if connector["suppressed"]:
            raise AetherWorkspaceError("validation_error", "suppressed connector cannot be mated", path)
        return {"instance_id": instance_id, "connector_definition_id": connector_id}

    def _validate_mate_tree(self, candidate: dict[str, Any]) -> None:
        active = [item for item in self.mates.values() if not item["suppressed"]]
        if not candidate["suppressed"]:
            active.append(candidate)
        child_ids = [item["endpoint_b"]["instance_id"] for item in active]
        if len(child_ids) != len(set(child_ids)):
            raise AetherWorkspaceError("validation_error", "an instance may have only one incoming mate in Assembly v1", "mate.endpoint_b")
        edges = {
            item["endpoint_a"]["instance_id"]: item["endpoint_b"]["instance_id"]
            for item in active
        }
        for start in edges:
            seen: set[str] = set()
            current = start
            while current in edges:
                if current in seen:
                    raise AetherWorkspaceError("validation_error", "mate graph contains a cycle", "mate")
                seen.add(current)
                current = edges[current]

    def _remove_mate(self, params: dict[str, Any]) -> None:
        mate_id = _string(params.get("mate_id"), "mate_id")
        mate = self.mates.get(mate_id)
        if mate is None:
            raise AetherWorkspaceError("unknown_entity", f"no mate {mate_id!r}")
        dof_ids = {dof["id"] for dof in mate["dofs"]}
        if any(
            relation["driver_dof_id"] in dof_ids or relation["driven_dof_id"] in dof_ids
            for relation in self.relations.values()
        ):
            raise AetherWorkspaceError("dependency_conflict", "mate DOF is still used by a relation", "mate_id")
        del self.mates[mate_id]

    def _add_relation(self, params: dict[str, Any]) -> None:
        relation = self._build_relation(params.get("relation"), assign=True)
        self.relations[relation["id"]] = relation

    def _update_relation(self, params: dict[str, Any]) -> None:
        value = params.get("relation")
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "relation")
        relation_id = _string(value.get("id"), "relation.id")
        if relation_id not in self.relations:
            raise AetherWorkspaceError("unknown_entity", f"no relation {relation_id!r}")
        self.relations[relation_id] = self._build_relation(value, assign=False)

    def _build_relation(self, value: object, *, assign: bool) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise AetherWorkspaceError("bad_request", "expected an object", "relation")
        relation_id = self._new_id("relation") if assign else _string(value.get("id"), "relation.id")
        kind_value = value.get("kind")
        try:
            kind = RelationKind(kind_value)
        except ValueError:
            raise AetherWorkspaceError("bad_request", "unsupported relation kind", "relation.kind") from None
        driver_id = _string(value.get("driver_dof_id"), "relation.driver_dof_id")
        driven_id = _string(value.get("driven_dof_id"), "relation.driven_dof_id")
        if driver_id == driven_id:
            raise AetherWorkspaceError("validation_error", "relation cannot drive itself", "relation.driven_dof_id")
        dofs = self._dofs_by_id()
        if driver_id not in dofs or driven_id not in dofs:
            raise AetherWorkspaceError("unknown_entity", "relation references an unknown DOF", "relation")
        expected = RELATION_KIND_DOF_KINDS[kind]
        actual = (DofKind(dofs[driver_id]["kind"]), DofKind(dofs[driven_id]["kind"]))
        if actual != expected:
            raise AetherWorkspaceError("validation_error", "relation DOF kinds do not match its type", "relation.kind")
        if any(item["driven_dof_id"] == driven_id and item["id"] != relation_id for item in self.relations.values()):
            raise AetherWorkspaceError("validation_error", "DOF already has a driving relation", "relation.driven_dof_id")
        ratio = _number(value.get("ratio"), "relation.ratio")
        if ratio == 0.0:
            raise AetherWorkspaceError("validation_error", "relation ratio must be non-zero", "relation.ratio")
        driven_kind = dofs[driven_id]["kind"]
        offset_rad = _optional_number(value.get("offset_rad"), "relation.offset_rad")
        offset_m = _optional_number(value.get("offset_m"), "relation.offset_m")
        if driven_kind == DofKind.ROTATION.value:
            if offset_m is not None:
                raise AetherWorkspaceError("validation_error", "rotation relation cannot use offset_m", "relation.offset_m")
            offset_rad = offset_rad if offset_rad is not None else 0.0
        else:
            if offset_rad is not None:
                raise AetherWorkspaceError("validation_error", "translation relation cannot use offset_rad", "relation.offset_rad")
            offset_m = offset_m if offset_m is not None else 0.0
        return {
            "id": relation_id,
            "kind": kind.value,
            "driver_dof_id": driver_id,
            "driven_dof_id": driven_id,
            "ratio": ratio,
            "offset_rad": offset_rad,
            "offset_m": offset_m,
            "reversed": _field_boolean(value, "reversed", ratio < 0, "relation"),
            "suppressed": _field_boolean(value, "suppressed", False, "relation"),
        }

    def _remove_relation(self, params: dict[str, Any]) -> None:
        relation_id = _string(params.get("relation_id"), "relation_id")
        if self.relations.pop(relation_id, None) is None:
            raise AetherWorkspaceError("unknown_entity", f"no relation {relation_id!r}")

    def _dofs_by_id(self) -> dict[str, dict[str, Any]]:
        return {dof["id"]: dof for mate in self.mates.values() for dof in mate["dofs"]}

    def _set_dof_value(self, params: dict[str, Any]) -> None:
        dof_id = _string(params.get("dof_id"), "dof_id")
        dof = self._dofs_by_id().get(dof_id)
        if dof is None:
            raise AetherWorkspaceError("unknown_entity", f"no DOF {dof_id!r}", "dof_id")
        suffix = "rad" if dof["kind"] == DofKind.ROTATION.value else "m"
        other = "m" if suffix == "rad" else "rad"
        if params.get(f"value_{other}") is not None:
            raise AetherWorkspaceError("validation_error", "DOF value uses the wrong unit family", f"value_{other}")
        dof[f"value_{suffix}"] = _number(params.get(f"value_{suffix}"), f"value_{suffix}")

    def save(self, path: Path) -> dict[str, Any]:
        archive_bytes, digest = self.to_bytes()
        path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
        )
        os.close(descriptor)
        temporary = Path(temporary_name)
        try:
            temporary.write_bytes(archive_bytes)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
        return {"path": str(path), "revision": self.revision, "graph_sha256": digest}

    def to_bytes(self) -> tuple[bytes, str]:
        """Serialize the canonical container for browser/native file dialogs."""
        graph_bytes = _canonical_json(self.graph())
        digest = hashlib.sha256(graph_bytes).hexdigest()
        manifest = {
            "format": FORMAT_NAME,
            "format_version": FORMAT_VERSION,
            "workspace_id": self.workspace_id,
            "name": self.name,
            "core_semantics_version": "1",
            "graph_path": "state/graph.json",
            "graph_sha256": digest,
            "root_view_ids": sorted(self.assemblies) + sorted(part_id for part_id, part in self.part_definitions.items() if "feature_document" in part),
            "display_unit_system": "metric",
        }
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            _write_zip_entry(archive, "manifest.json", _canonical_json(manifest))
            _write_zip_entry(archive, "state/graph.json", graph_bytes)
        return buffer.getvalue(), digest

    @classmethod
    def load(cls, path: Path) -> "AetherWorkspace":
        try:
            return cls.from_bytes(path.read_bytes(), source=str(path))
        except AetherWorkspaceError:
            raise
        except OSError as error:
            raise AetherWorkspaceError("format_error", str(error), str(path)) from error

    @classmethod
    def from_bytes(cls, data: bytes, *, source: str = "workspace_data_base64") -> "AetherWorkspace":
        """Decode a canonical container without giving the browser format ownership."""
        try:
            with zipfile.ZipFile(io.BytesIO(data), "r") as archive:
                _safe_zip_names(archive.namelist())
                manifest = json.loads(archive.read("manifest.json"))
                if not isinstance(manifest, dict) or manifest.get("format") != FORMAT_NAME:
                    raise AetherWorkspaceError("format_error", "not an Aether workspace", "manifest.json.format")
                if manifest.get("format_version") != FORMAT_VERSION:
                    raise AetherWorkspaceError("format_error", "unsupported workspace format version", "manifest.json.format_version")
                graph_path = manifest.get("graph_path")
                if graph_path != "state/graph.json":
                    raise AetherWorkspaceError("format_error", "unsupported graph path", "manifest.json.graph_path")
                graph_bytes = archive.read(graph_path)
                digest = hashlib.sha256(graph_bytes).hexdigest()
                if digest != manifest.get("graph_sha256"):
                    raise AetherWorkspaceError("format_error", "semantic graph checksum mismatch", "state/graph.json")
                graph = json.loads(graph_bytes)
                cache_entries = [name for name in archive.namelist() if name.startswith("cache/")]
        except AetherWorkspaceError:
            raise
        except (OSError, KeyError, json.JSONDecodeError, zipfile.BadZipFile) as error:
            raise AetherWorkspaceError("format_error", str(error), source) from error
        workspace = cls.from_graph(graph)
        if workspace.workspace_id != manifest.get("workspace_id"):
            raise AetherWorkspaceError("format_error", "manifest workspace ID mismatch", "manifest.json.workspace_id")
        if cache_entries:
            workspace.issues.append(
                workspace._diagnostic(
                    "cache_ignored",
                    "Disposable geometry/render caches were ignored and may be rebuilt.",
                    [],
                    severity="info",
                )
            )
        return workspace

    @classmethod
    def from_graph(cls, value: object) -> "AetherWorkspace":
        if not isinstance(value, dict):
            raise AetherWorkspaceError("format_error", "semantic graph must be an object", "state/graph.json")
        if value.get("schema_version") != GRAPH_SCHEMA_VERSION:
            raise AetherWorkspaceError("format_error", "unsupported semantic graph version", "state/graph.json.schema_version")
        try:
            workspace = cls(
                workspace_id=_string(value.get("workspace_id"), "state/graph.json.workspace_id"),
                name=_string(value.get("name"), "state/graph.json.name"),
                revision_number=int(_string(value.get("revision"), "state/graph.json.revision")),
                id_counter=int(value.get("id_counter", 0)),
                document_settings=copy.deepcopy(value.get("document_settings", {})),
            )
        except (TypeError, ValueError) as error:
            raise AetherWorkspaceError("format_error", str(error), "state/graph.json") from error
        for field_name in (
            "part_definitions", "assemblies", "instances", "connector_definitions",
            "mates", "relations", "configurations",
        ):
            entries = value.get(field_name)
            if not isinstance(entries, list):
                raise AetherWorkspaceError("format_error", "expected an array", f"state/graph.json.{field_name}")
            mapping: dict[str, dict[str, Any]] = {}
            for index, item in enumerate(entries):
                if not isinstance(item, dict) or not isinstance(item.get("id"), str):
                    raise AetherWorkspaceError("format_error", "entity requires an ID", f"state/graph.json.{field_name}[{index}]")
                if item["id"] in mapping:
                    raise AetherWorkspaceError("format_error", "duplicate entity ID", f"state/graph.json.{field_name}[{index}].id")
                mapping[item["id"]] = copy.deepcopy(item)
            setattr(workspace, field_name, mapping)
        try:
            workspace._validate_loaded_graph()
        except AetherWorkspaceError as error:
            if error.code == "format_error":
                raise
            raise AetherWorkspaceError(
                "format_error", error.message, error.path
            ) from error
        return workspace

    def _validate_loaded_graph(self) -> None:
        if not self.assemblies:
            raise AetherWorkspaceError("format_error", "workspace has no Assembly", "state/graph.json.assemblies")
        self.assemblies = {
            assembly_id: {
                "id": assembly_id,
                "name": _string(item.get("name"), "state/graph.json.assemblies.name"),
                "description": self._nullable_string(
                    item.get("description"), "state/graph.json.assemblies.description"
                ),
            }
            for assembly_id, item in self.assemblies.items()
        }
        self.part_definitions = {
            part_id: self._build_part_definition(item, assign=False)
            for part_id, item in self.part_definitions.items()
        }
        # Keep the complete raw mapping visible while validating parent links,
        # then replace it with normalized entries in one step.
        self.instances = {
            instance_id: self._build_instance(item, assign=False)
            for instance_id, item in self.instances.items()
        }
        self.connector_definitions = {
            connector_id: self._build_connector(item, assign=False)
            for connector_id, item in self.connector_definitions.items()
        }
        original_mates = self.mates
        self.mates = {}
        for mate_id in sorted(original_mates):
            mate = self._build_mate(
                original_mates[mate_id], assign=False, existing=original_mates[mate_id]
            )
            self._validate_mate_tree(mate)
            self.mates[mate_id] = mate
        original_relations = self.relations
        self.relations = {}
        for relation_id in sorted(original_relations):
            relation = self._build_relation(original_relations[relation_id], assign=False)
            self.relations[relation_id] = relation
        configurations: dict[str, dict[str, Any]] = {}
        for configuration_id, item in self.configurations.items():
            suppressed = item.get("suppressed_instance_ids", [])
            overridden = item.get("overridden_dof_ids", [])
            if not isinstance(suppressed, list) or not all(
                isinstance(value, str) for value in suppressed
            ):
                raise AetherWorkspaceError(
                    "format_error", "expected an array of IDs",
                    "state/graph.json.configurations.suppressed_instance_ids",
                )
            if not isinstance(overridden, list) or not all(
                isinstance(value, str) for value in overridden
            ):
                raise AetherWorkspaceError(
                    "format_error", "expected an array of IDs",
                    "state/graph.json.configurations.overridden_dof_ids",
                )
            configurations[configuration_id] = {
                "id": configuration_id,
                "name": _string(
                    item.get("name"), "state/graph.json.configurations.name"
                ),
                "active": _field_boolean(
                    item, "active", False, "state/graph.json.configurations"
                ),
                "suppressed_instance_ids": sorted(set(suppressed)),
                "overridden_dof_ids": sorted(set(overridden)),
            }
        self.configurations = configurations
        if sum(1 for item in self.configurations.values() if item["active"]) > 1:
            raise AetherWorkspaceError(
                "format_error", "only one configuration may be active",
                "state/graph.json.configurations",
            )
        numeric_suffixes = [
            int(entity_id.rsplit("-", 1)[1])
            for mapping in (
                self.part_definitions, self.assemblies, self.instances,
                self.connector_definitions, self.mates, self.relations,
                self.configurations,
            )
            for entity_id in mapping
            if entity_id.rsplit("-", 1)[-1].isdigit()
        ]
        self.id_counter = max([self.id_counter, *numeric_suffixes])


__all__ = [
    "AetherWorkspace",
    "AetherWorkspaceError",
    "FORMAT_NAME",
    "FORMAT_VERSION",
    "GRAPH_SCHEMA_VERSION",
]
