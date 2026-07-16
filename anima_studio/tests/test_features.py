"""Parametric feature templates: schema, expressions, expansion, merge."""

import copy
import math
from pathlib import Path

import pytest
import yaml

from anima_studio.extensions import (
    ContributionKind,
    ExtensionManifestError,
    discover_extensions,
    parse_manifest,
)
from anima_studio.features import (
    FeatureExpansionError,
    FeatureTemplate,
    FeatureTemplateError,
    FloatUnit,
    ParameterKind,
    evaluate_expression,
    expand_feature,
    merge_fragment,
    parse_feature_template,
)
from anima_studio.loader import parse_character
from anima_studio.rig import evaluate_pose, project_channels

EXTENSIONS_DIR = (
    Path(__file__).resolve().parents[2] / "examples" / "extensions"
)

BASE_TEMPLATE = {
    "anima_feature": "1.0",
    "name": "Test linkage",
    "description": "A two-part hinge.",
    "parameters": [
        {
            "name": "limit_deg",
            "kind": "float",
            "unit": "deg",
            "default": 45,
            "min": 5,
            "max": 180,
        },
    ],
    "body": {
        "parts": {
            "base": {"parent": "$parent"},
            "flap": {},
        },
        "joints": {
            "hinge": {
                "type": "revolute",
                "parent": "base",
                "child": "flap",
                "dofs": {
                    "rotation": {
                        "limits": {
                            "min_deg": "${-limit_deg}",
                            "max_deg": "${limit_deg}",
                        },
                        "neutral_deg": 0,
                    },
                },
            },
        },
    },
}

BASE_CHARACTER = {
    "anima_version": "2.0",
    "type": "character",
    "identity": {"name": "feature_testbed"},
    "parts": {"chassis": None},
}


def template(**overrides) -> dict:
    doc = copy.deepcopy(BASE_TEMPLATE)
    doc.update(overrides)
    return doc


def parse(doc: dict) -> FeatureTemplate:
    return parse_feature_template(yaml.safe_dump(doc))


def assert_rejects(doc: dict, path_fragment: str):
    with pytest.raises(FeatureTemplateError) as excinfo:
        parse(doc)
    assert path_fragment in excinfo.value.path, excinfo.value


def parse_merged(character: dict):
    """Run the merged mapping through the real loader — the gatekeeper."""
    return parse_character(yaml.safe_dump(character))


class TestTemplateAccepts:
    def test_full_template(self):
        parsed = parse(
            template(
                parameters=[
                    {
                        "name": "length_mm",
                        "kind": "float",
                        "unit": "mm",
                        "default": 120.5,
                        "min": 10,
                        "max": 500,
                        "description": "Link length",
                    },
                    {
                        "name": "links",
                        "kind": "int",
                        "default": 3,
                        "min": 2,
                        "max": 8,
                    },
                    {"name": "gripper", "kind": "bool", "default": True},
                    {
                        "name": "mount",
                        "kind": "choice",
                        "choices": ["floor", "ceiling"],
                        "default": "floor",
                    },
                ]
            )
        )
        assert parsed.name == "Test linkage"
        assert parsed.description == "A two-part hinge."
        length, links, gripper, mount = parsed.parameters
        assert length.kind is ParameterKind.FLOAT
        assert length.unit is FloatUnit.MM
        assert length.default == 120.5
        assert (length.minimum, length.maximum) == (10.0, 500.0)
        assert links.kind is ParameterKind.INT
        assert links.default == 3
        assert gripper.kind is ParameterKind.BOOL
        assert gripper.default is True
        assert gripper.unit is None
        assert mount.kind is ParameterKind.CHOICE
        assert mount.choices == ("floor", "ceiling")
        assert mount.default == "floor"
        assert parsed.parameter("links") is links

    def test_minimal_template(self):
        doc = {
            "anima_feature": "1.0",
            "name": "Tiny",
            "body": {"parts": {"peg": {}}},
        }
        parsed = parse(doc)
        assert parsed.parameters == ()
        assert parsed.description == ""

    def test_repeat_blocks_parse(self):
        doc = template()
        doc["body"]["repeat"] = [
            {
                "count": "${limit_deg}",
                "var": "i",
                "body": {"parts": {"link_${i}": {}}},
            },
            {"count": 2, "var": "j", "body": {"parts": {"rib_${j}": {}}}},
        ]
        parse(doc)


