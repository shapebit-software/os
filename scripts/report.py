#!/usr/bin/env python3
"""Write what a release decision needs, as Markdown: what changed since the
image that installed systems run, in commits and in packages, and what was
tested. Both kinds matter: a build can differ by Fedora's updates alone.

Usage: report.py PROVENANCE COMMITS NEW_PACKAGES [OLD_PACKAGES]
  PROVENANCE    a passed run's provenance.json, naming the artifact
  COMMITS       `git log --oneline` output since stable
  *_PACKAGES    lines of "name version", as from rpm -qa; without OLD_PACKAGES,
                this is the first release
"""

import json
import pathlib
import sys


def packages(text):
    return dict(line.split(" ", 1) for line in text.splitlines() if " " in line)


def package_changes(old, new):
    """Lines for packages added, removed, or changed, by name."""
    changes = []
    for name in sorted(old | new):
        before, after = old.get(name), new.get(name)
        if before == after:
            continue
        if before is None:
            changes.append(f"{name}: added {after}")
        elif after is None:
            changes.append(f"{name}: removed {before}")
        else:
            changes.append(f"{name}: {before} -> {after}")
    return changes


def section(title, lines):
    body = "\n".join(lines) if lines else "None."
    return f"## {title} ({len(lines)})\n\n```\n{body}\n```\n"


def report(provenance, commits, new, old):
    artifact = provenance["artifact"]
    head = [
        "# Candidate",
        "",
        f"- Image digest: `{artifact['image_digest']}`",
        f"- Medium SHA-256: `{artifact['medium_sha256']}`",
        f"- Commit: `{provenance['source']['commit']}`",
        "",
    ]
    if old is None:
        changed = section("Packages, first release", sorted(f"{n}: {v}" for n, v in new.items()))
    else:
        changed = section("Packages changed since stable", package_changes(old, new))
    return "\n".join(head) + "\n" + section("Commits since stable", commits) + "\n" + changed


def main(provenance, commits, new, old=None):
    text = pathlib.Path
    print(report(
        json.loads(text(provenance).read_text()),
        text(commits).read_text().splitlines(),
        packages(text(new).read_text()),
        packages(text(old).read_text()) if old else None,
    ))  # fmt: skip


if __name__ == "__main__":
    main(*sys.argv[1:])
