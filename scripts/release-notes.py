#!/usr/bin/env python3
"""Write a release's notes in Markdown: what it is, and what changed since stable.
GitHub's generated notes list pull requests, and most commits here have none.

Usage: release-notes.py RECORD COMMIT COMMITS OLD_PACKAGES NEW_PACKAGES
RECORD is a medium's installer.img.json, COMMITS the output of `git log --oneline`,
and the packages are files of "name version" lines.
"""

import json
import pathlib
import sys


def read_packages(text):
    """Each package's versions; a package such as the kernel can have several."""
    packages = {}
    for line in text.splitlines():
        name, version = line.split(" ", 1)
        packages.setdefault(name, set()).add(version)
    return packages


def package_changes(old, new):
    """One line per package that was added, removed, or changed version."""
    lines = []
    for name in sorted(old.keys() | new.keys()):
        before = ", ".join(sorted(old.get(name, ())))
        after = ", ".join(sorted(new.get(name, ())))
        if not before:
            lines.append(f"- Added `{name}` {after}")
        elif not after:
            lines.append(f"- Removed `{name}` {before}")
        elif before != after:
            lines.append(f"- Updated `{name}` {before} → {after}")
    return lines


def notes(record, commit, commits, old_packages, new_packages):
    changes = package_changes(read_packages(old_packages), read_packages(new_packages))
    return "\n".join(
        [
            f"- Image digest: `{record['image_digest']}`",
            f"- Medium SHA-256: `{record['medium_sha256']}`",
            f"- Commit: `{commit}`",
            "",
            "## Commits since stable",
            "```",
            commits.strip() or "None",
            "```",
            "## Packages changed since stable",
            *(changes or ["None"]),
            "",
        ]
    )


def main(record, commit, commits, old_packages, new_packages):
    read = lambda path: pathlib.Path(path).read_text()
    print(notes(json.loads(read(record)), commit, read(commits), read(old_packages), read(new_packages)), end="")


if __name__ == "__main__":
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    main(*sys.argv[1:])
