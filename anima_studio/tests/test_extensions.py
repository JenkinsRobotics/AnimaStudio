"""`.animaext` bundles: manifest schema, discovery, entry loading."""

import copy
import sys
from pathlib import Path

import pytest
import yaml

from anima_studio.extensions import (
    Capability,
    Contribution,
    ContributionKind,
    ExtensionLoadError,
    ExtensionManifestError,
    ExtensionRegistry,
    discover_extensions,
    load_extension,
    parse_manifest,
)
from anima_studio.outputs import ChannelConfig, OutputAdapter

EXTENSIONS_DIR = (
    Path(__file__).resolve().parents[2] / "examples" / "extensions"
)

BASE_MANIFEST = {
    "anima_extension": "1.0",
    "id": "demo-output",
    "name": "Demo Output",
    "version": "0.1.0",
    "capabilities": ["network"],
    "provides": [
        {
            "kind": "output_adapter",
            "id": "demo",
            "entry": "adapter.py:DemoOutput",
        },
    ],
}

DEMO_ADAPTER_SOURCE = '''\
"""A complete, well-behaved output adapter for loader tests."""


class DemoOutput:
    def __init__(self, **config):
        self.config = config
        self.frames = []
        self.stopped = False

    def open(self, channel_configs):
        self.channel_configs = list(channel_configs)

    def send_frame(self, targets, duration_ms):
        self.frames.append((dict(targets), duration_ms))

    def stop(self):
        self.stopped = True

    def close(self):
        pass
'''


def manifest(**overrides) -> dict:
    doc = copy.deepcopy(BASE_MANIFEST)
    doc.update(overrides)
    return doc


def assert_rejects(doc: dict, path_fragment: str):
    with pytest.raises(ExtensionManifestError) as excinfo:
        parse_manifest(yaml.safe_dump(doc))
    assert path_fragment in excinfo.value.path, excinfo.value


def write_bundle(
    parent: Path,
    slug: str = "demo-output",
    doc: dict | None = None,
    adapter_source: str | None = DEMO_ADAPTER_SOURCE,
) -> Path:
    bundle = parent / f"{slug}.animaext"
    bundle.mkdir(parents=True)
    if doc is not None:
        document = doc
    else:
        document = manifest(id=slug)
        document["provides"][0]["id"] = slug.replace("-", "_")
    (bundle / "extension.yaml").write_text(
        yaml.safe_dump(document), encoding="utf-8"
    )
    if adapter_source is not None:
        (bundle / "adapter.py").write_text(adapter_source, encoding="utf-8")
    return bundle


class TestManifestAccepts:
    def test_full_manifest(self):
        parsed = parse_manifest(
            yaml.safe_dump(
                manifest(
                    author="Anima examples",
                    license="Apache-2.0",
                    description="A demo.",
                    compatibility={"anima_format": "2.0"},
                    requires=["other-extension"],
                    capabilities=["network", "hardware"],
                    provides=[
                        {
                            "kind": "output_adapter",
                            "id": "demo",
                            "entry": "adapter.py:DemoOutput",
                            "config": {"host": "127.0.0.1", "port": 9600},
                        },
                    ],
                    assets=["docs/README.md"],
                )
            )
        )
        assert parsed.id == "demo-output"
        assert parsed.name == "Demo Output"
        assert parsed.version == "0.1.0"
        assert parsed.author == "Anima examples"
        assert parsed.license == "Apache-2.0"
        assert parsed.anima_format == "2.0"
        assert parsed.requires == ("other-extension",)
        assert parsed.capabilities == (
            Capability.NETWORK,
            Capability.HARDWARE,
        )
        assert parsed.provides == (
            Contribution(
                kind=ContributionKind.OUTPUT_ADAPTER,
                id="demo",
                entry="adapter.py:DemoOutput",
                config={"host": "127.0.0.1", "port": 9600},
            ),
        )
        assert parsed.assets == ("docs/README.md",)

    def test_minimal_manifest(self):
        parsed = parse_manifest(
            yaml.safe_dump(
                {
                    "anima_extension": "1.0",
                    "id": "tiny",
                    "name": "Tiny",
                    "version": "0.0.1",
                }
            )
        )
        assert parsed.capabilities == ()
        assert parsed.provides == ()
        assert parsed.requires == ()
        assert parsed.assets == ()
        assert parsed.anima_format is None

    def test_future_kind_parses_without_being_loadable(self):
        parsed = parse_manifest(
            yaml.safe_dump(
                manifest(
                    provides=[
                        {
                            "kind": "parametric_feature",
                            "id": "gripper",
                            "entry": "gripper.yaml",
                        },
                    ]
                )
            )
        )
        kind = parsed.provides[0].kind
        assert kind is ContributionKind.PARAMETRIC_FEATURE


