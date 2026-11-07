#!/usr/bin/env python3
"""OCI artifacts of plain files, in the format of `podman artifact`: each file is
one blob, titled with its name, whose digest is the file's SHA-256. This writes
and reads them as OCI layouts; skopeo copies a layout to and from a registry
(`skopeo copy oci:LAYOUT docker://REF`). Blobs are hard links of the files where
the filesystem allows, so a layout of gigabytes costs no copy.

Usage: artifact.py pack LAYOUT TYPE TITLE FILE...   write FILEs as an artifact
       artifact.py unpack LAYOUT DIR [NAME...]      put its files (or only NAMEs) in DIR
       artifact.py list LAYOUT                      print each file's digest and name
"""

import hashlib
import json
import os
import pathlib
import shutil
import sys

MANIFEST = "application/vnd.oci.image.manifest.v1+json"
EMPTY = {"mediaType": "application/vnd.oci.empty.v1+json", "size": 2, "data": "e30="}
EMPTY_DIGEST = "sha256:" + hashlib.sha256(b"{}").hexdigest()
TITLE = "org.opencontainers.image.title"


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def place(source, target):
    """A hard link where possible, else a copy."""
    target = pathlib.Path(target)
    target.unlink(missing_ok=True)
    try:
        os.link(source, target)
    except OSError:
        shutil.copyfile(source, target)


def write_blob(layout, data):
    digest = hashlib.sha256(data).hexdigest()
    (layout / "blobs/sha256" / digest).write_bytes(data)
    return {"digest": f"sha256:{digest}", "size": len(data)}


def pack(layout, artifact_type, title, files):
    layout = pathlib.Path(layout)
    if layout.exists():
        shutil.rmtree(layout)
    (layout / "blobs/sha256").mkdir(parents=True)
    names = [pathlib.Path(f).name for f in files]
    if len(set(names)) != len(names):
        raise ValueError("two files have the same name")
    layers = []
    for path in sorted(files, key=lambda f: pathlib.Path(f).name):
        digest = sha256(path)
        place(path, layout / "blobs/sha256" / digest)
        layers.append({
            "mediaType": "application/octet-stream",
            "digest": f"sha256:{digest}",
            "size": os.path.getsize(path),
            "annotations": {TITLE: pathlib.Path(path).name},
        })  # fmt: skip
    (layout / "blobs/sha256" / EMPTY_DIGEST.split(":")[1]).write_bytes(b"{}")
    manifest = {
        "schemaVersion": 2,
        "mediaType": MANIFEST,
        "artifactType": artifact_type,
        "config": {**EMPTY, "digest": EMPTY_DIGEST},
        "layers": layers,
        "annotations": {TITLE: title},
    }
    descriptor = write_blob(layout, json.dumps(manifest, separators=(",", ":")).encode())
    index = {"schemaVersion": 2, "manifests": [{"mediaType": MANIFEST, **descriptor}]}
    (layout / "index.json").write_text(json.dumps(index))
    (layout / "oci-layout").write_text('{"imageLayoutVersion":"1.0.0"}')


def manifest(layout):
    layout = pathlib.Path(layout)
    index = json.loads((layout / "index.json").read_text())
    if len(index["manifests"]) != 1:
        raise ValueError(f"{layout}: expected one manifest, found {len(index['manifests'])}")
    digest = index["manifests"][0]["digest"]
    return json.loads((layout / "blobs" / digest.replace(":", "/")).read_text())


def files(layout):
    """Each file's name and digest, in the artifact's order."""
    for layer in manifest(layout)["layers"]:
        name = layer.get("annotations", {}).get(TITLE, "")
        if not name or "/" in name or name.startswith("."):
            raise ValueError(f"{layout}: a blob has no usable title: {name!r}")
        yield name, layer["digest"]


def unpack(layout, directory, names=()):
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    found = dict(files(layout))
    missing = set(names) - found.keys()
    if missing:
        raise ValueError(f"{layout}: no file {', '.join(sorted(missing))}")
    for name, digest in found.items():
        if not names or name in names:
            place(pathlib.Path(layout) / "blobs" / digest.replace(":", "/"), directory / name)


def main(command=None, *args):
    if command == "pack" and len(args) >= 4:
        layout, artifact_type, title, *paths = args
        pack(layout, artifact_type, title, paths)
    elif command == "unpack" and len(args) >= 2:
        unpack(args[0], args[1], args[2:])
    elif command == "list" and len(args) == 1:
        for name, digest in files(*args):
            print(digest, name)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:])
