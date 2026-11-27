"""Every file of a feature's src/, system/ and data/ is installed by the
feature's Makefile (packages/README.md): a file that is added but not installed
would otherwise ship nothing, without a word. Its tests/ and tools/ are never
installed, and its external/ packages are built apart; so are features that
build otherwise: the installer (CMake) and shapebit-system. Rust sources are
built into programs (cargo.mk), not installed. The license notices
that notices.py collects are installed by the licenses spec, in the image build."""

import pathlib
import subprocess

import pytest

PACKAGES = pathlib.Path(__file__).parents[2]
FEATURES = sorted(p.parent for p in PACKAGES.glob("*/Makefile"))
# What a feature installs.
INSTALLED = ("src", "system", "data")


def is_test(path):
    """A test, of any level, or what it uses (packages/testing/README.md)."""
    return path.name.startswith(("test_", "tst_")) or path.name == "conftest.py"


def sources(feature):
    for folder in INSTALLED:
        for path in sorted((feature / folder).rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".rs":
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
