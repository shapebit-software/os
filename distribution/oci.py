#!/usr/bin/env python3
"""OCI artifacts and registry digests, as release.py reads and writes them.

Artifacts of plain files: each file is one blob, titled with its name. ORAS,
the reference tool for them, pushes and pulls them (push(), pull(), titles());
Fedora doesn't package it, so it runs from its image, pinned by digest, with
the files and the registry login mounted.
"""

import hashlib
import json
import os
import pathlib
import shlex
import subprocess
import sys

ORAS_IMAGE = "ghcr.io/oras-project/oras:v1.3.6@sha256:9cfb578be975b762fd898b9d004243d8003aeb807a3e15b2ed212cdd1326c9eb"
TITLE = "org.opencontainers.image.title"


def auth_file():
    """The registry login that skopeo reads, in its order: REGISTRY_AUTH_FILE,
    containers' auth.json, then Docker's, which CI's `docker login` writes."""
    candidates = [os.environ.get("REGISTRY_AUTH_FILE"),
                  os.environ.get("XDG_RUNTIME_DIR") and f"{os.environ['XDG_RUNTIME_DIR']}/containers/auth.json",
                  pathlib.Path.home() / ".docker/config.json"]  # fmt: skip
    return next((pathlib.Path(c) for c in candidates if c and pathlib.Path(c).is_file()), None)


def oras(directory, *args):
    """The command that runs ORAS on DIRECTORY, its working directory, as this
    user, so that what it pulls is theirs."""
    command = [*shlex.split(os.environ["ENGINE"]), "run", "--rm", "--user", f"{os.getuid()}:{os.getgid()}",
               "-e", "HOME=/tmp", "-v", f"{pathlib.Path(directory).resolve()}:/work:z", "-w", "/work"]  # fmt: skip
    login = []
    if auth := auth_file():
        command += ["-v", f"{auth}:/auth.json:ro,z"]
        login = ["--registry-config", "/auth.json"]
    return [*command, ORAS_IMAGE, *args, *login]


def push(ref, artifact_type, title, files):
    """FILES, all in one directory, as an artifact at the registry REF."""
    paths = [pathlib.Path(f) for f in files]
    if len({p.parent.resolve() for p in paths}) != 1:
        raise ValueError("the files must be in one directory")
    names = sorted(p.name for p in paths)
    subprocess.run(oras(paths[0].parent, "push", ref, "--artifact-type", artifact_type,
                        "--annotation", f"{TITLE}={title}", *names), check=True)  # fmt: skip


def pull(ref, directory, attempts=3):
    """The files of the artifact at the registry REF, into DIRECTORY. A reset
    connection stops ORAS mid-file, which a medium's gigabytes meet on CI's
    runners, and ORAS doesn't retry it; it starts the file over."""
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    for attempt in range(1, attempts + 1):
        try:
            subprocess.run(oras(directory, "pull", ref, "--output", "."), check=True)
            return
        except subprocess.CalledProcessError:
            if attempt == attempts:
                raise
            print(f"Pulling {ref} failed; trying again ({attempt + 1} of {attempts})", file=sys.stderr)


def titles(ref):
    """The names of the files of the artifact at REF, from its manifest alone;
    None if it is missing."""
    done = subprocess.run(["skopeo", "inspect", "--raw", f"docker://{ref}"], capture_output=True, text=True)
    if done.returncode != 0:
        return None
    return {layer.get("annotations", {}).get(TITLE) for layer in json.loads(done.stdout).get("layers", [])}


def registry_digest(ref):
    """The digest of what REF names in a registry: its manifest's SHA-256, for
    artifacts too, which `skopeo inspect` cannot read; None if it is missing."""
    done = subprocess.run(["skopeo", "inspect", "--raw", f"docker://{ref}"], capture_output=True)
    return "sha256:" + hashlib.sha256(done.stdout).hexdigest() if done.returncode == 0 else None
