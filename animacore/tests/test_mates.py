"""Mate-authoring model: static per-kind schema and per-instance hook."""

import pytest

from animacore.mates import (
    JOINT_TYPE_DOF_TEMPLATES,
    UNIVERSAL_CONTROL_IDS,
    JointType,
    MateConnector,
    MateControls,
    MateOffset,
    RotationAxis,
    all_mate_type_schemas,
    describe_mate,
    mate_type_schema,
)
from animacore.rig import Joint, RotationDof, TranslationDof

EXPECTED_UNIVERSAL = [
    "connector_a",
    "connector_b",
    "offset",
    "flip_primary_axis",
    "secondary_axis_rotation",
    "simulation_connection",
]


class TestMateTypeSchema:
    @pytest.mark.parametrize("joint_type", list(JointType))
    def test_schema_shape_for_every_kind(self, joint_type):
        schema = mate_type_schema(joint_type)
        template = JOINT_TYPE_DOF_TEMPLATES[joint_type]
        assert schema["type"] == joint_type.value
        assert schema["label"]
        assert schema["dof_count"] == len(template)
        assert schema["universal_controls"] == EXPECTED_UNIVERSAL
        assert len(schema["dofs"]) == len(template)
        for slot, (name, kind) in zip(schema["dofs"], template, strict=True):
            assert slot["name"] == name
            assert slot["kind"] == kind.value
            assert slot["unit"] == (
                "radians" if kind.value == "rotation" else "meters"
            )

    def test_universal_controls_match_constant(self):
        assert list(UNIVERSAL_CONTROL_IDS) == EXPECTED_UNIVERSAL

    def test_fastened_has_no_dofs(self):
        assert mate_type_schema(JointType.FASTENED)["dofs"] == []

    def test_ball_has_three_rotation_dofs(self):
        dofs = mate_type_schema(JointType.BALL)["dofs"]
        assert [d["kind"] for d in dofs] == ["rotation", "rotation", "rotation"]

    def test_pin_slot_rotation_then_translation(self):
        dofs = mate_type_schema(JointType.PIN_SLOT)["dofs"]
        assert [d["kind"] for d in dofs] == ["rotation", "translation"]

    def test_all_schemas_covers_eight_kinds(self):
        schemas = all_mate_type_schemas()
        assert len(schemas) == 8
        assert [s["type"] for s in schemas] == [t.value for t in JointType]
        assert {s["label"] for s in schemas} >= {"Revolute", "Slider", "Ball"}


class TestDescribeMate:
    def _joint(self, **kwargs) -> Joint:
        base = dict(
            name="pan",
            joint_type=JointType.CYLINDRICAL,
            parent_part="base",
            child_part="carriage",
            dofs=(
                RotationDof(name="rotation"),
                TranslationDof(
                    name="travel", min_meters=-0.01, max_meters=0.01
                ),
            ),
        )
        base.update(kwargs)
        return Joint(**base)

    def test_bare_joint_describes_with_default_controls(self):
        described = describe_mate(self._joint())
        assert described["id"] == ""
        assert described["name"] == "pan"
        assert described["type"] == "cylindrical"
        assert described["parent_part"] == "base"
        assert described["child_part"] == "carriage"
        controls = described["controls"]
        assert controls["connectors"] == {"a": None, "b": None}
        assert controls["offset"]["enabled"] is False
        assert controls["offset"]["rotation_axis"] == "z"
        assert controls["flip_primary_axis"] is False
        assert controls["secondary_axis_rotation_deg"] == 0
        assert controls["simulation_connection"] is True

    def test_dof_descriptors_carry_paths_and_limits(self):
        dofs = describe_mate(self._joint())["dofs"]
        assert dofs[0]["path"] == "pan.rotation"
        assert dofs[0]["kind"] == "rotation"
        assert dofs[0]["unit"] == "radians"
        assert dofs[0]["min"] is None
        assert dofs[1]["path"] == "pan.travel"
        assert dofs[1]["unit"] == "meters"
        assert dofs[1]["min"] == pytest.approx(-0.01)

    def test_full_controls_serialize(self):
        controls = MateControls(
            connector_a=MateConnector(
                part="base", origin_m=(0, 0, 0.05), feature="base/top"
            ),
            connector_b=MateConnector(part="carriage"),
            offset=MateOffset(
                enabled=True,
                translation_m=(0, 0, 0.01),
                rotation_axis=RotationAxis.X,
                rotation_radians=0.5,
            ),
            flip_primary_axis=True,
            secondary_axis_rotation_deg=180,
            simulation_connection=False,
        )
        described = describe_mate(self._joint(id="Cylindrical 4", controls=controls))
        assert described["id"] == "Cylindrical 4"
        connectors = described["controls"]["connectors"]
        assert connectors["a"]["part"] == "base"
        assert connectors["a"]["origin_m"] == [0.0, 0.0, 0.05]
        assert connectors["a"]["feature"] == "base/top"
        assert connectors["b"]["part"] == "carriage"
        offset = described["controls"]["offset"]
        assert offset["enabled"] is True
        assert offset["rotation_axis"] == "x"
        assert offset["rotation_radians"] == pytest.approx(0.5)
        assert described["controls"]["flip_primary_axis"] is True
        assert described["controls"]["secondary_axis_rotation_deg"] == 180
        assert described["controls"]["simulation_connection"] is False
