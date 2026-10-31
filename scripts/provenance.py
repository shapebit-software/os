#!/usr/bin/env python3
"""Record what a medium is when it is made, since later builds replace image.tar
and booting would change the file.

Usage: provenance.py digest IMAGE_TAR                 print an image's digest
       provenance.py medium IMAGE_TAR MEDIUM OUT      record a new medium
       provenance.py field RECORD KEY                 print one value of a record
"""

import hashlib
import json
import pathlib
import sys
import tarfile

INDEXES = {"application/vnd.oci.image.index.v1+json", "application/vnd.docker.distribution.manifest.list.v2+json"}


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


def main(command, *args):
    if command == "digest":
        print(image_digest(*args))
    elif command == "medium":
        archive, medium, out = args
        record = {"image_digest": image_digest(archive), "medium_sha256": sha256(medium)}
        pathlib.Path(out).write_text(json.dumps(record, indent=2) + "\n")
    elif command == "field":
        record, key = args
        print(json.loads(pathlib.Path(record).read_text())[key])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:])
