"""%shapebit_install, of package.macros, as rpm expands it: run on a feature,
it lists what the feature installed as the package's files, with ShapeBit's
license once. rpm's expansion drops some backslashes, which once turned a sed
address into a syntax error that only the image build found."""

import pathlib
import shutil
import subprocess

import pytest

PACKAGES = pathlib.Path(__file__).parent


def install(feature, buildroot, workdir, *options):
    script = subprocess.run(
        ["rpm", "--define", f"packages {PACKAGES}", "--define", f"buildroot {buildroot}",
         "--define", "fedora 45", "--define", "image_version dev", "--define", "image_revision dev",
         "--load", str(PACKAGES / "package.macros"), "--eval", f"%shapebit_install {' '.join(options)} {feature}"],
        capture_output=True, text=True, check=True).stdout
    subprocess.run(["bash", "-euc", script], cwd=workdir, check=True, capture_output=True)
    return (workdir / "files").read_text().splitlines()


@pytest.fixture
def rpm():
    if not shutil.which("rpm"):
        pytest.skip("rpm is missing: run in the development image, as `make test-unit` does")


def test_lists_the_installed_files_and_the_license_once(rpm, tmp_path):
    files = install("release", tmp_path / "root", tmp_path)
    assert "/usr/lib/os-release" in files
    assert files.count("%license /usr/share/licenses/shapebit/LICENSE") == 1
    assert "/usr/share/licenses/shapebit/LICENSE" not in files
    assert files.count("%dir /usr/share/licenses/shapebit") == 1


def test_n_leaves_the_license_out(rpm, tmp_path):
    files = install("release", tmp_path / "root", tmp_path, "-n")
    assert "/usr/lib/os-release" in files
    assert not [f for f in files if "licenses/shapebit" in f]
