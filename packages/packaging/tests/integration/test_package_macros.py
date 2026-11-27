"""%shapebit_install, of package.macros, as rpm expands it: run on a feature,
it lists what the feature installed as the package's files, with the text of
each of ShapeBit's licenses that the package's License names, once. rpm's expansion drops some backslashes, which once turned a sed
address into a syntax error that only the image build found."""

import shutil
import subprocess

import pytest
from testing import package_dir

HERE = package_dir(__file__)
PACKAGES = HERE.parent
LICENSES = HERE / "data/licenses"


def install(feature, buildroot, workdir, license):
    script = subprocess.run(
        ["rpm", "--define", f"packages {PACKAGES}", "--define", f"buildroot {buildroot}",
         "--define", f"license {license}", "--define", "fedora 45", "--define", "image_version dev", "--define", "image_revision dev",
         "--define", f"shapebit_licenses {LICENSES}",
         "--load", str(HERE / "src/package.macros"), "--eval", f"%shapebit_install {feature}"],
        capture_output=True, text=True, check=True).stdout
    subprocess.run(["bash", "-euc", script], cwd=workdir, check=True, capture_output=True)
    return (workdir / "files").read_text().splitlines()


@pytest.fixture
def rpm():
    if not shutil.which("rpm"):
        pytest.skip("rpm is missing: run in the development image, as `make test-unit` does")


def test_lists_the_installed_files_and_each_license_once(rpm, tmp_path):
    files = install("release", tmp_path / "root", tmp_path, "GPL-3.0-or-later AND MIT AND LicenseRef-ShapeBit-Brand")
    assert "/usr/lib/os-release" in files
    for name in ("LICENSE-GPL-3.0-or-later.txt", "LICENSE-MIT.txt", "LICENSE-ShapeBit-Brand.txt"):
        assert files.count(f"%license /usr/share/licenses/shapebit/{name}") == 1
        assert (tmp_path / "root/usr/share/licenses/shapebit" / name).read_bytes() == \
            (LICENSES / name).read_bytes()
    assert not [f for f in files if f.startswith("/usr/share/licenses/")]
    assert files.count("%dir /usr/share/licenses/shapebit") == 1


def test_others_licenses_bring_no_text(rpm, tmp_path):
    files = install("release", tmp_path / "root", tmp_path, "OFL-1.1")
    assert "/usr/lib/os-release" in files
    assert not [f for f in files if "licenses/shapebit" in f]
