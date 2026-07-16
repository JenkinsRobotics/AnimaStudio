"""``.animaext`` extension bundles: manifest, discovery, loading.

Implements the community-extension packet E1 of
``dev/docs/roadmap/Extensions.md``. An extension is one directory named
``<slug>.animaext/`` whose single ``extension.yaml`` manifest describes
everything it contributes. The manifest is closed-schema — unknown
fields are rejected with a typed ``ExtensionManifestError`` naming the
offending path, the same loader discipline as ``anima_core.loader``.

``discover_extensions`` scans caller-supplied directories for bundles
and returns an ``ExtensionRegistry``; duplicate extension ids (and
duplicate per-kind contribution ids) are loud load errors. Two kinds
are loadable: ``output_adapter`` (E1) contributions name an
``entry: "<module>.py:<ClassName>"`` module that is imported from
inside the bundle under an extension-id-namespaced module name (no
``sys.path`` pollution) and whose class must implement the
``anima_core.outputs.OutputAdapter`` protocol; ``parametric_feature``
(E2) contributions name a pure-data YAML template file inside the
bundle, parsed and validated by ``anima_core.features`` — no Python
ever runs for a feature. The other known kinds (``scene_action``,
``motor_backend``) parse but raise "not yet supported" when loaded;
unknown kinds are manifest errors.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from enum import StrEnum
from pathlib import Path

import yaml

from anima_core.features import (
    FeatureTemplate,
    FeatureTemplateError,
    load_feature_template,
)
from anima_core.outputs import OutputAdapter

SUPPORTED_MANIFEST_VERSION = "1.0"

MANIFEST_FILENAME = "extension.yaml"
BUNDLE_SUFFIX = ".animaext"

# Extension and contribution ids: lowercase slugs, usable in file and
# module names (hyphens are normalized to underscores for the latter).
_SLUG_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]*$")


class Capability(StrEnum):
    """Declared access, surfaced to the user at install time."""

    HARDWARE = "hardware"
    NETWORK = "network"
    FILESYSTEM = "filesystem"


class ContributionKind(StrEnum):
    """The known extension points (Extensions.md table).

    ``OUTPUT_ADAPTER`` (E1) and ``PARAMETRIC_FEATURE`` (E2) are
    loadable; the others parse so a bundle targeting a future point
    fails at load time with "not yet supported" instead of failing at
    parse time with "unknown".
    """

    OUTPUT_ADAPTER = "output_adapter"
    PARAMETRIC_FEATURE = "parametric_feature"
    SCENE_ACTION = "scene_action"
    MOTOR_BACKEND = "motor_backend"


class ExtensionError(ValueError):
    """Base for every extension manifest/discovery/loading failure."""


class ExtensionManifestError(ExtensionError):
    """A manifest that cannot be parsed; ``path`` names the field."""

    def __init__(self, path: str, message: str):
        super().__init__(f"{path}: {message}")
        self.path = path
        self.message = message


class ExtensionLoadError(ExtensionError):
    """Discovery or contribution loading failed; names the bundle."""


@dataclass(frozen=True)
class Contribution:
    """One ``provides:`` entry: a contribution to an extension point.

    ``entry`` locates the implementation inside the bundle; for
    ``output_adapter`` it is ``"<module>.py:<ClassName>"``. ``config``
    is the optional manifest ``config:`` mapping, passed through as
    constructor keyword arguments when the contribution is
    instantiated.
    """

    kind: ContributionKind
    id: str
    entry: str
    config: Mapping[str, object] = field(default_factory=dict)


@dataclass(frozen=True)
class ExtensionManifest:
    """A parsed, validated ``extension.yaml``."""

    id: str
    name: str
    version: str
    author: str = ""
    license: str = ""
    description: str = ""
    anima_format: str | None = None
    requires: tuple[str, ...] = ()
    capabilities: tuple[Capability, ...] = ()
    provides: tuple[Contribution, ...] = ()
    assets: tuple[str, ...] = ()


@dataclass(frozen=True)
class Extension:
    """One discovered bundle: its manifest plus where it lives."""

    manifest: ExtensionManifest
    bundle_dir: Path


# Manifest parsing ------------------------------------------------------------


def parse_manifest(text: str) -> ExtensionManifest:
    """Parse ``extension.yaml`` text into a validated manifest."""
    try:
        document = yaml.safe_load(text)
    except yaml.YAMLError as error:
        raise ExtensionManifestError(
            "<document>", f"not valid YAML: {error}"
        ) from error
    document = _mapping(document, "<document>")

    supported = {
        "anima_extension",
        "id",
        "name",
        "version",
        "author",
        "license",
        "description",
        "compatibility",
        "requires",
        "capabilities",
        "provides",
        "assets",
    }
    for key in document:
        if key not in supported:
            raise ExtensionManifestError(str(key), "unknown field")

    schema_version = document.get("anima_extension")
    if schema_version is None:
        raise ExtensionManifestError(
            "anima_extension", "missing required field"
        )
    if schema_version != SUPPORTED_MANIFEST_VERSION:
        raise ExtensionManifestError(
            "anima_extension",
            f"unsupported manifest version {schema_version!r} "
            f"(expected {SUPPORTED_MANIFEST_VERSION!r})",
        )
    for required in ("id", "name", "version"):
        if required not in document:
            raise ExtensionManifestError(required, "missing required field")

    return ExtensionManifest(
        id=_slug(document["id"], "id"),
        name=_non_empty_string(document["name"], "name"),
        version=_non_empty_string(document["version"], "version"),
        author=_string(document.get("author", ""), "author"),
        license=_string(document.get("license", ""), "license"),
        description=_string(document.get("description", ""), "description"),
        anima_format=_parse_compatibility(document.get("compatibility")),
        requires=_parse_requires(document.get("requires")),
        capabilities=_parse_capabilities(document.get("capabilities")),
        provides=_parse_provides(document.get("provides")),
        assets=_parse_assets(document.get("assets")),
    )


def _parse_compatibility(raw: object) -> str | None:
    if raw is None:
        return None
    entry = _mapping(raw, "compatibility")
    _reject_unknown_fields(entry, "compatibility", {"anima_format"})
    if "anima_format" not in entry:
        return None
    return _non_empty_string(
        entry["anima_format"], "compatibility.anima_format"
    )


def _parse_requires(raw: object) -> tuple[str, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        raise ExtensionManifestError(
            "requires",
            f"expected a list of extension ids, got {type(raw).__name__}",
        )
    requires: list[str] = []
    for index, item in enumerate(raw):
        path = f"requires[{index}]"
        extension_id = _slug(item, path)
        if extension_id in requires:
            raise ExtensionManifestError(
                path, f"duplicate required extension id {extension_id!r}"
            )
        requires.append(extension_id)
    return tuple(requires)


def _parse_capabilities(raw: object) -> tuple[Capability, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        raise ExtensionManifestError(
            "capabilities",
            f"expected a list of capabilities, got {type(raw).__name__}",
        )
    capabilities: list[Capability] = []
    for index, item in enumerate(raw):
        path = f"capabilities[{index}]"
        try:
            capability = Capability(item)
        except ValueError:
            valid = ", ".join(sorted(c.value for c in Capability))
            raise ExtensionManifestError(
                path,
                f"unknown capability {item!r} (expected one of: {valid})",
            ) from None
        if capability in capabilities:
            raise ExtensionManifestError(
                path, f"duplicate capability {capability.value!r}"
            )
        capabilities.append(capability)
    return tuple(capabilities)


def _parse_provides(raw: object) -> tuple[Contribution, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        raise ExtensionManifestError(
            "provides",
            f"expected a list of contributions, got {type(raw).__name__}",
        )
    contributions: list[Contribution] = []
    seen_ids: set[tuple[ContributionKind, str]] = set()
    for index, item in enumerate(raw):
        path = f"provides[{index}]"
        contribution = _parse_contribution(item, path)
        key = (contribution.kind, contribution.id)
        if key in seen_ids:
            raise ExtensionManifestError(
                f"{path}.id",
                f"duplicate {contribution.kind.value} contribution id "
                f"{contribution.id!r}",
            )
        seen_ids.add(key)
        contributions.append(contribution)
    return tuple(contributions)


def _parse_contribution(raw: object, path: str) -> Contribution:
    entry = _mapping(raw, path)
    _reject_unknown_fields(entry, path, {"kind", "id", "entry", "config"})
    for required in ("kind", "id", "entry"):
        if required not in entry:
            raise ExtensionManifestError(
                f"{path}.{required}", "missing required field"
            )
    try:
        kind = ContributionKind(entry["kind"])
    except ValueError:
        valid = ", ".join(sorted(k.value for k in ContributionKind))
        raise ExtensionManifestError(
            f"{path}.kind",
            f"unknown contribution kind {entry['kind']!r} "
            f"(expected one of: {valid})",
        ) from None
    entry_str = _non_empty_string(entry["entry"], f"{path}.entry")
    if kind is ContributionKind.OUTPUT_ADAPTER:
        module_file, separator, class_name = entry_str.partition(":")
        if (
            not separator
            or not module_file.endswith(".py")
            or not class_name.isidentifier()
        ):
            raise ExtensionManifestError(
                f"{path}.entry",
                f'expected "<module>.py:<ClassName>", got {entry_str!r}',
            )
    elif kind is ContributionKind.PARAMETRIC_FEATURE:
        # Pure data by construction: the entry is a YAML template file,
        # never Python code.
        if not entry_str.endswith((".yaml", ".yml")):
            raise ExtensionManifestError(
                f"{path}.entry",
                f'expected a bundle-relative "<template>.yaml" file, '
                f"got {entry_str!r}",
            )
        if "config" in entry:
            raise ExtensionManifestError(
                f"{path}.config",
                "parametric_feature contributions are pure data and take "
                "no config (parameters live in the template)",
            )
    config: dict[str, object] = {}
    if "config" in entry:
        config_path = f"{path}.config"
        for key, value in _mapping(entry["config"], config_path).items():
            if not isinstance(key, str) or not key.isidentifier():
                raise ExtensionManifestError(
                    config_path,
                    f"config keys must be identifiers (constructor "
                    f"keyword arguments), got {key!r}",
                )
            config[key] = value
    return Contribution(
        kind=kind,
        id=_slug(entry["id"], f"{path}.id"),
        entry=entry_str,
        config=config,
    )


def _parse_assets(raw: object) -> tuple[str, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list):
        raise ExtensionManifestError(
            "assets",
            f"expected a list of bundle-relative paths, "
            f"got {type(raw).__name__}",
        )
    return tuple(
        _non_empty_string(item, f"assets[{index}]")
        for index, item in enumerate(raw)
    )


# Discovery --------------------------------------------------------------------


def load_extension(bundle_dir: str | Path) -> Extension:
    """Load and validate one ``<slug>.animaext`` bundle directory."""
    bundle_dir = Path(bundle_dir)
    if not bundle_dir.is_dir():
        raise ExtensionLoadError(
            f"{bundle_dir}: an extension bundle must be a directory "
            f"(a zipped bundle needs unpacking first)"
        )
    manifest_file = bundle_dir / MANIFEST_FILENAME
    if not manifest_file.is_file():
        raise ExtensionLoadError(
            f"{bundle_dir}: missing {MANIFEST_FILENAME} manifest"
        )
    try:
        manifest = parse_manifest(manifest_file.read_text(encoding="utf-8"))
    except ExtensionManifestError as error:
        raise ExtensionManifestError(
            f"{manifest_file}: {error.path}", error.message
        ) from error
    return Extension(manifest=manifest, bundle_dir=bundle_dir)


def discover_extensions(
    search_dirs: Iterable[str | Path],
) -> ExtensionRegistry:
    """Scan directories for ``*.animaext`` bundles; build a registry.

    No default global paths are baked in — callers pass the directories
    to scan. The conventional locations (Extensions.md) are the
    user-level ``~/Library/Application Support/AnimaStudio/Extensions/``
    directory and the project-local ``<project>/extensions/`` directory
    that ships with a project.

    A nonexistent search directory is skipped (an empty install is
    normal); a ``*.animaext`` entry that is not a valid bundle — not a
    directory, missing its manifest, or failing manifest validation —
    is a loud typed error, never silently ignored. Duplicate extension
    ids across bundles are an ``ExtensionLoadError``.
    """
    extensions: list[Extension] = []
    for search_dir in search_dirs:
        search_dir = Path(search_dir)
        if not search_dir.is_dir():
            continue
        for bundle_dir in sorted(search_dir.glob(f"*{BUNDLE_SUFFIX}")):
            extensions.append(load_extension(bundle_dir))
    return ExtensionRegistry(extensions)


class ExtensionRegistry:
    """The validated set of discovered extensions and contributions.

    Extension ids are unique across the registry, and contribution ids
    are unique per kind across the registry (v1 keeps one flat
    namespace per extension point, so a contribution id alone
    identifies an implementation) — either duplicate is a construction
    error naming both bundles.
    """

    def __init__(self, extensions: Iterable[Extension]):
        self._extensions: dict[str, Extension] = {}
        self._contributions: dict[
            tuple[ContributionKind, str], tuple[Extension, Contribution]
        ] = {}
        for extension in extensions:
            extension_id = extension.manifest.id
            existing = self._extensions.get(extension_id)
            if existing is not None:
                raise ExtensionLoadError(
                    f"duplicate extension id {extension_id!r}: "
                    f"{existing.bundle_dir} and {extension.bundle_dir}"
                )
            self._extensions[extension_id] = extension
            for contribution in extension.manifest.provides:
                key = (contribution.kind, contribution.id)
                claimed = self._contributions.get(key)
                if claimed is not None:
                    raise ExtensionLoadError(
                        f"duplicate {contribution.kind.value} contribution "
                        f"id {contribution.id!r}: extensions "
                        f"{claimed[0].manifest.id!r} and {extension_id!r}"
                    )
                self._contributions[key] = (extension, contribution)

    @property
    def extensions(self) -> Mapping[str, Extension]:
        """Every discovered extension, keyed by extension id."""
        return dict(self._extensions)

    def contributions(
        self, kind: ContributionKind
    ) -> tuple[tuple[Extension, Contribution], ...]:
        """Every registered contribution of one kind, with its owner."""
        return tuple(
            pair
            for (contribution_kind, _), pair in self._contributions.items()
            if contribution_kind is kind
        )

    def load_contribution(
        self, kind: ContributionKind, contribution_id: str
    ) -> type | FeatureTemplate:
        """Load one contribution's implementation.

        ``output_adapter`` contributions load their adapter class (E1);
        ``parametric_feature`` contributions load their validated
        ``FeatureTemplate`` (E2, pure data). The other known kinds
        raise ``ExtensionLoadError`` ("not yet supported") here rather
        than failing at parse time.
        """
        pair = self._contributions.get((kind, contribution_id))
        if pair is None:
            raise ExtensionLoadError(
                f"no {kind.value} contribution with id "
                f"{contribution_id!r} is registered"
            )
        extension, contribution = pair
        if kind is ContributionKind.OUTPUT_ADAPTER:
            return _load_output_adapter_class(extension, contribution)
        if kind is ContributionKind.PARAMETRIC_FEATURE:
            return _load_feature_template(extension, contribution)
        raise ExtensionLoadError(
            f"{kind.value} contributions are not yet supported "
            f"(output_adapter and parametric_feature load today; see "
            f"dev/docs/roadmap/Extensions.md)"
        )

    def load_output_adapter(
        self, contribution_id: str
    ) -> type[OutputAdapter]:
        """Load one ``output_adapter`` contribution's adapter class."""
        return self.load_contribution(
            ContributionKind.OUTPUT_ADAPTER, contribution_id
        )

    def load_parametric_feature(
        self, contribution_id: str
    ) -> FeatureTemplate:
        """Load one ``parametric_feature`` contribution's template."""
        return self.load_contribution(
            ContributionKind.PARAMETRIC_FEATURE, contribution_id
        )