class TestTemplateRejects:
    def test_not_yaml(self):
        with pytest.raises(FeatureTemplateError):
            parse_feature_template(":\n  - {")

    def test_not_a_mapping(self):
        with pytest.raises(FeatureTemplateError):
            parse_feature_template("- a\n- list\n")

    def test_unknown_top_level_field(self):
        assert_rejects(template(bogus=1), "bogus")

    def test_missing_schema_version(self):
        doc = template()
        del doc["anima_feature"]
        assert_rejects(doc, "anima_feature")

    def test_unsupported_schema_version(self):
        assert_rejects(template(anima_feature="2.0"), "anima_feature")

    def test_missing_name(self):
        doc = template()
        del doc["name"]
        assert_rejects(doc, "name")

    def test_missing_body(self):
        doc = template()
        del doc["body"]
        assert_rejects(doc, "body")

    def test_empty_body(self):
        assert_rejects(template(body={}), "body")

    def test_unknown_body_section(self):
        assert_rejects(template(body={"outputs": []}), "body.outputs")

    def test_body_section_wrong_shape(self):
        assert_rejects(template(body={"parts": []}), "body.parts")
        assert_rejects(template(body={"relations": {}}), "body.relations")

    @pytest.mark.parametrize("required", ["name", "kind", "default"])
    def test_missing_parameter_field(self, required):
        entry = {"name": "n", "kind": "int", "default": 1}
        del entry[required]
        assert_rejects(template(parameters=[entry]), "parameters[0]")

    def test_parameter_name_must_be_identifier(self):
        assert_rejects(
            template(
                parameters=[{"name": "bad-name", "kind": "int", "default": 1}]
            ),
            "parameters[0].name",
        )

    def test_duplicate_parameter_name(self):
        entry = {"name": "n", "kind": "int", "default": 1}
        assert_rejects(
            template(parameters=[entry, dict(entry)]), "parameters[1].name"
        )

    def test_unknown_parameter_kind(self):
        assert_rejects(
            template(
                parameters=[{"name": "n", "kind": "text", "default": "x"}]
            ),
            "parameters[0].kind",
        )

    def test_float_requires_unit(self):
        assert_rejects(
            template(
                parameters=[{"name": "n", "kind": "float", "default": 1.0}]
            ),
            "parameters[0].unit",
        )

    def test_unknown_unit(self):
        assert_rejects(
            template(
                parameters=[
                    {
                        "name": "n",
                        "kind": "float",
                        "unit": "furlong",
                        "default": 1.0,
                    }
                ]
            ),
            "parameters[0].unit",
        )

    @pytest.mark.parametrize(
        "kind,field,value",
        [
            ("int", "unit", "deg"),
            ("bool", "min", 0),
            ("bool", "unit", "deg"),
            ("choice", "max", 3),
            ("int", "choices", ["a"]),
        ],
    )
    def test_field_not_allowed_for_kind(self, kind, field, value):
        entry = {"name": "n", "kind": kind, "default": 1}
        if kind == "bool":
            entry["default"] = True
        if kind == "choice":
            entry["choices"] = ["a", "b"]
            entry["default"] = "a"
        entry[field] = value
        assert_rejects(template(parameters=[entry]), f"parameters[0].{field}")

    def test_descending_range(self):
        assert_rejects(
            template(
                parameters=[
                    {
                        "name": "n",
                        "kind": "int",
                        "default": 3,
                        "min": 8,
                        "max": 2,
                    }
                ]
            ),
            "parameters[0].min",
        )

    def test_default_outside_range(self):
        assert_rejects(
            template(
                parameters=[
                    {
                        "name": "n",
                        "kind": "int",
                        "default": 9,
                        "min": 2,
                        "max": 8,
                    }
                ]
            ),
            "parameters[0].default",
        )

    def test_default_wrong_kind(self):
        assert_rejects(
            template(
                parameters=[{"name": "n", "kind": "int", "default": 1.5}]
            ),
            "parameters[0].default",
        )
        assert_rejects(
            template(
                parameters=[{"name": "n", "kind": "bool", "default": 1}]
            ),
            "parameters[0].default",
        )

    def test_choice_default_not_in_choices(self):
        assert_rejects(
            template(
                parameters=[
                    {
                        "name": "n",
                        "kind": "choice",
                        "choices": ["a", "b"],
                        "default": "c",
                    }
                ]
            ),
            "parameters[0].default",
        )

    def test_choices_must_be_unique_non_empty(self):
        assert_rejects(
            template(
                parameters=[
                    {
                        "name": "n",
                        "kind": "choice",
                        "choices": ["a", "a"],
                        "default": "a",
                    }
                ]
            ),
            "parameters[0].choices[1]",
        )
        assert_rejects(
            template(
                parameters=[
                    {
                        "name": "n",
                        "kind": "choice",
                        "choices": [],
                        "default": "a",
                    }
                ]
            ),
            "parameters[0].choices",
        )

    @pytest.mark.parametrize("missing", ["count", "var", "body"])
    def test_repeat_block_missing_field(self, missing):
        block = {"count": 2, "var": "i", "body": {"parts": {"p_${i}": {}}}}
        del block[missing]
        doc = template()
        doc["body"]["repeat"] = [block]
        assert_rejects(doc, f"body.repeat[0].{missing}")

    def test_repeat_var_shadows_parameter(self):
        doc = template()
        doc["body"]["repeat"] = [
            {
                "count": 2,
                "var": "limit_deg",
                "body": {"parts": {"p_${limit_deg}": {}}},
            }
        ]
        assert_rejects(doc, "body.repeat[0].var")

    def test_nested_repeat_var_shadows_outer(self):
        doc = template()
        doc["body"]["repeat"] = [
            {
                "count": 2,
                "var": "i",
                "body": {
                    "repeat": [
                        {
                            "count": 2,
                            "var": "i",
                            "body": {"parts": {"p_${i}": {}}},
                        }
                    ]
                },
            }
        ]
        assert_rejects(doc, "repeat[0].var")

    def test_repeat_count_wrong_type(self):
        doc = template()
        doc["body"]["repeat"] = [
            {"count": 2.5, "var": "i", "body": {"parts": {"p_${i}": {}}}}
        ]
        assert_rejects(doc, "body.repeat[0].count")


