"""Each own package's License names exactly the licenses that REUSE.toml gives
the files it installs: those of its src/, system/ and data/ (test_install.py),
except others' license texts. The texts that its packages install
(packaging's data/licenses and package.macros) are those of LICENSES/."""

import pathlib
import re
import tomllib

import pytest

PACKAGES = pathlib.Path(__file__).parents[2]
ROOT = PACKAGES.parent
INSTALLED = ("src", "system", "data")
# Others' license texts, which a package carries but are not its contents.
TEXTS = ("data/notices", "data/licenses")
# shapebit-system installs no files of its own, only its license's text.
SPECS = sorted(p for p in PACKAGES.glob("*/*.spec") if p.parent.name != "system")


def annotations():
    return tomllib.loads((ROOT / "REUSE.toml").read_text())["annotations"]


def license_of(path):
    """The license REUSE.toml gives PATH, relative to the repository: the last
    annotation that matches it."""
    found = None
    for annotation in annotations():
        paths = annotation["path"]
        if any(pathlib.PurePosixPath(path).full_match(p) for p in ([paths] if isinstance(paths, str) else paths)):
            found = annotation["SPDX-License-Identifier"]
    return found


def macros():
    text = (PACKAGES / "packaging/src/package.macros").read_text()
    return dict(re.findall(r"^%(shapebit_\w+)\s+(\S+)$", text, re.MULTILINE))


def declared(spec):
    line = re.search(r"^License:\s+(.+)$", spec.read_text(), re.MULTILINE)[1]
    line = re.sub(r"%\(.*\)", "", line)
    line = re.sub(r"%\{(\w+)\}", lambda m: macros()[m[1]], line)
    return {term for term in line.split(" AND ") if term.strip()}


def contents(feature):
    for folder in INSTALLED:
        for path in sorted((feature / folder).rglob("*")):
            relative = path.relative_to(feature).as_posix()
            if path.is_file() and "__pycache__" not in path.parts and not relative.startswith(TEXTS):
                yield path.relative_to(ROOT).as_posix()


def test_the_last_matching_annotation_counts():
    assert license_of("packages/shell/src/shell.qml") == "GPL-3.0-or-later"
    assert license_of("packages/colors/README.md") == "CC-BY-SA-4.0"
    assert license_of("packages/assistant/data/skills/writing.md") == "MIT"
    assert license_of("packages/splash/data/watermark.png") == "LicenseRef-ShapeBit-Brand"


@pytest.mark.parametrize("spec", SPECS, ids=lambda p: p.parent.name)
def test_license_names_the_licenses_of_the_installed_files(spec):
    expected = {license_of(path) for path in contents(spec.parent)}
    assert declared(spec) == expected


def test_installed_texts_are_the_repositorys():
    texts = sorted((PACKAGES / "packaging/data/licenses").iterdir())
    assert texts
    for text in texts:
        ident = re.fullmatch(r"LICENSE-(.+)\.txt", text.name)[1]
        source = ROOT / "LICENSES" / f"{ident}.txt"
        if not source.exists():
            source = ROOT / "LICENSES" / f"LicenseRef-{ident}.txt"
        assert text.read_bytes() == source.read_bytes(), text.name


def test_every_own_license_has_a_text_to_install():
    for kind in ("program", "library", "config", "artwork", "brand"):
        ident = macros()[f"shapebit_{kind}"].removeprefix("LicenseRef-")
        assert (PACKAGES / "packaging/data/licenses" / f"LICENSE-{ident}.txt").exists(), kind
