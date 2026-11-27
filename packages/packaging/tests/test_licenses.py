"""The licenses: REUSE.toml's last matching annotation counts, and every one of
ShapeBit's own licenses has a text to install. The repository's LICENSES/ is
a link to data/licenses."""

import importlib.util

from testing import package_dir

HERE = package_dir(__file__)
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location("conformance", HERE / "src/conformance.py")
conformance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(conformance)


def test_the_last_matching_annotation_counts():
    assert conformance.license_of("packages/shell/src/shell.qml", ROOT) == "GPL-3.0-or-later"
    assert conformance.license_of("packages/colors/README.md", ROOT) == "CC-BY-SA-4.0"
    assert conformance.license_of("packages/assistant/data/skills/writing.md", ROOT) == "MIT"
    assert conformance.license_of("packages/splash/data/watermark.png", ROOT) == "LicenseRef-Brand"


def test_every_own_license_has_a_text_to_install():
    for kind in ("program", "library", "config", "artwork", "brand"):
        ident = conformance.macros()[f"shapebit_{kind}"]
        assert (HERE / "data/licenses" / f"{ident}.txt").exists(), kind
