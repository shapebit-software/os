"""Every file of a feature folder is installed by the feature's Makefile, unless
it is a test, a tool, or what builds the package: a file that is added but not
installed would otherwise ship nothing, without a word. The tests beside the
code are never installed. External packages (a folder with a sources file)
are built apart, and so are features that build otherwise: the installer
(CMake), the collected license notices, and shapebit-system."""

import pathlib
import subprocess

import pytest

PACKAGES = pathlib.Path(__file__).parent
FEATURES = sorted(p.parent for p in PACKAGES.glob("*/Makefile"))
# What builds or describes a package, everywhere.
BUILD = {"Makefile", "README.md"}
# Tools that serve a feature but are not part of it on the system.
TOOLS = {"colors": {"colors.py"}, "repositories": {"rpm-build.sh", "rpm-repo.sh"}}


def is_test(path):
    return path.name.startswith(("test_", "tst_"))


def external(feature):
    return {p.parent for p in feature.glob("*/sources")}


def sources(feature):
    skip = BUILD | TOOLS.get(feature.name, set())
    outside = external(feature)
    for path in sorted(feature.rglob("*")):
        if not path.is_file() or path.suffix == ".spec" or path.name in skip or is_test(path):
            continue
        if "__pycache__" in path.parts or any(folder in path.parents for folder in outside):
            continue
        yield str(path.relative_to(feature)), path.read_bytes()


def install(feature, destination):
    subprocess.run(["make", "-C", feature, "install", f"DESTDIR={destination}", "FEDORA=45",
                    "IMAGE_VERSION=test", "IMAGE_REVISION=test"], check=True, capture_output=True)
    return [p for p in destination.rglob("*") if p.is_file() and not p.is_symlink()]


@pytest.mark.parametrize("feature", FEATURES, ids=lambda p: p.name)
def test_every_file_is_installed(feature, tmp_path):
    installed = [p.read_bytes() for p in install(feature, tmp_path)]
    # os-release gets the image's version and commit appended.
    missing = [name for name, data in sources(feature) if not any(i.startswith(data) for i in installed)]
    assert missing == [], f"not installed by packages/{feature.name}/Makefile"


@pytest.mark.parametrize("feature", FEATURES, ids=lambda p: p.name)
def test_no_test_is_installed(feature, tmp_path):
    assert [str(p.relative_to(tmp_path)) for p in install(feature, tmp_path) if is_test(p)] == []
