"""The tests' own tools (../../README.md): the pytest plugin that holds every
test to its level, the fixtures that tests share, and the machines that the
system tests run on; and how a test finds its package's files, wherever the
package lives: in this repository, or in one of its own."""

import pathlib

import pytest


def package_dir(test_file):
    """The folder of the package that the test file test_file belongs to: the
    nearest above it with a spec."""
    for folder in pathlib.Path(test_file).resolve().parents:
        if next(folder.glob("*.spec"), None):
            return folder
    raise LookupError(f"{test_file}: no package folder, with a spec, above it")


def sibling(name, test_file):
    """Package name's folder, beside the package of test_file, for a test that
    reads another package's files, as its spec declares. Where the package is
    alone, in a repository of its own, the test is skipped."""
    folder = package_dir(test_file).parent / name
    if not (folder / f"{name}.spec").exists():
        pytest.skip(f"needs the package {name} beside this one")
    return folder