class TestManifestRejects:
    def test_not_yaml(self):
        with pytest.raises(ExtensionManifestError):
            parse_manifest(":\n  - {")

    def test_not_a_mapping(self):
        with pytest.raises(ExtensionManifestError):
            parse_manifest("- just\n- a\n- list\n")

    def test_unknown_top_level_field(self):
        assert_rejects(manifest(bogus=1), "bogus")

    def test_missing_schema_version(self):
        doc = manifest()
        del doc["anima_extension"]
        assert_rejects(doc, "anima_extension")

    def test_unsupported_schema_version(self):
        assert_rejects(manifest(anima_extension="2.0"), "anima_extension")

    @pytest.mark.parametrize("required", ["id", "name", "version"])
    def test_missing_required_field(self, required):
        doc = manifest()
        del doc[required]
        assert_rejects(doc, required)

    @pytest.mark.parametrize("bad_id", ["", "Has Spaces", "UPPER", "-lead"])
    def test_bad_id_slug(self, bad_id):
        assert_rejects(manifest(id=bad_id), "id")

    def test_capabilities_must_be_a_list(self):
        assert_rejects(manifest(capabilities="network"), "capabilities")

    def test_unknown_capability(self):
        assert_rejects(
            manifest(capabilities=["telepathy"]), "capabilities[0]"
        )

    def test_duplicate_capability(self):
        assert_rejects(
            manifest(capabilities=["network", "network"]), "capabilities[1]"
        )

    def test_unknown_contribution_kind(self):
        assert_rejects(
            manifest(
                provides=[
                    {"kind": "studio_panel", "id": "x", "entry": "x.py:X"}
                ]
            ),
            "provides[0].kind",
        )

    @pytest.mark.parametrize("required", ["kind", "id", "entry"])
    def test_missing_contribution_field(self, required):
        entry = {
            "kind": "output_adapter",
            "id": "demo",
            "entry": "adapter.py:DemoOutput",
        }
        del entry[required]
        assert_rejects(manifest(provides=[entry]), f"provides[0].{required}")

    @pytest.mark.parametrize(
        "bad_entry", ["adapter.py", "adapter:DemoOutput", "adapter.py:not-id"]
    )
    def test_bad_output_adapter_entry_format(self, bad_entry):
        assert_rejects(
            manifest(
                provides=[
                    {"kind": "output_adapter", "id": "demo", "entry": bad_entry}
                ]
            ),
            "provides[0].entry",
        )

    def test_duplicate_contribution_id(self):
        contribution = {
            "kind": "output_adapter",
            "id": "demo",
            "entry": "adapter.py:DemoOutput",
        }
        assert_rejects(
            manifest(provides=[contribution, dict(contribution)]),
            "provides[1].id",
        )

    def test_unknown_contribution_field(self):
        assert_rejects(
            manifest(
                provides=[
                    {
                        "kind": "output_adapter",
                        "id": "demo",
                        "entry": "adapter.py:DemoOutput",
                        "pin": 9,
                    }
                ]
            ),
            "provides[0].pin",
        )

    def test_config_keys_must_be_identifiers(self):
        assert_rejects(
            manifest(
                provides=[
                    {
                        "kind": "output_adapter",
                        "id": "demo",
                        "entry": "adapter.py:DemoOutput",
                        "config": {"bad-key": 1},
                    }
                ]
            ),
            "provides[0].config",
        )

    def test_unknown_compatibility_field(self):
        assert_rejects(
            manifest(compatibility={"firmware": "1"}), "compatibility"
        )

    def test_duplicate_requires(self):
        assert_rejects(manifest(requires=["a", "a"]), "requires[1]")


