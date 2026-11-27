"""The licenses: REUSE.toml's last matching annotation counts, and the texts
that packages install (data/licenses, for package.macros' licenses) are those
of the repository's LICENSES/."""

import importlib.util
import re

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
    assert conformance.license_of("packages/splash/data/watermark.png", ROOT) == "LicenseRef-ShapeBit-Brand"


def test_installed_texts_are_the_repositorys():
    texts = sorted((HERE / "data/licenses").iterdir())
    assert texts
    for text in texts:
        ident = re.fullmatch(r"LICENSE-(.+)\.txt", text.name)[1]
        source = ROOT / "LICENSES" / f"{ident}.txt"
        if not source.exists():
            source = ROOT / "LICENSES" / f"LicenseRef-{ident}.txt"
        assert text.read_bytes() == source.read_bytes(), text.name


def test_every_own_license_has_a_text_to_install():
    for kind in ("program", "library", "config", "artwork", "brand"):
        ident = conformance.macros()[f"shapebit_{kind}"].removeprefix("LicenseRef-")
        assert (HERE / "data/licenses" / f"LICENSE-{ident}.txt").exists(), kind