# Entry loading ----------------------------------------------------------------


def _load_output_adapter_class(
    extension: Extension, contribution: Contribution
) -> type[OutputAdapter]:
    """Import ``entry: "<module>.py:<ClassName>"`` from inside a bundle.

    The module file is imported directly with ``importlib.util`` under
    a module name namespaced by the extension id — nothing is added to
    ``sys.path``, so bundles cannot shadow each other or the app.
    """
    extension_id = extension.manifest.id
    module_file, _, class_name = contribution.entry.partition(":")
    bundle_dir = extension.bundle_dir.resolve()
    module_path = (bundle_dir / module_file).resolve()
    if not module_path.is_relative_to(bundle_dir):
        raise ExtensionLoadError(
            f"extension {extension_id!r}: entry {contribution.entry!r} "
            f"escapes the bundle directory"
        )
    if not module_path.is_file():
        raise ExtensionLoadError(
            f"extension {extension_id!r}: entry module not found: "
            f"{module_file!r}"
        )
    module_name = "anima_core._animaext_" + re.sub(
        r"[^0-9a-zA-Z_]", "_", f"{extension_id}_{module_path.stem}"
    )
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise ExtensionLoadError(
            f"extension {extension_id!r}: cannot import {module_file!r}"
        )
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    try:
        spec.loader.exec_module(module)
    except Exception as error:
        sys.modules.pop(module_name, None)
        raise ExtensionLoadError(
            f"extension {extension_id!r}: importing {module_file!r} "
            f"failed: {error}"
        ) from error
    adapter_class = getattr(module, class_name, None)
    if adapter_class is None:
        raise ExtensionLoadError(
            f"extension {extension_id!r}: {module_file!r} has no class "
            f"named {class_name!r}"
        )
    if not isinstance(adapter_class, type) or not issubclass(
        adapter_class, OutputAdapter
    ):
        raise ExtensionLoadError(
            f"extension {extension_id!r}: {contribution.entry!r} does not "
            f"implement the OutputAdapter protocol "
            f"(open/send_frame/stop/close)"
        )
    return adapter_class


