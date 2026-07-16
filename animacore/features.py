"""Parametric feature templates: declarative rig fragments (E2).

Implements the ``parametric_feature`` extension point of
``dev/docs/roadmap/Extensions.md`` — a "custom feature" in the Onshape
sense. A feature is **pure data**: one YAML template file inside an
``.animaext`` bundle (no Python — that is its safety property). The
template declares typed parameters (a form the Studio UI can render)
and a ``body`` of parts/joints/relations/rig-parameters in the exact
shapes ``animacore.loader`` accepts, plus two template-only
constructs:

- ``${expr}`` substitution inside scalar values and mapping keys — a
  tiny safe arithmetic evaluator over numbers, parameter names, and
  loop variables (never Python ``eval``).
- ``repeat:`` blocks producing indexed copies of a body fragment, which
  is what makes an N-link arm a single feature.

``expand_feature`` turns a template plus concrete parameter values
into a character-format-shaped fragment, prefixing every declared name
with ``<instance_name>_`` so two instances coexist; ``merge_fragment``
inserts that fragment into a loaded character mapping. Expansion never
bypasses loader validation: features emit standard primitives, never
new kernel types, and the merged document is re-parsed by
``animacore.loader`` — the loader stays the single gatekeeper.
"""

from __future__ import annotations

import copy
import re
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

import yaml

SUPPORTED_TEMPLATE_VERSION = "1.0"

# A body part's parent (or a joint's parent/child) may name this
# sentinel to attach to an existing rig part chosen at insertion time.
PARENT_SENTINEL = "$parent"

# The character-format sections a feature body may emit, in the exact
# shapes animacore.loader accepts.
_BODY_SECTIONS = ("parts", "joints", "relations", "parameters")
_MAPPING_SECTIONS = ("parts", "joints", "parameters")

_EXPRESSION_PATTERN = re.compile(r"\$\{([^{}]*)\}")


class FeatureError(ValueError):
    """Base for every parametric-feature template/expansion failure."""


class FeatureTemplateError(FeatureError):
    """A template that cannot be parsed; ``path`` names the field."""

    def __init__(self, path: str, message: str):
        super().__init__(f"{path}: {message}")
        self.path = path
        self.message = message


class FeatureExpansionError(FeatureError):
    """Expanding a template with concrete values failed; ``path`` names
    the offending field or expression site."""

    def __init__(self, path: str, message: str):
        super().__init__(f"{path}: {message}")
        self.path = path
        self.message = message


class ParameterKind(StrEnum):
    """The declared type of one feature parameter."""

    FLOAT = "float"
    INT = "int"
    BOOL = "bool"
    CHOICE = "choice"


class FloatUnit(StrEnum):
    """Explicit-unit hint for float parameters (display only).

    The unit labels the form field; values substitute into the body
    verbatim, so a template wanting a different body unit converts in
    an expression (e.g. ``${length_mm / 1000}`` for a meters field).
    """

    DEG = "deg"
    M = "m"
    MM = "mm"
    RATIO = "ratio"
    COUNT = "count"


@dataclass(frozen=True)
class FeatureParameter:
    """One declared template parameter — one row of the insertion form."""

    name: str
    kind: ParameterKind
    default: float | int | bool | str
    unit: FloatUnit | None = None
    minimum: float | None = None
    maximum: float | None = None
    choices: tuple[str, ...] = ()
    description: str = ""


@dataclass(frozen=True)
class FeatureTemplate:
    """A parsed, validated ``anima_feature`` template."""

    name: str
    description: str
    parameters: tuple[FeatureParameter, ...]
    body: Mapping[str, object]

    def parameter(self, name: str) -> FeatureParameter:
        """Look up one declared parameter by name."""
        for parameter in self.parameters:
            if parameter.name == name:
                return parameter
        raise KeyError(f"template has no parameter named {name!r}")


# Template parsing -------------------------------------------------------------


def load_feature_template(file_path: str | Path) -> FeatureTemplate:
    """Read and parse one feature template YAML file."""
    return parse_feature_template(Path(file_path).read_text(encoding="utf-8"))