class TestExpressionEvaluator:
    SCOPE = {"a": 4, "b": 2.5, "flag": True, "mode": "fast"}

    def test_precedence(self):
        assert evaluate_expression("1 + 2 * 3", {}) == 7
        assert evaluate_expression("6 / 2 + 1", {}) == 4.0

    def test_parentheses(self):
        assert evaluate_expression("(1 + 2) * 3", {}) == 9

    def test_unary_minus(self):
        assert evaluate_expression("-a", self.SCOPE) == -4
        assert evaluate_expression("3 - -2", {}) == 5
        assert evaluate_expression("-(1 + 2)", {}) == -3

    def test_names_resolve(self):
        assert evaluate_expression("a * b", self.SCOPE) == 10.0

    def test_bool_coerces_in_arithmetic(self):
        assert evaluate_expression("flag + 1", self.SCOPE) == 2

    def test_bare_choice_name_passes_through(self):
        assert evaluate_expression("mode", self.SCOPE) == "fast"

    def test_choice_in_arithmetic_is_an_error(self):
        with pytest.raises(ValueError, match="arithmetic"):
            evaluate_expression("mode + 1", self.SCOPE)

    def test_unknown_name(self):
        with pytest.raises(ValueError, match="unknown name 'ghost'"):
            evaluate_expression("ghost + 1", {})

    def test_division_by_zero(self):
        with pytest.raises(ValueError, match="division by zero"):
            evaluate_expression("1 / (a - 4)", self.SCOPE)

    @pytest.mark.parametrize(
        "bad", ["", "1 +", "* 2", "(1", "1 2", "a ** 2", "f(1)", "1 @ 2"]
    )
    def test_syntax_errors(self, bad):
        with pytest.raises(ValueError):
            evaluate_expression(bad, self.SCOPE)

    def test_int_arithmetic_stays_int(self):
        assert evaluate_expression("a + 1", self.SCOPE) == 5
        assert isinstance(evaluate_expression("a + 1", self.SCOPE), int)

    def test_float_literals(self):
        assert evaluate_expression("0.5 + .25", {}) == 0.75


