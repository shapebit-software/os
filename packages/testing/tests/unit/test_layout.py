"""Every test is where the convention says (../../README.md): in the tests/
of the code it tests, in the folder of its level, named for its kind."""

import os
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[4]
LEVELS = ("unit", "integration", "system", "e2e")
SKIPPED = {".git", "build", "__pycache__", "node_modules"}
# What a level folder holds: pytest's tests, Qt's (CTest's, and the QML
# tests that the plugin runs), shared fixtures, and data.
TEST = re.compile(r"(test_.+\.py|tst_.+\.(cpp|qml|py)|conftest\.py)$")
# What tests/ itself holds: fixtures and CTest's list, shared by the levels.
SHARED = {"conftest.py", "CMakeLists.txt"}


def files():
    for folder, folders, names in os.walk(ROOT):
        folders[:] = [f for f in folders if f not in SKIPPED]
        for name in names:
            yield pathlib.Path(folder, name).relative_to(ROOT)


def test_every_file_in_tests_is_in_its_level_and_named_for_its_kind():
    wrong = []
    for path in files():
        if "tests" not in path.parts or path.parts[0] == "quality":
            continue
        inside = path.parts[len(path.parts) - 1 - path.parts[::-1].index("tests") + 1:]
        if len(inside) == 1:
            if inside[0] not in SHARED:
                wrong.append(f"{path}: tests/ holds only {', '.join(sorted(SHARED))}; tests go in tests/LEVEL/")
        elif inside[0] not in LEVELS:
            wrong.append(f"{path}: {inside[0]}/ is not a level ({', '.join(LEVELS)})")
        elif inside[0] != "e2e" and "data" not in inside[1:-1] and not TEST.match(inside[-1]):
            wrong.append(f"{path}: a level holds test_*.py, tst_*, conftest.py, and data/")
    assert wrong == []


def test_no_test_is_outside_tests():
    loose = [str(p) for p in files() if re.match(r"(test_|check_|tst_)", p.name) and "tests" not in p.parts]
    assert loose == []


def test_no_check_prefix_is_left():
    assert [str(p) for p in files() if p.name.startswith("check_") and p.suffix == ".py"] == []
