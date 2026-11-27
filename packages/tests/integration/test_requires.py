"""What requires.sh lists: what the images install for ShapeBit's packages."""

import pathlib
import subprocess

PACKAGES = pathlib.Path(__file__).parents[2]


def requires(*args):
    result = subprocess.run([PACKAGES / "requires.sh", *args], capture_output=True, text=True, check=True)
    return result.stdout.split()


def test_lists_what_the_image_packages_run_on():
    packages = requires()
    assert "hyprland" in packages
    assert packages == sorted(set(packages))
    # ShapeBit's own come from this build, and macros are the specs' own.
    assert not [p for p in packages if p.startswith("shapebit-") or "%{" in p]


def test_leaves_out_the_installer_which_is_only_on_the_medium():
    assert "cmake" not in requires("--build")
    assert "cmake" in requires("--build", "installer/installer.spec")
