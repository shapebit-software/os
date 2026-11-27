"""Every test is where the convention says (../README.md): in the tests/ of
the code it tests, arranged as its package likes, named for its kind; its
markers, not its folder, say its level."""

import os
import pathlib
import re

from testing import package_dir

ROOT = package_dir(__file__).parents[1]
SKIPPED = {".git", "build", "__pycache__", "node_modules"}
# What tests/ holds, in any folders: pytest's tests, Qt's (CTest's, and the QML
# tests that the plugin runs), fixtures, and CTest's list; anything in a data/
# folder; and openQA's modules and needles, in e2e/.
TEST = re.compile(r"(test_.+\.py|tst_.+\.(cpp|qml|py)|conftest\.py|CMakeLists\.txt)$")


def files():
    for folder, folders, names in os.walk(ROOT):
        folders[:] = [f for f in folders if f not in SKIPPED]
        for name in names:
            yield pathlib.Path(folder, name).relative_to(ROOT)


def test_every_file_in_tests_is_named_for_its_kind():
    wrong = []
    for path in files():
        if "tests" not in path.parts:
            continue
        inside = path.parts[len(path.parts) - path.parts[::-1].index("tests"):]
        if inside[0] != "e2e" and "data" not in inside[:-1] and not TEST.match(inside[-1]):
            wrong.append(f"{path}: tests/ holds test_*.py, tst_*, conftest.py, CMakeLists.txt, data/, and e2e/")
    assert wrong == []


def test_no_test_is_outside_tests():
    loose = [str(p) for p in files() if re.match(r"(test_|check_|tst_)", p.name) and "tests" not in p.parts]
    assert loose == []


def test_no_check_prefix_is_left():
    assert [str(p) for p in files() if p.name.startswith("check_") and p.suffix == ".py"] == []


# What every package keeps to, so that it can move to a repository of its own
# and still build and test (../../README.md): the tools' own files and the
# tests of packages/ as a whole read the whole repository, by their nature.
TOOLS = {"packaging", "linting", "testing"}
FEATURES = sorted(p.parent for p in (ROOT / "packages").glob("*/*.spec") if p.parent.name not in TOOLS)


def test_a_package_builds_with_the_kit_not_with_its_neighbours():
    wrong = [f"{path.relative_to(ROOT)}: includes ../; use $(PACKAGING)/"
             for path in (ROOT / "packages").glob("*/Makefile") if re.search(r"^\s*-?include\s+\.\./", path.read_text(), re.M)]
    wrong += [f"{spec.relative_to(ROOT)}: loads %{{shapebit_macros}} first"
              for spec in (ROOT / "packages").glob("*/*.spec") if "%{load:%{shapebit_macros}}" not in spec.read_text()]
    assert wrong == []


def test_a_packages_files_reach_only_their_own_package():
    """No file of a package climbs above its folder with __file__: its tests
    find their package with package_dir(__file__), and another package with
    sibling(NAME, __file__)."""
    wrong = []
    for feature in FEATURES:
        for path in feature.rglob("*.py"):
            depth = len(path.relative_to(feature).parts) - 1
            for number, line in enumerate(path.read_text().splitlines(), 1):
                for up in re.findall(r"__file__\)(?:\.resolve\(\))?\.parents\[(\d+)\]", line):
                    if int(up) > depth:
                        wrong.append(f"{path.relative_to(ROOT)}:{number}: climbs out of {feature.name}/")
    assert wrong == []