class TestParameterValidation:
    def test_defaults_apply(self):
        fragment = expand_feature(parse(template()), "inst")
        limits = fragment["joints"]["inst_hinge"]["dofs"]["rotation"]["limits"]
        assert limits == {"min_deg": -45.0, "max_deg": 45.0}

    def test_supplied_value_overrides_default(self):
        fragment = expand_feature(
            parse(template()), "inst", {"limit_deg": 30}
        )
        limits = fragment["joints"]["inst_hinge"]["dofs"]["rotation"]["limits"]
        assert limits == {"min_deg": -30.0, "max_deg": 30.0}

    def test_unknown_parameter_name(self):
        with pytest.raises(FeatureExpansionError, match="unknown parameter"):
            expand_feature(parse(template()), "inst", {"ghost": 1})

    def test_out_of_range(self):
        with pytest.raises(FeatureExpansionError) as excinfo:
            expand_feature(parse(template()), "inst", {"limit_deg": 999})
        assert "limit_deg" in excinfo.value.path

    def test_wrong_kind(self):
        with pytest.raises(FeatureExpansionError):
            expand_feature(parse(template()), "inst", {"limit_deg": "wide"})

    def test_int_rejects_float_and_bool(self):
        doc = template(
            parameters=[{"name": "links", "kind": "int", "default": 2}],
        )
        doc["body"] = {"parts": {"p": {}}}
        parsed = parse(doc)
        with pytest.raises(FeatureExpansionError):
            expand_feature(parsed, "inst", {"links": 2.5})
        with pytest.raises(FeatureExpansionError):
            expand_feature(parsed, "inst", {"links": True})

    def test_choice_validated(self):
        doc = template(
            parameters=[
                {
                    "name": "mount",
                    "kind": "choice",
                    "choices": ["floor", "ceiling"],
                    "default": "floor",
                }
            ],
        )
        doc["body"] = {"parts": {"p": {"description": "${mount}"}}}
        parsed = parse(doc)
        fragment = expand_feature(parsed, "inst", {"mount": "ceiling"})
        assert fragment["parts"]["inst_p"]["description"] == "ceiling"
        with pytest.raises(FeatureExpansionError):
            expand_feature(parsed, "inst", {"mount": "wall"})

    def test_instance_name_must_be_identifier(self):
        with pytest.raises(FeatureExpansionError, match="identifier"):
            expand_feature(parse(template()), "bad name")


def repeat_template(**body_overrides) -> FeatureTemplate:
    doc = {
        "anima_feature": "1.0",
        "name": "Chain",
        "parameters": [
            {"name": "links", "kind": "int", "default": 3, "min": 1, "max": 8}
        ],
        "body": {
            "parts": {"link_0": {}},
            "repeat": [
                {
                    "count": "${links}",
                    "var": "i",
                    "body": {
                        "parts": {"link_${i + 1}": {}},
                        "joints": {
                            "pivot_${i + 1}": {
                                "type": "revolute",
                                "parent": "link_${i}",
                                "child": "link_${i + 1}",
                                "dofs": {
                                    "rotation": {
                                        "limits": {
                                            "min_deg": -90,
                                            "max_deg": 90,
                                        },
                                        "neutral_deg": 0,
                                    },
                                },
                            },
                        },
                    },
                },
            ],
            **body_overrides,
        },
    }
    return parse(doc)


