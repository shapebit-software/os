#!/usr/bin/env python3
"""Tie test results to the exact artifact that they tested.

Records what a medium or disk is when it is made, since later builds replace
image.tar and booting would change the file; then writes provenance.json next
to each run's results. The kinds of run differ in what they prove:

  container-image   checks of the image's files; nothing booted
  installer-medium  the medium as it boots, before installing
  installed-disk    a disk that installerctl installed from the medium, without
                    its UI, then cloned for each run: tests the installed system
  release-medium    the medium's whole path through its UI (openQA)

Usage: provenance.py digest IMAGE_TAR                 print an image's digest
       provenance.py image IMAGE_TAR OUT              record an image
       provenance.py medium IMAGE_TAR MEDIUM OUT      record a new medium
       provenance.py disk MEDIUM_RECORD DISK OUT      record a new disk
       provenance.py run KIND PLAN OUTCOME OUT RECORD write a run's provenance
       provenance.py field RECORD KEY                 print one value of a record
"""

import datetime
import hashlib
import json
import pathlib
import subprocess
import sys
import tarfile

INDEXES = {"application/vnd.oci.image.index.v1+json", "application/vnd.docker.distribution.manifest.list.v2+json"}
KINDS = {"container-image", "installer-medium", "installed-disk", "release-medium"}


def image_digest(archive):
    """The digest of the image's own manifest, which `bootc status` reports. Docker
    nests it in a second index, beside an attestation for an "unknown" platform."""
    with tarfile.open(archive) as tar:
        index = json.load(tar.extractfile("index.json"))
        while True:
            manifests = [m for m in index["manifests"] if m.get("platform", {}).get("architecture") != "unknown"]
            if len(manifests) != 1:
                raise ValueError(f"{archive}: expected one manifest, found {len(manifests)}")
            manifest = manifests[0]
            if manifest["mediaType"] not in INDEXES:
                return manifest["digest"]
            blob = "blobs/" + manifest["digest"].replace(":", "/")
            index = json.load(tar.extractfile(blob))


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def commit():
    def git(*args):
        return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()

    return {"commit": git("rev-parse", "HEAD"), "dirty": bool(git("status", "--porcelain"))}


def run_record(plan, outcome, kind, disk_record):
    if kind not in KINDS:
        raise ValueError(f"unknown kind of run: {kind}")
    return {
        "kind": kind,
        "plan": plan,
        "outcome": outcome,
        "finished": datetime.datetime.now(datetime.UTC).isoformat(timespec="seconds"),
        "source": commit(),
        "artifact": json.loads(pathlib.Path(disk_record).read_text()),
    }


def write(path, record):
    pathlib.Path(path).write_text(json.dumps(record, indent=2) + "\n")


def main(command, *args):
    if command == "digest":
        print(image_digest(*args))
    elif command == "image":
        archive, out = args
        write(out, {"image_digest": image_digest(archive)})
    elif command == "medium":
        archive, medium, out = args
        write(out, {"image_digest": image_digest(archive), "medium_sha256": sha256(medium)})
    elif command == "disk":
        medium_record, disk, out = args
        record = json.loads(pathlib.Path(medium_record).read_text())
        write(out, record | {"disk_sha256": sha256(disk)})
    elif command == "run":
        kind, plan, outcome, out, record = args
        write(out, run_record(plan, outcome, kind, record))
    elif command == "field":
        record, key = args
        print(json.loads(pathlib.Path(record).read_text())[key])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:])
