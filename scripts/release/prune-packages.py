#!/usr/bin/env python3
"""Delete every version of a GHCR container package except those that carry one of
the tags to keep, and what they refer to: the manifests of an index, which GHCR
lists as untagged versions. Moving a tag deletes nothing, and a version stays
downloadable by its digest until it is deleted (docs/License.md). Deleted versions
can be restored for 30 days.

Usage: prune-packages.py [--dry-run] REPOSITORY TAG...
       e.g. prune-packages.py ghcr.io/shapebit-software/os stable 202611051112 ...
`gh` lists and deletes the versions, as a user or token with the Admin role on the
package; skopeo reads the manifests.
"""

import json
import subprocess
import sys

INDEXES = {"application/vnd.oci.image.index.v1+json", "application/vnd.docker.distribution.manifest.list.v2+json"}


def to_delete(versions, keep_tags, children):
    """The versions to delete: those without a tag to keep, unless a kept index
    refers to them. versions: [{"id", "name" (the digest), "tags"}]; children:
    digest -> the digests that its manifest refers to."""
    kept = {v["name"] for v in versions if set(v["tags"]) & set(keep_tags)}
    found = {tag for v in versions for tag in v["tags"]}
    missing = set(keep_tags) - found
    if missing:
        raise ValueError(f"no version has the tags {sorted(missing)}: refusing to delete anything")
    pending = list(kept)
    while pending:
        for child in children(pending.pop()):
            if child not in kept:
                kept.add(child)
                pending.append(child)
    return [v for v in versions if v["name"] not in kept]


def gh(*args):
    return subprocess.run(["gh", "api", *args], check=True, capture_output=True, text=True).stdout


def main(argv):
    dry_run = argv[:1] == ["--dry-run"]
    argv = argv[1:] if dry_run else argv
    if len(argv) < 2:
        sys.exit(__doc__)
    repository, *keep = argv
    _, org, package = repository.split("/", 2)
    path = f"/orgs/{org}/packages/container/{package.replace('/', '%2F')}/versions"
    lines = gh("--paginate", path, "--jq", ".[] | {id, name, tags: .metadata.container.tags}")
    versions = [json.loads(line) for line in lines.splitlines()]

    def children(digest):
        manifest = json.loads(subprocess.run(
            ["skopeo", "inspect", "--raw", f"docker://{repository}@{digest}"],
            check=True, capture_output=True, text=True,
        ).stdout)  # fmt: skip
        if manifest.get("mediaType") in INDEXES or "manifests" in manifest:
            return [m["digest"] for m in manifest["manifests"]]
        return []

    for version in to_delete(versions, keep, children):
        print(f"{'Would delete' if dry_run else 'Deleting'} {version['name']} {version['tags'] or '(untagged)'}")
        if not dry_run:
            gh("-X", "DELETE", f"{path}/{version['id']}")


if __name__ == "__main__":
    main(sys.argv[1:])