class TestDiscovery:
    def test_discovers_across_multiple_directories(self, tmp_path):
        user_dir = tmp_path / "user"
        project_dir = tmp_path / "project"
        write_bundle(user_dir, "alpha-output")
        write_bundle(project_dir, "beta-output")
        registry = discover_extensions([user_dir, project_dir])
        assert set(registry.extensions) == {"alpha-output", "beta-output"}
        bundle = registry.extensions["alpha-output"].bundle_dir
        assert bundle == user_dir / "alpha-output.animaext"

    def test_nonexistent_search_directory_is_skipped(self, tmp_path):
        registry = discover_extensions([tmp_path / "missing"])
        assert registry.extensions == {}

    def test_non_bundle_entries_are_ignored(self, tmp_path):
        write_bundle(tmp_path, "alpha-output")
        (tmp_path / "notes.txt").write_text("not a bundle")
        (tmp_path / "plain-directory").mkdir()
        registry = discover_extensions([tmp_path])
        assert set(registry.extensions) == {"alpha-output"}

    def test_duplicate_extension_id_across_directories_is_an_error(
        self, tmp_path
    ):
        first = tmp_path / "first"
        second = tmp_path / "second"
        write_bundle(first, "alpha-output")
        write_bundle(second, "alpha-output")
        with pytest.raises(ExtensionLoadError, match="duplicate extension id"):
            discover_extensions([first, second])

    def test_bundle_missing_manifest_fails_loudly(self, tmp_path):
        (tmp_path / "broken.animaext").mkdir()
        with pytest.raises(ExtensionLoadError, match="extension.yaml"):
            discover_extensions([tmp_path])

    def test_bundle_that_is_a_file_fails_loudly(self, tmp_path):
        (tmp_path / "zipped.animaext").write_text("PK...")
        with pytest.raises(ExtensionLoadError, match="directory"):
            discover_extensions([tmp_path])

    def test_manifest_error_names_the_manifest_file(self, tmp_path):
        bundle = write_bundle(tmp_path, "alpha-output", doc=manifest(bogus=1))
        with pytest.raises(ExtensionManifestError) as excinfo:
            discover_extensions([tmp_path])
        assert str(bundle / "extension.yaml") in excinfo.value.path
        assert "bogus" in excinfo.value.path

    def test_duplicate_contribution_id_across_extensions_is_an_error(
        self, tmp_path
    ):
        write_bundle(tmp_path, "alpha-output", doc=manifest(id="alpha-output"))
        write_bundle(tmp_path, "beta-output", doc=manifest(id="beta-output"))
        with pytest.raises(
            ExtensionLoadError, match="duplicate output_adapter contribution"
        ):
            discover_extensions([tmp_path])

    def test_registry_lists_contributions_by_kind(self, tmp_path):
        write_bundle(tmp_path, "alpha-output")
        registry = discover_extensions([tmp_path])
        pairs = registry.contributions(ContributionKind.OUTPUT_ADAPTER)
        assert len(pairs) == 1
        extension, contribution = pairs[0]
        assert extension.manifest.id == "alpha-output"
        assert contribution.id == "alpha_output"
        assert registry.contributions(ContributionKind.SCENE_ACTION) == ()