def _load_feature_template(
    extension: Extension, contribution: Contribution
) -> FeatureTemplate:
    """Load ``entry: "<template>.yaml"`` from inside a bundle (E2).

    The entry is pure data: it is read and validated by
    ``anima_core.features.load_feature_template``, never imported or
    executed. Template validation errors are re-raised with the
    template file path prefixed, mirroring manifest error handling.
    """
    extension_id = extension.manifest.id
    bundle_dir = extension.bundle_dir.resolve()
    template_path = (bundle_dir / contribution.entry).resolve()
    if not template_path.is_relative_to(bundle_dir):
        raise ExtensionLoadError(
            f"extension {extension_id!r}: entry {contribution.entry!r} "
            f"escapes the bundle directory"
        )
    if not template_path.is_file():
        raise ExtensionLoadError(
            f"extension {extension_id!r}: entry template not found: "
            f"{contribution.entry!r}"
        )
    try:
        return load_feature_template(template_path)
    except FeatureTemplateError as error:
        raise FeatureTemplateError(
            f"{template_path}: {error.path}", error.message
        ) from error


# Primitive validators ----------------------------------------------------------


def _mapping(value: object, path: str) -> dict:
    if not isinstance(value, dict):
        raise ExtensionManifestError(
            path, f"expected a mapping, got {type(value).__name__}"
        )
    return value


def _string(value: object, path: str) -> str:
    if not isinstance(value, str):
        raise ExtensionManifestError(path, f"expected a string, got {value!r}")
    return value


def _non_empty_string(value: object, path: str) -> str:
    string = _string(value, path)
    if not string:
        raise ExtensionManifestError(path, "must not be empty")
    return string


def _slug(value: object, path: str) -> str:
    string = _non_empty_string(value, path)
    if not _SLUG_PATTERN.match(string):
        raise ExtensionManifestError(
            path,
            f"must be a lowercase slug ([a-z0-9_-], starting with a "
            f"letter or digit), got {string!r}",
        )
    return string


def _reject_unknown_fields(raw: dict, path: str, allowed: set[str]) -> None:
    for key in raw:
        if key not in allowed:
            raise ExtensionManifestError(f"{path}.{key}", "unknown field")
