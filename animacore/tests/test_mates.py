"""Mate-authoring model: static per-kind schema and per-instance hook."""

import pytest

from animacore.mates import (
    JOINT_TYPE_DOF_TEMPLATES,
    UNIVERSAL_CONTROL_IDS,
    JointType,
    MateCategory,
    MateConnector,
    MateControls,
    MateOffset,
    RotationAxis,
    TangentSpec,
    all_mate_type_schemas,
    describe_mate,
    mate_category,
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

EXPECTED_WIDTH_CONTROLS = [
    "connector_a",
    "connector_b",
    "flip_primary_axis",
    "simulation_connection",
]

EXPECTED_TANGENT_CONTROLS = [
    "tangent_selection_a",
    "tangent_selection_b",
    "tangent_propagation",
    "simulation_connection",
]

GEOMETRY_CONSTRAINT_TYPES = {JointType.WIDTH, JointType.TANGENT}


def _expected_controls(joint_type):
    if joint_type is JointType.WIDTH:
        return EXPECTED_WIDTH_CONTROLS
    if joint_type is JointType.TANGENT:
        return EXPECTED_TANGENT_CONTROLS
    return EXPECTED_UNIVERSAL


class TestMateTypeSchema:
    @pytest.mark.parametrize("joint_type", list(JointType))
    def test_schema_shape_for_every_kind(self, joint_type):
        schema = mate_type_schema(joint_type)
        template = JOINT_TYPE_DOF_TEMPLATES[joint_type]
        assert schema["type"] == joint_type.value
        assert schema["label"]
        assert schema["dof_count"] == len(template)
        assert schema["universal_controls"] == _expected_controls(joint_type)
        assert len(schema["dofs"]) == len(template)
        for slot, (name, kind, axis) in zip(schema["dofs"], template, strict=True):
            assert slot["name"] == name
            assert slot["kind"] == kind.value
            assert slot["unit"] == (
                "radians" if kind.value == "rotation" else "meters"
            )

    @pytest.mark.parametrize("joint_type", list(JointType))
    def test_schema_carries_category_and_drivable(self, joint_type):
        schema = mate_type_schema(joint_type)
        is_geometry = joint_type in GEOMETRY_CONSTRAINT_TYPES
        expected_category = (
            MateCategory.GEOMETRY_CONSTRAINT
            if is_geometry
            else MateCategory.KINEMATIC
        )
        assert schema["category"] == expected_category.value
        assert schema["category"] == mate_category(joint_type).value
        assert schema["drivable"] is (not is_geometry)
        # Only the geometry-constraint pair carries the app-resolved note.
        assert ("note" in schema) is is_geometry

    def test_width_schema_has_no_offset_control(self):
        schema = mate_type_schema(JointType.WIDTH)
        assert schema["category"] == "geometry_constraint"
        assert schema["drivable"] is False
        assert schema["dof_count"] == 0
        assert schema["universal_controls"] == EXPECTED_WIDTH_CONTROLS
        assert "offset" not in schema["universal_controls"]
        assert "secondary_axis_rotation" not in schema["universal_controls"]
        assert schema["note"]

    def test_tangent_schema_has_tangent_controls_and_no_connectors(self):
        schema = mate_type_schema(JointType.TANGENT)
        assert schema["category"] == "geometry_constraint"
        assert schema["drivable"] is False
        assert schema["dof_count"] == 0
        assert schema["universal_controls"] == EXPECTED_TANGENT_CONTROLS
        assert "connector_a" not in schema["universal_controls"]
        assert "connector_b" not in schema["universal_controls"]
        assert "offset" not in schema["universal_controls"]
        assert schema["note"]

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

    def test_all_schemas_covers_ten_kinds(self):
        schemas = all_mate_type_schemas()
        assert len(schemas) == 10
        assert [s["type"] for s in schemas] == [t.value for t in JointType]
        assert {s["label"] for s in schemas} >= {
            "Revolute",
            "Slider",
            "Ball",
            "Width",
            "Tangent",
        }
        # The eight kinematic mates lead, the two geometry-constraint
        # mates trail (JointType order).
        assert [s["category"] for s in schemas] == (
            ["kinematic"] * 8 + ["geometry_constraint"] * 2
        )
        assert [s["type"] for s in schemas][-2:] == ["width", "tangent"]


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


class TestDofAxes:
    """The canonical axis per DOF — the UI needs it to label a Slider's
    travel as Z but a Pin Slot's as X (both are one bare 'translation')."""

    def test_slider_translates_along_z(self):
        dofs = mate_type_schema(JointType.PRISMATIC)["dofs"]
        assert dofs[0]["axis"] == "z"

    def test_pin_slot_translates_along_x_rotates_about_z(self):
        dofs = mate_type_schema(JointType.PIN_SLOT)["dofs"]
        by_kind = {d["kind"]: d["axis"] for d in dofs}
        assert by_kind == {"translation": "x", "rotation": "z"}

    def test_planar_axes(self):
        dofs = mate_type_schema(JointType.PLANAR)["dofs"]
        assert [d["axis"] for d in dofs] == ["x", "y", "z"]

    def test_ball_rotates_about_all_three(self):
        dofs = mate_type_schema(JointType.BALL)["dofs"]
        assert [d["axis"] for d in dofs] == ["x", "y", "z"]

    def test_every_rotation_is_z_except_ball(self):
        for jt in JointType:
            if jt is JointType.BALL:
                continue
            for d in mate_type_schema(jt)["dofs"]:
                if d["kind"] == "rotation":
                    assert d["axis"] == "z", jt


class TestDescribeGeometryConstraintMate:
    """describe_mate for the two geometry-constraint mates (app-resolved).

    Width reuses the connector/flip/simulation controls block (its
    connectors are app-computed midplanes); tangent reports a distinct
    tangent block instead of connectors. Both carry ``category``.
    """

    def test_width_describes_with_category_and_connectors(self):
        joint = Joint(
            name="center_tab",
            joint_type=JointType.WIDTH,
            parent_part="frame",
            child_part="tab",
            id="Width 1",
            controls=MateControls(
                connector_a=MateConnector(part="frame"),
                connector_b=MateConnector(part="tab"),
            ),
        )
        described = describe_mate(joint)
        assert described["type"] == "width"
        assert described["category"] == "geometry_constraint"
        assert described["id"] == "Width 1"
        assert described["dofs"] == []
        # Width carries the controls block with its two connectors.
        assert described["controls"]["connectors"]["a"]["part"] == "frame"
        assert described["controls"]["connectors"]["b"]["part"] == "tab"
        # No tangent block on a width.
        assert "tangent" not in described

    def test_tangent_describes_with_category_and_tangent_block(self):
        joint = Joint(
            name="cam_contact",
            joint_type=JointType.TANGENT,
            parent_part="cam",
            child_part="follower",
            id="Tangent 1",
            tangent=TangentSpec(
                selection_a="cam/lobe",
                selection_b="follower/roller",
                propagation=False,
            ),
        )
        described = describe_mate(joint)
        assert described["type"] == "tangent"
        assert described["category"] == "geometry_constraint"
        assert described["id"] == "Tangent 1"
        assert described["dofs"] == []
        # Tangent reports its selection block INSTEAD of connectors.
        assert "controls" not in described
        assert described["tangent"] == {
            "selection_a": "cam/lobe",
            "selection_b": "follower/roller",
            "propagation": False,
        }

    def test_kinematic_mate_describe_still_carries_category(self):
        joint = Joint(
            name="pan",
            joint_type=JointType.REVOLUTE,
            parent_part="base",
            child_part="arm",
            dofs=(RotationDof(name="rotation"),),
        )
        described = describe_mate(joint)
        assert described["category"] == "kinematic"
        # The kinematic controls shape is unchanged (still a controls dict).
        assert "controls" in described
        assert "tangent" not in described


class TestGeometryConstraintJointModel:
    """Joint-level validation for the geometry-constraint mates."""

    def test_width_rejects_enabled_offset(self):
        with pytest.raises(ValueError, match="offset"):
            Joint(
                name="center_tab",
                joint_type=JointType.WIDTH,
                parent_part="frame",
                child_part="tab",
                controls=MateControls(
                    offset=MateOffset(enabled=True, translation_m=(0, 0, 0.01))
                ),
            )

    def test_tangent_rejects_mate_controls(self):
        with pytest.raises(ValueError, match="tangent"):
            Joint(
                name="cam_contact",
                joint_type=JointType.TANGENT,
                parent_part="cam",
                child_part="follower",
                controls=MateControls(),
                tangent=TangentSpec(selection_a="a", selection_b="b"),
            )

    def test_kinematic_mate_rejects_tangent_block(self):
        with pytest.raises(ValueError, match="tangent block"):
            Joint(
                name="pan",
                joint_type=JointType.REVOLUTE,
                parent_part="base",
                child_part="arm",
                dofs=(RotationDof(name="rotation"),),
                tangent=TangentSpec(selection_a="a", selection_b="b"),
            )

    def test_width_and_tangent_are_zero_dof(self):
        for jt in (JointType.WIDTH, JointType.TANGENT):
            tangent = (
                TangentSpec(selection_a="a", selection_b="b")
                if jt is JointType.TANGENT
                else None
            )
            with pytest.raises(ValueError, match="dof kinds"):
                Joint(
                    name="bad",
                    joint_type=jt,
                    parent_part="p",
                    child_part="c",
                    dofs=(RotationDof(name="rotation"),),
                    tangent=tangent,
                )

    def test_tangent_spec_rejects_empty_selection(self):
        with pytest.raises(ValueError, match="selection_a"):
            TangentSpec(selection_a="", selection_b="b")