class TestEntryLoading:
    def test_loads_a_conforming_adapter_class(self, tmp_path):
        write_bundle(tmp_path, "demo-output")
        sys_path_before = list(sys.path)
        registry = discover_extensions([tmp_path])
        adapter_class = registry.load_output_adapter("demo_output")
        assert adapter_class.__name__ == "DemoOutput"
        assert issubclass(adapter_class, OutputAdapter)
        assert sys.path == sys_path_before  # no sys.path pollution

    def test_loaded_adapter_takes_manifest_config_as_kwargs(self, tmp_path):
        doc = manifest()
        doc["provides"][0]["config"] = {"port": 4242}
        write_bundle(tmp_path, "demo-output", doc=doc)
        registry = discover_extensions([tmp_path])
        _, contribution = registry.contributions(
            ContributionKind.OUTPUT_ADAPTER
        )[0]
        adapter = registry.load_output_adapter("demo")(**contribution.config)
        assert adapter.config == {"port": 4242}

    def test_unknown_contribution_id(self, tmp_path):
        write_bundle(tmp_path, "demo-output")
        registry = discover_extensions([tmp_path])
        with pytest.raises(ExtensionLoadError, match="no output_adapter"):
            registry.load_output_adapter("nope")

    def test_future_kind_is_not_yet_supported(self, tmp_path):
        doc = manifest(
            provides=[
                {"kind": "scene_action", "id": "boom", "entry": "boom.py:Boom"}
            ]
        )
        write_bundle(tmp_path, "demo-output", doc=doc)
        registry = discover_extensions([tmp_path])
        with pytest.raises(ExtensionLoadError, match="not yet supported"):
            registry.load_contribution(ContributionKind.SCENE_ACTION, "boom")

    def test_missing_entry_module_file(self, tmp_path):
        write_bundle(tmp_path, "demo-output", adapter_source=None)
        registry = discover_extensions([tmp_path])
        with pytest.raises(ExtensionLoadError, match="not found"):
            registry.load_output_adapter("demo_output")

    def test_entry_escaping_the_bundle_is_rejected(self, tmp_path):
        doc = manifest()
        doc["provides"][0]["entry"] = "../outside.py:DemoOutput"
        write_bundle(tmp_path, "demo-output", doc=doc)
        (tmp_path / "outside.py").write_text(DEMO_ADAPTER_SOURCE)
        registry = discover_extensions([tmp_path])
        with pytest.raises(ExtensionLoadError, match="escapes the bundle"):
            registry.load_output_adapter("demo")

    def test_missing_class_in_entry_module(self, tmp_path):
        doc = manifest()
        doc["provides"][0]["entry"] = "adapter.py:Missing"
        write_bundle(tmp_path, "demo-output", doc=doc)
        registry = discover_extensions([tmp_path])
        with pytest.raises(ExtensionLoadError, match="no class named"):
            registry.load_output_adapter("demo")

    def test_class_not_implementing_the_protocol(self, tmp_path):
        source = "class DemoOutput:\n    def open(self, configs):\n        pass\n"
        write_bundle(tmp_path, "demo-output", adapter_source=source)
        registry = discover_extensions([tmp_path])
        with pytest.raises(ExtensionLoadError, match="OutputAdapter"):
            registry.load_output_adapter("demo_output")

    def test_import_failure_is_a_typed_error(self, tmp_path):
        write_bundle(
            tmp_path, "demo-output", adapter_source="raise RuntimeError('x')\n"
        )
        registry = discover_extensions([tmp_path])
        with pytest.raises(ExtensionLoadError, match="failed"):
            registry.load_output_adapter("demo_output")

    def test_load_extension_rejects_a_missing_directory(self, tmp_path):
        with pytest.raises(ExtensionLoadError, match="directory"):
            load_extension(tmp_path / "ghost.animaext")

    def test_registry_construction_rejects_duplicate_ids(self, tmp_path):
        bundle = write_bundle(tmp_path, "demo-output")
        extension = load_extension(bundle)
        with pytest.raises(ExtensionLoadError, match="duplicate extension"):
            ExtensionRegistry([extension, extension])


class TestUdpWireOutputExample:
    """The packaged example, loaded from its real bundle path."""

    def test_example_bundle_discovers_and_validates(self):
        registry = discover_extensions([EXTENSIONS_DIR])
        extension = registry.extensions["udp-wire-output"]
        assert extension.manifest.capabilities == (Capability.NETWORK,)
        assert extension.manifest.anima_format == "2.0"
        pairs = registry.contributions(ContributionKind.OUTPUT_ADAPTER)
        assert [contribution.id for _, contribution in pairs] == ["udp_wire"]

    def test_example_streams_exact_wire_lines_over_udp(self):
        import socket

        registry = discover_extensions([EXTENSIONS_DIR])
        adapter_class = registry.load_output_adapter("udp_wire")
        assert issubclass(adapter_class, OutputAdapter)
        _, contribution = registry.contributions(
            ContributionKind.OUTPUT_ADAPTER
        )[0]

        receiver = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            receiver.bind(("127.0.0.1", 0))
            receiver.settimeout(5.0)
            port = receiver.getsockname()[1]

            config = dict(contribution.config)
            assert config["host"] == "127.0.0.1"
            config["port"] = port  # ephemeral test port over the default
            adapter = adapter_class(**config)
            adapter.open(
                [ChannelConfig(channel=0, pin=9, min_us=600, max_us=2400)]
            )
            adapter.send_frame({0: 0.25}, duration_ms=33)
            adapter.stop()
            adapter.close()

            lines = [receiver.recv(512).decode("utf-8") for _ in range(4)]
        finally:
            receiver.close()
        assert lines == [
            "CFG,0,servo,pin=9,min_us=600,max_us=2400",
            "EN,0,1",
            "FRM,33,0:0.250",
            "STOP",
        ]
