#!/usr/bin/env python3
"""What an image archive of the build is (`make image`, `make update-builds`,
or one pulled with `skopeo copy`): its digest, which `bootc status` reports,
and its labels; and the record of a medium made from one. The build writes
these; the tests (quality/) and distribution (distribution/) read them, so
both depend on the build and not on each other.

The digest is that of the archive's own manifest: `skopeo inspect` reports
Docker's outer index instead, which nests the manifest beside an attestation.

Usage: archive.py digest ARCHIVE                    the archive's digest
       archive.py medium ARCHIVE MEDIUM REVISION    write MEDIUM.json, the record
                                                    of MEDIUM, made from ARCHIVE
"""

import hashlib
import json
import pathlib
import sys
import tarfile

INDEXES = {"application/vnd.oci.image.index.v1+json", "application/vnd.docker.distribution.manifest.list.v2+json"}
VERSION_LABEL = "org.opencontainers.image.version"


def sha256(path):
    with open(path, "rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def manifest(tar):
    """The descriptor of an image archive's own manifest, looking inside
    Docker's nested index, past its attestation for an "unknown" platform."""
    index = json.load(tar.extractfile("index.json"))
    while True:
        manifests = [m for m in index["manifests"] if m.get("platform", {}).get("architecture") != "unknown"]
        if len(manifests) != 1:
            raise ValueError(f"{tar.name}: expected one manifest, found {len(manifests)}")
        descriptor = manifests[0]
        if descriptor["mediaType"] not in INDEXES:
            return descriptor
        index = blob(tar, descriptor["digest"])


def blob(tar, digest):
    return json.load(tar.extractfile("blobs/" + digest.replace(":", "/")))


def image_digest(archive):
    with tarfile.open(archive) as tar:
        return manifest(tar)["digest"]


def label(archive, key):
    with tarfile.open(archive) as tar:
        config = blob(tar, blob(tar, manifest(tar)["digest"])["config"]["digest"])
    return config.get("config", {}).get("Labels", {})[key]


def medium_record(version, digest, revision, medium_sha256):
    """What a medium is (packages/installer/README.md#medium): the OS it installs, the
    commit its screens show, and its checksum, which the download server checks."""
    return {"version": version, "image_digest": digest, "revision": revision, "medium_sha256": medium_sha256}


def write_medium_record(archive, medium, revision):
    """Written as the medium is made, since later builds replace the image
    archive and booting would change the medium."""
    medium = pathlib.Path(medium)
    record = medium_record(label(archive, VERSION_LABEL), image_digest(archive), revision, sha256(medium))
    medium.with_name(medium.name + ".json").write_text(json.dumps(record, indent=2) + "\n")


def main(command=None, *args):
    if command == "digest" and len(args) == 1:
        print(image_digest(args[0]))
    elif command == "medium" and len(args) == 3:
        write_medium_record(*args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:])
