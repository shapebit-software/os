#!/usr/bin/env python3
"""The packages that a change touches, so that CI checks only those
(README.md): the packages with changed files, and those that depend on
them, again and again: whose specs require them, or whose tests read their
files (packages/NAME/ in a test); every package is built, linted, and tested
with the tools (image/requires.sh --tools), so every package depends on them.
A change anywhere else, such as
to the Makefile or to what all packages share, touches every package; one only to
documentation touches none of them, but is checked as everything is.

Prints PACKAGE=, with the packages, or empty for every package, for
$GITHUB_ENV and make.

Usage: changed.py [BASE] (the commit the change is from; none, or one that is
all zeros, as a new branch's push has, compares with main)."""

import pathlib
import re
import subprocess
import sys

# The repository: this runs from it (packages/testing/src/testing/).
ROOT = pathlib.Path(__file__).resolve().parents[4]
PACKAGES = ROOT / "packages"
# The tools, which every package is built, linted, and tested with.
TOOLS = subprocess.run([ROOT / "image/requires.sh", "--tools"], capture_output=True, text=True,
                       check=True).stdout.split()


def dependents():
    """For each package, the packages that depend on it."""
    names = sorted(p.parent.name for p in PACKAGES.glob("*/*.spec"))
    graph = {name: set() for name in names}
    for name in names:
        spec = (PACKAGES / name / f"{name}.spec").read_text()
        required = re.findall(r"^Requires:\s*shapebit-(\S+)", spec, re.M)
        # The tools' own tests read every package, which needs none of them.
        tests = [p for p in (PACKAGES / name / "tests").rglob("*") if p.suffix in (".py", ".qml", ".cpp")
                 and name not in TOOLS]
        read = {other for test in tests for other in re.findall(r"packages/([a-z-]+)/", test.read_text())}
        for other in set(required) | read | set(TOOLS):
            if other in graph and other != name:
                graph[other].add(name)
    return graph


def touched(paths, graph):
    """The packages that PATHS touch, with those that depend on them; None for
    every package."""
    found = set()
    for path in paths:
        parts = path.split("/")
        if path.endswith(".md") or parts[0] == "guidebook":
            continue
        if parts[0] == "packages" and len(parts) > 2 and parts[1] in graph:
            found.add(parts[1])
            continue
        return None
    pending = list(found)
    while pending:
        for name in graph[pending.pop()] - found:
            found.add(name)
            pending.append(name)
    return found


def changed_paths(base):
    """The files changed since BASE, or None when it cannot tell."""
    def git(*args):
        return subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=True)

    if not base or not base.strip("0"):
        base = git("merge-base", "origin/main", "HEAD").stdout.strip()
    diff = git("diff", "--name-only", base, "HEAD") if base else None
    return diff.stdout.split() if diff and diff.returncode == 0 else None


def main():
    paths = changed_paths(sys.argv[1] if len(sys.argv) > 1 else "")
    names = touched(paths, dependents()) if paths is not None else None
    print(f"PACKAGE={' '.join(sorted(names or []))}")


if __name__ == "__main__":
    main()
