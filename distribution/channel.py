"""The channel computers update from, os:stable (README.md#versions-and-channels):
promote the draft's candidate to it, signed with the release image key and
checked as computers check it; undo the last release; and prune what nobody
may download any more."""

import contextlib
import json
import os
import pathlib
import sys
import tempfile

from common import (INSTALLED_KEY, REPOSITORY, TRUST, VERSION_LABEL, WITHDRAWN, copy, exists, image_label, log,
                    release_record, releases, run)
import oci


def draft_version(releases):
    """The candidate to release: the newest draft. A release that was undone is
    no longer a draft, so it cannot go out again."""
    return max((r["tagName"] for r in releases if r["isDraft"]), default=None)


def latest_release(releases):
    return next((r["tagName"] for r in releases if r.get("isLatest")), None)


def previous_release(releases, version):
    """The release that stable goes back to from VERSION: the newest one before
    it that was not withdrawn."""
    return max((r["tagName"] for r in releases if not r["isDraft"] and r["tagName"] < version
                and not r["name"].endswith(WITHDRAWN)), default=None)


def signature_tag(digest):
    """Where a sigstore signature of the image DIGEST is, beside it, as
    use-sigstore-attachments puts it (packages/updates/system/shapebit-os.yaml)."""
    return digest.replace(":", "-") + ".sig"


def to_delete(versions, keep_tags, children):
    """The versions of a GHCR package to delete: those without a tag to keep,
    unless a kept index refers to them, as GHCR lists an index's manifests as
    untagged versions. versions: [{"id", "name" (the digest), "tags"}];
    children: digest -> the digests that its manifest refers to. Refuses if a
    tag to keep is missing, so a mistake deletes nothing."""
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


def verification_policy(policy, public_key):
    """The policy that computers check updates with, with the key at public_key
    instead of where the image installs it."""
    text = json.dumps(policy)
    if INSTALLED_KEY not in text:
        raise ValueError(f"the policy has no key at {INSTALLED_KEY}")
    return json.loads(text.replace(INSTALLED_KEY, str(public_key)))


@contextlib.contextmanager
def trusted(trust, work):
    """The candidate's TRUST files in WORK: the policy, naming the key where it
    lies here, and registries.d; yields their paths."""
    work = pathlib.Path(work)
    key = work / "release-image.pub"
    key.write_text(trust["key"])
    (work / "registries.d").mkdir()
    (work / "registries.d" / pathlib.PurePosixPath(TRUST["registries"]).name).write_text(trust["registries"])
    policy = work / "policy.json"
    policy.write_text(json.dumps(verification_policy(json.loads(trust["policy"]), key)))
    yield policy, work / "registries.d"


def verify(ref, policy, registries_d, work):
    """Fail unless computers would accept REF: copy it as they do, with their
    POLICY, which requires the release image key's signature. The policy is
    checked before the copy; a layout cannot keep the signatures themselves."""
    run("skopeo", "--policy", policy, "--registries.d", registries_d, "copy", "-q", "--remove-signatures",
        f"docker://{ref}", f"oci:{work}/image")


