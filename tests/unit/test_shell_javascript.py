"""The shell's JavaScript (desktop/shell): Qt's engine lacks some of the newer
language, and a binding that calls what is missing fails only at run time,
leaving empty what it fills, as all of Settings once was."""

import pathlib
import re

import pytest

SHELL = pathlib.Path(__file__).parents[2] / "desktop" / "shell"

# Array methods of ECMAScript 2019 and later that Qt 6.11's engine does not have.
MISSING = ["flatMap", "flat", "findLast", "findLastIndex", "toSorted", "toReversed", "toSpliced"]


@pytest.mark.parametrize("method", MISSING)
def test_no_array_method_that_qt_lacks(method):
    used = [
        f"{path.relative_to(SHELL)}:{number}"
        for path in sorted(SHELL.rglob("*.qml"))
        for number, line in enumerate(path.read_text().splitlines(), 1)
        if re.search(rf"\.{method}\(", line)
    ]
    assert not used, f"Qt's JavaScript has no Array.prototype.{method}: {used}"
