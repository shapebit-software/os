#!/usr/bin/env python3
"""What every ShapeBit package keeps to (../README.md), checked on one
package, wherever it lives: in this repository or in one of its own.

- Its spec's Name is shapebit-FOLDER.
- Its Makefile installs every file of its src/, system/ and data/ (but Rust
  sources, which it builds), and none of its tests: a file that is added but
  not installed would otherwise ship nothing, without a word.
- Its spec's License names exactly the licenses that REUSE.toml gives the files
  it installs, but others' license texts.
- Its systemd units parse.

Usage: conformance.py [FEATURE]   (make check-package, in the feature's folder)"""

import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib

# This kit's folder, with package.macros: this tree's packaging/src, or where
# shapebit-packaging installed it.
KIT = pathlib.Path(__file__).resolve().parent
INSTALLED = ("src", "system", "data")
# Others' license texts, which a package carries but are not its contents.
TEXTS = ("data/notices", "data/licenses")


def spec_of(feature):
    return feature / f"{feature.name}.spec"


def name_problems(feature):
    if re.search(rf"^Name:\s*shapebit-{re.escape(feature.name)}$", spec_of(feature).read_text(), re.M):
        return []
    return [f"{feature.name}.spec: Name is not shapebit-{feature.name}"]


def sources(feature):
    """The files that the feature's Makefile installs."""
    for folder in INSTALLED:
        for path in sorted((feature / folder).rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".rs":
                yield path


def is_test(path):
    return path.name.startswith(("test_", "tst_")) or path.name == "conftest.py"


def install(feature, destination):
    """What the feature's Makefile installs into destination."""
    subprocess.run(["make", "-C", feature, "install", f"DESTDIR={destination}", "FEDORA=45", "IMAGE_VERSION=test",
                    "IMAGE_REVISION=test"], check=True, capture_output=True)
    return [p for p in pathlib.Path(destination).rglob("*") if p.is_file() and not p.is_symlink()]


def install_problems(feature):
    """Its sources that nothing installs, and its tests that are installed. A
    feature that builds otherwise, without a Makefile (the installer: CMake),
    has none."""
    if not (feature / "Makefile").exists():
        return []
    with tempfile.TemporaryDirectory() as destination:
        installed = install(feature, destination)
        data = [p.read_bytes() for p in installed]
        # os-release gets the image's version and commit appended.
        missing = [p.relative_to(feature) for p in sources(feature) if not any(i.startswith(p.read_bytes()) for i in data)]
        tests = [p.relative_to(destination) for p in installed if is_test(p)]
    return ([f"{feature.name}: not installed by its Makefile: {path}" for path in missing]
            + [f"{feature.name}: a test is installed: /{path}" for path in tests])


def reuse_root(feature):
    """The folder of the REUSE.toml that gives the feature's files their licenses."""
    for folder in [feature, *feature.parents]:
        if (folder / "REUSE.toml").exists():
            return folder
    return None


def license_of(path, root):
    """The license REUSE.toml of root gives path, relative to root: the last
    annotation that matches it."""
    found = None
    for annotation in tomllib.loads((root / "REUSE.toml").read_text())["annotations"]:
        paths = annotation["path"]
        if any(pathlib.PurePosixPath(path).full_match(p) for p in ([paths] if isinstance(paths, str) else paths)):
            found = annotation["SPDX-License-Identifier"]
    return found


def macros():
    """package.macros' licenses, such as shapebit_program."""
    return dict(re.findall(r"^%(shapebit_\w+)\s+(\S+)$", (KIT / "package.macros").read_text(), re.M))


def declared(spec):
    """The licenses that spec's License names; a computed part, %(...), such
    as the crates' of a Rust program, is left out."""
    line = re.search(r"^License:\s+(.+)$", spec.read_text(), re.M)[1]
    line = re.sub(r"%\(.*\)", "", line)
    line = re.sub(r"%\{(\w+)\}", lambda m: macros()[m[1]], line)
    return {term for term in line.split(" AND ") if term.strip()}


def license_problems(feature):
    """A package that installs nothing of its own, such as shapebit-system,
    names only its license's text."""
    root = reuse_root(feature)
    if root is None:
        return [f"{feature.name}: no REUSE.toml above it gives its files their licenses"]
    contents = [p.relative_to(root).as_posix() for p in sources(feature)
                if not p.relative_to(feature).as_posix().startswith(TEXTS)]
    if not contents:
        return []
    expected, named = {license_of(path, root) for path in contents}, declared(spec_of(feature))
    if named == expected:
        return []
    return [f"{feature.name}.spec: License names {' AND '.join(sorted(named))}; its files are "
            f"{' AND '.join(sorted(expected))}"]


def units(feature):
    """Its systemd units: not D-Bus's service files, which only share the suffix."""
    return sorted(p for pattern in ("*.service", "*.timer") for p in (feature / "system").glob(pattern)
                  if not p.name.endswith(".dbus.service"))


def unit_problems(unit):
    """Only syntax counts: the units' programs are in the image, not here."""
    if not shutil.which("systemd-analyze"):
        return []
    result = subprocess.run(["systemd-analyze", "verify", "--man=no", str(unit)], capture_output=True, text=True)
    return [f"{unit.name}: {line.strip()}" for line in result.stderr.splitlines()
            if re.search(r"Unknown (?:key|section)|Failed to parse|Invalid", line)]


def problems(feature):
    feature = pathlib.Path(feature).resolve()
    found = name_problems(feature) + install_problems(feature) + license_problems(feature)
    for unit in units(feature):
        found += unit_problems(unit)
    return found


def main(feature="."):
    found = problems(feature)
    for problem in found:
        print(problem, file=sys.stderr)
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main(*sys.argv[1:])