class TestRepeatExpansion:
    def test_indexed_copies(self):
        fragment = expand_feature(repeat_template(), "arm", {"links": 2})
        assert set(fragment["parts"]) == {
            "arm_link_0",
            "arm_link_1",
            "arm_link_2",
        }
        assert set(fragment["joints"]) == {"arm_pivot_1", "arm_pivot_2"}
        assert fragment["joints"]["arm_pivot_2"]["parent"] == "arm_link_1"
        assert fragment["joints"]["arm_pivot_2"]["child"] == "arm_link_2"

    def test_zero_count_emits_nothing(self):
        fragment = expand_feature(repeat_template(), "arm", {"links": 1})
        assert set(fragment["joints"]) == {"arm_pivot_1"}

    def test_nested_repeat_with_name_templating(self):
        doc = {
            "anima_feature": "1.0",
            "name": "Grid",
            "body": {
                "repeat": [
                    {
                        "count": 2,
                        "var": "i",
                        "body": {
                            "repeat": [
                                {
                                    "count": 2,
                                    "var": "j",
                                    "body": {
                                        "parts": {
                                            "cell_${i}_${j}": {
                                                "description": (
                                                    "row ${i} col ${j}"
                                                ),
                                            },
                                        },
                                    },
                                },
                            ],
                        },
                    },
                ],
            },
        }
        fragment = expand_feature(parse(doc), "grid")
        assert set(fragment["parts"]) == {
            "grid_cell_0_0",
            "grid_cell_0_1",
            "grid_cell_1_0",
            "grid_cell_1_1",
        }
        assert fragment["parts"]["grid_cell_1_0"]["description"] == (
            "row 1 col 0"
        )

    def test_duplicate_name_after_expansion(self):
        doc = {
            "anima_feature": "1.0",
            "name": "Clash",
            "body": {
                "repeat": [
                    {
                        "count": 2,
                        "var": "i",
                        "body": {"parts": {"same": {}}},
                    },
                ],
            },
        }
        with pytest.raises(FeatureExpansionError, match="duplicate name"):
            expand_feature(parse(doc), "inst")

    def test_negative_count(self):
        doc = {
            "anima_feature": "1.0",
            "name": "Neg",
            "body": {
                "repeat": [
                    {
                        "count": "${0 - 1}",
                        "var": "i",
                        "body": {"parts": {"p_${i}": {}}},
                    },
                ],
            },
        }
        with pytest.raises(FeatureExpansionError, match=">= 0"):
            expand_feature(parse(doc), "inst")

    def test_fractional_count(self):
        doc = {
            "anima_feature": "1.0",
            "name": "Frac",
            "body": {
                "repeat": [
                    {
                        "count": "${3 / 2}",
                        "var": "i",
                        "body": {"parts": {"p_${i}": {}}},
                    },
                ],
            },
        }
        with pytest.raises(FeatureExpansionError, match="integer"):
            expand_feature(parse(doc), "inst")

    def test_expression_error_names_the_site(self):
        doc = template()
        doc["body"]["parts"]["flap"] = {"description": "${ghost * 2}"}
        with pytest.raises(FeatureExpansionError) as excinfo:
            expand_feature(parse(doc), "inst")
        assert "ghost" in str(excinfo.value)
        assert "body.parts" in excinfo.value.path


