"""A candidate (README.md#steps): the built image, the build that the update
test moves on to, its sources, and its SBOM, pushed to os/candidate; and,
once its tests pass, its draft release, with notes, packages, and a record
that names each part by digest."""

import json
import os
import pathlib
import sys
import tempfile

from common import (CANDIDATES, REPOSITORY, REVISION_LABEL, TRUST, VERSION_LABEL, copy, engine, exists, image_label,
                    log, push_sources, releases, run, stdout_to_stderr)
import archive
import oci
import sbom
import sources


def commits_since(revision):
    """The commits since REVISION, for the notes; all of them when there is no
    REVISION, as for a stable image from before the revision label, or when it
    is no longer in the history, which started again on 2026-11-23."""
    if revision and run("git", "cat-file", "-e", f"{revision}^{{commit}}", check=False).returncode == 0:
        return run("git", "log", "--oneline", f"{revision}..HEAD", capture=True)
    return run("git", "log", "--oneline", "HEAD", capture=True)


def candidate_record(version, revision, digest, sources_digest, sbom_digest, trust):
    """What a candidate is, as the draft release keeps it and promote copies it:
    each part by digest, so that what was tested is what is released; and the
    contents of its TRUST files, which promote checks the signature with."""
    return {
        "version": version,
        "revision": revision,
        "image": f"{CANDIDATES}@{digest}",
        "sources": f"{CANDIDATES}@{sources_digest}",
        "sbom": f"{CANDIDATES}@{sbom_digest}" if sbom_digest else None,
        "trust": trust,
    }


def read_packages(text):
    """Each package's versions, from "name version" lines; a package such as
    the kernel can have several."""
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


def notes(digest, sources_ref, commit, commits, old_packages, new_packages, bootstrap=False):
    """A release's notes: what it is, and what changed since stable. GitHub's
    generated notes list pull requests, and most commits here have none."""
    changes = package_changes(read_packages(old_packages), read_packages(new_packages))
    return "\n".join([
        *(["**Bootstrap:** not tested by an update, as no installer existed; the Installer workflow tests it "
           "in full.", ""] if bootstrap else []),
        f"- Image digest: `{digest}`",
        f"- Sources: `{sources_ref}`",
        f"- Commit: `{commit}`",
        "",
        "## Commits since stable",
        "```",
        commits.strip() or "None",
        "```",
        "## Packages changed since stable",
        *(changes or ["None"]),
        "",
    ])  # fmt: skip


def candidate(version, image, image_archive, update_archive):
    """The image, the build that the update test moves on to, its sources, and
    its SBOM, to os/candidate. The digest is the one the tests compare with the
    booted system. Sources are collected now, while Fedora's repositories and
    the COPR still have them (sources/README.md). Only the digest goes
    to stdout, for GITHUB_OUTPUT."""
    with stdout_to_stderr():
        digest = push_candidate(version, image, image_archive, update_archive)
    print(f"digest={digest}")


def push_candidate(version, image, image_archive, update_archive):
    digest = archive.image_digest(image_archive)
    copy(f"oci-archive:{image_archive}", f"docker://{CANDIDATES}:{version}")
    pushed = run("skopeo", "inspect", "--format", "{{.Digest}}", f"docker://{CANDIDATES}:{version}",
                 capture=True).strip()
    if pushed != digest:
        sys.exit(f"error: {CANDIDATES}:{version} is {pushed}, not the build's {digest}")
    copy(f"oci-archive:{update_archive}", f"docker://{CANDIDATES}:{version}-update")
    work = pathlib.Path(image_archive).parent
    stable = image_label(f"{REPOSITORY}:stable", VERSION_LABEL) if exists(f"{REPOSITORY}:stable") else ""
    names = sources.collect(image, work / "sources")
    if stable:
        before = oci.titles(f"{REPOSITORY}:{stable}-sources") or set()
        new = [name for name in names if name not in before]
        log("\n  ".join([f"{len(new)} source RPMs new since {stable}:", *new]))
    push_sources(work / "sources", f"{CANDIDATES}:{version}-sources", f"ShapeBit {version}: sources")
    sbom.generate(image, work / "sbom")
    oci.push(f"{CANDIDATES}:{version}-sbom", sbom.TYPE, f"ShapeBit {version}: SBOM", [work / "sbom" / sbom.FILE])
    return digest


def draft(version, digest, bootstrap=False):
    """The draft release of a candidate whose tests passed, which promote
    releases: its notes, its packages, and its record. Only the latest
    candidate can be released, so only it keeps a draft."""
    def packages(ref):
        return "".join(sorted(run(*engine(), "run", "--rm", "--network", "none", "--entrypoint", "rpm", ref,
                                  "-qa", "--qf", "%{NAME} %{VERSION}-%{RELEASE}\n", capture=True).splitlines(True)))

    candidate_ref = f"{CANDIDATES}@{digest}"
    revision = image_label(candidate_ref, REVISION_LABEL)
    trust = {name: run(*engine(), "run", "--rm", "--network", "none", "--entrypoint", "cat", candidate_ref, path,
                       capture=True) for name, path in TRUST.items()}  # fmt: skip
    new = packages(candidate_ref)
    old, stable = "", None
    if exists(f"{REPOSITORY}:stable"):
        old = packages(f"{REPOSITORY}:stable")
        stable = image_label(f"{REPOSITORY}:stable", REVISION_LABEL)
    commits = commits_since(stable)
    record = candidate_record(version, revision, digest, oci.registry_digest(f"{CANDIDATES}:{version}-sources"),
                              oci.registry_digest(f"{CANDIDATES}:{version}-sbom"), trust)
    text = notes(digest, f"{REPOSITORY}:{version}-sources", revision, commits, old, new, bootstrap)
    with tempfile.TemporaryDirectory() as work:
        work = pathlib.Path(work)
        (work / "notes.md").write_text(text)
        (work / "packages.txt").write_text(new)
        (work / "record.json").write_text(json.dumps(record, indent=2) + "\n")
        for release in releases():
            if release["isDraft"]:
                run("gh", "release", "delete", release["tagName"], "--yes")
        run("gh", "release", "create", version, "--draft", "--target", revision, "--title", version,
            "--notes-file", work / "notes.md", work / "packages.txt", work / "record.json")
    if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(summary, "a") as file:
            file.write(f"# Candidate {version}\n\n{text}")