def parse_feature_template(text: str) -> FeatureTemplate:
    """Parse feature-template YAML text into a validated template."""
    try:
        document = yaml.safe_load(text)
    except yaml.YAMLError as error:
        raise FeatureTemplateError(
            "<document>", f"not valid YAML: {error}"
        ) from error
    document = _mapping(document, "<document>")

    supported = {"anima_feature", "name", "description", "parameters", "body"}
    for key in document:
        if key not in supported:
            raise FeatureTemplateError(str(key), "unknown field")

    schema_version = document.get("anima_feature")
    if schema_version is None:
        raise FeatureTemplateError("anima_feature", "missing required field")
    if schema_version != SUPPORTED_TEMPLATE_VERSION:
        raise FeatureTemplateError(
            "anima_feature",
            f"unsupported template version {schema_version!r} "
            f"(expected {SUPPORTED_TEMPLATE_VERSION!r})",
        )
    if "name" not in document:
        raise FeatureTemplateError("name", "missing required field")
    name = _non_empty_string(document["name"], "name")
    description = _string(document.get("description", ""), "description")

    parameters = _parse_parameters(document.get("parameters"))
    if "body" not in document:
        raise FeatureTemplateError("body", "missing required section")
    body = _mapping(document["body"], "body")
    reserved = {parameter.name for parameter in parameters}
    _validate_body(body, "body", reserved)

    return FeatureTemplate(
        name=name,
        description=description,
        parameters=parameters,
        body=body,
    )


