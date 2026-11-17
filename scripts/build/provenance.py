#!/usr/bin/env python3
"""Record what a medium is when it is made, since later builds replace image.tar
and booting would change the file.

Usage: provenance.py digest IMAGE_TAR                 print an image's digest
       provenance.py label IMAGE_TAR KEY              print one of an image's labels
       provenance.py medium IMAGE_TAR MEDIUM REVISION OUT   record a new medium
       provenance.py sources RECORD TAR               add the medium's sources to its record
       provenance.py field RECORD KEY [DEFAULT]       print one value of a record

A medium's record names the system it installs: its version, which is also the
installer's, and its image digest; the commit the installer was built from,
which its screens show; and the SHA-256 of the medium and of its sources, which
the download server checks.
"""

import hashlib
import json
import pathlib
import sys
import tarfile

INDEXES = {"application/vnd.oci.image.index.v1+json", "application/vnd.docker.distribution.manifest.list.v2+json"}


def manifest(tar):
    """The descriptor of the image's own manifest, which `bootc status` reports.
    Docker nests it in a second index, beside an attestation for an "unknown"
    platform."""
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


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main(command, *args):
    if command == "digest":
        print(image_digest(*args))
    elif command == "label":
        print(label(*args))
    elif command == "medium":
        archive, medium, revision, out = args
        record = {
            "version": label(archive, "org.opencontainers.image.version"),
            "image_digest": image_digest(archive),
            "revision": revision,
            "medium_sha256": sha256(medium),
        }
        pathlib.Path(out).write_text(json.dumps(record, indent=2) + "\n")
    elif command == "sources":
        record, tar = args
        values = json.loads(pathlib.Path(record).read_text()) | {"sources_sha256": sha256(tar)}
        pathlib.Path(record).write_text(json.dumps(values, indent=2) + "\n")
    elif command == "field":
        # A default for a key that older records lack.
        record, key, *default = args
        values = json.loads(pathlib.Path(record).read_text())
        print(values.get(key, *default) if default else values[key])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:])
