#!/usr/bin/python3
"""Read the packaged materials for Settings > Licenses; no scanning or network.
Qt's text FileView cannot decompress legacy notices, so this small reader also
handles compressed files and references to RPM-owned documents.
Usage: licenses list | licenses read COMPONENT/FILE
LICENSES_DIR can point at a trial installation during development or tests.
"""

import bz2
import gzip
import json
import lzma
import os
import pathlib
import sys

ROOT = pathlib.Path(os.environ.get("LICENSES_DIR", "/usr/share/licenses"))


def listing():
    components = []
    for directory in sorted(ROOT.iterdir(), key=lambda p: p.name.lower()):
        if not directory.is_dir() or directory.name.startswith("."):
            continue
        files = []
        for path in sorted(directory.rglob("*")):
            relative = path.relative_to(ROOT)
            if not any(p.startswith(".") for p in relative.parts) and path.is_file() and path.stat().st_size:
                files.append({"name": str(path.relative_to(directory)), "path": str(relative)})
        if files:
            components.append({"name": directory.name, "files": files})
    return components


def read(name):
    path = pathlib.PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or len(path.parts) < 2 or any(p.startswith(".") for p in path.parts):
        raise ValueError("Choose a packaged license file.")
    data = (ROOT / path).read_bytes()
    if path.suffix == ".gz":
        data = gzip.decompress(data)
    elif path.suffix == ".bz2":
        data = bz2.decompress(data)
    elif path.suffix == ".xz":
        data = lzma.decompress(data)
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["list"]:
            result = {"components": listing()}
        elif len(sys.argv) == 3 and sys.argv[1] == "read":
            result = {"text": read(sys.argv[2])}
        else:
            raise ValueError(__doc__)
        print(json.dumps(result))
    except (OSError, ValueError) as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