def _parse_parameters(raw: object) -> tuple[FeatureParameter, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        raise FeatureTemplateError(
            "parameters",
            f"expected a list of parameter declarations, "
            f"got {type(raw).__name__}",
        )
    parameters: list[FeatureParameter] = []
    seen: set[str] = set()
    for index, item in enumerate(raw):
        path = f"parameters[{index}]"
        parameter = _parse_parameter(item, path)
        if parameter.name in seen:
            raise FeatureTemplateError(
                f"{path}.name", f"duplicate parameter name {parameter.name!r}"
            )
        seen.add(parameter.name)
        parameters.append(parameter)
    return tuple(parameters)


def _parse_parameter(raw: object, path: str) -> FeatureParameter:
    entry = _mapping(raw, path)
    _reject_unknown_fields(
        entry,
        path,
        {"name", "kind", "unit", "default", "min", "max", "choices",
         "description"},
    )
    for required in ("name", "kind", "default"):
        if required not in entry:
            raise FeatureTemplateError(
                f"{path}.{required}", "missing required field"
            )
    name = _identifier(entry["name"], f"{path}.name")
    try:
        kind = ParameterKind(entry["kind"])
    except ValueError:
        valid = ", ".join(sorted(k.value for k in ParameterKind))
        raise FeatureTemplateError(
            f"{path}.kind",
            f"unknown parameter kind {entry['kind']!r} "
            f"(expected one of: {valid})",
        ) from None
    description = _string(entry.get("description", ""), f"{path}.description")

    numeric = kind in (ParameterKind.FLOAT, ParameterKind.INT)
    for forbidden, kinds in (
        ("unit", (ParameterKind.FLOAT,)),
        ("min", (ParameterKind.FLOAT, ParameterKind.INT)),
        ("max", (ParameterKind.FLOAT, ParameterKind.INT)),
        ("choices", (ParameterKind.CHOICE,)),
    ):
        if forbidden in entry and kind not in kinds:
            raise FeatureTemplateError(
                f"{path}.{forbidden}",
                f"not allowed for kind {kind.value!r}",
            )

    unit: FloatUnit | None = None
    if kind is ParameterKind.FLOAT:
        if "unit" not in entry:
            raise FeatureTemplateError(
                f"{path}.unit",
                "float parameters require an explicit unit "
                f"({', '.join(u.value for u in FloatUnit)})",
            )
        try:
            unit = FloatUnit(entry["unit"])
        except ValueError:
            valid = ", ".join(u.value for u in FloatUnit)
            raise FeatureTemplateError(
                f"{path}.unit",
                f"unknown unit {entry['unit']!r} (expected one of: {valid})",
            ) from None

    minimum: float | None = None
    maximum: float | None = None
    if numeric:
        check = _int if kind is ParameterKind.INT else _number
        if "min" in entry:
            minimum = check(entry["min"], f"{path}.min")
        if "max" in entry:
            maximum = check(entry["max"], f"{path}.max")
        if minimum is not None and maximum is not None and minimum >= maximum:
            raise FeatureTemplateError(
                f"{path}.min",
                f"range must be ascending: [{minimum}, {maximum}]",
            )

    choices: tuple[str, ...] = ()
    if kind is ParameterKind.CHOICE:
        raw_choices = entry.get("choices")
        if not isinstance(raw_choices, list) or not raw_choices:
            raise FeatureTemplateError(
                f"{path}.choices",
                "choice parameters require a non-empty list of choices",
            )
        seen: set[str] = set()
        collected: list[str] = []
        for index, choice in enumerate(raw_choices):
            choice = _non_empty_string(choice, f"{path}.choices[{index}]")
            if choice in seen:
                raise FeatureTemplateError(
                    f"{path}.choices[{index}]",
                    f"duplicate choice {choice!r}",
                )
            seen.add(choice)
            collected.append(choice)
        choices = tuple(collected)

    default = _checked_parameter_value(
        entry["default"],
        kind,
        minimum,
        maximum,
        choices,
        f"{path}.default",
        FeatureTemplateError,
    )
    return FeatureParameter(
        name=name,
        kind=kind,
        default=default,
        unit=unit,
        minimum=minimum,
        maximum=maximum,
        choices=choices,
        description=description,
    )


def _checked_parameter_value(
    value: object,
    kind: ParameterKind,
    minimum: float | None,
    maximum: float | None,
    choices: tuple[str, ...],
    path: str,
    error: type[FeatureTemplateError] | type[FeatureExpansionError],
) -> float | int | bool | str:
    """Validate one concrete value (default or supplied) against a kind."""
    if kind is ParameterKind.BOOL:
        if not isinstance(value, bool):
            raise error(path, f"expected true/false, got {value!r}")
        return value
    if kind is ParameterKind.CHOICE:
        if not isinstance(value, str):
            raise error(path, f"expected a string choice, got {value!r}")
        if value not in choices:
            raise error(
                path,
                f"{value!r} is not one of the choices "
                f"({', '.join(choices)})",
            )
        return value
    if kind is ParameterKind.INT:
        if isinstance(value, bool) or not isinstance(value, int):
            raise error(path, f"expected an integer, got {value!r}")
        checked: float | int = value
    else:  # FLOAT accepts int or float
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise error(path, f"expected a number, got {value!r}")
        checked = float(value)
    if minimum is not None and checked < minimum:
        raise error(path, f"{checked} below the minimum {minimum}")
    if maximum is not None and checked > maximum:
        raise error(path, f"{checked} above the maximum {maximum}")
    return checked


def _validate_body(raw: dict, path: str, reserved: set[str]) -> None:
    """Structurally validate a body (or repeat body) fragment.

    Section *contents* are deliberately not deep-validated here: they
    are character-format shapes, and the loader validates the merged
    document after expansion (composition rule — one gatekeeper).
    Template-only constructs (``repeat`` blocks, loop-variable naming)
    are fully validated. ``reserved`` carries parameter names plus
    outer loop variables so a ``var`` can never shadow one.
    """
    allowed = set(_BODY_SECTIONS) | {"repeat"}
    for key in raw:
        if key not in allowed:
            raise FeatureTemplateError(f"{path}.{key}", "unknown field")
    if not raw:
        raise FeatureTemplateError(path, "empty body")
    for section in _MAPPING_SECTIONS:
        if section in raw:
            _mapping(raw[section], f"{path}.{section}")
    if "relations" in raw and not isinstance(raw["relations"], list):
        raise FeatureTemplateError(
            f"{path}.relations",
            f"expected a list, got {type(raw['relations']).__name__}",
        )
    repeats = raw.get("repeat")
    if repeats is None:
        return
    if not isinstance(repeats, list):
        raise FeatureTemplateError(
            f"{path}.repeat",
            f"expected a list of repeat blocks, got {type(repeats).__name__}",
        )
    for index, block in enumerate(repeats):
        block_path = f"{path}.repeat[{index}]"
        block = _mapping(block, block_path)
        _reject_unknown_fields(block, block_path, {"count", "var", "body"})
        for required in ("count", "var", "body"):
            if required not in block:
                raise FeatureTemplateError(
                    f"{block_path}.{required}", "missing required field"
                )
        count = block["count"]
        if isinstance(count, bool) or not isinstance(count, (int, str)):
            raise FeatureTemplateError(
                f"{block_path}.count",
                f"expected an integer or a ${{...}} expression, got {count!r}",
            )
        var = _identifier(block["var"], f"{block_path}.var")
        if var in reserved:
            raise FeatureTemplateError(
                f"{block_path}.var",
                f"{var!r} shadows a parameter or an outer loop variable",
            )
        _validate_body(
            _mapping(block["body"], f"{block_path}.body"),
            f"{block_path}.body",
            reserved | {var},
        )


# Expression evaluation ---------------------------------------------------------

# ponytail: the v1 expression grammar tops out at numbers, names,
# + - * /, unary minus, and parentheses — no functions, comparisons, or
# conditionals. Upgrade path: extend this recursive-descent parser with
# a whitelisted function table; never reach for Python eval().

_TOKEN_PATTERN = re.compile(
    r"\s*(?:(?P<number>\d+\.\d+|\.\d+|\d+)"
    r"|(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"|(?P<op>[()+\-*/])"
    r"|(?P<bad>\S))"
)

Scalar = float | int | bool | str


def evaluate_expression(text: str, scope: Mapping[str, Scalar]) -> Scalar:
    """Safely evaluate one ``${...}`` expression body against a scope.

    Numbers, scope names (parameters and loop variables), ``+ - * /``,
    unary minus, and parentheses. Booleans coerce to 1/0 in arithmetic;
    a string (choice) value is only legal as the entire expression.
    Unknown names, division by zero, and syntax errors raise
    ``ValueError`` (callers wrap it with the template path).
    """
    tokens: list[tuple[str, str]] = []
    for match in _TOKEN_PATTERN.finditer(text):
        group = match.lastgroup
        if group == "bad":
            raise ValueError(f"unexpected character {match.group().strip()!r}")
        if group is not None:
            tokens.append((group, match.group().strip()))
    if not tokens:
        raise ValueError("empty expression")
    parser = _ExpressionParser(tokens, scope)
    value = parser.parse_expression()
    if parser.position != len(tokens):
        kind, token = tokens[parser.position]
        raise ValueError(f"unexpected {token!r}")
    return value


class _ExpressionParser:
    """Recursive-descent parser over the tokenized expression."""

    def __init__(
        self, tokens: Sequence[tuple[str, str]], scope: Mapping[str, Scalar]
    ):
        self.tokens = tokens
        self.scope = scope
        self.position = 0

    def _peek(self) -> str | None:
        if self.position < len(self.tokens):
            return self.tokens[self.position][1]
        return None

    def parse_expression(self) -> Scalar:
        value = self.parse_term()
        while self._peek() in ("+", "-"):
            operator = self.tokens[self.position][1]
            self.position += 1
            right = self.parse_term()
            left, right = _numeric(value), _numeric(right)
            value = left + right if operator == "+" else left - right
        return value

    def parse_term(self) -> Scalar:
        value = self.parse_factor()
        while self._peek() in ("*", "/"):
            operator = self.tokens[self.position][1]
            self.position += 1
            right = self.parse_factor()
            left, right = _numeric(value), _numeric(right)
            if operator == "*":
                value = left * right
            else:
                if right == 0:
                    raise ValueError("division by zero")
                value = left / right
        return value

    def parse_factor(self) -> Scalar:
        if self.position >= len(self.tokens):
            raise ValueError("unexpected end of expression")
        kind, token = self.tokens[self.position]
        if token == "-" or token == "+":
            self.position += 1
            value = _numeric(self.parse_factor())
            return -value if token == "-" else value
        if token == "(":
            self.position += 1
            value = self.parse_expression()
            if self._peek() != ")":
                raise ValueError("missing closing parenthesis")
            self.position += 1
            return value
        self.position += 1
        if kind == "number":
            return float(token) if "." in token else int(token)
        if kind == "name":
            if token not in self.scope:
                raise ValueError(f"unknown name {token!r}")
            return self.scope[token]
        raise ValueError(f"unexpected {token!r}")


def _numeric(value: Scalar) -> float | int:
    """Coerce an operand for arithmetic; strings never participate."""
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return value
    raise ValueError(
        f"string value {value!r} cannot be used in arithmetic "
        f"(a choice parameter is only legal as the whole expression)"
    )


# Substitution -------------------------------------------------------------------


def _substitute(value: object, scope: Mapping[str, Scalar], path: str):
    if isinstance(value, str):
        return _substitute_string(value, scope, path)
    if isinstance(value, dict):
        result: dict = {}
        for key, item in value.items():
            new_key = key
            if isinstance(key, str):
                substituted = _substitute_string(key, scope, f"{path}.{key}")
                new_key = (
                    substituted
                    if isinstance(substituted, str)
                    else _format_scalar(substituted)
                )
            if new_key in result:
                raise FeatureExpansionError(
                    f"{path}.{key}",
                    f"duplicate name {new_key!r} after substitution",
                )
            result[new_key] = _substitute(item, scope, f"{path}.{key}")
        return result
    if isinstance(value, list):
        return [
            _substitute(item, scope, f"{path}[{index}]")
            for index, item in enumerate(value)
        ]
    return value


def _substitute_string(
    text: str, scope: Mapping[str, Scalar], path: str
) -> Scalar:
    whole = _EXPRESSION_PATTERN.fullmatch(text)
    if whole is not None:
        # The scalar IS one expression: keep the evaluated value's type
        # (a number stays a number, a bool a bool, a choice a string).
        return _evaluate_at(whole.group(1), scope, path)

    def replace(match: re.Match) -> str:
        return _format_scalar(_evaluate_at(match.group(1), scope, path))

    return _EXPRESSION_PATTERN.sub(replace, text)


def _evaluate_at(
    expression: str, scope: Mapping[str, Scalar], path: str
) -> Scalar:
    try:
        return evaluate_expression(expression, scope)
    except FeatureError:
        raise
    except ValueError as error:
        raise FeatureExpansionError(
            path, f"in ${{{expression}}}: {error}"
        ) from error


def _format_scalar(value: Scalar) -> str:
    """Render an evaluated value for embedding inside a longer string."""
    if isinstance(value, bool):
        return str(int(value))
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


# Expansion ----------------------------------------------------------------------


def expand_feature(
    template: FeatureTemplate,
    instance_name: str,
    parameter_values: Mapping[str, object] | None = None,
    parent_part: str | None = None,
) -> dict:
    """Expand a template into a character-format-shaped fragment.

    ``parameter_values`` are validated against the declared parameters
    (unknown names, wrong kinds, and out-of-range values are typed
    errors); unsupplied parameters take their defaults. Every declared
    part/joint/relation/rig-parameter name is prefixed
    ``<instance_name>_`` so two instances coexist, and references
    inside the body are rewritten to match. A part parent (or joint
    parent/child) of ``$parent`` attaches to ``parent_part``; with no
    ``parent_part`` a ``$parent`` part becomes an unattached root part
    and a ``$parent`` joint reference is an error.

    The result is a plain mapping in loader shapes — merge it with
    ``merge_fragment`` and re-parse through ``animacore.loader``;
    expansion never bypasses loader validation.
    """
    if not isinstance(instance_name, str) or not instance_name.isidentifier():
        raise FeatureExpansionError(
            "<instance_name>",
            f"must be an identifier, got {instance_name!r}",
        )
    if parent_part is not None and (
        not isinstance(parent_part, str) or not parent_part
    ):
        raise FeatureExpansionError(
            "<parent_part>", f"must be a part name, got {parent_part!r}"
        )
    scope = _resolve_parameter_values(template, parameter_values or {})
    expanded = _expand_body(template.body, scope, "body")
    return _prefix_fragment(expanded, instance_name, parent_part)


def _resolve_parameter_values(
    template: FeatureTemplate, supplied: Mapping[str, object]
) -> dict[str, Scalar]:
    declared = {parameter.name: parameter for parameter in template.parameters}
    for name in supplied:
        if name not in declared:
            raise FeatureExpansionError(
                f"parameter_values.{name}",
                f"unknown parameter (declared: "
                f"{', '.join(declared) or 'none'})",
            )
    values: dict[str, Scalar] = {}
    for name, parameter in declared.items():
        if name in supplied:
            values[name] = _checked_parameter_value(
                supplied[name],
                parameter.kind,
                parameter.minimum,
                parameter.maximum,
                parameter.choices,
                f"parameter_values.{name}",
                FeatureExpansionError,
            )
        else:
            values[name] = parameter.default
    return values


def _expand_body(
    body: Mapping[str, object], scope: Mapping[str, Scalar], path: str
) -> dict:
    """Substitute expressions and unroll ``repeat`` blocks, recursively."""
    result: dict = {
        "parts": {},
        "joints": {},
        "parameters": {},
        "relations": [],
    }
    for section in _MAPPING_SECTIONS:
        raw = body.get(section)
        if raw:
            substituted = _substitute(raw, scope, f"{path}.{section}")
            _merge_expanded(result, {section: substituted}, path)
    raw_relations = body.get("relations")
    if raw_relations:
        result["relations"].extend(
            _substitute(raw_relations, scope, f"{path}.relations")
        )
    for index, block in enumerate(body.get("repeat") or ()):
        block_path = f"{path}.repeat[{index}]"
        count = _evaluate_count(block["count"], scope, f"{block_path}.count")
        var = block["var"]
        for iteration in range(count):
            inner = _expand_body(
                block["body"],
                {**scope, var: iteration},
                f"{block_path}.body",
            )
            _merge_expanded(result, inner, block_path)
            result["relations"].extend(inner["relations"])
    return result


def _merge_expanded(result: dict, fragment: Mapping[str, object], path: str):
    for section in _MAPPING_SECTIONS:
        entries = fragment.get(section)
        if not entries:
            continue
        target = result[section]
        for name, entry in entries.items():
            if name in target:
                raise FeatureExpansionError(
                    f"{path}.{section}.{name}",
                    "duplicate name after expansion (template a repeated "
                    "name with the loop variable, e.g. \"link_${i}\")",
                )
            target[name] = entry


def _evaluate_count(
    raw: object, scope: Mapping[str, Scalar], path: str
) -> int:
    if isinstance(raw, str):
        match = _EXPRESSION_PATTERN.fullmatch(raw)
        if match is None:
            raise FeatureExpansionError(
                path, f"expected an integer or ${{...}} expression, got {raw!r}"
            )
        value = _evaluate_at(match.group(1), scope, path)
    else:
        value = raw
    if isinstance(value, bool):
        value = int(value)  # a bool parameter makes an optional block
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    if not isinstance(value, int):
        raise FeatureExpansionError(
            path, f"count must evaluate to an integer, got {value!r}"
        )
    if value < 0:
        raise FeatureExpansionError(path, f"count must be >= 0: {value}")
    return value


def _prefix_fragment(
    expanded: dict, instance_name: str, parent_part: str | None
) -> dict:
    prefix = f"{instance_name}_"
    declared_parts = set(expanded["parts"])
    declared_joints = set(expanded["joints"])

    def attach(reference: str, path: str, joint_role: bool) -> str | None:
        """Rewrite one part reference; ``None`` drops the key (root)."""
        if reference == PARENT_SENTINEL:
            if parent_part is not None:
                return parent_part
            if joint_role:
                raise FeatureExpansionError(
                    path,
                    "$parent in a joint needs the instance attached to an "
                    "existing rig part (pass parent_part)",
                )
            return None
        if reference in declared_parts:
            return prefix + reference
        raise FeatureExpansionError(
            path,
            f"{reference!r} references neither a body part nor "
            f"{PARENT_SENTINEL!r}",
        )

    parts: dict = {}
    for name, entry in expanded["parts"].items():
        path = f"parts.{name}"
        if isinstance(entry, dict) and isinstance(entry.get("parent"), str):
            entry = dict(entry)
            parent = attach(entry["parent"], f"{path}.parent", False)
            if parent is None:
                del entry["parent"]
            else:
                entry["parent"] = parent
        parts[prefix + str(name)] = entry

    joints: dict = {}
    for name, entry in expanded["joints"].items():
        path = f"joints.{name}"
        if isinstance(entry, dict):
            entry = dict(entry)
            for role in ("parent", "child"):
                if isinstance(entry.get(role), str):
                    entry[role] = attach(
                        entry[role], f"{path}.{role}", True
                    )
        joints[prefix + str(name)] = entry

    relations: list = []
    for index, entry in enumerate(expanded["relations"]):
        path = f"relations[{index}]"
        if isinstance(entry, dict):
            entry = dict(entry)
            for role in ("driver", "driven"):
                reference = entry.get(role)
                if isinstance(reference, str) and "." in reference:
                    joint, _, dof = reference.partition(".")
                    if joint not in declared_joints:
                        raise FeatureExpansionError(
                            f"{path}.{role}",
                            f"{reference!r} does not reference a body joint",
                        )
                    entry[role] = f"{prefix}{joint}.{dof}"
        relations.append(entry)

    parameters = {
        prefix + str(name): entry
        for name, entry in expanded["parameters"].items()
    }

    fragment = {
        "parts": parts,
        "joints": joints,
        "relations": relations,
        "parameters": parameters,
    }
    return {key: value for key, value in fragment.items() if value}


# Merging ------------------------------------------------------------------------


def merge_fragment(character: Mapping[str, object], fragment: dict) -> dict:
    """Insert an expanded fragment into a loaded character mapping.

    Returns a new mapping (inputs are not mutated). Name collisions
    with the existing character are typed errors. The result must be
    re-validated by the standard loader
    (``loader.parse_character(yaml.safe_dump(merged))``) — merging
    performs no character-format validation of its own.
    """
    if not isinstance(character, Mapping):
        raise FeatureExpansionError(
            "<character>",
            f"expected a character mapping, got {type(character).__name__}",
        )
    for key in fragment:
        if key not in _BODY_SECTIONS:
            raise FeatureExpansionError(
                f"<fragment>.{key}", "unknown fragment section"
            )
    merged = copy.deepcopy(dict(character))
    for section in _MAPPING_SECTIONS:
        entries = fragment.get(section)
        if not entries:
            continue
        existing = merged.setdefault(section, {})
        if not isinstance(existing, dict):
            raise FeatureExpansionError(
                section,
                f"character section is not a mapping "
                f"({type(existing).__name__})",
            )
        for name, entry in entries.items():
            if name in existing:
                raise FeatureExpansionError(
                    f"{section}.{name}",
                    "already exists in the character "
                    "(is the instance name unique?)",
                )
            existing[name] = copy.deepcopy(entry)
    relations = fragment.get("relations")
    if relations:
        existing = merged.setdefault("relations", [])
        if not isinstance(existing, list):
            raise FeatureExpansionError(
                "relations",
                f"character section is not a list "
                f"({type(existing).__name__})",
            )
        existing.extend(copy.deepcopy(relations))
    return merged


# Primitive validators ------------------------------------------------------------


def _mapping(value: object, path: str) -> dict:
    if not isinstance(value, dict):
        raise FeatureTemplateError(
            path, f"expected a mapping, got {type(value).__name__}"
        )
    return value


def _string(value: object, path: str) -> str:
    if not isinstance(value, str):
        raise FeatureTemplateError(path, f"expected a string, got {value!r}")
    return value


def _non_empty_string(value: object, path: str) -> str:
    string = _string(value, path)
    if not string:
        raise FeatureTemplateError(path, "must not be empty")
    return string


def _identifier(value: object, path: str) -> str:
    string = _non_empty_string(value, path)
    if not string.isidentifier():
        raise FeatureTemplateError(
            path, f"must be an identifier, got {string!r}"
        )
    return string


def _number(value: object, path: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise FeatureTemplateError(path, f"expected a number, got {value!r}")
    return float(value)


def _int(value: object, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise FeatureTemplateError(path, f"expected an integer, got {value!r}")
    return value


def _reject_unknown_fields(raw: dict, path: str, allowed: set[str]) -> None:
    for key in raw:
        if key not in allowed:
            raise FeatureTemplateError(f"{path}.{key}", "unknown field")
