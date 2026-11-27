#!/usr/bin/python3
"""The crates that a feature's Rust programs are built from (cargo.mk), from
`cargo tree --prefix none --format '{p}|{l}'` lines on standard input.

licenses: prints their licenses as one SPDX expression, the feature's own
left out, for the spec's License.
install REGISTRY DIRECTORY: writes their list, DIRECTORY/cargo-vendor.txt, one
"NAME vVERSION" per line, and copies each crate's license texts from
REGISTRY/NAME-VERSION/ into DIRECTORY/NAME-VERSION/; a crate without one fails.

Usage: cargo tree ... | crates.py licenses
       cargo tree ... | crates.py install REGISTRY DIRECTORY
"""

import pathlib
import re
import shutil
import sys

# What a crate's license texts are called: LICENSE, LICENSE-MIT, COPYING, UNLICENSE...
TEXT = re.compile(r"(un)?licen[cs]e.*|copying.*|notice.*", re.IGNORECASE)


def crates(lines):
    """{(name, version): license}, without the feature itself, whose path
    cargo shows, such as "network v0.0.0 (/path)"."""
    found = {}
    for line in lines:
        package, _, license = line.rstrip("\n").partition("|")
        match = re.fullmatch(r"(\S+) v(\S+)(?: \((proc-macro|\*)\))*", package.strip())
        if match:
            found[match[1], match[2]] = license.removesuffix(" (*)").strip()
    return found


def expression(licenses):
    """One SPDX expression for all LICENSES, each a term or terms joined by
    AND, whose terms are a license or a choice, in parentheses or not: each
    term once, a choice in parentheses and in one order."""
    terms = set()
    for license in licenses:
        for term in re.split(r" AND (?![^(]*\))", license):
            choices = term.strip().removeprefix("(").removesuffix(")").split(" OR ")
            terms.add(choices[0] if len(choices) == 1 else "(" + " OR ".join(sorted(choices)) + ")")
    return " AND ".join(sorted(terms))


def install(found, registry, directory):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "cargo-vendor.txt").write_text("".join(f"{name} v{version}\n" for name, version in sorted(found)))
    for name, version in sorted(found):
        source = registry / f"{name}-{version}"
        texts = [p for p in sorted(source.iterdir()) if p.is_file() and TEXT.fullmatch(p.name)]
        if not texts:
            sys.exit(f"error: the crate {name} {version} has no license text in {source}")
        for text in texts:
            (directory / source.name).mkdir(exist_ok=True)
            shutil.copyfile(text, directory / source.name / text.name)


def main(args):
    found = crates(sys.stdin)
    if args == ["licenses"]:
        print(expression(found.values()))
    elif len(args) == 3 and args[0] == "install":
        install(found, pathlib.Path(args[1]), pathlib.Path(args[2]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
