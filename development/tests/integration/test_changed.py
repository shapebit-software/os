"""development/changed.py: which packages a change touches, for CI."""

import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("changed", ROOT / "development/changed.py")
changed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(changed)
GRAPH = changed.dependents()


def test_a_package_touches_itself_and_what_requires_it():
    found = changed.touched(["packages/colors/data/colors.toml"], GRAPH)
    assert {"colors", "shell", "system"} <= found


def test_a_package_touches_the_packages_whose_tests_read_its_files():
    # packages/colors/tests/unit/test_colors.py reads the splash's theme.
    assert "colors" in changed.touched(["packages/splash/data/boot.plymouth"], GRAPH)


def test_the_tests_tools_touch_every_package():
    assert changed.touched(["packages/testing/src/testing/fixtures.py"], GRAPH) == set(GRAPH)


def test_a_package_that_nothing_needs_touches_itself_the_system_and_what_reads_the_system():
    found = changed.touched(["packages/downloads/src/downloads"], GRAPH)
    assert {"downloads", "system"} <= found
    assert found.isdisjoint({"network", "assistant", "dictation", "capture"})


def test_a_change_outside_the_packages_touches_every_package():
    assert changed.touched(["packages/shell/src/shell.qml", "Makefile"], GRAPH) is None
    assert changed.touched(["packages/package.mk"], GRAPH) is None


def test_documentation_touches_no_package():
    assert changed.touched(["packages/shell/README.md", "guidebook/Desktop.md"], GRAPH) == set()


def test_no_base_to_compare_with_checks_every_package():
    assert changed.changed_paths("not-a-commit") is None