class TestPrefixingAndParent:
    def test_all_names_are_prefixed(self):
        doc = template()
        doc["body"]["parameters"] = {"glow": {"default": 0.5}}
        doc["body"]["relations"] = []
        fragment = expand_feature(parse(doc), "wing")
        assert set(fragment["parts"]) == {"wing_base", "wing_flap"}
        assert set(fragment["joints"]) == {"wing_hinge"}
        assert set(fragment["parameters"]) == {"wing_glow"}
        joint = fragment["joints"]["wing_hinge"]
        assert joint["parent"] == "wing_base"
        assert joint["child"] == "wing_flap"

    def test_parent_sentinel_attaches_to_existing_part(self):
        fragment = expand_feature(
            parse(template()), "wing", parent_part="chassis"
        )
        assert fragment["parts"]["wing_base"]["parent"] == "chassis"

    def test_parent_sentinel_defaults_to_root(self):
        fragment = expand_feature(parse(template()), "wing")
        assert "parent" not in fragment["parts"]["wing_base"]

    def test_parent_sentinel_in_joint_requires_attachment(self):
        doc = template()
        doc["body"]["joints"]["hinge"]["parent"] = "$parent"
        parsed = parse(doc)
        fragment = expand_feature(parsed, "wing", parent_part="chassis")
        assert fragment["joints"]["wing_hinge"]["parent"] == "chassis"
        with pytest.raises(FeatureExpansionError, match="parent_part"):
            expand_feature(parsed, "wing")

    def test_undeclared_reference_is_an_error(self):
        doc = template()
        doc["body"]["joints"]["hinge"]["child"] = "elsewhere"
        with pytest.raises(FeatureExpansionError, match="elsewhere"):
            expand_feature(parse(doc), "wing")

    def test_relation_dof_paths_are_prefixed(self):
        doc = template()
        doc["body"]["parts"]["mirror"] = {}
        doc["body"]["joints"]["mirror_hinge"] = {
            "type": "revolute",
            "parent": "base",
            "child": "mirror",
            "dofs": {
                "rotation": {
                    "limits": {"min_deg": -45, "max_deg": 45},
                    "neutral_deg": 0,
                },
            },
        }
        doc["body"]["relations"] = [
            {
                "kind": "gear",
                "driver": "hinge.rotation",
                "driven": "mirror_hinge.rotation",
                "ratio": -1.0,
            },
        ]
        fragment = expand_feature(parse(doc), "wing")
        relation = fragment["relations"][0]
        assert relation["driver"] == "wing_hinge.rotation"
        assert relation["driven"] == "wing_mirror_hinge.rotation"

    def test_relation_to_undeclared_joint_is_an_error(self):
        doc = template()
        doc["body"]["relations"] = [
            {
                "kind": "gear",
                "driver": "ghost.rotation",
                "driven": "hinge.rotation",
                "ratio": 2.0,
            },
        ]
        with pytest.raises(FeatureExpansionError, match="ghost"):
            expand_feature(parse(doc), "wing")

    def test_two_instances_coexist(self):
        parsed = parse(template())
        character = merge_fragment(
            merge_fragment(
                BASE_CHARACTER,
                expand_feature(parsed, "left", parent_part="chassis"),
            ),
            expand_feature(parsed, "right", parent_part="chassis"),
        )
        rig = parse_merged(character)
        assert {"left_base", "left_flap", "right_base", "right_flap"} <= set(
            rig.parts
        )
        assert {"left_hinge.rotation", "right_hinge.rotation"} <= set(
            rig.dof_paths()
        )


class TestMergeFragment:
    def test_inputs_are_not_mutated(self):
        character = copy.deepcopy(BASE_CHARACTER)
        fragment = expand_feature(parse(template()), "wing")
        merge_fragment(character, fragment)
        assert character == BASE_CHARACTER

    def test_collision_with_existing_name(self):
        fragment = expand_feature(parse(template()), "chassis_less_one")
        character = copy.deepcopy(BASE_CHARACTER)
        character["parts"]["chassis_less_one_base"] = None
        with pytest.raises(FeatureExpansionError, match="already exists"):
            merge_fragment(character, fragment)

    def test_unknown_fragment_section(self):
        with pytest.raises(FeatureExpansionError, match="fragment"):
            merge_fragment(BASE_CHARACTER, {"outputs": []})

    def test_merged_document_passes_the_loader(self):
        fragment = expand_feature(
            parse(template()), "wing", parent_part="chassis"
        )
        rig = parse_merged(merge_fragment(BASE_CHARACTER, fragment))
        assert rig.parts["wing_base"].parent == "chassis"
        dof = rig.dof_paths()["wing_hinge.rotation"]
        assert dof.min_radians == pytest.approx(math.radians(-45))

    def test_loader_stays_the_gatekeeper(self):
        # A body emitting a loader-invalid joint expands fine but the
        # merged document is rejected by the real loader.
        doc = template()
        doc["body"]["joints"]["hinge"]["type"] = "helical"
        fragment = expand_feature(parse(doc), "wing")
        with pytest.raises(Exception, match="helical"):
            parse_merged(merge_fragment(BASE_CHARACTER, fragment))