def promote(key):
    """The draft's candidate, unchanged, as the release os:<version>, signed with
    KEY, then os:stable, which computers update from. The sources and the SBOM
    go first, so that they are public before the image is. Promotion never
    re-signs boot files: a development build can never become a release."""
    version = draft_version(releases())
    if not version:
        sys.exit("error: there is no draft release; run Candidate")
    record = release_record(version)
    if "trust" not in record:
        sys.exit("error: the draft has no trust files; run Candidate again")
    digest = record["image"].split("@", 1)[1]
    if not exists(record["image"]):
        sys.exit(f"error: {record['image']} no longer exists")
    copy(f"docker://{record['sources']}", f"docker://{REPOSITORY}:{version}-sources")
    if record["sbom"]:
        copy(f"docker://{record['sbom']}", f"docker://{REPOSITORY}:{version}-sbom")
    with (tempfile.TemporaryDirectory(dir=os.environ.get("RUNNER_TEMP")) as work,
          trusted(record["trust"], work) as (policy, registries_d),
          tempfile.NamedTemporaryFile(dir=work) as passphrase):
        copy(f"docker://{record['image']}", f"docker://{REPOSITORY}:{version}",
             "--sign-by-sigstore-private-key", key, "--sign-passphrase-file", passphrase.name,
             "--registries.d", str(registries_d))
        verify(f"{REPOSITORY}:{version}", policy, registries_d, work)
    released = run("skopeo", "inspect", "--format", "{{.Digest}}", f"docker://{REPOSITORY}:{version}",
                   capture=True).strip()
    if released != digest:
        sys.exit(f"error: {REPOSITORY}:{version} is {released}, not the tested {digest}")
    copy(f"docker://{REPOSITORY}:{version}", f"docker://{REPOSITORY}:stable")
    run("gh", "release", "edit", version, "--draft=false", "--latest", "--target", record["revision"])
    log(f"Released {version} ({digest})")


def undo():
    """stable back to the release before the latest, which is marked withdrawn,
    and computers take it as their next update. Withdrawn first: until the
    previous release is the latest, a repeat of this still finds the withdrawn
    one, so running it again finishes the job."""
    known = releases()
    latest = latest_release(known)
    previous = previous_release(known, latest) if latest else None
    if not previous:
        sys.exit(f"error: {latest} has no earlier release to go back to")
    if not exists(f"{REPOSITORY}:{previous}"):
        sys.exit(f"error: {REPOSITORY}:{previous} no longer exists")
    title = json.loads(run("gh", "release", "view", latest, "--json", "name,body", capture=True))
    if not title["name"].endswith(WITHDRAWN):
        run("gh", "release", "edit", latest, "--title", latest + WITHDRAWN, "--notes",
            f"**Withdrawn:** installed systems went back to {previous}.\n\n{title['body']}")
    copy(f"docker://{REPOSITORY}:{previous}", f"docker://{REPOSITORY}:stable")
    run("gh", "release", "edit", previous, "--latest")


def prune(dry_run=False):
    """Every version of os but stable's and the release before it (Undo's
    target), each with its sources, SBOM and signature. Moving a tag deletes
    nothing, and a version stays downloadable by its digest until it is
    deleted. Deleting needs this repository's Admin role on the package;
    deleted versions can be restored for 30 days."""
    stable = image_label(f"{REPOSITORY}:stable", VERSION_LABEL)
    previous = previous_release(releases(), stable)
    keep = ["stable"]
    for version in filter(None, (stable, previous)):
        if version == previous and not exists(f"{REPOSITORY}:{version}"):
            continue
        keep += [version, f"{version}-sources"]
        # Releases from before SBOMs and signatures have none.
        for optional in (f"{version}-sbom", signature_tag(oci.registry_digest(f"{REPOSITORY}:{version}"))):
            if exists(f"{REPOSITORY}:{optional}"):
                keep.append(optional)
    _, org, package = REPOSITORY.split("/", 2)
    path = f"/orgs/{org}/packages/container/{package.replace('/', '%2F')}/versions"
    lines = run("gh", "api", "--paginate", path, "--jq", ".[] | {id, name, tags: .metadata.container.tags}",
                capture=True)
    versions = [json.loads(line) for line in lines.splitlines()]

    def children(digest):
        manifest = json.loads(run("skopeo", "inspect", "--raw", f"docker://{REPOSITORY}@{digest}", capture=True))
        return [m["digest"] for m in manifest.get("manifests", [])]

    for version in to_delete(versions, keep, children):
        log(f"{'Would delete' if dry_run else 'Deleting'} {version['name']} {version['tags'] or '(untagged)'}")
        if not dry_run:
            run("gh", "api", "-X", "DELETE", f"{path}/{version['id']}", capture=True)