class TestManifestIntegration:
    def test_feature_entry_must_be_yaml(self):
        doc = {
            "anima_extension": "1.0",
            "id": "feat",
            "name": "Feat",
            "version": "0.1.0",
            "provides": [
                {
                    "kind": "parametric_feature",
                    "id": "gripper",
                    "entry": "gripper.py:Gripper",
                }
            ],
        }
        with pytest.raises(ExtensionManifestError) as excinfo:
            parse_manifest(yaml.safe_dump(doc))
        assert "provides[0].entry" in excinfo.value.path

    def test_feature_takes_no_config(self):
        doc = {
            "anima_extension": "1.0",
            "id": "feat",
            "name": "Feat",
            "version": "0.1.0",
            "provides": [
                {
                    "kind": "parametric_feature",
                    "id": "gripper",
                    "entry": "gripper.yaml",
                    "config": {"links": 3},
                }
            ],
        }
        with pytest.raises(ExtensionManifestError) as excinfo:
            parse_manifest(yaml.safe_dump(doc))
        assert "provides[0].config" in excinfo.value.path


class TestParametricLinkageExample:
    """The packaged example bundle, end to end through the real stack."""

    def registry(self):
        return discover_extensions([EXTENSIONS_DIR])

    def test_bundle_discovers_with_no_capabilities(self):
        extension = self.registry().extensions["parametric-linkage"]
        assert extension.manifest.capabilities == ()
        pairs = self.registry().contributions(
            ContributionKind.PARAMETRIC_FEATURE
        )
        assert [contribution.id for _, contribution in pairs] == [
            "serial_linkage"
        ]

    def test_template_loads_with_form_metadata(self):
        loaded = self.registry().load_parametric_feature("serial_linkage")
        assert isinstance(loaded, FeatureTemplate)
        links = loaded.parameter("links")
        assert links.kind is ParameterKind.INT
        assert (links.minimum, links.maximum) == (2, 8)
        limit = loaded.parameter("joint_limit_deg")
        assert limit.unit is FloatUnit.DEG
        slider = loaded.parameter("end_slider")
        assert slider.kind is ParameterKind.BOOL
        orientation = loaded.parameter("slider_orientation")
        assert orientation.choices == ("lengthwise", "crosswise")

    def test_end_to_end_expand_merge_load_evaluate_project(self):
        loaded = self.registry().load_parametric_feature("serial_linkage")
        fragment = expand_feature(
            loaded,
            "arm",
            {"links": 2, "joint_limit_deg": 90, "end_slider": True},
            parent_part="chassis",
        )
        character = merge_fragment(BASE_CHARACTER, fragment)
        character["outputs"] = [
            {
                "target": "arm_pivot_1.rotation",
                "channel": 0,
                "range_deg": [-90, 90],
            },
            {
                "target": "arm_end_slide.travel",
                "channel": 1,
                "range_m": [0, 0.05],
            },
        ]
        rig = parse_merged(character)
        assert rig.parts["arm_link_0"].parent == "chassis"
        assert set(rig.joints) == {
            "arm_pivot_1",
            "arm_pivot_2",
            "arm_end_slide",
        }
        assert rig.joints["arm_end_slide"].parent_part == "arm_link_2"
        dof = rig.dof_paths()["arm_end_slide.travel"]
        assert dof.description == "End slider, lengthwise"

        pose = evaluate_pose(rig)
        assert pose.limit_violations == ()
        channels = project_channels(rig, pose)
        assert channels == {0: 0.5, 1: 0.0}

    def test_slider_omitted_by_default(self):
        loaded = self.registry().load_parametric_feature("serial_linkage")
        fragment = expand_feature(loaded, "arm", {"links": 2})
        assert "arm_end_slide" not in fragment["joints"]
        assert "arm_end_effector" not in fragment["parts"]
